import 'package:shiori/core/storage/cache_reservation.dart';

/// Shared removable-byte admission; callers serialize measurement and eviction.
/// A reservation stays charged until its bytes are measured on disk or removed.
final class CacheBudget {
  CacheBudget({this.limit = 512 * 1024 * 1024}) {
    if (limit < 1) throw ArgumentError('Invalid cache limit');
  }

  final int limit;
  int _reserved = 0;
  int get reservedBytes => _reserved;

  bool fits(int bytes, int usedBytes) => usedBytes + _reserved + bytes <= limit;

  CacheReservation reserve(int bytes, {required int usedBytes}) {
    if (bytes < 0 || !fits(bytes, usedBytes)) {
      throw StateError('Cache reservation requires prior admission');
    }
    _reserved += bytes;
    return CacheReservation(bytes, () => _reserved -= bytes);
  }
}
