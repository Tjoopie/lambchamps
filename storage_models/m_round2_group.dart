import 'dart:async';

import 'package:dart_frog/dart_frog.dart';

import '../constants/k.dart';
import '../mixin/mix_mongo_model.dart';
import '../mixin/mix_mongo_storage_model.dart';
import '../services/api_mapper.dart';
import '../services/membership_sync.dart';

/// A **Round 2** group. `groupNumber` matches `super_judge_group` on animals.
///
/// Round 1 groups live in the separate `groups` collection (`GroupModel`).
/// Round 2 is fully independent: admins create one or more Round 2 groups and
/// redistribute the advanced animals (`animals.super_judge_group`) and super
/// judges across them. Advancement itself is client-side.
class Round2GroupModel extends MongoFlagDeleteModel<Round2GroupModel> {
  static const keyGroupNumber = 'group_number';
  static const keySuperJudgeUserIds = 'super_judge_user_ids';

  static MongoStorageModel<Round2GroupModel> get storage => MongoStorageModel(
        collectionId: 'round2_groups',
        fromMap: Round2GroupModel.fromMap,
        createRequiredKeys: [keyGroupNumber],
        updateRequiredKeys: [],
        isOfflineModel: false,
        enableServerIdManagement: true,
        flagDeletion: true,
        uuidAsID: true,
      );

  int groupNumber;
  List<String> superJudgeUserIds;

  Round2GroupModel({
    required super.id,
    required this.groupNumber,
    required this.superJudgeUserIds,
    required super.createdAt,
    required super.updatedAt,
    required super.serverUpdatedAt,
    required super.isDeleted,
  });

  @override
  FutureOr<Future<Response>?> updateProperties(
    Round2GroupModel model,
    Map<String, dynamic> map,
  ) {
    if (map.containsKey(keyGroupNumber)) groupNumber = model.groupNumber;
    if (map.containsKey(keySuperJudgeUserIds)) {
      superJudgeUserIds = model.superJudgeUserIds;
    }
    return null;
  }

  // Keep `users.assigned_group_ids` in sync with this group's super-judge list.
  // Failures are logged but never block the primary group write.

  @override
  FutureOr<void> onCreateSuccessful() => _syncMembers();

  @override
  FutureOr<void> onUpdateSuccessful() => _syncMembers();

  @override
  FutureOr<void> onPreDelete() => _detachMembers();

  Future<void> _syncMembers() async {
    try {
      await MembershipSync.syncUsersForRound2Group(this);
    } catch (e) {
      print('[Round2GroupModel] member sync failed for group $groupNumber: $e');
    }
  }

  Future<void> _detachMembers() async {
    try {
      await MembershipSync.removeR2GroupFromUsers(groupNumber);
    } catch (e) {
      print(
        '[Round2GroupModel] member detach failed for group $groupNumber: $e',
      );
    }
  }

  factory Round2GroupModel.fromMap(Map<String, dynamic> map) {
    final m = APIMapper(map);
    return Round2GroupModel(
      id: m.getString(kKeyID),
      groupNumber: m.getInt(keyGroupNumber),
      superJudgeUserIds: m.getStringList(keySuperJudgeUserIds),
      createdAt: m.getString(kKeyCreatedAt),
      updatedAt: m.getString(kKeyUpdatedAt),
      serverUpdatedAt: m.getString(kKeyServerUpdatedAt),
      isDeleted: m.getBool(kKeyIsDeleted),
    );
  }

  @override
  Map<String, dynamic> toPropertiesMap() => {
        keyGroupNumber: groupNumber,
        keySuperJudgeUserIds: superJudgeUserIds,
      };
}
