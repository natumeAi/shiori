import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/reader/fixed_layout_svg_clipmask_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('production clip/mask row reports every required channel', () async {
    final report = await FixedLayoutSvgClipMaskHarness().run();
    expect(report['geometryToleranceCssPx'], .5);
    expect(report['d7ComponentAlphaThreshold'], 32);
    expect(report['d10ChangedPixelMinimumDelta'], 2);
    final cases = (report['cases'] as List).cast<Map>();
    expect(cases, hasLength(4));
    expect(report['pass'], true);
    for (final c in cases) {
      expect(
        c['typedCapabilityPass'],
        true,
        reason: '${c['id']}: ${c['constructs']}',
      );
      if (c['required'] == true) {
        final geometry = c['geometry'] as Map;
        expect(geometry['pass'], true, reason: '${c['id']}');
        expect(geometry['sourceGeometryComplete'], true);
        expect(geometry['comparisons'], greaterThan(0));
        final evidence = geometry['evidence'] as Map;
        expect(evidence['clips'], 2, reason: '${c['id']}');
        expect(evidence['masks'], 1, reason: '${c['id']}');
        expect(evidence['unresolvedClips'], isEmpty);
        expect(evidence['unresolvedMasks'], isEmpty);
        expect(evidence['maskKinds'], [
          c['variant'] == 'boundary' ? 'alpha' : 'luminance',
        ]);
        final fixed = c['fixedGeometry'] as Map;
        expect(fixed['pass'], true, reason: '${c['id']}');
        expect((fixed['maskIds'] as List).single, startsWith('slot:'));
        final pixels = c['pixels'] as Map;
        expect(pixels['pass'], true, reason: '${c['id']}');
        final d4 = pixels['d4'] as Map;
        for (final rule in const [
          'interior',
          'edgeNeighbourhood',
          'supportBounds',
          'components',
          'samples',
        ]) {
          expect((d4[rule] as Map)['pass'], true, reason: '${c['id']}:$rule');
        }
        expect((d4['samples'] as Map)['samples'], isA<List>());
        expect(
          File('build/fixed-layout-svg-clipmask/${c['id']}.png').existsSync(),
          true,
        );
      } else {
        expect(c['status'], 'refused');
        expect(c['referenceDefects'], isEmpty);
        expect(c['capability'], 'UnsupportedSectionCapability');
        expect(
          (c['constructs'] as List).single,
          anyOf('svg-css-clip-path', 'svg-clip-path'),
        );
        expect((c['geometry'] as Map)['pass'], false);
      }
    }
    expect(
      File('build/fixed-layout-svg-clipmask/report.json').existsSync(),
      true,
    );
  });
}
