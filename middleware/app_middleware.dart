import 'package:dart_frog/dart_frog.dart';

import '../models/m_api_error.dart';
import '../services/logging_service.dart';

Middleware appMiddleware() {
  return (Handler innerHandler) {
    return (RequestContext context) async {
      final stopwatch = Stopwatch()..start();
      final now = DateTime.now().toUtc();

      Response? response;
      try {
        response = await innerHandler(context);
      } on ApiError catch (e) {
        response = e.toResponse();
      } catch (e, s) {
        stopwatch.stop();
        LogService.logError(
          '${context.request.method.value} ${context.request.uri}: $e ||| $s',
        );
        rethrow;
      }

      stopwatch.stop();
      LogService.logRequest(
        '${context.request.method.value}'
        ' [${response.statusCode}]'
        ' $now > ${DateTime.now().toUtc()}'
        ' (${stopwatch.elapsedMilliseconds}ms)'
        ' ${context.request.uri}',
      );

      return response;
    };
  };
}
