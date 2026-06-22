import 'package:dart_frog/dart_frog.dart';

import '../../../../extensions/e_request_context.dart';
import '../../../../models/m_api_response.dart';
import '../../../../services/api_mapper.dart';
import '../../../../services/membership_sync.dart';
import '../../../../storage_models/m_group.dart';
import '../../../../storage_models/m_round2_group.dart';
import '../../../../storage_models/m_user.dart';

const _keyAction = 'action';

Future<Response> onRequest(RequestContext context) =>
    context.forHttpMethod(post: () => _reconcile(context));

Future<ApiResponseModel> _reconcile(RequestContext context) async {
  final body = await context.getValidatedBodyMap(requiredKeys: [_keyAction]);
  final action = body.getString(_keyAction);
  final m = APIMapper(body);
  final now = DateTime.now().toUtc().toIso8601String();

  switch (action) {
    case 'sync_users_for_group':
      await MembershipSync.syncUsersForGroup(
        GroupModel(
          id: '',
          groupNumber: m.getInt('group_number'),
          judgeUserIds: m.getStringList('member_ids'),
          topXAdvance: 0,
          createdAt: now,
          updatedAt: now,
          serverUpdatedAt: now,
          isDeleted: false,
        ),
      );
      return ApiResponseModel.emptySuccess('sync_users_for_group completed');

    case 'sync_users_for_round2_group':
      await MembershipSync.syncUsersForRound2Group(
        Round2GroupModel(
          id: '',
          groupNumber: m.getInt('group_number'),
          superJudgeUserIds: m.getStringList('member_ids'),
          createdAt: now,
          updatedAt: now,
          serverUpdatedAt: now,
          isDeleted: false,
        ),
      );
      return ApiResponseModel.emptySuccess('sync_users_for_round2_group completed');

    case 'sync_groups_for_user':
      final userId = m.getString('user_id');
      final user = await UserModel.storage.getModel(userId);
      if (user == null) {
        return ApiResponseModel.notFoundError('User $userId not found');
      }
      await MembershipSync.syncGroupsForUser(user);
      return ApiResponseModel.emptySuccess('sync_groups_for_user completed');

    case 'remove_user_from_all_groups':
      await MembershipSync.removeUserFromAllGroups(m.getString('user_id'));
      return ApiResponseModel.emptySuccess('remove_user_from_all_groups completed');

    case 'remove_r1_group_from_users':
      await MembershipSync.removeR1GroupFromUsers(m.getInt('group_number'));
      return ApiResponseModel.emptySuccess('remove_r1_group_from_users completed');

    case 'remove_r2_group_from_users':
      await MembershipSync.removeR2GroupFromUsers(m.getInt('group_number'));
      return ApiResponseModel.emptySuccess('remove_r2_group_from_users completed');

    default:
      return ApiResponseModel.badRequestError('Unknown action: $action');
  }
}
