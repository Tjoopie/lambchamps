import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../constants/k.dart';

/// Decodes and verifies judge submission payloads produced by the Flutter
/// client (`payload_codec.dart`). The transfer string format is:
///
///   `LC1:{base64url-no-padding(zlib(compactJson))}:{hmac8}`
///
/// where `hmac8` is the first 8 hex chars of
/// `HMAC-SHA256(kSubmissionSigningSecret, <compact JSON string>)`.
///
/// Chunked (`LC1C:`) payloads are reassembled client-side; this codec only
/// handles the final single `LC1:` string.
class SubmissionCodec {
  SubmissionCodec._();

  /// Decodes and integrity-checks [payload]. Returns the parsed compact-JSON
  /// map on success, or throws [SubmissionCodecError] on any failure.
  static Map<String, dynamic> decodeAndVerify(String payload) {
    final raw = payload.trim();
    const prefix = '$kPayloadPrefix:';
    if (!raw.startsWith(prefix)) {
      throw const SubmissionCodecError('Unrecognised payload (bad prefix)');
    }

    // Strip the prefix, then split the trailing `:hmac8` from the data.
    final body = raw.substring(prefix.length);
    final lastColon = body.lastIndexOf(':');
    if (lastColon <= 0) {
      throw const SubmissionCodecError('Malformed payload (missing checksum)');
    }
    final data = body.substring(0, lastColon);
    final hmac8 = body.substring(lastColon + 1);
    if (hmac8.isEmpty) {
      throw const SubmissionCodecError('Malformed payload (empty checksum)');
    }

    final String jsonString;
    try {
      final compressed = base64Url.decode(_repad(data));
      jsonString = utf8.decode(zlib.decode(compressed));
    } catch (_) {
      throw const SubmissionCodecError('Could not decode payload');
    }

    final expected = _hmac8(jsonString);
    if (expected != hmac8.toLowerCase()) {
      throw const SubmissionCodecError(
        'Checksum mismatch — payload tampered or signed with a different secret',
      );
    }

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) return decoded;
      throw const SubmissionCodecError('Payload JSON is not an object');
    } on SubmissionCodecError {
      rethrow;
    } catch (_) {
      throw const SubmissionCodecError('Payload JSON is invalid');
    }
  }

  /// First 8 hex chars of HMAC-SHA256(secret, [jsonString]).
  static String _hmac8(String jsonString) {
    final mac = Hmac(sha256, utf8.encode(kSubmissionSigningSecret));
    return mac.convert(utf8.encode(jsonString)).toString().substring(0, 8);
  }

  /// Restores base64url `=` padding stripped by the client encoder.
  static String _repad(String value) {
    final remainder = value.length % 4;
    if (remainder == 0) return value;
    return value.padRight(value.length + (4 - remainder), '=');
  }
}

/// Raised when a submission payload cannot be decoded or fails verification.
class SubmissionCodecError implements Exception {
  const SubmissionCodecError(this.message);
  final String message;

  @override
  String toString() => 'SubmissionCodecError: $message';
}
