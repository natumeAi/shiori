// Run: flutter test test/tool/reader/fixed_layout_spike_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show FlutterVersion;
import 'package:shiori/features/reader/data/canonical/canonical_text.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';

import 'fixed_layout_spike_filters.dart';
import 'fixed_layout_spike_fonts.dart';
import 'fixed_layout_spike_defects.dart';
import 'fixed_layout_spike_geometry.dart';
import 'fixed_layout_spike_pixels.dart';
import 'fixed_layout_spike_scene.dart';

/// A real dart:ui experiment. Test success means the experiment executed;
/// its independent fidelityGate must be read separately. Output is ignored.
final class FixedLayoutSpike {
  static const outputPath = 'build/fixed-layout-native';
  static const rows = {'svg-text', 'filters', 'clip-mask', 'foreign-object'};
  late SpikeReferenceDefects _defects;

  Future<Map<String, Object?>> run() async {
    final corpusBytes = File('test/fixtures/reader/fixed_layout/corpus.json')
        .readAsBytesSync();
    final oracleBytes = File('test/fixtures/reader/fixed_layout/oracle.json')
        .readAsBytesSync();
    final corpus = jsonDecode(utf8.decode(corpusBytes)) as Map<String, Object?>;
    final oracle = jsonDecode(utf8.decode(oracleBytes)) as Map<String, Object?>;
    if (oracle['corpusSHA256'] != sha256.convert(corpusBytes).toString()) {
      throw StateError('Oracle does not match exact corpus bytes');
    }
    final font = corpus['font'] as Map<String, Object?>;
    final bytes = File(font['path'] as String).readAsBytesSync();
    if (sha256.convert(bytes).toString() != font['sha256']) {
      throw StateError('Font provenance mismatch');
    }
    await ui.loadFontFromList(bytes, fontFamily: 'FixedLayoutSpikeRoboto');
    final fontProbes = await runSpikeFonts(oracle);
    final references = {
      for (final c in oracle['cases'] as List<Object?>)
        (c as Map<String, Object?>)['id'] as String: c,
    };
    Directory(outputPath).createSync(recursive: true);
    _defects = SpikeReferenceDefects(oracle);
    await _defects.load();
    final staticReference = _defects.control('foreignStatic', 'text/html');
    final staticControl = await _render(
      {
        'id': 'foreignStatic',
        'row': 'foreign-object',
        'variant': 'positive',
        'source':
            '<html xmlns="http://www.w3.org/1999/xhtml"><body>${(staticReference['sourceBody'] as String).replaceFirst('<foreignObject ', '<foreignObject id="source" ')}</body></html>',
      },
      {'samples': <Object?>[], 'pngBase64': staticReference['pngBase64']},
      paintControl: true,
    );
    _defects.staticControlPass = staticControl['pixelGate'] == true;
    final cases = <Map<String, Object?>>[];
    for (final entry in corpus['cases'] as List<Object?>) {
      final fixture = entry as Map<String, Object?>;
      if (!rows.contains(fixture['row'])) continue;
      if (fixture['expectedCapability'] == 'unsupported') {
        cases.add({
          'id': fixture['id'],
          'status': 'outside-spike-profile',
          'required': false,
          'fidelityGate': null,
          'referenceDefects': _defects.unmeasured(
            'Outside spike profile; no raster gate',
          ),
        });
        continue;
      }
      cases.add(await _render(fixture, references[fixture['id']]!));
      if (fixture['row'] == 'svg-text') {
        cases.add(
          await _render(
            fixture,
            references[fixture['id']]!,
            applyParentTextLength: false,
          ),
        );
      }
    }
    for (final raw in oracle['svgTextProbes'] as List<Object?>) {
      final probe = raw as Map<String, Object?>;
      final fixture = <String, Object?>{
        'id': 'svg-text-path-${probe['adjustment']}',
        'source': probe['source'],
        'row': 'svg-text',
        'variant': 'positive',
        // setContent retains the XHTML host, with the default body margin.
        'captureHostMediaType': 'application/xhtml+xml',
        'captureBodyMargin': [8, 8],
      };
      cases.add(
        await _render(fixture, {
          'samples': <Object?>[],
          'svgTexts': [probe],
          'pngBase64': probe['pngBase64'],
          'paintStability': probe['paintStability'],
        }),
      );
    }
    final report = <String, Object?>{
      'd4ComponentAlphaThresholdInclusive': d4ComponentAlphaThreshold,
      'd10ChangedPixelMinimumDelta': d10ChangedPixelMinimumDelta,
      'schemaVersion': 2,
      'evidence': 'host-flutter-test-dart-ui-no-device-performance-claim',
      'host': Platform.operatingSystem,
      'dart': Platform.version,
      'flutterVersion': FlutterVersion.version,
      'frameworkRevision': FlutterVersion.frameworkRevision,
      'engineRevision': FlutterVersion.engineRevision,
      'harnessSHA256': sha256.convert([
        for (final name in [
          'fixed_layout_spike.dart',
          'fixed_layout_spike_filters.dart',
          'fixed_layout_spike_fonts.dart',
          'fixed_layout_spike_scene.dart',
          'fixed_layout_spike_defects.dart',
          'fixed_layout_spike_geometry.dart',
          'fixed_layout_spike_pixels.dart',
        ])
          ...File('tool/reader/$name').readAsBytesSync(),
      ]).toString(),
      'corpusSHA256': sha256.convert(corpusBytes).toString(),
      'oracleSHA256': sha256.convert(oracleBytes).toString(),
      'referenceEngine': oracle['engine'],
      'referenceEngineVersion': oracle['engineVersion'],
      'referenceCommit': oracle['referenceCommit'],
      'font': font,
      'fontProbes': fontProbes,
      'requiredSfntFontGate': fontProbes.first['fidelityGate'],
      'fontRegistrationFuturesCompleted': fontProbes
          .where((p) => p['registrationFutureCompleted'] == true)
          .length,
      'attemptedRegistrationBytes': fontProbes
          .where((p) => p['registrationFutureCompleted'] == true)
          .fold<int>(0, (sum, p) => sum + (p['bytes'] as int)),
      'usableFontBytes': fontProbes
          .where((p) => p['fidelityGate'] == true)
          .fold<int>(0, (sum, p) => sum + (p['bytes'] as int)),
      'uncertainFontRegistrationBytes': fontProbes
          .where(
            (p) =>
                p['registrationFutureCompleted'] == true &&
                p['fidelityGate'] != true,
          )
          .fold<int>(0, (sum, p) => sum + (p['bytes'] as int)),
      'viewport': [320, 240],
      'geometryToleranceCssPx': .5,
      'imageAdmission': {
        'maximumImagesPerCase': 32,
        'bytesPerImage': 320 * 240 * 4,
      },
      'cases': cases,
      'paintControls': [staticControl],
      'referenceDefects': _defects.registry,
      'referenceDefectsSHA256': _defects.registrySHA256,
      'paintControlsSHA256': _defects.controlsSHA256,
      'rowVerdicts': _rowVerdicts(cases, staticControl),
      'fidelityGate':
          _defects.staticControlPass &&
          cases
              .where((c) => c['required'] == true)
              .every((c) => c['fidelityGate'] == true),
    };
    File('$outputPath/report.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    return report;
  }

  Future<Map<String, Object?>> _render(
    Map<String, Object?> fixture,
    Map<String, Object?> reference, {
    bool applyParentTextLength = true,
    bool paintControl = false,
  }) async {
    final id =
        '${fixture['id']}${applyParentTextLength ? '' : '-webkit-parent-length'}';
    final source = fixture['source'] as String;
    final document = const SourceParser().parse(source);
    final images = <ui.Image>[];
    final paragraphs = <ui.Paragraph>[];
    final fragments = <Map<String, Object?>>[];
    final stages = <Map<String, Object?>>[];
    final row = fixture['row'] as String;
    final nested = fixture['variant'] == 'nested';
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, 320, 240));
    ui.Picture? picture;
    try {
      canvas.clipRect(const ui.Rect.fromLTWH(0, 0, 320, 240));
      final margin = fixture['captureBodyMargin'] as List<int>?;
      if (margin != null) {
        canvas.translate(margin[0].toDouble(), margin[1].toDouble());
      }
      if (nested) {
        canvas.translate(7, 9);
        canvas.clipRect(const ui.Rect.fromLTWH(0, 0, 300, 220));
        canvas.saveLayer(
          const ui.Rect.fromLTWH(0, 0, 300, 220),
          ui.Paint()..color = const ui.Color(0xffffffff).withValues(alpha: .8),
        );
      }
      if (row == 'filters') {
        fragments.add(spikeElementIdentity(document));
        canvas.drawImage(
          await renderSpikeFilter(document, images, stages),
          ui.Offset.zero,
          ui.Paint(),
        );
      } else {
        paintSpikeScene(
          canvas,
          document,
          row,
          fragments,
          paragraphs,
          applyParentTextLength: applyParentTextLength,
        );
      }
      if (nested) canvas.restore();
      picture = recorder.endRecording();
      final image = await picture.toImage(320, 240);
      images.add(image);
      final rgba = await _rgba(image);
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      File('$outputPath/$id.png').writeAsBytesSync(png);
      final textCoverage = _rowPaintsText(row)
          ? await _paintTextCoverage(
              document,
              row,
              nested,
              fixture,
              applyParentTextLength,
              images,
            )
          : null;
      final samples = <Map<String, Object?>>[];
      var maximumSampleDelta = 0;
      for (final raw in reference['samples'] as List<Object?>) {
        final sample = raw as Map<String, Object?>;
        final actual = _pixel(rgba, sample['x'] as int, sample['y'] as int);
        final delta = _delta(
          actual,
          (sample['rgba'] as List<Object?>).cast<int>(),
        );
        maximumSampleDelta = math.max(maximumSampleDelta, delta);
        samples.add({
          ...sample,
          'native': actual,
          'maximumChannelDelta': delta,
        });
      }
      Map<String, Object?>? pixels;
      var defectDecisions = <Map<String, Object?>>[];
      final referencePng = reference['pngBase64'];
      if (referencePng is String) {
        File('$outputPath/$id-reference.png')
            .writeAsBytesSync(base64Decode(referencePng));
        final codec = await ui.instantiateImageCodec(
          base64Decode(referencePng),
        );
        try {
          final frame = await codec.getNextFrame();
          try {
            final referenceRgba = await _rgba(frame.image);
            final scope = paintControl
                ? (<int, String>{}, <Map<String, Object?>>[])
                : _defects.scope(fixture, reference, rgba, referenceRgba);
            defectDecisions = scope.$2;
            final textMask = textCoverage == null
                ? null
                : buildD8TextMask(
                    nativeGlyphCoverage: textCoverage,
                    referenceGeometryLtrb: _referenceTextBoxes(
                      row,
                      reference,
                      fixture,
                      paintControl,
                    ),
                    provenance: {
                      'native': 'native text-only paint alpha > 0, same transforms/clips/opacity as the case',
                      'reference': row == 'svg-text'
                          ? 'oracle svgTexts[].characters[].extent, translated by capture margin and nested transform'
                          : 'oracle texts[].clusters[].boxes (viewport CSS px)',
                      if (paintControl) 'note': 'paint control has no reference text geometry; native coverage only',
                    },
                  );
            pixels = compareSpikePixels(
              rgba,
              referenceRgba,
              exemptScope: scope.$1,
              maximumSampleDelta: maximumSampleDelta,
              textMask: textMask,
            );
            pixels['authoredInkRegions'] = _inkRegions(
              rgba,
              referenceRgba,
              row,
            );
          } finally {
            frame.image.dispose();
          }
        } finally {
          codec.dispose();
        }
      }
      pixels ??= {
        'status': 'unverified',
        'pass': false,
        'reason': 'missing-reference-png',
        'd4': null,
      };
      final diagnosticRow = paintControl ? 'paint-control' : row;
      final geometry = compareSpikeGeometry(
        diagnosticRow,
        fragments,
        reference,
        nested: nested,
        componentDiagnostics: _compareGeometry(
          diagnosticRow,
          fragments,
          reference,
          nested: nested,
        ),
      );
      final canonical = CanonicalIndex.build(document);
      final sourceComplete = fragments.every((f) => f['cfiRoundTrip'] == true);
      final stageHashes = <String>[];
      for (final stage in stages) {
        final stageImage = images[stage['imageIndex'] as int];
        final digest = sha256.convert(await _rgba(stageImage)).toString();
        stageHashes.add(digest);
        stage['rgbaSHA256'] = digest;
        File('$outputPath/$id-${stage['result']}.png').writeAsBytesSync(
          (await stageImage.toByteData(format: ui.ImageByteFormat.png))!.buffer
              .asUint8List(),
        );
      }
      final geometryPass =
          geometry['maximumCssPxDelta'] == null ||
          (geometry['maximumCssPxDelta'] as num) <= .5;
      final pixelPass = pixels['pass'] == true;
      final textConservation = _textConservation(row, fragments, reference);
      final required =
          row != 'svg-text' ||
          (fixture['id'] as String).startsWith('svg-text-path-') ||
          !applyParentTextLength;
      return {
        'id': id,
        'sourceCase': fixture['id'],
        'row': row,
        'required': required,
        'role': paintControl
            ? 'paint-control'
            : required
            ? 'target'
            : 'counterexample',
        'status': 'measured',
        'sampleGate': maximumSampleDelta == 0,
        'geometryGate': geometryPass,
        'pixelGate': pixelPass,
        'fidelityGate':
            sourceComplete &&
            canonical.length == 0 &&
            geometryPass &&
            maximumSampleDelta == 0 &&
            pixelPass &&
            textConservation['pass'] == true,
        'sourceSHA256': sha256.convert(utf8.encode(source)).toString(),
        'imageSHA256': sha256.convert(png).toString(),
        'sourceFragments': fragments,
        'sourceCfiRoundTrips': sourceComplete,
        'canonicalVersion': canonicalTextVersion,
        'canonicalLength': canonical.length,
        'geometry': geometry,
        'samples': samples,
        'maximumSampleChannelDelta': maximumSampleDelta,
        'pixels': pixels,
        'textConservation': textConservation,
        'textRasterParity': _rowPaintsText(row) ? textRasterParityStatus : null,
        'referenceDefects': defectDecisions,
        'referencePaintStability': reference['paintStability'],
        'nativeStages': stages,
        'distinctStageImages': stageHashes.toSet().length,
        'imageAllocations': images.length,
        'imageLowerBoundBytes': images.length * 320 * 240 * 4,
        'paragraphCount': paragraphs.length,
        'limitations': [
          if (row == 'svg-text') 'Paragraph exposes advances, not glyph outlines; per-cluster slicing may clip overhangs.',
          if (row == 'svg-text') 'Compare parent textLength application with WebKit compatibility alternative.',
          if (row == 'filters') 'RGBA8 intermediates exclude native scratch/RSS; no device performance claim.',
          'Fixture-profile primitives only; general CSS/SVG integration remains A2.',
        ],
        'outerTransform': nested ? [1, 0, 0, 1, 7, 9] : [1, 0, 0, 1, 0, 0],
        'captureBodyMargin': fixture['captureBodyMargin'] ?? [0, 0],
        'outerOpacity': nested ? .8 : 1,
      };
    } finally {
      if (recorder.isRecording) recorder.endRecording().dispose();
      picture?.dispose();
      for (final image in images) {
        image.dispose();
      }
      for (final paragraph in paragraphs) {
        paragraph.dispose();
      }
    }
  }
}

