import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';

import '../../constants/k.dart';
import '../../models/m_api_response.dart';
import '../../services/leaderboard_service.dart';
import '../../storage_models/m_animal.dart';
import '../../storage_models/m_leaderboard.dart';

Future<Response> onRequest(RequestContext context, String round) async {
  if (context.request.method != HttpMethod.get) {
    return ApiResponseModel.notImplemented.response();
  }
  return (await _getLeaderboard(round)).response();
}

/// Returns the computed leaderboard for [round], **denormalized**: each row is
/// joined to its animal (adding `animal_number` + `farmer_name`) and carries a
/// `judge_count`. Sorted by group, then rank.
Future<ApiResponseModel> _getLeaderboard(String round) async {
  final roundInt = int.tryParse(round);
  if (roundInt == null) {
    return const ApiResponseModel.badRequestError('Round must be an integer');
  }

  final rows = await LeaderboardModel.storage.getAllModelsWhere(
    where.eq(LeaderboardModel.keyRound, roundInt).eq(kKeyIsDeleted, false),
  );

  if (rows.isEmpty) {
    return ApiResponseModel.success(
      message: 'No leaderboard entries for round $roundInt',
      jsonData: <Map<String, dynamic>>[],
    );
  }

  // Join animal display fields in one query.
  final animalIds = rows.map((r) => r.animalId).toSet().toList();
  final animals = await AnimalModel.storage.getAllModelsWhere(
    where.oneFrom(kKeyID, animalIds),
  );
  final animalById = {for (final a in animals) a.id: a};

  final judgeCounts = await LeaderboardService.judgeCountByAnimal(roundInt);

  final sorted = [...rows]
    ..sort((a, b) {
      final byGroup = a.groupNumber.compareTo(b.groupNumber);
      return byGroup != 0 ? byGroup : a.rank.compareTo(b.rank);
    });

  final data = sorted.map((row) {
    final animal = animalById[row.animalId];
    return {
      LeaderboardModel.keyRound: row.round,
      LeaderboardModel.keyGroupNumber: row.groupNumber,
      LeaderboardModel.keyAnimalId: row.animalId,
      LeaderboardModel.keyAverageScore: row.averageScore,
      LeaderboardModel.keyRank: row.rank,
      LeaderboardModel.keyAdvancedToRound2: row.advancedToRound2,
      AnimalModel.keyAnimalNumber: animal?.animalNumber ?? '',
      AnimalModel.keyFarmerName: animal?.farmerName ?? '',
      'judge_count': judgeCounts[row.animalId] ?? 0,
    };
  }).toList();

  return ApiResponseModel.success(
    message: 'Leaderboard for round $roundInt',
    jsonData: data,
  );
}
