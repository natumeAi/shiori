import 'dart:async';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/worker/publication_snapshot.dart';
import 'package:shiori/features/reader/data/worker/publication_tag.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_exception.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_protocol.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_test_hooks.dart';

const fixturePath = 'assets/reader_fixtures/one-page.epub';
const fixtureSectionPath = 'EPUB/only.xhtml';
const tagA = PublicationTag('session-A/content-1');
const tagB = PublicationTag('session-B/content-2');

Matcher workerFailure(PublicationWorkerFailure failure) =>
    isA<PublicationWorkerException>().having(
      (e) => e.failure,
      'failure',
      failure,
    );

/// Real isolates with message-driven gates; no timing sleeps or fake worker.
final class WorkerHarness {
  final events = ReceivePort();
  late final iterator = StreamIterator<Object?>(events);
  late final PublicationWorker worker;
  final work = <PublicationWorkerWorkEvent>[];
  final requests = <PublicationWorkerRequestEvent>[];

  Future<void> start() async {
    worker = await PublicationWorker.spawn(
      testHooks: PublicationWorkerTestHooks(
        events.sendPort,
        pauseRequests: true,
      ),
    );
  }

  Future<PublicationWorkerRequestEvent> nextRequest() async {
    while (await iterator.moveNext()) {
      final event = iterator.current;
      if (event is PublicationWorkerWorkEvent) work.add(event);
      if (event is PublicationWorkerRequestEvent) {
        requests.add(event);
        return event;
      }
    }
    throw StateError('Worker event stream closed');
  }

  void resume(PublicationWorkerRequestEvent event) =>
      event.resume!.send(PublicationWorkerTestAction.resume);

  Future<PublicationSnapshot> open({String path = fixturePath}) async {
    final result = worker.open(path, tagA);
    final event = await nextRequest();
    expect(event.request, isA<OpenPublication>());
    resume(event);
    return result;
  }

  Future<void> dispose() async {
    await worker.close();
    await iterator.cancel();
    events.close();
  }
}