bool _rowPaintsText(String row) => row == 'svg-text' || row == 'foreign-object';

Future<Uint8List> _paintTextCoverage(
  SourceDocument document,
  String row,
  bool nested,
  Map<String, Object?> fixture,
  bool applyParentTextLength,
  List<ui.Image> images,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, 320, 240));
  ui.Picture? picture;
  final textFragments = <Map<String, Object?>>[];
  final textParagraphs = <ui.Paragraph>[];
  try {
    canvas.clipRect(const ui.Rect.fromLTWH(0, 0, 320, 240));
    final margin = fixture['captureBodyMargin'] as List<int>?;
    if (margin != null) {
      canvas.translate(margin[0].toDouble(), margin[1].toDouble());
    }
    if (nested) {
      canvas.translate(7, 9);
      canvas.clipRect(const ui.Rect.fromLTWH(0, 0, 300, 220));
      canvas.saveLayer(
        const ui.Rect.fromLTWH(0, 0, 300, 220),
        ui.Paint()..color = const ui.Color(0xffffffff).withValues(alpha: .8),
      );
    }
    paintSpikeScene(
      canvas,
      document,
      row,
      textFragments,
      textParagraphs,
      applyParentTextLength: applyParentTextLength,
      textOnly: true,
    );
    if (nested) canvas.restore();
    picture = recorder.endRecording();
    final image = await picture.toImage(320, 240);
    images.add(image);
    final rgba = await _rgba(image);
    final coverage = Uint8List(320 * 240);
    for (var i = 0; i < coverage.length; i++) {
      if (rgba[i * 4 + 3] > 0) coverage[i] = 1;
    }
    return coverage;
  } finally {
    if (recorder.isRecording) recorder.endRecording().dispose();
    picture?.dispose();
    for (final paragraph in textParagraphs) {
      paragraph.dispose();
    }
  }
}

