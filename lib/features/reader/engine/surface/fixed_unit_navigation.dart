import 'package:shiori/features/reader/data/cfi/cfi.dart';
import 'package:shiori/features/reader/data/layout/reading_unit.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_section_preparer.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';
import 'package:shiori/features/reader/engine/pagination/layout_identity.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/fixed_position_proof.dart';

/// Uses independent source leases (including publication worker/file pins).
/// No section cache or alternate renderer lives in this adapter.
final class FixedUnitSources {
  const FixedUnitSources({
    required this.loadSource,
    required this.layoutFor,
    required this.sectionBaseFor,
    required this.fonts,
  });
  final FixedSourceLoader loadSource;
  final LayoutIdentity Function(int section) layoutFor;
  final String Function(SourcePageId page) sectionBaseFor;
  final FontRegistry fonts;

  Future<PageSurfaceLease?> prepare(
    PageSurfacePool pool,
    ReadingUnit unit,
    PublicationCancellation cancellation,
  ) => pool.prepareFixedUnit(
    unit,
    layout: layoutFor(unit.activeSource.sectionIndex),
    loadSource: loadSource,
    fonts: fonts,
    cancellation: cancellation,
  );

  TurnPosition? positionFor(
    PreparedPageSurface surface, {
    required bool atStart,
    required bool atEnd,
  }) {
    final unit = surface.unit!;
    final scene = surface.fixedScenes.singleWhere(
      (s) => s.plan.source.page == unit.activeSource,
    );
    final source = scene.plan.source;
    final base = sectionBaseFor(source.page);
    for (final fragment in scene.geometry.fragments) {
      final position = SourcePosition(
        nodeIndex: fragment.nodeIndex,
        offset: fragment.textRange?.start ?? 0,
      );
      final cfi = Cfi.export(source.document, position, sectionBase: base);
      if (!proveFixedAnchor(scene, cfi, base)) continue;
      return TurnPosition(
        cfi: cfi,
        layoutKey: surface.layout.key,
        layoutGeneration: surface.layout.generation,
        sectionIndex: source.page.sectionIndex,
        pageIndex: 0,
        pageCount: 1,
        pageIdentity: '${unit.id.stableId}|${source.page.stableId}',
        atStart: atStart,
        atEnd: atEnd,
      );
    }
    throw FixedPreparationFailure(
      RenderSectionCapability(
        sectionIndex: source.page.sectionIndex,
        reason: 'Fixed source has no proven visible anchor',
        constructs: [
          OffendingConstruct(
            kind: CapabilityConstructKind.render,
            identifier: 'fixed-anchor-proof',
          ),
        ],
      ),
    );
  }

  bool prove(
    PreparedPageSurface surface,
    TurnPosition position, {
    String? anchor,
  }) {
    if (surface.disposed || surface.unit == null) return false;
    final unit = surface.unit!;
    if (position.layoutKey != surface.layout.key ||
        position.layoutGeneration != surface.layout.generation ||
        position.sectionIndex != unit.activeSource.sectionIndex ||
        position.pageIndex != 0 ||
        position.pageCount != 1 ||
        position.pageIdentity !=
            '${unit.id.stableId}|${unit.activeSource.stableId}') {
      return false;
    }
    final scene = surface.fixedScenes.singleWhere(
      (s) => s.plan.source.page == unit.activeSource,
    );
    final base = sectionBaseFor(unit.activeSource);
    return proveFixedAnchor(scene, position.cfi, base) &&
        (anchor == null || proveFixedAnchor(scene, anchor, base));
  }
}
