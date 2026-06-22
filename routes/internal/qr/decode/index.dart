import 'package:dart_frog/dart_frog.dart';

import '../../../../extensions/e_request_context.dart';
import '../../../../models/m_api_response.dart';
import '../../../../services/api_mapper.dart';
import '../../../../services/submission_codec.dart';

const _keyPayload = 'payload';

Future<Response> onRequest(RequestContext context) =>
    context.forHttpMethod(post: () => _decode(context));

Future<ApiResponseModel> _decode(RequestContext context) async {
  final body = await context.getValidatedBodyMap(requiredKeys: [_keyPayload]);
  final payload = body.getString(_keyPayload);
  if (payload.isEmpty) {
    return ApiResponseModel.missingBodyKeys([_keyPayload]);
  }

  try {
    final data = SubmissionCodec.decodeAndVerify(payload);
    return ApiResponseModel.success(
      message: 'Payload decoded and verified',
      jsonData: {
        'verified': true,
        'qr_batch_id': (data['b'] ?? '').toString(),
        'data': data,
      },
    );
  } on SubmissionCodecError catch (e) {
    return ApiResponseModel.badRequestError(e.message);
  }
}