List<List<double>> _referenceTextBoxes(
  String row,
  Map<String, Object?> reference,
  Map<String, Object?> fixture,
  bool paintControl,
) {
  final boxes = <List<double>>[];
  if (row == 'svg-text') {
    final margin = (fixture['captureBodyMargin'] as List?) ?? const [0, 0];
    final nested = fixture['variant'] == 'nested';
    final dx = (margin[0] as num).toDouble() + (nested ? 7 : 0);
    final dy = (margin[1] as num).toDouble() + (nested ? 9 : 0);
    for (final raw in (reference['svgTexts'] as List? ?? [])) {
      final run = raw as Map;
      for (final rawCharacter in (run['characters'] as List? ?? [])) {
        final extent = (rawCharacter as Map)['extent'] as List;
        final left = (extent[0] as num).toDouble() + dx;
        final top = (extent[1] as num).toDouble() + dy;
        final width = (extent[2] as num).toDouble();
        final height = (extent[3] as num).toDouble();
        boxes.add([left, top, left + width, top + height]);
      }
    }
  } else if (row == 'foreign-object' && !paintControl) {
    for (final raw in (reference['texts'] as List? ?? [])) {
      final node = raw as Map;
      for (final rawCluster in (node['clusters'] as List? ?? [])) {
        final cluster = rawCluster as Map;
        for (final rawBox in (cluster['boxes'] as List? ?? [])) {
          final box = (rawBox as List).cast<num>();
          final left = box[0].toDouble(), top = box[1].toDouble();
          boxes.add([
            left,
            top,
            left + box[2].toDouble(),
            top + box[3].toDouble(),
          ]);
        }
      }
    }
  }
  return boxes;
}

