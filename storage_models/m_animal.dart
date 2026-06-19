import 'dart:async';

import 'package:dart_frog/dart_frog.dart';

import '../constants/k.dart';
import '../mixin/mix_mongo_model.dart';
import '../mixin/mix_mongo_storage_model.dart';
import '../services/api_mapper.dart';

/// A competition animal. Master data is imported from / exported to Excel.
///
/// The `_id` is the stable identifier and the upsert key on re-import:
/// re-importing updates existing animals (match on `_id`) and adds new rows.
/// `species` comes from the Excel sheet and is NOT admin-editable (not dynamic).
///
/// Grouping is round-aware. `judge_group` is the Round 1 group (from Excel).
/// For Round 2 the admin re-assigns advanced animals to groups, stored in
/// `super_judge_group` (0 = not yet assigned). Use [groupForRound] to resolve
/// the group for a given round.
class AnimalModel extends MongoFlagDeleteModel<AnimalModel> {
  static const keyAnimalNumber = 'animal_number';
  static const keyFarmerName = 'farmer_name';
  static const keyContactNumber = 'contact_number';
  static const keyProvince = 'province';
  static const keySpecies = 'species';
  static const keyJudgeGroup = 'judge_group';
  static const keySuperJudgeGroup = 'super_judge_group';

  /// Sentinel for "not yet assigned to a Round 2 group".
  static const unassignedGroup = 0;

  static MongoStorageModel<AnimalModel> get storage => MongoStorageModel(
        collectionId: 'animals',
        fromMap: AnimalModel.fromMap,
        createRequiredKeys: [keyAnimalNumber],
        updateRequiredKeys: [],
        isOfflineModel: false,
        // `_id` is supplied by the Excel import (stable upsert key).
        enableServerIdManagement: false,
        flagDeletion: true,
        uuidAsID: false,
      );

  String animalNumber;
  String farmerName;
  String contactNumber;
  String province;
  String species;

  /// Round 1 group (from Excel `judge_group`).
  int judgeGroup;

  /// Round 2 (super judge) group, admin-assigned after advancement.
  /// [unassignedGroup] until the admin places the animal into a Round 2 group.
  int superJudgeGroup;

  AnimalModel({
    required super.id,
    required this.animalNumber,
    required this.farmerName,
    required this.contactNumber,
    required this.province,
    required this.species,
    required this.judgeGroup,
    required this.superJudgeGroup,
    required super.createdAt,
    required super.updatedAt,
    required super.serverUpdatedAt,
    required super.isDeleted,
  });

  /// Resolves the group this animal belongs to for [round].
  /// Round 1 uses [judgeGroup]; Round 2 uses [superJudgeGroup].
  int groupForRound(int round) => round == 2 ? superJudgeGroup : judgeGroup;

  /// Whether the animal has been assigned to a Round 2 (super judge) group.
  bool get hasSuperJudgeGroup => superJudgeGroup != unassignedGroup;

  @override
  FutureOr<Future<Response>?> updateProperties(
    AnimalModel model,
    Map<String, dynamic> map,
  ) {
    if (map.containsKey(keyAnimalNumber)) animalNumber = model.animalNumber;
    if (map.containsKey(keyFarmerName)) farmerName = model.farmerName;
    if (map.containsKey(keyContactNumber)) contactNumber = model.contactNumber;
    if (map.containsKey(keyProvince)) province = model.province;
    if (map.containsKey(keySpecies)) species = model.species;
    if (map.containsKey(keyJudgeGroup)) judgeGroup = model.judgeGroup;
    if (map.containsKey(keySuperJudgeGroup)) superJudgeGroup = model.superJudgeGroup;
    return null;
  }

  factory AnimalModel.fromMap(Map<String, dynamic> map) {
    final m = APIMapper(map);
    return AnimalModel(
      id: m.getString(kKeyID),
      animalNumber: m.getString(keyAnimalNumber),
      farmerName: m.getString(keyFarmerName),
      contactNumber: m.getString(keyContactNumber),
      province: m.getString(keyProvince),
      species: m.getString(keySpecies),
      judgeGroup: m.getInt(keyJudgeGroup),
      superJudgeGroup: m.getInt(keySuperJudgeGroup),
      createdAt: m.getString(kKeyCreatedAt),
      updatedAt: m.getString(kKeyUpdatedAt),
      serverUpdatedAt: m.getString(kKeyServerUpdatedAt),
      isDeleted: m.getBool(kKeyIsDeleted),
    );
  }

  @override
  Map<String, dynamic> toPropertiesMap() => {
        keyAnimalNumber: animalNumber,
        keyFarmerName: farmerName,
        keyContactNumber: contactNumber,
        keyProvince: province,
        keySpecies: species,
        keyJudgeGroup: judgeGroup,
        keySuperJudgeGroup: superJudgeGroup,
      };
}
