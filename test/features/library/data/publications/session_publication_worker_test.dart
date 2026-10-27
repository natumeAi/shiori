import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/features/library/data/publications/session_publication_worker.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_exception.dart';

import '../library_test_support.dart';

void main() {
  test(
    'concurrent get shares a worker and retirement closes it during spawn',
    () async {
      final active = session();
      final guard = SessionPublicationGuard()..select(active);
      final spawn = Completer<PublicationWorker>();
      var count = 0;
      final owner = SessionPublicationWorker(
        active,
        guard,
        spawn: () {
          count++;
          return spawn.future;
        },
      );
      final first = owner.get();
      final second = owner.get();
      final firstCanceled = expectLater(
        first,
        throwsA(isA<RequestCancelled>()),
      );
      final secondCanceled = expectLater(
        second,
        throwsA(isA<RequestCancelled>()),
      );
      guard.retire();
      final worker = await PublicationWorker.spawn();
      spawn.complete(worker);
      await firstCanceled;
      await secondCanceled;
      await owner.closed;
      expect(count, 1);
      expect(worker.isClosed, isTrue);
      await expectLater(owner.get(), throwsA(isA<RequestCancelled>()));
    },
  );

  test('failed worker spawn is retryable in the same session', () async {
    final active = session();
    final guard = SessionPublicationGuard()..select(active);
    var count = 0;
    final owner = SessionPublicationWorker(
      active,
      guard,
      spawn: () {
        count++;
        return count == 1
            ? Future.error(
                const PublicationWorkerException(
                  PublicationWorkerFailure.workerError,
                ),
              )
            : PublicationWorker.spawn();
      },
    );
    await expectLater(owner.get(), throwsA(isA<PublicationWorkerException>()));
    final worker = await owner.get();
    expect(count, 2);
    expect(identical(worker, await owner.get()), isTrue);
    guard.retire();
    await owner.closed;
    expect(worker.isClosed, isTrue);
  });
}
