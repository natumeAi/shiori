import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/core/storage/storage_exception.dart';
import 'package:shiori/core/storage/stored_snapshot.dart';
import 'package:shiori/features/library/data/library_decode_exception.dart';
import 'package:shiori/features/library/data/library_snapshot_protocol_exception.dart';
import 'package:shiori/features/library/data/library_snapshot_repository.dart';
import 'package:shiori/features/library/data/library_snapshot_state.dart';

import '../../../core/network/fake_server_adapter.dart';
import 'library_test_support.dart';
import 'snapshot_cache_test_support.dart';

void main() {
  final active = session();
  late SessionPublicationGuard guard;
  late MemorySnapshotCache cache;
  late FakeServerAdapter adapter;
  late LibrarySnapshotRepository repository;
  late List<LibrarySnapshotState> states;
  late List<Duration> delays;
  final now = DateTime.utc(2026, 10, 27, 12);

  void setup(FutureOr<ResponseBody> Function(RequestOptions, int) respond) {
    adapter = FakeServerAdapter(respond);
    final transport = SessionTransport(active, adapter: adapter);
    repository = LibrarySnapshotRepository(
      transport,
      cache,
      guard,
      now: () => now,
      waitBeforeRetry: (delay) async => delays.add(delay),
    );
    final sub = repository.changes.listen(states.add);
    addTearDown(() async {
      await sub.cancel();
      repository.dispose();
      transport.dispose();
    });
  }

  setUp(() {
    guard = SessionPublicationGuard()..select(active);
    cache = MemorySnapshotCache();
    states = [];
    delays = [];
    addTearDown(guard.retire);
  });

  test('fixture 200 commits exact payload and validators before publication; 304 reuses', () async {
    setup(
      (_, index) =>
          responseFixture(index == 0 ? 'snapshot_200' : 'snapshot_304'),
    );
    final sub = repository.changes.listen((state) {
      if (!state.stale) expect(cache.writes, 1);
    });
    addTearDown(sub.cancel);
    await repository.load();
    final saved = cache.values[active.serverKey]!;
    expect(saved.payload, fixture('snapshot_typical.json'));
    expect(saved.etag, '"library-42"');
    expect(saved.revision, 42);
    expect(saved.schemaVersion, 1);
    expect(saved.fetchedAt, now);
    expect(repository.state.stale, isFalse);
    expect(adapter.requests.first.headers['If-None-Match'], isNull);
    await repository.refresh();
    expect(adapter.requests.last.headers['If-None-Match'], saved.etag);
    expect(cache.writes, 1);
    expect(cache.reads, 3);
    expect(repository.state.snapshot!.stored, same(saved));
    expect(repository.state.stale, isFalse);
  });

  test('relaunch exposes stale data before waiting for refresh; opaque ETag is exact', () async {
    final stored = storedFixture();
    cache.values[active.serverKey] = stored;
    final entered = Completer<void>();
    final response = Completer<ResponseBody>();
    setup((_, _) {
      entered.complete();
      return response.future;
    });
    final loading = repository.load();
    await entered.future;
    expect(repository.state.snapshot!.stored, same(stored));
    expect(repository.state.stale, isTrue);
    expect(repository.state.refreshing, isTrue);
    expect(adapter.requests.single.headers['If-None-Match'], stored.etag);
    response.complete(responseFixture('snapshot_304'));
    await loading;
    expect(repository.state.stale, isFalse);
    expect(cache.writes, 0);
  });

  for (final kind in [
    'missing',
    'corrupt',
    'incompatible',
    'metadata',
    'index',
  ]) {
    test(
      '$kind cache sends no validator and gets exactly one unconditional recovery',
      () async {
        if (kind != 'missing') {
          final base = storedFixture();
          cache.values[active.serverKey] = StoredSnapshot(
            payload: switch (kind) {
              'corrupt' => '{',
              'index' => fixture('snapshot_invalid_duplicate_book_id.json'),
              _ => base.payload,
            },
            schemaVersion: kind == 'incompatible' ? 2 : 1,
            revision: kind == 'metadata' ? 17 : base.revision,
            fetchedAt: base.fetchedAt,
            etag: base.etag,
          );
        }
        setup(
          (_, index) =>
              responseFixture(index == 0 ? 'snapshot_304' : 'snapshot_200'),
        );
        await repository.load();
        expect(adapter.requests.length, 2);
        expect(
          adapter.requests.every(
            (r) => !r.headers.containsKey('If-None-Match'),
          ),
          isTrue,
        );
        expect(repository.state.error, isNull);
        expect(repository.state.stale, isFalse);
        expect(cache.writes, 1);
        expect(delays, isEmpty);
      },
    );
  }

  test(
    'repeated bodyless 304 is a typed protocol error with no third request',
    () async {
      setup((_, _) => responseFixture('snapshot_304'));
      await repository.load();
      expect(adapter.requests.length, 2);
      expect(repository.state.error, isA<LibrarySnapshotProtocolException>());
      expect(cache.writes, 0);
      expect(delays, isEmpty);
    },
  );

  test('200 without validators replaces old ETag and never enables conditional reuse', () async {
    cache.values[active.serverKey] = storedFixture();
    setup((_, _) => jsonBody(fixture('snapshot_typical.json')));
    await repository.load();
    expect(cache.values[active.serverKey]!.etag, isNull);
    await repository.refresh();
    expect(adapter.requests.last.headers.containsKey('If-None-Match'), isFalse);
    expect(repository.state.error, isNull);
  });

  for (final kind in [
    'missing',
    'corrupt',
    'incompatible',
    'changedValidator',
  ]) {
    test(
      'cache $kind during conditional request forces one unconditional fetch',
      () async {
        cache.values[active.serverKey] = storedFixture();
        final entered = Completer<void>();
        final response = Completer<ResponseBody>();
        setup((_, index) {
          if (index == 0) {
            entered.complete();
            return response.future;
          }
          return responseFixture('snapshot_200');
        });
        final refresh = repository.load();
        await entered.future;
        switch (kind) {
          case 'missing':
            cache.values.clear();
          case 'corrupt':
            cache.values[active.serverKey] = StoredSnapshot(
              payload: '{',
              schemaVersion: 1,
              revision: 42,
              fetchedAt: now,
              etag: 'W/"opaque exact"',
            );
          case 'incompatible':
            cache.values[active.serverKey] = storedFixture(schema: 2);
          case 'changedValidator':
            cache.values[active.serverKey] = storedFixture(etag: '"new"');
        }
        response.complete(responseFixture('snapshot_304'));
        await refresh;
        expect(adapter.requests.length, 2);
        expect(
          adapter.requests.first.headers['If-None-Match'],
          'W/"opaque exact"',
        );
        expect(
          adapter.requests.last.headers.containsKey('If-None-Match'),
          isFalse,
        );
        expect(repository.state.stale, isFalse);
        expect(cache.writes, 1);
      },
    );
  }

  test('no-validator cache cannot be reused even if server returns unsolicited 304', () async {
    cache.values[active.serverKey] = storedFixture(etag: null);
    setup((_, _) => responseFixture('snapshot_304'));
    await repository.load();
    expect(adapter.requests.length, 2);
    expect(repository.state.error, isA<LibrarySnapshotProtocolException>());
    expect(repository.state.snapshot, isNotNull);
    expect(repository.state.stale, isTrue);
  });

  test(
    'network failure keeps stale snapshot and uses only bounded retry delays',
    () async {
      cache.values[active.serverKey] = storedFixture();
      setup(
        (options, _) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
      );
      await repository.load();
      expect(
        repository.state.snapshot!.stored.payload,
        fixture('snapshot_typical.json'),
      );
      expect(repository.state.stale, isTrue);
      expect(repository.state.refreshing, isFalse);
      expect(repository.state.error, isA<NetworkException>());
      expect(guard.current, active);
      expect(cache.writes, 0);
      expect(adapter.requests.length, 4);
      expect(delays.map((d) => d.inMilliseconds), [200, 400, 800]);
    },
  );

  test(
    'bounded network retry can recover without losing cached display',
    () async {
      cache.values[active.serverKey] = storedFixture();
      setup(
        (options, index) => index < 2
            ? throw DioException.connectionError(
                requestOptions: options,
                reason: 'offline',
              )
            : responseFixture('snapshot_200'),
      );
      await repository.load();
      expect(adapter.requests.length, 3);
      expect(repository.state.error, isNull);
      expect(repository.state.stale, isFalse);
      expect(delays.map((d) => d.inMilliseconds), [200, 400]);
    },
  );

  for (final kind in [
    'unauthorized',
    'http',
    'tls',
    'parse',
    'schema',
    'revision',
    'store',
  ]) {
    test(
      '$kind failure preserves cache and selection without network retry',
      () async {
        final stored = storedFixture();
        cache.values[active.serverKey] = stored;
        if (kind == 'store') {
          cache.writeError = const StorageException(StorageFailure.command);
        }
        setup(
          (options, _) => switch (kind) {
            'unauthorized' => jsonBody('{}', 401),
            'http' => jsonBody('{}', 500),
            'tls' => throw DioException(
              requestOptions: options,
              type: DioExceptionType.badCertificate,
            ),
            'parse' => jsonBody('{'),
            'schema' => jsonBody(
              fixture('snapshot_invalid_schema_version.json'),
            ),
            'revision' => jsonBody(fixture('snapshot_typical.json'), 200, {
              'x-library-revision': ['99'],
            }),
            _ => responseFixture('snapshot_200'),
          },
        );
        await repository.load();
        expect(repository.state.error, switch (kind) {
          'unauthorized' => isA<UnauthorizedException>(),
          'http' => isA<ServerException>(),
          'tls' => isA<TlsException>(),
          'parse' => isA<ParseException>(),
          'schema' || 'revision' => isA<LibraryDecodeException>(),
          _ => isA<StorageException>(),
        });
        expect(repository.state.snapshot!.stored, same(stored));
        expect(cache.values[active.serverKey], same(stored));
        expect(guard.current, active);
        expect(repository.state.stale, isTrue);
        expect(adapter.requests.length, 1);
        expect(delays, isEmpty);
      },
    );
  }

  test('concurrent load and refresh coalesce to one request', () async {
    final entered = Completer<void>();
    final response = Completer<ResponseBody>();
    setup((_, _) {
      entered.complete();
      return response.future;
    });
    final first = repository.load();
    final second = repository.refresh();
    await entered.future;
    expect(adapter.requests.length, 1);
    response.complete(responseFixture('snapshot_200'));
    await Future.wait([first, second]);
    expect(cache.writes, 1);
  });
}