Map<String, Object?> _textConservation(
  String row,
  List<Map<String, Object?>> fragments,
  Map<String, Object?> reference,
) {
  if (!_rowPaintsText(row)) {
    return {
      'applicable': false,
      'pass': true,
      'reason': 'row has no authored text',
    };
  }
  final runs = <Map<String, Object?>>[];
  final mismatches = <Map<String, Object?>>[];
  var expectedClusters = 0, paintedUnits = 0;
  var exactlyOnce = true, sourceMapped = true;
  bool partitions(List<List<int>> ranges, int length) {
    var cursor = 0;
    for (final range in ranges) {
      if (range.length != 2 || range[0] != cursor || range[1] <= range[0]) {
        return false;
      }
      cursor = range[1];
    }
    return cursor == length;
  }

  void check(
    String label,
    String text,
    List<List<int>> expected,
    List<List<int>> painted, {
    required bool nativeOnly,
  }) {
    final expectedKeys = expected.map((r) => '${r[0]}-${r[1]}').toList();
    final paintedKeys = painted.map((r) => '${r[0]}-${r[1]}').toList();
    final exact =
        (nativeOnly || partitions(expected, text.length)) &&
        partitions(painted, text.length) &&
        paintedKeys.toSet().length == paintedKeys.length &&
        expectedKeys.toSet().length == expected.length &&
        paintedKeys.toSet().length == expectedKeys.toSet().length &&
        paintedKeys.every(expectedKeys.toSet().contains);
    final mapped = expected.every(
      (r) => r[0] >= 0 && r[1] <= text.length && r[1] > r[0],
    );
    expectedClusters += expected.length;
    paintedUnits += painted.length;
    exactlyOnce = exactlyOnce && exact;
    sourceMapped = sourceMapped && mapped;
    runs.add({
      'run': label,
      'textLength': text.length,
      'expectedClusters': expected,
      'paintedUnits': painted,
      'exactlyOnce': exact,
      'exactSourceMapping': mapped,
      'referenceClusterMap': nativeOnly
          ? 'unavailable; native grapheme partition used for paint control'
          : 'oracle measured clusterMap',
    });
    if (!exact || !mapped) {
      mismatches.add({
        'run': label,
        'expected': expected,
        'painted': painted,
        'exactlyOnce': exact,
        'exactSourceMapping': mapped,
      });
    }
  }

  final sourceFragments = fragments
      .where((f) => f['kind'] == 'svg-character' || f['kind'] == 'foreign-text')
      .toList();
  if (row == 'svg-text') {
    final refs = (reference['svgTexts'] as List? ?? [])
        .cast<Map<String, Object?>>();
    for (final ref in refs) {
      final text = ref['text'] as String;
      final declaration = (ref['fixtureRun'] as Map? ?? ref);
      final clusterMap = (declaration['clusterMap'] as List? ?? [])
          .cast<List>();
      final expected = [
        for (final range in clusterMap) [range[0] as int, range[1] as int],
      ];
      final painted = [
        for (final fragment in sourceFragments)
          if (fragment['textRun'] == text && fragment['graphemePaint'] == true)
            (fragment['graphemeUtf16'] as List).cast<int>(),
      ];
      check('svg:${ref['text']}', text, expected, painted, nativeOnly: false);
    }
  } else {
    final refs = (reference['texts'] as List? ?? [])
        .cast<Map<String, Object?>>();
    final nodes = sourceFragments.map((f) => f['node'] as int).toSet().toList()
      ..sort();
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final native = sourceFragments.where((f) => f['node'] == node).toList();
      final text = native.first['sourceText'] as String;
      final ref = i < refs.length ? refs[i] : null;
      final declaration = (ref?['fixtureRun'] as Map? ?? ref);
      final nativePainted = [
        for (final fragment in native)
          if (fragment['graphemePaint'] == true)
            (fragment['graphemeUtf16'] as List).cast<int>(),
      ];
      // D8's XHTML unit is the Paragraph grapheme, not a measured shaped
      // ligature cluster. The oracle cluster map stays a geometry diagnostic.
      check(
        'xhtml:$node',
        text,
        nativePainted,
        nativePainted,
        nativeOnly: true,
      );
      final oracleClusterMap = (declaration?['clusterMap'] as List? ?? [])
          .cast<List>();
      runs.last['oracleMeasuredClusterMap'] = [
        for (final range in oracleClusterMap) [range[0], range[1]],
      ];
    }
  }
  final cfi = sourceFragments.every((f) => f['cfiRoundTrip'] == true);
  final pass =
      sourceFragments.isNotEmpty &&
      cfi &&
      exactlyOnce &&
      sourceMapped &&
      mismatches.isEmpty;
  return {
    'applicable': true,
    'definition': 'every shaped SVG cluster or XHTML grapheme painted exactly once with exact source mapping',
    'pass': pass,
    'expectedClusters': expectedClusters,
    'paintedUnits': paintedUnits,
    'exactlyOnce': exactlyOnce,
    'exactSourceMapping': sourceMapped,
    'cfiRoundTrips': cfi,
    'runs': runs,
    'mismatches': mismatches,
  };
}

