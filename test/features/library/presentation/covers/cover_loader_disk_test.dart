import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/library/presentation/covers/cover_failure.dart';
import 'package:shiori/features/library/presentation/covers/cover_loader.dart';

import '../../../../core/network/fake_server_adapter.dart';
import '../../data/covers/cover_disk_test_support.dart';
import '../../data/publications/cache_test_support.dart';
import 'cover_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CacheFixture p;
  late CoverDiskFixture f;
  Future<void> create({
    int shared = 1024,
    Future<void> Function()? beforeRename,
  }) async {
    p = await CacheFixture.create(limit: shared);
    addTearDown(p.dispose);
    f = CoverDiskFixture(p, limit: 1024, beforeRename: beforeRename);
  }

  CoverLoader loader(FakeServerAdapter adapter) {
    final transport = SessionTransport(p.session, adapter: adapter);
    final value = CoverLoader(
      transport,
      p.guard,
      diskStore: () async => f.disk,
    );
    addTearDown(() {
      value.dispose();
      transport.dispose();
    });
    return value;
  }

  test(
    'cold loader decodes disk hit without network, including after retirement',
    () async {
      await create();
      final bytes = await png();
      final firstAdapter = FakeServerAdapter((_, _) => imageBody(bytes));
      final first = loader(firstAdapter);
      release(await first.load('/covers/a%20b.png?v=a%2Fb'));
      expect(firstAdapter.requests, hasLength(1));
      final file = f.file('/covers/a%20b.png?v=a%2Fb');
      expect(await file.readAsBytes(), bytes);
      p.select(serverA);
      expect(first.isActive, isFalse);
      expect(file.existsSync(), isTrue);
      final offline = FakeServerAdapter(
        (_, _) => throw StateError('disk must win'),
      );
      final second = loader(offline);
      release(await second.load('/covers/a%20b.png?v=a%2Fb'));
      expect(offline.requests, isEmpty);
      expect(second.decodedBytes, 4);
      expect(f.budget.reservedBytes, bytes.length);
    },
  );

  test(
    'non-decodable disk file is removed and replaced by one network fetch',
    () async {
      await create();
      final file = f.file('/covers/a');
      await file.parent.create(recursive: true);
      await file.writeAsString('<html>not an image</html>');
      await f.disk.reconcile();
      final bytes = await png();
      final adapter = FakeServerAdapter((_, _) => imageBody(bytes));
      final value = loader(adapter);
      release(await value.load('/covers/a'));
      expect(adapter.requests, hasLength(1));
      expect(await file.readAsBytes(), bytes);
      expect(f.budget.reservedBytes, bytes.length);
      release(await value.load('/covers/a'));
      expect(adapter.requests, hasLength(1));
    },
  );

  test(
    'shared busy returns successful image and preserves unleased publication',
    () async {
      await create(shared: 6);
      final book = await p.publish(BookKey(serverA, 7), 'abcdef');
      final adapter = FakeServerAdapter((_, _) async => imageBody(await png()));
      final value = loader(adapter);
      release(await value.load('/covers/a'));
      expect(value.decodedBytes, 4);
      expect(f.file('/covers/a').existsSync(), isFalse);
      expect(await p.file(book).readAsString(), 'abcdef');
      expect(
        (await p.store.readPublicationHead(book.key))!.sha256,
        book.sha256,
      );
      expect(f.budget.reservedBytes, 0);
    },
  );

  test(
    'retirement during write returns cancellation with no temp or charge',
    () async {
      final entered = Completer<void>();
      final gate = Completer<void>();
      await create(
        beforeRename: () async {
          entered.complete();
          await gate.future;
        },
      );
      final adapter = FakeServerAdapter((_, _) async => imageBody(await png()));
      final value = loader(adapter);
      final result = value.load('/covers/a');
      await entered.future;
      expect(f.budget.reservedBytes, greaterThan(0));
      p.guard.retire();
      expect(await result, placeholder(CoverFailure.cancelled));
      await f.serialize(() async {});
      expect(f.budget.reservedBytes, 0);
      expect(f.root.listSync(recursive: true).whereType<File>(), isEmpty);
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(value.encodedBytes, 0);
      expect(value.decodedBytes, 0);
    },
  );

  test(
    'same cover path on another server fetches a separate disk file',
    () async {
      await create();
      final bytes = await png();
      final a = loader(FakeServerAdapter((_, _) => imageBody(bytes)));
      release(await a.load('/covers/same'));
      final fileA = f.file('/covers/same');
      p.select(serverB);
      final adapter = FakeServerAdapter((_, _) => imageBody(bytes));
      final b = loader(adapter);
      release(await b.load('/covers/same'));
      expect(adapter.requests, hasLength(1));
      expect(f.file('/covers/same').path, isNot(fileA.path));
      expect(fileA.existsSync(), isTrue);
      expect(f.file('/covers/same').existsSync(), isTrue);
      expect(f.budget.reservedBytes, bytes.length * 2);
    },
  );

  test(
    'disk write failure keeps decoded success and cleans temporary bytes',
    () async {
      await create(
        beforeRename: () async {
          throw const FileSystemException('synthetic disk failure');
        },
      );
      final adapter = FakeServerAdapter((_, _) async => imageBody(await png()));
      final value = loader(adapter);
      release(await value.load('/covers/a'));
      expect(adapter.requests, hasLength(1));
      expect(value.decodedBytes, 4);
      expect(f.budget.reservedBytes, 0);
      expect(f.root.listSync(recursive: true).whereType<File>(), isEmpty);
    },
  );

  test('memory hit succeeds after removable disk file disappears', () async {
    await create();
    final adapter = FakeServerAdapter((_, _) async => imageBody(await png()));
    final value = loader(adapter);
    release(await value.load('/covers/a'));
    final scope = f.scope();
    addTearDown(scope.dispose);
    await f.disk.invalidate(scope, '/covers/a');
    release(await value.load('/covers/a'));
    expect(adapter.requests, hasLength(1));
    expect(f.file('/covers/a').existsSync(), isFalse);
  });

  test('non-image network body never enters the disk cache', () async {
    await create();
    final adapter = FakeServerAdapter(
      (_, _) => imageBody(Uint8List.fromList([1, 2, 3])),
    );
    final value = loader(adapter);
    expect(await value.load('/covers/a'), placeholder(CoverFailure.nonImage));
    expect(f.budget.reservedBytes, 0);
    expect(f.file('/covers/a').existsSync(), isFalse);
  });
}
