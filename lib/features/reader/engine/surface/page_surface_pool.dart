import 'dart:ui' as ui;

import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/engine/layout/image_cache.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/pagination/page_painter.dart';
import 'package:shiori/features/reader/engine/pagination/page_plan.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';

/// A lease owns one reference; the last release disposes the retained picture.
final class PageSurfaceLease {
  PageSurfaceLease._(this._pool, this.surface);
  final PageSurfacePool _pool;
  final PreparedPageSurface surface;
  bool _released = false;
  bool get released => _released;
  PageSurfaceLease retain() {
    if (_released || surface.disposed) throw StateError('Expired page surface');
    surface._references++;
    return PageSurfaceLease._(_pool, surface);
  }

  void release() {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    if (_released) return;
    _released = true;
    if (--surface._references == 0) _pool._dispose(surface);
  }
}

final class PreparedPageSurface {
  PreparedPageSurface._(
    this.section,
    this.pageIndex,
    this.picture,
    this._images,
  );
  final PreparedSection section;
  final int pageIndex;
  final ui.Picture picture;
  final Map<int, ImageLease> _images;
  int _references = 1;
  bool disposed = false;
  int get pictureBytes => picture.approximateBytesUsed;
  String get identity => section.pages[pageIndex].map.identity;
}

/// Three presented pages plus one preparation/handoff reserve. No idle pictures
/// are cached: a released page returns its bytes immediately. Pending records
/// occupy the same owner budget, including through cancellation and close.
final class PageSurfacePool {
  PageSurfacePool({
    this.maxPictureBytes = 16 * 1024 * 1024,
    this.maxImageBytes = 48 * 1024 * 1024,
  }) : images = ReaderImageCache(maxBytes: maxImageBytes);
  static const presentedCapacity = 3;
  static const reserve = 1;
  static const capacity = presentedCapacity + reserve;
  final int maxPictureBytes;
  final int maxImageBytes;
  final ReaderImageCache images;
  final Set<PreparedPageSurface> _live = {};
  int _pending = 0;
  int _pictureBytes = 0;
  int _epoch = 0;
  bool _closed = false;
  int peakOwners = 0;
  int get liveSurfaces => _live.length;
  int get owners => liveSurfaces + _pending;
  int get pictureBytes => _pictureBytes;

  Future<PageSurfaceLease?> prepare(
    PreparedSection section,
    int pageIndex,
    PagePaintTheme theme,
  ) async {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    if (_closed || owners >= capacity) return null;
    final epoch = _epoch;
    _pending++;
    if (owners > peakOwners) peakOwners = owners;
    final leases = <int, ImageLease>{};
    ui.Picture? picture;
    var transferred = false;
    try {
      for (final fragment in section.pages[pageIndex].fragments) {
        if (fragment is! BoxFragment) continue;
        final block = section.blocks[fragment.blockIndex].block;
        if (block is! ImageBlock ||
            block.resourcePath == null ||
            leases.containsKey(block.index)) {
          continue;
        }
        final bytes = section.archive.bytes(block.resourcePath!);
        if (bytes == null) continue;
        final dpr = section.identity.devicePixelRatio;
        final lease = await images.lease(
          '${section.identity.contentId}:${block.resourcePath}',
          bytes,
          targetWidth: (fragment.width * dpr).ceil().clamp(1, 8192),
          targetHeight: (fragment.height * dpr).ceil().clamp(1, 8192),
        );
        if (lease != null) leases[block.index] = lease;
      }
      if (_closed || epoch != _epoch || images.totalBytes > maxImageBytes) {
        return null;
      }
      picture = PagePainter.record(
        section,
        pageIndex,
        theme,
        imageOf: (i) => leases[i],
      );
      final size = picture.approximateBytesUsed;
      if (_pictureBytes + size > maxPictureBytes) return null;
      final surface = PreparedPageSurface._(
        section,
        pageIndex,
        picture,
        leases,
      );
      _live.add(surface);
      _pictureBytes += size;
      transferred = true;
      return PageSurfaceLease._(this, surface);
    } finally {
      _pending--;
      if (!transferred) {
        picture?.dispose();
        for (final lease in leases.values) {
          lease.release();
        }
        images.clearUnleased();
      }
    }
  }

  void _dispose(PreparedPageSurface surface) {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    if (!_live.remove(surface)) return;
    _pictureBytes -= surface.pictureBytes;
    surface.disposed = true;
    surface.picture.dispose();
    for (final lease in surface._images.values) {
      lease.release();
    }
    surface._images.clear();
    images.clearUnleased();
  }

  /// Existing leases stay valid until released; pending work cannot publish.
  void close() {
    _closed = true;
    _epoch++;
    images.clearUnleased();
  }
}
