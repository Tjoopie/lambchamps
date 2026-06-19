import 'dart:convert';

class JWTService {
  /// Decodes (does NOT verify) the payload section of a JWT.
  ///
  /// Use only for the dev auth bypass or for reading non-sensitive claims.
  /// Real verification is done by `FirebaseAdminAuthService.verifyIdToken`.
  static Map<String, dynamic>? decodePayload(String jwt) {
    try {
      final parts = jwt.split('.');

      if (parts.length != 3) {
        print('Invalid JWT');
        return null;
      }

      final payload = parts[1];
      final normalized = base64.normalize(payload);
      final decodedString = utf8.decode(base64.decode(normalized));

      return jsonDecode(decodedString) as Map<String, dynamic>;
    } catch (e) {
      print(e);
      return null;
    }
  }
}
