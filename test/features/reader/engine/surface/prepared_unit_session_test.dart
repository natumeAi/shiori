import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/layout/reading_unit.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_section.dart';
import 'package:shiori/features/reader/data/layout/section_rendition.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';
import 'package:shiori/features/reader/engine/motion/reader_preparation_failure.dart';
import 'package:shiori/features/reader/engine/pagination/anchor.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';
import 'package:shiori/features/reader/engine/pagination/reading_unit_navigator.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/prepared_reader_session.dart';

import '../../contract_test_values.dart';
import '../layout/layout_test_support.dart';
import 'surface_test_support.dart';

void main() {
  initEngineBinding();
  final sections = <PreparedSection>[];
  setUpAll(() async {
    final book = EpubBook.open(
      buildEpub(
        sections: {
          for (var section = 0; section < 3; section++)
            's$section.xhtml': xhtml(
              [
                for (var page = 0; page < 3; page++)
                  '<p id="target-$page" style="break-before:page">'
                      'Section $section page $page alpha beta gamma.</p>',
              ].join(),
            ),
        },
      ),
    );
    for (var i = 0; i < 3; i++) {
      sections.add(
        await prepareSection(
          book,
          i,
          preparer: SectionPreparer(),
          resolver: fixtureResolver(),
          contentId: contractContent().sha256,
        ),
      );
    }
    expect(sections.map((s) => s.pageCount), [3, 3, 3]);
  });
  tearDownAll(() {
    for (final section in sections) {
      section.dispose();
    }
  });

  Future<PreparedReaderSession> open({
    int section = 0,
    int page = 0,
    Set<int> nonlinear = const {},
    Future<PreparedSection?> Function(int)? loader,
    ServerSession? activation,
    bool Function(ServerSession)? current,
    PageSurfacePool? pool,
  }) async => (await PreparedReaderSession.open(
    pool: pool ?? PageSurfacePool(),
    section: sections[section],
    pageIndex: page,
    sectionCount: sections.length,
    loadSection: loader ?? (i) async => sections[i],
    theme: surfaceTheme,
    navigator: surfaceNavigator(sections, nonlinear: nonlinear),
    activation: activation ?? surfaceActivation(1),
    isActivationCurrent: current ?? (_) => true,
  ))!;

  Future<void> settle(
    PreparedReaderSession session,
    PreparedTurn preview,
  ) async {
    final origin = session.position;
    final result = await session.navigate(origin, preview.direction, preview);
    expect(result.kind, TurnNavigationKind.verified);
    expect(await session.prove(result.position!, preview: preview), isTrue);
    session.accept(result.position!);
    preview.release();
    expect(session.pool.owners, 2, reason: 'old/new overlap until unbind');
    session.unbind();
    expect(session.pool.owners, 1);
    expect(session.frames.value.current.unit, session.unit);
  }

  test(
    'A1 adjacency matches reflow arithmetic in both directions and restores',
    () async {
      final session = await open();
      addTearDown(session.close);
      expect(session.position.atStart, isTrue);
      expect(session.unit!.kind, ReadingUnitKind.reflowPage);
      for (var i = 1; i < 9; i++) {
        final preview = (await session.prepare(
          session.position,
          TurnDirection.next,
        ))!;
        expect(
          (preview.target.sectionIndex, preview.target.pageIndex),
          (i ~/ 3, i % 3),
        );
        await settle(session, preview);
      }
      expect(session.position.atEnd, isTrue);
      expect(
        (await session.navigate(
          session.position,
          TurnDirection.next,
          null,
        )).kind,
        TurnNavigationKind.boundary,
      );
      for (var i = 7; i >= 0; i--) {
        final preview = (await session.prepare(
          session.position,
          TurnDirection.previous,
        ))!;
        expect(
          (preview.target.sectionIndex, preview.target.pageIndex),
          (i ~/ 3, i % 3),
        );
        await settle(session, preview);
      }
      final origin = session.position;
      final originUnit = session.unit;
      final preview = (await session.prepare(origin, TurnDirection.next))!;
      await session.navigate(origin, preview.direction, preview);
      expect(await session.restore(origin), isTrue);
      preview.release();
      session.unbind();
      expect(session.position.sameOrigin(origin), isTrue);
      expect(session.unit, originUnit);
      expect(session.pool.resourceBudget.used[SceneResource.sourcePages], 1);
    },
  );

  test(
    'TOC and source restore use A1 lookup and do not reuse an adjacent preview',
    () async {
      final session = await open(nonlinear: {1}, page: 2);
      addTearDown(session.close);
      final origin = session.position;
      final adjacent = (await session.prepare(origin, TurnDirection.next))!;
      expect(
        adjacent.target.sectionIndex,
        2,
        reason: 'nonlinear source is skipped',
      );
      final toc = (await session.prepareTocTarget(
        origin,
        'section-1.xhtml#target-2',
      ))!;
      expect((toc.target.sectionIndex, toc.target.pageIndex), (1, 2));
      final again = (await session.prepare(origin, TurnDirection.next))!;
      expect(again.target.samePage(adjacent.target), isTrue);
      expect(
        session.position.sameOrigin(origin),
        isTrue,
        reason: 'lookup is not acceptance',
      );
      adjacent.release();
      again.release();
      await settle(session, toc);
      final anchor = PageAnchors(sections[0]).exportVisible(1)!;
      final restored = (await session.prepareSourcePosition(
        session.position,
        contractPage(section: 0, id: 'section-0.xhtml'),
        anchor.position,
      ))!;
      expect((restored.target.sectionIndex, restored.target.pageIndex), (0, 1));
      await settle(session, restored);
      expect(
        await session.prepareTocTarget(
          session.position,
          'section-1.xhtml#missing',
        ),
        isNull,
      );
    },
  );

  test('missing fixed source owner yields typed capability without a false boundary', () async {
    final reflow = surfaceNavigator([sections.first]);
    final navigator = ComposedReadingUnitNavigator(
      sections: [
        reflow.sections.single,
        ReadingUnitSection(
          page: contractPage(section: 1, id: 'fixed.xhtml'),
          href: 'fixed.xhtml',
          rendition: resolveSectionRendition(
            package: {'layout': 'pre-paginated'},
          ),
          dimensions: ResolvedDimensions(
            size: AuthoredPageSize(320, 240),
            source: DimensionSource.viewportMeta,
            reason: 'test viewport',
          ),
          layoutKey: 'authored-fixed',
        ),
      ],
      viewportWidth: reflow.viewportWidth,
      viewportHeight: reflow.viewportHeight,
      documents: reflow.documents,
      locateReflow: reflow.locateReflow,
    );
    final pool = PageSurfacePool();
    final session = (await PreparedReaderSession.open(
      pool: pool,
      section: sections.first,
      pageIndex: 2,
      sectionCount: 2,
      loadSection: (_) =>
          throw StateError('Fixed must not use reflow preparation'),
      theme: surfaceTheme,
      navigator: navigator,
      activation: surfaceActivation(1),
      isActivationCurrent: (_) => true,
    ))!;
    addTearDown(session.close);
    expect(session.position.atEnd, isFalse);
    final origin = session.position;
    final result = await session.navigate(origin, TurnDirection.next, null);
    expect(result.kind, TurnNavigationKind.failed);
    expect(result.failure!.kind, ReaderPreparationFailureKind.fixedCapability);
    expect(session.position.sameOrigin(origin), isTrue);
    expect(pool.owners, 1);
    expect(pool.resourceBudget.used[SceneResource.sourcePages], 1);
  });

  test(
    'one canceled waiter cannot release the shared cross-section result',
    () async {
      final entered = Completer<void>();
      final pending = Completer<PreparedSection?>();
      var loads = 0;
      final session = await open(
        page: 2,
        loader: (i) {
          loads++;
          if (!entered.isCompleted) entered.complete();
          return pending.future;
        },
      );
      addTearDown(session.close);
      final canceled = PublicationCancellation();
      final abandoned = session.prepare(
        session.position,
        TurnDirection.next,
        cancellation: canceled,
      );
      final live = session.prepare(session.position, TurnDirection.next);
      await entered.future;
      canceled.cancel();
      expect(await abandoned, isNull);
      expect(session.pool.owners, 1);
      pending.complete(sections[1]);
      final preview = (await live)!;
      expect(loads, 1);
      expect(session.pool.resourceBudget.used[SceneResource.sourcePages], 2);
      await settle(session, preview);
      await session.stopAndDrain();
      session.close();
      expect(session.pool.resourceBudget.used.values, everyElement(0));
    },
  );

  test(
    'A to B to A retains activation identity and rejects a late first-A result',
    () async {
      var current = surfaceActivation(1);
      final firstActivation = current;
      final entered = Completer<void>();
      final pending = Completer<PreparedSection?>();
      final budget = SceneResourceBudget();
      final old = await open(
        page: 2,
        activation: firstActivation,
        current: (captured) => captured == current,
        pool: PageSurfacePool(resourceBudget: budget),
        loader: (_) {
          entered.complete();
          return pending.future;
        },
      );
      addTearDown(old.close);
      final stale = old.prepare(old.position, TurnDirection.next);
      await entered.future;
      current = ServerSession(
        endpoint: ServerEndpoint.parse('https://b.example.test/').endpoint!,
        generation: 2,
      );
      expect(await old.prepare(old.position, TurnDirection.next), isNull);
      current = surfaceActivation(3);
      final fresh = await open(
        page: 2,
        activation: current,
        current: (captured) => captured == current,
        pool: PageSurfacePool(resourceBudget: budget),
      );
      addTearDown(fresh.close);
      expect(old.position.sameOrigin(fresh.position), isTrue);
      expect(
        budget.used[SceneResource.readingUnits],
        2,
        reason: 'old picture still owns its charge',
      );
      pending.complete(sections[1]);
      expect(await stale, isNull);
      await old.stopAndDrain();
      expect(await old.prove(old.position), isFalse);
      final preview = (await fresh.prepare(
        fresh.position,
        TurnDirection.next,
      ))!;
      expect(budget.used[SceneResource.sourcePages], 3);
      preview.release();
      old.close();
      expect(budget.used[SceneResource.sourcePages], 1);
      fresh.close();
      expect(budget.used.values, everyElement(0));
    },
  );
}
