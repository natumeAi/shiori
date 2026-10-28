import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/reader/fixed_layout_svg_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'production SVG graphics reports every required channel and refusal',
    () async {
      final report = await FixedLayoutSvgHarness().run();
      expect(report['geometryToleranceCssPx'], .5);
      expect(report['d7ComponentAlphaThreshold'], 32);
      final cases = (report['cases'] as List).cast<Map>();
      expect(cases, hasLength(4));
      for (final c in cases) {
        expect(
          c['typedCapabilityPass'],
          true,
          reason: '${c['id']}: ${c['constructs']}',
        );
        if (c['required'] == true) {
          expect(c['sourceGeometryComplete'], true);
          expect((c['geometry'] as Map)['comparisons'], greaterThan(0));
          expect((c['pixels'] as Map)['d4'], isA<Map>());
          expect(
            (c['referencePaintStability']
                as Map)['twoAnimationFramesIdentical'],
            true,
          );
          expect(
            File('build/fixed-layout-svg/${c['id']}.png').existsSync(),
            true,
          );
        } else {
          expect(c['capability'], 'UnsupportedSectionCapability');
          expect(c['sourceFragments'], 0);
          expect(c['constructs'], contains('svg-filter'));
        }
      }
    },
  );
}
