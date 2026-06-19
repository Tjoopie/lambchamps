import 'package:dart_frog/dart_frog.dart';

import '../constants/k.dart';

Future<Response> onRequest(RequestContext context) async {
  return Response(
    body: '🐑 ${K.appName} v${K.version} - ${kIsProd ? 'PROD' : 'DEV'}',
  );
}
