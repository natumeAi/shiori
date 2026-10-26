import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/storage/server_record.dart';
import 'package:shiori/core/storage/sqlite_store_test_hooks.dart';
import 'package:shiori/core/storage/storage_exception.dart';
import 'package:shiori/core/storage/stored_snapshot.dart';

import 'store_test_support.dart';

void main() {
  late StoreFixture fixture;
  setUp(() async {
    fixture = StoreFixture(
      await Directory.systemTemp.createTemp('shiori-store-'),
    );
    addTearDown(fixture.dispose);
  });

  test('upsert preserves creation time; touch and selection persist', () async {
    final store = await fixture.open();
    expect(await store.readServer(serverA), isNull);
    expect(await store.readSnapshot(serverA), isNull);
    await store.upsertServer(record(serverA));
    expect(await store.readSnapshot(serverA), isNull);
    final later = testTime.add(const Duration(hours: 1));
    await store.upsertServer(
      ServerRecord(key: serverA, createdAt: later, lastUsedAt: later),
    );
    expect((await store.readServer(serverA))!.createdAt, testTime);
    expect((await store.readServer(serverA))!.lastUsedAt, later);
    await store.touchLastUsed(serverA, testTime);
    expect((await store.readServer(serverA))!.lastUsedAt, testTime);
    await store.setActiveServer(serverA);
    expect((await store.readActiveServer())!.key, serverA);
    await store.setActiveServer(null);
    expect(await store.readActiveServer(), isNull);
    await store.close();
    final reopened = await fixture.open();
    expect(await reopened.readActiveServer(), isNull);
    expect((await reopened.readServer(serverA))!.lastUsedAt, testTime);
  });

  test(
    'activation and snapshot replacement keep server namespaces separate',
    () async {
      final store = await fixture.open();
      await store.commitActivation(record(serverA), snapshot(7));
      await store.commitActivation(record(serverB), snapshot(1, etag: null));
      expect((await store.readActiveServer())!.key, serverB);
      expect((await store.readSnapshot(serverA))!.revision, 7);
      expect((await store.readSnapshot(serverB))!.revision, 1);
      expect((await store.readSnapshot(serverB))!.etag, isNull);
      // Revision decreases can represent a server restore and remain valid.
      await store.replaceSnapshot(serverA, snapshot(2));
      expect((await store.readSnapshot(serverA))!.revision, 2);
      expect((await store.readActiveServer())!.key, serverB);
    },
  );

  test(
    'mid-activation failure preserves old active, metadata and snapshots',
    () async {
      final seed = await fixture.open();
      await seed.commitActivation(record(serverA), snapshot(7));
      await seed.upsertServer(record(serverB));
      await seed.replaceSnapshot(serverB, snapshot(3));
      await seed.close();
      final store = await fixture.open(
        hooks: const SqliteStoreTestHooks(failActivation: true),
      );
      await expectLater(
        store.commitActivation(
          record(serverB, at: testTime.add(const Duration(days: 1))),
          snapshot(4),
        ),
        throwsA(failure(StorageFailure.command)),
      );
      expect((await store.readActiveServer())!.key, serverA);
      expect((await store.readSnapshot(serverA))!.revision, 7);
      expect((await store.readSnapshot(serverB))!.revision, 3);
      expect((await store.readServer(serverB))!.lastUsedAt, testTime);
      await store.close();
      final reopened = await fixture.open();
      expect((await reopened.readActiveServer())!.key, serverA);
      expect((await reopened.readSnapshot(serverB))!.revision, 3);
    },
  );

  test('failed activation of new server rolls back its endpoint too', () async {
    final seed = await fixture.open();
    await seed.commitActivation(record(serverA), snapshot(7));
    await seed.close();
    final store = await fixture.open(
      hooks: const SqliteStoreTestHooks(failActivation: true),
    );
    await expectLater(
      store.commitActivation(record(serverB), snapshot(1)),
      throwsA(failure(StorageFailure.command)),
    );
    expect(await store.readServer(serverB), isNull);
    expect(await store.readSnapshot(serverB), isNull);
    expect((await store.readActiveServer())!.key, serverA);
  });

  test(
    'unknown server writes fail without changing active selection',
    () async {
      final store = await fixture.open();
      await store.commitActivation(record(serverA), snapshot(7));
      for (final operation in [
        () => store.setActiveServer(serverB),
        () => store.replaceSnapshot(serverB, snapshot(1)),
        () => store.touchLastUsed(serverB, testTime),
      ]) {
        await expectLater(
          operation(),
          throwsA(failure(StorageFailure.invalidRecord)),
        );
      }
      expect((await store.readActiveServer())!.key, serverA);
    },
  );

  test('invalid snapshot constraint rolls back entire activation', () async {
    final store = await fixture.open();
    await store.commitActivation(record(serverA), snapshot(7));
    await expectLater(
      store.commitActivation(
        record(serverB),
        StoredSnapshot(
          payload: '{}',
          schemaVersion: 0,
          revision: -1,
          fetchedAt: testTime,
        ),
      ),
      throwsA(failure(StorageFailure.command)),
    );
    expect(await store.readServer(serverB), isNull);
    expect((await store.readActiveServer())!.key, serverA);
  });

  test(
    'bound JSON and opaque ETag round trip without SQL interpretation',
    () async {
      final store = await fixture.open();
      const payload = '{"text":"\u0027); DROP TABLE servers; --"}';
      const etag = '\u0027; DELETE FROM app_state; --';
      await store.commitActivation(
        record(serverA),
        StoredSnapshot(
          payload: payload,
          schemaVersion: 1,
          revision: 0,
          fetchedAt: testTime,
          etag: etag,
        ),
      );
      final saved = (await store.readSnapshot(serverA))!;
      expect(saved.payload, payload);
      expect(saved.etag, etag);
      expect(saved.fetchedAt.isUtc, isTrue);
      expect(saved.fetchedAt, testTime);
      expect((await store.readActiveServer())!.key, serverA);
    },
  );

  test(
    'canonical mismatch rejects every namespace command and active restore',
    () async {
      final seed = await fixture.open();
      await seed.commitActivation(record(serverA), snapshot(7));
      await seed.close();
      fixture.inspect(
        (db) => db.execute(
          'UPDATE servers SET canonical_endpoint = ? WHERE server_key = ?',
          [serverB.canonicalRoot, serverA.value],
        ),
      );
      final store = await fixture.open();
      for (final operation in <Future<Object?> Function()>[
        () => store.readServer(serverA),
        () => store.readActiveServer(),
        () => store.upsertServer(record(serverA)),
        () => store.setActiveServer(serverA),
        () => store.commitActivation(record(serverA), snapshot(8)),
        () => store.readSnapshot(serverA),
        () => store.replaceSnapshot(serverA, snapshot(8)),
        () => store.touchLastUsed(serverA, testTime),
      ]) {
        await expectLater(
          operation(),
          throwsA(failure(StorageFailure.canonicalMismatch)),
        );
      }
      await store.close();
      fixture.inspect((db) {
        expect(
          db
              .select('SELECT canonical_endpoint FROM servers')
              .single
              .values
              .single,
          serverB.canonicalRoot,
        );
        expect(
          db
              .select('SELECT revision FROM library_snapshots')
              .single
              .values
              .single,
          7,
        );
      });
    },
  );

  test('concurrent commands execute in request order on one worker', () async {
    final store = await fixture.open();
    await store.upsertServer(record(serverA));
    final results = <Future<void>>[];
    for (var revision = 0; revision < 100; revision++) {
      results.add(store.replaceSnapshot(serverA, snapshot(revision)));
      results.add(
        store.readSnapshot(serverA).then((saved) {
          expect(saved!.revision, revision);
        }),
      );
    }
    await Future.wait(results);
    expect((await store.readSnapshot(serverA))!.revision, 99);
    expect(await store.runsOffRootForTesting(), isTrue);
  });
}
