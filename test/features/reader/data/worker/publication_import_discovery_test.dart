import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_exception.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_protocol.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_test_hooks.dart';

import 'import_test_support.dart';
import 'worker_test_support.dart';

void main() {
  late Directory directory;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('shiori-import-discovery-');
    addTearDown(() => directory.deleteSync(recursive: true));
  });

  File resourceBook() => writeImport(
    directory,
    importEntries(
      sources: [
        sourcePage(
          head: '<link rel="stylesheet" href="style.css"/>',
          body:
              '<img src="page.png" srcset="page.png 1x, missing.png 2x"/>'
              '<object data="art.svg"/><img src="https://fixture.invalid/remote.png"/>'
              '<img src="//fixture.invalid/remote.png"/><img src="data:image/png;base64,AA=="/>'
              '<svg xmlns="http://www.w3.org/2000/svg"><use href="#local"/></svg>',
        ),
        sourcePage(body: '<img src="unloaded.png"/>'),
      ],
    ),
  );

  test('resource inventory follows local CSS/SVG cycles, keeps missing/external facts and excludes later sections', () async {
    final file = resourceBook();
    final events = ReceivePort();
    final observed = <PublicationWorkerWorkEvent>[];
    final subscription = events.listen((event) {
      if (event is PublicationWorkerWorkEvent) observed.add(event);
    });
    final worker = await PublicationWorker.spawn(
      testHooks: PublicationWorkerTestHooks(events.sendPort),
    );
    addTearDown(() async {
      await worker.close();
      await subscription.cancel();
      events.close();
    });
    final result = await ReaderWorkGuard.callback(
      () => worker.prepare(file.path, identityFor(file)),
    );
    final references = result.firstSection.resources;
    expect(references.map((r) => r.path).whereType<String>().toSet(), {
      'EPUB/style.css',
      'EPUB/nested.css',
      'EPUB/page.png',
      'EPUB/art.svg',
      'EPUB/missing.png',
    });
    expect(
      references.where((r) => r.path == 'EPUB/missing.png').single.present,
      isFalse,
    );
    expect(
      references.where((r) => r.url.startsWith('https:')).single.path,
      isNull,
    );
    expect(references.where((r) => r.url.startsWith('//')).single.path, isNull);
    expect(
      references.where((r) => r.url.startsWith('data:')).single.path,
      isNull,
    );
    expect(references.where((r) => r.url == '#local').single.path, isNull);
    expect(references.any((r) => r.url == 'unloaded.png'), isFalse);
    expect(
      references.any(
        (r) => r.sourcePath == 'EPUB/art.svg' && r.url == 'page.png',
      ),
      isTrue,
    );
    expect(
      references.any(
        (r) => r.sourcePath == 'EPUB/nested.css' && r.path == 'EPUB/style.css',
      ),
      isTrue,
    );
    await worker.close();
    expect(
      observed.where((e) => e.work == PublicationWorkerWork.sectionStyle),
      hasLength(1),
    );
    expect(
      observed.where((e) => e.work == PublicationWorkerWork.canonicalIndex),
      hasLength(1),
    );
    expect(observed.map((e) => e.isolateControl).toSet(), hasLength(1));
    expect(
      observed.every((e) => e.isolateControl != Isolate.current.controlPort),
      isTrue,
    );
  });

  for (final action in ['cancel', 'reopen', 'close']) {
    test(
      '$action during nested resource discovery discards the late import reply',
      () async {
        final file = resourceBook();
        final events = ReceivePort();
        final iterator = StreamIterator<Object?>(events);
        final worker = await PublicationWorker.spawn(
          testHooks: PublicationWorkerTestHooks(
            events.sendPort,
            pauseDiscovery: true,
          ),
        );
        addTearDown(() async {
          await worker.close();
          await iterator.cancel();
          events.close();
        });
        final cancellation = PublicationCancellation();
        final importing = worker.prepare(
          file.path,
          identityFor(file),
          tag: tagA,
          cancellation: cancellation,
        );
        final rejected = expectLater(
          importing,
          throwsA(
            workerFailure(switch (action) {
              'cancel' => PublicationWorkerFailure.canceled,
              'reopen' => PublicationWorkerFailure.stale,
              _ => PublicationWorkerFailure.closed,
            }),
          ),
        );
        Future<PublicationWorkerDiscoveryEvent> nextGate() async {
          while (await iterator.moveNext()) {
            if (iterator.current
                case final PublicationWorkerDiscoveryEvent event) {
              return event;
            }
          }
          throw StateError('Missing discovery gate');
        }

        (await nextGate()).resume.send(PublicationWorkerTestAction.resume);
        // First source's references were collected; now inside a dependency.
        final gate = await nextGate();
        if (action == 'cancel') cancellation.cancel();
        final next = action == 'close'
            ? worker.close()
            : worker.open(fixturePath, tagA);
        await rejected;
        var dispatched = false;
        unawaited(
          next.then((_) {
            dispatched = true;
          }),
        );
        expect(dispatched, isFalse);
        gate.resume.send(PublicationWorkerTestAction.resume);
        while (await iterator.moveNext()) {
          final event = iterator.current;
          if (event is PublicationWorkerDiscoveryEvent) {
            event.resume.send(PublicationWorkerTestAction.resume);
          }
          if (event is PublicationWorkerRequestEvent &&
              (event.request is OpenPublication ||
                  event.request is ClosePublication)) {
            break;
          }
        }
        await next;
        if (action != 'close') {
          expect((await worker.loadSection(0)).nodes, isNotEmpty);
        }
        await worker.close();
        file.deleteSync();
      },
    );
  }
}
