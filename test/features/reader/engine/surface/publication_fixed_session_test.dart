import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/layout/reading_unit.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_navigator.dart';
import 'package:shiori/features/reader/data/layout/source_page_slot.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_section_preparer.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/publication_fixed_composition.dart';

import 'publication_fixed_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'spreads, centered pages, reverse and TOC use the real loader',
    () async {
      final h = await PublicationFixedHarness.open(
        corpusPublication('mixed-navigation-positive'),
        width: 600,
        height: 400,
      );
      final navigator = h.composition.navigator;
      expect(navigator.sections, hasLength(6));
      expect(navigator.units, hasLength(5));
      expect(navigator.units[0].kind, ReadingUnitKind.reflowPage);
      expect(navigator.units[1].kind, ReadingUnitKind.fixedSingle);
      expect(navigator.units[1].slots.single, isA<RealSourcePageSlot>());
      expect(
        (navigator.units[1].slots.single as RealSourcePageSlot).side,
        SpreadSide.center,
      );
      expect(navigator.units[2].kind, ReadingUnitKind.fixedSpread);
      final spread = navigator.units[2].slots.cast<RealSourcePageSlot>();
      expect(spread.map((s) => s.side), [SpreadSide.left, SpreadSide.right]);
      expect(spread.map((s) => s.page.sectionIndex), [2, 3]);

      final toc = await navigator.forTocTarget(navigator.sections[3].href);
      expect(toc, isA<LocatedReadingUnit>());
      expect((toc as LocatedReadingUnit).unit.activeSource.sectionIndex, 3);
      final fragment = await navigator.forTocTarget(
        '${navigator.sections[2].href}#source',
      );
      expect(fragment, isA<LocatedReadingUnit>());
      expect(
        (fragment as LocatedReadingUnit).unit.activeSource.sectionIndex,
        2,
      );

      final next = await navigator.adjacent(
        navigator.units[2],
        UnitDirection.next,
      );
      expect((next as LocatedReadingUnit).unit.activeSource.sectionIndex, 5);
      final previous = await navigator.adjacent(
        navigator.units[2],
        UnitDirection.previous,
      );
      expect(
        (previous as LocatedReadingUnit).unit.activeSource.sectionIndex,
        1,
      );

      final session = await h.openSession();
      expect(session.position.sectionIndex, 0);
      var origin = session.position;
      final visited = <int>[origin.sectionIndex];
      for (var i = 0; i < 3; i++) {
        final result = await session.navigate(origin, TurnDirection.next, null);
        expect(result.kind, TurnNavigationKind.verified);
        origin = result.position!;
        visited.add(origin.sectionIndex);
      }
      expect(visited, [0, 1, 2, 5]);
      final back = await session.navigate(origin, TurnDirection.previous, null);
      expect(back.kind, TurnNavigationKind.verified);
      expect(back.position!.sectionIndex, 3);
    },
  );

  test(
    'centered and padded spreads retain blank slots and the end boundary',
    () async {
      final centered = await PublicationFixedHarness.open(
        fixedSidesPublication(['center']),
        width: 600,
        height: 400,
      );
      final unit = centered.composition.navigator.units.single;
      expect(unit.kind, ReadingUnitKind.fixedSingle);
      expect((unit.slots.single as RealSourcePageSlot).side, SpreadSide.center);
      final centeredSession = await centered.openSession();
      expect(centeredSession.position.sectionIndex, 0);
      expect(centeredSession.position.pageCount, 1);

      final padded = await PublicationFixedHarness.open(
        fixedSidesPublication(['left', 'right', 'left']),
        width: 600,
        height: 400,
      );
      final units = padded.composition.navigator.units;
      expect(units, hasLength(2));
      expect(units[0].kind, ReadingUnitKind.fixedSpread);
      expect(units[1].kind, ReadingUnitKind.fixedSpread);
      expect(units[1].slots.last, isA<BlankSourcePageSlot>());
      final session = await padded.openSession(unit: units[0]);
      expect(session.position.sectionIndex, 0);
      final next = await session.navigate(
        session.position,
        TurnDirection.next,
        null,
      );
      expect(next.kind, TurnNavigationKind.verified);
      expect(next.position!.sectionIndex, 2);
      expect(next.position!.atEnd, true);
      final result = await session.navigate(
        next.position!,
        TurnDirection.next,
        null,
      );
      expect(result.kind, TurnNavigationKind.boundary);
    },
  );

  test(
    'typed unsupported SVG section refuses without publishing a page',
    () async {
      final h = await PublicationFixedHarness.open(
        corpusPublication('svg-graphics-unsupported'),
        width: 600,
        height: 400,
      );
      final unit = h.composition.navigator.units.single;
      Object? failure;
      try {
        await h.pool.prepareFixedUnit(
          unit,
          layout: h.fixedLayout(unit.activeSource.sectionIndex),
          loadSource: h.sources.unitSources.loadSource,
          fonts: h.fonts,
        );
      } on Object catch (error) {
        failure = error;
      }
      expect(failure, isA<FixedPreparationFailure>());
      final capability = (failure as FixedPreparationFailure).capability;
      expect(capability, isA<UnsupportedSectionCapability>());
      expect(capability.constructs, isNotEmpty);
      expect(h.pool.owners, 0);
      expect(h.pool.liveSurfaces, 0);
      expect(h.sources.retainedSourceOwners, 0);
    },
  );

  test('source leases are released exactly once on close', () async {
    final h = await PublicationFixedHarness.open(
      fixedSidesPublication(['center']),
      width: 600,
      height: 400,
    );
    final page = h.composition.navigator.sections.single.page;
    final lease = await h.sources.unitSources.loadSource(page);
    expect(h.sources.retainedSourceOwners, 1);
    lease.dispose();
    lease.dispose();
    expect(h.sources.retainedSourceOwners, 0);
    final second = await h.sources.unitSources.loadSource(page);
    expect(h.sources.retainedSourceOwners, 1);
    await h.sources.close();
    second.dispose();
    expect(h.sources.retainedSourceOwners, 0);
    expect(h.sources.publication.isActive, false);
  });

  test(
    'direction refusal maps to a typed preparation failure before units',
    () async {
      final h = await PublicationFixedHarness.open(
        fixedSidesPublication(['center']),
        width: 600,
        height: 400,
      );
      final facts = PublicationLayoutFacts(
        pageProgressionDirection: 'rtl',
        primaryLanguage: h.ready.layoutFacts.primaryLanguage,
        packageRendition: h.ready.layoutFacts.packageRendition,
        sections: h.ready.layoutFacts.sections,
      );
      Object? failure;
      try {
        await PublicationFixedComposition.prepare(
          book: h.sources.book,
          identity: h.ready.identity,
          facts: facts,
          settings: const ReaderSettings(),
          viewportWidth: 600,
          viewportHeight: 400,
          devicePixelRatio: 1,
          fixedLayout: h.fixedLayout,
          fonts: h.fonts,
        );
      } on Object catch (error) {
        failure = error;
      }
      expect(failure, isA<FixedPreparationFailure>());
      final capability = (failure as FixedPreparationFailure).capability;
      expect(capability, isA<UnsupportedSectionCapability>());
      expect(
        capability.constructs.map((construct) => construct.identifier),
        contains('direction:rtlProgression'),
      );
      expect(h.pool.owners, 0);
    },
  );
}
