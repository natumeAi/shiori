import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/reader/fixed_layout_svg_filters_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'production SVG filters prove geometry, D4/D9 and typed refusal',
    () async {
      final report = await FixedLayoutSvgFiltersHarness().run();
      expect(report['geometryToleranceCssPx'], .5);
      expect(report['d7ComponentAlphaThreshold'], 32);
      final cases = (report['cases'] as List).cast<Map>();
      expect(cases, hasLength(4));
      expect(report['pass'], true);
      expect(report['rowVerdict'], 'PASS');
      for (final c in cases) {
        expect(
          c['capabilityPass'],
          true,
          reason: '${c['id']}: ${c['constructs']}',
        );
        expect(c['pass'], true, reason: '${c['id']}');
        expect(c['verdict'], 'PASS');
        expect(c['budgetUsedZero'], true);
        final id = c['id'] as String;
        if (c['required'] == true) {
          expect(c['status'], 'prepared');
          expect(c['picture'], true);
          expect((c['filterPaintEvidence'] as List).isNotEmpty, true);
          for (final evidence
              in (c['filterPaintEvidence'] as List).cast<Map>()) {
            expect(evidence['exactCoverage'], true);
            expect(evidence['pixelSize'], 1);
            expect(evidence['storageBytes'], greaterThanOrEqualTo(128));
          }
          expect(c['filterEvidencePass'], true);
          final geometry = c['geometry'] as Map;
          expect(geometry['pass'], true, reason: '$id geometry');
          expect(geometry['comparisons'], greaterThanOrEqualTo(1));
          expect(
            (geometry['maximumCssPxDelta'] as num) <= .5,
            true,
            reason: '$id geometry delta',
          );
          expect(geometry['visibilityEvidenceBounded'], true);
          final pixels = c['pixels'] as Map;
          expect(pixels['pass'], true, reason: '$id pixels');
          final d4 = pixels['d4'] as Map;
          for (final key in const [
            'interior',
            'edgeNeighbourhood',
            'supportBounds',
            'components',
            'samples',
          ]) {
            expect((d4[key] as Map)['pass'], true, reason: '$id D4 $key');
          }
          expect(
            ((pixels['d4SubRules'] as Map).values).every((v) => v == true),
            true,
          );
          expect((pixels['referenceDefects'] as List).isNotEmpty, true);
          expect(
            File('build/fixed-layout-svg-filters/$id.png').existsSync(),
            true,
          );
        } else {
          expect(c['status'], 'refused');
          expect(c['capability'], 'UnsupportedSectionCapability');
          expect((c['constructs'] as List).isNotEmpty, true);
          expect(c['picture'], false);
          expect(c['fragments'], 0);
        }
      }
      expect(
        File('build/fixed-layout-svg-filters/report.json').existsSync(),
        true,
      );
    },
  );
}
