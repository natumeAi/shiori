import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/core/storage/app_directories.dart';
import 'package:shiori/core/storage/sqlite_store.dart';
import 'package:shiori/features/library/data/covers/cover_disk_store.dart';
import 'package:shiori/features/library/data/publications/publication_cache.dart';
import 'package:shiori/features/library/data/publications/publication_cache_exception.dart';
import 'package:shiori/features/library/presentation/covers/cover_loader.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';

import '../../../../core/network/fake_server_adapter.dart';
import '../../presentation/covers/cover_test_support.dart';
import '../publications/cache_test_support.dart';
import 'cover_disk_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CacheFixture p;
  Future<void> create({int limit = 1024}) async {
    p = await CacheFixture.create(limit: limit);
    addTearDown(p.dispose);
  }

  test(
    'production loader provider persists then reuses disk after invalidation',
    () async {
      await create();
      p.cache.dispose();
      final bytes = await png();
      final adapter = FakeServerAdapter((_, _) => imageBody(bytes));
      final transport = SessionTransport(p.session, adapter: adapter);
      final container = ProviderContainer.test(
        overrides: [
          appDirectoriesProvider.overrideWithValue(p),
          sqliteStoreProvider.overrideWith((ref) async => p.store),
          sessionPublicationGuardProvider.overrideWithValue(p.guard),
          sessionTransportProvider(p.session).overrideWithValue(transport),
        ],
        retry: (_, _) => null,
      );
      addTearDown(transport.dispose);
      final provider = coverLoaderProvider(p.session);
      release(await container.read(provider).load('/covers/a'));
      final cache = await container.read(publicationCacheProvider.future);
      expect(cache.budget.reservedBytes, bytes.length);
      final subBudget = cache.budget.subBudget('covers');
      container.invalidate(provider);
      container.invalidate(publicationCacheProvider);
      final replacement = await container.read(publicationCacheProvider.future);
      expect(replacement.budget, same(cache.budget));
      expect(replacement.budget.subBudget('covers'), same(subBudget));
      expect(replacement.budget.reservedBytes, bytes.length);
      release(await container.read(provider).load('/covers/a'));
      expect(adapter.requests, hasLength(1));
      await replacement.reconcile();
      expect(replacement.budget.reservedBytes, bytes.length);
    },
  );

  test(
    'startup registers disk covers before any publication admission',
    () async {
      await create(limit: 6);
      final f = CoverDiskFixture(p);
      final file = f.file('/covers/a');
      await file.parent.create(recursive: true);
      await file.writeAsBytes([1, 2, 3, 4]);
      final sentinel = await File('${p.root.path}/caches/keep.part')
          .writeAsString('keep');
      final temp = await File('${file.parent.path}/stray.part')
          .writeAsString('temp');
      p.cache.dispose();
      await p.openCache();
      expect(p.cache.budget.reservedBytes, 4);
      expect(temp.existsSync(), isFalse);
      expect(sentinel.readAsStringSync(), 'keep');
      await expectLater(
        p.publish(BookKey(serverA, 7), 'new'),
        throwsA(cacheFailure(PublicationCacheFailure.cacheBusy)),
      );
      expect(file.existsSync(), isTrue);
      final scope = f.scope();
      addTearDown(scope.dispose);
      await CoverDiskStore.fromBudget(p.cache.budget)
          .invalidate(scope, '/covers/a');
      expect(p.cache.budget.reservedBytes, 0);
      await p.publish(BookKey(serverA, 7), 'new');
    },
  );

  test('startup shared pressure discards covers while keeping unleased publication', () async {
    await create(limit: 6);
    final book = await p.publish(BookKey(serverA, 7), 'abcdef');
    final file = CoverDiskFixture(p).file('/covers/a');
    await file.parent.create(recursive: true);
    await file.writeAsBytes([1]);
    p.cache.dispose();
    await p.openCache();
    expect(file.existsSync(), isFalse);
    expect(p.cache.budget.reservedBytes, 0);
    expect(p.file(book).readAsStringSync(), 'abcdef');
    expect((await p.store.readPublicationHead(book.key))!.sha256, book.sha256);
  });

  test(
    'production cover admission reclaims covers and never a publication',
    () async {
      await create(limit: 8);
      final book = await p.publish(BookKey(serverA, 7), 'book');
      final disk = CoverDiskStore.fromBudget(p.cache.budget);
      final f = CoverDiskFixture(p);
      final scope = f.scope();
      addTearDown(scope.dispose);
      expect(await disk.write(scope, '/covers/a', Uint8List(4)), isTrue);
      expect(await disk.write(scope, '/covers/b', Uint8List(4)), isTrue);
      expect(f.file('/covers/a').existsSync(), isFalse);
      expect(f.file('/covers/b').existsSync(), isTrue);
      expect(p.cache.budget.reservedBytes, 4);
      expect(p.file(book).readAsStringSync(), 'book');
      expect(
        (await p.store.readPublicationHead(book.key))!.sha256,
        book.sha256,
      );
    },
  );
}
