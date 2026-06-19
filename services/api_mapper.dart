import 'dart:convert';

import '../constants/k.dart';
import '../extensions/e_list.dart';

extension APIMapperExtra on Map<String, dynamic> {
  T getEnum<T extends Enum>(String key, Iterable<T> values, T onErrorReturn) =>
      getEnumNullable(key, values) ?? onErrorReturn;

  T? getEnumNullable<T extends Enum>(String key, Iterable<T> values) {
    final name = getStringNullable(key);
    if (name == null) return null;
    return values.getWhere((e) => e.name == name);
  }

  /// Returns a String. If an error occurs or the key doesn't exist, it will
  /// return [onErrorReturn].
  String getString(String key, [String onErrorReturn = '']) =>
      this[key]?.toString() ?? onErrorReturn;

  /// If the key exists, will return a String, else null.
  String? getStringNullable(String key) => this[key]?.toString();

  /// Returns a bool. If an error occurs or the key doesn't exist, it will
  /// return [onErrorReturn]
  bool getBool(String key, [bool onErrorReturn = false]) =>
      !onErrorReturn ? _isTrue(this[key]) : !_isFalse(this[key]);

  /// If the key exists, will return a bool, else null.
  bool? getBoolNullable(String key) {
    if (_isTrue(this[key])) return true;
    if (_isFalse(this[key])) return false;
    return null;
  }

  bool _isTrue(dynamic value) =>
      value == true || value == 1 || value.toString().toLowerCase() == 'true';

  bool _isFalse(dynamic value) =>
      value == false || value == 0 || value.toString().toLowerCase() == 'false';

  DateTime getUTCDateTimeFromMillis(String key) {
    final millis = getIntNullable(key);
    return millis == null
        ? kDefaultDate
        : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  /// Returns an int. If an error occurs or the key doesn't exist, it will
  /// return [onErrorReturn]
  int getInt(String key, [int onErrorReturn = 0]) =>
      int.tryParse(this[key].toString()) ?? onErrorReturn;

  /// If the key exists, will return an int, else null.
  int? getIntNullable(String key) => int.tryParse(this[key].toString());

  /// Returns a double. If an error occurs or the key doesn't exist, it will
  /// return [onErrorReturn]
  double getDouble(String key, [double onErrorReturn = 0.0]) =>
      double.tryParse(this[key].toString()) ?? onErrorReturn;

  /// If the key exists, will return a double, else null.
  double? getDoubleNullable(String key) =>
      double.tryParse(this[key].toString());

  /// If the key exists, will return a DateTime, else default date returned.
  DateTime getDateTime(String key) =>
      DateTime.tryParse(this[key].toString()) ?? kDefaultDate;

  /// If the key exists, will return a DateTime, else null.
  DateTime? getDateTimeNullable(String key) =>
      DateTime.tryParse(this[key].toString());

  /// Returns a List<String>. Falls back to [onErrorReturn] or [].
  List<String> getStringList(String key, [List<String>? onErrorReturn]) =>
      getList<String>(key, onErrorReturn ?? [])!;

  /// If the key exists, will return a List<String>, else null.
  List<String>? getStringListNullable(String key) => getList<String>(key);

  /// Returns a List<int>. Falls back to [onErrorReturn] or [].
  List<int> getIntList(String key, [List<int>? onErrorReturn]) =>
      getList<int>(key, onErrorReturn ?? [])!;

  /// Returns a List<double>. Falls back to [onErrorReturn] or [].
  List<double> getDoubleList(String key, [List<double>? onErrorReturn]) =>
      getList<double>(key, onErrorReturn ?? [])!;

  List<T> getCustomList<T>(
    String key, {
    required T Function(Map<String, dynamic>) fromMap,
    List<T>? onErrorReturn,
  }) {
    final mapList = this[key];
    try {
      final List<dynamic> list = (mapList is String
          ? jsonDecode(mapList)
          : mapList) as List<dynamic>;
      final maps = list.cast<Map<String, dynamic>>();
      return maps.map(fromMap).toList();
    } catch (_) {}
    return onErrorReturn ?? [];
  }

  /// Returns a list of type [T]. Falls back to [onErrorReturn].
  List<T>? getList<T>(String key, [List<T>? onErrorReturn]) {
    try {
      final value = this[key];
      if (value is String) return (jsonDecode(value) as List).cast<T>();
      return (value as List?)?.cast<T>() ?? onErrorReturn;
    } catch (_) {}
    return onErrorReturn;
  }

  /// Returns a List<Map<String,dynamic>>. Falls back to [onErrorReturn] or [].
  List<Map<String, dynamic>> getMapList(
    String key, [
    List<Map<String, dynamic>>? onErrorReturn,
  ]) =>
      getList<Map<String, dynamic>>(
        key,
        onErrorReturn ?? <Map<String, dynamic>>[],
      )!;

  Map<String, dynamic> getMap(String key) =>
      getMapNullable(key) ?? <String, dynamic>{};

  Map<String, dynamic>? getMapNullable(String key) {
    try {
      var value = this[key];
      if (value is String) value = jsonDecode(value);
      if (value is Map<String, dynamic>) return value;
    } catch (_) {}
    return null;
  }

  T? getCustomObjectNullable<T>(
    String key,
    T Function(Map<String, dynamic>) fromMap,
  ) {
    final map = getMapNullable(key);
    return map == null ? null : fromMap(map);
  }

  T getCustomObject<T>(String key, T Function(Map<String, dynamic>) fromMap) =>
      getCustomObjectNullable(key, fromMap) ?? fromMap({});
}

extension StringMapExtras on Map<String, String> {
  String getString(String key, [String onErrorReturn = '']) =>
      this[key] ?? onErrorReturn;

