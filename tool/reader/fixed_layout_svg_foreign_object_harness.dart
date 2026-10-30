import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:shiori/features/reader/data/canonical/canonical_text.dart';
import 'package:shiori/features/reader/data/cfi/cfi.dart';
import 'package:shiori/features/reader/data/geometry/source_fragment.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/resources/archive_reader_resource_source.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene_admission.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_section_preparer.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_preparation_scale.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';

import 'fixed_layout_scene_input.dart';
import 'fixed_layout_scene_metrics.dart';
import 'fixed_layout_spike_defects.dart';
import 'fixed_layout_spike_geometry.dart';
import 'fixed_layout_spike_pixels.dart';
import 'fixed_layout_svg_samples.dart';

/// First production verdict, including a real unexempted static HTML control.
final class FixedLayoutSvgForeignObjectHarness {
  Future<Map<String, Object?>> run() async {
    const folder = 'test/fixtures/reader/fixed_layout';
    final corpusBytes = File('$folder/corpus.json').readAsBytesSync();
    final oracleBytes = File('$folder/oracle.json').readAsBytesSync();
    final corpus = jsonDecode(utf8.decode(corpusBytes)) as Map<String, Object?>;
    final oracle = jsonDecode(utf8.decode(oracleBytes)) as Map<String, Object?>;
    if (oracle['corpusSHA256'] != sha256.convert(corpusBytes).toString()) {
      throw StateError('Oracle corpus mismatch');
    }
    final fontInfo = corpus['font'] as Map;
    final font = File(fontInfo['path'] as String).readAsBytesSync();
    if (sha256.convert(font).toString() != fontInfo['sha256']) {
      throw StateError('Font provenance mismatch');
    }
    final defects = SpikeReferenceDefects(oracle);
    await defects.load();
    final registry = FontRegistry(processBudget: ProcessFontBudget());
    final directory = Directory('build/fixed-layout-svg-foreign-object')
      ..createSync(recursive: true);
    final fixtures = (corpus['cases'] as List)
        .cast<Map<String, Object?>>()
        .where((c) => c['row'] == 'foreign-object')
        .toList();
    final control = defects.control('foreignStatic', 'text/html');
    final source =
        '<html xmlns="http://www.w3.org/1999/xhtml"><head>'
        '<meta name="viewport" content="width=320,height=240"/>'
        '<style>@font-face{font-family:Fixture;src:url(/font.ttf)}'
        'html,body{margin:0;width:320px;height:240px}'
        'body{font:20px Fixture}</style></head>'
        '<body>${control['sourceBody']}</body></html>';
    final controlFixture = <String, Object?>{
      ...fixtures.first,
      'id': 'foreignStatic',
      'source': source,
      'sha256': sha256.convert(utf8.encode(source)).toString(),
      'expectedCapability': 'required',
      'variant': 'control',
    };
    final staticReport = await _case(
      controlFixture,
      corpus,
      font,
      registry,
      {'pngBase64': control['pngBase64'], 'samples': <Object?>[]},
      defects,
      directory,
      control: true,
    );
    defects.staticControlPass = staticReport['pass'] == true;
    final cases = <Map<String, Object?>>[];
    for (final fixture in fixtures) {
      final reference = (oracle['cases'] as List)
          .cast<Map<String, Object?>>()
          .singleWhere((c) => c['id'] == fixture['id']);
      cases.add(
        await _case(
          fixture,
          corpus,
          font,
          registry,
          reference,
          defects,
          directory,
        ),
      );
    }
    final pass =
        staticReport['pass'] == true && cases.every((c) => c['pass'] == true);
    final report = <String, Object?>{
      'row': 'foreign-object',
      'geometryToleranceCssPx': .5,
      'd7ComponentAlphaThreshold': d4ComponentAlphaThreshold,
      'd10ChangedPixelMinimumDelta': d10ChangedPixelMinimumDelta,
      'corpusSHA256': sha256.convert(corpusBytes).toString(),
      'oracleSHA256': sha256.convert(oracleBytes).toString(),
      'referenceDefectsSHA256': defects.registrySHA256,
      'paintControlsSHA256': defects.controlsSHA256,
      'foreignStatic': staticReport,
      'cases': cases,
      'pass': pass,
      'rowVerdict': pass ? 'PASS' : 'FAIL',
    };
    File('${directory.path}/report.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    return report;
  }

  Future<Map<String, Object?>> _case(
    Map<String, Object?> fixture,
    Map<String, Object?> corpus,
    Uint8List font,
    FontRegistry registry,
    Map<String, Object?> reference,
    SpikeReferenceDefects defects,
    Directory directory, {
    bool control = false,
  }) async {
    final input = SceneHarnessInput(fixture, corpus, font);
    final preparer = FixedSectionPreparer(
      fonts: registry,
      drainFonts: registry.drainFonts,
    );
    final shared = SceneResourceBudget();
    PreparedFixedScene? result;
    final report = <String, Object?>{
      'id': fixture['id'],
      'variant': fixture['variant'],
      'required': fixture['expectedCapability'] == 'required',
    };
    try {
      final styles = const CssStyleResolver().resolve(
        input.book,
        0,
        input.document,
        const ReaderSettings(),
        authoredViewport: AuthoredPageSize(320, 240),
      );
      final source = FixedSourceLease(
        page: input.page,
        document: input.document,
        styles: styles,
        rendition: sectionRendition(input.book, 0),
        resources: ArchiveReaderResourceSource(input.book.archive),
        retainedSourceBytes: utf8.encode(fixture['source'] as String).length,
        releaseSource: () {},
      );
      final plan = preparer.plan(
        source,
        scale: const FixedPreparationScale.authored(),
      );
      final lease = shared.reserveUnit(
        sourcePages: 1,
        resources: plan.resources,
        sourceDepth: plan.sourceDepth,
        referenceDepth: plan.referenceDepth,
        layerDepth: plan.layerDepth,
      );
      final operation = preparer.prepare(
        plan,
        FixedSceneAdmission(
          plan: plan,
          sceneLease: lease,
          pictureBytes: plan.pictureBytes,
          decodedImageBytes: plan.decodedImageBytes,
          reconcilePictureBytes: (_) => true,
          releaseReservations: lease.release,
        ),
      );
      try {
        result = await operation.result;
        final scene = result.scene;
        final geometry = control
            ? <String, Object?>{
                'pass': true,
                'status': 'raster-control; no oracle geometry',
              }
            : _geometry(scene, input, reference);
        final pixels = await _pixels(
          scene,
          input,
          fixture,
          reference,
          defects,
          directory,
          control: control,
        );
        final conservation = _conservation(
          scene,
          input,
          reference,
          control: control,
        );
        final pass =
            fixture['expectedCapability'] != 'unsupported' &&
            geometry['pass'] == true &&
            pixels['pass'] == true &&
            conservation['pass'] == true;
        report.addAll({
          'status': 'prepared',
          'capabilityPass': true,
          'capability': scene.capability.runtimeType.toString(),
          'picture': true,
          'geometry': geometry,
          'pixels': pixels,
          'conservation': conservation,
          'pass': pass,
          'verdict': pass ? 'PASS' : 'FAIL',
        });
      } on FixedPreparationFailure catch (e) {
        final pass =
            fixture['expectedCapability'] == 'unsupported' &&
            e.capability is UnsupportedSectionCapability;
        report.addAll({
          'status': 'refused',
          'capabilityPass': pass,
          'capability': e.capability.runtimeType.toString(),
          'constructs': e.capability.constructs
              .map((c) => c.identifier)
              .toList(),
          'picture': false,
          'pass': pass,
          'verdict': pass ? 'PASS' : 'FAIL',
        });
      } finally {
        await operation.drained;
      }
    } finally {
      result?.dispose();
      input.book.archive.close();
      report['budgetUsedZero'] = shared.used.values.every((v) => v == 0);
      if (report['budgetUsedZero'] != true) {
        report['pass'] = false;
        report['verdict'] = 'FAIL';
      }
    }
    return report;
  }
}

Map<String, Object?> _geometry(
  FixedScene scene,
  SceneHarnessInput input,
  Map<String, Object?> reference,
) {
  final native = <Map<String, Object?>>[];
  for (final f in scene.geometry.fragments.where(
    (f) => f.kind == SourceFragmentKind.xhtmlText,
  )) {
    final data = input.document.node(f.nodeIndex).text!;
    final positions = List<double>.filled(data.length + 1, double.nan);
    double? baseline;
    for (final cluster in f.clusters) {
      final start = fixedMap(
        f.sourceToUnit,
        ui.Offset(cluster.baselineStart.x, cluster.baselineStart.y),
      );
      final end = fixedMap(
        f.sourceToUnit,
        ui.Offset(cluster.baselineEnd.x, cluster.baselineEnd.y),
      );
      positions[cluster.range.start] = start.dx;
      positions[cluster.range.end] = end.dx;
      baseline ??= start.dy;
    }
    native.add({
      'node': f.nodeIndex,
      'sourceText': data,
      'utf16Start': 0,
      'baseline': baseline,
      'boundaryPositions': positions,
    });
  }
  // Coordinates above already include every SVG and XHTML ancestor transform.
  final text = compareSpikeGeometry(
    'foreign-object',
    native,
    reference,
    nested: false,
    componentDiagnostics: const {},
  );
  final channels = (text['channels'] as List).cast<Map<String, Object?>>();
  for (final raw in (reference['elements'] as List).cast<Map>()) {
    final node = input.document.nodes.singleWhere(
      (n) =>
          n.namespaceUri == raw['namespace'] &&
          n.attribute('data-source') == raw['role'],
    );
    final f = scene.geometry.fragments.singleWhere(
      (f) => f.nodeIndex == node.index && f.kind == SourceFragmentKind.element,
    );
    final points = f.elementQuad.map(
      (p) => fixedMap(f.sourceToUnit, ui.Offset(p.x, p.y)),
    );
    final xs = points.map((p) => p.dx), ys = points.map((p) => p.dy);
    final box = [
      xs.reduce(math.min),
      ys.reduce(math.min),
      xs.reduce(math.max) - xs.reduce(math.min),
      ys.reduce(math.max) - ys.reduce(math.min),
    ];
    final expected = (raw['box'] as List).cast<num>();
    final delta = List.generate(
      4,
      (i) => (box[i] - expected[i]).abs(),
    ).reduce(math.max);
    channels.add({
      'channel': 'element-box',
      'role': raw['role'],
      'native': box,
      'reference': expected,
      'maximumCssPxDelta': delta,
      'pass': delta <= .5,
    });
  }
  final maximum = channels
      .map((c) => c['maximumCssPxDelta'] as double)
      .reduce(math.max);
  return {
    ...text,
    'channels': channels,
    'comparisons': channels.length,
    'maximumCssPxDelta': maximum,
    'pass': channels.isNotEmpty && channels.every((c) => c['pass'] == true),
  };
}

Map<String, Object?> _conservation(
  FixedScene scene,
  SceneHarnessInput input,
  Map<String, Object?> reference, {
  required bool control,
}) {
  final fragments = scene.geometry.fragments
      .where((f) => f.kind == SourceFragmentKind.xhtmlText)
      .toList();
  final projected = <Map<String, Object?>>[];
  for (final f in fragments) {
    final text = input.document.node(f.nodeIndex).text!;
    final cfis = [
      for (var i = 0; i <= text.length; i++)
        {
          'utf16': i,
          'cfi': Cfi.export(
            input.document,
            SourcePosition(nodeIndex: f.nodeIndex, offset: i),
          ),
        },
    ];
    var cursor = 0;
    var covered = true;
    for (final c in f.clusters) {
      covered = covered && c.range.start == cursor;
      cursor = c.range.end;
    }
    projected.add({
      'text': text,
      'cfis': cfis,
      'clustersExactOnce': covered && cursor == text.length,
    });
  }
  final expected = (reference['projectedTexts'] as List? ?? const [])
      .cast<Map>();
  Object normalized(Map p) => [
    p['text'],
    for (final c in (p['cfis'] as List).cast<Map>()) [c['utf16'], c['cfi']],
  ];
  final exact =
      control ||
      jsonEncode(projected.map(normalized).toList()) ==
          jsonEncode(expected.map(normalized).toList());
  final canonical = CanonicalIndex.build(input.document);
  final excluded = fragments.every(
    (f) => canonical.entries.every((e) => e.nodeIndex != f.nodeIndex),
  );
  final pass =
      fragments.isNotEmpty &&
      exact &&
      excluded &&
      projected.every((p) => p['clustersExactOnce'] == true) &&
      scene.geometry.completeness is CompleteGeometry;
  return {
    'projected': projected,
    'projectedCfiExact': exact,
    'canonicalV1Exclusion': excluded,
    'pass': pass,
  };
}

Future<Map<String, Object?>> _pixels(
  FixedScene scene,
  SceneHarnessInput input,
  Map<String, Object?> fixture,
  Map<String, Object?> reference,
  SpikeReferenceDefects defects,
  Directory directory, {
  required bool control,
}) async {
  final image = await scene.picture.toImage(320, 240);
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
  final codec = await ui.instantiateImageCodec(
    base64Decode(reference['pngBase64'] as String),
  );
  late Uint8List expected;
  try {
    final frame = await codec.getNextFrame();
    try {
      expected = (await frame.image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      ))!.buffer.asUint8List();
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
  final scope = control
      ? (<int, String>{}, <Map<String, Object?>>[])
      : defects.scope(fixture, reference, actual, expected);
  final coverage = Uint8List(320 * 240);
  for (final p in scene.geometry.paint.where((p) => p.kind.name == 'text')) {
    final alpha = p.alphaFootprint;
    if (alpha == null) continue;
    for (var y = 0; y < alpha.height; y++) {
      for (var x = 0; x < alpha.width; x++) {
        if (alpha.alpha[y * alpha.width + x] == 0) continue;
        final point = fixedMap(
          alpha.transform,
          ui.Offset(
            alpha.origin.x + x * alpha.pixelSize,
            alpha.origin.y + y * alpha.pixelSize,
          ),
        );
        final xx = point.dx.floor(), yy = point.dy.floor();
        if (xx >= 0 && xx < 320 && yy >= 0 && yy < 240) {
          coverage[yy * 320 + xx] = 1;
        }
      }
    }
  }
  final textMask = buildD8TextMask(
    nativeGlyphCoverage: coverage,
    referenceGeometryLtrb: control
        ? const []
        : referenceSceneTextBoxes(reference),
    provenance: {
      'native': 'production foreignObject text paint alpha',
      'reference': 'oracle text geometry',
    },
  );
  final svg = scene.svgScenes.single;
  final pixels = compareSpikePixels(
    actual,
    expected,
    exemptScope: scope.$1,
    textMask: textMask,
    samples: classifySvgSamples(
      document: input.document,
      elements: svg.elements,
      clips: svg.geometry.clips,
      fragments: svg.geometry.fragments,
      paints: svg.geometry.paint,
      referenceComputedPaint: svgReferenceComputedPaint(
        document: input.document,
        reference: reference,
      ),
      samples: (reference['samples'] as List? ?? const []).cast<Map>(),
      actual: actual,
    ),
  );
  return {
    ...pixels,
    'referenceDefects': scope.$2,
    'exemptions': scope.$1.length,
  };
}
