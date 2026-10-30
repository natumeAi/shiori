import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:shiori/features/reader/data/source/reader_work_guard.dart';

/// A decoded raster held by [ReaderImageCache] until released.
final class ImageLease {
  ImageLease._(this._cache, this._key, this.image, this.bytes);

  final ReaderImageCache _cache;
  final String _key;
  final ui.Image image;
  final int bytes;
  bool _released = false;

  /// Returns the image to the cache. Discard removes only this entry after its
  /// final lease returns, even when another holder releases without discard.
  void release({bool discard = false}) {
    if (_released) return;
    _released = true;
    _cache._release(_key, discard: discard);
  }
}

class _Entry {
  _Entry(this.image, this.bytes);

  final ui.Image image;
  final int bytes;
  int leases = 0;
  bool discard = false;
}

/// Capacity refusal is distinct from a malformed/missing optional raster.
final class ImageAdmissionException implements Exception {
  const ImageAdmissionException();
}

/// Output payload reserved by a complete fixed-unit plan before any decode.
/// Cache decodes exchange this credit for their intrinsic + output peak.
final class ImageReservation {
  ImageReservation._(this._cache, this._remaining);
  final ReaderImageCache _cache;
  int _remaining;
  bool _released = false;
  void _consume(int bytes) {
    if (_released || bytes > _remaining) throw const ImageAdmissionException();
    _remaining -= bytes;
    _cache._reservedBytes -= bytes;
  }

  void release() {
    if (_released) return;
    _released = true;
    _cache._reservedBytes -= _remaining;
    _remaining = 0;
  }
}

/// Byte-bounded cache of decoded rasters and their intrinsic sizes.
///
/// Decoding happens only in [lease] during preparation. Entries with an
/// active lease are never evicted; unleased entries are dropped oldest first
/// before a decode starts. Pending decode peaks share the retained byte cap;
/// an oversized image is refused before codec allocation.
final class ReaderImageCache {
  ReaderImageCache({this.maxBytes = 48 * 1024 * 1024});

  final int maxBytes;
  final LinkedHashMap<String, _Entry> _entries = LinkedHashMap();
  final Map<String, ({double width, double height})?> _sizes = {};
  int _total = 0;
  int _pendingBytes = 0;
  int _reservedBytes = 0;
  int _peakBytes = 0;

  int get totalBytes => _total + _pendingBytes + _reservedBytes;
  int get pendingBytes => _pendingBytes;
  int get entryCount => _entries.length;

  /// High-water committed bytes, including pending codec/output and credits.
  int get peakBytes => _peakBytes;
  void resetPeakBytes() => _peakBytes = totalBytes;
  void _observePeak() {
    if (totalBytes > _peakBytes) _peakBytes = totalBytes;
  }

  ImageReservation reserveOutput(int bytes) {
    if (bytes < 0) throw ArgumentError('Negative image reservation');
    _makeRoom(bytes);
    if (bytes > maxBytes - totalBytes) throw const ImageAdmissionException();
    _reservedBytes += bytes;
    _observePeak();
    return ImageReservation._(this, bytes);
  }

