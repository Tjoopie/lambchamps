import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart' as shelf;

import 'constants/k.dart';
import 'middleware/app_middleware.dart';
import 'storage/mongo_storage.dart';

Future<void> init(InternetAddress ip, int port) async {
  print('🐑 ${K.appName} started + DB connecting. ');

  try {
    await MongoStorage.instance.safeInitDatabase();
    print('🐑 ${K.appName} started + DB connected. '
        '${kIsProd ? 'PROD' : 'DEV'} 🐑');
  } catch (e) {
    // Don't block server startup if the DB is unreachable (e.g. no local
    // Mongo during dev). Routes that need the DB will retry on demand.
    print('⚠️ ${K.appName} started WITHOUT DB connection: $e');
  }
}

Future<HttpServer> run(Handler handler, InternetAddress ip, int port) {
  return serve(
    handler.use(appMiddleware()).use(
          fromShelfMiddleware(
            shelf.corsHeaders(
              headers: {
                shelf.ACCESS_CONTROL_ALLOW_ORIGIN: '*',
                shelf.ACCESS_CONTROL_ALLOW_METHODS:
                    'GET, POST, PUT, PATCH, DELETE, OPTIONS',
                shelf.ACCESS_CONTROL_ALLOW_HEADERS:
                    'Origin, Content-Type, Authorization',
              },
            ),
          ),
        ),
    ip,
    port,
  );
}
