import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/storage/app_directories.dart';
import 'package:shiori/core/storage/sqlite_store.dart';
import 'package:shiori/core/storage/storage_exception.dart';

import 'store_test_support.dart';

void main() {
  late StoreFixture fixture;
  setUp(() async {
    fixture = StoreFixture(
      await Directory.systemTemp.createTemp('shiori-store-'),
    );
    addTearDown(fixture.dispose);
  });

  test(
    'close drains accepted commands, rejects new calls and awaits exit',
    () async {
      final store = await fixture.open();
      final commands = <Future<void>>[];
      for (var i = 0; i < 40; i++) {
        commands.add(store.commitActivation(record(serverA), snapshot(i)));
      }
      final closing = store.close();
      expect(store.isClosed, isTrue);
      expect(identical(store.close(), closing), isTrue);
      await expectLater(
        store.readActiveServer(),
        throwsA(failure(StorageFailure.closed)),
      );
      await Future.wait([...commands, closing]);
      final reopened = await fixture.open();
      expect((await reopened.readSnapshot(serverA))!.revision, 39);
    },
  );

  test(
    'unexpected isolate exit completes running and queued waiters',
    () async {
      final store = await fixture.open();
      final exiting = expectLater(
        store.exitForTesting(),
        throwsA(failure(StorageFailure.workerExit)),
      );
      final queued = List.generate(
        30,
        (_) => expectLater(
          store.readActiveServer(),
          throwsA(failure(StorageFailure.workerExit)),
        ),
      );
      await Future.wait([exiting, ...queued]);
      await store.close();
      expect(store.isClosed, isTrue);
      await expectLater(
        store.readActiveServer(),
        throwsA(failure(StorageFailure.closed)),
      );
      final reopened = await fixture.open();
      expect(await reopened.runsOffRootForTesting(), isTrue);
    },
  );

  test(
    'provider keeps same owner after listeners leave and disposes scope',
    () async {
      final container = ProviderContainer(
        overrides: [appDirectoriesProvider.overrideWithValue(fixture)],
        retry: (_, _) => null,
      );
      addTearDown(container.dispose);
      final subscription = container.listen(sqliteStoreProvider, (_, _) {});
      final store = await container.read(sqliteStoreProvider.future);
      subscription.close();
      await container.pump();
      expect(await container.read(sqliteStoreProvider.future), same(store));
      await store.commitActivation(record(serverA), snapshot(1));
      container.dispose();
      expect(store.isClosed, isTrue);
      await store.close();
      final reopened = await fixture.open();
      expect((await reopened.readActiveServer())!.key, serverA);
    },
  );

  test(
    'provider invalidation waits for retired worker to drain and exit',
    () async {
      final container = ProviderContainer(
        overrides: [appDirectoriesProvider.overrideWithValue(fixture)],
        retry: (_, _) => null,
      );
      addTearDown(container.dispose);
      final old = await container.read(sqliteStoreProvider.future);
      final writes = List.generate(
        100,
        (i) => old.commitActivation(record(serverA), snapshot(i)),
      );
      container.invalidate(sqliteStoreProvider);
      final next = await container.read(sqliteStoreProvider.future);
      expect(old.isClosed, isTrue);
      expect(next, isNot(same(old)));
      expect((await next.readSnapshot(serverA))!.revision, 99);
      await Future.wait(writes);
      container.dispose();
      await next.close();
    },
  );

  test(
    'scope disposal during directory lookup never starts an owner',
    () async {
      final lookup = Completer<Directory>();
      final requested = Completer<void>();
      final directories = _DelayedDirectories(lookup.future, requested);
      final container = ProviderContainer(
        overrides: [appDirectoriesProvider.overrideWithValue(directories)],
        retry: (_, _) => null,
      );
      final pending = container.read(sqliteStoreProvider.future);
      // Disposed provider futures need not publish their result. Observe errors
      // without awaiting that deliberately retired Riverpod future.
      unawaited(
        pending.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
      await requested.future;
      container.dispose();
      lookup.complete(fixture.support);
      // A barrier on the same lookup completion flushes the provider continuation.
      await lookup.future;
      await Future<void>.value();
      expect(fixture.file.existsSync(), isFalse);
    },
  );
}

final class _DelayedDirectories implements AppDirectories {
  _DelayedDirectories(this.lookup, this.requested);
  final Future<Directory> lookup;
  final Completer<void> requested;
  @override
  Future<Directory> applicationSupport() {
    requested.complete();
    return lookup;
  }

  @override
  Future<Directory> documents() => throw StateError('Documents');
  @override
  Future<Directory> caches() => throw StateError('Caches');
}
