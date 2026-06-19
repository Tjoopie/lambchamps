extension DateTimeExtras on DateTime {
  String get friendlyString => toString().substring(0, 19);

  bool between(DateTime start, DateTime end, {bool includeDates = true}) {
    return compareTo(start) >= 0 && compareTo(end) <= 0;
  }

  DateTime justDate() =>
      isUtc ? DateTime.utc(year, month, day) : DateTime(year, month, day);

  DateTime monthBeginning() =>
      isUtc ? DateTime.utc(year, month) : DateTime(year, month);

  /// Canonical string form for storing DateTimes in Mongo (UTC ISO-8601).
  String toMongoString() => toUtc().toIso8601String();

  DateTime get startOfMonth => DateTime(year, month);

  DateTime get startOfYear => DateTime(year);

  DateTime get dateOnly => DateTime(year, month, day);
}

extension NullableDateTimeExtras on DateTime? {
  bool? isBeforeOther(DateTime? other) {
    if (this == null && other == null) return null;
    if (this == null) return true;
    if (other == null) return false;
    return this!.isBefore(other);
  }

  bool? isAfterOther(DateTime? other) {
    if (this == null && other == null) return null;
    if (this == null) return false;
    if (other == null) return true;
    return this!.isAfter(other);
  }
}
