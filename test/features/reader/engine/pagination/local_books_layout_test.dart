@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/engine/pagination/anchor.dart';
import 'package:shiori/features/reader/engine/pagination/conservation.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';

import '../../data/epub/sha256.dart';
import '../layout/layout_test_support.dart';

/// Runs the conservation check and the page-anchor proof on the four private
/// real books at the default settings. Skipped when the local EPUB folder or
/// `build/oracle-local/` is absent. Output carries digests, counts and
/// coordinates only: never book text.
void main() {
  initEngineBinding();
  final directories = [
    Platform.environment['SHIORI_LOCAL_EPUB_DIR'],
    'D:/Projects/lan-reader/docs',
  ].whereType<String>().where((path) => Directory(path).existsSync());
  final skip =
      !Directory('build/oracle-local').existsSync() || directories.isEmpty
      ? 'build/oracle-local/ or the local EPUB folder is absent'
      : null;

  test(
    'local books: conservation and anchors at the three gate settings',
    () async {
      final files = <String, File>{};
      for (final directory in directories) {
        for (final entity in Directory(directory).listSync()) {
          if (entity is File && entity.path.toLowerCase().endsWith('.epub')) {
            files[sha256Hex(entity.readAsBytesSync())] = entity;
          }
        }
      }
      expect(files, isNotEmpty);
      final preparer = SectionPreparer();
      final failures = <String>[];
      for (final entry in files.entries) {
        for (final setting in gateSettings.entries) {
          final id = '${entry.key.substring(0, 12)} ${setting.key}';
          final book = EpubBook.open(entry.value.readAsBytesSync());
          var pages = 0;
          var lines = 0;
          var chars = 0;
          var images = 0;
          var surfaced = 0;
          var anchors = 0;
          var unsupported = 0;
          final differences = <String, int>{};
          final resolver = fixtureResolver();
          final watch = Stopwatch()..start();
          for (var i = 0; i < book.sections.length; i++) {
            final section = await prepareSection(
              book,
              i,
              preparer: preparer,
              resolver: resolver,
              settings: setting.value,
              contentId: entry.key,
            );
            final styled = resolver.resolve(
              book,
              i,
              section.document,
              setting.value,
            );
            final report = checkConservation(section, styled);
            for (final failure in report.failures) {
              failures.add('$id#$i: $failure');
            }
            pages += report.pages;
            lines += report.lines;
            chars += report.sourceCharacters;
            images += report.images;
            surfaced += report.surfacedUnsupported;
            unsupported += section.unsupported.length;
            section.model.differences.forEach(
              (code, count) => differences.update(
                code,
                (v) => v + count,
                ifAbsent: () => count,
              ),
            );
            final service = PageAnchors(section);
            for (final page in section.pages) {
              final anchor = service.exportVisible(page.index);
              if (anchor == null) {
                if (page.map.spans.isNotEmpty ||
                    page.map.imageNodes.isNotEmpty) {
                  failures.add('$id#$i page ${page.index}: no anchor');
                }
                continue;
              }
              anchors++;
            }
            section.dispose();
          }
          // ignore: avoid_print, counts only; no logger in tests.
          print(
            'book $id: sections=${book.sections.length} pages=$pages '
            'lines=$lines chars=$chars images=$images surfaced=$surfaced '
            'unsupported=$unsupported anchors=$anchors '
            'differences=$differences ms=${watch.elapsedMilliseconds}',
          );
        }
      }
      expect(failures, isEmpty);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
