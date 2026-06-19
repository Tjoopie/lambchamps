import 'package:mongo_dart/mongo_dart.dart';

import '../constants/k.dart';
import '../storage_models/m_judging_criteria.dart';
import '../storage_models/m_judging_result.dart';
import '../storage_models/m_leaderboard.dart';

/// Server-side scoring + leaderboard computation.
///
/// Implements the weighted-average formula from the spec (§4.4):
///
///   `weighted_total = Σ (score_i / max_score_i * weight_i) / Σ weight_i`
///
/// matching scores to attributes **by id**, and recomputes [LeaderboardModel]
/// rows (per-animal average + rank within group) for a round/group.
class LeaderboardService {
  LeaderboardService._();

  /// All sub-attributes (shared across rounds), keyed by their stable `id`.
  static Future<Map<String, SubAttribute>> loadAttributes() async {
    final categories = await JudgingCriteriaModel.storage.getAllModelsWhere(
      where.eq(kKeyIsDeleted, false),
    );
    final byId = <String, SubAttribute>{};
    for (final category in categories) {
      for (final attr in category.subAttributes) {
        if (attr.id.isNotEmpty) byId[attr.id] = attr;
      }
    }
    return byId;
  }

  /// Weighted total for one animal/judge from raw [attributeScores]
  /// (`attributeId -> rawScore`) against the round's [attributes].
  ///
  /// Only attributes present in both the scores and the criteria contribute.
  /// Returns a normalised value in `0..1` (0 when no weights apply).
  static double computeWeightedTotal(
    Map<String, dynamic> attributeScores,
    Map<String, SubAttribute> attributes,
  ) {
    var weightedSum = 0.0;
    var weightSum = 0.0;
    for (final entry in attributeScores.entries) {
      final attr = attributes[entry.key];
      if (attr == null || attr.maxScore <= 0 || attr.weight <= 0) continue;
      final raw = double.tryParse(entry.value.toString());
      if (raw == null) continue;
      weightedSum += (raw / attr.maxScore) * attr.weight;
      weightSum += attr.weight;
    }
    if (weightSum <= 0) return 0;
    return weightedSum / weightSum;
  }

  /// Recomputes leaderboard rows for every group that has results in [round].
  static Future<void> recomputeRound(int round) async {
    final results = await JudgingResultModel.storage.getAllModelsWhere(
      where.eq(JudgingResultModel.keyRound, round).eq(kKeyIsDeleted, false),
    );
    final groups = results.map((r) => r.groupNumber).toSet();
    for (final group in groups) {
      await recomputeRoundGroup(round, group);
    }
  }

  /// Recomputes leaderboard rows for one [round]/[groupNumber] from the stored
  /// [JudgingResultModel] documents. Averages each animal's `weighted_total`
  /// across judges, ranks within the group, and upserts [LeaderboardModel]
  /// rows (preserving any existing `advanced_to_round_2` flag).
  static Future<void> recomputeRoundGroup(int round, int groupNumber) async {
    final results = await JudgingResultModel.storage.getAllModelsWhere(
      where
          .eq(JudgingResultModel.keyRound, round)
          .eq(JudgingResultModel.keyGroupNumber, groupNumber)
          .eq(kKeyIsDeleted, false),
    );

    // animalId -> list of weighted totals (one per judge).
    final byAnimal = <String, List<double>>{};
    for (final r in results) {
      byAnimal.putIfAbsent(r.animalId, () => []).add(r.weightedTotal);
    }

    // Average per animal, then rank descending.
    final averages = byAnimal.entries
        .map((e) => (animalId: e.key, avg: e.value.reduce((a, b) => a + b) / e.value.length))
        .toList()
      ..sort((a, b) => b.avg.compareTo(a.avg));

    final existing = await LeaderboardModel.storage.getAllModelsWhere(
      where
          .eq(LeaderboardModel.keyRound, round)
          .eq(LeaderboardModel.keyGroupNumber, groupNumber)
          .eq(kKeyIsDeleted, false),
    );
    final existingByAnimal = {for (final l in existing) l.animalId: l};

    for (var i = 0; i < averages.length; i++) {
      final entry = averages[i];
      final rank = i + 1;
      final current = existingByAnimal[entry.animalId];
      if (current != null) {
        current
          ..averageScore = entry.avg
          ..rank = rank
          ..updatedAt = DateTime.now().toUtc()
          ..serverUpdatedAt = DateTime.now().toUtc();
        await LeaderboardModel.storage.updateModel(current);
      } else {
        final now = DateTime.now().toUtc();
        final model = LeaderboardModel.fromMap({
          kKeyID: newUuid(),
          LeaderboardModel.keyRound: round,
          LeaderboardModel.keyGroupNumber: groupNumber,
          LeaderboardModel.keyAnimalId: entry.animalId,
          LeaderboardModel.keyAverageScore: entry.avg,
          LeaderboardModel.keyRank: rank,
          LeaderboardModel.keyAdvancedToRound2: false,
          kKeyCreatedAt: now.toIso8601String(),
          kKeyUpdatedAt: now.toIso8601String(),
          kKeyServerUpdatedAt: now.toIso8601String(),
          kKeyIsDeleted: false,
        });
        await LeaderboardModel.storage.insertModel(model);
      }
    }
  }

  /// Number of distinct judges that contributed a result per animal in [round].
  static Future<Map<String, int>> judgeCountByAnimal(int round) async {
    final results = await JudgingResultModel.storage.getAllModelsWhere(
      where.eq(JudgingResultModel.keyRound, round).eq(kKeyIsDeleted, false),
    );
    final byAnimal = <String, Set<String>>{};
    for (final r in results) {
      byAnimal.putIfAbsent(r.animalId, () => <String>{}).add(r.judgeUserId);
    }
    return byAnimal.map((k, v) => MapEntry(k, v.length));
  }
}
