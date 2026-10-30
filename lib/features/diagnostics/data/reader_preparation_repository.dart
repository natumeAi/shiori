import 'package:shiori/features/diagnostics/data/reader_probe_recorder.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/resources/archive_reader_resource_source.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/surface/reflow_section_cache.dart';

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
    SceneResourceBudget? resourceBudget,
  }) {
    _cache = ReflowSectionCache(
      prepare: _prepare,
      budget: resourceBudget ?? SceneResourceBudget(),
    );
  }
  final EpubBook book;
  final String digest;
  final ReaderSettings settings;
  final double width;
  final double height;
  final double dpr;
  final int generation;
  final ReaderProbeRecorder recorder;
  final _preparer = SectionPreparer();
  late final ReflowSectionCache _cache;
  final _controls = <PreparationControl>{};
  set pinned(bool Function(PreparedSection)? value) => _cache.pinned = value;
  bool _closed = false;
  int get cachedSections => _cache.sections.length;

  Future<PreparedSection?> load(int index) {
    if (_closed) return Future.value(null);
    final hit = _cache.sections.containsKey(index);
    recorder.preparation(start: true, section: index, cacheHit: hit);
    if (hit) {
      recorder.preparation(start: false, section: index, cacheHit: true);
    }
    return _cache.load(index);
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
      recorder.preparation(start: false, section: index, cacheHit: false);
      return section;
    } on PreparationCancelled {
      return null;
    } finally {
      _controls.remove(control);
    }
  }

  Future<void> drain() => _cache.drain();

  /// Call after closing the surface session, which releases its picture leases.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final control in _controls) {
      control.cancel();
    }
    await drain();
    _cache.dispose();
    _preparer.images.clearUnleased();
  }
}
