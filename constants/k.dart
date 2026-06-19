import 'package:uuid/uuid.dart';

// ---------------------------------------------------------------------------
// Mongo document keys (shared across all storage models)
// ---------------------------------------------------------------------------
const kKeyID = '_id';
const kKeyIsDeleted = 'deleted';
const kKeyCreatedAt = 'created_at';
const kKeyUpdatedAt = 'updated_at';
const kKeyServerUpdatedAt = 'server_updated_at';

// ---------------------------------------------------------------------------
// Environment
// ---------------------------------------------------------------------------

/// Master prod/dev flag. Keep `false` while developing locally.
const kIsProd = false;

/// While `true`, Firebase ID-token verification is bypassed and the token is
/// trusted as-is (decoded, not verified). Keep `true` for local dev until the
/// Firebase service account is provisioned, then set to `false`.
const kFirebaseAuthBypass = true;

// ---------------------------------------------------------------------------
// Submission (QR) payload
// ---------------------------------------------------------------------------

/// Magic prefix / schema tag on encoded submission payloads (`LC1:{data}:{hmac8}`).
const kPayloadPrefix = 'LC1';

/// Shared secret for HMAC-SHA256 signing of submission payloads. MUST match the
/// client's `K.submissionSigningSecret`. This dev value is used while there is
/// no secure per-login secret delivery — replace with a securely delivered
/// secret before production.
const kSubmissionSigningSecret = 'lamb-champs-dev-secret';

final kDefaultDate = DateTime.utc(1900);

String newUuid() => const Uuid().v4();

/// Firebase Admin service account for token verification.
///
/// Replace with the real Lamb Champs Firebase service account JSON once
/// provisioned. Until then `kFirebaseAuthBypass` should remain `true` so this
/// is never used.
const kFirebaseServiceAccount = <String, dynamic>{
  'type': 'service_account',
  'project_id': 'lamb-champs-placeholder',
  'private_key_id': 'REPLACE_ME',
  'private_key': '-----BEGIN PRIVATE KEY-----\nREPLACE_ME\n-----END PRIVATE KEY-----\n',
  'client_email': 'REPLACE_ME@lamb-champs-placeholder.iam.gserviceaccount.com',
  'client_id': 'REPLACE_ME',
  'auth_uri': 'https://accounts.google.com/o/oauth2/auth',
  'token_uri': 'https://oauth2.googleapis.com/token',
  'auth_provider_x509_cert_url': 'https://www.googleapis.com/oauth2/v1/certs',
  'client_x509_cert_url': 'https://www.googleapis.com/robot/v1/metadata/x509/REPLACE_ME',
  'universe_domain': 'googleapis.com',
};

class K {
  K._();

  static const appName = 'Lamb Champs API';
  static const version = '1.0.0';
}
