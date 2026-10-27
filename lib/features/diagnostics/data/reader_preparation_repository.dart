import 'dart:async';

import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/diagnostics/data/reader_probe_recorder.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/resources/archive_reader_resource_source.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';

/// Bounded section owner. Presented sections cannot be evicted underneath pictures.
final class ReaderPreparationRepository {
  ReaderPreparationRepository({
    required this.book,
    required this.digest,
    required this.settings,
    required this.width,
    required this.height,
    required this.dpr,
    required this.generation,
    required this.recorder,
  });
  final EpubBook book;
  final String digest;
  final ReaderSettings settings;
  final double width;
  final double height;
  final double dpr;
  final int generation;
  final ReaderProbeRecorder recorder;
  final _preparer = SectionPreparer();
  final _cache = <int, PreparedSection>{};
  final _pending = <int, Future<PreparedSection?>>{};
  final _controls = <PreparationControl>{};
  bool Function(PreparedSection)? pinned;
  bool _closed = false;
  int get cachedSections => _cache.length;

  Future<PreparedSection?> load(int index) {
    if (_closed) return Future.value(null);
    final cached = _cache.remove(index);
    recorder.preparation(start: true, section: index, cacheHit: cached != null);
    if (cached != null) {
      _cache[index] = cached;
      recorder.preparation(start: false, section: index, cacheHit: true);
      return Future.value(cached);
    }
    return _pending.putIfAbsent(index, () => _prepare(index));
  }

  Future<PreparedSection?> _prepare(int index) async {
    final control = PreparationControl();
    _controls.add(control);
    try {
      final doc = book.loadSection(index);
      final styled = const CssStyleResolver().resolve(
        book,
        index,
        doc,
        settings,
      );
      final section = await _preparer.prepare(
        PrepareRequest.resources(
          resources: ArchiveReaderResourceSource(book.archive),
          sectionHref: book.sections[index].item.href,
          sectionBase: book.sections[index].spine.cfiBase,
          sectionIndex: index,
          document: doc,
          styled: styled,
          settings: settings,
          viewportWidth: width,
          viewportHeight: height,
          devicePixelRatio: dpr,
          contentId: digest,
          generation: generation,
        ),
        control: control,
      );
      if (_closed) {
        section.dispose();
        return null;
      }
      for (final cost in section.paragraphCosts) {
        recorder.layout(
          section: index,
          layoutUs: cost.layoutMicros,
          codeUnits: cost.codeUnits,
          lines: cost.lines,
          pageCount: section.pageCount,
        );
      }
      // Three presented sections plus one incoming reserve.
      while (_cache.length >= 4) {
        final candidates = _cache.entries.where(
          (e) => !(pinned?.call(e.value) ?? false),
        );
        if (candidates.isEmpty) {
          section.dispose();
          throw const ParseException();
        }
        final key = candidates.first.key;
        _cache.remove(key)?.dispose();
      }
      _cache[index] = section;
      recorder.preparation(start: false, section: index, cacheHit: false);
      return section;
    } on PreparationCancelled {
      return null;
    } finally {
      _controls.remove(control);
      unawaited(_pending.remove(index));
    }
  }

  Future<void> drain() async {
    await Future.wait(_pending.values.toList());
  }

  /// Call after closing the surface session, which releases its picture leases.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final control in _controls) {
      control.cancel();
    }
    await drain();
    for (final section in _cache.values) {
      section.dispose();
    }
    _cache.clear();
    _preparer.images.clearUnleased();
  }
}
