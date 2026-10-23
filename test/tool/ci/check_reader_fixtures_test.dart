import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/diagnostics/data/book_digest.dart';

import '../../../tool/ci/check_reader_fixtures.dart';

const assets = 'assets/reader_fixtures';
const edges = 'test/fixtures/reader/source_edge';

void put(Directory root, String path, String text) {
  final file = File('${root.path}/$path');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(text);
}

void manifest(Directory root, String directory, List<String> names) {
  put(
    root,
    '$directory/manifest.json',
    jsonEncode({
      'fixtureSchemaVersion': 1,
      'fixtures': [
        for (final name in names)
          {
            'file': name,
            'bytes': File('${root.path}/$directory/$name').lengthSync(),
            'sha256': sha256Hex(
              File('${root.path}/$directory/$name').readAsBytesSync(),
            ),
          },
      ],
    }),
  );
}

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('reader-guard-');
    final git = await Process.run('git', ['init', root.path]);
    expect(git.exitCode, 0);
    put(root, '$assets/test.epub', 'synthetic');
    put(root, '$assets/.gitattributes', '*.epub binary');
    manifest(root, assets, ['test.epub']);
    for (final name in ['edge-html.epub', 'edge-xhtml.epub']) {
      put(root, '$edges/$name', 'edge synthetic');
    }
    manifest(root, edges, ['edge-html.epub', 'edge-xhtml.epub']);
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'clean temporary repository with both hashed edge fixtures passes',
    () async {
      expect(await checkReaderFixtures(root), isEmpty);
    },
  );
  test('clean real repository passes', () async {
    expect(await checkReaderFixtures(Directory.current), isEmpty);
  });
  test(
    'nonignored untracked EPUB outside assets fails without printing names',
    () async {
      put(root, 'private-title.EPUB', 'private content');
      final errors = await checkReaderFixtures(root);
      expect(errors.join(), contains('Unapproved EPUB'));
      expect(errors.join(), isNot(contains('private-title')));
      expect(errors.join(), isNot(contains('private content')));
    },
  );
  test('ignored untracked EPUB passes, tracked ignored EPUB fails', () async {
    put(root, '.gitignore', 'ignored/');
    put(root, 'ignored/private.epub', 'private');
    expect(await checkReaderFixtures(root), isEmpty);
    final git = await Process.run('git', [
      '-C',
      root.path,
      'add',
      '-f',
      'ignored/private.epub',
    ]);
    expect(git.exitCode, 0);
    expect(
      (await checkReaderFixtures(root)).join(),
      contains('Unapproved EPUB'),
    );
  });
  test('missing fixture and missing manifest fail', () async {
    File('${root.path}/$assets/test.epub').deleteSync();
    expect(
      (await checkReaderFixtures(root)).join(),
      contains('missing or differs'),
    );
    File('${root.path}/$assets/manifest.json').deleteSync();
    expect(
      (await checkReaderFixtures(root)).join(),
      contains('invalid hashed manifest'),
    );
  });
  for (final extension in ['epub', 'txt']) {
    test('extra asset .$extension absent from manifest fails', () async {
      put(root, '$assets/extra.$extension', 'extra');
      expect(
        (await checkReaderFixtures(root)).join(),
        contains('Extra fixture'),
      );
    });
  }
  for (final content in ['different size', 'synthetiX']) {
    test('asset bytes or equal-length hash drift fails: $content', () async {
      put(root, '$assets/test.epub', content);
      expect(
        (await checkReaderFixtures(root)).join(),
        contains('missing or differs'),
      );
    });
  }
  test('edge hash drift fails even with equal byte count', () async {
    put(root, '$edges/edge-html.epub', 'edge synthetiX');
    final errors = (await checkReaderFixtures(root)).join();
    expect(errors, contains('Edge fixture missing or differs'));
    expect(errors, contains('Unapproved EPUB'));
  });
  test('missing edge fixture or manifest fails', () async {
    File('${root.path}/$edges/edge-xhtml.epub').deleteSync();
    expect((await checkReaderFixtures(root)).join(), contains('Edge fixture'));
    File('${root.path}/$edges/manifest.json').deleteSync();
    expect(
      (await checkReaderFixtures(root)).join(),
      contains('invalid hashed manifest'),
    );
  });
  test(
    'edge folder and extra hashed manifest entries grant no blanket exemption',
    () async {
      put(root, '$edges/other.epub', 'synthetic');
      manifest(root, edges, [
        'edge-html.epub',
        'edge-xhtml.epub',
        'other.epub',
      ]);
      final errors = (await checkReaderFixtures(root)).join();
      expect(errors, contains('exactly the two'));
      expect(errors, contains('Unapproved EPUB'));
    },
  );
  for (final kind in ['malformed', 'duplicate', 'traversal', 'version']) {
    test('$kind manifest fails closed', () async {
      final file = File('${root.path}/$assets/manifest.json');
      final raw = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final list = raw['fixtures'] as List<Object?>;
      if (kind == 'duplicate') list.add(list.first);
      if (kind == 'traversal') (list.first as Map)['file'] = '../escape.epub';
      if (kind == 'version') raw['fixtureSchemaVersion'] = 2;
      file.writeAsStringSync(kind == 'malformed' ? '{' : jsonEncode(raw));
      expect(
        (await checkReaderFixtures(root)).join(),
        contains('invalid hashed manifest'),
      );
    });
  }
  test('nonrepository directory fails inventory check', () async {
    final outside = await Directory.systemTemp.createTemp('reader-nongit-');
    addTearDown(() => outside.delete(recursive: true));
    expect(
      (await checkReaderFixtures(outside)).join(),
      contains('Cannot enumerate'),
    );
  });
}
