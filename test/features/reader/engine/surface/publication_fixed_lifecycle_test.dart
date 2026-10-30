import 'dart:async';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_test_hooks.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/pagination/layout_identity.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/publication_fixed_composition.dart';
import 'package:shiori/features/reader/engine/surface/publication_fixed_sources.dart';

import '../../../library/data/publications/prepare_test_support.dart';
import 'publication_fixed_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('retired activation cannot load and close releases once', () async {
    final h = await PrepareHarness.create();
    h.bytes = fixedSidesPublication(['center']);
    final ready = await h.service.prepare(h.key);
    var current = true;
    final pool = PageSurfacePool();
    final fonts = FontRegistry(processBudget: ProcessFontBudget());
    const settings = ReaderSettings();
    LayoutIdentity layout(int section) => fixedSectionLayout(
      identity: ready.identity,
      section: section,
      viewportWidth: 600,
      viewportHeight: 400,
      devicePixelRatio: 1,
      settings: settings,
    );
    late PublicationFixedSources sources;
    sources = await PublicationFixedSources.open(
      preparedBook: ready,
      activation: h.session,
      layout: layout(0),
      isCurrent: () => current,
      acquireLease: () => h.f.cache.acquireHead(h.session, h.key),
      queue: h.service.queue,
      worker: h.service.worker.get,
      pool: pool,
      fonts: fonts,
      layoutFor: layout,
      sectionBaseFor: (page) =>
          sources.book.sections[page.sectionIndex].spine.cfiBase,
    );
    final composition = await PublicationFixedComposition.prepare(
      book: sources.book,
      identity: ready.identity,
      facts: ready.layoutFacts,
      settings: settings,
      viewportWidth: 600,
      viewportHeight: 400,
      devicePixelRatio: 1,
      fixedLayout: layout,
      fonts: fonts,
    );
    final page = SourcePageId(
      content: ready.identity,
      sectionIndex: 0,
      spineIndex: 0,
      stableId: 'EPUB/p0.xhtml',
    );
    current = false;
    await expectLater(
      sources.unitSources.loadSource(page),
      throwsA(isA<PreparationCancelled>()),
    );
    expect(sources.isActive, false);
    await sources.close();
    expect(sources.publication.isActive, false);
    expect(sources.retainedSourceOwners, 0);
    composition.dispose();
    pool.close();
    await pool.drained;
    ready.release();
  });

  test('close during paused worker preload drains and releases once', () async {
    final events = ReceivePort();
    final paused = Completer<PublicationWorkerPreloadEvent>();
    final subscription = events.listen((value) {
      if (value is! PublicationWorkerPreloadEvent) return;
      if (paused.isCompleted) {
        value.resume.send(null);
      } else {
        paused.complete(value);
      }
    });
    final h = await PrepareHarness.create(
      workerHooks: PublicationWorkerTestHooks(
        events.sendPort,
        pausePreload: true,
      ),
    );
    h.bytes = fixedSidesPublication(['center']);
    final ready = await h.service.prepare(h.key);
    final pool = PageSurfacePool();
    final fonts = FontRegistry(processBudget: ProcessFontBudget());
    const settings = ReaderSettings();
    LayoutIdentity layout(int section) => fixedSectionLayout(
      identity: ready.identity,
      section: section,
      viewportWidth: 600,
      viewportHeight: 400,
      devicePixelRatio: 1,
      settings: settings,
    );
    late PublicationFixedSources sources;
    sources = await PublicationFixedSources.open(
      preparedBook: ready,
      activation: h.session,
      layout: layout(0),
      isCurrent: () => true,
      acquireLease: () => h.f.cache.acquireHead(h.session, h.key),
      queue: h.service.queue,
      worker: h.service.worker.get,
      pool: pool,
      fonts: fonts,
      layoutFor: layout,
      sectionBaseFor: (page) =>
          sources.book.sections[page.sectionIndex].spine.cfiBase,
    );
    final page = SourcePageId(
      content: ready.identity,
      sectionIndex: 0,
      spineIndex: 0,
      stableId: 'EPUB/p0.xhtml',
    );
    final loading = sources.unitSources.loadSource(page);
    final event = await paused.future;
    final closing = sources.close();
    await expectLater(
      loading.timeout(const Duration(seconds: 5)),
      throwsA(isA<PreparationCancelled>()),
    );
    event.resume.send(null);
    await closing.timeout(const Duration(seconds: 5));
    expect(sources.retainedSourceOwners, 0);
    expect(sources.publication.isActive, false);
    await subscription.cancel();
    events.close();
    pool.close();
    await pool.drained;
    ready.release();
  });
}
