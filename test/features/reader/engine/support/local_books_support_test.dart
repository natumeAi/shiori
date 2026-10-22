@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/support/unsupported_layout.dart';

/// Checks the private real books: supported layout, and counts of ignored or
/// approximated CSS. Skipped when `build/oracle-local/` or the local EPUB
/// folder is absent. Output carries counts and CSS property/at-rule names
/// only: never book text.
void main() {
  final vectors = Directory('build/oracle-local');
  final directories = [
    Platform.environment['SHIORI_LOCAL_EPUB_DIR'],
    'D:/Projects/lan-reader/docs',
  ].whereType<String>().where((path) => Directory(path).existsSync());
  final skip = !vectors.existsSync() || directories.isEmpty
      ? 'build/oracle-local/ or the local EPUB folder is absent'
      : null;

  test(
    'local books are supported and report their ignored CSS',
    () {
      final files = <File>[];
      for (final directory in directories) {
        for (final entity in Directory(directory).listSync()) {
          if (entity is File && entity.path.toLowerCase().endsWith('.epub')) {
            files.add(entity);
          }
        }
      }
      files.sort((a, b) => a.path.compareTo(b.path));
      expect(files, isNotEmpty);
      var number = 0;
      for (final file in files) {
        number++;
        final book = EpubBook.open(file.readAsBytesSync());
        final support = detectBookLayout(book);
        final totals = <String, int>{};
        final fontFaces = <String>{};
        for (var i = 0; i < book.sections.length; i++) {
          final styled = const CssStyleResolver().resolve(
            book,
            i,
            book.loadSection(i),
            const ReaderSettings(),
          );
          fontFaces.addAll(styled.fontFaces.map((f) => f.archivePath));
          for (final d in styled.diagnostics) {
            final key = '${d.kind.name}:${d.detail}';
            totals[key] = (totals[key] ?? 0) + d.count;
          }
        }
        final sorted = totals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        // ignore: avoid_print, counts and CSS names only; no logger in tests.
        print(
          'book $number: sections=${book.sections.length} '
          'supported=${support.supported} '
          'reasons=${support.reasons.map((r) => r.name).toList()} '
          'fontFaces=${fontFaces.length} '
          'ignoredTotal=${totals.values.fold(0, (a, b) => a + b)} '
          'ignored=${sorted.map((e) => '${e.key} x${e.value}').toList()}',
        );
        expect(
          support.supported,
          isTrue,
          reason: 'book $number: ${support.reasons}',
        );
      }
      expect(number, greaterThan(0));
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