  bool? getBoolNullable(String key) {
    final value = this[key]?.toLowerCase();
    if (value == 'true' || value == '1') return true;
    if (value == 'false' || value == '0') return false;
    return null;
  }

  bool getBool(String key, [bool onErrorReturn = false]) =>
      getBoolNullable(key) ?? onErrorReturn;
}

/// Convenience wrapper around a `Map<String, dynamic>` for safe extraction.
///
/// Storage models use this in their `fromMap` factories:
/// `final m = APIMapper(map); ... m.getString(keyX);`
class APIMapper {
  APIMapper(this.map);

  final Map<String, dynamic> map;

  T getEnum<T extends Enum>(String key, Iterable<T> values, T onErrorReturn) =>
      map.getEnum(key, values, onErrorReturn);

  T? getEnumNullable<T extends Enum>(String key, Iterable<T> values) =>
      map.getEnumNullable(key, values);

  String getString(String key, [String onErrorReturn = '']) =>
      map.getString(key, onErrorReturn);

  String? getStringNullable(String key) => map.getStringNullable(key);

  bool getBool(String key, [bool onErrorReturn = false]) =>
      map.getBool(key, onErrorReturn);

  bool? getBoolNullable(String key) => map.getBoolNullable(key);

  int getInt(String key, [int onErrorReturn = 0]) =>
      map.getInt(key, onErrorReturn);

  int? getIntNullable(String key) => map.getIntNullable(key);

  double getDouble(String key, [double onErrorReturn = 0.0]) =>
      map.getDouble(key, onErrorReturn);

  double? getDoubleNullable(String key) => map.getDoubleNullable(key);

  DateTime getDateTime(String key) => map.getDateTime(key);

  DateTime? getDateTimeNullable(String key) => map.getDateTimeNullable(key);

  List<String> getStringList(String key, [List<String>? onErrorReturn]) =>
      map.getStringList(key, onErrorReturn);

  List<String>? getStringListNullable(String key) =>
      map.getStringListNullable(key);

  List<int> getIntList(String key, [List<int>? onErrorReturn]) =>
      map.getIntList(key, onErrorReturn);

  List<double> getDoubleList(String key, [List<double>? onErrorReturn]) =>
      map.getDoubleList(key, onErrorReturn);

  List<T> getCustomList<T>(
    String key, {
    required T Function(Map<String, dynamic>) fromMap,
    List<T>? onErrorReturn,
  }) =>
      map.getCustomList(key, fromMap: fromMap, onErrorReturn: onErrorReturn);

  List<T>? getList<T>(String key, [List<T>? onErrorReturn]) =>
      map.getList(key, onErrorReturn);

  List<Map<String, dynamic>> getMapList(String key) => map.getMapList(key);

  Map<String, dynamic> getMap(String key) => map.getMap(key);

  Map<String, dynamic>? getMapNullable(String key) => map.getMapNullable(key);

  T? getCustomObjectNullable<T>(
    String key,
    T Function(Map<String, dynamic>) fromMap,
  ) =>
      map.getCustomObjectNullable(key, fromMap);

  T getCustomObject<T>(String key, T Function(Map<String, dynamic>) fromMap) =>
      map.getCustomObject(key, fromMap);
}
