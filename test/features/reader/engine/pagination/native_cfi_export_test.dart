@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/cfi/cfi.dart';
import 'package:shiori/features/reader/engine/pagination/anchor.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';

import '../layout/layout_test_support.dart';

const _fixtures = [
  'cfi-structure',
  'html-fallback',
  'inert-content',
  'opf-variants',
  'unicode',
  'styles',
  'images',
  'long-content',
  'chapters',
  'one-page',
];

/// Writes the CFI of every page anchor of every fixture (all gate settings)
/// to `$SHIORI_NATIVE_CFI_OUT/native-cfis.json` for `npm run resolve` in
/// `tool/oracle`, plus `native-cfi-expected.json` with the native resolution
/// of each. Skipped unless the variable names a directory.
void main() {
  initEngineBinding();
  final out = Platform.environment['SHIORI_NATIVE_CFI_OUT'];
  test(
    'export native page anchors for the Foliate resolve loop',
    () async {
      final preparer = SectionPreparer();
      final groups = <Map<String, Object?>>[];
      final expected = <String, Object?>{};
      for (final id in _fixtures) {
        final book = openFixture(id);
        final cfis = <String>{};
        for (final setting in gateSettings.values) {
          for (var i = 0; i < book.sections.length; i++) {
            final section = await prepareSection(
              book,
              i,
              preparer: preparer,
              resolver: fixtureResolver(),
              settings: setting,
            );
            final service = PageAnchors(section);
            for (final page in section.pages) {
              final anchor = service.exportVisible(page.index);
              if (anchor == null) continue;
              cfis.add(anchor.cfi);
              final range = Cfi.resolve(section.document, anchor.cfi);
              expected['$id|${anchor.cfi}'] = {
                'node': range.start.nodeIndex,
                'offset': range.start.offset,
              };
            }
            section.dispose();
          }
        }
        groups.add({'fixtureId': id, 'cfis': cfis.toList()..sort()});
      }
      Directory(out!).createSync(recursive: true);
      File('$out/native-cfis.json').writeAsStringSync(jsonEncode(groups));
      File('$out/native-cfi-expected.json')
          .writeAsStringSync(jsonEncode(expected));
      // ignore: avoid_print, counts only; no logger in tests.
      print('native CFIs written: ${expected.length}');
    },
    skip: out == null ? 'SHIORI_NATIVE_CFI_OUT is not set' : null,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
