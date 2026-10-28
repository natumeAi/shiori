import 'dart:ui' as ui;

import 'package:shiori/features/reader/data/layout/section_rendition.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';

/// Independent section/file/worker ownership acquired by A3 before planning.
/// The document/styles are retained by this object; encoded buffers by resources.
final class FixedSourceLease {
  FixedSourceLease({
    required this.page,
    required this.document,
    required this.styles,
    required this.rendition,
    required this.resources,
    required this.retainedSourceBytes,
    required this.releaseSource,
    Map<String, FixedImageRequest> images = const {},
  }) : images = Map.unmodifiable(images) {
    if (retainedSourceBytes < 0) throw ArgumentError('Negative source bytes');
  }
  final SourcePageId page;
  final SourceDocument document;
  final CssStyledDocument styles;
  final SectionRendition rendition;
  final ReaderResourceSource resources;
  final int retainedSourceBytes;
  final Map<String, FixedImageRequest> images;

  /// Nonthrowing final release of the independently retained source owners.
  final void Function() releaseSource;
  bool _disposed = false;
  bool _transferred = false;
  bool get isDisposed => _disposed;
  void requireLive() {
    if (isDisposed) throw StateError('Fixed source disposed');
  }

  void transfer() {
    requireLive();
    if (_transferred) throw StateError('Fixed source already transferred');
    _transferred = true;
  }

  void dispose() {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    if (_disposed) return;
    _disposed = true;
    try {
      resources.dispose();
    } finally {
      releaseSource();
    }
  }
}

/// Dimensions come from A3's encoded-resource inspection, before decode.
/// acquire must complete only after its physical decode has settled, even on
/// cancellation. A late returned lease is destroyed before reservations release.
final class FixedImageRequest {
  FixedImageRequest({
    required this.width,
    required this.height,
    required this.acquire,
  }) {
    if (width <= 0 || height <= 0) throw ArgumentError('Invalid image bounds');
  }
  final int width, height;
  final Future<FixedImageLease> Function(PublicationCancellation) acquire;
}

final class FixedImageLease {
  FixedImageLease(this.image, void Function() release) : _release = release;
  final ui.Image image;
  void Function()? _release;
  void dispose() {
    final release = _release;
    _release = null;
    release?.call();
  }
}
