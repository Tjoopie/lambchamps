import 'package:dart_frog/dart_frog.dart';
import 'package:uuid/uuid.dart';

import '../../constants/k.dart';
import '../../extensions/e_request_context.dart';
import '../../mixin/mix_mongo_storage_model.dart';
import '../../models/m_api_response.dart';

/// Create a new model and store it.
/// Summary is:
/// - Get body from request and parse to client.
/// - Ensure all required keys are supplied.
/// - Create a model from the body.
/// - Store the model in the database.
Future<Response> handlePost(
  RequestContext context,
  MongoStorageModel storage,
) async {
  final body = await context.getValidatedBodyMap(
    requiredKeys: [
      if (!storage.enableServerIdManagement) kKeyID,
      if (storage.isOfflineModel) kKeyUpdatedAt,
      if (storage.isOfflineModel) kKeyCreatedAt,
      ...storage.createRequiredKeys,
    ],
  );

  print('POST request for ${storage.collectionId} with body: $body');

  final model = storage.fromMap(body);

  // If id is managed by the server, generate a new id
  if (storage.enableServerIdManagement) {
    final newId = storage.uuidAsID
        ? const Uuid().v4()
        : DateTime.now().millisecondsSinceEpoch.toString();
    model.id = newId;
  }

  // If id is managed by the client, ensure that it is unique
  if (!storage.enableServerIdManagement) {
    final existingModel = await storage.getModel(model.id);
    if (existingModel != null) {
      return ApiResponseModel(
        message: 'This id already exists for ${storage.collectionId}.',
        jsonData: existingModel.toMap(),
        status: 208,
      ).response();
    }
  }

  // Run a custom pre-create function if it exists
  final onPreCreateResponse = await model.onPreCreate();
  if (onPreCreateResponse != null) return onPreCreateResponse;

  // Always set by server
  model.serverUpdatedAt = DateTime.now().toUtc();

  // If NOT offline model, server sets createdAt & updatedAt
  if (!storage.isOfflineModel) {
    model
      ..createdAt = model.serverUpdatedAt
      ..updatedAt = model.serverUpdatedAt;
  }

  final savedModel = await storage.insertModel(model);

  if (savedModel == null) {
    return ApiResponseModel(
      message: 'Failed to add ${storage.collectionId}',
      jsonData: null,
      status: 500,
    ).response();
  }

  // This must run on the inserted model, not the model received from Mongo
  await model.onCreateSuccessful();

  final headers = await model.getPostAddedHeaders();

  return ApiResponseModel.success(
    message: '${storage.collectionId} added',
    addedHeaders: headers,
    jsonData: savedModel.toMap(),
  ).response();
}
