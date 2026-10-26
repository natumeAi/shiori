import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/selection_storage_exception.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/validated_snapshot.dart';
import 'package:shiori/core/storage/sqlite_server_selection_store.dart';
import 'package:shiori/core/storage/storage_exception.dart';

import 'store_test_support.dart';

TypeMatcher<SelectionStorageException> selectionFailure(
  SelectionStorageIssue issue,
) => isA<SelectionStorageException>().having((e) => e.issue, 'issue', issue);

ValidatedSnapshot validated() => ValidatedSnapshot(
  payloadText: 'raw validated payload',
  schemaVersion: 1,
  revision: 0,
  fetchedAt: testTime,
);

void main() {
  for (final (failure, issue) in [
    (StorageFailure.open, SelectionStorageIssue.unavailable),
    (StorageFailure.newerSchema, SelectionStorageIssue.newerSchema),
    (StorageFailure.migration, SelectionStorageIssue.unavailable),
    (StorageFailure.command, SelectionStorageIssue.unavailable),
    (StorageFailure.canonicalMismatch, SelectionStorageIssue.invalidSelection),
    (StorageFailure.invalidRecord, SelectionStorageIssue.invalidSelection),
    (StorageFailure.closed, SelectionStorageIssue.unavailable),
    (StorageFailure.workerExit, SelectionStorageIssue.unavailable),
    (StorageFailure.protocol, SelectionStorageIssue.unavailable),
  ]) {
    test('maps resolver ${failure.name} to typed ${issue.name}', () async {
      final adapter = SqliteServerSelectionStore(
        () async => throw StorageException(failure, schemaVersion: 99),
      );
      await expectLater(
        adapter.readActiveServer(),
        throwsA(selectionFailure(issue)),
      );
    });
  }

  late StoreFixture directories;
  setUp(() async {
    directories = StoreFixture(
      await Directory.systemTemp.createTemp('shiori-selection-'),
    );
    addTearDown(directories.dispose);
  });

  test(
    'absent reads, stored timestamps and touch use the real worker',
    () async {
      final worker = await directories.open();
      final adapter = SqliteServerSelectionStore(() async => worker);
      expect(await adapter.readActiveServer(), isNull);
      expect(await adapter.readServer(serverA), isNull);
      expect(await adapter.readCurrentSnapshot(serverA), isNull);
      await expectLater(
        adapter.touchLastUsed(serverA),
        throwsA(selectionFailure(SelectionStorageIssue.invalidSelection)),
      );
      await worker.commitActivation(record(serverA), snapshot(7));
      final before = (await adapter.readServer(serverA))!;
      expect(before.canonicalEndpoint, serverA.canonicalRoot);
      expect(before.createdAt, testTime);
      expect(before.lastUsedAt, testTime);
      final touchedAfter = DateTime.now().toUtc();
      await adapter.touchLastUsed(serverA);
      final touchedBefore = DateTime.now().toUtc();
      final after = (await adapter.readServer(serverA))!;
      expect(after.createdAt, testTime);
      expect(after.lastUsedAt.isUtc, isTrue);
      expect(after.lastUsedAt.isBefore(touchedAfter), isFalse);
      expect(after.lastUsedAt.isAfter(touchedBefore), isFalse);
      expect(await adapter.readActiveServer(), serverA);
      expect((await adapter.readCurrentSnapshot(serverA))!.revision, 7);
    },
  );

  test(
    'endpoint/key mismatch is rejected before resolving or writing',
    () async {
      var resolutions = 0;
      final adapter = SqliteServerSelectionStore(() async {
        resolutions++;
        return directories.open();
      });
      await expectLater(
        adapter.commitActivation(
          endpoint: ServerEndpoint.parse(serverB.canonicalRoot).endpoint!,
          key: serverA,
          snapshot: validated(),
        ),
        throwsA(selectionFailure(SelectionStorageIssue.invalidSelection)),
      );
      expect(resolutions, 0);
      expect(directories.file.existsSync(), isFalse);
    },
  );

  test(
    'all namespace calls retain the stored canonical-string check',
    () async {
      final first = await directories.open();
      await first.commitActivation(record(serverA), snapshot(7));
      await first.close();
      directories.inspect((db) {
        db.execute('UPDATE servers SET canonical_endpoint = ?', [
          'HTTPS://A.EXAMPLE.TEST:443/',
        ]);
      });
      final worker = await directories.open();
      final adapter = SqliteServerSelectionStore(() async => worker);
      for (final call in <Future<Object?> Function()>[
        adapter.readActiveServer,
        () => adapter.readServer(serverA),
        () => adapter.readCurrentSnapshot(serverA),
        () => adapter.touchLastUsed(serverA),
        () => adapter.commitActivation(
          endpoint: ServerEndpoint.parse(serverA.canonicalRoot).endpoint!,
          key: serverA,
          snapshot: validated(),
        ),
      ]) {
        await expectLater(
          call(),
          throwsA(selectionFailure(SelectionStorageIssue.invalidSelection)),
        );
      }
    },
  );

  test(
    'every port method redacts real closed-worker command failures',
    () async {
      final worker = await directories.open();
      final adapter = SqliteServerSelectionStore(() async => worker);
      await worker.close();
      for (final call in <Future<Object?> Function()>[
        adapter.readActiveServer,
        () => adapter.readServer(serverA),
        () => adapter.readCurrentSnapshot(serverA),
        () => adapter.touchLastUsed(serverA),
        () => adapter.commitActivation(
          endpoint: ServerEndpoint.parse(serverA.canonicalRoot).endpoint!,
          key: serverA,
          snapshot: validated(),
        ),
      ]) {
        await expectLater(
          call(),
          throwsA(selectionFailure(SelectionStorageIssue.unavailable)),
        );
      }
    },
  );
}
