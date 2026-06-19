import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import '../../constants/k.dart';
import '../../extensions/e_request_context.dart';
import '../../mixin/mix_mongo_storage_model.dart';
import '../../models/m_api_response.dart';

/// Update a model
Future<Response> handlePatch(
  RequestContext context,
  MongoStorageModel storage,
) async {
  final body = await context.getValidatedBodyMap(
    requiredKeys: [
      kKeyID,
      if (storage.isOfflineModel) kKeyUpdatedAt,
      ...storage.updateRequiredKeys,
    ],
  );

  print(
    'PATCH request for collection: ${storage.collectionId} with body: $body',
  );

  final model = storage.fromMap(body);

  final existingModel = await storage.getModel(model.id);

  if (existingModel == null) {
    return ApiResponseModel.error(
      status: 404,
      'No document in ${storage.collectionId} with id ${model.id} found.',
    ).response();
  }

  // Run a custom pre-update function if it exists
  final onPreUpdateResponse = await model.onPreUpdate(existingModel, body);
  if (onPreUpdateResponse != null) return onPreUpdateResponse;

  // For offline model, don't update if update is older than existing version
  if (storage.isOfflineModel &&
      model.updatedAt.isBefore(existingModel.updatedAt)) {
    return ApiResponseModel(
      message: '${storage.collectionId} not updated. Here is latest model',
      jsonData: existingModel.toMap(),
      status: HttpStatus.alreadyReported,
    ).response();
  }

  // Always set by server
  existingModel.serverUpdatedAt = DateTime.now().toUtc();
  // Update updatedAt (If NOT offline model, server sets updatedAt)
  storage.isOfflineModel
      ? existingModel.updatedAt = model.updatedAt
      : existingModel.updatedAt = existingModel.serverUpdatedAt;

  final updatePropertiesResponse = await existingModel.updateProperties(
    model,
    body,
  );

  if (updatePropertiesResponse != null) return updatePropertiesResponse;

  await existingModel.onUpdate();

  final isSuccess = await storage.updateModel(existingModel);
  print('isSuccess: $isSuccess');

  await existingModel.onUpdateSuccessful();

  if (!isSuccess) {
    return ApiResponseModel(
      message:
          'An unknown error occurred while updating ${storage.collectionId}',
      jsonData: existingModel.toMap(),
      status: 409,
    ).response();
  }
  return ApiResponseModel.success(
    message: '${storage.collectionId} updated',
    jsonData: existingModel.toMap(),
  ).response();
}
