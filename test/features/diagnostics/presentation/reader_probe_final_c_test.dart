import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/diagnostics/probe_declarations.dart';
import 'package:shiori/features/diagnostics/data/book_digest.dart';
import 'package:shiori/features/diagnostics/data/probe_book_repository.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/reader_probe_controller.dart';
import 'package:shiori/features/library/data/publications/publication_lease.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';
import 'package:shiori/features/reader/engine/pagination/anchor.dart';

import '../../../helpers/reader_probe_fixtures.dart';
import '../../library/data/publications/prepare_test_support.dart';
import '../../reader/engine/surface/publication_fixed_test_support.dart';
import '../../reader/data/worker/import_test_support.dart' as input;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final mixed in [false, true]) {
    for (final manual in [false, true]) {
      test(
        'new capture identity and position mixed=$mixed manual=$manual',
        () async {
          final h = await PrepareHarness.create();
          h.bytes = mixed
              ? corpusPublication('mixed-navigation-positive')
              : fixedSidesPublication(['center', 'center']);
          final ready = await h.service.prepare(h.key);
          addTearDown(ready.release);
          final recorder = readerRecorder(capacity: 1024);
          addTearDown(recorder.dispose);
          final controller = ReaderProbeController(recorder);
          addTearDown(controller.dispose);
          controller.identity = ProbeBook(
            sha256: readerDigest,
            read: () async => h.bytes,
          );
          expect(
            await controller.openPublication(
              book: ready,
              activation: h.session,
              isCurrent: h.f.guard.isCurrent,
              acquireLease: () => h.f.cache.acquireHead(h.session, h.key),
              queue: h.service.queue,
              worker: h.service.worker.get,
              section: 1,
            ),
            true,
          );
          expect(controller.identity!.sha256 == ready.identity.sha256, true);
          expect(controller.session!.position.sectionIndex, 1);
          ready.release();
          expect(
            controller.accepted.value!.layoutKey,
            controller.session!.position.layoutKey,
          );
          await recorder.start(
            runId: 'capture',
            bookSha256: controller.identity!.sha256,
            fixtureId: controller.identity!.fixtureId,
            scenarioId: manual ? 'R11' : 'R02',
            repeatIndex: 1,
            repeatCount: 1,
            input: manual ? 'manual_touch' : 'synthetic_injected',
            declarations: const ProbeDeclarations(),
            metadata: const {},
          );
          await controller.jump(manual ? 1 : 0, cold: true);
          expect(controller.accepted.value!.sectionIndex, manual ? 1 : 0);
          final record = (await recorder.stop())!;
          expect(record.bookSha256 == ready.identity.sha256, true);
        },
      );
    }

    test(
      'fixed-safe counts, jumps and frozen replacement mixed=$mixed',
      () async {
        final h = await PrepareHarness.create();
        h.bytes = mixed
            ? corpusPublication('mixed-navigation-positive')
            : fixedSidesPublication(['left', 'right', 'center']);
        final ready = await h.service.prepare(h.key);
        addTearDown(ready.release);
        final recorder = readerRecorder();
        addTearDown(recorder.dispose);
        final controller = ReaderProbeController(recorder)
          ..width = 600
          ..height = 400;
        addTearDown(controller.dispose);
        await controller.openPublication(
          book: ready,
          activation: h.session,
          isCurrent: h.f.guard.isCurrent,
          acquireLease: () => h.f.cache.acquireHead(h.session, h.key),
          queue: h.service.queue,
          worker: h.service.worker.get,
          section: 1,
        );
        ready.release();
        expect(controller.pageCount, 1);
        await controller.jump(
          controller.sectionCount - 1,
          page: -1,
          cold: true,
        );
        expect(controller.accepted.value!.atEnd, true);
        final old = controller.session!;
        final source = controller.accepted.value!.sectionIndex;
        final nextSettings = controller.settings.copyWith(fontSize: 26);
        await controller.reflow(nextSettings);
        expect(controller.session, isNot(same(old)));
        expect(old.state, TurnSessionState.closed);
        expect(controller.settings, nextSettings);
        expect(controller.accepted.value!.sectionIndex, source);
        expect(
          controller.session!.frames.value.current.layout.settings,
          nextSettings,
        );
        controller.width = 400;
        controller.height = 600;
        controller.dpr = 2;
        await controller.reflow(nextSettings);
        expect(
          controller.session!.frames.value.current.layout.viewportWidth,
          400,
        );
        expect(
          controller.session!.frames.value.current.layout.devicePixelRatio,
          2,
        );
        await controller.jump(0);
        expect(controller.accepted.value!.atStart, true);
      },
    );
  }

  test(
    'mixed reflow last page restores its source after repagination',
    () async {
      final h = await PrepareHarness.create();
      h.bytes = input.importZip(
        input.importEntries(
          sources: [
            input.sourcePage(
              head: input.viewportHead,
              body: '<p>Fixed source.</p>',
            ),
            input.sourcePage(
              body:
                  '<p>${List.filled(600, 'A long reflow source. ').join()}</p>',
            ),
          ],
          properties: [
            'rendition:layout-pre-paginated rendition:spread-none',
            '',
          ],
        ),
      );
      final ready = await h.service.prepare(h.key);
      addTearDown(ready.release);
      final recorder = readerRecorder();
      addTearDown(recorder.dispose);
      final controller = ReaderProbeController(recorder);
      addTearDown(controller.dispose);
      expect(
        await controller.openPublication(
          book: ready,
          activation: h.session,
          isCurrent: h.f.guard.isCurrent,
          acquireLease: () => h.f.cache.acquireHead(h.session, h.key),
          queue: h.service.queue,
          worker: h.service.worker.get,
          section: 1,
        ),
        true,
      );
      ready.release();
      expect(controller.pageCount, greaterThan(4));
      await controller.jump(1, page: -1, cold: true);
      final cfi = controller.accepted.value!.cfi;
      final oldCount = controller.pageCount;
      controller.width = 800;
      controller.height = 1000;
      await controller.reflow(controller.settings);
      expect(controller.pageCount, lessThan(oldCount));
      final current = controller.session!.frames.value.current;
      final proof = PageAnchors(current.section).prove(cfi);
      expect(proof.ok, true);
      expect(current.pageIndex, proof.pageIndex);
      final large = controller.settings.copyWith(fontSize: 26);
      await controller.reflow(large);
      expect(controller.session!.frames.value.current.layout.settings, large);
      expect(controller.accepted.value!.sectionIndex, 1);
    },
  );

  test('reflow fixed reflow retires publication owners exactly once', () async {
    final h = await PrepareHarness.create();
    final reflow = h.bytes;
    h.bytes = fixedSidesPublication(['center']);
    final ready = await h.service.prepare(h.key);
    addTearDown(ready.release);
    final recorder = readerRecorder();
    addTearDown(recorder.dispose);
    final controller = ReaderProbeController(
      recorder,
      openBook: (b) async => EpubBook.open(b),
    );
    addTearDown(controller.dispose);
    final raw = ProbeBook(sha256: sha256Hex(reflow), read: () async => reflow);
    await controller.open(raw);
    final first = controller.session!;
    var releases = 0;
    await controller.openPublication(
      book: ready,
      activation: h.session,
      isCurrent: h.f.guard.isCurrent,
      acquireLease: () async {
        final lease = (await h.f.cache.acquireHead(h.session, h.key))!;
        return PublicationLease(lease.generation, lease.local, () {
          releases++;
          lease.release();
        });
      },
      queue: h.service.queue,
      worker: h.service.worker.get,
    );
    expect(first.state, TurnSessionState.closed);
    ready.release();
    final fixed = controller.session!;
    await controller.open(raw);
    expect(fixed.state, TurnSessionState.closed);
    expect(controller.identity, same(raw));
    expect(controller.session!.unit, isNull);
    expect(releases, 1);
    controller.dispose();
    await controller.session!.closed;
    await h.idle();
    expect(releases, 1);
  });
}
