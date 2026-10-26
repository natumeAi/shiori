import 'dart:async';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_exception.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_protocol.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_runtime.dart';

import 'worker_test_support.dart';

void main() {
  test(
    'wire uses single-owner TransferableTypedData and enforces request tag',
    () async {
      final replies = ReceivePort();
      final iterator = StreamIterator<Object?>(replies);
      final isolate = await Isolate.spawn(
        runPublicationWorker,
        PublicationWorkerBootstrap(
          replies.sendPort,
          Isolate.current.controlPort,
          const EpubLimits(),
          64 * 1024 * 1024,
          null,
        ),
        onExit: replies.sendPort,
      );
      addTearDown(() async {
        isolate.kill(priority: Isolate.immediate);
        await iterator.cancel();
        replies.close();
      });
      await iterator.moveNext();
      final requests = iterator.current! as SendPort;
      requests.send(const OpenPublication(1, tagA, 1, fixturePath));
      await iterator.moveNext();
      expect(iterator.current, isA<PublicationOpened>());
      requests.send(
        const ReadPublicationResource(2, tagB, 1, fixtureSectionPath),
      );
      await iterator.moveNext();
      final rejected = iterator.current! as PublicationFailed;
      expect(rejected.id, 2);
      expect(rejected.error, workerFailure(PublicationWorkerFailure.notOpen));
      requests.send(
        const ReadPublicationResource(3, tagA, 1, fixtureSectionPath),
      );
      await iterator.moveNext();
      final resource = iterator.current! as PublicationResourceRead;
      expect(resource.bytes, isA<TransferableTypedData>());
      expect(resource.bytes!.materialize().lengthInBytes, resource.length);
      expect(resource.length, greaterThan(0));
      expect(resource.bytes!.materialize, throwsArgumentError);
      requests.send(const ClosePublication(4, tagA, 1));
      await iterator.moveNext();
      expect(iterator.current, isA<PublicationClosed>());
      await iterator.moveNext();
      expect(
        iterator.current,
        isNull,
      ); // Actual exit follows archive close ACK.
    },
  );

  test('unused worker closes and all later APIs fail as closed', () async {
    final worker = await PublicationWorker.spawn();
    addTearDown(worker.close);
    await worker.close();
    await expectLater(
      worker.open(fixturePath, tagA),
      throwsA(workerFailure(PublicationWorkerFailure.closed)),
    );
    await expectLater(
      worker.readResource('absent'),
      throwsA(workerFailure(PublicationWorkerFailure.closed)),
    );
  });
}
