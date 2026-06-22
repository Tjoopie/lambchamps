import 'package:dart_frog/dart_frog.dart';

import '../../../../extensions/e_request_context.dart';
import '../../../../models/m_api_response.dart';
import '../../../../services/api_mapper.dart';
import '../../../../services/qr_ingest_service.dart';

const _keyPayload = 'payload';

Future<Response> onRequest(RequestContext context) =>
    context.forHttpMethod(post: () => _ingest(context));

Future<ApiResponseModel> _ingest(RequestContext context) async {
  final body = await context.getValidatedBodyMap(requiredKeys: [_keyPayload]);
  final payload = body.getString(_keyPayload);
  return QrIngestService.ingestPayload(payload);
}
