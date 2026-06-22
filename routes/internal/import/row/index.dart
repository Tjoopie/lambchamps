import 'package:dart_frog/dart_frog.dart';

import '../../../../constants/k.dart';
import '../../../../extensions/e_request_context.dart';
import '../../../../models/m_api_response.dart';
import '../../../../services/api_mapper.dart';
import '../../../../storage_models/m_animal.dart';

Future<Response> onRequest(RequestContext context) =>
    context.forHttpMethod(post: () => _importRow(context));

/// Upsert one animal row (match on `_id`). Preserves `super_judge_group` on
/// update unless explicitly supplied — same rules as admin import.
Future<ApiResponseModel> _importRow(RequestContext context) async {
  final body = await context.getValidatedBodyMap(requiredKeys: ['row']);
  final row = body['row'];
  if (row is! Map<String, dynamic>) {
    return const ApiResponseModel.badRequestError('row must be an object');
  }

  final id = (row[kKeyID] ?? '').toString();
  if (id.isEmpty) {
    return const ApiResponseModel.badRequestError('row missing _id');
  }

  final incoming = AnimalModel.fromMap(row);
  final existing = await AnimalModel.storage.getModel(id);
  final now = DateTime.now().toUtc();

  if (existing == null) {
    incoming
      ..createdAt = now
      ..updatedAt = now
      ..serverUpdatedAt = now;
    final saved = await AnimalModel.storage.insertModel(incoming);
    if (saved == null) {
      return ApiResponseModel.error('Insert failed for $id');
    }
    return ApiResponseModel.success(
      message: 'Animal added',
      jsonData: {'action': 'added', '_id': id, 'document': saved.toMap()},
    );
  }

  await existing.updateProperties(incoming, row);
  existing
    ..updatedAt = now
    ..serverUpdatedAt = now;
  final ok = await AnimalModel.storage.updateModel(existing);
  if (!ok) {
    return ApiResponseModel.error('Update failed for $id');
  }
  return ApiResponseModel.success(
    message: 'Animal updated',
    jsonData: {'action': 'updated', '_id': id, 'document': existing.toMap()},
  );
}
