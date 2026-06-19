import 'dart:async';

import 'package:dart_frog/dart_frog.dart';

import '../constants/k.dart';
import '../mixin/mix_mongo_model.dart';
import '../mixin/mix_mongo_storage_model.dart';
import '../services/api_mapper.dart';

/// One judge's score for one animal in one round.
///
/// Results are NOT written by judge devices. They are created server-side when
/// an admin ingests a judge's QR submission (one document per animal). The
/// `weightedTotal` is computed server-side from `attributeScores` + the criteria
/// snapshot. `qrBatchId` is shared across all animals from the same QR scan.
class JudgingResultModel extends MongoFlagDeleteModel<JudgingResultModel> {
  static const keyJudgeUserId = 'judge_user_id';
  static const keyAnimalId = 'animal_id';
  static const keyGroupNumber = 'group_number';
  static const keyRound = 'round';
  static const keyAttributeScores = 'attribute_scores';
  static const keyWeightedTotal = 'weighted_total';
  static const keySubmittedAt = 'submitted_at';
  static const keyQrBatchId = 'qr_batch_id';

  static MongoStorageModel<JudgingResultModel> get storage =>
      MongoStorageModel(
        collectionId: 'judging_results',
        fromMap: JudgingResultModel.fromMap,
        createRequiredKeys: [keyJudgeUserId, keyAnimalId, keyRound],
        updateRequiredKeys: [],
        isOfflineModel: false,
        enableServerIdManagement: true,
        flagDeletion: true,
        uuidAsID: true,
      );

  String judgeUserId;
  String animalId;
  int groupNumber;
  int round;

  /// Map of attribute id/name -> raw score.
  Map<String, dynamic> attributeScores;

  /// Computed server-side on ingest.
  double weightedTotal;

  /// From the QR `scored_at`.
  DateTime submittedAt;

  /// Shared across all animals from the same QR submission.
  String qrBatchId;

  JudgingResultModel({
    required super.id,
    required this.judgeUserId,
    required this.animalId,
    required this.groupNumber,
    required this.round,
    required this.attributeScores,
    required this.weightedTotal,
    required this.submittedAt,
    required this.qrBatchId,
    required super.createdAt,
    required super.updatedAt,
    required super.serverUpdatedAt,
    required super.isDeleted,
  });

  @override
  FutureOr<Future<Response>?> updateProperties(
    JudgingResultModel model,
    Map<String, dynamic> map,
  ) {
    if (map.containsKey(keyJudgeUserId)) judgeUserId = model.judgeUserId;
    if (map.containsKey(keyAnimalId)) animalId = model.animalId;
    if (map.containsKey(keyGroupNumber)) groupNumber = model.groupNumber;
    if (map.containsKey(keyRound)) round = model.round;
    if (map.containsKey(keyAttributeScores)) {
      attributeScores = model.attributeScores;
    }
    if (map.containsKey(keyWeightedTotal)) weightedTotal = model.weightedTotal;
    if (map.containsKey(keySubmittedAt)) submittedAt = model.submittedAt;
    if (map.containsKey(keyQrBatchId)) qrBatchId = model.qrBatchId;
    return null;
  }

  factory JudgingResultModel.fromMap(Map<String, dynamic> map) {
    final m = APIMapper(map);
    return JudgingResultModel(
      id: m.getString(kKeyID),
      judgeUserId: m.getString(keyJudgeUserId),
      animalId: m.getString(keyAnimalId),
      groupNumber: m.getInt(keyGroupNumber),
      round: m.getInt(keyRound, 1),
      attributeScores: m.getMap(keyAttributeScores),
      weightedTotal: m.getDouble(keyWeightedTotal),
      submittedAt: m.getDateTime(keySubmittedAt),
      qrBatchId: m.getString(keyQrBatchId),
      createdAt: m.getString(kKeyCreatedAt),
      updatedAt: m.getString(kKeyUpdatedAt),
      serverUpdatedAt: m.getString(kKeyServerUpdatedAt),
      isDeleted: m.getBool(kKeyIsDeleted),
    );
  }

  @override
  Map<String, dynamic> toPropertiesMap() => {
        keyJudgeUserId: judgeUserId,
        keyAnimalId: animalId,
        keyGroupNumber: groupNumber,
        keyRound: round,
        keyAttributeScores: attributeScores,
        keyWeightedTotal: weightedTotal,
        keySubmittedAt: submittedAt.toIso8601String(),
        keyQrBatchId: qrBatchId,
      };
}
