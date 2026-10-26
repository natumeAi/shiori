@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';

import 'oracle_comparison.dart';
import 'sha256.dart';

const _vectorDirectory = 'build/oracle-local';
final _hexId = RegExp(r'^[0-9a-f]{64}$');

/// Compares the four private real books with their WebKit vectors. Skipped
/// when `build/oracle-local/` is absent. Failure output carries digests,
/// section and node indices and coordinates only: never book text.
void main() {
  final vectors = Directory(_vectorDirectory);
  final directories = [
    Platform.environment['SHIORI_LOCAL_EPUB_DIR'],
    'D:/Projects/lan-reader/docs',
  ].whereType<String>().where((path) => Directory(path).existsSync());
  final skip = !vectors.existsSync() || directories.isEmpty
      ? 'build/oracle-local/ or the local EPUB folder is absent'
      : null;

  test(
    'local books equal their WebKit vectors',
    () {
      final epubs = <String, File>{};
      for (final directory in directories) {
        for (final entity in Directory(directory).listSync()) {
          if (entity is File && entity.path.toLowerCase().endsWith('.epub')) {
            epubs[sha256Hex(entity.readAsBytesSync())] = entity;
          }
        }
      }
      final failures = <String>[];
      var compared = 0;
      var sections = 0;
      var cfiSamples = 0;
      for (final entity in vectors.listSync()) {
        final name = entity.uri.pathSegments.last;
        if (!name.endsWith('.webkit.json')) continue;
        final id = name.substring(0, name.length - '.webkit.json'.length);
        if (!_hexId.hasMatch(id)) continue;
        final epub = epubs[id];
        if (epub == null) {
          failures.add('$id: no local EPUB with this SHA-256');
          continue;
        }
        final vector = jsonDecode(
          File(entity.path).readAsStringSync(),
        ) as Map<String, Object?>;
        final book = EpubBook.open(
          epub.readAsBytesSync(),
          tokens: oracleTokens,
        );
        final differences = compareBookToVector(
          book,
          vector,
          showValues: false,
        );
        final cfi = compareNativeCfi(book, vector);
        failures.addAll(cfi.failures.map((f) => '${id.substring(0, 12)}: $f'));
        cfiSamples += cfi.samples;
        compared++;
        sections += book.sections.length;
        for (final difference in differences) {
          failures.add('${id.substring(0, 12)}: $difference');
        }
      }
      // ignore: avoid_print, counts only; this test has no logger and the output carries no book text.
      print(
        'local books compared: $compared, sections: $sections, cfi samples: $cfiSamples',
      );
      expect(failures, isEmpty);
      expect(compared, greaterThan(0));
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
