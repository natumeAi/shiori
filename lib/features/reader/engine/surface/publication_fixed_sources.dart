import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:shiori/core/config/content_identity.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/features/library/data/publications/prepare_book_queue.dart';
import 'package:shiori/features/library/data/publications/prepared_book.dart';
import 'package:shiori/features/library/data/publications/publication_lease.dart';
import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/epub/epub_package.dart';
import 'package:shiori/features/reader/data/epub/epub_url.dart';
import 'package:shiori/features/reader/data/layout/authored_dimension_resolver.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/layout/section_rendition.dart';
import 'package:shiori/features/reader/data/layout/section_source_facts.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/worker/preloaded_publication_section.dart';
import 'package:shiori/features/reader/data/worker/prepared_publication.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_exception.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/pagination/layout_identity.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';
import 'package:shiori/features/reader/engine/surface/fixed_unit_navigation.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/reader_publication_lifetime.dart';

/// Production fixed/mixed source owner built from the S3 prepared publication.
///
/// It holds one independent file/worker lease (the existing
/// [ReaderPublicationLifetime]) and one root [EpubBook] opened from that exact
/// immutable path. Section documents/resources come from the existing worker
/// preload; the root book is only used by the existing reflow style resolver so
/// fixed sections get the real fixed-profile [CssStyledDocument]. There is no
/// second parser, cascade or resource graph.
final class PublicationFixedSources {
  PublicationFixedSources._(
    this.identity,
    this.layoutFacts,
    this.book,
    this._lifetime,
    this._pool,
    this._fonts,
    this._layoutFor,
    this._sectionBaseFor,
    this._generation,
  ) {
    unitSources = FixedUnitSources(
      loadSource: _loadSource,
      layoutFor: _layoutFor,
      sectionBaseFor: _sectionBaseFor,
      fonts: _fonts,
    );
  }

  final ContentIdentity identity;
  final PublicationLayoutFacts layoutFacts;
  final EpubBook book;
  final ReaderPublicationLifetime _lifetime;
  final PageSurfacePool _pool;
  final FontRegistry _fonts;
  final LayoutIdentity Function(int) _layoutFor;
  final String Function(SourcePageId) _sectionBaseFor;
  final int _generation;
  late final FixedUnitSources unitSources;

  bool _enabled = true;
  Future<void>? _bookClose;
  int _liveSources = 0;
  int _pendingLoads = 0;
  Completer<void>? _loadsDrained;
  Future<void>? _closed;

  bool get isActive => _enabled && _lifetime.isActive;

  /// The independent file/worker pin, shared with the prepared session so its
  /// close drains motion/surfaces before detach and file release.
  ReaderPublicationLifetime get publication => _lifetime;

  int get retainedSourceOwners => _liveSources;

  /// Acquires the independent file/worker pin before opening the immutable path.
  /// The route [preparedBook] may be released after this returns.
  static Future<PublicationFixedSources> open({
    required PreparedBook preparedBook,
    required ServerSession activation,
    required LayoutIdentity layout,
    required bool Function() isCurrent,
    required Future<PublicationLease?> Function() acquireLease,
    required PrepareBookQueue queue,
    required Future<PublicationWorker> Function() worker,
    required PageSurfacePool pool,
    required FontRegistry fonts,
    required LayoutIdentity Function(int section) layoutFor,
    required String Function(SourcePageId page) sectionBaseFor,
    PublicationCancellation? cancellation,
  }) async {
    final path = preparedBook.lease.local.path;
    final lifetime = await ReaderPublicationLifetime.open(
      preparedBook: preparedBook,
      activation: activation,
      layout: layout,
      isCurrent: isCurrent,
      acquireLease: acquireLease,
      queue: queue,
      worker: worker,
      cancellation: cancellation,
    );
    EpubBook? book;
    try {
      if (!isCurrent() || (cancellation?.isCanceled ?? false)) {
        throw const PreparationCancelled();
      }
      book = _openBook(path);
      if (!isCurrent() || (cancellation?.isCanceled ?? false)) {
        throw const PreparationCancelled();
      }
      return PublicationFixedSources._(
        preparedBook.identity,
        preparedBook.layoutFacts,
        book,
        lifetime,
        pool,
        fonts,
        layoutFor,
        sectionBaseFor,
        activation.generation,
      );
    } on Object {
      book?.archive.close();
      await lifetime.close(
        disableAndInvalidate: () {},
        cancelAndDrain: () async {},
        disposeScenesAndSources: () async {},
      );
      rethrow;
    }
  }

  static EpubBook _openBook(String path) {
    final archive = EpubArchive.openFile(path);
    try {
      return EpubBook.fromArchive(archive, readEpubPackage(archive));
    } on Object {
      archive.close();
      rethrow;
    }
  }

