import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/reader/fixed_layout_scene_harness.dart';
import '../../../tool/reader/fixed_layout_spike_pixels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'authored XHTML rows execute native paint, channels and capability checks',
    () async {
      final report = await FixedLayoutSceneHarness().run();
      expect(report['geometryToleranceCssPx'], .5);
      final cases = (report['cases'] as List).cast<Map<String, Object?>>();
      expect(cases, hasLength(27));
      expect(cases.where((c) => c['required'] == true), hasLength(20));
      for (final c in cases) {
        expect(c['capability'], isA<Map>());
        expect((c['geometry'] as Map).containsKey('unverified'), true);
        if ((c['pixels'] as Map)['status'] == 'not-applicable') {
          expect(c['typedCapabilityPass'], true);
          expect(c['identityPass'], true);
        } else if (c['required'] == true) {
          expect(c['referencePaintStability'], isNotNull);
          expect((c['pixels'] as Map).containsKey('d4'), true);
          if ((c['textConservation'] as Map)['applicable'] == true) {
            expect(c['textRasterParity'], textRasterParityStatus);
            expect((c['textConservation'] as Map)['pass'], true);
            expect((c['pixels'] as Map)['textMask']['applied'], true);
            expect(
              ((c['pixels'] as Map)['d4']
                  as Map)['components']['textMask']['applied'],
              true,
            );
          } else {
            expect(c['textRasterParity'], isNull);
          }
          expect(
            File('build/fixed-layout-native/${c['id']}.png').existsSync(),
            true,
          );
        } else {
          expect(c['unsupportedVerdict'], true, reason: c['id'] as String);
        }
      }
      expect(
        (report['rowVerdicts'] as List).map((v) => v['row']).toSet(),
        FixedLayoutSceneHarness.rows,
      );
      for (final row in (report['rowVerdicts'] as List).cast<Map>()) {
        if (row['row'] == 'text') {
          expect(row['verdict'], textRasterParityStatus);
          expect(row['hostGate'], true);
          expect(row['failedCases'], isEmpty);
          expect(row['textRasterParity'], textRasterParityStatus);
        } else {
          expect(row['verdict'], 'pass', reason: row['row'] as String);
          expect(row['hostGate'], true);
        }
      }
      expect(report['textRasterParity'], textRasterParityStatus);
      final singular = cases.singleWhere((c) => c['id'] == 'stacking-boundary');
      expect((singular['capability'] as Map)['complete'], true);
      expect(singular['sourceGeometryComplete'], true);
      expect((singular['pixels'] as Map)['pass'], true);
      final fallback = (report['fallbackCases'] as List).single as Map;
      expect(fallback['id'], 'text-boundary');
      expect(fallback['hostConservationPass'], true);
      expect(fallback['fidelityGate'], false);
      for (final channel in ['geometry', 'pixels']) {
        expect(fallback[channel]['status'], 'device-gated (A5)');
        expect(fallback[channel]['pass'], false);
      }
    },
  );
}