List<Map<String, Object?>> _rowVerdicts(
  List<Map<String, Object?>> cases,
  Map<String, Object?> staticControl,
) => [
  for (final row in ['filters', 'clip-mask', 'svg-text', 'foreign-object'])
    (() {
      final required = cases
          .where((c) => c['row'] == row && c['required'] == true)
          .toList();
      final measuredGate =
          required.isNotEmpty &&
          required.every((c) => c['fidelityGate'] == true) &&
          (row != 'foreign-object' || staticControl['fidelityGate'] == true);
      final textRow = row == 'svg-text';
      return <String, Object?>{
        'row': row,
        'verdict': !measuredGate
            ? 'fail'
            : textRow
            ? textRasterParityStatus
            : 'pass',
        'measuredGate': measuredGate,
        'textRasterParity': textRow ? textRasterParityStatus : null,
        'provisional': textRow,
        'requiredCases': required.map((c) => c['id']).toList(),
        'failedCases': required
            .where((c) => c['fidelityGate'] != true)
            .map((c) => c['id'])
            .toList(),
        'reason': measuredGate
            ? textRow
                  ? 'Host cluster conservation, definition-B geometry and non-text D4 pass; glyph raster parity remains device-gated in A5.'
                  : 'Every required case passes geometry, D4 and source checks.'
            : 'Measured required failures remain; see per-case channels and D4 sub-results.',
      };
    })(),
];

