import 'dart:async';

import 'package:dart_frog/dart_frog.dart';

import '../constants/k.dart';

/// Extension of [MongoModel] that includes a flag for deletion.
///
/// Use this instead of [MongoModel] when you don't want to delete the data
/// from the database, but rather just flag it as deleted.
abstract class MongoFlagDeleteModel<T> extends MongoModel<T> {
  MongoFlagDeleteModel({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required super.serverUpdatedAt,
    required this.isDeleted,
  });

  bool isDeleted;

  @override
  Map<String, dynamic> toMap() => super.toMap()..[kKeyIsDeleted] = isDeleted;
}

/// Abstract class for models that are stored in MongoDB.
abstract class MongoModel<T> {
  /// [createdAt]: see [MongoModel.createdAt].
  /// [updatedAt]: see [MongoModel.updatedAt].
  /// [serverUpdatedAt]: see [MongoModel.serverUpdatedAt].
  MongoModel({
    required this.id,
    required String createdAt,
    required String updatedAt,
    required String serverUpdatedAt,
  })  : createdAt = (DateTime.tryParse(createdAt) ?? kDefaultDate).toUtc(),
        updatedAt = (DateTime.tryParse(updatedAt) ??
                DateTime.tryParse(createdAt) ??
                kDefaultDate)
            .toUtc(),
        serverUpdatedAt =
            (DateTime.tryParse(serverUpdatedAt) ?? kDefaultDate).toUtc();

  /// UUID or a string that represents the unique identifier of the model.
  String id;

  /// When created (if offline model from device, else server).
  DateTime createdAt;

  /// When last updated (if offline model from device, else server).
  DateTime updatedAt;

  /// When last updated on the server.
  DateTime serverUpdatedAt;

  /// Should return a map of all the properties (variables) of the model,
  /// excluding those in [MongoModel] or [MongoFlagDeleteModel]:
  /// - [id]
  /// - [createdAt]
  /// - [updatedAt]
  /// - [serverUpdatedAt]
  /// - [MongoFlagDeleteModel.isDeleted]
  Map<String, dynamic> toPropertiesMap();

  /// Returns a map of all the properties (variables) of the model, including
  /// those in [MongoModel] or [MongoFlagDeleteModel]
  Map<String, dynamic> toMap() => toPropertiesMap()
    ..[kKeyID] = id
    ..[kKeyUpdatedAt] = updatedAt.toIso8601String()
    ..[kKeyServerUpdatedAt] = serverUpdatedAt.toIso8601String()
    ..[kKeyCreatedAt] = createdAt.toIso8601String();

  /// Custom code to run before creating the model.
  FutureOr<Future<Response>?> onPreCreate() => null;

  /// Custom code to run after creating the model successfully.
  ///
  /// NOTE: This runs on the inserted model, not on the model received from
  /// Mongo after insertion. This allows for the model to preserve a variable
  /// through-out the process of inserting.
  FutureOr<void> onCreateSuccessful() {}

  /// Custom code to run before updating the model.
  FutureOr<Future<Response>?> onPreUpdate(
    T mongoModel,
    Map<String, dynamic> map,
  ) =>
      null;

  /// Method to copy over the properties of a model to existing model.
  FutureOr<Future<Response>?> updateProperties(
    T model,
    Map<String, dynamic> map,
  );

  /// Custom code to run when the model is updated.
  FutureOr<void> onUpdate() => null;

  /// Custom code to run after updating the model successfully.
  ///
  /// NOTE: This runs on the inserted model, not on the model received from
  /// Mongo after insertion. This allows for the model to preserve a variable
  /// through-out the process of inserting.
  FutureOr<void> onUpdateSuccessful() {}

  /// Custom code to run before deleting the model.
  FutureOr<void> onPreDelete() {}

  /// Custom headers to add to response.
  Future<Map<String, String>> getPostAddedHeaders() async => {};

  void updateUpdateDates() {
    final now = DateTime.now().toUtc();
    updatedAt = now;
    serverUpdatedAt = now;
  }
}
