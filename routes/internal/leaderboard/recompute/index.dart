import 'package:dart_frog/dart_frog.dart';

import '../../../../extensions/e_request_context.dart';
import '../../../../models/m_api_response.dart';
import '../../../../services/api_mapper.dart';
import '../../../../services/leaderboard_service.dart';

Future<Response> onRequest(RequestContext context) =>
    context.forHttpMethod(post: () => _recompute(context));

Future<ApiResponseModel> _recompute(RequestContext context) async {
  final body = await context.getValidatedBodyMap();
  final m = APIMapper(body);
  final round = m.getInt('round', 1);
  final groupNumber = m.getInt('group_number', 0);

  if (groupNumber > 0) {
    await LeaderboardService.recomputeRoundGroup(round, groupNumber);
    return ApiResponseModel.success(
      message: 'Leaderboard recomputed for round $round group $groupNumber',
      jsonData: {'round': round, 'group_number': groupNumber},
    );
  }

  await LeaderboardService.recomputeRound(round);
  return ApiResponseModel.success(
    message: 'Leaderboard recomputed for round $round',
    jsonData: {'round': round},
  );
}
