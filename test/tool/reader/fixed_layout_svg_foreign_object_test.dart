import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/reader/fixed_layout_svg_foreign_object_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'production foreignObject geometry, conservation and reference rules',
    () async {
      final report = await FixedLayoutSvgForeignObjectHarness().run();
      expect(report['geometryToleranceCssPx'], .5);
      expect(report['d7ComponentAlphaThreshold'], 32);
      expect(report['d10ChangedPixelMinimumDelta'], 2);
      expect(
        File('build/fixed-layout-svg-foreign-object/report.json').existsSync(),
        true,
      );
      final control = report['foreignStatic'] as Map;
      expect(control['pass'], true, reason: '$control');
      expect((control['pixels'] as Map)['exemptions'], 0);
      final cases = (report['cases'] as List).cast<Map>();
      expect(cases, hasLength(4));
      for (final c in cases) {
        expect(c['budgetUsedZero'], true);
        expect(c['capabilityPass'], true, reason: '$c');
        expect(c['pass'], true, reason: '${c['id']}: $c');
        if (c['required'] == true) {
          expect((c['geometry'] as Map)['pass'], true);
          expect((c['conservation'] as Map)['pass'], true);
          final pixels = c['pixels'] as Map;
          expect(pixels['pass'], true);
          final rd2 = (pixels['referenceDefects'] as List)
              .cast<Map>()
              .singleWhere((r) => r['id'] == 'RD-2');
          expect(rd2['eligible'], true);
        } else {
          expect(c['picture'], false);
          expect((c['constructs'] as List).isNotEmpty, true);
        }
      }
      expect(report['rowVerdict'], 'PASS');
    },
  );
}
