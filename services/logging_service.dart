import 'dart:async';

import '../storage/mongo_storage.dart';

/// Lightweight logging service. Prints to stdout and (optionally) persists
/// non-transient logs to the `system_logs` Mongo collection.
class LogService {
  static const _collection = 'system_logs';

  static void logRequest(String message) =>
      _log(message, '[REQUEST]', dontPermanentLog: true);

  static void logInfo(String message) =>
      _log(message, '[INFO]', dontPermanentLog: true);

  static void logWarning(String message) =>
      _log(message, '[WARNING]', dontPermanentLog: true);

  static void logSuccess(String message) =>
      _log(message, '[SUCCESS]', dontPermanentLog: true);

  static void logError(String message) => _log(message, '[ERROR]');

  static void logLogin(String message) => _log(message, '[LOGIN]');

  static void logNotice(String message) => _log(message, '[NOTICE]');

  static void _log(
    String message,
    String type, {
    bool dontPermanentLog = false,
  }) {
    print('$type: $message');

    if (dontPermanentLog) return;

    final data = <String, dynamic>{
      'type': type,
      'message': message,
      'server_time': DateTime.now().toUtc().toString(),
    };

    unawaited(_insert(data));
  }

  static Future<void> _insert(Map<String, dynamic> map) async {
    try {
      await MongoStorage.instance
          .use((db) => db.collection(_collection).insertOne(map));
    } catch (e) {
      print('[ERROR]: Failed to persist log > $e');
    }
  }
}
