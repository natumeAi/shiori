import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_budget.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';
import 'package:shiori/features/reader/data/worker/preloaded_publication_section.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/pagination/page_painter.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';

import '../../data/worker/import_test_support.dart';
import '../layout/layout_test_support.dart';
import 'guarded_resource_source.dart';

PrepareRequest requestFor(
  PreloadedPublicationSection loaded,
  GuardedResourceSource source,
) => PrepareRequest.resources(
  resources: source,
  sectionHref: loaded.plan.href,
  sectionBase: loaded.plan.cfiBase,
  sectionIndex: loaded.plan.sectionIndex,
  document: loaded.plan.document,
  styled: loaded.plan.styled,
  settings: const ReaderSettings(),
  viewportWidth: phoneWidth,
  viewportHeight: phoneHeight,
  contentId: 'ownership',
);

void main() {
  initEngineBinding();
  late Directory temp;
  late PublicationWorker worker;
  late ReaderResourceBudget budget;
  setUp(() async {
    temp = Directory.systemTemp.createTempSync('shiori-section-resources-');
    worker = await PublicationWorker.spawn();
    budget = ReaderResourceBudget();
    final file = writeImport(
      temp,
      importEntries(
        sources: [
          sourcePage(
            body:
                '$simpleFixedBody${[for (var i = 0; i < 100; i++) '<p>Paragraph $i repeated content for pagination.</p>'].join()}',
          ),
        ],
      ),
    );
    await worker.prepare(file.path, identityFor(file));
  });
  tearDown(() async {
    await worker.close();
    temp.deleteSync(recursive: true);
  });

  test(
    'prepared section owns encoded bytes through image/surface preparation',
    () async {
      final loaded = await worker.preloadSection(0, budget: budget);
      final source = GuardedResourceSource(loaded.resources);
      final preparer = SectionPreparer();
      final section = await preparer.prepare(requestFor(loaded, source));
      final image = section.blocks.firstWhere(
        (laid) => laid.block is ImageBlock,
      );
      final page = image.linePage.single;
      expect(budget.retainedBytes, greaterThan(0));
      final initialReads = source.reads;
      await section.ensureImages(page, preparer.images);
      expect(source.reads, greaterThan(initialReads));
      expect(section.leaseOf(image.index), isNotNull);
      final pool = PageSurfacePool();
      final surface = await pool.prepare(
        section,
        page,
        const PagePaintTheme(background: 0xFFFFFFFF),
      );
      expect(surface, isNotNull);
      expect(source.presenceChecks, greaterThan(0));
      expect(source.disposals, 0);
      surface!.release();
      pool.close();
      section.dispose();
      section.dispose();
      expect(source.disposals, 1);
      expect(
        loaded.resources.miss('EPUB/page.png'),
        ReaderResourceMiss.disposed,
      );
      expect(budget.accountedBytes, 0);
      await section.ensureImages(page, preparer.images);
      preparer.images.clearUnleased();
    },
  );

  test(
    'cancellation at the first checkpoint releases preloaded leases',
    () async {
      final loaded = await worker.preloadSection(0, budget: budget);
      final source = GuardedResourceSource(loaded.resources);
      final control = PreparationControl()..cancel();
      await expectLater(
        SectionPreparer().prepare(requestFor(loaded, source), control: control),
        throwsA(isA<PreparationCancelled>()),
      );
      expect(source.disposals, 1);
      expect(budget.accountedBytes, 0);
    },
  );

  test(
    'cancellation after blocks were built releases encoded leases',
    () async {
      final loaded = await worker.preloadSection(0, budget: budget);
      final source = GuardedResourceSource(loaded.resources);
      final control = PreparationControl(
        slice: Duration.zero,
        yielder: () async {},
      );
      var pages = 0;
      await expectLater(
        SectionPreparer().prepare(
          requestFor(loaded, source),
          control: control,
          onPageReady: (_) {
            pages++;
            control.cancel();
          },
        ),
        throwsA(isA<PreparationCancelled>()),
      );
      expect(pages, greaterThan(0));
      expect(source.reads, greaterThan(0));
      expect(source.disposals, 1);
      expect(budget.accountedBytes, 0);
    },
  );

  test(
    'failed page callback releases built blocks and encoded leases',
    () async {
      final loaded = await worker.preloadSection(0, budget: budget);
      final source = GuardedResourceSource(loaded.resources);
      await expectLater(
        SectionPreparer().prepare(
          requestFor(loaded, source),
          onPageReady: (_) => throw StateError('injected'),
        ),
        throwsStateError,
      );
      expect(source.disposals, 1);
      expect(budget.accountedBytes, 0);
    },
  );

  test(
    'retirement revokes bytes even while a prepared section owns them',
    () async {
      final loaded = await worker.preloadSection(0, budget: budget);
      final source = GuardedResourceSource(loaded.resources);
      final section = await SectionPreparer().prepare(
        requestFor(loaded, source),
      );
      final closing = worker.close();
      expect(budget.accountedBytes, 0);
      expect(
        loaded.resources.miss('EPUB/page.png'),
        ReaderResourceMiss.retired,
      );
      section.dispose();
      expect(source.disposals, 1);
      await closing;
    },
  );
}
