import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';

import '../../../../constants/k.dart';
import '../../../../extensions/e_request_context.dart';
import '../../../../models/m_api_response.dart';
import '../../../../services/api_mapper.dart';
import '../../../../services/leaderboard_service.dart';
import '../../../../services/logging_service.dart';
import '../../../../services/submission_codec.dart';
import '../../../../storage_models/m_judging_result.dart';

const _keyPayload = 'payload';

// Compact-JSON keys inside the decoded submission payload (see backend-api §7.1).
const _pBatch = 'b';
const _pJudge = 'j';
const _pRound = 'r';
const _pGroup = 'g';
const _pScoredAt = 't';
const _pAnimals = 'a';
const _pAnimalId = 'id';
const _pScores = 's';

Future<Response> onRequest(RequestContext context) =>
    context.forHttpMethod(post: () => _ingest(context));

/// Admin ingest of a judge's QR submission.
///
/// Decodes + HMAC-verifies the `LC1:` payload, then (idempotently by
/// `qr_batch_id`) creates one [JudgingResultModel] per animal with a
/// server-computed `weighted_total`, and recomputes the affected leaderboard.
Future<ApiResponseModel> _ingest(RequestContext context) async {
  final body = await context.getValidatedBodyMap(requiredKeys: [_keyPayload]);
  final payload = body.getString(_keyPayload);
  if (payload.isEmpty) {
    return ApiResponseModel.missingBodyKeys([_keyPayload]);
  }

  // 1. Decode + verify integrity.
  final Map<String, dynamic> data;
  try {
    data = SubmissionCodec.decodeAndVerify(payload);
  } on SubmissionCodecError catch (e) {
    LogService.logWarning('[ingest-qr] rejected: ${e.message}');
    return ApiResponseModel.badRequestError(e.message);
  }

  final m = APIMapper(data);
  final batchId = m.getString(_pBatch);
  final judgeUserId = m.getString(_pJudge);
  final round = m.getInt(_pRound, 1);
  final group = m.getInt(_pGroup);
  final scoredAtEpoch = m.getInt(_pScoredAt);
  final animals = data[_pAnimals];

  if (batchId.isEmpty) {
    return const ApiResponseModel.badRequestError('Payload missing batch id');
  }
  if (animals is! List || animals.isEmpty) {
    return const ApiResponseModel.badRequestError(
      'Payload contains no animal scores',
    );
  }

  // 2. Idempotency — never double-ingest the same batch.
  final existing = await JudgingResultModel.storage.getModelWhere(
    where.eq(JudgingResultModel.keyQrBatchId, batchId).eq(kKeyIsDeleted, false),
  );
  if (existing != null) {
    return ApiResponseModel(
      status: 208,
      message: 'Submission already ingested (batch $batchId)',
      jsonData: {'qr_batch_id': batchId},
    );
  }

  // 3. Load the (shared) criteria for weighting + score-range validation.
  final attributes = await LeaderboardService.loadAttributes();

  final submittedAt = DateTime.fromMillisecondsSinceEpoch(
    scoredAtEpoch * 1000,
    isUtc: true,
  );

  // 4. Build + validate one result per animal.
  final toInsert = <JudgingResultModel>[];
  for (final raw in animals) {
    if (raw is! Map<String, dynamic>) {
      return const ApiResponseModel.badRequestError('Malformed animal entry');
    }
    final animalId = (raw[_pAnimalId] ?? '').toString();
    final scores = raw[_pScores];
    if (animalId.isEmpty || scores is! Map<String, dynamic>) {
      return const ApiResponseModel.badRequestError(
        'Animal entry missing id or scores',
      );
    }

    // Validate each score against its attribute max (when criteria known).
    for (final score in scores.entries) {
      final attr = attributes[score.key];
      final value = double.tryParse(score.value.toString());
      if (value == null || value < 0) {
        return ApiResponseModel.badRequestError(
          'Invalid score for attribute ${score.key} on animal $animalId',
        );
      }
      if (attr != null && value > attr.maxScore) {
        return ApiResponseModel.badRequestError(
          'Score ${value.toStringAsFixed(0)} exceeds max ${attr.maxScore} '
          'for attribute "${attr.name}" on animal $animalId',
        );
      }
    }

    final weightedTotal = LeaderboardService.computeWeightedTotal(
      scores,
      attributes,
    );

    final now = DateTime.now().toUtc();
    toInsert.add(
      JudgingResultModel.fromMap({
        kKeyID: newUuid(),
        JudgingResultModel.keyJudgeUserId: judgeUserId,
        JudgingResultModel.keyAnimalId: animalId,
        JudgingResultModel.keyGroupNumber: group,
        JudgingResultModel.keyRound: round,
        JudgingResultModel.keyAttributeScores: scores,
        JudgingResultModel.keyWeightedTotal: weightedTotal,
        JudgingResultModel.keySubmittedAt: submittedAt.toIso8601String(),
        JudgingResultModel.keyQrBatchId: batchId,
        kKeyCreatedAt: now.toIso8601String(),
        kKeyUpdatedAt: now.toIso8601String(),
        kKeyServerUpdatedAt: now.toIso8601String(),
        kKeyIsDeleted: false,
      }),
    );
  }

  // 5. Persist results.
  var inserted = 0;
  for (final result in toInsert) {
    final saved = await JudgingResultModel.storage.insertModel(result);
    if (saved != null) inserted++;
  }

  // 6. Recompute the leaderboard for the affected round/group.
  await LeaderboardService.recomputeRoundGroup(round, group);

  LogService.logInfo(
    '[ingest-qr] batch $batchId: judge $judgeUserId, round $round, '
    'group $group, $inserted result(s)',
  );

  return ApiResponseModel.success(
    message: 'Submission ingested',
    jsonData: {
      'qr_batch_id': batchId,
      'round': round,
      'group_number': group,
      'judge_user_id': judgeUserId,
      'results_created': inserted,
    },
  );
}
