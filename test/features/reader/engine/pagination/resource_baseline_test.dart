import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';

import '../layout/layout_test_support.dart';
import 'resource_parity_snapshot.dart';

void main() {
  initEngineBinding();
  test(
    'bundled prepared output matches the optional pre-seam host capture',
    () async {
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
      const path = 'build/d4/pre-seam-pages.json';
      if (Platform.environment['D4_CAPTURE_BASELINE'] == '1') {
        File(path).writeAsStringSync(jsonEncode(snapshots));
      } else if (File(path).existsSync()) {
        expect(
          jsonDecode(jsonEncode(snapshots)),
          jsonDecode(File(path).readAsStringSync()),
        );
      }
    },
  );
}
