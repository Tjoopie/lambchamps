import 'dart:io';

import 'package:firebase_admin/firebase_admin.dart';
import 'package:firebase_admin/src/auth/credential.dart';

import '../constants/k.dart';
import 'jwt_service.dart';

/// Verifies Firebase ID tokens and looks up Firebase users.
///
/// While [kFirebaseAuthBypass] is `true`, tokens are decoded (NOT verified) so
/// development can proceed before the Firebase service account is provisioned.
class FirebaseAdminAuthService {
  static FirebaseAdminAuthService? _instance;

  factory FirebaseAdminAuthService() =>
      _instance ??= FirebaseAdminAuthService._internal();

  FirebaseAdminAuthService._internal();

  App? _app;

  App get _firebaseApp => _app ??= FirebaseAdmin.instance.initializeApp(
        AppOptions(
          credential: ServiceAccountCredential.fromJson(
            kFirebaseServiceAccount,
          ),
        ),
      );

  /// Verifies a Firebase ID token and returns a [TokenVerificationResult].
  Future<TokenVerificationResult> verifyIdToken(String idToken) async {
    // DEV: trust the token without verifying (until Firebase is provisioned).
    if (kFirebaseAuthBypass) {
      final claims = JWTService.decodePayload(idToken);
      if (claims == null) return TokenVerificationResult.invalid;
      return TokenVerificationResult.verified(
        uid: (claims['user_id'] ?? claims['sub'] ?? '').toString(),
        email: (claims['email'] ?? '').toString(),
      );
    }

    try {
      final token = await _firebaseApp.auth().verifyIdToken(idToken);
      return TokenVerificationResult.verified(
        uid: token.claims.subject,
        email: token.claims.email ?? '',
      );
    } on SocketException catch (e) {
      print('[FirebaseAdminAuthService] Network error: $e');
      return TokenVerificationResult.networkError;
    } on HttpException catch (e) {
      print('[FirebaseAdminAuthService] HTTP error: $e');
      return TokenVerificationResult.networkError;
    } catch (e) {
      print('[FirebaseAdminAuthService] Invalid token: $e');
      return TokenVerificationResult.invalid;
    }
  }

  Future<(bool success, UserRecord? user)> getUserByEmail(String email) async {
    if (kFirebaseAuthBypass) return (false, null);
    try {
      return (true, await _firebaseApp.auth().getUserByEmail(email));
    } catch (e) {
      if (e is FirebaseAuthError && e.code == 'auth/user-not-found') {
        return (true, null);
      }
      print('[FirebaseAdminAuthService] getUserByEmail error: $e');
      return (false, null);
    }
  }

  Future<(bool success, UserRecord? user)> updateUser(
    String uid, {
    String? password,
    bool? emailVerified,
  }) async {
    if (kFirebaseAuthBypass) return (false, null);
    try {
      return (
        true,
        await _firebaseApp.auth().updateUser(
              uid,
              password: password,
              emailVerified: emailVerified,
            ),
      );
    } catch (e) {
      print('[FirebaseAdminAuthService] updateUser error: $e');
      return (false, null);
    }
  }
}

/// Result of a Firebase ID token verification attempt.
sealed class TokenVerificationResult {
  const TokenVerificationResult();

  /// Token is valid.
  const factory TokenVerificationResult.verified({
    required String uid,
    required String email,
  }) = TokenVerified;

  /// Token is missing, malformed, expired, or otherwise invalid.
  static const invalid = TokenInvalid();

  /// The public-key fetch failed due to a network error. The token may be
  /// legitimate — the server just could not verify it right now.
  static const networkError = TokenNetworkError();
}

final class TokenVerified extends TokenVerificationResult {
  const TokenVerified({required this.uid, required this.email});
  final String uid;
  final String email;
}

final class TokenInvalid extends TokenVerificationResult {
  const TokenInvalid();
}

final class TokenNetworkError extends TokenVerificationResult {
  const TokenNetworkError();
}
