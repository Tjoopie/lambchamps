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

/// DEPRECATED / optional (spec §9.9c): advancement is now driven client-side.
/// The Flutter app computes top-X per Round 1 group, ensures a `round2_groups`
/// "Group 1" exists, sets `super_judge_group = 1` on advancing animals, and
/// assigns super judges to that group. This endpoint is retained only as a
/// server-side convenience and is NOT relied upon by the live flow.
///
/// Computes Round 1 → Round 2 advancement (top-X per group).
///
/// Recomputes Round 1 leaderboards, then for each group marks the top
/// `top_x_advance` animals (by rank) as `advanced_to_round_2`, and flips
/// `round_config` (`round_1_complete = true`, `current_round = 2`).
///
/// NOTE: Round 2 grouping is admin-defined and independent of Round 1 (spec
/// §3.3), so this endpoint does NOT auto-assign `super_judge_group` — the admin
/// places advanced animals into Round 2 groups in-app afterwards.
Future<ApiResponseModel> _advance(RequestContext context) async {
  // Ensure ranks reflect all ingested results.
  await LeaderboardService.recomputeRound(1);

  final groups = await GroupModel.storage.getAllModelsWhere(
    where.eq(kKeyIsDeleted, false),
  );
  final topXByGroup = {for (final g in groups) g.groupNumber: g.topXAdvance};

  final rows = await LeaderboardModel.storage.getAllModelsWhere(
    where.eq(LeaderboardModel.keyRound, 1).eq(kKeyIsDeleted, false),
  );

  // Group leaderboard rows by group number.
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
    '[admin/rounds/advance] advanced $advancedTotal animal(s) across '
    '${byGroup.length} group(s)',
  );

  return ApiResponseModel.success(
    message: 'Round 1 advancement computed',
    jsonData: {
      'advanced_total': advancedTotal,
      'advanced_by_group': advancedByGroup,
      'note': 'Assign super_judge_group per advanced animal in-app for Round 2.',
    },
  );
}

/// Flips the single `round_config` doc to Round 2 (creating it if absent).
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
