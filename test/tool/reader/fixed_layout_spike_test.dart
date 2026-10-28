import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/reader/fixed_layout_spike.dart';
import '../../../tool/reader/fixed_layout_spike_defects.dart';
import '../../../tool/reader/fixed_layout_spike_geometry.dart';
import '../../../tool/reader/fixed_layout_spike_pixels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('RD-1 requires the own PNG and independent matching control; RD-2 requires static proof', () async {
    final defects = SpikeReferenceDefects({
      'engine': 'webkit',
      'engineVersion': '27.2',
    });
    await defects.load();
    final native = Uint8List(320 * 240 * 4);
    final expected = Uint8List.fromList(native)..[3] = 38;
    final fixture = <String, Object?>{
      'id': 'unlisted-xhtml-svg',
      'source': '<html xmlns="http://www.w3.org/1999/xhtml"><svg xmlns="http://www.w3.org/2000/svg"/></html>',
    };
    final reference = <String, Object?>{
      'paintStability': {
        'topLeft': [0, 0, 0, 38],
      },
    };
    expect(defects.scope(fixture, reference, native, expected).$1, {0: 'RD-1'});
    final decision = defects.scope(fixture, reference, native, expected).$2;
    expect(decision, hasLength(2));
    expect(decision.first['evidence'], isA<Map>());
    expect(
      defects
          .scope(
            {
              ...fixture,
              'id': 'filters-positive',
              'source': '<html xmlns="http://www.w3.org/1999/xhtml"/>',
            },
            reference,
            native,
            expected,
          )
          .$1,
      isEmpty,
    );
    expected[3] = 0;
    expect(defects.scope(fixture, reference, native, expected).$1, isEmpty);
    expected[3] = 38;
    defects.rasters['application/xhtml+xml/emptySVG']![3] = 0;
    expect(defects.scope(fixture, reference, native, expected).$1, isEmpty);
    final foreign = defects.scope(
      {
        'id': 'foreign-object-positive',
        'variant': 'positive',
        'source': fixture['source'],
      },
      {},
      defects.rasters['text/html/foreignStatic']!,
      defects.rasters['text/html/foreignRelative']!,
    );
    expect(foreign.$1.values, isNot(contains('RD-2')));
  });
  test('D7 thresholds components only, including faint missing interiors', () {
    final actual = Uint8List(320 * 240 * 4);
    void alpha(Uint8List image, int x, int y, int value) =>
        image[(y * 320 + x) * 4 + 3] = value;
    alpha(actual, 20, 20, 255);
    alpha(actual, 22, 20, 255);
    final expected = Uint8List.fromList(actual);
    alpha(actual, 21, 20, 31);
    alpha(expected, 21, 20, 4);
    var result = compareSpikePixels(actual, expected);
    expect(result['pass'], true);
    expect((result['d4'] as Map)['components']['alphaThresholdInclusive'], 32);
    expect((result['d4'] as Map)['components']['nativeCount'], 2);
    alpha(actual, 21, 20, 32);
    result = compareSpikePixels(actual, expected);
    expect((result['d4'] as Map)['components']['pass'], false);
    for (var y = 50; y < 55; y++) {
      for (var x = 50; x < 55; x++) {
        alpha(expected, x, y, 25);
      }
    }
    result = compareSpikePixels(actual, expected);
    expect((result['d4'] as Map)['interior']['pass'], false);
    expect((result['d4'] as Map)['supportBounds']['pass'], false);
  });
  test('D8 excludes only masked text pixels from the component sub-rule', () {
    final actual = Uint8List(320 * 240 * 4);
    final expected = Uint8List(320 * 240 * 4);
    void alpha(Uint8List image, int x, int y) =>
        image[(y * 320 + x) * 4 + 3] = 255;
    // Actual text forms one 8-connected run; expected text has two pieces.
    alpha(actual, 20, 20);
    alpha(actual, 21, 20);
    alpha(expected, 20, 20);
    alpha(expected, 22, 20);
    // Identical non-text paint stays outside the mask.
    alpha(actual, 100, 100);
    alpha(expected, 100, 100);
    expect(
      (compareSpikePixels(actual, expected)['d4'] as Map)['components']['pass'],
      isFalse,
    );
    final coverage = Uint8List(320 * 240)
      ..[20 * 320 + 20] = 1
      ..[20 * 320 + 21] = 1;
    final mask = buildD8TextMask(
      nativeGlyphCoverage: coverage,
      referenceGeometryLtrb: [
        [20, 20, 23, 21],
      ],
      provenance: {'test': 'synthetic'},
    );
    final result = compareSpikePixels(actual, expected, textMask: mask);
    expect((result['d4'] as Map)['components']['pass'], isTrue);
    expect((result['d4'] as Map)['components']['textMask']['applied'], isTrue);
    expect(result['textRasterParity'], textRasterParityStatus);
    expect(
      (result['textMask'] as Map)['excludedPixelsPerImage']['native'],
      greaterThan(0),
    );
    expect((result['textMask'] as Map)['maskPixels'], greaterThanOrEqualTo(4));
    // A non-text topology difference outside the mask still fails.
    alpha(expected, 110, 110);
    expect(
      (compareSpikePixels(actual, expected, textMask: mask)['d4']
          as Map)['components']['pass'],
      isFalse,
    );
    // The mask never suppresses the other D4 sub-rules.
    expect((result['d4'] as Map)['edgeNeighbourhood']['pass'], isFalse);
    expect(result['pass'], isFalse);
  });
  test(
    'D4 rejects flat recolouring, distant changes, lost components and samples',
    () {
      Uint8List image(List<(int, int, List<int>)> points) {
        final bytes = Uint8List(320 * 240 * 4);
        for (final p in points) {
          bytes.setRange(
            (p.$2 * 320 + p.$1) * 4,
            (p.$2 * 320 + p.$1) * 4 + 4,
            p.$3,
          );
        }
        return bytes;
      }

      final base = image([
        for (var y = 20; y < 25; y++)
          for (var x = 20; x < 25; x++) (x, y, [255, 0, 0, 255]),
      ]);
      final recoloured = Uint8List.fromList(base);
      for (var y = 20; y < 25; y++) {
        for (var x = 20; x < 25; x++) {
          recoloured[(y * 320 + x) * 4] = 100;
        }
      }
      final flat = compareSpikePixels(recoloured, base);
      expect((flat['d4'] as Map)['interior']['pass'], isFalse);
      expect((flat['d4'] as Map)['edgeNeighbourhood']['pass'], isFalse);
      final extra = Uint8List.fromList(base);
      extra.setRange((80 * 320 + 80) * 4, (80 * 320 + 80) * 4 + 4, [
        255,
        0,
        0,
        128,
      ]);
      final missing = compareSpikePixels(extra, base);
      expect((missing['d4'] as Map)['supportBounds']['pass'], isFalse);
      expect((missing['d4'] as Map)['components']['pass'], isFalse);
      expect(
        (compareSpikePixels(base, base, maximumSampleDelta: 1)['d4']
            as Map)['samples']['pass'],
        isFalse,
      );
      final edgeA = image([
        (20, 20, [255, 0, 0, 100]),
      ]);
      final edgeB = image([
        (20, 20, [255, 0, 0, 110]),
      ]);
      expect(compareSpikePixels(edgeA, edgeB)['pass'], isTrue);
      // Delta 2 is unchanged; delta 3 must be classified.
      edgeB[(20 * 320 + 20) * 4 + 3] = 102;
      expect(compareSpikePixels(edgeA, edgeB)['changedPixels'], 0);
      edgeB[(20 * 320 + 20) * 4 + 3] = 103;
      expect(compareSpikePixels(edgeA, edgeB)['changedPixels'], 1);
    },
  );
  test('geometry uses 2D endpoints and rotation displacement, not component extents', () {
    final result = compareSpikeGeometry(
      'svg-text',
      [
        {
          'textRun': 'a',
          'svgIndex': 0,
          'start': [.4, .4],
          'end': [10, 0],
          'rotation': 4.0,
        },
      ],
      {
        'svgTexts': [
          {
            'text': 'a',
            'clusterMap': [
              [0, 1],
            ],
            'characters': [
              {
                'start': [0, 0],
                'end': [10, 0],
                'rotation': 0.0,
              },
            ],
          },
        ],
      },
      nested: false,
      componentDiagnostics: {'maximumCssPxDelta': 100},
    );
    final channels = (result['channels'] as List).cast<Map>();
    expect(channels.first['maximumCssPxDelta'], greaterThan(.5));
    expect(
      channels
          .where((c) => c['channel'] == 'cluster-rotation-displacement')
          .every((c) => (c['maximumCssPxDelta'] as num) > .5),
      isTrue,
    );
    expect(result['maximumCssPxDelta'], lessThan(1));
  });
  test(
    'native A0 experiment measures real primitives and conserves source CFIs',
    () async {
      final report = await FixedLayoutSpike().run();
      final cases = (report['cases'] as List<Object?>)
          .cast<Map<String, Object?>>();
      final measured = cases.where((c) => c['status'] == 'measured').toList();
      expect(measured, hasLength(18));
      expect(report['schemaVersion'], 2);
      expect(report['geometryToleranceCssPx'], .5);
      expect(measured.where((c) => c['required'] == true), hasLength(15));
      expect(
        cases.where((c) => c['status'] == 'outside-spike-profile'),
        hasLength(4),
      );
      for (final result in measured) {
        expect(
          result['sourceCfiRoundTrips'],
          isTrue,
          reason: result['id'] as String,
        );
        expect(result['canonicalVersion'], 1);
        expect(result['canonicalLength'], 0);
        final id = result['id'] as String;
        if (id.startsWith('svg-text-') && !id.startsWith('svg-text-path-')) {
          final target = id.endsWith('-webkit-parent-length');
          expect(result['required'], target, reason: id);
          expect(result['role'], target ? 'target' : 'counterexample');
        }
        final geometry = result['geometry'] as Map<String, Object?>;
        expect(geometry['componentDiagnostics'], isA<Map>());
        if (result['row'] == 'svg-text') {
          expect(geometry['provisional'], isTrue);
          final channels = (geometry['channels'] as List).cast<Map>();
          expect(channels.map((c) => c['channel']).toSet(), {
            'cluster-start',
            'cluster-end',
            'cluster-rotation-displacement',
          });
          expect(
            channels.where((c) => c['channel'] == 'cluster-start'),
            hasLength(id.startsWith('svg-text-path-') ? 8 : 12),
          );
          expect(
            result['geometryGate'],
            (geometry['maximumCssPxDelta'] as num) <= .5,
          );
        } else if (result['row'] == 'foreign-object') {
          final channels = (geometry['channels'] as List).cast<Map>();
          expect(
            channels.where((c) => c['channel'] == 'baseline-y'),
            hasLength(7),
          );
          expect(
            channels.where((c) => c['channel'] == 'cluster-boundary-x'),
            hasLength(8),
          );
          expect(geometry['maximumCssPxDelta'], lessThanOrEqualTo(.5));
          expect(
            (geometry['componentDiagnostics'] as Map)['maximumCssPxDelta'],
            greaterThan(.5),
          );
        }
        _expectPixels(result);
        final conservation = result['textConservation'] as Map;
        if (result['row'] == 'svg-text') {
          expect(conservation['applicable'], isTrue, reason: id);
          expect(result['textRasterParity'], textRasterParityStatus);
          expect((result['pixels'] as Map)['textMask']['applied'], isTrue);
        } else if (result['row'] == 'foreign-object') {
          expect(conservation['pass'], isTrue, reason: id);
          expect(result['textRasterParity'], textRasterParityStatus);
          expect((result['pixels'] as Map)['textMask']['applied'], isTrue);
        } else {
          expect(conservation['applicable'], isFalse, reason: id);
        }
        final fragments = (result['sourceFragments'] as List<Object?>)
            .cast<Map<String, Object?>>();
        final expectedFragments = id.startsWith('svg-text-path-')
            ? 10
            : id.startsWith('svg-text-')
            ? 15
            : id.startsWith('foreign-object-')
            ? 7
            : 1;
        expect(fragments, hasLength(expectedFragments), reason: id);
        final textNodes = <int, List<Map<String, Object?>>>{};
        for (final fragment in fragments.where(
          (f) => f['kind'] == 'svg-character' || f['kind'] == 'foreign-text',
        )) {
          textNodes
              .putIfAbsent(fragment['node'] as int, () => [])
              .add(fragment);
        }
        for (final node in textNodes.values) {
          final text = node.first['sourceText'] as String;
          expect(
            node.map((f) => f['utf16Start']),
            List<int>.generate(text.length, (i) => i),
            reason: id,
          );
          expect(
            node.map((f) => f['utf16End']),
            List<int>.generate(text.length, (i) => i + 1),
            reason: id,
          );
        }
        expect(result['imageAllocations'], lessThanOrEqualTo(32));
        expect(
          File('${FixedLayoutSpike.outputPath}/${result['id']}.png')
              .existsSync(),
          isTrue,
        );
      }
      final filters = measured.where(
        (c) => (c['id'] as String).startsWith('filters-'),
      );
      for (final result in filters) {
        final stages = (result['nativeStages'] as List<Object?>)
            .cast<Map<String, Object?>>();
        expect(stages.map((s) => s['primitive']), [
          'feGaussianBlur',
          'feOffset',
          'feColorMatrix',
          'feFlood',
          'feComposite',
          'feBlend',
          'feMerge',
        ]);
        expect(result['distinctStageImages'], greaterThanOrEqualTo(6));
      }
      final alpha = measured.singleWhere(
        (c) => c['id'] == 'clip-mask-boundary',
      );
      final luminance = measured.singleWhere(
        (c) => c['id'] == 'clip-mask-positive',
      );
      final alphaSample =
          ((alpha['samples'] as List<Object?>).first
                  as Map<String, Object?>)['native']
              as List<int>;
      final luminanceSample =
          ((luminance['samples'] as List<Object?>).first
                  as Map<String, Object?>)['native']
              as List<int>;
      expect(alphaSample[3], inInclusiveRange(127, 128));
      expect(luminanceSample[3], inInclusiveRange(63, 65));
      final fontProbes = (report['fontProbes'] as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(fontProbes.map((p) => p['format']), ['sfnt', 'woff', 'woff2']);
      final sfnt = fontProbes.first;
      expect(sfnt['differentFromAbsentControl'], isTrue);
      expect(sfnt['widthDeltaCssPx'], lessThanOrEqualTo(.5));
      expect(report['usableFontBytes'], greaterThanOrEqualTo(171676));
      final controls = (report['paintControls'] as List)
          .cast<Map<String, Object?>>();
      expect(controls, hasLength(1));
      expect(controls.single['id'], 'foreignStatic');
      expect(controls.single['pixelGate'], isTrue);
      expect(controls.single['referenceDefects'], isEmpty);
      _expectPixels(controls.single);
      expect((controls.single['pixels'] as Map)['exemptPixels'], 0);
      final rows = (report['rowVerdicts'] as List).cast<Map>();
      expect(rows.map((r) => r['row']), [
        'filters',
        'clip-mask',
        'svg-text',
        'foreign-object',
      ]);
      for (final row in rows) {
        expect(row['verdict'], isIn(['pass', 'fail', textRasterParityStatus]));
        if (row['verdict'] == 'pass') expect(row['measuredGate'], isTrue);
        if (row['row'] != 'svg-text') expect(row['verdict'], 'pass');
        if (row['row'] == 'svg-text') {
          expect(row['verdict'], isNot('pass'));
          expect(row['textRasterParity'], textRasterParityStatus);
          expect(row['provisional'], isTrue);
        }
      }
      final curved = measured.singleWhere(
        (c) => c['id'] == 'svg-text-path-spacingAndGlyphs',
      );
      final combining = ((curved['geometry'] as Map)['channels'] as List)
          .cast<Map>()
          .where((c) => c['utf16'].toString() == '[6, 8]');
      expect(
        combining.any((c) => (c['maximumCssPxDelta'] as num) > .5),
        isTrue,
      );
      expect(curved['fidelityGate'], isFalse);
      expect(
        report['fidelityGate'],
        measured
                .where((c) => c['required'] == true)
                .every((c) => c['fidelityGate'] == true) &&
            controls.single['fidelityGate'] == true,
      );
      final registry = jsonDecode(
        File('test/fixtures/reader/fixed_layout/reference-defects.json')
            .readAsStringSync(),
      ) as Map;
      expect((registry['exceptions'] as List).map((r) => r['id']), [
        'RD-1',
        'RD-2',
      ]);
      // This exit status does not substitute for the report's fidelityGate.
      expect(
        File('${FixedLayoutSpike.outputPath}/report.json').existsSync(),
        isTrue,
      );
    },
  );
}

