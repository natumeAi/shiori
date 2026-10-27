import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/features/library/data/covers/cover_disk_store.dart';

import '../publications/cache_test_support.dart';
import 'cover_disk_test_support.dart';

void main() {
  late CacheFixture p;
  late CoverDiskFixture f;
  Future<void> create({
    int shared = 1024,
    int covers = 16,
    Future<void> Function()? beforeRename,
  }) async {
    p = await CacheFixture.create(limit: shared);
    addTearDown(p.dispose);
    f = CoverDiskFixture(p, limit: covers, beforeRename: beforeRename);
  }

  Uint8List bytes(int length) => Uint8List(length)..fillRange(0, length, 7);

  test('sub-budget evicts least recently read cover across servers', () async {
    await create(covers: 8);
    final scopeA = f.scope();
    addTearDown(scopeA.dispose);
    expect(await f.disk.write(scopeA, '/covers/a', bytes(4)), isTrue);
    p.time = p.time.add(const Duration(seconds: 1));
    expect(await f.disk.write(scopeA, '/covers/b', bytes(4)), isTrue);
    final a = f.file('/covers/a');
    final b = f.file('/covers/b');
    p.time = p.time.add(const Duration(seconds: 1));
    expect(await f.disk.read(scopeA, '/covers/a'), bytes(4));
    p.select(serverB);
    final scopeB = f.scope();
    addTearDown(scopeB.dispose);
    expect(await f.disk.write(scopeB, '/covers/a', bytes(4)), isTrue);
    expect(a.existsSync(), isTrue);
    expect(b.existsSync(), isFalse);
    expect(f.file('/covers/a').path, isNot(a.path));
    expect(f.disk.encodedBytes, 8);
    expect(f.budget.reservedBytes, 8);
  });

  test(
    'shared busy skips persistence and never evicts an unleased publication',
    () async {
      await create(shared: 6);
      final book = await p.publish(BookKey(serverA, 7), 'abcdef');
      final scope = f.scope();
      addTearDown(scope.dispose);
      expect(await f.disk.write(scope, '/covers/a', bytes(1)), isFalse);
      expect(await p.file(book).readAsString(), 'abcdef');
      expect(
        (await p.store.readPublicationHead(book.key))!.sha256,
        book.sha256,
      );
      expect(f.budget.reservedBytes, 0);
    },
  );

  test(
    'retirement before rename cleans own temp and releases reservation',
    () async {
      final entered = Completer<void>();
      final gate = Completer<void>();
      await create(
        beforeRename: () async {
          entered.complete();
          await gate.future;
        },
      );
      final scope = f.scope();
      addTearDown(scope.dispose);
      final write = f.disk.write(scope, '/covers/a', bytes(8));
      final cancelled = expectLater(write, throwsA(isA<RequestCancelled>()));
      await entered.future;
      expect(f.budget.reservedBytes, 8);
      expect(
        f.root.listSync(recursive: true).whereType<File>().single.path,
        endsWith('.part'),
      );
      p.guard.retire();
      await cancelled;
      expect(f.budget.reservedBytes, 0);
      expect(f.root.listSync(recursive: true).whereType<File>(), isEmpty);
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(f.root.listSync(recursive: true).whereType<File>(), isEmpty);
    },
  );

  test('startup removes temps, enforces LRU, restores charges and preserves siblings', () async {
    await create(covers: 8);
    final scope = f.scope();
    addTearDown(scope.dispose);
    final a = f.file('/covers/a');
    final b = f.file('/covers/b');
    final c = f.file('/covers/c');
    await a.parent.create(recursive: true);
    for (final file in [a, b, c]) {
      await file.writeAsBytes(bytes(4));
    }
    await a.setLastModified(DateTime.utc(2020));
    await b.setLastModified(DateTime.utc(2021));
    await c.setLastModified(DateTime.utc(2022));
    final temp = await File('${a.parent.path}/stray.part')
        .writeAsString('temp');
    final invalid = await f.file('/covers/empty').writeAsBytes([]);
    final sentinel = await File('${p.root.path}/caches/keep.part')
        .writeAsString('keep');
    await f.disk.reconcile();
    expect(a.existsSync(), isFalse);
    expect(b.existsSync(), isTrue);
    expect(c.existsSync(), isTrue);
    expect(temp.existsSync(), isFalse);
    expect(invalid.existsSync(), isFalse);
    expect(sentinel.readAsStringSync(), 'keep');
    expect(f.budget.reservedBytes, 8);
    await f.disk.reconcile();
    expect(f.budget.reservedBytes, 8);
    await c.delete();
    await f.disk.reconcile();
    expect(f.budget.reservedBytes, 4);
  });

  test('read rejects oversize files and never uses supplied path components as names', () async {
    await create(covers: 8);
    final scope = f.scope();
    addTearDown(scope.dispose);
    const path = '/covers/a%20b.png?v=a%2Fb';
    final file = f.file(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes(9));
    expect(await f.disk.read(scope, path), isNull);
    expect(file.existsSync(), isFalse);
    expect(
      file.uri.pathSegments.last,
      matches(RegExp(r'^[a-f0-9]{64}\.cache$')),
    );
    expect(
      () => f.disk.read(scope, '/covers/../private'),
      throwsFormatException,
    );
    expect(CoverDiskStore.defaultLimit, 16 * 1024 * 1024);
    expect(CoverDiskStore.individualLimit, 8 * 1024 * 1024);
  });
}
