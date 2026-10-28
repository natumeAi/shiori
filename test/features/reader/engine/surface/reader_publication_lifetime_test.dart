import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/library/data/publications/publication_cache_exception.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_exception.dart';
import 'package:shiori/features/reader/engine/pagination/layout_identity.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/surface/reader_publication_lifetime.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/prepared_reader_session.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';

import '../../../library/data/publications/prepare_test_support.dart';
import '../../../library/data/publications/cache_test_support.dart'
    show cacheFailure;
import '../../data/worker/worker_test_support.dart' show workerFailure;
import 'surface_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'route release preserves independent file pin and defers another prepare',
    () async {
      final h = await PrepareHarness.create(limit: 16384);
      final service = h.service;
      final ready = await service.prepare(h.key);
      final layout = LayoutIdentity(
        contentId: ready.identity.sha256,
        sectionIndex: 0,
        viewportWidth: 400,
        viewportHeight: 600,
        devicePixelRatio: 1,
        settings: const ReaderSettings(),
        fontSignature: 'none',
        generation: 1,
      );
      final activation = h.session;
      final reader = await ReaderPublicationLifetime.open(
        preparedBook: ready,
        activation: activation,
        layout: layout,
        isCurrent: () => h.f.guard.isCurrent(activation),
        acquireLease: () =>
            h.f.cache.acquireHead(activation, ready.identity.bookKey),
        queue: service.queue,
        worker: service.worker.get,
      );
      ready.release();
      expect(ready.isReleased, isTrue);
      expect(File(ready.lease.local.path).existsSync(), isTrue);
      await expectLater(
        h.f.cache.reserveBytes(h.f.limit),
        throwsA(cacheFailure(PublicationCacheFailure.cacheBusy)),
      );
      final preload = await reader.preload(0, expectedLayout: layout);
      expect(preload.plan.document.nodes, isNotEmpty);
      var prepared = false;
      final next = service.prepare(h.key, refresh: true).then((value) {
        prepared = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      expect(prepared, isFalse);
      final drain = Completer<void>();
      final disposed = Completer<void>();
      final events = <String>[];
      final closing = reader.close(
        disableAndInvalidate: () => events.add('disable/invalidate'),
        cancelAndDrain: () {
          events.add('drain');
          return drain.future;
        },
        disposeScenesAndSources: () async {
          events.add('dispose');
          preload.dispose();
          await disposed.future;
        },
      );
      expect(events, ['disable/invalidate', 'drain']);
      await expectLater(
        reader.preload(0, expectedLayout: layout),
        throwsA(workerFailure(PublicationWorkerFailure.stale)),
      );
      drain.complete();
      await Future<void>.delayed(Duration.zero);
      expect(events, ['disable/invalidate', 'drain', 'dispose']);
      expect(prepared, isFalse);
      disposed.complete();
      await closing;
      final repeated = reader.close(
        disableAndInvalidate: () => fail('twice'),
        cancelAndDrain: () async => fail('twice'),
        disposeScenesAndSources: () async => fail('twice'),
      );
      expect(identical(closing, repeated), isTrue);
      (await next).release();
      expect(prepared, isTrue);
      final evict = await h.f.cache.reserveBytes(h.f.limit);
      evict.release();
      expect(File(ready.lease.local.path).existsSync(), isFalse);
    },
  );

  test('full acquired identity is compared before worker access', () async {
    final h = await PrepareHarness.create();
    final service = h.service;
    final old = await service.prepare(h.key);
    final layout = LayoutIdentity(
      contentId: old.identity.sha256,
      sectionIndex: 0,
      viewportWidth: 400,
      viewportHeight: 600,
      devicePixelRatio: 1,
      settings: const ReaderSettings(),
      fontSignature: 'none',
    );
    h.etag = 'changed';
    h.bytes = importZip(
      importEntries(sources: [sourcePage(body: '<p>Changed</p>')]),
    );
    final replacement = await service.prepare(h.key, refresh: true);
    var workerCalls = 0;
    await expectLater(
      ReaderPublicationLifetime.open(
        preparedBook: old,
        activation: h.session,
        layout: layout,
        isCurrent: () => true,
        acquireLease: () => h.f.cache.acquireHead(h.session, h.key),
        queue: service.queue,
        worker: () {
          workerCalls++;
          return service.worker.get();
        },
      ),
      throwsA(workerFailure(PublicationWorkerFailure.incompatibleIdentity)),
    );
    expect(workerCalls, 0);
    old.release();
    replacement.release();
    final eviction = await h.f.cache.reserveBytes(h.f.limit);
    eviction.release();
    expect(await h.f.store.readPublicationHead(h.key), isNull);
  });

  test(
    'session close drains motion before scenes, adapters and file',
    () async {
      final h = await PrepareHarness.create();
      final service = h.service;
      final ready = await service.prepare(h.key);
      final layout = LayoutIdentity(
        contentId: ready.identity.sha256,
        sectionIndex: 0,
        viewportWidth: 400,
        viewportHeight: 600,
        devicePixelRatio: 1,
        settings: const ReaderSettings(),
        fontSignature: '',
      );
      final activation = h.session;
      final reader = await ReaderPublicationLifetime.open(
        preparedBook: ready,
        activation: activation,
        layout: layout,
        isCurrent: () => h.f.guard.isCurrent(activation),
        acquireLease: () => h.f.cache.acquireHead(activation, h.key),
        queue: service.queue,
        worker: service.worker.get,
      );
      ready.release();
      final preload = await reader.preload(0, expectedLayout: layout);
      final plan = preload.plan;
      final section = await SectionPreparer().prepare(
        PrepareRequest.resources(
          resources: preload.resources,
          sectionHref: plan.href,
          sectionBase: plan.cfiBase,
          sectionIndex: 0,
          document: plan.document,
          styled: plan.styled,
          settings: layout.settings,
          viewportWidth: 400,
          viewportHeight: 600,
          devicePixelRatio: 1,
          contentId: layout.contentId,
        ),
      );
      // Native font signature is part of the actual pagination identity.
      expect(section.identity, layout);
      final motion = Completer<void>();
      final source = Completer<void>();
      final pool = PageSurfacePool();
      final session = (await PreparedReaderSession.open(
        pool: pool,
        section: section,
        pageIndex: 0,
        sectionCount: 1,
        loadSection: (_) async => section,
        theme: surfaceTheme,
        activation: activation,
        isActivationCurrent: h.f.guard.isCurrent,
        publication: reader,
        cancelAndDrainMotion: () => motion.future,
        disposeSourceAdapters: () async {
          expect(pool.liveSurfaces, 0);
          section.dispose();
          await source.future;
        },
      ))!;
      final surface = session.frames.value.current;
      final external = (await pool.prepare(section, 0, surfaceTheme))!;
      session.close();
      session.close();
      expect(surface.disposed, isFalse);
      expect(await pool.prepare(section, 0, surfaceTheme), isNull);
      motion.complete();
      await Future<void>.delayed(Duration.zero);
      expect(surface.disposed, isTrue);
      expect(external.surface.disposed, isFalse);
      await expectLater(
        h.f.cache.reserveBytes(h.f.limit),
        throwsA(cacheFailure(PublicationCacheFailure.cacheBusy)),
      );
      external.release();
      source.complete();
      await session.closed;
      final evict = await h.f.cache.reserveBytes(h.f.limit);
      evict.release();
      expect(File(ready.lease.local.path).existsSync(), isFalse);
    },
  );
}
