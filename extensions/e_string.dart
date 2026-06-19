import 'package:mongo_dart/mongo_dart.dart';
import 'package:uuid/uuid.dart';

extension StringExtras on String {
  bool isValidEmail() {
    return RegExp(
      r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$',
    ).hasMatch(this);
  }

  bool isValidCellNumber() =>
      RegExp(r'^([0-9]{10})$').hasMatch(replaceAll(' ', ''));

  bool isValidPassword() => length >= 6;

  String ifEmpty(String value) => isEmpty ? value : this;

  String? get nullIfEmpty => isEmpty ? null : this;

  DateTime toDateTime() => DateTime.tryParse(this) ?? DateTime(2000);

  BsonBinary uuidToBsonBinary() => BsonBinary.from(
        Uuid.parse(this),
        subType: BsonBinary.subtypeUuid,
      );
}

extension StringNullableExtras on String? {
  bool get isEmptyOrNull => this == null || this!.isEmpty;
}
