import 'dart:developer';

extension IterableExtras<E> on Iterable<E> {
  E? getWhere(bool Function(E e) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

extension ListExtras<E> on List<E> {
  void addIfUnique(E e) {
    if (!contains(e)) add(e);
  }

  void testPrint(dynamic Function(int index, E e) stringFromElement) {
    for (int i = 0; i < length; i++) {
      final value = stringFromElement(i, this[i]);
      if (value != null) log(value.toString());
    }
  }

  E? get tryFirst => isEmpty ? null : first;

  E? tryGet(int index) => length > index ? this[index] : null;

  E? get tryLast => isEmpty ? null : last;

  E? get getIfOnlyOne => length == 1 ? first : null;
}
