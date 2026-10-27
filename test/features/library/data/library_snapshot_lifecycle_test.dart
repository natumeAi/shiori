import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/library/data/library_snapshot_repository.dart';

import '../../../core/network/fake_server_adapter.dart';
import 'library_test_support.dart';
import 'snapshot_cache_test_support.dart';

void main() {
  late SessionPublicationGuard guard;
  late MemorySnapshotCache cache;
  setUp(() {
    guard = SessionPublicationGuard();
    cache = MemorySnapshotCache();
    addTearDown(guard.retire);
  });

  LibrarySnapshotRepository repository(
    ServerSession active,
    FakeServerAdapter adapter, {
    Future<void> Function(Duration)? pause,
  }) {
    final transport = SessionTransport(active, adapter: adapter);
    final repo = LibrarySnapshotRepository(
      transport,
      cache,
      guard,
      waitBeforeRetry: pause,
    );
    addTearDown(() {
      repo.dispose();
      transport.dispose();
    });
    return repo;
  }

  for (final lateError in [false, true]) {
    test(
      'A -> B -> A rejects old response (error=$lateError), accepts lower revision on new activation',
      () async {
        final firstA = guard.createSession(session().endpoint);
        guard.select(firstA);
        cache.values[firstA.serverKey] = storedFixture();
        final entered = Completer<void>();
        final response = Completer<ResponseBody>();
        final adapter = FakeServerAdapter((_, _) {
          entered.complete();
          return response.future;
        });
        final old = repository(firstA, adapter);
        final refresh = old.load();
        await entered.future;
        final before = old.state;
        guard.retire();
        final b = guard.createSession(
          ServerEndpoint.parse('https://b.example.test').endpoint!,
        );
        guard.select(b);
        final other = repository(
          b,
          FakeServerAdapter((_, _) => snapshotRevision(99)),
        );
        await other.load();
        guard.retire();
        final secondA = guard.createSession(firstA.endpoint);
        guard.select(secondA);
        final fresh = repository(
          secondA,
          FakeServerAdapter((_, _) => snapshotRevision(1)),
        );
        await fresh.load();
        // Does not wait for an adapter that ignores transport cancellation.
        await refresh;
        if (lateError) {
          response.completeError(StateError('late'));
        } else {
          response.complete(snapshotRevision(900));
        }
        await Future<void>.value();
        await Future<void>.value();
        expect(old.state, same(before));
        expect(old.state.error, isNull);
        expect(cache.values[firstA.serverKey]!.revision, 1);
        expect(cache.values[b.serverKey]!.revision, 99);
        expect(fresh.state.snapshot!.stored.revision, 1);
        expect(guard.current, secondA);
        expect(cache.writes, 2);
      },
    );
  }

  test(
    'retirement before snapshot transaction admission prevents stale dispatch',
    () async {
      final active = guard.createSession(session().endpoint);
      guard.select(active);
      cache.values[active.serverKey] = storedFixture();
      final entered = Completer<void>();
      final release = Completer<void>();
      cache.beforeWrite = () {
        entered.complete();
        return release.future;
      };
      final repo = repository(
        active,
        FakeServerAdapter((_, _) => responseFixture('snapshot_200')),
      );
      final refresh = repo.load();
      await entered.future;
      guard.retire();
      await refresh;
      release.complete();
      await Future<void>.value();
      await Future<void>.value();
      expect(cache.writes, 0);
      expect(cache.values[active.serverKey]!.etag, 'W/"opaque exact"');
      expect(repo.state.error, isNull);
    },
  );

  test(
    'synchronous stale-state listener can retire session before any request',
    () async {
      final active = session();
      guard.select(active);
      cache.values[active.serverKey] = storedFixture();
      final adapter = FakeServerAdapter(
        (_, _) => responseFixture('snapshot_200'),
      );
      final repo = repository(active, adapter);
      final sub = repo.changes.listen((_) => guard.retire());
      addTearDown(sub.cancel);
      await repo.load();
      expect(adapter.requests, isEmpty);
      expect(cache.writes, 0);
    },
  );

  test(
    'retirement interrupts retry wait and never starts another request',
    () async {
      final active = session();
      guard.select(active);
      final waiting = Completer<void>();
      final pause = Completer<void>();
      final adapter = FakeServerAdapter(
        (options, _) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
      );
      final repo = repository(
        active,
        adapter,
        pause: (_) {
          waiting.complete();
          return pause.future;
        },
      );
      final refresh = repo.load();
      await waiting.future;
      guard.retire();
      await refresh;
      pause.complete();
      await Future<void>.value();
      expect(adapter.requests.length, 1);
      expect(repo.state.error, isNull);
    },
  );

  test(
    'disposed repository rejects future loads silently and publishes no error',
    () async {
      final active = session();
      guard.select(active);
      final adapter = FakeServerAdapter(
        (_, _) => responseFixture('snapshot_200'),
      );
      final repo = repository(active, adapter);
      repo.dispose();
      await repo.load();
      expect(adapter.requests, isEmpty);
      expect(repo.state.error, isNull);
    },
  );
  test(
    'synchronous state listener may dispose the repository safely',
    () async {
      final active = session();
      guard.select(active);
      final adapter = FakeServerAdapter(
        (_, _) => responseFixture('snapshot_200'),
      );
      final repo = repository(active, adapter);
      final sub = repo.changes.listen((_) => repo.dispose());
      addTearDown(sub.cancel);
      await repo.load();
      expect(adapter.requests, isEmpty);
      expect(repo.state.error, isNull);
    },
  );
}
