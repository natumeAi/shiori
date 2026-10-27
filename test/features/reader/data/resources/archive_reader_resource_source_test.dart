import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/resources/archive_reader_resource_source.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';

void main() {
  final manifest = jsonDecode(
    File('assets/reader_fixtures/manifest.json').readAsStringSync(),
  ) as Map<String, Object?>;
  for (final value in manifest['fixtures']! as List<Object?>) {
    final fixture = value! as Map<String, Object?>;
    test('archive adapter preserves every bundled entry: ${fixture['id']}', () {
      final archive = EpubArchive.open(
        File('assets/reader_fixtures/${fixture['file']}').readAsBytesSync(),
      );
      final source = ArchiveReaderResourceSource(archive);
      for (final path in archive.names) {
        expect(source.contains(path), archive.contains(path));
        expect(source.size(path), archive.size(path));
        expect(source.bytes(path), archive.bytes(path));
        expect(source.text(path), archive.text(path));
      }
      expect(source.contains('absent'), isFalse);
      expect(source.size('absent'), 0);
      expect(source.bytes('absent'), isNull);
      expect(
        () => ReaderWorkGuard.callback(() => source.bytes('absent')),
        throwsAssertionError,
      );
      source.dispose();
      source.dispose();
      // Compatibility adapters do not own or close their caller's archive.
      expect(
        source.bytes(archive.names.first),
        archive.bytes(archive.names.first),
      );
      archive.close();
    });
  }
}