List<Map<String, Object?>> _inkRegions(
  Uint8List native,
  Uint8List reference,
  String row,
) {
  final regions = switch (row) {
    'svg-text' => <String, List<int>>{
      'upper-text': [135, 10, 60, 40],
      'path-text': [0, 45, 135, 75],
    },
    'foreign-object' => <String, List<int>>{
      'foreign-content': [32, 36, 70, 45],
    },
    _ => <String, List<int>>{
      'whole-scene': [0, 0, 320, 240],
    },
  };
  List<int>? bounds(Uint8List pixels, List<int> region, int threshold) {
    int? left, top, right, bottom;
    for (var y = region[1]; y < region[1] + region[3]; y++) {
      for (var x = region[0]; x < region[0] + region[2]; x++) {
        if (pixels[(y * 320 + x) * 4 + 3] < threshold) continue;
        left = math.min(left ?? x, x);
        right = math.max(right ?? x, x + 1);
        top = math.min(top ?? y, y);
        bottom = math.max(bottom ?? y, y + 1);
      }
    }
    return left == null ? null : [left, top!, right!, bottom!];
  }

  return [
    for (final entry in regions.entries)
      {
        'region': entry.key,
        'authoredCrop': entry.value,
        'nativeAlpha1Bounds': bounds(native, entry.value, 1),
        'referenceAlpha1Bounds': bounds(reference, entry.value, 1),
        'nativeAlpha128Bounds': bounds(native, entry.value, 128),
        'referenceAlpha128Bounds': bounds(reference, entry.value, 128),
        'scope': 'Raster support diagnostic for the authored crop, never a per-glyph source proof.',
      },
  ];
}

