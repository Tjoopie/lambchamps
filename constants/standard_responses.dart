import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import '../models/m_api_response.dart';

class StandardResponses {
  StandardResponses._();

  static Future<Response> notMapStringDynamic() => const ApiResponseModel(
        status: 500,
        message: 'Body is not a Map<String,dynamic>',
        jsonData: null,
      ).response();

  static Future<Response> jsonParseFailed() => const ApiResponseModel(
        status: 400,
        message: 'Unable to parse body json',
        jsonData: null,
      ).response();

  static Future<Response> queryParseFailed() => const ApiResponseModel(
        status: 400,
        message: 'Unable to parse query',
        jsonData: null,
      ).response();

  static Future<Response> unknownErrorResponse() => const ApiResponseModel(
        status: 500,
        message: 'Unknown error occurred',
        jsonData: null,
      ).response();

  static Future<Response> notImplementedResponse() => const ApiResponseModel(
        status: 404,
        message: 'API or method not implemented',
        jsonData: null,
      ).response();

  static Future<Response> noCollectionFound() => const ApiResponseModel(
        status: 404,
        message: 'You are using the dynamic collection API, '
            'but this collection was not found. '
            'Please add a valid collection name',
        jsonData: null,
      ).response();

  static Future<Response> methodNotAllowed() => const ApiResponseModel(
        status: 405,
        message: 'Method not allowed',
        jsonData: null,
      ).response();

  static Future<Response> notFound(String message) => ApiResponseModel(
        status: HttpStatus.notFound,
        message: message,
        jsonData: null,
      ).response();

  static Future<Response> badRequest(String message) => ApiResponseModel(
        status: HttpStatus.badRequest,
        message: message,
        jsonData: null,
      ).response();

  static Future<Response> internalServerError(String message) =>
      ApiResponseModel(
        status: HttpStatus.internalServerError,
        message: message,
        jsonData: null,
      ).response();

  static Future<Response> ok({Map<String, dynamic>? body}) => ApiResponseModel(
        status: 200,
        message: 'Success',
        jsonData: body,
      ).response();
}
