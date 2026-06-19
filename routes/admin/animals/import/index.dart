import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import '../../../../constants/k.dart';
import '../../../../extensions/e_request_context.dart';
import '../../../../models/m_api_response.dart';
import '../../../../services/logging_service.dart';
import '../../../../storage_models/m_animal.dart';

const _keyAnimals = 'animals';

Future<Response> onRequest(RequestContext context) =>
    context.forHttpMethod(post: () => _import(context));

/// Bulk Excel import → upsert animals (match on client `_id`).
///
/// Accepts either a raw JSON array of animal docs or an object
/// `{ "animals": [ ... ] }`. Existing animals (matched on `_id`) are updated;
/// new rows are inserted. `super_judge_group` is intentionally NOT overwritten
/// on update unless explicitly supplied, since it is admin-set in-app (not an
/// Excel column).
Future<ApiResponseModel> _import(RequestContext context) async {
  final List<dynamic> rows;
  try {
    final decoded = jsonDecode(await context.request.body());
    if (decoded is List) {
      rows = decoded;
    } else if (decoded is Map<String, dynamic> && decoded[_keyAnimals] is List) {
      rows = decoded[_keyAnimals] as List;
    } else {
      return const ApiResponseModel.badRequestError(
        'Body must be a JSON array of animals or { "animals": [ ... ] }',
      );
    }
  } catch (_) {
    return const ApiResponseModel.badRequestError('Unable to parse body json');
  }

  if (rows.isEmpty) {
    return const ApiResponseModel.badRequestError('No animals provided');
  }

  final added = <String>[];
  final updated = <String>[];
  final skipped = <Map<String, dynamic>>[];

  for (final row in rows) {
    if (row is! Map<String, dynamic>) {
      skipped.add({'row': row, 'reason': 'not an object'});
      continue;
    }
    final id = (row[kKeyID] ?? '').toString();
    if (id.isEmpty) {
      skipped.add({'row': row, 'reason': 'missing _id'});
      continue;
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
      if (saved != null) {
        added.add(id);
      } else {
        skipped.add({kKeyID: id, 'reason': 'insert failed'});
      }
    } else {
      await existing.updateProperties(incoming, row);
      existing
        ..updatedAt = now
        ..serverUpdatedAt = now;
      final ok = await AnimalModel.storage.updateModel(existing);
      ok ? updated.add(id) : skipped.add({kKeyID: id, 'reason': 'update failed'});
    }
  }

  LogService.logInfo(
    '[admin/animals/import] added: ${added.length}, '
    'updated: ${updated.length}, skipped: ${skipped.length}',
  );

  return ApiResponseModel.success(
    message: 'Imported animals',
    jsonData: {
      'added_count': added.length,
      'updated_count': updated.length,
      'skipped_count': skipped.length,
      'added_ids': added,
      'updated_ids': updated,
      'skipped': skipped,
    },
  );
}
