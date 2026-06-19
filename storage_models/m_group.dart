import 'dart:async';

import 'package:dart_frog/dart_frog.dart';

import '../constants/k.dart';
import '../mixin/mix_mongo_model.dart';
import '../mixin/mix_mongo_storage_model.dart';
import '../services/api_mapper.dart';
import '../services/membership_sync.dart';

/// A **Round 1** judging group. `groupNumber` matches `judge_group` on animals.
///
/// Round 1 judges are assigned per group. `topXAdvance` is the admin-set number
/// of animals that advance from Round 1 to Round 2. Round 2 (super judge) groups
/// live in the separate `round2_groups` collection (`Round2GroupModel`).
class GroupModel extends MongoFlagDeleteModel<GroupModel> {
  static const keyGroupNumber = 'group_number';
  static const keyJudgeUserIds = 'judge_user_ids';
  static const keyTopXAdvance = 'top_x_advance';

  static MongoStorageModel<GroupModel> get storage => MongoStorageModel(
        collectionId: 'groups',
        fromMap: GroupModel.fromMap,
        createRequiredKeys: [keyGroupNumber],
        updateRequiredKeys: [],
        isOfflineModel: false,
        enableServerIdManagement: true,
        flagDeletion: true,
        uuidAsID: true,
      );

  int groupNumber;
  List<String> judgeUserIds;
  int topXAdvance;

  GroupModel({
    required super.id,
    required this.groupNumber,
    required this.judgeUserIds,
    required this.topXAdvance,
    required super.createdAt,
    required super.updatedAt,
    required super.serverUpdatedAt,
    required super.isDeleted,
  });

  @override
  FutureOr<Future<Response>?> updateProperties(
    GroupModel model,
    Map<String, dynamic> map,
  ) {
    if (map.containsKey(keyGroupNumber)) groupNumber = model.groupNumber;
    if (map.containsKey(keyJudgeUserIds)) judgeUserIds = model.judgeUserIds;
    if (map.containsKey(keyTopXAdvance)) topXAdvance = model.topXAdvance;
    return null;
  }

  // Keep `users.assigned_group_ids` in sync with this group's judge list.
  // Failures are logged but never block the primary group write.

  @override
  FutureOr<void> onCreateSuccessful() => _syncMembers();

  @override
  FutureOr<void> onUpdateSuccessful() => _syncMembers();

  @override
  FutureOr<void> onPreDelete() => _detachMembers();

  Future<void> _syncMembers() async {
    try {
      await MembershipSync.syncUsersForGroup(this);
    } catch (e) {
      print('[GroupModel] member sync failed for group $groupNumber: $e');
    }
  }

  Future<void> _detachMembers() async {
    try {
      await MembershipSync.removeR1GroupFromUsers(groupNumber);
    } catch (e) {
      print('[GroupModel] member detach failed for group $groupNumber: $e');
    }
  }

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    final m = APIMapper(map);
    return GroupModel(
      id: m.getString(kKeyID),
      groupNumber: m.getInt(keyGroupNumber),
      judgeUserIds: m.getStringList(keyJudgeUserIds),
      topXAdvance: m.getInt(keyTopXAdvance),
      createdAt: m.getString(kKeyCreatedAt),
      updatedAt: m.getString(kKeyUpdatedAt),
      serverUpdatedAt: m.getString(kKeyServerUpdatedAt),
      isDeleted: m.getBool(kKeyIsDeleted),
    );
  }

  @override
  Map<String, dynamic> toPropertiesMap() => {
        keyGroupNumber: groupNumber,
        keyJudgeUserIds: judgeUserIds,
        keyTopXAdvance: topXAdvance,
      };
}