  /// Intrinsic pixel size without decoding the pixels, or null when the data
  /// is not a decodable image. Cached by [key].
  Future<({double width, double height})?> intrinsicSize(
    String key,
    Uint8List bytes,
  ) async {
    ReaderWorkGuard.check(ReaderWork.imageDecode);
    if (_sizes.containsKey(key)) return _sizes[key];
    ({double width, double height})? size;
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        size = (
          width: descriptor.width.toDouble(),
          height: descriptor.height.toDouble(),
        );
        descriptor.dispose();
      } finally {
        buffer.dispose();
      }
    } on Object {
      size = null;
    }
    _sizes[key] = size;
    return size;
  }

  /// Decodes [bytes] at no more than [targetWidth] x [targetHeight] device
  /// pixels (aspect preserved) and leases the result. Null when decoding
  /// fails.
  Future<ImageLease?> lease(
    String key,
    Uint8List bytes, {
    required int targetWidth,
    required int targetHeight,
    ImageReservation? reservation,
  }) async {
    ReaderWorkGuard.check(ReaderWork.imageDecode);
    if (targetWidth < 1 || targetHeight < 1) {
      throw ArgumentError('Image targets must be positive');
    }
    final entryKey = '$key@${targetWidth}x$targetHeight';
    if (reservation != null && !identical(reservation._cache, this)) {
      throw ArgumentError('Image reservation belongs to another owner');
    }
    final existing = _entries[entryKey];
    if (existing != null) {
      reservation?._consume(targetWidth * targetHeight * 4);
      _entries.remove(entryKey);
      _entries[entryKey] = existing;
      existing.leases++;
      return ImageLease._(this, entryKey, existing.image, existing.bytes);
    }
    if (targetWidth > maxBytes ~/ 4 ~/ targetHeight) {
      throw const ImageAdmissionException();
    }
    ui.Image? image;
    var reserved = 0;
    var pendingCharge = 0;
    var outputBound = 0;
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        try {
          // Conservative peak: full intrinsic decode plus requested output.
          // Admission occurs before instantiateCodec/getNextFrame. Keep both
          // old rasters and other in-flight decodes charged across every await.
          outputBound = targetWidth * targetHeight * 4;
          if (descriptor.height < 1 ||
              descriptor.width < 1 ||
              descriptor.width > maxBytes ~/ 4 ~/ descriptor.height) {
            throw const ImageAdmissionException();
          }
          reserved = descriptor.width * descriptor.height * 4 + outputBound;
          final credit = reservation == null ? 0 : outputBound;
          _makeRoom(reserved - credit);
          if (reserved - credit > maxBytes - totalBytes) {
            reserved = 0;
            throw const ImageAdmissionException();
          }
          reservation?._consume(outputBound);
          _pendingBytes += reserved;
          _observePeak();
          pendingCharge = reserved;
          final codec = await descriptor.instantiateCodec(
            targetWidth: targetWidth,
            targetHeight: targetHeight,
          );
          try {
            image = (await codec.getNextFrame()).image;
          } finally {
            codec.dispose();
          }
        } finally {
          descriptor.dispose();
        }
      } finally {
        buffer.dispose();
      }
    } on ImageAdmissionException {
      rethrow;
    } on Object {
      image?.dispose();
      return null;
    } finally {
      _pendingBytes -= pendingCharge;
    }
    final size = image.width * image.height * 4;
    if (size > outputBound || size > maxBytes - totalBytes) {
      image.dispose();
      throw const ImageAdmissionException();
    }
    final raced = _entries[entryKey];
    if (raced != null) {
      image.dispose();
      raced.leases++;
      return ImageLease._(this, entryKey, raced.image, raced.bytes);
    }
    final entry = _Entry(image, size)..leases = 1;
    _entries[entryKey] = entry;
    _total += size;
    _observePeak();
    _evict();
    return ImageLease._(this, entryKey, image, size);
  }

  void _release(String key, {bool discard = false}) {
    final entry = _entries[key];
    if (entry == null) return;
    entry.discard |= discard;
    entry.leases--;
    if (entry.discard && entry.leases == 0) {
      _entries.remove(key);
      _total -= entry.bytes;
      entry.image.dispose();
    }
    _evict();
  }

  void _evict() {
    _makeRoom(0);
  }

  void _makeRoom(int bytes) {
    if (totalBytes + bytes <= maxBytes) return;
    for (final key in _entries.keys.toList()) {
      if (totalBytes + bytes <= maxBytes) break;
      final entry = _entries[key]!;
      if (entry.leases > 0) continue;
      _entries.remove(key);
      _total -= entry.bytes;
      entry.image.dispose();
    }
  }

  /// Disposes every unleased entry.
  void clearUnleased() {
    for (final key in _entries.keys.toList()) {
      final entry = _entries[key]!;
      if (entry.leases > 0) continue;
      _entries.remove(key);
      _total -= entry.bytes;
      entry.image.dispose();
    }
  }
}