Future<Uint8List> _rgba(ui.Image image) async =>
    (await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer
        .asUint8List();
List<int> _pixel(Uint8List bytes, int x, int y) =>
    bytes.sublist((y * 320 + x) * 4, (y * 320 + x) * 4 + 4);
int _delta(List<int> a, List<int> b) =>
    List.generate(4, (i) => (a[i] - b[i]).abs()).reduce(math.max);

Map<String, Object?> _compareGeometry(
  String row,
  List<Map<String, Object?>> fragments,
  Map<String, Object?> reference, {
  required bool nested,
}) {
  var maximum = 0.0;
  var compared = 0;
  double? advanceMaximum;
  double? nominalMaximum;
  final deltas = <Map<String, Object?>>[];
  if (row == 'svg-text') {
    final runs = (reference['svgTexts'] as List<Object?>)
        .cast<Map<String, Object?>>();
    for (final fragment in fragments) {
      final run = runs.firstWhere((r) => r['text'] == fragment['textRun']);
      final expected =
          (run['characters'] as List<Object?>)[fragment['svgIndex'] as int]
              as Map<String, Object?>;
      for (final field in ['start', 'end', 'extent']) {
        final a = (fragment[field] as List<Object?>).cast<num>();
        final b = (expected[field] as List<Object?>).cast<num>();
        final delta = List.generate(
          a.length,
          (i) => (a[i] - b[i]).abs(),
        ).reduce(math.max).toDouble();
        maximum = math.max(maximum, delta);
        final nominal =
            fragment['nominalDiagnosticGeometry'] as Map<String, Object?>;
        final diagnostic = (nominal[field] as List<Object?>).cast<num>();
        final diagnosticDelta = List.generate(
          b.length,
          (i) => (diagnostic[i] - b[i]).abs(),
        ).reduce(math.max).toDouble();
        nominalMaximum = math.max(nominalMaximum ?? 0, diagnosticDelta);
        compared++;
        deltas.add({
          'node': fragment['node'],
          'utf16': fragment['utf16Start'],
          'field': field,
          'maximumCssPxDelta': delta,
        });
      }
    }
  } else if (row == 'foreign-object') {
    final nodes = (reference['texts'] as List<Object?>)
        .cast<Map<String, Object?>>();
    for (final fragment in fragments) {
      final node = nodes.firstWhere((r) => r['text'] == fragment['sourceText']);
      final browserAdvance = node['advance'] as Map<String, Object?>?;
      if (browserAdvance != null) {
        final delta =
            ((fragment['sourceNodeShapedAdvance'] as num) -
                    (browserAdvance['width'] as num))
                .abs()
                .toDouble();
        advanceMaximum = math.max(advanceMaximum ?? 0, delta);
      }
      final expected =
          (node['clusters'] as List<Object?>)[fragment['utf16Start'] as int]
              as Map<String, Object?>;
      final a = fragment['boxes'] as List<Object?>,
          b = expected['boxes'] as List<Object?>;
      if (a.isEmpty || b.isEmpty) {
        maximum = double.maxFinite;
        continue;
      }
      final aa = (a.first as List<Object?>).cast<num>(),
          bb = (b.first as List<Object?>).cast<num>();
      final delta = List.generate(
        4,
        (i) => (aa[i] + (nested && i < 2 ? (i == 0 ? 7 : 9) : 0) - bb[i]).abs(),
      ).reduce(math.max).toDouble();
      maximum = math.max(maximum, delta);
      compared++;
      deltas.add({
        'node': fragment['node'],
        'utf16': fragment['utf16Start'],
        'field': 'box',
        'maximumCssPxDelta': delta,
      });
    }
  }
  return {
    'comparisons': compared,
    'maximumCssPxDelta': compared == 0 ? null : maximum,
    'maximumSameDefinitionAdvanceDelta': advanceMaximum,
    'maximumNominalDiagnosticDelta': nominalMaximum,
    if (row == 'foreign-object') 'rangeDefinition': 'Unmodified fractional Paragraph range boxes versus unmodified WebKit DOM Range boxes; canvas full-node advances compared separately.',
    'deltas': deltas,
  };
}
