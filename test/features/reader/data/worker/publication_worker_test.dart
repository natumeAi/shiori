import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/reader/data/canonical/canonical_text.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_exception.dart';

import 'worker_test_support.dart';

void main() {
  final manifest = jsonDecode(
    File('assets/reader_fixtures/manifest.json').readAsStringSync(),
  ) as Map<String, Object?>;
  for (final entry in manifest['fixtures']! as List) {
    final file = (entry as Map<String, Object?>)['file']! as String;
    test('file-backed worker matches direct first section: $file', () async {
      final path = 'assets/reader_fixtures/$file';
      final direct = EpubBook.open(File(path).readAsBytesSync());
      final worker = await PublicationWorker.spawn();
      addTearDown(worker.close);
      final snapshot = await worker.open(path, tagA);
      final actual = await worker.loadSection(0);
      final expected = direct.loadSection(0);
      expect(actual.toProjectionJson(), expected.toProjectionJson());
      expect(_sourceDetails(actual), _sourceDetails(expected));
      expect(actual.parserUsed, expected.parserUsed);
      expect(actual.originalMediaType, expected.originalMediaType);
      expect(actual.parserErrorClass, expected.parserErrorClass);
      expect(actual.documentElementIndex, expected.documentElementIndex);
      expect(actual.bodyIndex, expected.bodyIndex);
      expect(snapshot.package.opfPath, direct.package.opfPath);
      expect(snapshot.package.rendition, direct.package.rendition);
      expect(snapshot.package.direction, direct.package.direction);
      expect(
        snapshot.package.toc?.map((e) => e.toJson()).toList(),
        direct.package.toc?.map((e) => e.toJson()).toList(),
      );
      expect(
        snapshot.sections.map((e) => e.spine.cfiBase).toList(),
        direct.sections.map((e) => e.spine.cfiBase).toList(),
      );
      final canonical = CanonicalIndex.build(actual);
      final expectedCanonical = direct.canonicalIndex(expected);
      expect(canonical.length, expectedCanonical.length);
      expect(canonical.signature, expectedCanonical.signature);
      expect(() => actual.nodes.clear(), throwsUnsupportedError);
      expect(() => actual.nodes.first.children.clear(), throwsUnsupportedError);
      expect(
        () => actual.nodes.first.attributes.clear(),
        throwsUnsupportedError,
      );
      expect(() => snapshot.sections.clear(), throwsUnsupportedError);
      expect(() => snapshot.package.manifest.clear(), throwsUnsupportedError);
      expect(() => snapshot.package.spine.clear(), throwsUnsupportedError);
      expect(() => snapshot.package.rendition.clear(), throwsUnsupportedError);
      final properties = snapshot.package.manifest
          .map((item) => item.properties)
          .whereType<List<String>>();
      for (final list in properties) {
        expect(() => list.clear(), throwsUnsupportedError);
      }
    });
  }

  test(
    'resource is transferred as detached read-only decompressed bytes',
    () async {
      final direct = EpubBook.open(File(fixturePath).readAsBytesSync());
      final worker = await PublicationWorker.spawn();
      addTearDown(worker.close);
      final snapshot = await worker.open(fixturePath, tagA);
      final path = snapshot.sections.first.item.href;
      final actual = await worker.readResource(path);
      expect(actual, direct.archive.bytes(path));
      expect(() => actual![0] = 0, throwsUnsupportedError);
      expect(await worker.readResource('absent'), isNull);
      await worker.close();
      expect(actual, direct.archive.bytes(path));
    },
  );

  test('individual resource bound fails recoverably before transfer', () async {
    final worker = await PublicationWorker.spawn(maxResourceBytes: 1);
    addTearDown(worker.close);
    final snapshot = await worker.open(fixturePath, tagA);
    await expectLater(
      worker.readResource(snapshot.sections.first.item.href),
      throwsA(workerFailure(PublicationWorkerFailure.resourceTooLarge)),
    );
    expect((await worker.loadSection(0)).nodes, isNotEmpty);
  });

  for (final mode in ['corrupt', 'truncated']) {
    test(
      '$mode archive gives ParseException and worker stays usable',
      () async {
        final directory = Directory.systemTemp.createTempSync('shiori-worker-');
        addTearDown(() => directory.deleteSync(recursive: true));
        final file = File('${directory.path}/invalid.epub');
        final original = File(fixturePath).readAsBytesSync();
        file.writeAsBytesSync(
          mode == 'corrupt'
              ? [1, 2, 3]
              : original.sublist(0, original.length - 10),
        );
        final worker = await PublicationWorker.spawn();
        addTearDown(worker.close);
        await expectLater(
          worker.open(file.path, tagA),
          throwsA(isA<ParseException>()),
        );
        expect(worker.isClosed, isFalse);
        file.deleteSync();
        await worker.open(fixturePath, tagB);
        expect((await worker.loadSection(0)).nodes, isNotEmpty);
      },
    );
  }

  test(
    'close waits for handle release and allows Windows file deletion',
    () async {
      final directory = Directory.systemTemp.createTempSync('shiori-worker-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File(fixturePath).copySync('${directory.path}/book.epub');
      final worker = await PublicationWorker.spawn();
      addTearDown(worker.close);
      await worker.open(file.path, tagA);
      await worker.loadSection(0);
      await worker.close();
      expect(worker.isClosed, isTrue);
      file.deleteSync();
      expect(file.existsSync(), isFalse);
      await worker.close();
      await expectLater(
        worker.loadSection(0),
        throwsA(workerFailure(PublicationWorkerFailure.closed)),
      );
    },
  );
}

List<Object?> _sourceDetails(SourceDocument document) => [
  for (final node in document.nodes)
    [
      node.children,
      [
        for (final attribute in node.attributes)
          [
            attribute.qualifiedName,
            attribute.localName,
            attribute.namespaceUri,
            attribute.value,
          ],
      ],
    ],
];
