import '../constants/k.dart';
import '../models/m_api_query_builder.dart';

/// Builds Mongo-compatible filter/limit/skip/sort maps from API query params.
/// Used by POST /internal/query/build for Volcano agents (no mongo_dart selectors).
class QueryFilterBuilder {
  QueryFilterBuilder._();

  static const kParamID = kKeyID;
  static const kParamUpdatedBefore = 'updated_before';
  static const kParamUpdatedAfter = 'updated_after';
  static const kParamLimit = 'limit';
  static const kParamPage = 'page';
  static const kParamInclDeleted = 'include_deleted';

  /// Returns `{ filter, limit?, skip?, sort?, error? }`.
  static Map<String, dynamic> build(Map<String, dynamic> raw) {
    final params = Map<String, dynamic>.from(raw);
    final id = params.remove(kParamID)?.toString();
    if (id != null && id.isNotEmpty) {
      return {
        'filter': {kKeyID: id},
      };
    }

    final filter = <String, dynamic>{};

    final updatedBefore = params.remove(kParamUpdatedBefore)?.toString();
    if (updatedBefore != null) {
      filter[kKeyServerUpdatedAt] = {
        r'$lt': updatedBefore.replaceAll(' ', 'T'),
      };
    }

    final updatedAfter = params.remove(kParamUpdatedAfter)?.toString();
    if (updatedAfter != null) {
      final existing = filter[kKeyServerUpdatedAt];
      if (existing is Map<String, dynamic>) {
        existing[r'$gt'] = updatedAfter.replaceAll(' ', 'T');
      } else {
        filter[kKeyServerUpdatedAt] = {
          r'$gt': updatedAfter.replaceAll(' ', 'T'),
        };
      }
    }

    int? limitInt;
    final limit = params.remove(kParamLimit)?.toString();
    if (limit != null) {
      limitInt = int.tryParse(limit);
      if (limitInt == null || limitInt < 1) {
        return {'error': '"$kParamLimit" parameter not a valid int > 0'};
      }
    }

    int? skip;
    final page = params.remove(kParamPage)?.toString();
    if (page != null) {
      if (limitInt == null) {
        return {
          'error':
              'Valid "$kParamLimit" is required when "$kParamPage" is present',
        };
      }
      final pageInt = int.tryParse(page);
      if (pageInt == null || pageInt < 1) {
        return {'error': '"$kParamPage" parameter not a valid int > 0'};
      };
      skip = limitInt * (pageInt - 1);
    }

    final inclDeleted = params.remove(kParamInclDeleted)?.toString();
    if (inclDeleted != true.toString()) {
      filter[kKeyIsDeleted] = false;
    }

    params.remove('unique_values_field');

    final sort = <String, dynamic>{};
    final keysToRemove = <String>[];

    for (final entry in params.entries) {
      final key = entry.key;
      final value = entry.value.toString();
      final splitIndex = key.indexOf(kParamQueryTypeSplitter);
      if (splitIndex == -1) continue;

      final queryType = key.substring(0, splitIndex);
      final field = key.substring(splitIndex + 1);

      switch (queryType) {
        case kParamQueryTypeOrder:
          if (value != '1' && value != '-1') {
            return {'error': 'Order value must be 1 or -1 for "$key"'};
          }
          sort[field] = value == '-1' ? -1 : 1;
          keysToRemove.add(key);
        case kParamQueryTypeStringEqual:
          if (value.isEmpty) return {'error': 'Empty value for "$key"'};
          filter[field] = value;
          keysToRemove.add(key);
        case kParamQueryTypeStringContains:
          if (value.isEmpty) return {'error': 'Empty value for "$key"'};
          filter[field] = {r'$regex': '.*$value.*'};
          keysToRemove.add(key);
        case kParamQueryTypeStringAny:
          if (value.isEmpty) return {'error': 'Empty value for "$key"'};
          final parts = value.split(';');
          filter[r'$or'] = parts.map((p) => {field: p}).toList();
          keysToRemove.add(key);
        case kParamQueryTypeIntEqual:
          final n = int.tryParse(value);
          if (n == null) return {'error': 'Invalid int for "$key"'};
          filter[field] = n;
          keysToRemove.add(key);
        case kParamQueryTypeIntGreaterThan:
          final n = int.tryParse(value);
          if (n == null) return {'error': 'Invalid int for "$key"'};
          filter[field] = {r'$gt': n};
          keysToRemove.add(key);
        case kParamQueryTypeIntLessThan:
          final n = int.tryParse(value);
          if (n == null) return {'error': 'Invalid int for "$key"'};
          filter[field] = {r'$lt': n};
          keysToRemove.add(key);
        default:
          return {'error': 'Invalid query type "$queryType" for "$key"'};
      }
    }

    for (final k in keysToRemove) {
      params.remove(k);
    }

    final result = <String, dynamic>{'filter': filter};
    if (limitInt != null) result['limit'] = limitInt;
    if (skip != null) result['skip'] = skip;
    if (sort.isNotEmpty) result['sort'] = sort;
    return result;
  }
}
