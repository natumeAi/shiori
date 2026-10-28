import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/reader/fixed_layout_spike_pixels.dart';
import '../../../tool/reader/harfbuzz_probe.dart';
import '../../../tool/reader/harfbuzz_probe_ffi.dart';
import '../../../tool/reader/harfbuzz_probe_gates.dart';
import '../../../tool/reader/harfbuzz_probe_inputs.dart';
import '../../../tool/reader/harfbuzz_probe_scene.dart';
import '../../../tool/reader/harfbuzz_probe_shape.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final reason = !Platform.isWindows
      ? 'Windows x64 HarfBuzz 14.6.0 host probe; no binary for this platform.'
      : !File(harfBuzzProbeLibrary).existsSync()
      ? 'Owner-approved HarfBuzz DLL absent at $harfBuzzProbeLibrary; CI has no binary. No download is attempted.'
      : null;
  test('HarfBuzz shaping, cluster Path paint, D3/D4 and teardown execute', () async {
    final report = await runHarfBuzzProbe();
    expect(report['runtimeVersion'], '14.6.0');
    expect(report['clusterProvenance'], 'shaped');
    final shaping = (report['shaping'] as List).cast<Map<String, Object?>>();
    expect(shaping, hasLength(2));
    for (final run in shaping) {
      expect(run['fixtureClustersConfirmed'], isTrue);
      expect(run['paragraphAdvanceDelta'], lessThanOrEqualTo(.01));
      expect(run['webkitAdvanceDelta'], lessThanOrEqualTo(.01));
    }
    final cases = (report['cases'] as List).cast<Map<String, Object?>>();
    expect(
      cases.map((c) => c['id']),
      unorderedEquals([
        'svg-text-positive',
        'svg-text-boundary',
        'svg-text-nested',
        'svg-text-path-none',
        'svg-text-path-spacing',
        'svg-text-path-spacingAndGlyphs',
      ]),
    );
    for (final c in cases) {
      expect(c['fixtureClustersConfirmed'], isTrue);
      expect(c['sourceAndGlyphConservation'], isTrue);
      expect((c['geometry'] as Map)['comparisons'], greaterThan(0));
      expect((c['geometry'] as Map)['provisional'], isFalse);
      expect((c['geometryB'] as Map)['pass'], isTrue);
      expect((c['geometry'] as Map)['paintedUnit'], 'component-fragment');
      expect((c['pixels'] as Map)['status'], isNot('unverified'));
      expect(c['textRasterParity'], textRasterParityStatus);
      expect((c['clusterConservation'] as Map)['pass'], isTrue);
      expect((c['pixels'] as Map)['textMask']['applied'], isTrue);
      expect(
        ((c['pixels'] as Map)['d4']
            as Map)['components']['textMask']['applied'],
        isTrue,
      );
      final channels = ((c['geometryB'] as Map)['channels'] as List)
          .cast<Map>();
      expect(channels.where((x) => x['channel'] == 'cluster-end'), isEmpty);
      expect(
        channels.where((x) => x['channel'] == 'run-total-advance'),
        hasLength((c['runs'] as List).length),
      );
      final emitted = c['emittedGlyphs'] as List;
      expect(emitted.toSet(), hasLength(c['glyphEmissionCount'] as int));
    }
    final variants = (report['featureComparisons'] as List).cast<Map>();
    expect(variants, hasLength(11));
    for (final variant in variants) {
      expect(variant['sourceAndGlyphConservation'], isTrue);
      expect((variant['pixels'] as Map)['status'], isNot('unverified'));
    }
    final rasterComparisons = (report['rasterComparisons'] as List).cast<Map>();
    expect(rasterComparisons, hasLength(6));
    for (final candidate in cases) {
      final raw = rasterComparisons.singleWhere(
        (v) => v['id'] == '${candidate['id']}-unhinted-fragments',
      );
      expect(raw['geometryB'], candidate['geometryB']);
      expect(raw['d3Decisions'], candidate['d3Decisions']);
      expect(raw['sourceAndGlyphConservation'], isTrue);
    }
    final gdi = (report['gdiDiagnostics'] as List).cast<Map>();
    expect(gdi, hasLength(6));
    for (final diagnostic in gdi) {
      expect(diagnostic['id'], endsWith('-gdi-diagnostic'));
      expect((diagnostic['pixels'] as Map)['status'], isNot('unverified'));
      expect(
        (diagnostic['pixels'] as Map)['textMask']['provenance']['paintPath'],
        contains('GDI'),
      );
    }
    expect(report['gdiDiagnosticOnly'], contains('never'));
    expect(
      (cases.first['pixels'] as Map)['textMask']['provenance']['paintPath'],
      'unhinted hb_font_draw_glyph',
    );
    expect(
      report['svgTextRowVerdict'],
      report['hostD8Gate'] == true ? textRasterParityStatus : 'fail',
    );
    expect(report['svgTextRowVerdict'], isNot('pass'));
    for (final adjustment in ['none', 'spacing', 'spacingAndGlyphs']) {
      final on = variants.singleWhere(
        (v) => v['id'] == 'svg-text-path-$adjustment-liga-on',
      );
      final original = cases.singleWhere(
        (v) => v['id'] == 'svg-text-path-$adjustment',
      );
      // Fragment painting can change D4, but never D3 eligibility or scope.
      expect(on['d3Decisions'], original['d3Decisions']);
      expect(
        (on['pixels'] as Map)['exemptCoordinates'],
        (original['pixels'] as Map)['exemptCoordinates'],
      );
      final off = variants.singleWhere(
        (v) => v['id'] == 'svg-text-path-$adjustment-liga-off',
      );
      expect(((off['runs'] as List).single as Map)['features'], 'liga=0');
    }
    final control = report['outlineControl'] as Map;
    expect(control['sourceAndGlyphConservation'], isTrue);
    expect(
      (control['clusters'] as List).every(
        (c) => c['inkCrossesAdvance'] == true,
      ),
      isTrue,
    );
    final resources = report['resources'] as Map;
    expect((resources['live'] as Map).values, everyElement(0));
    expect((resources['livePayloadBytes'] as Map).values, everyElement(0));
    expect(
      report['fidelityGate'],
      cases.every((c) => c['fidelityGateB'] == true),
    );
    expect(report['adoptedGateDefinition'], 'B');
    expect((report['svgTextContentHashes'] as Map)['unchanged'], isTrue);
    // A successful experiment test does not require a fidelity pass.
    // ignore: avoid_print
    print(
      'svg-text=${report['svgTextRowVerdict']}; $harfBuzzProbeOutput/report.json',
    );
  }, skip: reason ?? false);

  test('B keeps starts, total advance and single-component rotation only', () {
    final scene = HbScene()..runs.add(HbRun('fi X', [], 1, true));
    scene.clusters.add({'runIndex': 0, 'runAdvance': 10});
    Map<String, Object?> channel(String name, List<int> range, double delta) =>
        {
          'channel': name,
          'utf16': range,
          'maximumCssPxDelta': delta,
          'pass': delta <= .5,
        };
    final current = <String, Object?>{
      'channels': [
        channel('cluster-start', [0, 2], .2),
        channel('cluster-end', [0, 2], 9),
        channel('cluster-rotation-displacement', [0, 2], 7),
        channel('cluster-rotation-displacement', [3, 4], .4),
      ],
    };
    final refs = <Map<String, Object?>>[
      {'text': 'fi X', 'computedTextLength': 10},
    ];
    final result = probeGateB(scene, refs, current);
    expect(result['maximumCssPxDelta'], .4);
    expect(result['pass'], isTrue);
    expect(result['diagnostics'], hasLength(2));
    scene.clusters.single['runAdvance'] = 11;
    expect(probeGateB(scene, refs, current)['pass'], isFalse);
    scene.close();
  });
  test('content pins ignore provenance but retain measurements and PNGs', () {
    final record = <String, Object?>{
      'id': 'svg-text-probe',
      'clusterSource': 'fixture-declared',
      'clusterConfirmation': 'pending',
      'evidence': {'producer': 'old'},
      'characters': [
        {
          'start': [1, 2],
          'rotation': 10,
        },
      ],
      'pngBase64': 'original',
    };
    String hash() => svgTextContentHash({
      'cases': [record],
      'svgTextProbes': [],
    });
    final initial = hash();
    record['clusterSource'] = 'shaped';
    record['clusterConfirmation'] = 'confirmed';
    record['evidence'] = {'producer': 'new'};
    expect(hash(), initial);
    record['pngBase64'] = 'changed';
    expect(hash(), isNot(initial));
    record['pngBase64'] = 'original';
    record['characters'] = [
      {
        'start': [1, 3],
        'rotation': 10,
      },
    ];
    expect(hash(), isNot(initial));
  });
}
