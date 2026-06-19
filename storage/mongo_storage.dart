import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:mongo_dart/mongo_dart.dart';

import '../constants/k.dart';

export 'package:mongo_dart/mongo_dart.dart';

class MongoStorage {
  static const defaultUseTimeoutSeconds = 15;
  static final instance = MongoStorage._(_resolveConnectionString());

  /// Resolves the Mongo connection string.
  ///
  /// In any deployed environment the URI is injected via the `MONGO_URI`
  /// environment variable (delivered as a DevCockpit app secret), so no
  /// credentials live in source. When unset, falls back to a local Docker
  /// Mongo for development.
  static String _resolveConnectionString() {
    final fromEnv = Platform.environment['MONGO_URI']?.trim();
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return kIsProd
        ? 'mongodb://localhost:27017/v2_prod'
        : 'mongodb://localhost:27017/v2_dev';
  }

  /// If null, the database hasn't been opened yet
  Db? _db;

  final String connectionString;

  MongoStorage._(this.connectionString);

  Completer<void>? _busyOpening;

  bool get isConnected => _db?.isConnected ?? false;

  /// Opens the database (creates it if it doesn't exist)
  Future<void> safeInitDatabase() async {
    if (_db?.isConnected ?? false) return;
    if (_busyOpening != null) return _busyOpening!.future;
    final completer = Completer<void>();
    _busyOpening = completer;
    print('MongoStorage.safeInitDatabase() > Running');

    try {
      try {
        if (_db != null) {
          print(
            'Closing old db: ${(isConnected: _db?.isConnected, state: _db?.state)}',
          );
          await _db?.close();
        }
      } catch (e) {
        print('MongoStorage.safeInitDatabase() > ERROR closing old db > $e');
      }
      final db = await Db.create(connectionString);
      // TLS only for Atlas (mongodb+srv). Local Docker Mongo speaks plain TCP.
      await db.open(secure: connectionString.startsWith('mongodb+srv'));
      print(
        'MongoStorage.safeInitDatabase() > db opened: ${(isConnected: db.isConnected, state: db.state)}',
      );
      _db = db;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      completer.complete();
    } catch (e, s) {
      print('MongoStorage.safeInitDatabase() > ERROR Opening db > $e');
      completer.completeError(e, s);
      // Mark the completer's future as handled so an unawaited caller (server
      // init) doesn't crash the VM with an unhandled async error when the DB
      // is unreachable.
      completer.future.ignore();
      rethrow;
    } finally {
      _busyOpening = null;
    }
  }

  Future<void> close() async {
    final db = _db;
    if (db == null) return;
    try {
      _db = null;
      await db.close();
    } catch (e) {
      print('MongoStorage.close() > ERROR closing db > $e');
    } finally {
      _db = null;
    }
  }

  Future<Db> _getOpenDb() async {
    await safeInitDatabase();
    final db = _db;
    if (db == null || !db.isConnected) {
      throw Exception('MongoStorage.getOpenDb() > Database is not connected');
    }
    return db;
  }

  Future<S> use<S>(
    Future<S> Function(Db db) function, {
    int retries = 1,
    int initialTimeoutSeconds = defaultUseTimeoutSeconds,
  }) async {
    final maxAttempts = max(retries, 0) + 1;
    late (Object error, StackTrace stack) lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        if (attempt > 1) {
          // Exponential backoff: 1s, 2s, 4s, 8s...
          await Future<void>.delayed(Duration(seconds: 1 << (attempt - 2)));
        }

        final timeoutDuration = Duration(
          seconds: initialTimeoutSeconds * attempt,
        );
        final db = await _getOpenDb();
        return function(db).timeout(timeoutDuration);
      } catch (e, s) {
        lastError = (e, s);
        print('MongoStorage.use() [$attempt] > function Error: $e, $s');
        // Attempt to reopen if needed
        unawaited(safeInitDatabase());
      }
    }

    print('MongoStorage.use() > Failed after $maxAttempts attempt(s)');
    Error.throwWithStackTrace(lastError.$1, lastError.$2);
  }
}