void _expectPixels(Map<String, Object?> result) {
  final p = result['pixels'] as Map;
  expect(p['status'], isIn(['pass', 'fail']));
  final d4 = p['d4'] as Map;
  expect(d4.keys.toSet(), {
    'interior',
    'edgeNeighbourhood',
    'supportBounds',
    'components',
    'samples',
  });
  expect(result['pixelGate'], d4.values.every((v) => v['pass'] == true));
  expect(result['sampleGate'], result['maximumSampleChannelDelta'] == 0);
  final textMask = p['textMask'] as Map;
  if (textMask['applied'] == true) {
    expect(textMask['provenance'], isA<Map>());
    expect(textMask['dilationPixels'], d8TextMaskDilationPixels);
    expect(textMask['excludedPixelsPerImage'], isA<Map>());
    expect((d4['components'] as Map)['textMask']['applied'], isTrue);
  }
  final counts = p['exemptCounts'] as Map,
      scopes = p['scopePixelCounts'] as Map;
  expect(counts['RD-1'], lessThanOrEqualTo(1));
  expect(counts['RD-2'], lessThanOrEqualTo(scopes['RD-2'] as int));
  if (result['row'] == 'foreign-object' && result['id'] != 'foreignStatic') {
    expect(counts['RD-2'], greaterThan(0));
    expect(scopes['RD-2'], 413);
  }
  if ((result['id'] as String).contains('nested')) expect(counts['RD-1'], 0);
  final decisions = (result['referenceDefects'] as List).cast<Map>();
  final rd2 = decisions.where((d) => d['id'] == 'RD-2').firstOrNull;
  for (final pixel in (p['exemptCoordinates'] as List).cast<Map>()) {
    if (pixel['defect'] == 'RD-1') {
      expect([pixel['x'], pixel['y']], [0, 0]);
      expect(pixel['reference'], [0, 0, 0, 38]);
      expect(
        decisions.singleWhere((d) => d['id'] == 'RD-1')['eligible'],
        isTrue,
      );
    } else {
      expect(result['row'], 'foreign-object');
      expect(rd2?['eligible'], isTrue);
      final boxes = (rd2!['expandedGlyphBoxesLTRB'] as List).cast<List>();
      expect(boxes, hasLength(2));
      final nested = result['id'] == 'foreign-object-nested';
      expect(
        boxes,
        nested
            ? [
                [88, 67, 101, 83],
                [78, 52, 91, 68],
              ]
            : [
                [81, 58, 94, 74],
                [71, 43, 84, 59],
              ],
      );
      expect(
        boxes.any(
          (b) =>
              pixel['x'] >= b[0] &&
              pixel['x'] < b[2] &&
              pixel['y'] >= b[1] &&
              pixel['y'] < b[3],
        ),
        isTrue,
      );
    }
  }
  expect(p['exemptCoordinates'], hasLength(p['exemptPixels'] as int));
  expect(
    p['changedPixels'],
    (p['nonExemptChangedPixels'] as int) + (p['exemptPixels'] as int),
  );
}
