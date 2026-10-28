import 'dart:collection';
import 'dart:typed_data';

import 'package:shiori/features/reader/engine/motion/turn_session.dart';

/// Fixed numeric storage. Motion writes never serialize or materialize maps.
/// Snapshots are lazy, immutable and retain their own sealed storage on reset.
final class ReaderEventBuffer {
  ReaderEventBuffer(this.capacity) {
    if (capacity < 1) throw ArgumentError.value(capacity, 'capacity');
    _rows = _Rows(capacity);
  }
  static final submission = TurnTimingEvent.values.length;
  static final firstSubmission = submission + 1;
  static final preparationStart = submission + 2;
  static final preparationEnd = submission + 3;
  final int capacity;
  late _Rows _rows;
  int _head = 0, _count = 0;
  int overflow = 0;
  bool _sealed = false;
  int get materializedRows => _rows.materialized;
  int get numericBytes => capacity * 90; // 10 int64 + double + 2 uint8.

  void add({
    required int kind,
    required int sequence,
    required int monotonicUs,
    int generation = 0,
    int activeGeneration = 0,
    int? epoch,
    int queueOrFrame = 0,
    int? inputId,
    double value = 0,
    int section = 0,
    int page = 0,
    int layoutGeneration = 0,
    String? pageIdentity,
    bool cacheHit = false,
  }) {
    if (_sealed) throw StateError('Reset sealed event buffer before writing');
    final index = (_head + _count) % capacity;
    final base = index * 10;
    final integers = _rows.integers;
    integers[base] = sequence;
    integers[base + 1] = monotonicUs;
    integers[base + 2] = generation;
    integers[base + 3] = activeGeneration;
    integers[base + 4] = epoch ?? -1;
    integers[base + 5] = queueOrFrame;
    integers[base + 6] = inputId ?? 0;
    integers[base + 7] = section;
    integers[base + 8] = page;
    integers[base + 9] = layoutGeneration;
    _rows.values[index] = value;
    _rows.kinds[index] = kind;
    _rows.cacheHits[index] = cacheHit ? 1 : 0;
    _rows.identities[index] = pageIdentity;
    if (_count == capacity) {
      _head = (_head + 1) % capacity;
      overflow++;
    } else {
      _count++;
    }
  }

  List<Map<String, Object?>> snapshot({bool seal = false}) {
    if (seal || _sealed) {
      _sealed = true;
      return _Snapshot(_rows, _head, _count, capacity);
    }
    // Explicit mid-capture inspection is off the recording path. Copy only
    // live rows so inspection neither seals nor exposes mutable storage.
    final copy = _Rows(_count);
    for (var i = 0; i < _count; i++) {
      final slot = (_head + i) % capacity;
      copy.integers.setRange(i * 10, (i + 1) * 10, _rows.integers, slot * 10);
      copy.values[i] = _rows.values[slot];
      copy.kinds[i] = _rows.kinds[slot];
      copy.cacheHits[i] = _rows.cacheHits[slot];
      copy.identities[i] = _rows.identities[slot];
    }
    return _Snapshot(copy, 0, _count, _count);
  }

  void clear() {
    // Allocation happens at capture start, never in add(). Repeated captures
    // cannot overwrite a previously exported/saved record's lazy snapshot.
    if (_sealed) _rows = _Rows(capacity);
    _sealed = false;
    _head = _count = overflow = 0;
  }

  void dispose() {
    _rows = _Rows(0);
    _sealed = true;
    _head = _count = overflow = 0;
  }
}

final class _Rows {
  _Rows(int capacity)
    : integers = Int64List(capacity * 10),
      values = Float64List(capacity),
      kinds = Uint8List(capacity),
      cacheHits = Uint8List(capacity),
      identities = List<String?>.filled(capacity, null);
  final Int64List integers;
  final Float64List values;
  final Uint8List kinds, cacheHits;
  final List<String?> identities;
  int materialized = 0;
}

final class _Snapshot extends ListBase<Map<String, Object?>> {
  _Snapshot(this.rows, this.head, this.length, this.capacity);
  final _Rows rows;
  final int head, capacity;
  @override
  final int length;
  @override
  set length(int value) => throw UnsupportedError('Immutable event snapshot');
  @override
  void operator []=(int index, Map<String, Object?> value) =>
      throw UnsupportedError('Immutable event snapshot');
  @override
  Map<String, Object?> operator [](int index) {
    RangeError.checkValidIndex(index, this);
    rows.materialized++;
    final slot = (head + index) % capacity;
    final base = slot * 10;
    int field(int offset) => rows.integers[base + offset];
    final kind = rows.kinds[slot];
    final normal = kind < ReaderEventBuffer.submission;
    final preparation = kind >= ReaderEventBuffer.preparationStart;
    return Map.unmodifiable({
      'sequence': field(0),
      'event': normal
          ? TurnTimingEvent.values[kind].name
          : kind == ReaderEventBuffer.submission
          ? 'motionSubmission'
          : kind == ReaderEventBuffer.firstSubmission
          ? 'firstMotionSubmission'
          : kind == ReaderEventBuffer.preparationStart
          ? 'sectionPreparationStart'
          : 'sectionPreparationEnd',
      'monotonicUs': field(1),
      if (!preparation) ...{
        'generation': field(2),
        'captureEpoch': field(4) == -1 ? null : field(4),
        'inputId': field(6) == 0 ? null : field(6),
        if (normal) ...{
          'turnClockMs': rows.values[slot],
          'activeGeneration': field(3),
          'queueDepth': field(5),
        } else ...{
          'frameNumber': field(5),
          if (kind == ReaderEventBuffer.submission) 'offset': rows.values[slot],
        },
      } else ...{
        'section': field(7),
        'cacheHit': rows.cacheHits[slot] == 1,
      },
      if (rows.identities[slot] case final identity?)
        'destination': {
          'sectionIndex': field(7),
          'pageIndex': field(8),
          'layoutGeneration': field(9),
          'pageIdentity': identity,
        },
    });
  }
}
