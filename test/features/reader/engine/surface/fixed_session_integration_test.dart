import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/layout/reading_unit.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_navigator.dart';
import 'package:shiori/features/reader/data/layout/source_page_slot.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/reader_preparation_failure.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/prepared_reader_session.dart';

import 'fixed_session_test_support.dart';
import 'surface_test_support.dart';

Future<void> settleFixed(
  PreparedReaderSession session,
  PreparedTurn preview,
) async {
  final result = await session.navigate(
    session.position,
    preview.direction,
    preview,
  );
  expect(result.kind, TurnNavigationKind.verified);
  expect(await session.prove(result.position!, preview: preview), true);
  session.accept(result.position!);
  preview.release();
  session.unbind();
  expect(session.pool.owners, 1);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('A0 mixed source: reflow, single, spread and reverse/TOC retain exact sources', () async {
    final f = FixedSessionFixture();
    await f.prepareNavigation();
    addTearDown(f.dispose);
    final pool = PageSurfacePool();
    final session = (await PreparedReaderSession.openUnit(
      pool: pool,
      unit: f.navigator.units.first,
      navigator: f.navigator,
      fixedSources: f.sources(),
      loadSection: (i) async => f.reflow[i],
      theme: surfaceTheme,
      activation: surfaceActivation(1),
      isActivationCurrent: (_) => true,
    ))!;
    addTearDown(session.close);
    final seen = [session.position.sectionIndex];
    for (var i = 0; i < 3; i++) {
      await settleFixed(
        session,
        (await session.prepare(session.position, TurnDirection.next))!,
      );
      seen.add(session.position.sectionIndex);
      if (session.unit!.kind == ReadingUnitKind.fixedSpread) {
        expect(session.unit!.realSourceCount, 2);
        expect(session.frames.value.current.geometry.length, 2);
        expect(
          session
              .frames
              .value
              .current
              .geometry
              .last
              .fragments
              .first
              .sourceToUnit
              .e,
          greaterThanOrEqualTo(320),
        );
      }
    }
    expect(seen, [
      0,
      1,
      2,
      5,
    ], reason: 'nonlinear 4 skipped; 3 is the spread partner');
    expect(session.position.atEnd, true);
    final reverse = <int>[];
    for (var i = 0; i < 3; i++) {
      await settleFixed(
        session,
        (await session.prepare(session.position, TurnDirection.previous))!,
      );
      reverse.add(session.position.sectionIndex);
    }
    expect(reverse, [3, 1, 0]);
    await settleFixed(
      session,
      (await session.prepareTocTarget(
        session.position,
        'EPUB/p4.xhtml#source',
      ))!,
    );
    expect(session.position.sectionIndex, 4);
    await settleFixed(
      session,
      (await session.prepareTocTarget(
        session.position,
        'EPUB/p3.xhtml#source',
      ))!,
    );
    expect(session.unit!.activeSource, f.page(3));
    expect(
      session.unit!.slots.whereType<RealSourcePageSlot>().map(
        (s) => s.page.sectionIndex,
      ),
      [2, 3],
    );
    session.close();
    await session.closed;
    expect(pool.resourceBudget.used.values, everyElement(0));
  });

  test(
    'A0 single and padded spread open; source restore recomposes to portrait',
    () async {
      for (final caseId in ['metadata-positive', 'metadata-boundary']) {
        final f = FixedSessionFixture(caseId: caseId);
        await f.prepareNavigation();
        final pool = PageSurfacePool();
        final session = (await PreparedReaderSession.openUnit(
          pool: pool,
          unit: f.navigator.units.single,
          navigator: f.navigator,
          fixedSources: f.sources(),
          loadSection: (_) async => null,
          theme: surfaceTheme,
          activation: surfaceActivation(1),
          isActivationCurrent: (_) => true,
        ))!;
        expect(await session.prove(session.position), true);
        expect(pool.resourceBudget.used[SceneResource.sourcePages], 1);
        expect(
          f.acquired.values.single,
          1,
          reason: 'blank never loads a source',
        );
        expect(
          (await session.navigate(
            session.position,
            TurnDirection.next,
            null,
          )).kind,
          TurnNavigationKind.boundary,
        );
        session.close();
        await session.closed;
        f.dispose();
      }
      final landscape = FixedSessionFixture(spreads: 1),
          portrait = FixedSessionFixture(spreads: 1, width: 400, height: 800);
      await landscape.prepareNavigation();
      await portrait.prepareNavigation();
      final budget = SceneResourceBudget(),
          allocations = SurfaceAllocationBudget();
      final old = (await PreparedReaderSession.openUnit(
        pool: PageSurfacePool(resourceBudget: budget, allocations: allocations),
        unit: landscape.navigator.units.single,
        navigator: landscape.navigator,
        fixedSources: landscape.sources(),
        loadSection: (_) async => null,
        theme: surfaceTheme,
        activation: surfaceActivation(1),
        isActivationCurrent: (_) => true,
      ))!;
      final target = await portrait.navigator.forSourcePosition(
        landscape.page(1),
        SourcePosition(
          nodeIndex: portrait.documents[1]!.getElementById('source')!.index,
          offset: 0,
        ),
      ) as LocatedReadingUnit;
      final fresh = (await PreparedReaderSession.openUnit(
        pool: PageSurfacePool(resourceBudget: budget, allocations: allocations),
        unit: target.unit,
        navigator: portrait.navigator,
        fixedSources: portrait.sources(),
        loadSection: (_) async => null,
        theme: surfaceTheme,
        activation: surfaceActivation(1),
        isActivationCurrent: (_) => true,
      ))!;
      expect(fresh.unit!.kind, ReadingUnitKind.fixedSingle);
      expect(fresh.unit!.activeSource, landscape.page(1));
      expect(
        budget.used[SceneResource.sourcePages],
        3,
        reason: 'replacement overlaps old spread',
      );
      old.close();
      await old.closed;
      expect(budget.used[SceneResource.sourcePages], 1);
      fresh.close();
      await fresh.closed;
      landscape.dispose();
      portrait.dispose();
      expect(budget.used.values, everyElement(0));
      expect(allocations.images.totalBytes, 0);
    },
  );

  test('four real prepared spreads retain eight independent sources and release once', () async {
    final f = FixedSessionFixture(spreads: 4);
    await f.prepareNavigation();
    final pool = PageSurfacePool(), sources = f.sources();
    final pictures = <ui.Picture>[];
    final previousCreate = ui.Picture.onCreate;
    ui.Picture.onCreate = pictures.add;
    addTearDown(() => ui.Picture.onCreate = previousCreate);
    final leases = <PageSurfaceLease>[];
    for (final unit in f.navigator.units) {
      leases.add(
        (await pool.prepareFixedUnit(
          unit,
          layout: f.layout(unit.activeSource.sectionIndex),
          loadSource: sources.loadSource,
          fonts: sources.fonts,
        ))!,
      );
    }
    expect(pool.owners, 4);
    expect(pool.liveSurfaces, 4);
    expect(pool.resourceBudget.used[SceneResource.readingUnits], 4);
    expect(pool.resourceBudget.used[SceneResource.sourcePages], 8);
    expect(pool.resourceBudget.peaks[SceneResource.sourcePages], 8);
    expect(f.acquired.length, 8);
    expect(f.acquired.values, everyElement(1));
    expect(f.released, isEmpty);
    final retainedPictures = pictures.where((p) => !p.debugDisposed).toList();
    expect(
      retainedPictures.length,
      12,
      reason: 'eight scenes plus four composites',
    );
    final chargedPictures = pool.pictureBytes;
    await expectLater(
      pool.prepareFixedUnit(
        f.navigator.units.first,
        layout: f.layout(0),
        loadSource: sources.loadSource,
        fonts: sources.fonts,
      ),
      throwsA(
        isA<Exception>().having(
          (e) => ReaderPreparationFailure.from(e)?.kind,
          'failure kind',
          ReaderPreparationFailureKind.sceneAdmission,
        ),
      ),
    );
    expect(pool.owners, 4);
    expect(pool.resourceBudget.used[SceneResource.sourcePages], 8);
    expect(pool.pictureBytes, chargedPictures);
    expect(f.released, {0: 1, 1: 1}, reason: 'refused sources released once');
    expect(retainedPictures.every((p) => !p.debugDisposed), true);
    final extra = leases.first.retain();
    pool.close();
    for (final lease in leases) {
      lease.release();
      lease.release();
    }
    expect(pool.owners, 1);
    expect(f.released.length, 8);
    expect(f.released[0], 1, reason: 'extra reference still pins first spread');
    extra.release();
    extra.release();
    await pool.drained;
    expect(pool.owners, 0);
    expect(pool.pictureBytes, 0);
    expect(pool.resourceBudget.used.values, everyElement(0));
    expect(f.released, f.acquired);
    expect(f.resourceDisposals, f.acquired);
    expect(pictures.every((p) => p.debugDisposed), true);
    f.dispose();
  });
}
