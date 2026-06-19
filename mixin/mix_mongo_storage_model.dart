import 'dart:async';

import 'package:uuid/uuid.dart';

import '../constants/k.dart';
import '../extensions/e_string.dart';
import '../storage/mongo_storage.dart';
import 'mix_mongo_model.dart';

class MongoStorageModel<T extends MongoModel<T>> {
  MongoStorageModel({
    required this.collectionId,
    required this.fromMap,
    required this.createRequiredKeys,
    required this.updateRequiredKeys,
    required this.isOfflineModel,
    required this.flagDeletion,
    required this.enableServerIdManagement,
    required this.uuidAsID,
  });

  /// The id of the collection (Think of it as table name)
  String collectionId;

  /// List of keys that are required to create a model. Requests are filtered
  /// by this list
  List<String> createRequiredKeys;

  /// List of keys that are required to update a model. Requests are filtered
  /// by this list.
  List<String> updateRequiredKeys;

  /// Function used to convert map into a model
  T Function(Map<String, dynamic> map) fromMap;

  /// Whether this model will support offline functionality in mobile apps. In
  /// both cases the serverUpdateTime will be set.
  /// - TRUE -> The server WILL NOT update/set the updateTime or the createTime
  /// but rather allows the mobile users to do so.
  /// - FALSE -> The server WILL update/set the updateTime or the creationTime,
  /// NOT the mobile users.
  final bool isOfflineModel;

  /// NOTE: If [T] is [MongoFlagDeleteModel] then this should be true, otherwise
  /// false.
  ///
  /// Whether the models will be removed from database or simply flagged as
  /// deleted.
  /// - TRUE -> The object will NOT be deleted from the database, but rather
  /// the model's [MongoFlagDeleteModel.isDeleted] flag will be set to true.
  /// - FALSE -> The object will be deleted from the database.
  bool flagDeletion;

  /// This bool is used to determine whether the server will manage the id of
  /// the model or whether the client will manage the id of the model.
  /// - TRUE -> The server will set the id of the model, assigning a UUID.
  /// - FALSE -> The client will manage the id of the model.
  final bool enableServerIdManagement;

  /// - TRUE -> The id of the model will be a UUID.
  /// - FALSE -> The id of the model will be a unique string.
  final bool uuidAsID;

  /// Converts model id to MongoDB id (String or UUID, depending on [uuidAsID]).
  dynamic toMongoID(String id) {
    if (uuidAsID) {
      // Handle temporary IDs (e.g., temp_<uuid>)
      if (id.startsWith('temp_')) {
        final uuidPart = id.substring(5);
        return uuidPart.uuidToBsonBinary();
      }
      return id.uuidToBsonBinary();
    }
    return id;
  }

  /// Converts MongoDB id (String or UUID, depending on [uuidAsID]) to model id.
  String _fromMongoID(dynamic id) {
    if (id is BsonBinary) return Uuid.unparse(id.byteList);
    if (id is UuidValue) return id.uuid;
    return id.toString();
  }

  /// Converts object to MongoDB map (converts id).
  Map<String, dynamic> _objectToMongoMap(T object) {
    final map = object.toMap();
    if (uuidAsID) map[kKeyID] = toMongoID(map[kKeyID] as String);
    return map;
  }

  /// Converts MongoDB map to object (converts id).
  T _fromMongoMap(Map<String, dynamic> map) {
    map[kKeyID] = _fromMongoID(map[kKeyID]);
    return fromMap(map);
  }

  /// Get a single document from a collection using the ID.
  Future<T?> getModel(String id) => MongoStorage.instance.use((db) async {
        final result = await db
            .collection(collectionId)
            .findOne(where.eq(kKeyID, toMongoID(id)));
        return result == null ? null : _fromMongoMap(result);
      });

  /// Get all documents from collection
  Future<List<T>> getAllModels() => MongoStorage.instance.use(
        (db) => db.collection(collectionId).find().map(_fromMongoMap).toList(),
      );

