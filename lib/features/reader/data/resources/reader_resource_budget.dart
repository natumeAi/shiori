import 'dart:typed_data';

import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';

part 'preloaded_reader_resource_source.dart';

enum ReaderResourceFailure { budgetExceeded, busy, retired, invalidTransfer }

final class ReaderResourceException implements Exception {
  const ReaderResourceException(this.failure);
  final ReaderResourceFailure failure;
}

/// Encoded-byte accounting, including in-flight reservations. This is not a
/// decoded-image/font or process-RSS budget. Inject smaller limits in tests.
final class ReaderResourceBudget {
  ReaderResourceBudget({this.maxBytes = defaultMaxBytes}) {
    if (maxBytes < 0 || maxBytes > defaultMaxBytes) {
      throw ArgumentError.value(maxBytes, 'maxBytes');
    }
  }

  static const defaultMaxBytes = 128 * 1024 * 1024;
  static final shared = ReaderResourceBudget();
  final int maxBytes;
  final Map<(ReaderResourceSession, String), _ResourceEntry> _entries = {};
  final Set<(ReaderResourceSession, String)> _pending = {};
  int _retained = 0;
  int _reserved = 0;
  int _clock = 0;

  int get retainedBytes => _retained;
  int get reservedBytes => _reserved;
  int get accountedBytes => _retained + _reserved;
  int get entryCount => _entries.length;

  ReaderResourceSession createSession() => ReaderResourceSession._(this);

  void _remove((ReaderResourceSession, String) key) {
    final entry = _entries.remove(key);
    if (entry != null) _retained -= entry.bytes.length;
  }
}

/// One worker publication generation. Retirement revokes even live adapters
/// and reservations, so an A -> B -> A transition cannot reuse old resources.
final class ReaderResourceSession {
  ReaderResourceSession._(this.budget);
  final ReaderResourceBudget budget;
  final Set<ReaderResourceReservation> _reservations = {};
  final Set<PreloadedReaderResourceSource> _sources = {};
  bool _retired = false;
  bool get isRetired => _retired;

  ReaderResourceReservation reserve(Map<String, int> lengths) {
    if (_retired) {
      throw const ReaderResourceException(ReaderResourceFailure.retired);
    }
    final sizes = Map<String, int>.unmodifiable(lengths);
    var needed = 0;
    final existing = <String, _ResourceEntry>{};
    final missing = <String, int>{};
    for (final path in sizes.keys) {
      final length = sizes[path]!;
      if (length < 0) {
        throw const ReaderResourceException(
          ReaderResourceFailure.invalidTransfer,
        );
      }
      final key = (this, path);
      if (budget._pending.contains(key)) {
        throw const ReaderResourceException(ReaderResourceFailure.busy);
      }
      final entry = budget._entries[key];
      if (entry != null) {
        if (entry.bytes.length != length) {
          throw const ReaderResourceException(
            ReaderResourceFailure.invalidTransfer,
          );
        }
        existing[path] = entry;
      } else {
        missing[path] = length;
        needed += length;
      }
    }
    final candidates =
        budget._entries.entries
            .where(
              (entry) =>
                  entry.value.leases == 0 &&
                  !existing.containsValue(entry.value),
            )
            .toList()
          ..sort((a, b) => a.value.used.compareTo(b.value.used));
    var available = budget.maxBytes - budget.accountedBytes;
    final evictions = <(ReaderResourceSession, String)>[];
    for (final candidate in candidates) {
      if (available >= needed) break;
      available += candidate.value.bytes.length;
      evictions.add(candidate.key);
    }
    if (available < needed) {
      throw const ReaderResourceException(ReaderResourceFailure.budgetExceeded);
    }
    for (final key in evictions) {
      budget._remove(key);
    }
    for (final entry in existing.values) {
      entry.leases++;
      entry.used = ++budget._clock;
    }
    budget._reserved += needed;
    budget._pending.addAll(missing.keys.map((path) => (this, path)));
    final reservation = ReaderResourceReservation._(
      this,
      existing,
      missing,
      needed,
    );
    _reservations.add(reservation);
    return reservation;
  }

  void retire() {
    if (_retired) return;
    _retired = true;
    for (final reservation in _reservations.toList()) {
      reservation.dispose();
    }
    for (final source in _sources.toList()) {
      source.dispose();
    }
    for (final key
        in budget._entries.keys
            .where((key) => identical(key.$1, this))
            .toList()) {
      budget._remove(key);
    }
  }
}

final class _ResourceEntry {
  _ResourceEntry(this.bytes, this.used);
  final Uint8List bytes;
  int used;
  int leases = 1;
}
