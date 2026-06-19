import 'dart:async';

import 'package:dart_frog/dart_frog.dart';

import '../constants/k.dart';
import '../mixin/mix_mongo_model.dart';
import '../mixin/mix_mongo_storage_model.dart';
import '../services/api_mapper.dart';

/// A single weighted attribute within a judging category.
///
/// Score range is 0..[maxScore]. [weight] is the relative weight used in the
/// weighted average. [id] is a stable attribute identifier: QR submissions key
/// their raw scores by this id (the `s` map / `attribute_scores`), so scores
/// are matched by id, NOT by position. It must persist and round-trip
/// unchanged.
class SubAttribute {
  static const keyId = 'id';
  static const keyName = 'name';
  static const keyMaxScore = 'max_score';
  static const keyWeight = 'weight';

  String id;
  String name;
  int maxScore;
  double weight;

  SubAttribute({
    required this.id,
    required this.name,
    required this.maxScore,
    required this.weight,
  });

  factory SubAttribute.fromMap(Map<String, dynamic> map) {
    final m = APIMapper(map);
    return SubAttribute(
      id: m.getString(keyId),
      name: m.getString(keyName),
      maxScore: m.getInt(keyMaxScore),
      weight: m.getDouble(keyWeight, 1),
    );
  }

  Map<String, dynamic> toMap() => {
        keyId: id,
        keyName: name,
        keyMaxScore: maxScore,
        keyWeight: weight,
      };
}

/// Admin-defined, dynamic judging criteria.
///
/// A category (e.g. "Conformation") holds an ordered list of weighted
/// sub-attributes. Categories/attributes/weights/max-scores are all dynamic.
/// Criteria are **shared across both rounds** — there is no `round` dimension;
/// Round 1 judges and Round 2 super judges score against the same set.
///
/// Each category is **species-specific** via [species] (matches `animals.species`)
/// — the judging UI shows only the categories whose `species` matches the animal
/// being judged. An empty [species] means it is not yet scoped to a species.
class JudgingCriteriaModel extends MongoFlagDeleteModel<JudgingCriteriaModel> {
  static const keyMainCategory = 'main_category';
  static const keySpecies = 'species';
  static const keySubAttributes = 'sub_attributes';
  static const keyOrder = 'order';

  static MongoStorageModel<JudgingCriteriaModel> get storage =>
      MongoStorageModel(
        collectionId: 'judging_criteria',
        fromMap: JudgingCriteriaModel.fromMap,
        createRequiredKeys: [keyMainCategory],
        updateRequiredKeys: [],
        isOfflineModel: false,
        enableServerIdManagement: true,
        flagDeletion: true,
        uuidAsID: true,
      );

  String mainCategory;

  /// Species this category applies to (matches `animals.species`). Empty when
  /// not yet scoped to a species.
  String species;

  /// Display/processing order of this category relative to others.
  int order;

  List<SubAttribute> subAttributes;

  JudgingCriteriaModel({
    required super.id,
    required this.mainCategory,
    required this.species,
    required this.order,
    required this.subAttributes,
    required super.createdAt,
    required super.updatedAt,
    required super.serverUpdatedAt,
    required super.isDeleted,
  });

  @override
  FutureOr<Future<Response>?> updateProperties(
    JudgingCriteriaModel model,
    Map<String, dynamic> map,
  ) {
    if (map.containsKey(keyMainCategory)) mainCategory = model.mainCategory;
    if (map.containsKey(keySpecies)) species = model.species;
    if (map.containsKey(keyOrder)) order = model.order;
    if (map.containsKey(keySubAttributes)) subAttributes = model.subAttributes;
    return null;
  }

  factory JudgingCriteriaModel.fromMap(Map<String, dynamic> map) {
    final m = APIMapper(map);
    return JudgingCriteriaModel(
      id: m.getString(kKeyID),
      mainCategory: m.getString(keyMainCategory),
      species: m.getString(keySpecies),
      order: m.getInt(keyOrder),
      subAttributes: m.getCustomList(
        keySubAttributes,
        fromMap: SubAttribute.fromMap,
      ),
      createdAt: m.getString(kKeyCreatedAt),
      updatedAt: m.getString(kKeyUpdatedAt),
      serverUpdatedAt: m.getString(kKeyServerUpdatedAt),
      isDeleted: m.getBool(kKeyIsDeleted),
    );
  }

  @override
  Map<String, dynamic> toPropertiesMap() => {
        keyMainCategory: mainCategory,
        keySpecies: species,
        keyOrder: order,
        keySubAttributes: subAttributes.map((e) => e.toMap()).toList(),
      };
}
