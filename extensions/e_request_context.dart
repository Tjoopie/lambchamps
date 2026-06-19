import 'dart:async';
import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';

import '../models/m_api_error.dart';
import '../models/m_api_response.dart';
import '../services/api_mapper.dart';

extension RequestContextExtras on RequestContext {
  Map<String, String> get queryParameters =>
      Map<String, String>.from(request.url.queryParameters);

  Future<Response> forHttpMethod({
    FutureOr<ApiResponseModel> Function()? get,
    FutureOr<Response> Function()? getResponse,
    FutureOr<ApiResponseModel> Function()? post,
    FutureOr<Response> Function()? postResponse,
    FutureOr<ApiResponseModel> Function()? patch,
    FutureOr<Response> Function()? patchResponse,
    FutureOr<ApiResponseModel> Function()? put,
    FutureOr<Response> Function()? putResponse,
    FutureOr<ApiResponseModel> Function()? delete,
    FutureOr<Response> Function()? deleteResponse,
  }) async {
    final callback = switch (request.method) {
      HttpMethod.get => get,
      HttpMethod.post => post,
      HttpMethod.patch => patch,
      HttpMethod.put => put,
      HttpMethod.delete => delete,
      _ => null,
    };
    if (callback != null) return (await callback()).response();

    final responseCallback = switch (request.method) {
      HttpMethod.get => getResponse,
      HttpMethod.post => postResponse,
      HttpMethod.patch => patchResponse,
      HttpMethod.put => putResponse,
      HttpMethod.delete => deleteResponse,
      _ => null,
    };
    return responseCallback?.call() ??
        ApiResponseModel.notImplemented.response();
  }

  Future<Map<String, dynamic>> getValidatedBodyMap({
    List<String> requiredKeys = const [],
  }) async {
    try {
      final body = jsonDecode(await request.body());
      if (body is Map<String, dynamic>) {
        final missingKeys = requiredKeys
            .where((key) => !body.containsKey(key))
            .toList();
        if (missingKeys.isNotEmpty) throw ApiError.missingBodyKeys(missingKeys);

        return body;
      }

      throw const ApiError.badRequestError(
        'Body is not of type Map<String,dynamic>',
      );
    } catch (e) {
      if (e is ApiError) rethrow;
      throw const ApiError.badRequestError('Unable to parse body json');
    }
  }

  T validateParams1<T>(ParamParser<T> p1) {
    final params = queryParameters;
    final (valid1, value1) = p1.parse(params);
    if (!valid1) throw ApiError.missingQueryParams([p1.key]);
    return value1;
  }

  (T1, T2) validateParams2<T1, T2>(ParamParser<T1> p1, ParamParser<T2> p2) {
    final params = queryParameters;
    final (valid1, value1) = p1.parse(params);
    final (valid2, value2) = p2.parse(params);
    final missingParams = [if (!valid1) p1.key, if (!valid2) p2.key];
    if (missingParams.isNotEmpty) {
      throw ApiError.missingQueryParams(missingParams);
    }
    return (value1, value2);
  }
}

class ParamParser<T> {
  final String key;
  final (bool, T) Function(Map<String, String>) parse;

  const ParamParser({required this.key, required this.parse});

  static ParamParser<String> nonEmptyString(String key) => ParamParser<String>(
        key: key,
        parse: (params) {
          final value = params.getString(key);
          return (value.isNotEmpty, value);
        },
      );

  static ParamParser<bool> providedBool(String key) => ParamParser<bool>(
        key: key,
        parse: (params) {
          final value = params.getBoolNullable(key);
          return (value != null, value ?? false);
        },
      );
}
