import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';
import 'package:shiori/features/reader/engine/pagination/layout_identity.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/prepared_reader_session.dart';
import 'package:shiori/features/reader/engine/surface/publication_fixed_composition.dart';
import 'package:shiori/features/reader/engine/surface/publication_fixed_sources.dart';

import '../../../library/data/publications/prepare_test_support.dart';
import 'surface_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('prepared fixed publication loads fixed profile, rendition and images', () async {
    final h = await PrepareHarness.create();
    h.bytes = importZip(
      importEntries(
        layout: 'pre-paginated',
        sources: [
          sourcePage(
            head: viewportHead,
            body:
                '<div style="position:absolute;left:10px;top:20px;'
                'width:40px;height:30px;background-image:url(page.png)"></div>'
                '<svg xmlns="http://www.w3.org/2000/svg" width="600" '
                'height="800" viewBox="0 0 600 800">'
                '<image href="./page.png" width="30" height="30"/></svg>',
          ),
        ],
      ),
    );
    final ready = await h.service.prepare(h.key);
    final identity = ready.identity;
    final facts = ready.layoutFacts;
    const settings = ReaderSettings();
    LayoutIdentity fixedLayout(int section) => fixedSectionLayout(
      identity: identity,
      section: section,
      viewportWidth: 400,
      viewportHeight: 600,
      devicePixelRatio: 1,
      settings: settings,
    );
    late PublicationFixedSources sources;
    final pool = PageSurfacePool();
    final fonts = FontRegistry(processBudget: ProcessFontBudget());
    sources = await PublicationFixedSources.open(
      preparedBook: ready,
      activation: h.session,
      layout: fixedLayout(0),
      isCurrent: () => h.f.guard.isCurrent(h.session),
      acquireLease: () => h.f.cache.acquireHead(h.session, h.key),
      queue: h.service.queue,
      worker: h.service.worker.get,
      pool: pool,
      fonts: fonts,
      layoutFor: fixedLayout,
      sectionBaseFor: (page) =>
          sources.book.sections[page.sectionIndex].spine.cfiBase,
    );
    addTearDown(() async {
      await sources.close();
      ready.release();
      pool.close();
      await pool.drained;
    });
    final composition = await PublicationFixedComposition.prepare(
      book: sources.book,
      identity: identity,
      facts: facts,
      settings: settings,
      viewportWidth: 400,
      viewportHeight: 600,
      devicePixelRatio: 1,
      fixedLayout: fixedLayout,
      fonts: fonts,
    );
    addTearDown(composition.dispose);
    expect(composition.navigator.units, hasLength(1));
    final section = composition.navigator.sections.single;
    expect(section.dimensions, isNotNull);
    final page = SourcePageId(
      content: identity,
      sectionIndex: 0,
      spineIndex: 0,
      stableId: 'EPUB/s0.xhtml',
    );
    final lease = await sources.unitSources.loadSource(page);
    expect(lease.styles.fixedLayout, true);
    expect(lease.page, page);
    expect(lease.rendition.isFixed, true);
    expect(lease.images.keys, containsAll(['EPUB/page.png', './page.png']));
    expect(lease.images['EPUB/page.png']!.width, 1);
    expect(lease.images['EPUB/page.png']!.height, 1);
    expect(lease.images['./page.png']!.width, 1);
    expect(lease.images['./page.png']!.height, 1);
    lease.dispose();
    expect(sources.retainedSourceOwners, 0);
  });

  test('mixed publication opens one session and turns into reflow', () async {
    final h = await PrepareHarness.create();
    h.bytes = importZip(
      importEntries(
        layout: 'pre-paginated',
        properties: ['', 'rendition:layout-reflowable'],
        sources: [
          sourcePage(head: viewportHead, body: '<p>Fixed page</p>'),
          sourcePage(body: '<p>Reflow continuation</p>'),
        ],
      ),
    );
    final ready = await h.service.prepare(h.key);
    final identity = ready.identity;
    final facts = ready.layoutFacts;
    const settings = ReaderSettings();
    LayoutIdentity fixedLayout(int section) => fixedSectionLayout(
      identity: identity,
      section: section,
      viewportWidth: 400,
      viewportHeight: 600,
      devicePixelRatio: 1,
      settings: settings,
    );
    late PublicationFixedSources sources;
    final pool = PageSurfacePool();
    final fonts = FontRegistry(processBudget: ProcessFontBudget());
    sources = await PublicationFixedSources.open(
      preparedBook: ready,
      activation: h.session,
      layout: fixedLayout(0),
      isCurrent: () => h.f.guard.isCurrent(h.session),
      acquireLease: () => h.f.cache.acquireHead(h.session, h.key),
      queue: h.service.queue,
      worker: h.service.worker.get,
      pool: pool,
      fonts: fonts,
      layoutFor: fixedLayout,
      sectionBaseFor: (page) =>
          sources.book.sections[page.sectionIndex].spine.cfiBase,
    );
    final composition = await PublicationFixedComposition.prepare(
      book: sources.book,
      identity: identity,
      facts: facts,
      settings: settings,
      viewportWidth: 400,
      viewportHeight: 600,
      devicePixelRatio: 1,
      fixedLayout: fixedLayout,
      fonts: fonts,
    );
    addTearDown(() async {
      composition.dispose();
      await sources.close();
      ready.release();
    });
    expect(composition.navigator.units, hasLength(2));
    final session = (await PreparedReaderSession.openUnit(
      pool: pool,
      unit: composition.navigator.units.first,
      navigator: composition.navigator,
      fixedSources: sources.unitSources,
      loadSection: composition.loadReflow,
      theme: surfaceTheme,
      activation: h.session,
      isActivationCurrent: h.f.guard.isCurrent,
      publication: sources.publication,
      cancelAndDrainMotion: () async {},
      disposeSourceAdapters: () async {
        composition.dispose();
        await sources.disposeBook();
      },
    ))!;
    expect(session.position.sectionIndex, 0);
    final next = await session.navigate(
      session.position,
      TurnDirection.next,
      null,
    );
    expect(next.kind, TurnNavigationKind.verified);
    expect(next.position!.sectionIndex, 1);
    session.close();
    await session.closed;
    expect(pool.owners, 0);
  });
}
