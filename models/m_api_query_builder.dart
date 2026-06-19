import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';

import '../routes_handlers/v1/handle_get.dart';
import 'm_api_response.dart';

typedef _Data = ({
  SelectorBuilder whereBuilder,
  String key,
  String queryType,
  String field,
  String value,
});

class APIQueryBuilder {
  Future<Response>? addToWhereBuilder(
    SelectorBuilder whereBuilder,
    String key,
    String value,
  ) {
    final splitIndex = key.indexOf(kParamQueryTypeSplitter);
    if (splitIndex == -1) {
      return ApiResponseModel.error(
        'Query parameter "$key" does not follow pattern of "type${kParamQueryTypeSplitter}field"',
      ).response();
    }

    final queryType = key.substring(0, splitIndex);
    final field = key.substring(splitIndex + 1);

    final data = (
      whereBuilder: whereBuilder,
      key: key,
      queryType: queryType,
      field: field,
      value: value,
    );

    final result = switch (queryType) {
      kParamQueryTypeOrder => _order(data),
      kParamQueryTypeStringEqual => _stringEqual(data),
      kParamQueryTypeStringContains => _stringContains(data),
      kParamQueryTypeStringAny => _stringAny(data),
      kParamQueryTypeIntEqual => _intEqual(data),
      kParamQueryTypeIntGreaterThan => _intGreaterThan(data),
      kParamQueryTypeIntLessThan => _intLessThan(data),
      _ => ApiResponseModel.error(
          'Invalid query type "$queryType" for parameter "$key"',
        ),
    };
    return result is ApiResponseModel ? result.response() : null;
  }

  ApiResponseModel? _order(_Data data) {
    if (data.value != '1' && data.value != '-1') {
      return ApiResponseModel.error(
        'Query parameter "${data.key}" value is empty (should be -1 or 1)',
      );
    }
    data.whereBuilder.sortBy(data.field, descending: data.value == '-1');
    return null;
  }

  ApiResponseModel? _stringEqual(_Data data) {
    if (data.value.isEmpty) {
      return ApiResponseModel.error(
        'Query parameter "${data.key}" value is empty',
      );
    }
    data.whereBuilder.eq(data.field, data.value);
    return null;
  }

  ApiResponseModel? _stringContains(_Data data) {
    if (data.value.isEmpty) {
      return ApiResponseModel.error(
        'Query parameter "${data.key}" value is empty',
      );
    }
    data.whereBuilder.match(data.field, '.*${RegExp.escape(data.value)}.*');
    return null;
  }

  ApiResponseModel? _stringAny(_Data data) {
    if (data.value.isEmpty) {
      return ApiResponseModel.error(
        'Query parameter "${data.key}" value is empty',
      );
    }

    final whereBuilder = where;
    final splitList = data.value.split(';');

    for (int i = 0; i < splitList.length; i++) {
      if (i == 0) {
        whereBuilder.eq(data.field, splitList[i]);
      } else {
        whereBuilder.or(where.eq(data.field, splitList[i]));
      }
    }

    data.whereBuilder.and(whereBuilder);
    return null;
  }

  ApiResponseModel? _intEqual(_Data data) {
    final value = int.tryParse(data.value);
    if (value == null) {
      return ApiResponseModel.error(
        'Query parameter "${data.key}" value is not a valid int',
      );
    }
    data.whereBuilder.eq(data.field, value);
    return null;
  }

  ApiResponseModel? _intGreaterThan(_Data data) => _numberGreaterOrLessThan(
        data: data,
        isGreater: true,
        value: int.tryParse(data.value),
      );

  ApiResponseModel? _intLessThan(_Data data) => _numberGreaterOrLessThan(
        data: data,
        isGreater: false,
        value: int.tryParse(data.value),
      );

  ApiResponseModel? _numberGreaterOrLessThan<T>({
    required _Data data,
    required bool isGreater,
    required T? value,
  }) {
    if (value == null) {
      return ApiResponseModel.error(
        'Query parameter "${data.key}" value is not a valid $T',
      );
    }
    isGreater
        ? data.whereBuilder.gt(data.field, value)
        : data.whereBuilder.lt(data.field, value);
    return null;
  }
}
