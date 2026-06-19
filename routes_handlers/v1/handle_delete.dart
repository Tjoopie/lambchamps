import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import '../../constants/k.dart';
import '../../extensions/e_request_context.dart';
import '../../mixin/mix_mongo_model.dart';
import '../../mixin/mix_mongo_storage_model.dart';
import '../../models/m_api_response.dart';

/// Delete a model.
/// Supports marking as deleted or actually removing the item from db.
Future<ApiResponseModel> handleDelete(
  RequestContext context,
  MongoStorageModel storage,
) async {
  final id = context.validateParams1(ParamParser.nonEmptyString(kKeyID));

  print('Delete request for id: $id in collection: ${storage.collectionId}');

  final model = await storage.getModel(id);

  if (model == null) {
    return ApiResponseModel(
      message: 'Model from ${storage.collectionId} not found',
      jsonData: {kKeyID: id},
      status: HttpStatus.alreadyReported,
    );
  }

  await model.onPreDelete();

  final bool isDeleted;
  if (storage.flagDeletion) {
    (model as MongoFlagDeleteModel)
      ..isDeleted = true
      // Always set by server
      ..serverUpdatedAt = DateTime.now().toUtc()
      // Update even if offline model as no updatedAt is provided on delete
      ..updatedAt = model.serverUpdatedAt;
    isDeleted = await storage.updateModel(model);
  } else {
    isDeleted = await storage.deleteModel(id);
  }

  if (!isDeleted) {
    return ApiResponseModel.error(
      'Failed to delete ${storage.collectionId} with id $id',
    );
  }

  return ApiResponseModel.success(
    message: 'Deleted ${storage.collectionId} with id $id',
    jsonData: model.toMap(),
  );
}
