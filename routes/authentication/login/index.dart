import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';

import '../../../constants/k.dart';
import '../../../extensions/e_request_context.dart';
import '../../../models/m_api_response.dart';
import '../../../services/api_mapper.dart';
import '../../../services/firebase_admin_auth_service.dart';
import '../../../services/logging_service.dart';
import '../../../storage_models/m_user.dart';

const _keyFirebaseIDToken = 'firebase_id_token';

Future<Response> onRequest(RequestContext context) =>
    context.forHttpMethod(post: () => _login(context));

/// Log a user in via a Firebase ID token.
///
/// Flow:
/// 1. Verify the Firebase ID token (bypassed in dev — see `kFirebaseAuthBypass`).
/// 2. Match the verified email to a pre-provisioned Mongo [UserModel]
///    (by `firebase_uid`, then by `email`).
/// 3. On first sign-in, link the Firebase uid to the user record.
/// 4. Return the full user profile + roles for app routing.
///
/// Login is blocked (403) if no provisioned user matches the email.
Future<ApiResponseModel> _login(RequestContext context) async {
  final body = await context.getValidatedBodyMap();

  final token = body.getString(_keyFirebaseIDToken);
  if (token.isEmpty) {
    return ApiResponseModel.missingBodyKeys([_keyFirebaseIDToken]);
  }

  final result = await FirebaseAdminAuthService().verifyIdToken(token);

  switch (result) {
    case TokenVerified():
      if (result.email.isEmpty) {
        return const ApiResponseModel.error('Missing email in token');
      }
      return _resolveUser(uid: result.uid, email: result.email.toLowerCase());

    case TokenNetworkError():
      return const ApiResponseModel.error(
        'Unable to verify token: network error. Please try again.',
      );

    case TokenInvalid():
      return const ApiResponseModel.badRequestError(
        'Invalid or expired Firebase token',
      );
  }
}

/// Matches the verified identity to a Mongo user, links the uid on first login,
/// and returns the profile + roles.
Future<ApiResponseModel> _resolveUser({
  required String uid,
  required String email,
}) async {
  UserModel? user;

  if (uid.isNotEmpty) {
    user = await UserModel.storage.getModelWhere(
      where.eq(UserModel.keyFirebaseUid, uid).eq(kKeyIsDeleted, false),
    );
  }
  user ??= await UserModel.storage.getModelWhere(
    where.eq(UserModel.keyEmail, email).eq(kKeyIsDeleted, false),
  );

  if (user == null) {
    LogService.logWarning('[login] No provisioned user for $email');
    return ApiResponseModel(
      status: HttpStatus.forbidden,
      message: 'No provisioned account for $email. Ask an admin to add you.',
      jsonData: null,
    );
  }

  // Link the Firebase uid to the pre-provisioned record on first sign-in.
  if (uid.isNotEmpty && user.firebaseUid != uid) {
    user
      ..firebaseUid = uid
      ..updatedAt = DateTime.now().toUtc()
      ..serverUpdatedAt = DateTime.now().toUtc();
    await UserModel.storage.updateModel(user);
  }

  final roleKeys = user.roles.map((e) => e.key).toList();
  LogService.logLogin(
    '$email signed in as ${roleKeys.join(', ')} (uid: $uid)',
  );
  return ApiResponseModel.success(
    message: 'Login successful',
    jsonData: {
      'uid': uid,
      'email': email,
      'roles': roleKeys,
      'user': user.toMap(),
    },
  );
}
