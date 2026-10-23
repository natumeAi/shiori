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

  /// Returns the image to the cache; it may be evicted afterwards.
  void release() {
    if (_released) return;
    _released = true;
    _cache._release(_key);
  }
}

class _Entry {
  _Entry(this.image, this.bytes);

  final ui.Image image;
  final int bytes;
  int leases = 0;
}

/// Byte-bounded cache of decoded rasters and their intrinsic sizes.
///
/// Decoding happens only in [lease] during preparation. Entries with an
/// active lease are never evicted; unleased entries are dropped oldest first
/// once [totalBytes] exceeds [maxBytes]. A single lease larger than the
/// bound is still granted (and dropped as soon as it is released).
final class ReaderImageCache {
  ReaderImageCache({this.maxBytes = 48 * 1024 * 1024});

  final int maxBytes;
  final LinkedHashMap<String, _Entry> _entries = LinkedHashMap();
  final Map<String, ({double width, double height})?> _sizes = {};
  int _total = 0;

  int get totalBytes => _total;
  int get entryCount => _entries.length;

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
  }) async {
    ReaderWorkGuard.check(ReaderWork.imageDecode);
    final entryKey = '$key@${targetWidth}x$targetHeight';
    final existing = _entries.remove(entryKey);
    if (existing != null) {
      _entries[entryKey] = existing;
      existing.leases++;
      return ImageLease._(this, entryKey, existing.image, existing.bytes);
    }
    ui.Image image;
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        try {
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
    } on Object {
      return null;
    }
    final size = image.width * image.height * 4;
    final raced = _entries[entryKey];
    if (raced != null) {
      image.dispose();
      raced.leases++;
      return ImageLease._(this, entryKey, raced.image, raced.bytes);
    }
    final entry = _Entry(image, size)..leases = 1;
    _entries[entryKey] = entry;
    _total += size;
    _evict();
    return ImageLease._(this, entryKey, image, size);
  }

  void _release(String key) {
    final entry = _entries[key];
    if (entry == null) return;
    entry.leases--;
    _evict();
  }

  void _evict() {
    if (_total <= maxBytes) return;
    for (final key in _entries.keys.toList()) {
      if (_total <= maxBytes) break;
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
