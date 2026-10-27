import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';

import '../layout/layout_test_support.dart';
import 'resource_parity_snapshot.dart';

void main() {
  initEngineBinding();
  const path = 'build/d4/pre-seam-pages.json';
  final capture = Platform.environment['D4_CAPTURE_BASELINE'] == '1';
  final required = Platform.environment['D4_REQUIRE_BASELINE'] == '1';
  final missing = !File(path).existsSync();
  test(
    'bundled prepared output matches the optional pre-seam host capture',
    () async {
      if (required && !capture) {
        expect(
          missing,
          isFalse,
          reason: 'Required pre-seam evidence is missing: $path',
        );
      }
      final snapshots = <String, Object?>{};
      final manifest = jsonDecode(
        File('assets/reader_fixtures/manifest.json').readAsStringSync(),
      ) as Map<String, Object?>;
      for (final value in manifest['fixtures']! as List<Object?>) {
        final fixture = value! as Map<String, Object?>;
        final id = fixture['id']! as String;
        final book = openFixture(id);
        for (final entry in gateSettings.entries) {
          for (var i = 0; i < book.sections.length; i++) {
            final section = await prepareSection(
              book,
              i,
              preparer: SectionPreparer(),
              resolver: fixtureResolver(),
              settings: entry.value,
            );
            snapshots['$id/${entry.key}/$i'] = resourceParitySnapshot(section);
            section.dispose();
          }
        }
        book.archive.close();
      }
      expect(snapshots.length, greaterThan(100));
      if (capture) {
        File(path).writeAsStringSync(jsonEncode(snapshots));
      } else {
        expect(
          jsonDecode(jsonEncode(snapshots)),
          jsonDecode(File(path).readAsStringSync()),
        );
      }
    },
    skip: missing && !capture && !required
        ? 'Missing optional pre-seam evidence: $path; set D4_REQUIRE_BASELINE=1 to require it.'
        : false,
  );
}
