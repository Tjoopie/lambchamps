import 'package:mongo_dart/mongo_dart.dart';

import '../constants/k.dart';
import '../mixin/mix_mongo_model.dart';
import '../storage_models/m_group.dart';
import '../storage_models/m_round2_group.dart';
import '../storage_models/m_user.dart';

/// Keeps both sides of group membership consistent across two collections:
///
/// - Round 1: `groups.judge_user_ids`        ↔ `users.assigned_group_ids`
///   (only for users with role [UserRole.judge]).
/// - Round 2: `round2_groups.super_judge_user_ids` ↔ `users.assigned_group_ids`
///   (only for users with role [UserRole.superJudge]).
///
/// A user has exactly one role, so their `assigned_group_ids` refers to the
/// group numbers of whichever collection matches that role; the two collections
/// never reconcile the same user.
///
/// Either side can be edited (the admin Groups screens write the group lists;
/// the admin Users screen writes `assigned_group_ids`). After each write the
/// matching model hook calls into here to reconcile the other side.
///
/// All reconciliation uses direct storage writes (NOT the CRUD handlers), so it
/// does not re-trigger model hooks — there is no sync recursion.
class MembershipSync {
  MembershipSync._();

  // ---------------------------------------------------------------------------
  // Group write → reconcile users.assigned_group_ids
  // ---------------------------------------------------------------------------

  /// Reconcile judge users' `assigned_group_ids` to match a Round 1 [group].
  static Future<void> syncUsersForGroup(GroupModel group) =>
      _reconcileUsersForGroup(
        group.groupNumber,
        group.judgeUserIds.toSet(),
        UserRole.judge,
      );

  /// Reconcile super-judge users' `assigned_group_ids` to match a Round 2
  /// [group].
  static Future<void> syncUsersForRound2Group(Round2GroupModel group) =>
      _reconcileUsersForGroup(
        group.groupNumber,
        group.superJudgeUserIds.toSet(),
        UserRole.superJudge,
      );

  /// Remove a Round 1 group number from all judge users (group deleted).
  static Future<void> removeR1GroupFromUsers(int groupNumber) =>
      _reconcileUsersForGroup(groupNumber, const <String>{}, UserRole.judge);

  /// Remove a Round 2 group number from all super-judge users (group deleted).
  static Future<void> removeR2GroupFromUsers(int groupNumber) =>
      _reconcileUsersForGroup(
        groupNumber,
        const <String>{},
        UserRole.superJudge,
      );

  /// For every user of [role], make `assigned_group_ids` carry [number] iff the
  /// user id is in [memberIds]. Users of other roles are never touched, so a
  /// Round 1 and Round 2 group sharing a `group_number` don't collide.
  static Future<void> _reconcileUsersForGroup(
    int number,
    Set<String> memberIds,
    UserRole role,
  ) async {
    final users = await UserModel.storage.getAllModelsWhere(
      where.eq(kKeyIsDeleted, false),
    );
    for (final user in users) {
      if (!user.roles.contains(role)) continue;
      final has = user.assignedGroupIds.contains(number);
      final shouldHave = memberIds.contains(user.id);
      if (has == shouldHave) continue;

      user.assignedGroupIds = shouldHave
          ? ([...user.assignedGroupIds, number]..sort())
          : user.assignedGroupIds.where((g) => g != number).toList();
      _touch(user);
      await UserModel.storage.updateModel(user);
    }
  }

  // ---------------------------------------------------------------------------
  // User write → reconcile group member lists
  // ---------------------------------------------------------------------------

  /// Reconcile the group member lists to match [user]'s `assigned_group_ids`,
  /// routed per role. A user may hold several roles: a `judge` is reconciled
  /// against Round 1 `groups`, a `super_judge` against `round2_groups`, and a
  /// user holding both is reconciled against both. A role the user does NOT
  /// hold purges them from that collection (so admin / unassigned users — and
  /// users who lost a role — end up in neither side).
  static Future<void> syncGroupsForUser(UserModel user) async {
    if (user.isJudge) {
      await _reconcileR1GroupsForUser(user);
    } else {
      await _removeUserFromAllR1Groups(user.id);
    }

    if (user.isSuperJudge) {
      await _reconcileRound2GroupsForUser(user);
    } else {
      await _removeUserFromAllRound2Groups(user.id);
    }
  }

  /// Remove [userId] from every group's member list in both collections (used
  /// when a user is deleted).
  static Future<void> removeUserFromAllGroups(String userId) async {
    await _removeUserFromAllR1Groups(userId);
    await _removeUserFromAllRound2Groups(userId);
  }

  static Future<void> _reconcileR1GroupsForUser(UserModel user) async {
    final assigned = user.assignedGroupIds.toSet();
    final groups = await GroupModel.storage.getAllModelsWhere(
      where.eq(kKeyIsDeleted, false),
    );
    for (final group in groups) {
      final shouldContain = assigned.contains(group.groupNumber);
      if (group.judgeUserIds.contains(user.id) == shouldContain) continue;
      group.judgeUserIds =
          _applyMembership(group.judgeUserIds, user.id, shouldContain);
      _touch(group);
      await GroupModel.storage.updateModel(group);
    }
  }

  static Future<void> _reconcileRound2GroupsForUser(UserModel user) async {
    final assigned = user.assignedGroupIds.toSet();
    final groups = await Round2GroupModel.storage.getAllModelsWhere(
      where.eq(kKeyIsDeleted, false),
    );
    for (final group in groups) {
      final shouldContain = assigned.contains(group.groupNumber);
      if (group.superJudgeUserIds.contains(user.id) == shouldContain) continue;
      group.superJudgeUserIds =
          _applyMembership(group.superJudgeUserIds, user.id, shouldContain);
      _touch(group);
      await Round2GroupModel.storage.updateModel(group);
    }
  }

  static Future<void> _removeUserFromAllR1Groups(String userId) async {
    final groups = await GroupModel.storage.getAllModelsWhere(
      where.eq(kKeyIsDeleted, false),
    );
    for (final group in groups) {
      if (!group.judgeUserIds.contains(userId)) continue;
      group.judgeUserIds = _applyMembership(group.judgeUserIds, userId, false);
      _touch(group);
      await GroupModel.storage.updateModel(group);
    }
  }

  static Future<void> _removeUserFromAllRound2Groups(String userId) async {
    final groups = await Round2GroupModel.storage.getAllModelsWhere(
      where.eq(kKeyIsDeleted, false),
    );
    for (final group in groups) {
      if (!group.superJudgeUserIds.contains(userId)) continue;
      group.superJudgeUserIds =
          _applyMembership(group.superJudgeUserIds, userId, false);
      _touch(group);
      await Round2GroupModel.storage.updateModel(group);
    }
  }

  static List<String> _applyMembership(
    List<String> list,
    String id,
    bool shouldContain,
  ) {
    final has = list.contains(id);
    if (has == shouldContain) return list;
    return shouldContain ? [...list, id] : list.where((e) => e != id).toList();
  }

  static void _touch(MongoModel<dynamic> model) {
    final now = DateTime.now().toUtc();
    model
      ..updatedAt = now
      ..serverUpdatedAt = now;
  }
}
