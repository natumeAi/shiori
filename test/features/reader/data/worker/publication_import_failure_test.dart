import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/worker/publication_import_exception.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';

import 'import_test_support.dart';

void main() {
  late Directory directory;
  late PublicationWorker worker;
  setUp(() async {
    directory = Directory.systemTemp.createTempSync('shiori-import-failure-');
    worker = await PublicationWorker.spawn();
  });
  tearDown(() async {
    await worker.close();
    directory.deleteSync(recursive: true);
  });

  final mutations =
      <String, (PublicationImportFailure, void Function(Map<String, String>))>{
        'missing container': (
          .invalidPackage,
          (e) {
            e.remove('META-INF/container.xml');
          },
        ),
        'malformed container': (
          .invalidPackage,
          (e) {
            e['META-INF/container.xml'] = '<container';
          },
        ),
        'wrong container root': (
          .invalidPackage,
          (e) {
            e['META-INF/container.xml'] = e['META-INF/container.xml']!
                .replaceAll('container ', 'wrong ')
                .replaceAll('</container>', '</wrong>');
          },
        ),
        'missing OPF': (
          .invalidPackage,
          (e) {
            e.remove('EPUB/package.opf');
          },
        ),
        'malformed OPF': (
          .invalidPackage,
          (e) {
            e['EPUB/package.opf'] = '<package';
          },
        ),
        'wrong OPF root': (
          .invalidPackage,
          (e) {
            e['EPUB/package.opf'] = e['EPUB/package.opf']!
                .replaceAll('<package ', '<wrong ')
                .replaceAll('</package>', '</wrong>');
          },
        ),
        'empty spine': (
          .invalidPackage,
          (e) {
            e['EPUB/package.opf'] = e['EPUB/package.opf']!.replaceAll(
              RegExp(r'<itemref[^>]*/>'),
              '',
            );
          },
        ),
        'unresolved first itemref': (
          .invalidPackage,
          (e) {
            e['EPUB/package.opf'] = e['EPUB/package.opf']!.replaceFirst(
              'idref="s0"',
              'idref="absent"',
            );
          },
        ),
        'no linear section': (
          .invalidPackage,
          (e) {
            e['EPUB/package.opf'] = e['EPUB/package.opf']!.replaceAll(
              'linear="yes"',
              'linear="no"',
            );
          },
        ),
        'missing first source': (
          .invalidFirstSection,
          (e) {
            e.remove('EPUB/s0.xhtml');
          },
        ),
        'empty first source': (
          .invalidFirstSection,
          (e) {
            e['EPUB/s0.xhtml'] = '';
          },
        ),
        'unparseable SVG first source': (
          .invalidFirstSection,
          (e) {
            e['EPUB/package.opf'] = e['EPUB/package.opf']!.replaceAll(
              'application/xhtml+xml',
              'image/svg+xml',
            );
            e['EPUB/s0.xhtml'] = '<svg';
          },
        ),
        'non-source spine item': (
          .invalidFirstSection,
          (e) {
            e['EPUB/package.opf'] = e['EPUB/package.opf']!.replaceAll(
              'application/xhtml+xml',
              'application/octet-stream',
            );
          },
        ),
      };
  for (final entry in mutations.entries) {
    test(
      '${entry.key} is typed, redacted, releases handle and worker recovers',
      () async {
        final entries = importEntries();
        entry.value.$2(entries);
        final file = writeImport(directory, entries);
        final identity = identityFor(file);
        await expectLater(
          worker.prepare(file.path, identity),
          throwsA(
            isA<PublicationImportException>()
                .having((e) => e.failure, 'failure', entry.value.$1)
                .having(
                  (e) => e.toString().contains(directory.path),
                  'path leaked',
                  false,
                ),
          ),
        );
        expect(worker.isClosed, isFalse);
        file.deleteSync();
        final good = writeImport(directory, importEntries(), name: 'good');
        expect(
          (await worker.prepare(good.path, identityFor(good))).metadata.titles,
          ['Generated import'],
        );
        expect((await worker.loadSection(0)).nodes, isNotEmpty);
      },
    );
  }

  for (final mode in ['garbage', 'truncated', 'CRC']) {
    test('$mode archive/first-section corruption is recoverable', () async {
      final file = writeImport(
        directory,
        importEntries(),
        badCrc: mode == 'CRC' ? 'EPUB/s0.xhtml' : null,
      );
      if (mode == 'garbage') file.writeAsBytesSync([1, 2, 3]);
      if (mode == 'truncated') {
        final bytes = file.readAsBytesSync();
        file.writeAsBytesSync(bytes.sublist(0, bytes.length - 10));
      }
      await expectLater(
        worker.prepare(file.path, identityFor(file)),
        throwsA(
          isA<PublicationImportException>().having(
            (e) => e.failure,
            'failure',
            mode == 'CRC'
                ? PublicationImportFailure.invalidFirstSection
                : PublicationImportFailure.invalidArchive,
          ),
        ),
      );
      file.deleteSync();
      final good = writeImport(directory, importEntries());
      await worker.prepare(good.path, identityFor(good));
    });
  }

  test('prepare enforces injected archive admission limits', () async {
    await worker.close();
    worker = await PublicationWorker.spawn(
      limits: const EpubLimits(maxEntries: 1),
    );
    final file = writeImport(directory, importEntries());
    await expectLater(
      worker.prepare(file.path, identityFor(file)),
      throwsA(
        isA<PublicationImportException>().having(
          (e) => e.failure,
          'failure',
          PublicationImportFailure.invalidArchive,
        ),
      ),
    );
    expect(worker.isClosed, isFalse);
    file.deleteSync();
  });
}
