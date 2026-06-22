import 'package:dart_frog/dart_frog.dart';

import '../../../../extensions/e_request_context.dart';
import '../../../../models/m_api_response.dart';
import '../../../../services/api_mapper.dart';
import '../../../../services/qr_ingest_service.dart';

Future<Response> onRequest(RequestContext context) =>
    context.forHttpMethod(post: () => _build(context));

Future<ApiResponseModel> _build(RequestContext context) async {
  final body = await context.getValidatedBodyMap(requiredKeys: ['data']);
  final data = body['data'];
  if (data is! Map<String, dynamic>) {
    return const ApiResponseModel.badRequestError('data must be an object');
  }
  return QrIngestService.buildDocuments(data);
}
