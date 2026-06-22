import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';

import '../../../../constants/k.dart';
import '../../../../extensions/e_request_context.dart';
import '../../../../models/m_api_response.dart';
import '../../../../services/leaderboard_service.dart';
import '../../../../services/logging_service.dart';
import '../../../../storage_models/m_group.dart';
import '../../../../storage_models/m_leaderboard.dart';
import '../../../../storage_models/m_round_config.dart';

Future<Response> onRequest(RequestContext context) =>
    context.forHttpMethod(post: () => _advance(context));

Future<ApiResponseModel> _advance(RequestContext context) async {
  await LeaderboardService.recomputeRound(1);

  final groups = await GroupModel.storage.getAllModelsWhere(
    where.eq(kKeyIsDeleted, false),
  );
  final topXByGroup = {for (final g in groups) g.groupNumber: g.topXAdvance};

  final rows = await LeaderboardModel.storage.getAllModelsWhere(
    where.eq(LeaderboardModel.keyRound, 1).eq(kKeyIsDeleted, false),
  );

  final byGroup = <int, List<LeaderboardModel>>{};
  for (final row in rows) {
    byGroup.putIfAbsent(row.groupNumber, () => []).add(row);
  }

  final advancedByGroup = <String, List<String>>{};
  var advancedTotal = 0;

  for (final entry in byGroup.entries) {
    final groupNumber = entry.key;
    final topX = topXByGroup[groupNumber] ?? 0;
    final ranked = [...entry.value]..sort((a, b) => a.rank.compareTo(b.rank));

    final advancedIds = <String>[];
    for (final row in ranked) {
      final shouldAdvance = row.rank <= topX;
      if (row.advancedToRound2 != shouldAdvance) {
        row
          ..advancedToRound2 = shouldAdvance
          ..updatedAt = DateTime.now().toUtc()
          ..serverUpdatedAt = DateTime.now().toUtc();
        await LeaderboardModel.storage.updateModel(row);
      }
      if (shouldAdvance) advancedIds.add(row.animalId);
    }
    advancedByGroup['$groupNumber'] = advancedIds;
    advancedTotal += advancedIds.length;
  }

  await _markRound1Complete();

  LogService.logInfo(
    '[internal/rounds/advance] advanced $advancedTotal animal(s)',
  );

  return ApiResponseModel.success(
    message: 'Round 1 advancement computed',
    jsonData: {
      'advanced_total': advancedTotal,
      'advanced_by_group': advancedByGroup,
    },
  );
}

Future<void> _markRound1Complete() async {
  final configs = await RoundConfigModel.storage.getAllModelsWhere(
    where.eq(kKeyIsDeleted, false),
  );
  final now = DateTime.now().toUtc();

  if (configs.isEmpty) {
    final model = RoundConfigModel.fromMap({
      kKeyID: newUuid(),
      RoundConfigModel.keyCurrentRound: 2,
      RoundConfigModel.keyRound1Complete: true,
      RoundConfigModel.keyRound2Complete: false,
      kKeyCreatedAt: now.toIso8601String(),
      kKeyUpdatedAt: now.toIso8601String(),
      kKeyServerUpdatedAt: now.toIso8601String(),
      kKeyIsDeleted: false,
    });
    await RoundConfigModel.storage.insertModel(model);
    return;
  }

  final config = configs.first
    ..round1Complete = true
    ..currentRound = 2
    ..updatedAt = now
    ..serverUpdatedAt = now;
  await RoundConfigModel.storage.updateModel(config);
}
