import 'dart:async';

import 'package:dart_frog/dart_frog.dart';

import '../constants/k.dart';
import '../mixin/mix_mongo_model.dart';
import '../mixin/mix_mongo_storage_model.dart';
import '../services/api_mapper.dart';
import '../services/membership_sync.dart';

/// The Lamb Champs roles. The Mongo `role` value uses [key].
///
/// [unassigned] is the state of a self-signed-up user before an admin grants a
/// real role. Unknown/empty roles map here too — they must NEVER be coerced to
/// [judge], or a no-role account would silently gain judging access.
enum UserRole {
  admin('admin'),
  judge('judge'),
  superJudge('super_judge'),
  unassigned('unassigned');

  const UserRole(this.key);

  final String key;

  static UserRole fromKey(String key) =>
      values.where((e) => e.key == key).firstOrNull ?? UserRole.unassigned;
}

/// A pre-provisioned competition user.
///
/// Admin creates the record (email + roles) before the person signs up. On
/// first Firebase sign-in the backend matches the Firebase email to this record
/// and sets [firebaseUid]. Roles drive app routing — not Firebase custom claims.
///
/// A user can hold **multiple** roles (e.g. both `judge` and `super_judge`),
/// stored as a list of role keys under [keyRoles].
class UserModel extends MongoFlagDeleteModel<UserModel> {
  static const keyEmail = 'email';

  /// Multi-role wire key: a list of role keys (string[]).
  static const keyRoles = 'roles';
  static const keyDisplayName = 'display_name';
  static const keyAssignedGroupIds = 'assigned_group_ids';
  static const keyFirebaseUid = 'firebase_uid';
  static const keyIsProvisioned = 'is_provisioned';

  static MongoStorageModel<UserModel> get storage => MongoStorageModel(
        collectionId: 'users',
        fromMap: UserModel.fromMap,
        // `roles` is optional on create — self-sign-ups default to `unassigned`.
        createRequiredKeys: [keyEmail],
        updateRequiredKeys: [],
        isOfflineModel: false,
        enableServerIdManagement: true,
        flagDeletion: true,
        uuidAsID: true,
      );

  String email;
  List<UserRole> roles;
  String displayName;
  List<int> assignedGroupIds;
  String firebaseUid;
  bool isProvisioned;

  UserModel({
    required super.id,
    required this.email,
    required this.roles,
    required this.displayName,
    required this.assignedGroupIds,
    required this.firebaseUid,
    required this.isProvisioned,
    required super.createdAt,
    required super.updatedAt,
    required super.serverUpdatedAt,
    required super.isDeleted,
  });

  bool get isAdmin => roles.contains(UserRole.admin);
  bool get isJudge => roles.contains(UserRole.judge);
  bool get isSuperJudge => roles.contains(UserRole.superJudge);

  /// Parses the [keyRoles] list. Unknown/empty/missing → `[unassigned]`;
  /// `unassigned` is dropped when a real role is present.
  static List<UserRole> _parseRoles(Map<String, dynamic> map) {
    final m = APIMapper(map);
    final parsed = m.getStringList(keyRoles).map(UserRole.fromKey).toSet();
    if (parsed.length > 1) parsed.remove(UserRole.unassigned);
    return parsed.isEmpty ? [UserRole.unassigned] : parsed.toList();
  }

  @override
  FutureOr<Future<Response>?> onPreCreate() {
    email = email.toLowerCase();
    // A freshly created user has not linked a Firebase account yet.
    if (firebaseUid.isEmpty) isProvisioned = true;
    return null;
  }

  // Keep group member lists in sync with this user's `assigned_group_ids`.
  // Failures are logged but never block the primary user write.

  @override
  FutureOr<void> onCreateSuccessful() => _syncGroups();

  @override
  FutureOr<void> onUpdateSuccessful() => _syncGroups();

  @override
  FutureOr<void> onPreDelete() => _detachGroups();

  Future<void> _syncGroups() async {
    try {
      await MembershipSync.syncGroupsForUser(this);
    } catch (e) {
      print('[UserModel] group sync failed for user $id: $e');
    }
  }

  Future<void> _detachGroups() async {
    try {
      await MembershipSync.removeUserFromAllGroups(id);
    } catch (e) {
      print('[UserModel] group detach failed for user $id: $e');
    }
  }

  @override
  FutureOr<Future<Response>?> updateProperties(
    UserModel model,
    Map<String, dynamic> map,
  ) {
    if (map.containsKey(keyEmail)) email = model.email.toLowerCase();
    if (map.containsKey(keyRoles)) roles = model.roles;
    if (map.containsKey(keyDisplayName)) displayName = model.displayName;
    if (map.containsKey(keyAssignedGroupIds)) {
      assignedGroupIds = model.assignedGroupIds;
    }
    if (map.containsKey(keyFirebaseUid)) firebaseUid = model.firebaseUid;
    if (map.containsKey(keyIsProvisioned)) isProvisioned = model.isProvisioned;
    return null;
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final m = APIMapper(map);
    return UserModel(
      id: m.getString(kKeyID),
      email: m.getString(keyEmail).toLowerCase(),
      roles: _parseRoles(map),
      displayName: m.getString(keyDisplayName),
      assignedGroupIds: m.getIntList(keyAssignedGroupIds),
      firebaseUid: m.getString(keyFirebaseUid),
      isProvisioned: m.getBool(keyIsProvisioned),
      createdAt: m.getString(kKeyCreatedAt),
      updatedAt: m.getString(kKeyUpdatedAt),
      serverUpdatedAt: m.getString(kKeyServerUpdatedAt),
      isDeleted: m.getBool(kKeyIsDeleted),
    );
  }

  @override
  Map<String, dynamic> toPropertiesMap() => {
        keyEmail: email,
        keyRoles: roles.map((e) => e.key).toList(),
        keyDisplayName: displayName,
        keyAssignedGroupIds: assignedGroupIds,
        keyFirebaseUid: firebaseUid,
        keyIsProvisioned: isProvisioned,
      };
}