  /// Create a new document in a collection
  Future<T?> insertModel(T model) => MongoStorage.instance.use((db) async {
        final result = await db
            .collection(collectionId)
            .insertOne(_objectToMongoMap(model));

        return result.document == null
            ? null
            : _fromMongoMap(result.document!);
      });

  /// Update a model in a collection
  Future<bool> updateModel(T model) async {
    try {
      return await MongoStorage.instance.use((db) async {
        final result = await db.collection(collectionId).replaceOne(
              where.eq(kKeyID, toMongoID(model.id)),
              _objectToMongoMap(model),
            );
        return result.isSuccess;
      });
    } catch (e) {
      print('Update failed: $e');
      return false;
    }
  }

  /// Update a single field on a model in a collection
  Future<bool> updateModelValue({
    required T model,
    required String field,
    required dynamic value,
  }) =>
      MongoStorage.instance.use((db) async {
        final result = await db.collection(collectionId).updateOne(
              where.eq(kKeyID, toMongoID(model.id)),
              modify.set(field, value),
            );
        return result.isSuccess;
      });

  /// Update a model in a collection with a custom modifier
  Future<bool> updateModelValues({
    required T model,
    required ModifierBuilder modifier,
  }) =>
      MongoStorage.instance.use((db) async {
        final result = await db
            .collection(collectionId)
            .updateOne(where.eq(kKeyID, toMongoID(model.id)), modifier);
        return result.isSuccess;
      });

  /// (CAUTION: USE CAREFULLY) Update multiple models in a collection
  Future<bool> updateManyModelValues({
    required SelectorBuilder selector,
    required ModifierBuilder modifier,
    List<dynamic>? arrayFilters,
  }) =>
      MongoStorage.instance.use((db) async {
        final result = await db
            .collection(collectionId)
            .updateMany(selector, modifier, arrayFilters: arrayFilters);
        return result.isSuccess;
      });

  /// Delete a model from a collection
  Future<bool> deleteModel(String id) =>
      MongoStorage.instance.use((db) async {
        final result = await db.collection(collectionId).deleteOne({
          kKeyID: toMongoID(id),
        });
        return result.isSuccess;
      });

  /// Query data from collection based on supplied filters
  Future<List<T>> getAllModelsWhere(
    SelectorBuilder whereBuilder, {
    int timeoutSeconds = MongoStorage.defaultUseTimeoutSeconds,
  }) =>
      MongoStorage.instance.use(
        initialTimeoutSeconds: timeoutSeconds,
        (db) => db
            .collection(collectionId)
            .modernFind(selector: whereBuilder, findOptions: FindOptions())
            .map(_fromMongoMap)
            .toList(),
      );

  /// Count documents matching the supplied filters
  Future<int> getCount(SelectorBuilder whereBuilder) => MongoStorage.instance
      .use((db) => db.collection(collectionId).count(whereBuilder));

  /// Get distinct values for a field matching the supplied filters
  Future<Map<String, dynamic>> getDistinctFieldWhere(
    String field,
    SelectorBuilder whereBuilder,
  ) =>
      MongoStorage.instance.use(
        (db) => db.collection(collectionId).distinct(field, whereBuilder),
      );

  /// Get a single model matching the supplied filters
  Future<T?> getModelWhere(SelectorBuilder whereBuilder) =>
      MongoStorage.instance.use((db) async {
        final result = await db.collection(collectionId).findOne(whereBuilder);
        return result == null ? null : _fromMongoMap(result);
      });

  Future<S> use<S>(Future<S> Function(DbCollection collection) function) =>
      MongoStorage.instance.use((db) => function(db.collection(collectionId)));

  /// Aggregate data from collection based on supplied pipeline
  Future<List<Map<String, dynamic>>> aggregate(
    List<Map<String, Object>> pipeline,
  ) =>
      MongoStorage.instance.use(
        (db) =>
            db.collection(collectionId).aggregateToStream(pipeline).toList(),
      );
}
