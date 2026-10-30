import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:shiori/features/reader/data/geometry/source_fragment.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/resources/archive_reader_resource_source.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene_admission.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_section_preparer.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_preparation_scale.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';

import 'fixed_layout_scene_input.dart';
import 'fixed_layout_spike_defects.dart';
import 'fixed_layout_spike_pixels.dart';
import 'fixed_layout_svg_samples.dart';

/// Runs only production preparation. Oracle metrics are consumed exclusively
/// by the comparisons after preparation; they never supply placement data.
final class FixedLayoutSvgTextHarness {
  Future<Map<String, Object?>> run() async {
    const folder = 'test/fixtures/reader/fixed_layout';
    final corpusBytes = File('$folder/corpus.json').readAsBytesSync();
    final oracleBytes = File('$folder/oracle.json').readAsBytesSync();
    final corpus = jsonDecode(utf8.decode(corpusBytes)) as Map<String, Object?>;
    final oracle = jsonDecode(utf8.decode(oracleBytes)) as Map<String, Object?>;
    if (oracle['corpusSHA256'] != sha256.convert(corpusBytes).toString()) {
      throw StateError('Oracle corpus mismatch');
    }
    final font = File((corpus['font'] as Map)['path'] as String)
        .readAsBytesSync();
    final defects = SpikeReferenceDefects(oracle);
    await defects.load();
    final directory = Directory('build/fixed-layout-svg-text')
      ..createSync(recursive: true);
    final cases = <Map<String, Object?>>[];
    final fixtures = (corpus['cases'] as List)
        .cast<Map<String, Object?>>()
        .where((c) => c['row'] == 'svg-text')
        .toList();
    final pairs = <(Map<String, Object?>, Map<String, Object?>)>[
      for (final fixture in fixtures)
        (
          fixture,
          (oracle['cases'] as List).cast<Map<String, Object?>>().singleWhere(
            (r) => r['id'] == fixture['id'],
          ),
        ),
    ];
    for (final fixture in fixtures.where(
      (f) => f['expectedCapability'] != 'unsupported',
    )) {
      pairs.add((
        {
          ...fixture,
          'id': '${fixture['id']}-webkit-parent-length',
          'diagnostic':
              'parent textLength does not cross textPath length scope',
        },
        (oracle['cases'] as List).cast<Map<String, Object?>>().singleWhere(
          (r) => r['id'] == fixture['id'],
        ),
      ));
    }
    for (final probe
        in (oracle['svgTextProbes'] as List).cast<Map<String, Object?>>()) {
      final source =
          '<html xmlns="http://www.w3.org/1999/xhtml"><head>'
          '<meta name="viewport" content="width=320,height=240"/>'
          '<style>html,body{width:320px;height:240px}body{margin:8px}</style>'
          '</head><body>${probe['source']}</body></html>';
      pairs.add((
        {
          ...fixtures.first,
          'id': 'svg-text-path-${probe['adjustment']}',
          'variant': 'path-${probe['adjustment']}',
          'source': source,
          'sha256': sha256.convert(utf8.encode(source)).toString(),
          'captureHostMediaType': 'application/xhtml+xml',
        },
        {
          'svgTexts': [probe],
          'pngBase64': probe['pngBase64'],
          'paintStability': probe['paintStability'],
          'samples': <Map>[],
        },
      ));
    }
    for (final (fixture, reference) in pairs) {
      final input = SceneHarnessInput(fixture, corpus, font);
      final registry = FontRegistry(processBudget: ProcessFontBudget());
      final source = FixedSourceLease(
        page: input.page,
        document: input.document,
        styles: const CssStyleResolver().resolve(
          input.book,
          0,
          input.document,
          const ReaderSettings(),
          authoredViewport: AuthoredPageSize(320, 240),
        ),
        rendition: sectionRendition(input.book, 0),
        resources: ArchiveReaderResourceSource(input.book.archive),
        retainedSourceBytes: utf8.encode(fixture['source'] as String).length,
        releaseSource: () {},
      );
      final preparer = FixedSectionPreparer(
        fonts: registry,
        drainFonts: registry.drainFonts,
      );
      final plan = preparer.plan(
        source,
        scale: const FixedPreparationScale.authored(),
      );
      final budget = SceneResourceBudget();
      final lease = budget.reserveUnit(
        sourcePages: 1,
        resources: plan.resources,
        sourceDepth: plan.sourceDepth,
        referenceDepth: plan.referenceDepth,
        layerDepth: plan.layerDepth,
      );
      final admission = FixedSceneAdmission(
        plan: plan,
        sceneLease: lease,
        pictureBytes: plan.pictureBytes,
        decodedImageBytes: plan.decodedImageBytes,
        reconcilePictureBytes: (_) => true,
        releaseReservations: lease.release,
      );
      final operation = preparer.prepare(plan, admission);
      PreparedFixedScene? scene;
      final result = <String, Object?>{'id': fixture['id'], 'hostGate': false};
      try {
        scene = await operation.result;
        await operation.drained;
        final measured = measureSvgTextGeometry(
          scene,
          reference,
          // Probe screenshots use the recorded source in an 8px-margin host.
          // Corpus cases instead carry measured screen-space element boxes.
          referenceOffset: (fixture['variant'] as String).startsWith('path-')
              ? const [8.0, 8.0]
              : null,
        );
        result.addAll({
          'status': 'prepared',
          'geometry': measured,
          'complete': scene.geometry.completeness is CompleteGeometry,
        });
        final image = await scene.scene.picture.toImage(320, 240);
        late Uint8List actual;
        try {
          actual = (await image.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          ))!.buffer.asUint8List();
          File('${directory.path}/${fixture['id']}.png').writeAsBytesSync(
            (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
                .asUint8List(),
          );
        } finally {
          image.dispose();
        }
        final expected = await _decode(reference['pngBase64'] as String);
        final scope = defects.scope(fixture, reference, actual, expected);
        final svg = scene.scene.svgScenes.single;
        final pixels = compareSpikePixels(
          actual,
          expected,
          exemptScope: scope.$1,
          textMask: buildD8TextMask(
            nativeGlyphCoverage: _textCoverage(scene),
            referenceGeometryLtrb: _referenceBoxes(reference, fixture),
            provenance: {
              'native': 'production GeometryPaintKind.text alpha footprints',
              'reference': 'oracle SVG character extents',
            },
          ),
          samples: classifySvgSamples(
            document: input.document,
            elements: svg.elements,
            clips: scene.geometry.clips,
            fragments: scene.geometry.fragments,
            paints: scene.geometry.paint,
            referenceComputedPaint: svgReferenceComputedPaint(
              document: input.document,
              reference: reference,
            ),
            samples: (reference['samples'] as List).cast<Map>(),
            actual: actual,
          ),
        );
        result.addAll({
          'pixels': pixels,
          'referenceDefects': scope.$2,
          'hostGate':
              measured['pass'] == true &&
              pixels['pass'] == true &&
              scene.geometry.completeness is CompleteGeometry,
        });
      } on FixedPreparationFailure catch (error) {
        result.addAll({
          'status': 'refused',
          'constructs': error.capability.constructs
              .map((e) => e.identifier)
              .toList(),
          'hostGate':
              fixture['expectedCapability'] == 'unsupported' &&
              error.capability is UnsupportedSectionCapability &&
              error.capability.constructs.any(
                (c) => c.identifier == 'svg-text-vertical',
              ),
        });
      } catch (error) {
        result.addAll({
          'status': 'failed',
          'error': error.runtimeType.toString(),
        });
      } finally {
        await operation.drained;
        scene?.dispose();
        input.book.archive.close();
      }
      result['resourcesReleased'] = budget.used.values.every((n) => n == 0);
      cases.add(result);
    }
    final hostGate = cases.every(
      (c) => c['hostGate'] == true && c['resourcesReleased'] == true,
    );
    final report = <String, Object?>{
      'row': 'svg-text',
      'geometryToleranceCssPx': .5,
      'corpusSHA256': sha256.convert(corpusBytes).toString(),
      'oracleSHA256': sha256.convert(oracleBytes).toString(),
      'referenceDefectsSHA256': defects.registrySHA256,
      'paintControlsSHA256': defects.controlsSHA256,
      'd7ComponentAlphaThreshold': d4ComponentAlphaThreshold,
      'd8TextMaskDilationPixels': d8TextMaskDilationPixels,
      'd9GradientSampleMaximumDelta': d9GradientSampleMaximumDelta,
      'd10ChangedPixelMinimumDelta': d10ChangedPixelMinimumDelta,
      'cases': cases,
      'hostGate': hostGate,
      'textRasterParity': textRasterParityStatus,
      'verdict': hostGate ? textRasterParityStatus : 'fail',
    };
    File('${directory.path}/report.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    return report;
  }
}

Map<String, Object?> measureSvgTextGeometry(
  PreparedFixedScene scene,
  Map<String, Object?> reference, {
  List<double>? referenceOffset,
}) => measureSvgTextSourceGeometry(
  scene.geometry,
  scene.plan.source.document,
  reference,
  referenceOffset: referenceOffset,
);

/// Also used by module diagnostics. Such evidence cannot pass the fixed row.
Map<String, Object?> measureSvgTextSourceGeometry(
  SourceGeometry geometry,
  SourceDocument document,
  Map<String, Object?> reference, {
  List<double>? referenceOffset,
}) {
  final text = geometry.fragments
      .where((f) => f.kind == SourceFragmentKind.svgText)
      .toList();
  final roots = <int, List<SourceFragment>>{};
  for (final fragment in text) {
    var node = document.node(fragment.nodeIndex);
    while (node.localName != 'text' && node.parentIndex != null) {
      node = document.node(node.parentIndex!);
    }
    roots.putIfAbsent(node.index, () => []).add(fragment);
  }
  final references = (reference['svgTexts'] as List).cast<Map>();
  var conserved = roots.length == references.length,
      screenEvidence = true,
      maximum = 0.0,
      comparisons = 0;
  for (final ref in references) {
    final candidates = roots.values
        .where(
          (fragments) =>
              fragments
                  .map((f) => document.node(f.nodeIndex).text ?? '')
                  .join() ==
              ref['text'],
        )
        .toList();
    if (candidates.length != 1) {
      conserved = false;
      continue;
    }
    final fragments = candidates.single
      ..sort((a, b) => a.nodeIndex.compareTo(b.nodeIndex));
    final native = <(int, int)>[];
    final chars = (ref['characters'] as List).cast<Map>();
    // getStartPositionOfChar is local. The oracle's getBoundingClientRect is
    // screen-space; anchor its character extent union to that measured box.
    // The pinned WebKit boxes snap by < 0.03px, within the unchanged B gate.
    final elements = (reference['elements'] as List?)
        ?.cast<Map>()
        .where((e) => e['role'] == 'text' || e['role'] == 'path-text')
        .toList();
    final referenceIndex = references.indexOf(ref);
    final box = elements != null && referenceIndex < elements.length
        ? (elements[referenceIndex]['box'] as List).cast<num>()
        : null;
    screenEvidence = screenEvidence && (box != null || referenceOffset != null);
    final dx =
        referenceOffset?[0] ??
        (box == null
            ? 0.0
            : box[0] -
                  chars
                      .map((c) => (c['extent'] as List)[0] as num)
                      .reduce(math.min));
    final dy =
        referenceOffset?[1] ??
        (box == null
            ? 0.0
            : box[1] -
                  chars
                      .map((c) => (c['extent'] as List)[1] as num)
                      .reduce(math.min));
    var offset = 0, advance = 0.0, localAdvance = 0.0;
    for (final fragment in fragments) {
      var cursor = 0;
      for (final cluster in fragment.clusters) {
        conserved = conserved && cluster.range.start == cursor;
        native.add((offset + cluster.range.start, offset + cluster.range.end));
        cursor = cluster.range.end;
        final first = chars[offset + cluster.range.start];
        final start = (first['start'] as List).cast<num>();
        // Retain the original local B channels as well as screen placement.
        maximum = math.max(
          maximum,
          math.sqrt(
            math.pow(start[0] - cluster.baselineStart.x, 2) +
                math.pow(start[1] - cluster.baselineStart.y, 2),
          ),
        );
        final localWidth = math.sqrt(
          math.pow(cluster.baselineEnd.x - cluster.baselineStart.x, 2) +
              math.pow(cluster.baselineEnd.y - cluster.baselineStart.y, 2),
        );
        localAdvance += localWidth;
        final t = fragment.sourceToUnit;
        final x =
            t.a * cluster.baselineStart.x + t.c * cluster.baselineStart.y + t.e;
        final y =
            t.b * cluster.baselineStart.x + t.d * cluster.baselineStart.y + t.f;
        final vx =
            t.a * (cluster.baselineEnd.x - cluster.baselineStart.x) +
            t.c * (cluster.baselineEnd.y - cluster.baselineStart.y);
        final vy =
            t.b * (cluster.baselineEnd.x - cluster.baselineStart.x) +
            t.d * (cluster.baselineEnd.y - cluster.baselineStart.y);
        maximum = math.max(
          maximum,
          math.sqrt(
            math.pow(start[0] + dx - x, 2) + math.pow(start[1] + dy - y, 2),
          ),
        );
        final width = math.sqrt(vx * vx + vy * vy);
        advance += width;
        if (cluster.range.end - cluster.range.start == 1) {
          maximum = math.max(
            maximum,
            (cluster.rotationRadians -
                        (first['rotation'] as num) * math.pi / 180)
                    .abs() *
                localWidth,
          );
          maximum = math.max(
            maximum,
            (math.atan2(vy, vx) - (first['rotation'] as num) * math.pi / 180)
                    .abs() *
                width,
          );
        }
        comparisons++;
      }
      final length = (document.node(fragment.nodeIndex).text ?? '').length;
      conserved = conserved && cursor == length;
      offset += length;
    }
    final expected = (((ref['fixtureRun'] ?? ref) as Map)['clusterMap'] as List)
        .map((e) => ((e as List)[0] as int, e[1] as int))
        .toList();
    conserved =
        conserved &&
        native.length == expected.length &&
        List.generate(
          native.length,
          (i) => native[i] == expected[i],
        ).every((e) => e);
    maximum = math.max(
      maximum,
      math.max(
        (advance - (ref['computedTextLength'] as num)).abs(),
        (localAdvance - (ref['computedTextLength'] as num)).abs(),
      ),
    );
  }
  return {
    'definition': 'B',
    'maximumCssPx': maximum,
    'comparisons': comparisons,
    'clusterConservation': conserved,
    'screenEvidence': screenEvidence,
    'pass': conserved && screenEvidence && comparisons > 0 && maximum <= .5,
  };
}

Uint8List _textCoverage(PreparedFixedScene scene) {
  final output = Uint8List(320 * 240);
  for (final paint in scene.geometry.paint.where(
    (p) => p.kind == GeometryPaintKind.text,
  )) {
    final footprint = paint.alphaFootprint;
    if (footprint == null) continue;
    final inverse = footprint.transform.inverse();
    if (inverse is! InvertedTransform) {
      throw StateError('Singular text footprint');
    }
    for (var y = 0; y < 240; y++) {
      for (var x = 0; x < 320; x++) {
        final t = inverse.transform;
        final px = t.a * (x + .5) + t.c * (y + .5) + t.e;
        final py = t.b * (x + .5) + t.d * (y + .5) + t.f;
        final xx = ((px - footprint.origin.x) / footprint.pixelSize).floor();
        final yy = ((py - footprint.origin.y) / footprint.pixelSize).floor();
        if (xx >= 0 &&
            yy >= 0 &&
            xx < footprint.width &&
            yy < footprint.height &&
            footprint.alpha[yy * footprint.width + xx] > 0) {
          output[y * 320 + x] = 1;
        }
      }
    }
  }
  return output;
}

List<List<double>> _referenceBoxes(Map reference, Map fixture) => [
  for (final run in reference['svgTexts'] as List)
    for (final c in (run as Map)['characters'] as List)
      [
        ((c as Map)['extent'][0] as num).toDouble() + _offset(fixture, true),
        (c['extent'][1] as num).toDouble() + _offset(fixture, false),
        (c['extent'][0] as num).toDouble() +
            (c['extent'][2] as num).toDouble() +
            _offset(fixture, true),
        (c['extent'][1] as num).toDouble() +
            (c['extent'][3] as num).toDouble() +
            _offset(fixture, false),
      ],
];
double _offset(Map fixture, bool x) => fixture['variant'] == 'nested'
    ? (x ? 7 : 9)
    : (fixture['variant'] as String).startsWith('path-')
    ? 8
    : 0;

Future<Uint8List> _decode(String encoded) async {
  final codec = await ui.instantiateImageCodec(base64Decode(encoded));
  try {
    final frame = await codec.getNextFrame();
    try {
      return (await frame.image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      ))!.buffer.asUint8List();
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}
