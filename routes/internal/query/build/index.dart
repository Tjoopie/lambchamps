import 'package:dart_frog/dart_frog.dart';

import '../../../../extensions/e_request_context.dart';
import '../../../../models/m_api_response.dart';
import '../../../../services/api_mapper.dart';
import '../../../../services/query_filter_builder.dart';

Future<Response> onRequest(RequestContext context) =>
    context.forHttpMethod(post: () => _build(context));

Future<ApiResponseModel> _build(RequestContext context) async {
  final body = await context.getValidatedBodyMap();
  final m = APIMapper(body);
  final params = m.getMap('params');
  final id = m.getString('_id');
  if (id.isNotEmpty) {
    params['_id'] = id;
  }

  final built = QueryFilterBuilder.build(params);
  if (built.containsKey('error')) {
    return ApiResponseModel.badRequestError(built['error'].toString());
  }

  return ApiResponseModel.success(
    message: 'Query filter built',
    jsonData: built,
  );
}
