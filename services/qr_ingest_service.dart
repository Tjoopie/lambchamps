import 'package:mongo_dart/mongo_dart.dart';

import '../constants/k.dart';
import '../models/m_api_response.dart';
import '../services/api_mapper.dart';
import '../services/leaderboard_service.dart';
import '../services/submission_codec.dart';
import '../storage_models/m_judging_result.dart';

const _pBatch = 'b';
const _pJudge = 'j';
const _pRound = 'r';
const _pGroup = 'g';
const _pScoredAt = 't';
const _pAnimals = 'a';
const _pAnimalId = 'id';
const _pScores = 's';

/// Builds judging_results documents from a verified compact submission map.
class QrIngestService {
  QrIngestService._();

  /// Returns `{ documents, qr_batch_id, round, group_number, judge_user_id }`.
  static Future<ApiResponseModel> buildDocuments(
    Map<String, dynamic> data,
  ) async {
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

    final attributes = await LeaderboardService.loadAttributes();
    final submittedAt = DateTime.fromMillisecondsSinceEpoch(
      scoredAtEpoch * 1000,
      isUtc: true,
    );

    final documents = <Map<String, dynamic>>[];
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
      documents.add({
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
      });
    }

    return ApiResponseModel.success(
      message: 'Result documents built',
      jsonData: {
        'qr_batch_id': batchId,
        'round': round,
        'group_number': group,
        'judge_user_id': judgeUserId,
        'documents': documents,
      },
    );
  }

  /// Full ingest: decode payload, idempotent insert, leaderboard recompute.
  static Future<ApiResponseModel> ingestPayload(String payload) async {
    if (payload.isEmpty) {
      return ApiResponseModel.missingBodyKeys(['payload']);
    }

    final Map<String, dynamic> data;
    try {
      data = SubmissionCodec.decodeAndVerify(payload);
    } on SubmissionCodecError catch (e) {
      return ApiResponseModel.badRequestError(e.message);
    }

    final batchId = (data['b'] ?? '').toString();
    if (batchId.isEmpty) {
      return const ApiResponseModel.badRequestError('Payload missing batch id');
    }

    final existing = await JudgingResultModel.storage.getModelWhere(
      where.eq(JudgingResultModel.keyQrBatchId, batchId).eq(kKeyIsDeleted, false),
    );
    if (existing != null) {
      return ApiResponseModel(
        status: 208,
        message: 'Submission already ingested (batch $batchId)',
        jsonData: {'qr_batch_id': batchId, 'already_ingested': true},
      );
    }

    final built = await buildDocuments(data);
    if (built.status != 200 || built.jsonData is! Map<String, dynamic>) {
      return built;
    }

    final jsonData = built.jsonData as Map<String, dynamic>;
    final documents = jsonData['documents'];
    if (documents is! List) {
      return ApiResponseModel.error('Build step returned no documents');
    }

    var inserted = 0;
    for (final doc in documents) {
      if (doc is! Map<String, dynamic>) continue;
      final saved = await JudgingResultModel.storage.insertModel(
        JudgingResultModel.fromMap(doc),
      );
      if (saved != null) inserted++;
    }

    final round = jsonData['round'] as int? ?? 1;
    final group = jsonData['group_number'] as int? ?? 0;
    await LeaderboardService.recomputeRoundGroup(round, group);

    return ApiResponseModel.success(
      message: 'Submission ingested',
      jsonData: {
        'qr_batch_id': batchId,
        'round': round,
        'group_number': group,
        'judge_user_id': jsonData['judge_user_id'],
        'results_created': inserted,
      },
    );
  }
}
