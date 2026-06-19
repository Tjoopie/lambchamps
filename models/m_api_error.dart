import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

class ApiError implements Exception {
  final int status;
  final String message;

  static const notImplemented = ApiError(
    'Not implemented',
    status: HttpStatus.notImplemented,
  );

  const ApiError(this.message, {this.status = HttpStatus.internalServerError});

  const ApiError.notFoundError(this.message) : status = HttpStatus.notFound;

  const ApiError.doesNotExist(this.message)
      : status = HttpStatus.expectationFailed;

  const ApiError.badRequestError(this.message) : status = HttpStatus.badRequest;

  ApiError.missingQueryParams(List<String> items)
      : this.badRequestError(
          'Query parameters missing: ${items.map((e) => '`$e`').join(', ')}',
        );

  ApiError.missingBodyKeys(List<String> items)
      : this.badRequestError(
          'Body keys missing: ${items.map((e) => '`$e`').join(', ')}',
        );

  Map<String, dynamic> toMap() => {'status': status, 'message': message};

  /// Return [ApiError] as a Dart Frog [Response].
  Response toResponse() => Response.json(statusCode: status, body: toMap());
}
