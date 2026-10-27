import 'dart:io';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/selection_storage_exception.dart';
import 'package:shiori/core/config/server_key.dart';
import 'package:shiori/core/config/validated_snapshot.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/core/storage/app_directories.dart';
import 'package:shiori/core/storage/sqlite_server_selection_store.dart';
import 'package:shiori/core/storage/sqlite_store.dart';
import 'package:shiori/core/storage/sqlite_store_test_hooks.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';
import 'package:shiori/features/servers/data/server_activation_failure.dart';
import 'package:shiori/features/servers/presentation/server_activation_controller.dart';

import '../../../core/storage/store_test_support.dart' as storage;
import '../server_activation_test_support.dart' as fake;
import '../sqlite_activation_test_support.dart';

void main() {
  late storage.StoreFixture directories;
  setUp(() async {
    directories = storage.StoreFixture(
      await Directory.systemTemp.createTemp('shiori-activation-'),
    );
    addTearDown(directories.dispose);
  });

  SqliteActivationHarness harness({
    SqliteStore? worker,
    bool configureValidator = true,
  }) {
    final h = SqliteActivationHarness(
      directories,
      worker: worker,
      configureValidator: configureValidator,
    );
    addTearDown(h.close);
    return h;
  }

  test(
    'production activation persists exact endpoint, snapshot and selection',
    () async {
      final h = harness();
      expect((await h.restore()).session, isNull);
      final adapter = h.store;
      expect(adapter, isA<SqliteServerSelectionStore>());
      final value = ValidatedSnapshot(
        payloadText: ' { "snapshot": {"text":"雪", "version":4} }\n',
        schemaVersion: 3,
        revision: 4,
        etag: ' W/"opaque: AbC/雪" ',
        fetchedAt: DateTime.utc(2026, 10, 26, 12, 3, 4, 5, 678),
      );
      h.snapshots[fake.endpoint('a').canonicalRoot] = value;
      await h.activate('a');
      final session = h.state.session!;
      expect(h.state.failure, isNull);
      expect(await h.store.readActiveServer(), session.serverKey);
      final row = (await h.store.readServer(session.serverKey))!;
      expect(row.canonicalEndpoint, fake.endpoint('a').canonicalRoot);
      expect(row.createdAt.isUtc, isTrue);
      expect(row.lastUsedAt, row.createdAt);
      final saved = (await h.store.readCurrentSnapshot(session.serverKey))!;
      expect(saved.payloadText, value.payloadText);
      expect(saved.schemaVersion, value.schemaVersion);
      expect(saved.etag, value.etag);
      expect(saved.revision, value.revision);
      expect(saved.fetchedAt, value.fetchedAt);
      expect(h.candidates.single.requests.map((r) => r.uri.path), [
        '/Reader/api/health',
        '/Reader/api/library/snapshot',
      ]);
      final worker = await h.container.read(sqliteStoreProvider.future);
      h.subscription.close();
      await h.container.pump();
      expect(h.container.read(serverSelectionStoreProvider), same(adapter));
      expect(worker.isClosed, isFalse);
      await h.close();
      expect(worker.isClosed, isTrue);
    },
  );

  test('new container restores durable selection in a fresh generation without HTTP', () async {
    final first = harness();
    await first.restore();
    await first.activate('a');
    final selected = first.state.session!;
    final retiredGuard = first.guard;
    final saved = (await first.store.readCurrentSnapshot(selected.serverKey))!;
    await first.close();
    expect(retiredGuard.isCurrent(selected), isFalse);

    final next = harness();
    final restored = (await next.restore()).session!;
    expect(restored.serverKey, selected.serverKey);
    expect(restored.endpoint, selected.endpoint);
    expect(restored.generation, isPositive);
    expect(restored, isNot(selected));
    expect(next.guard.isCurrent(restored), isTrue);
    expect(next.candidates, isEmpty);
    expect(next.validator.calls, isEmpty);
    expect(next.activeAdapters.single.requests, isEmpty);
    expect(
      (await next.store.readCurrentSnapshot(restored.serverKey))!.payloadText,
      saved.payloadText,
    );
  });

  test('injected transaction failure preserves active server, both snapshots and work', () async {
    final initial = harness();
    await initial.restore();
    await initial.activate('b');
    await initial.activate('a');
    final a = initial.state.session!.serverKey;
    final b = ServerKey(fake.endpoint('b'));
    final oldA = (await initial.store.readCurrentSnapshot(a))!;
    final oldB = (await initial.store.readCurrentSnapshot(b))!;
    final oldBRow = (await initial.store.readServer(b))!;
    await initial.close();

    final worker = await directories.open(
      hooks: const SqliteStoreTestHooks(failActivation: true),
    );
    final h = harness(worker: worker);
    final previous = (await h.restore()).session!;
    var retired = false;
    h.guard.onRetire(previous, () => retired = true);
    h.snapshots[fake.endpoint('b').canonicalRoot] = fake.snapshot(
      'replacement',
    );
    await h.activate('b');
    expect(h.state.session, same(previous));
    expect(h.state.failure!.kind, ActivationFailureKind.storage);
    expect(h.state.failure!.storageIssue, SelectionStorageIssue.unavailable);
    expect(await h.store.readActiveServer(), a);
    expect(
      (await h.store.readCurrentSnapshot(a))!.payloadText,
      oldA.payloadText,
    );
    expect(
      (await h.store.readCurrentSnapshot(b))!.payloadText,
      oldB.payloadText,
    );
    expect((await h.store.readServer(b))!.lastUsedAt, oldBRow.lastUsedAt);
    expect(retired, isFalse);
    expect(h.guard.isCurrent(previous), isTrue);
    expect(h.activeAdapters.single.closed, isFalse);
  });

  test(
    'A to B to A retains both rows and snapshots and original creation time',
    () async {
      final h = harness();
      await h.restore();
      await h.activate('a');
      final firstA = h.state.session!;
      final createdAt = (await h.store.readServer(firstA.serverKey))!.createdAt;
      await h.activate('b');
      final b = h.state.session!;
      final bSnapshot = (await h.store.readCurrentSnapshot(b.serverKey))!;
      h.snapshots[fake.endpoint('a').canonicalRoot] = ValidatedSnapshot(
        payloadText: 'replacement A with a lower revision',
        schemaVersion: 1,
        revision: 0,
        fetchedAt: DateTime.utc(2026, 10, 26, 13),
      );
      await h.activate('a');
      final laterA = h.state.session!;
      expect(laterA.serverKey, firstA.serverKey);
      expect(laterA.generation, greaterThan(b.generation));
      expect(h.guard.isCurrent(firstA), isFalse);
      expect(h.guard.isCurrent(b), isFalse);
      expect(h.guard.isCurrent(laterA), isTrue);
      expect(await h.store.readActiveServer(), laterA.serverKey);
      expect(
        (await h.store.readServer(laterA.serverKey))!.createdAt,
        createdAt,
      );
      expect(await h.store.readServer(b.serverKey), isNotNull);
      final savedA = (await h.store.readCurrentSnapshot(laterA.serverKey))!;
      expect(savedA.revision, 0);
      expect(savedA.etag, isNull);
      expect(
        (await h.store.readCurrentSnapshot(b.serverKey))!.payloadText,
        bSnapshot.payloadText,
      );
      await h.close();
      directories.inspect((db) {
        expect(db.select('SELECT * FROM servers'), hasLength(2));
        expect(db.select('SELECT * FROM library_snapshots'), hasLength(2));
      });
    },
  );

  test(
    'newer schema is typed recoverable restore state and byte-identical',
    () async {
      directories.inspect((db) {
        db.execute('PRAGMA user_version = 99');
        db.execute('CREATE TABLE future_state(value TEXT)');
        db.execute("INSERT INTO future_state VALUES ('preserve')");
      });
      final before = await directories.file.readAsBytes();
      final h = harness();
      await expectLater(
        h.restore(),
        throwsA(
          isA<SelectionStorageException>().having(
            (e) => e.issue,
            'issue',
            SelectionStorageIssue.newerSchema,
          ),
        ),
      );
      final state = h.container.read(serverActivationControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<SelectionStorageException>());
      expect(h.candidates, isEmpty);
      expect(h.activeAdapters, isEmpty);
      await h.close();
      expect(await directories.file.readAsBytes(), before);
      expect(directories.file.parent.listSync(), hasLength(1));
    },
  );

  test(
    'corrupt database open is typed unavailable and preserves the file',
    () async {
      await directories.file.parent.create(recursive: true);
      await directories.file.writeAsString('synthetic invalid SQLite database');
      final before = await directories.file.readAsBytes();
      final h = harness();
      await expectLater(
        h.restore(),
        throwsA(
          isA<SelectionStorageException>().having(
            (e) => e.issue,
            'issue',
            SelectionStorageIssue.unavailable,
          ),
        ),
      );
      expect(h.candidates, isEmpty);
      await h.close();
      expect(await directories.file.readAsBytes(), before);
    },
  );

  for (final name in [
    'typical',
    'invalid_schema_version',
    'invalid_duplicate_book_id',
  ]) {
    test('production validator and SQLite activation: $name', () async {
      final adapters = <fake.FakeServerAdapter>[];
      final raw = fake.fixture('snapshot_$name.json');
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appDirectoriesProvider.overrideWithValue(directories),
          candidateTransportFactoryProvider.overrideWithValue((session) {
            final adapter = fake.FakeServerAdapter(
              (options, _) => options.uri.path.endsWith('/api/health')
                  ? fake.jsonBody(fake.fixture('health_ok.json'))
                  : fake.jsonBody(raw, 200, {
                      'etag': ['W/"exact opaque"'],
                      'x-library-revision': ['42'],
                    }),
            );
            adapters.add(adapter);
            return SessionTransport(session, adapter: adapter);
          }),
          sessionTransportProvider.overrideWith((ref, session) {
            final transport = SessionTransport(
              session,
              adapter: fake.FakeServerAdapter((_, _) => fake.jsonBody()),
            );
            ref.onDispose(transport.dispose);
            return transport;
          }),
        ],
      );
      addTearDown(container.dispose);
      container.listen(serverActivationControllerProvider, (_, _) {});
      await container.read(serverActivationControllerProvider.future);
      final worker = await container.read(sqliteStoreProvider.future);
      addTearDown(worker.close);
      await container
          .read(serverActivationControllerProvider.notifier)
          .activate(fake.endpoint('a').canonicalRoot);
      final state = container
          .read(serverActivationControllerProvider)
          .requireValue;
      final store = container.read(serverSelectionStoreProvider);
      if (name == 'typical') {
        expect(state.failure, isNull);
        final selected = state.session!;
        expect(await store.readActiveServer(), selected.serverKey);
        final saved = (await store.readCurrentSnapshot(selected.serverKey))!;
        expect(saved.payloadText, raw);
        expect(
          utf8.encode(saved.payloadText),
          File('test/fixtures/server/snapshot_$name.json').readAsBytesSync(),
        );
        expect(saved.schemaVersion, 1);
        expect(saved.revision, 42);
        expect(saved.etag, 'W/"exact opaque"');
        expect(saved.fetchedAt.isUtc, isTrue);
      } else {
        expect(state.session, isNull);
        expect(
          state.failure!.kind,
          name == 'invalid_schema_version'
              ? ActivationFailureKind.incompatibleSnapshot
              : ActivationFailureKind.malformedSnapshot,
        );
        expect(await store.readActiveServer(), isNull);
        expect(await store.readServer(ServerKey(fake.endpoint('a'))), isNull);
      }
      expect(adapters.single.requests.map((r) => r.uri.path), [
        '/Reader/api/health',
        '/Reader/api/library/snapshot',
      ]);
      expect(
        adapters.single.requests.last.headers.containsKey('If-None-Match'),
        isFalse,
      );
      expect(adapters.single.closed, isTrue);
    });
  }
}
