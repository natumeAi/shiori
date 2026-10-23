import 'dart:collection';

/// Evicts the oldest sample without hiding the loss of evidence.
final class BoundedRing<T> {
  BoundedRing(this.capacity) {
    if (capacity < 1) throw ArgumentError.value(capacity, 'capacity');
  }
  final int capacity;
  final _values = ListQueue<T>();
  int overflow = 0;
  void add(T value) {
    if (_values.length == capacity) {
      _values.removeFirst();
      overflow++;
    }
    _values.add(value);
  }

  List<T> snapshot() => List.unmodifiable(_values);
  void clear() {
    _values.clear();
    overflow = 0;
  }
}
