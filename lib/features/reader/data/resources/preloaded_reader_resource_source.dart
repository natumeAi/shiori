part of 'reader_resource_budget.dart';

/// A reservation pins cache hits and charges missing bytes before worker
/// transfer. [commit] takes ownership of exact-sized, detached byte buffers.
final class ReaderResourceReservation {
  ReaderResourceReservation._(
    this.session,
    this._existing,
    Map<String, int> missing,
    this._bytes,
  ) : missingLengths = Map.unmodifiable(missing);
  final ReaderResourceSession session;
  final Map<String, _ResourceEntry> _existing;
  final Map<String, int> missingLengths;
  final int _bytes;
  bool _done = false;

  PreloadedReaderResourceSource commit(
    Map<String, Uint8List> bytes, {
    Set<String> absent = const {},
    void Function(ReaderResourceMiss)? onMiss,
  }) {
    if (_done || session.isRetired) {
      throw const ReaderResourceException(ReaderResourceFailure.retired);
    }
    try {
      if (bytes.length != missingLengths.length ||
          missingLengths.entries.any(
            (entry) =>
                bytes[entry.key]?.length != entry.value ||
                bytes[entry.key]?.buffer.lengthInBytes != entry.value,
          )) {
        throw const ReaderResourceException(
          ReaderResourceFailure.invalidTransfer,
        );
      }
      final budget = session.budget;
      final entries = <String, _ResourceEntry>{..._existing};
      for (final entry in bytes.entries) {
        final value = _ResourceEntry(
          entry.value.asUnmodifiableView(),
          ++budget._clock,
        );
        entries[entry.key] = value;
        budget._entries[(session, entry.key)] = value;
        budget._retained += entry.value.length;
      }
      _finish();
      _existing.clear();
      final source = PreloadedReaderResourceSource._(
        session,
        entries,
        Set.unmodifiable(absent),
        onMiss,
      );
      session._sources.add(source);
      return source;
    } on Object {
      dispose();
      rethrow;
    }
  }

  void _finish() {
    _done = true;
    session.budget._reserved -= _bytes;
    for (final path in missingLengths.keys) {
      session.budget._pending.remove((session, path));
    }
    session._reservations.remove(this);
  }

  void dispose() {
    if (_done) return;
    _finish();
    for (final entry in _existing.entries) {
      if (--entry.value.leases == 0) {
        session.budget._remove((session, entry.key));
      }
    }
    _existing.clear();
  }
}

/// A section lease over preloaded entries only. No archive, reader callback,
/// worker port or fallback I/O is reachable through this adapter.
final class PreloadedReaderResourceSource implements ReaderResourceSource {
  PreloadedReaderResourceSource._(
    this.session,
    this._entries,
    this._absent,
    this._onMiss,
  );
  final ReaderResourceSession session;
  final Map<String, _ResourceEntry> _entries;
  final Set<String> _absent;
  void Function(ReaderResourceMiss)? _onMiss;
  bool _disposed = false;

  ReaderResourceMiss? miss(String path) {
    if (session.isRetired) return ReaderResourceMiss.retired;
    if (_disposed) return ReaderResourceMiss.disposed;
    if (_entries.containsKey(path)) return null;
    return _absent.contains(path)
        ? ReaderResourceMiss.absent
        : ReaderResourceMiss.notPreloaded;
  }

  _ResourceEntry? _find(String path) {
    final failure = miss(path);
    if (failure != null) {
      _onMiss?.call(failure);
      return null;
    }
    final entry = _entries[path]!;
    entry.used = ++session.budget._clock;
    return entry;
  }

  @override
  Uint8List? bytes(String path) => _find(path)?.bytes;
  @override
  bool contains(String path) => _find(path) != null;
  @override
  int size(String path) => _find(path)?.bytes.length ?? 0;

  /// Optional warm cache handoff. Releases all leases and retains entries only
  /// as unleased LRU candidates. The adapter cannot be read afterwards.
  void releaseToCache() => _release(evict: false);

  @override
  void dispose() => _release(evict: true);

  void _release({required bool evict}) {
    if (_disposed) return;
    _disposed = true;
    for (final entry in _entries.entries) {
      if (--entry.value.leases == 0 && evict) {
        session.budget._remove((session, entry.key));
      }
    }
    _entries.clear();
    session._sources.remove(this);
    // Do not retain a diagnostic owner through a disposed source.
    _onMiss = null;
  }
}
