// Host experiment only. Test exit status is never the svg-text row verdict.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';

import 'fixed_layout_spike_defects.dart';
import 'fixed_layout_spike_geometry.dart';
import 'fixed_layout_spike_pixels.dart';
import 'harfbuzz_probe_ffi.dart';
import 'harfbuzz_probe_gates.dart';
import 'harfbuzz_probe_inputs.dart';
import 'harfbuzz_probe_scene.dart';
import 'harfbuzz_probe_shape.dart';

const harfBuzzProbeOutput = 'build/harfbuzz-probe';

Future<Map<String, Object?>> runHarfBuzzProbe() async {
  Map<String, Object?> read(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
  final manifest = read('tool/reader/harfbuzz_probe_manifest.json');
  final corpus = read('test/fixtures/reader/fixed_layout/corpus.json');
  final oracle = read('test/fixtures/reader/fixed_layout/oracle.json');
  final inputHashes = {
    'corpus': svgTextContentHash(corpus),
    'oracle': svgTextContentHash(oracle),
  };
  final font = corpus['font'] as Map<String, Object?>;
  final fontBytes = File(font['path'] as String).readAsBytesSync();
  void verify(String path, String hash) {
    if (sha256.convert(File(path).readAsBytesSync()).toString() != hash) {
      throw StateError('Pinned input mismatch: $path');
    }
  }

  verify(harfBuzzProbeLibrary, manifest['librarySHA256'] as String);
  for (final entry in (manifest['dependenciesInLoadOrder'] as Map).entries) {
    verify('$harfBuzzProbeDirectory/${entry.key}', entry.value as String);
  }
  if (!_same(inputHashes, manifest['svgTextContentSHA256'])) {
    throw StateError('Pinned SVG text measured content changed');
  }
  final zip =
      'build/third_party/harfbuzz-14.6.0/download/${manifest['archive']}';
  verify(zip, manifest['archiveSHA256'] as String);
  if (File(zip).lengthSync() != manifest['archiveBytes']) {
    throw StateError('Archive size mismatch');
  }
  verify(font['path'] as String, font['sha256'] as String);
  if (font['sha256'] != manifest['fontSHA256']) {
    throw StateError('Font pin mismatch');
  }
  final ledger = HbLedger();
  final shaper = HbShaper(HbApi(), ledger, fontBytes);
  final defects = SpikeReferenceDefects(oracle);
  final cases = <Map<String, Object?>>[];
  final shaping = <Map<String, Object?>>[];
  final featureComparisons = <Map<String, Object?>>[];
  final rasterComparisons = <Map<String, Object?>>[];
  final gdiDiagnostics = <Map<String, Object?>>[];
  Future<void> renderRequired(
    Map<String, Object?> fixture,
    Map<String, Object?> reference,
  ) async {
    // D8 verdict route: unhinted HarfBuzz outlines from hb_font_draw_glyph.
    cases.add(
      await _render({...fixture, 'gridFit': false}, reference, shaper, defects),
    );
    rasterComparisons.add(
      await _render(
        {
          ...fixture,
          'id': '${fixture['id']}-unhinted-fragments',
          'referenceCaseId': fixture['id'],
          'gridFit': false,
        },
        reference,
        shaper,
        defects,
      ),
    );
    // Windows GDI transform-aware grid fitting stays a labelled diagnostic and
    // never supplies the row verdict.
    gdiDiagnostics.add(
      await _render(
        {
          ...fixture,
          'id': '${fixture['id']}-gdi-diagnostic',
          'referenceCaseId': fixture['id'],
          'gridFit': true,
        },
        reference,
        shaper,
        defects,
      ),
    );
  }

  Map<String, Object?>? outlineControl;
  Directory(harfBuzzProbeOutput).createSync(recursive: true);
  final version = shaper.version;
  try {
    if (version != manifest['version']) {
      throw StateError('HB runtime version mismatch');
    }
    if (sizeOfHbMismatch()) throw StateError('Unexpected C struct ABI');
    await ui.loadFontFromList(fontBytes, fontFamily: 'HarfBuzzProbeRoboto');
    await defects.load();
    final positive = (oracle['cases'] as List)
        .cast<Map<String, Object?>>()
        .firstWhere((c) => c['id'] == 'svg-text-positive');
    for (final ref
        in (positive['svgTexts'] as List).cast<Map<String, Object?>>()) {
      final run = shaper.shape(ref['text'] as String);
      try {
        final paragraphWidth = _paragraphWidth(run.text);
        shaping.add({
          ...run.json(),
          'nativeParagraphWidth': paragraphWidth,
          'webkitComputedTextLength': ref['computedTextLength'],
          'paragraphAdvanceDelta': (run.width - paragraphWidth).abs(),
          'webkitAdvanceDelta': (run.width - (ref['computedTextLength'] as num))
              .abs(),
          'fixtureClustersConfirmed': _same(
            run.clusterMap,
            (ref['fixtureRun'] as Map)['clusterMap'],
          ),
          'paragraphGlyphIDs':
              'not exposed by public dart:ui; width equality only',
        });
      } finally {
        run.close();
      }
    }
    for (final fixture
        in (corpus['cases'] as List).cast<Map<String, Object?>>().where(
          (c) =>
              c['row'] == 'svg-text' &&
              c['expectedCapability'] != 'unsupported',
        )) {
      final reference = (oracle['cases'] as List)
          .cast<Map<String, Object?>>()
          .firstWhere((r) => r['id'] == fixture['id']);
      await renderRequired(fixture, reference);
      if (fixture['id'] == 'svg-text-positive') {
        featureComparisons.add(
          await _render(
            {
              ...fixture,
              'id': '${fixture['id']}-liga-off',
              'referenceCaseId': fixture['id'],
              'ligatures': false,
              'fragmentPainting': false,
            },
            reference,
            shaper,
            defects,
          ),
        );
        featureComparisons.add(
          await _render(
            {
              ...fixture,
              'id': '${fixture['id']}-component-metrics',
              'referenceCaseId': fixture['id'],
              'ligatures': false,
              'componentMetrics': true,
              'fragmentPainting': false,
            },
            reference,
            shaper,
            defects,
          ),
        );
      }
    }
    for (final probe
        in (oracle['svgTextProbes'] as List).cast<Map<String, Object?>>()) {
      final fixture = <String, Object?>{
        'id': 'svg-text-path-${probe['adjustment']}',
        'source': probe['source'],
        'variant': 'positive',
        'captureHostMediaType': 'application/xhtml+xml',
        'captureBodyMargin': [8, 8],
      };
      final reference = <String, Object?>{
        'svgTexts': [probe],
        'pngBase64': probe['pngBase64'],
        'paintStability': probe['paintStability'],
        'samples': <Object?>[],
      };
      await renderRequired(fixture, reference);
      for (final ligatures in [true, false]) {
        featureComparisons.add(
          await _render(
            {
              ...fixture,
              'id': '${fixture['id']}-liga-${ligatures ? 'on' : 'off'}',
              'referenceCaseId': fixture['id'],
              'ligatures': ligatures,
              'fragmentPainting': false,
            },
            reference,
            shaper,
            defects,
          ),
        );
      }
      featureComparisons.add(
        await _render(
          {
            ...fixture,
            'id': '${fixture['id']}-component-metrics',
            'referenceCaseId': fixture['id'],
            'ligatures': false,
            'componentMetrics': true,
            'fragmentPainting': false,
          },
          reference,
          shaper,
          defects,
        ),
      );
    }
    outlineControl = await _render(
      {
        'id': 'overhang-straight-and-quadratic',
        'variant': 'positive',
        'fragmentPainting': false,
        'source':
            '<svg xmlns="http://www.w3.org/2000/svg"><defs><path id="p" d="M20 100 Q160 10 290 120"/></defs>'
            '<text x="30" y="40">f\u0301</text><text><textPath href="#p" startOffset="5%">f\u0301</textPath></text></svg>',
      },
      {'samples': <Object?>[]},
      shaper,
      defects,
    );
  } finally {
    shaper.close();
  }
  final pass =
      cases.length == 6 && cases.every((c) => c['fidelityGate'] == true);
  final passB =
      cases.length == 6 && cases.every((c) => c['fidelityGateB'] == true);
  final hostD8Pass = passB;
  final rowVerdict = hostD8Pass ? textRasterParityStatus : 'fail';
  final endHashes = currentSvgTextContentHashes();
  if (!_same(inputHashes, endHashes)) {
    throw StateError('SVG text measured content changed during probe; stop');
  }
  final report = <String, Object?>{
    'schemaVersion': 1,
    'host': Platform.operatingSystem,
    'dart': Platform.version,
    'evidence': 'Windows Flutter test engine; no device/performance acceptance',
    'manifest': manifest,
    'svgTextContentHashes': {
      'start': inputHashes,
      'end': endHashes,
      'unchanged': true,
    },
    'contentHashPolicy':
        'recursive sorted-key JSON; SVG text cases and probes; exclude clusterSource, '
        'clusterConfirmation and evidence/provenance fields; include PNGs and measurements',
    'runtimeVersion': version,
    'font': font,
    'fontUpem': shaper.upem,
    'corpusSHA256': sha256
        .convert(
          File('test/fixtures/reader/fixed_layout/corpus.json')
              .readAsBytesSync(),
        )
        .toString(),
    'oracleSHA256': sha256
        .convert(
          File('test/fixtures/reader/fixed_layout/oracle.json')
              .readAsBytesSync(),
        )
        .toString(),
    'helperSHA256': {
      for (final n in ['geometry', 'pixels', 'defects'])
        n: sha256
            .convert(
              File('tool/reader/fixed_layout_spike_$n.dart').readAsBytesSync(),
            )
            .toString(),
    },
    'probeSHA256': {
      for (final n in [
        '',
        '_ffi',
        '_draw',
        '_shape',
        '_scene',
        '_gates',
        '_inputs',
        '_path',
        '_gridfit',
        '_gridfit_path',
      ])
        'harfbuzz_probe$n.dart': sha256
            .convert(
              File('tool/reader/harfbuzz_probe$n.dart').readAsBytesSync(),
            )
            .toString(),
    },
    'referenceDefectsSHA256': defects.registrySHA256,
    'paintControlsSHA256': defects.controlsSHA256,
    'direction': 'ltr',
    'script': 'Latn',
    'language': 'en',
    'clusterLevel': 'MONOTONE_GRAPHEMES',
    'features': 'default layout shaping; liga=0 component-fragment painting',
    'paintedUnit':
        'component-fragment; base plus combining continuation stays shaped',
    'scale': 'upem/upem in HB; CSS factor 20/upem, inverted y for Path',
    'dllDependencyResolution': 'absolute preload libintl-8.dll, libglib-2.0-0.dll, then HB; no PATH mutation',
    'shaping': shaping,
    'cases': cases,
    'featureComparisons': featureComparisons,
    'rasterComparisons': rasterComparisons,
    'gdiDiagnostics': gdiDiagnostics,
    'verdictRoute': 'unhinted hb_font_draw_glyph outlines',
    'rasterRuleStatus':
        'D8: glyph pixels excluded from the component sub-rule; '
        'glyph presence is gated by cluster conservation and 0.5 px geometry',
    'outlineBackend':
        'HarfBuzz hb_font_draw_glyph unhinted outlines for the verdict; '
        'Windows GDI GetGlyphOutlineW transform-aware grid fit is diagnostic only',
    'gdiDiagnosticOnly':
        'gdiDiagnostics never enter svgTextRowVerdict or fidelityGate',
    'rasterBackendSystemVersion': Platform.operatingSystemVersion,
    'rasterBackendAcceptance':
        cases.length == 6 && cases.every((c) => c['pixelGate'] == true)
        ? 'D8 host pixel gate; text raster parity device-gated (A5)'
        : 'unaccepted: required D8 pixel failure',
    'gdiOpaqueNativeBytes':
        'unmeasured: system font admission and grid-fitting allocations',
    'outlineControl': outlineControl,
    'geometryToleranceCssPx': .5,
    'clusterProvenance': 'shaped',
    'resources': ledger.snapshot(),
    'engineRegistration': {
      'faces': 1,
      'bytes': fontBytes.length,
      'lifetime': 'process; ui.loadFontFromList has no unload API',
    },
    'adoptedGateDefinition': 'B',
    'textRasterParity': textRasterParityStatus,
    'svgTextRowVerdict': rowVerdict,
    'svgTextRowVerdictA': pass ? 'pass' : 'fail',
    'svgTextRowVerdictB': passB ? 'pass' : 'fail',
    'hostD8Gate': hostD8Pass,
    'fidelityGate': hostD8Pass,
    'hostFidelityGate': hostD8Pass,
  };
  File('$harfBuzzProbeOutput/report.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  return report;
}

Uint8List _textCoverage(Uint8List rgba) {
  final coverage = Uint8List(320 * 240);
  for (var i = 0; i < coverage.length; i++) {
    if (rgba[i * 4 + 3] > 0) coverage[i] = 1;
  }
  return coverage;
}

List<List<double>> _referenceTextBoxes(
  Map<String, Object?> fixture,
  Map<String, Object?> reference,
) {
  final margin = (fixture['captureBodyMargin'] as List?) ?? const [0, 0];
  final nested = fixture['variant'] == 'nested';
  final dx = (margin[0] as num).toDouble() + (nested ? 7 : 0);
  final dy = (margin[1] as num).toDouble() + (nested ? 9 : 0);
  return [
    for (final rawRun in (reference['svgTexts'] as List? ?? []))
      for (final rawCharacter in ((rawRun as Map)['characters'] as List? ?? []))
        () {
          final extent = ((rawCharacter as Map)['extent'] as List).cast<num>();
          final left = extent[0].toDouble() + dx;
          final top = extent[1].toDouble() + dy;
          return [
            left,
            top,
            left + extent[2].toDouble(),
            top + extent[3].toDouble(),
          ];
        }(),
  ];
}

bool _same(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);

double _paragraphWidth(String text) {
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            fontFamily: 'HarfBuzzProbeRoboto',
            fontSize: 20,
            textDirection: ui.TextDirection.ltr,
          ),
        )
        ..pushStyle(
          ui.TextStyle(fontFamily: 'HarfBuzzProbeRoboto', fontSize: 20),
        )
        ..addText(text);
  final paragraph = builder.build()
    ..layout(const ui.ParagraphConstraints(width: 10000));
  try {
    return paragraph.longestLine;
  } finally {
    paragraph.dispose();
  }
}

