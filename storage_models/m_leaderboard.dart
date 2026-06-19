import 'dart:async';

import 'package:dart_frog/dart_frog.dart';

import '../constants/k.dart';
import '../mixin/mix_mongo_model.dart';
import '../mixin/mix_mongo_storage_model.dart';
import '../services/api_mapper.dart';

/// A computed leaderboard entry for one animal, in one round, within one group.
///
/// Recomputed cloud-side after each QR ingest. `averageScore` is the mean of all
/// judges' weighted totals for that animal in the round; `rank` is the position
/// within the group; `advancedToRound2` is set once Round 1 advancement (top-X
/// per group) has been computed.
class LeaderboardModel extends MongoFlagDeleteModel<LeaderboardModel> {
  static const keyRound = 'round';
  static const keyGroupNumber = 'group_number';
  static const keyAnimalId = 'animal_id';
  static const keyAverageScore = 'average_score';
  static const keyRank = 'rank';
  static const keyAdvancedToRound2 = 'advanced_to_round_2';

  static MongoStorageModel<LeaderboardModel> get storage => MongoStorageModel(
        collectionId: 'leaderboards',
        fromMap: LeaderboardModel.fromMap,
        createRequiredKeys: [keyRound, keyGroupNumber, keyAnimalId],
        updateRequiredKeys: [],
        isOfflineModel: false,
        enableServerIdManagement: true,
        flagDeletion: true,
        uuidAsID: true,
      );

  int round;
  int groupNumber;
  String animalId;
  double averageScore;
  int rank;
  bool advancedToRound2;

  LeaderboardModel({
    required super.id,
    required this.round,
    required this.groupNumber,
    required this.animalId,
    required this.averageScore,
    required this.rank,
    required this.advancedToRound2,
    required super.createdAt,
    required super.updatedAt,
    required super.serverUpdatedAt,
    required super.isDeleted,
  });

  @override
  FutureOr<Future<Response>?> updateProperties(
    LeaderboardModel model,
    Map<String, dynamic> map,
  ) {
    if (map.containsKey(keyRound)) round = model.round;
    if (map.containsKey(keyGroupNumber)) groupNumber = model.groupNumber;
    if (map.containsKey(keyAnimalId)) animalId = model.animalId;
    if (map.containsKey(keyAverageScore)) averageScore = model.averageScore;
    if (map.containsKey(keyRank)) rank = model.rank;
    if (map.containsKey(keyAdvancedToRound2)) {
      advancedToRound2 = model.advancedToRound2;
    }
    return null;
  }

  factory LeaderboardModel.fromMap(Map<String, dynamic> map) {
    final m = APIMapper(map);
    return LeaderboardModel(
      id: m.getString(kKeyID),
      round: m.getInt(keyRound, 1),
      groupNumber: m.getInt(keyGroupNumber),
      animalId: m.getString(keyAnimalId),
      averageScore: m.getDouble(keyAverageScore),
      rank: m.getInt(keyRank),
      advancedToRound2: m.getBool(keyAdvancedToRound2),
      createdAt: m.getString(kKeyCreatedAt),
      updatedAt: m.getString(kKeyUpdatedAt),
      serverUpdatedAt: m.getString(kKeyServerUpdatedAt),
      isDeleted: m.getBool(kKeyIsDeleted),
    );
  }

  @override
  Map<String, dynamic> toPropertiesMap() => {
        keyRound: round,
        keyGroupNumber: groupNumber,
        keyAnimalId: animalId,
        keyAverageScore: averageScore,
        keyRank: rank,
        keyAdvancedToRound2: advancedToRound2,
      };
}
