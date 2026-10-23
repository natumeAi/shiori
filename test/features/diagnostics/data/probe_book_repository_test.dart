import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/diagnostics/data/book_digest.dart';
import 'package:shiori/features/diagnostics/data/probe_book_repository.dart';

import '../../../helpers/probe_storage_fixtures.dart';
import '../../../helpers/reader_probe_fixtures.dart';

void main() {
  test('SHA-256 matches standard short and empty vectors', () {
    expect(
      sha256Hex(Uint8List(0)),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    expect(
      sha256Hex(Uint8List.fromList([97, 98, 99])),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });
  test(
    'inventory uses fixture IDs and only digests for Documents EPUBs',
    () async {
      final root = await Directory.systemTemp.createTemp('reader-books-');
      addTearDown(() => root.delete(recursive: true));
      final dirs = TestDirectories(root);
      final docs = await dirs.documents();
      await docs.create();
      final bytes = File('assets/reader_fixtures/chapters.epub')
          .readAsBytesSync();
      final user = File('${docs.path}/private-test-title.EPUB');
      await user.writeAsBytes(bytes);
      await File('${docs.path}/shiori-reader-export.json').writeAsString('{}');
      final repo = ProbeBookRepository(dirs, assets: _DiskBundle());
      final books = await repo.list();
      final placed = books.where((b) => b.fixtureId == null).single;
      expect(placed.sha256, readerDigest);
      expect(await placed.read(), bytes);
      expect(placed.toString(), isNot(contains('private-test-title')));
      expect(
        books.where((b) => b.fixtureId == 'chapters').single.sha256,
        readerDigest,
      );
      await user.delete();
      await expectLater(placed.read(), throwsA(isA<ParseException>()));
    },
  );
  test('missing Documents is a valid fixture-only inventory', () async {
    final root = await Directory.systemTemp.createTemp('reader-no-books-');
    addTearDown(() => root.delete(recursive: true));
    final books = await ProbeBookRepository(
      TestDirectories(root),
      assets: _DiskBundle(),
    ).list();
    expect(books, isNotEmpty);
    expect(books.every((b) => b.fixtureId != null), true);
  });
  test('bad manifest and unavailable assets produce typed failures', () async {
    final root = await Directory.systemTemp.createTemp('reader-invalid-books-');
    addTearDown(() => root.delete(recursive: true));
    for (final bundle in [_BadBundle(false), _BadBundle(true)]) {
      await expectLater(
        ProbeBookRepository(TestDirectories(root), assets: bundle).list(),
        throwsA(isA<ParseException>()),
      );
    }
  });
}

final class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await File(key).readAsBytes());
}

final class _BadBundle extends CachingAssetBundle {
  _BadBundle(this.missing);
  final bool missing;
  @override
  Future<ByteData> load(String key) async {
    if (missing) throw FlutterError('Missing test asset');
    return ByteData.sublistView(Uint8List.fromList([123]));
  }
}