Future<Map<String, Object?>> _render(
  Map<String, Object?> fixture,
  Map<String, Object?> reference,
  HbShaper shaper,
  SpikeReferenceDefects defects,
) async {
  final scene = HbScene();
  final nested = fixture['variant'] == 'nested';
  final document = const SourceParser().parse(fixture['source'] as String);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  ui.Picture? picture;
  ui.Image? image;
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
    scene.paint(
      canvas,
      document,
      shaper,
      ligatures: fixture['ligatures'] as bool?,
      componentMetrics: fixture['componentMetrics'] == true,
      fragmentPainting: fixture['fragmentPainting'] != false,
      gridFit: fixture['gridFit'] != false,
    );
    if (nested) canvas.restore();
    picture = recorder.endRecording();
    image = await picture.toImage(320, 240);
    final actual = (await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    ))!.buffer.asUint8List();
    final id = fixture['id'] as String;
    File('$harfBuzzProbeOutput/$id.png').writeAsBytesSync(
      (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
          .asUint8List(),
    );
    final samples = <Map<String, Object?>>[];
    var maxSample = 0;
    for (final sample
        in (reference['samples'] as List? ?? []).cast<Map<String, Object?>>()) {
      final i = ((sample['y'] as int) * 320 + (sample['x'] as int)) * 4;
      final native = actual.sublist(i, i + 4);
      final expected = (sample['rgba'] as List).cast<int>();
      final delta = List.generate(
        4,
        (j) => (native[j] - expected[j]).abs(),
      ).reduce(math.max);
      maxSample = math.max(maxSample, delta);
      samples.add({...sample, 'native': native, 'maximumChannelDelta': delta});
    }
    var pixels = <String, Object?>{
      'pass': false,
      'status': 'unverified',
      'reason': 'missing-reference-png',
    };
    var decisions = <Map<String, Object?>>[];
    final png = reference['pngBase64'];
    if (png is String) {
      final bytes = base64Decode(png);
      File('$harfBuzzProbeOutput/$id-reference.png').writeAsBytesSync(bytes);
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        try {
          final expected = (await frame.image.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          ))!.buffer.asUint8List();
          final scope = defects.scope(
            {...fixture, 'id': fixture['referenceCaseId'] ?? fixture['id']},
            reference,
            actual,
            expected,
          );
          decisions = scope.$2;
          final textMask = (reference['svgTexts'] as List? ?? []).isEmpty
              ? null
              : buildD8TextMask(
                  nativeGlyphCoverage: _textCoverage(actual),
                  referenceGeometryLtrb: _referenceTextBoxes(
                    fixture,
                    reference,
                  ),
                  provenance: {
                    'native': 'native glyph paint alpha > 0 from the same HarfBuzz outline render',
                    'reference': 'oracle svgTexts[].characters[].extent, translated by capture margin and nested transform',
                    'paintPath': fixture['gridFit'] == false
                        ? 'unhinted hb_font_draw_glyph'
                        : 'GDI transform-aware diagnostic',
                  },
                );
          pixels = compareSpikePixels(
            actual,
            expected,
            exemptScope: scope.$1,
            maximumSampleDelta: maxSample,
            textMask: textMask,
          );
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    }
    final refs = (reference['svgTexts'] as List? ?? [])
        .cast<Map<String, Object?>>();
    final confirmations = <bool>[];
    final fixtureMapsMatch = <bool>[];
    final shapedReferences = <Map<String, Object?>>[];
    for (final ref in refs) {
      final declaration = (ref['fixtureRun'] ?? ref) as Map<String, Object?>;
      final run = scene.runs.singleWhere((r) => r.text == ref['text']);
      final matches = _same(run.clusterMap, declaration['clusterMap']);
      fixtureMapsMatch.add(matches);
      // liga=0 may refine a fixture-declared ligature into actual HB clusters.
      // Keep that disagreement explicit; compare the observed shaped ranges.
      final declared = (declaration['clusterMap'] as List).cast<List>();
      final confirmed =
          matches ||
          (!run.ligatures &&
              declared.every((range) {
                final inside = run.clusterMap
                    .where(
                      (c) =>
                          c[0] >= (range[0] as int) &&
                          c[1] <= (range[1] as int),
                    )
                    .toList();
                return inside.isNotEmpty &&
                    inside.first[0] == range[0] &&
                    inside.last[1] == range[1];
              }));
      confirmations.add(confirmed);
      shapedReferences.add({
        ...ref,
        'fixtureRun': {
          ...declaration,
          'clusterMap': run.clusterMap,
          'clusterSource': confirmed ? 'shaped' : 'fixture-declared',
        },
      });
    }
    final comparison = refs.isEmpty
        ? null
        : compareSpikeGeometry(
            'svg-text',
            scene.fragments,
            {...reference, 'svgTexts': shapedReferences},
            nested: nested,
            componentDiagnostics: {
              'definition': 'unit adapter carries complete cluster edges; no component slicing',
            },
          );
    final confirmed = confirmations.isNotEmpty && confirmations.every((c) => c);
    final geometry = comparison == null
        ? null
        : <String, Object?>{
            ...comparison,
            'sharedHelperProvisional': comparison['provisional'],
            'provisional': !confirmed,
            'clusterProvenance': 'shaped',
            'paintedUnit': fixture['fragmentPainting'] != false
                ? 'component-fragment'
                : 'shaping-cluster',
            'layoutClusterProvenance': 'default whole-run HarfBuzz shaping',
            'clusterConfirmation': confirmed
                ? 'HB paint clusters confirm or exactly refine every fixture layout cluster'
                : 'membership mismatch',
          };
    final glyphCount = scene.runs.fold<int>(0, (s, r) => s + r.glyphs.length);
    final utf16Count = scene.runs.fold<int>(0, (s, r) => s + r.text.length);
    final uniqueCoverage = scene.fragments
        .map((f) => '${f['node']}/${f['utf16Start']}')
        .toSet();
    final conservation =
        scene.emitted.length == glyphCount &&
        scene.emitted.toSet().length == glyphCount &&
        scene.fragments.length == utf16Count &&
        uniqueCoverage.length == utf16Count &&
        scene.fragments.every((f) => f['cfiRoundTrip'] == true);
    final expectedClusterCount = scene.runs.fold<int>(
      0,
      (sum, run) => sum + run.clusterMap.length,
    );
    final clusterRuns = <Map<String, Object?>>[];
    var exactlyOnce = scene.clusters.length == expectedClusterCount;
    var exactSourceMapping = true;
    for (var runIndex = 0; runIndex < scene.runs.length; runIndex++) {
      final run = scene.runs[runIndex];
      final expected = [
        for (final range in run.clusterMap) [range[0], range[1]],
      ];
      final painted = [
        for (final cluster in scene.clusters)
          if (cluster['runIndex'] == runIndex)
            (cluster['utf16'] as List).cast<int>(),
      ];
      final expectedKeys = expected.map((r) => '${r[0]}-${r[1]}').toList();
      final paintedKeys = painted.map((r) => '${r[0]}-${r[1]}').toList();
      var cursor = 0;
      var partition = true;
      for (final range in expected) {
        if (range[0] != cursor || range[1] <= range[0]) partition = false;
        cursor = range[1];
      }
      if (cursor != run.text.length) partition = false;
      final runExact =
          partition &&
          paintedKeys.toSet().length == paintedKeys.length &&
          expectedKeys.toSet().length == expected.length &&
          paintedKeys.toSet().length == expectedKeys.toSet().length &&
          paintedKeys.every(expectedKeys.toSet().contains);
      exactlyOnce = exactlyOnce && runExact;
      final mapped = scene.fragments
          .where(
            (f) =>
                f['textRun'] == run.text &&
                (expectedKeys.contains(
                  '${(f['clusterUtf16'] as List)[0]}-${(f['clusterUtf16'] as List)[1]}',
                )),
          )
          .every((f) => f['cfiRoundTrip'] == true);
      exactSourceMapping = exactSourceMapping && mapped;
      clusterRuns.add({
        'runIndex': runIndex,
        'textLength': run.text.length,
        'expectedClusters': expected,
        'paintedClusters': painted,
        'exactlyOnce': runExact,
        'exactSourceMapping': mapped,
      });
    }
    final clusterConservation = <String, Object?>{
      'definition': 'every shaped HarfBuzz cluster painted exactly once with exact source mapping',
      'pass':
          exactlyOnce &&
          exactSourceMapping &&
          expectedClusterCount > 0 &&
          scene.clusters.length == expectedClusterCount,
      'expectedClusters': expectedClusterCount,
      'paintedClusters': scene.clusters.length,
      'exactlyOnce': exactlyOnce,
      'exactSourceMapping': exactSourceMapping,
      'runs': clusterRuns,
    };
    final geometryPass =
        geometry != null &&
        confirmed &&
        (geometry['comparisons'] as int) > 0 &&
        (geometry['maximumCssPxDelta'] as num) <= .5;
    final gateB = comparison == null
        ? null
        : probeGateB(scene, refs, comparison);
    return {
      'id': id,
      'required': refs.isNotEmpty,
      'fixtureClustersConfirmed': confirmed,
      'fixtureClusterMapsMatch': fixtureMapsMatch,
      'runs': [for (final run in scene.runs) run.json()],
      'clusters': scene.clusters,
      'sourceFragments': scene.fragments,
      'geometry': geometry,
      'geometryB': gateB,
      'pixels': pixels,
      'textRasterParity': textRasterParityStatus,
      'samples': samples,
      'd3Decisions': decisions,
      'glyphEmissionCount': glyphCount,
      'emittedGlyphs': scene.emitted,
      'utf16Count': utf16Count,
      'sourceAndGlyphConservation': conservation,
      'clusterConservation': clusterConservation,
      'resourceSnapshotWhileRetained': shaper.ledger.snapshot(),
      'nativeSurfaceBytes': 320 * 240 * 4,
      'nativePictures': 1,
      'referenceImages': png is String ? 1 : 0,
      'geometryGate': geometryPass,
      'pixelGate': pixels['pass'],
      'fidelityGate':
          geometryPass &&
          pixels['pass'] == true &&
          conservation &&
          clusterConservation['pass'] == true,
      'fidelityGateB':
          confirmed &&
          gateB?['pass'] == true &&
          pixels['pass'] == true &&
          conservation &&
          clusterConservation['pass'] == true,
    };
  } finally {
    image?.dispose();
    if (recorder.isRecording) recorder.endRecording().dispose();
    picture?.dispose();
    scene.close();
  }
}
