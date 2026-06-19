import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';

import '../../constants/k.dart';
import '../../mixin/mix_mongo_storage_model.dart';
import '../../models/m_api_query_builder.dart';
import '../../models/m_api_response.dart';

const kParamID = kKeyID;

/// Will only return items where the serverUpdatedAt is before the given time
const kParamUpdatedBefore = 'updated_before';

/// Will only return items where the serverUpdatedAt is after the given time
const kParamUpdatedAfter = 'updated_after';
const kParamLimit = 'limit';
const kParamPage = 'page';

/// If true, will include items that are marked as deleted
const kParamInclDeleted = 'include_deleted';

/// Will return a list of unique values for the given field
const kParamUniqueValuesField = 'unique_values_field';

// ORDERING
const kParamQueryTypeOrder = 'order';

const kParamQueryTypeSplitter = ':';

// MATCHING
const kParamQueryTypeStringEqual = 'string_equal';
const kParamQueryTypeStringContains = 'string_contains';
const kParamQueryTypeStringAny = 'string_equal_any';
const kParamQueryTypeIntEqual = 'int_equal';
const kParamQueryTypeIntGreaterThan = 'int_greater_than';
const kParamQueryTypeIntLessThan = 'int_less_than_int';

// ORDERING
const kParamQueryTypeStringOrder = 'string_order';

/// Get all models from a collection.
/// Query parameters supported are
/// - matching keys of model
/// - limit (max records returned)
/// - page (page number of records after limit)
/// - updated_before (records updated since given time)
/// - updated_after (records updated before given time)
/// - include_deleted (if items are marked deleted or not)
Future<Response> handleGet(
  RequestContext context,
  MongoStorageModel storage,
  Map<String, String> params,
) async {
  final whereBuilder = where;

  // Single item by ID
  final id = params.remove(kParamID);

  if (id != null) {
    whereBuilder.eq(kKeyID, storage.toMongoID(id));
    final item = await storage.getModelWhere(whereBuilder);

    if (item == null) {
      return ApiResponseModel.error(
        'Error getting ${storage.collectionId} Object with ID: $id',
      ).response();
    }

    return ApiResponseModel.success(
      message: '${storage.collectionId} Object with ID: $id',
      jsonData: item.toMap(),
    ).response();
  }

  // Updated Before query
  String? updatedBefore = params.remove(kParamUpdatedBefore);

  if (updatedBefore != null) {
    updatedBefore = updatedBefore.replaceAll(' ', 'T');
    whereBuilder.lt(kKeyServerUpdatedAt, updatedBefore);
  }

  // Updated After query
  String? updatedAfter = params.remove(kParamUpdatedAfter);

  if (updatedAfter != null) {
    updatedAfter = updatedAfter.replaceAll(' ', 'T');
    whereBuilder.gt(kKeyServerUpdatedAt, updatedAfter);
  }

  // Limit query
  final limit = params.remove(kParamLimit);
  final limitInt = int.tryParse(limit ?? '');
  if (limit != null) {
    if (limitInt == null) {
      return const ApiResponseModel.error(
        '"$kParamLimit" parameter not a valid int',
      ).response();
    }
    if (limitInt < 1) {
      return const ApiResponseModel.error(
        '"$kParamLimit" parameter must be greater than 0',
      ).response();
    }
    whereBuilder.limit(limitInt);
  }

  // Page query
  final page = params.remove(kParamPage);

  if (page != null) {
    if (limitInt == null) {
      return const ApiResponseModel.error(
        'Valid "$kParamLimit" parameter is required when "$kParamPage" parameter is present',
      ).response();
    }
    final pageInt = int.tryParse(page);
    if (pageInt == null) {
      return const ApiResponseModel.error(
        '"$kParamPage" parameter not a valid int',
      ).response();
    }
    if (pageInt < 1) {
      return const ApiResponseModel.error(
        '"$kParamPage" parameter must be greater than 0',
      ).response();
    }
    whereBuilder.skip(limitInt * (pageInt - 1));
  }

  // Include Deleted query
  final inclDeleted = params.remove(kParamInclDeleted);

  if (storage.flagDeletion && inclDeleted != true.toString()) {
    whereBuilder.eq(kKeyIsDeleted, false);
  }

  // Unique Values query (must be before "other" queries)
  final distinctValueField = params.remove(kParamUniqueValuesField);

  // Other queries
  for (final entry in params.entries) {
    final result = APIQueryBuilder().addToWhereBuilder(
      whereBuilder,
      entry.key,
      entry.value,
    );
    if (result != null) return result;
  }

  if (distinctValueField != null) {
    final distinctValues = await storage.getDistinctFieldWhere(
      distinctValueField,
      whereBuilder,
    );
    return ApiResponseModel.success(
      message:
          'All unique values for "$distinctValueField" in ${storage.collectionId}',
      jsonData: distinctValues,
    ).response();
  }

  // First, get a count to see how many records match
  final totalCount = await storage.getCount(whereBuilder);

  final items = await storage.getAllModelsWhere(
    whereBuilder,
    timeoutSeconds: totalCount ~/ 500 + 15,
  );

  return ApiResponseModel.success(
    message: 'All ${storage.collectionId}',
    jsonData: items.map((e) => e.toMap()).toList(),
  ).response();
}
