import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/core/storage/server_record.dart';
import 'package:shiori/core/storage/sqlite_store.dart';
import 'package:shiori/features/library/data/book_repository.dart';
import 'package:shiori/features/library/data/library_snapshot_repository.dart';
import 'package:shiori/features/library/data/models/book_detail_result.dart';
import 'package:shiori/features/library/presentation/library_snapshot_controller.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';

import '../../../core/network/fake_server_adapter.dart';
import '../../../core/storage/store_test_support.dart' show StoreFixture;
import '../data/library_test_support.dart';
import '../data/snapshot_cache_test_support.dart';

void main() {
  test('production SQLite cache/provider restores stale on reopen and replaces whole snapshot on 200', () async {
    final dirs = StoreFixture(
      await Directory.systemTemp.createTemp('shiori-c2-'),
    );
    addTearDown(dirs.dispose);
    final active = session();
    final initial = storedFixture();
    final first = await dirs.open();
    await first.commitActivation(
      ServerRecord(
        key: active.serverKey,
        createdAt: initial.fetchedAt,
        lastUsedAt: initial.fetchedAt,
      ),
      initial,
    );
    await first.close();
    final store = await dirs.open();
    final guard = SessionPublicationGuard()..select(active);
    final response = Completer<ResponseBody>();
    final entered = Completer<void>();
    final adapter = FakeServerAdapter((_, _) {
      entered.complete();
      return response.future;
    });
    final transport = SessionTransport(active, adapter: adapter);
    addTearDown(transport.dispose);
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        sqliteStoreProvider.overrideWith((ref) async => store),
        sessionPublicationGuardProvider.overrideWithValue(guard),
        sessionTransportProvider(active).overrideWithValue(transport),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(guard.retire);
    final provider = librarySnapshotControllerProvider(active);
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    await entered.future;
    expect(container.read(provider).stale, isTrue);
    expect(container.read(provider).snapshot!.stored.payload, initial.payload);
    final done = container
        .read(librarySnapshotRepositoryProvider(active))
        .refresh();
    response.complete(responseFixture('snapshot_200'));
    await done;
    expect(container.read(provider).stale, isFalse);
    final saved = (await store.readSnapshot(active.serverKey))!;
    expect(saved.payload, fixture('snapshot_typical.json'));
    expect(saved.etag, '"library-42"');
    expect(saved.revision, 42);
    expect(saved.schemaVersion, 1);
    expect(saved.fetchedAt.isUtc, isTrue);
    expect((await store.readActiveServer())!.key, active.serverKey);
    await store.close();
    final reopened = await dirs.open();
    expect(
      (await reopened.readSnapshot(active.serverKey))!.payload,
      saved.payload,
    );
    expect((await reopened.readSnapshot(active.serverKey))!.etag, saved.etag);
  });

  for (final retire in [false, true]) {
    test(
      'detail provider guards result and silently cancels (retire=$retire)',
      () async {
        final active = session();
        final guard = SessionPublicationGuard()..select(active);
        final entered = Completer<void>();
        final response = Completer<ResponseBody>();
        final adapter = FakeServerAdapter((_, _) {
          entered.complete();
          return response.future;
        });
        final transport = SessionTransport(active, adapter: adapter);
        addTearDown(transport.dispose);
        final container = ProviderContainer.test(
          retry: (_, _) => null,
          overrides: [
            sessionPublicationGuardProvider.overrideWithValue(guard),
            sessionTransportProvider(active).overrideWithValue(transport),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(guard.retire);
        final provider = bookDetailProvider(
          active,
          BookKey(active.serverKey, 7),
        );
        container.listen(provider, (_, _) {});
        final result = container.read(provider.future);
        await entered.future;
        if (retire) {
          guard.retire();
          expect(await result, isNull);
        }
        response.complete(jsonBody(fixture('book_detail.json')));
        if (!retire) expect(await result, isA<BookAvailable>());
        await Future<void>.value();
        expect(container.read(provider).hasError, isFalse);
        expect(adapter.requests.single.method, 'GET');
      },
    );
  }
}
