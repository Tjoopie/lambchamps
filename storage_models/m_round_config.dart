import 'dart:async';

import 'package:dart_frog/dart_frog.dart';

import '../constants/k.dart';
import '../mixin/mix_mongo_model.dart';
import '../mixin/mix_mongo_storage_model.dart';
import '../services/api_mapper.dart';

/// Competition-wide round state. A single document for the single competition.
///
/// `round1Complete` is set once every assigned judge's Round 1 QR has been
/// ingested; advancement (top-X per group) can then be computed and Round 2
/// opened for super judges.
class RoundConfigModel extends MongoFlagDeleteModel<RoundConfigModel> {
  static const keyCurrentRound = 'current_round';
  static const keyRound1Complete = 'round_1_complete';
  static const keyRound2Complete = 'round_2_complete';

  static MongoStorageModel<RoundConfigModel> get storage => MongoStorageModel(
        collectionId: 'round_config',
        fromMap: RoundConfigModel.fromMap,
        createRequiredKeys: [],
        updateRequiredKeys: [],
        isOfflineModel: false,
        enableServerIdManagement: true,
        flagDeletion: true,
        uuidAsID: true,
      );

  int currentRound;
  bool round1Complete;
  bool round2Complete;

  RoundConfigModel({
    required super.id,
    required this.currentRound,
    required this.round1Complete,
    required this.round2Complete,
    required super.createdAt,
    required super.updatedAt,
    required super.serverUpdatedAt,
    required super.isDeleted,
  });

  @override
  FutureOr<Future<Response>?> updateProperties(
    RoundConfigModel model,
    Map<String, dynamic> map,
  ) {
    if (map.containsKey(keyCurrentRound)) currentRound = model.currentRound;
    if (map.containsKey(keyRound1Complete)) {
      round1Complete = model.round1Complete;
    }
    if (map.containsKey(keyRound2Complete)) {
      round2Complete = model.round2Complete;
    }
    return null;
  }

  factory RoundConfigModel.fromMap(Map<String, dynamic> map) {
    final m = APIMapper(map);
    return RoundConfigModel(
      id: m.getString(kKeyID),
      currentRound: m.getInt(keyCurrentRound, 1),
      round1Complete: m.getBool(keyRound1Complete),
      round2Complete: m.getBool(keyRound2Complete),
      createdAt: m.getString(kKeyCreatedAt),
      updatedAt: m.getString(kKeyUpdatedAt),
      serverUpdatedAt: m.getString(kKeyServerUpdatedAt),
      isDeleted: m.getBool(kKeyIsDeleted),
    );
  }

  @override
  Map<String, dynamic> toPropertiesMap() => {
        keyCurrentRound: currentRound,
        keyRound1Complete: round1Complete,
        keyRound2Complete: round2Complete,
      };
}
