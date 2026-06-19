import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

class ApiResponseModel {
  final int status;
  final String message;
  final Map<String, String> addedHeaders;
  final dynamic jsonData;

  const ApiResponseModel({
    required this.status,
    required this.message,
    this.addedHeaders = const {},
    required this.jsonData,
  });

  const ApiResponseModel.success({
    required this.message,
    this.jsonData,
    this.addedHeaders = const {},
  }) : status = 200;

  const ApiResponseModel.emptySuccess(
    this.message, {
    this.addedHeaders = const {},
  })  : status = HttpStatus.ok,
        jsonData = const <String, dynamic>{};

  const ApiResponseModel.error(
    this.message, {
    this.addedHeaders = const {},
    this.status = HttpStatus.internalServerError,
  }) : jsonData = null;

  const ApiResponseModel.notFoundError(
    this.message, {
    this.addedHeaders = const {},
  })  : status = HttpStatus.notFound,
        jsonData = null;

  const ApiResponseModel.doesNotExist(
    this.message, {
    this.addedHeaders = const {},
  })  : status = HttpStatus.expectationFailed,
        jsonData = null;

  const ApiResponseModel.badRequestError(
    this.message, {
    this.addedHeaders = const {},
  })  : status = HttpStatus.badRequest,
        jsonData = null;

  static const notImplemented = ApiResponseModel(
    status: HttpStatus.notImplemented,
    message: 'API or method not implemented',
    jsonData: null,
  );

  factory ApiResponseModel.missingQueryParams(List<String> items) =>
      ApiResponseModel.badRequestError(
        'Query parameters missing: ${items.map((e) => '`$e`').join(', ')}',
      );

  factory ApiResponseModel.missingBodyKeys(List<String> items) =>
      ApiResponseModel.badRequestError(
        'Body keys missing: ${items.map((e) => '`$e`').join(', ')}',
      );

  Map<String, dynamic> toMap() => {
        'status': status,
        'message': message,
        'data': jsonData,
      };

  /// Return [ApiResponseModel] as a Dart Frog [Response].
  Future<Response> response() {
    final responseMap = toMap();
    return Future.value(
      Response.json(
        headers: {
          'Content-Length': '${utf8.encode(jsonEncode(responseMap)).length}',
        }..addAll(addedHeaders),
        statusCode: status,
        body: responseMap,
      ),
    );
  }
}
