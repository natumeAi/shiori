@TestOn('vm')
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';

import '../../data/epub/sha256.dart';
import '../layout/layout_test_support.dart';
import 'surface_test_support.dart';

void main() {
  initEngineBinding();
  test('existing image and long-content fixtures admit every page', () async {
    var index = 0;
    for (final fixture in ['images', 'long-content']) {
      final book = openFixture(fixture);
      try {
        for (final settings in gateSettings.values) {
          final decoded = await _pass(book, settings, ++index, private: false);
          if (fixture == 'images') expect(decoded, greaterThan(0));
        }
      } finally {
        book.archive.close();
      }
    }
  });

  final directories = [
    Platform.environment['SHIORI_LOCAL_EPUB_DIR'],
    'D:/Projects/lan-reader/docs',
  ].whereType<String>().where((path) => Directory(path).existsSync()).toList();
  test(
    'optional private books admit every page without identifying output',
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
      var index = 0;
      for (final file in files.values) {
        final book = EpubBook.open(file.readAsBytesSync());
        try {
          for (final settings in gateSettings.values) {
            await _pass(book, settings, ++index, private: true);
          }
        } finally {
          book.archive.close();
        }
      }
    },
    skip: directories.isEmpty || !Directory('build/oracle-local').existsSync()
        ? 'optional private regression inputs absent'
        : null,
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

Future<int> _pass(
  EpubBook book,
  ReaderSettings settings,
  int index, {
  required bool private,
}) async {
  final pool = PageSurfacePool();
  final preparer = SectionPreparer(images: pool.images);
  final held = <PageSurfaceLease>[];
  final sections = <PreparedSection>[];
  var peak = 0;
  var retainedPeak = 0;
  var decoded = 0;
  var pages = 0;
  var refused = 0;
  final previous = ui.Image.onCreate;
  // Called while intrinsic + output reservation is still charged, before
  // lease() reconciles the allocation to retained pixels.
  ui.Image.onCreate = (_) {
    decoded++;
    if (pool.images.totalBytes > peak) peak = pool.images.totalBytes;
  };
  try {
    expect(pool.maxImageBytes, 48 * 1024 * 1024);
    for (
      var sectionIndex = 0;
      sectionIndex < book.sections.length;
      sectionIndex++
    ) {
      final section = await prepareSection(
        book,
        sectionIndex,
        preparer: preparer,
        resolver: fixtureResolver(),
        settings: settings,
      );
      sections.add(section);
      for (var page = 0; page < section.pageCount; page++) {
        pages++;
        final lease = await pool.prepare(section, page, surfaceTheme);
        if (lease == null) {
          refused++;
        } else {
          held.add(lease);
          if (pool.images.totalBytes > retainedPeak) {
            retainedPeak = pool.images.totalBytes;
          }
          // Retain three pages while allocating the fourth, also across
          // section boundaries: old raster leases remain charged.
          if (held.length > PageSurfacePool.presentedCapacity) {
            held.removeAt(0).release();
          }
        }
      }
      final retired = sections.where((s) => !pool.pinsSection(s)).toList();
      for (final old in retired) {
        old.dispose();
        sections.remove(old);
      }
    }
  } finally {
    ui.Image.onCreate = previous;
    for (final lease in held) {
      lease.release();
    }
    pool.close();
    for (final section in sections) {
      section.dispose();
    }
  }
  // ignore: avoid_print, anonymous indices and counts only.
  print(
    'private=${private ? 1 : 0} pass=$index sections=${book.sections.length} '
    'pages=$pages decoded=$decoded peakBytes=$peak retainedBytes=$retainedPeak '
    'refusals=$refused peakOwners=${pool.peakOwners}',
  );
  expect(refused, 0);
  expect(peak, lessThanOrEqualTo(pool.maxImageBytes));
  expect(pool.images.totalBytes, 0);
  expect(pool.owners, 0);
  return decoded;
}
