import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/features/library/data/publications/preparation_controller.dart';
import 'package:shiori/features/library/data/publications/preparation_state.dart';
import 'package:shiori/features/library/data/publications/publication_cache_exception.dart';
import 'package:shiori/features/library/data/publications/session_publication_worker.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_test_hooks.dart';

import 'prepare_test_support.dart';

void main() {
  test(
    'cancel retains fallback pin until physical 304 import detaches',
    () async {
      final events = ReceivePort();
      final paused = Completer<SendPort>();
      var armed = false;
      final sub = events.listen((event) {
        if (event is PublicationWorkerDiscoveryEvent) {
          if (armed && !paused.isCompleted) {
            paused.complete(event.resume);
          } else {
            event.resume.send(null);
          }
        }
      });
      addTearDown(() async {
        await sub.cancel();
        events.close();
      });
      final h = await PrepareHarness.create(
        workerHooks: PublicationWorkerTestHooks(
          events.sendPort,
          pauseDiscovery: true,
        ),
      );
      final old = await h.service.prepare(h.key);
      old.release();
      armed = true;
      final pending = h.service.prepare(h.key);
      final canceled = expectLater(pending, throwsA(isA<RequestCancelled>()));
      final resume = await paused.future;
      h.service.cancel(h.key);
      await canceled;
      final needed = h.f.limit - old.lease.generation.byteLength + 1;
      try {
        await expectLater(
          h.f.cache.reserveBytes(needed),
          throwsA(
            isA<PublicationCacheException>().having(
              (e) => e.failure,
              'failure',
              PublicationCacheFailure.cacheBusy,
            ),
          ),
        );
        expect(await File(old.lease.local.path).exists(), isTrue);
      } finally {
        resume.send(null);
      }
      await h.clean();
      final charge = await h.f.cache.reserveBytes(needed);
      charge.release();
      expect(await h.f.store.readPublicationHead(h.key), isNull);
    },
  );

  test('synchronous preparing listener cancels before HTTP starts', () async {
    final h = await PrepareHarness.create();
    final provider = preparationControllerProvider(h.session, h.key);
    h.container.listen(provider, (_, next) {
      if (next is PreparationPreparing) h.controller.cancel();
    });
    await h.controller.prepare();
    expect(h.state, isA<PreparationIdle>());
    expect(h.adapter.requests, isEmpty);
  });

  test('synchronous content listener retires before ready handoff', () async {
    final h = await PrepareHarness.create();
    h.listen();
    final sub = h.service.contentChanges.listen((_) => h.f.guard.retire());
    addTearDown(sub.cancel);
    await h.controller.prepare();
    expect(h.state, isA<PreparationIdle>());
    await h.clean();
    final head = (await h.f.store.readPublicationHead(h.key))!;
    final reservation = await h.f.cache.reserveBytes(
      h.f.limit - head.byteLength + 1,
    );
    reservation.release();
    expect(await h.f.store.readPublicationHead(h.key), isNull);
  });

  test(
    'ordinary duplicates coalesce; refresh supersedes a held download',
    () async {
      final h = await PrepareHarness.create();
      final body = HeldBody();
      h.respondFile = (_) => fileBody(stream: body.controller.stream);
      final first = h.service.prepare(h.key);
      final canceled = expectLater(first, throwsA(isA<RequestCancelled>()));
      expect(identical(first, h.service.prepare(h.key)), isTrue);
      await body.started.future;
      h.respondFile = null;
      final refreshed = h.service.prepare(h.key, refresh: true);
      await canceled;
      final book = await refreshed;
      expect(book.identity.sha256, isNotEmpty);
      expect(
        h.adapter.requests.where((r) => r.uri.path.endsWith('/file')).length,
        2,
      );
      expect(h.adapter.requests.last.headers['If-None-Match'], isNull);
      await h.clean();
    },
  );

  test(
    'cancel during download returns idle, releases staging, then retries',
    () async {
      final h = await PrepareHarness.create();
      h.listen();
      final body = HeldBody();
      h.respondFile = (_) => fileBody(stream: body.controller.stream);
      final reachedBytes = Completer<void>();
      final sub = h.container.listen(
        preparationControllerProvider(h.session, h.key),
        (_, next) {
          if (next case PreparationPreparing(receivedBytes: final int received)
              when received > 0) {
            if (!reachedBytes.isCompleted) reachedBytes.complete();
          }
        },
      );
      addTearDown(sub.close);
      final pending = h.controller.prepare();
      await body.started.future;
      body.controller.add(Uint8List.fromList([1, 2, 3]));
      await reachedBytes.future;
      h.controller.cancel();
      await pending;
      expect(h.state, isA<PreparationIdle>());
      await h.clean();
      expect(await h.f.store.readPublicationHead(h.key), isNull);
      h.respondFile = null;
      await h.controller.prepare();
      expect(h.state, isA<PreparationReady>());
    },
  );

  for (final retire in [false, true]) {
    test(
      '${retire ? 'session switch' : 'cancel'} during real import discards late result',
      () async {
        final events = ReceivePort();
        final discovery = Completer<SendPort>();
        final subscription = events.listen((event) {
          if (event is PublicationWorkerDiscoveryEvent) {
            if (!discovery.isCompleted) {
              discovery.complete(event.resume);
            } else {
              event.resume.send(null);
            }
          }
        });
        addTearDown(() async {
          await subscription.cancel();
          events.close();
        });
        final h = await PrepareHarness.create(
          workerHooks: PublicationWorkerTestHooks(
            events.sendPort,
            pauseDiscovery: true,
          ),
        );
        h.listen();
        final oldSession = h.session;
        final oldKey = h.key;
        final service = h.service;
        final changes = <Object>[];
        final changesSub = service.contentChanges.listen(changes.add);
        addTearDown(changesSub.cancel);
        final pending = h.controller.prepare();
        final resume = await discovery.future;
        final owner = h.container.read(
          sessionPublicationWorkerProvider(oldSession),
        );
        final worker = await owner.get();
        if (retire) {
          h.f.select(serverB);
        } else {
          h.controller.cancel();
        }
        await pending; // Logical cancellation never waits for synchronous import.
        expect(
          h.container.read(preparationControllerProvider(oldSession, oldKey)),
          isA<PreparationIdle>(),
        );
        resume.send(null);
        await h.clean();
        expect(changes, isEmpty);
        expect(await h.f.store.readPublicationHead(oldKey), isNull);
        if (retire) {
          await owner.closed;
          expect(worker.isClosed, isTrue);
          final b = await h.service.prepare(h.key);
          expect(b.identity.bookKey.serverKey, serverB);
          h.f.select(serverA);
          final laterA = h.service;
          expect(h.session, isNot(oldSession));
          await expectLater(
            service.prepare(oldKey),
            throwsA(isA<RequestCancelled>()),
          );
          final a = await laterA.prepare(h.key);
          expect(a.identity.bookKey, oldKey);
        } else {
          expect(worker.isClosed, isFalse);
          await h.controller.prepare();
          expect(h.state, isA<PreparationReady>());
        }
      },
    );
  }

  test(
    'session retirement during download releases ready leases and pins',
    () async {
      final h = await PrepareHarness.create();
      final old = await h.service.prepare(h.key);
      final oldKey = h.key;
      final size = old.lease.generation.byteLength;
      final body = HeldBody();
      h.respondFile = (_) => fileBody(stream: body.controller.stream);
      final pending = h.service.prepare(h.key, refresh: true);
      final canceled = expectLater(pending, throwsA(isA<RequestCancelled>()));
      await body.started.future;
      h.f.select(serverB);
      await canceled;
      await h.clean();
      expect(old.isReleased, isTrue);
      final charge = await h.f.cache.reserveBytes(h.f.limit - size + 1);
      charge.release();
      expect(await h.f.store.readPublicationHead(oldKey), isNull);
      expect(await File(old.lease.local.path).exists(), isFalse);
    },
  );

  test(
    'controller disposal cancels work and leaves no stale state publication',
    () async {
      final h = await PrepareHarness.create();
      final provider = preparationControllerProvider(h.session, h.key);
      final sub = h.container.listen(provider, (_, _) {});
      final body = HeldBody();
      h.respondFile = (_) => fileBody(stream: body.controller.stream);
      final pending = h.controller.prepare();
      await body.started.future;
      sub.close();
      h.container.invalidate(provider);
      await pending;
      await h.clean();
      expect(await h.f.store.readPublicationHead(h.key), isNull);
    },
  );

  test('foreign BookKey is refused before network admission', () async {
    final h = await PrepareHarness.create();
    expect(() => h.service.prepare(BookKey(serverB, 7)), throwsArgumentError);
    expect(h.adapter.requests, isEmpty);
  });
}