  Future<FixedSourceLease> _loadSource(SourcePageId page) async {
    if (!isActive) throw const PreparationCancelled();
    if (page.content != identity) {
      throw ArgumentError('Fixed source identity mismatch');
    }
    final generation = _generation;
    final section = page.sectionIndex;
    if (section < 0 || section >= book.sections.length) {
      throw ArgumentError('Fixed source section is outside the publication');
    }
    final expected = _layoutFor(section);
    if (expected.contentId != identity.sha256 ||
        expected.sectionIndex != section) {
      throw ArgumentError('Fixed layout identity does not match its section');
    }
    _pendingLoads++;
    try {
      final PreloadedPublicationSection preload;
      try {
        preload = await _lifetime.preload(section, expectedLayout: expected);
      } on PublicationWorkerException catch (error) {
        if (const {
          PublicationWorkerFailure.canceled,
          PublicationWorkerFailure.stale,
          PublicationWorkerFailure.closed,
        }.contains(error.failure)) {
          throw const PreparationCancelled();
        }
        rethrow;
      }
      PreloadedPublicationSection? owned = preload;
      try {
        _check(generation, page);
        final document = preload.plan.document;
        final rendition =
            _renditionFor(section) ?? sectionRendition(book, section);
        final dimensions = resolveAuthoredDimensions(
          source: extractSectionSourceFacts(document),
          packageRendition: rendition.effective,
        );
        final styled = const CssStyleResolver().resolve(
          book,
          section,
          document,
          expected.settings,
          authoredViewport: dimensions is ResolvedDimensions
              ? dimensions.size
              : null,
        );
        _check(generation, page);
        final images = await _images(
          page: page,
          href: preload.plan.href,
          document: document,
          styled: styled,
          references: preload.plan.references,
          resources: preload.resources,
        );
        _check(generation, page);
        final lease = FixedSourceLease(
          page: page,
          document: document,
          styles: styled,
          rendition: rendition,
          resources: preload.resources,
          retainedSourceBytes: document.nodes.length * 256,
          images: images,
          releaseSource: _releaseSource,
        );
        owned = null;
        _liveSources++;
        return lease;
      } finally {
        owned?.dispose();
      }
    } finally {
      if (--_pendingLoads == 0) {
        final drained = _loadsDrained;
        _loadsDrained = null;
        if (drained != null && !drained.isCompleted) drained.complete();
      }
    }
  }

  Future<Map<String, FixedImageRequest>> _images({
    required SourcePageId page,
    required String href,
    required SourceDocument document,
    required CssStyledDocument styled,
    required List<PublicationResourceReference> references,
    required ReaderResourceSource resources,
  }) async {
    final paths = <String, String?>{};
    for (final node in document.nodes) {
      final name = node.localName;
      if (name == null) continue;
      final background = styled.styleOf(node.index)?.authored.backgroundImage;
      if (background != null && background != 'none') {
        paths[fixedCssImageKey(document, background)] = _localImagePath(
          background,
          href,
          references,
          resources,
        );
      }
      if (name == 'image' || name == 'img') {
        final keys = name == 'img'
            ? const ['src']
            : const ['href', 'xlink:href'];
        for (final key in keys) {
          final value = node.attribute(key);
          if (value == null || value.isEmpty || value.startsWith('#')) {
            continue;
          }
          if (isExternalUrl(value) || value.startsWith('//')) continue;
          // Element attributes are document-relative even if their spelling
          // also happens to name an existing archive key or CSS resource.
          // An unavailable relative resource must not fall back to that key.
          final path = resolveUrl(value, href).split('#').first;
          paths[value] = path.isNotEmpty && resources.contains(path)
              ? path
              : null;
        }
      }
    }
    final images = <String, FixedImageRequest>{};
    for (final entry in paths.entries) {
      final url = entry.key, path = entry.value;
      if (path == null) continue;
      final bytes = resources.bytes(path);
      if (bytes == null) continue;
      final size = await _inspect(bytes);
      if (size == null) continue;
      images[url] = _pool.fixedImageRequest(
        path,
        bytes,
        page: page,
        width: size.$1,
        height: size.$2,
      );
    }
    return images;
  }

  static String? _localImagePath(
    String url,
    String sectionHref,
    List<PublicationResourceReference> references,
    ReaderResourceSource resources,
  ) {
    // CSS declarations are resolved against their declaring stylesheet before
    // they reach AuthoredStyle, so this is already an archive path for them.
    if (resources.contains(url)) return url;
    for (final reference in references) {
      final path = reference.path;
      if (reference.url == url && path != null && resources.contains(path)) {
        return path;
      }
    }
    final path = resolveUrl(url, sectionHref).split('#').first;
    if (path.isNotEmpty && resources.contains(path)) return path;
    return null;
  }

  static Future<(int, int)?> _inspect(Uint8List bytes) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      return (descriptor.width, descriptor.height);
    } on Object {
      return null;
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  SectionRendition? _renditionFor(int section) {
    final facts = layoutFacts.sections;
    if (section < 0 || section >= facts.length) return null;
    return facts[section].renditionResolution;
  }

  void _check(int generation, SourcePageId page) {
    if (!isActive ||
        _generation != generation ||
        page.content != identity ||
        !_lifetime.isActive) {
      throw const PreparationCancelled();
    }
  }

  void _releaseSource() {
    if (_liveSources > 0) _liveSources--;
  }

  /// Closes the root book after all prepared surfaces/sources are gone. The
  /// prepared session calls this from its source-disposal barrier; [close] then
  /// releases the independent file/worker pin exactly once.
  Future<void> disposeBook() => _bookClose ??= _disposeBook();

  Future<void> _disposeBook() async {
    if (_pendingLoads > 0) {
      final drained = _loadsDrained ??= Completer<void>();
      await drained.future;
    }
    book.archive.close();
  }

  Future<void> close() => _closed ??= _close();

  Future<void> _close() async {
    _enabled = false;
    await _lifetime.close(
      disableAndInvalidate: () {},
      cancelAndDrain: () async {},
      disposeScenesAndSources: disposeBook,
    );
  }
}
