import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/resources/archive_reader_resource_source.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_preparation_plan.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene_admission.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_section_preparer.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';

import 'fixed_layout_scene_input.dart';
import 'fixed_layout_spike_defects.dart';
import 'fixed_layout_spike_pixels.dart';

/// Production proof for the `filters` row. Fixed-scene preparation is the
/// route under test; the oracle supplies the geometry boxes, D9 samples and
/// reference PNG, while D3 scope comes only from the shared rule registry.
final class FixedLayoutSvgFiltersHarness {
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
    final registry = FontRegistry(processBudget: ProcessFontBudget());
    final defects = SpikeReferenceDefects(oracle);
    await defects.load();
    final directory = Directory('build/fixed-layout-svg-filters')
      ..createSync(recursive: true);
    final cases = <Map<String, Object?>>[];
    for (final fixture
        in (corpus['cases'] as List).cast<Map<String, Object?>>().where(
          (c) => c['row'] == 'filters',
        )) {
      final id = fixture['id'] as String;
      final reference = (oracle['cases'] as List)
          .cast<Map<String, Object?>>()
          .singleWhere((c) => c['id'] == id);
      final input = SceneHarnessInput(fixture, corpus, font);
      final caseReport = <String, Object?>{
        'id': id,
        'variant': fixture['variant'],
        'required': fixture['expectedCapability'] == 'required',
        'expectedCapability': fixture['expectedCapability'],
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
        final plan = FixedPreparationPlan.inspect(
          source,
          scale: const FixedPreparationScale.authored(),
        );
        final shared = SceneResourceBudget();
        final lease = shared.reserveUnit(
          sourcePages: 1,
          resources: plan.resources,
          sourceDepth: plan.sourceDepth,
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
        final preparer = FixedSectionPreparer(
          fonts: registry,
          drainFonts: registry.drainFonts,
        );
        final operation = preparer.prepare(plan, admission);
        PreparedFixedScene? result;
        try {
          result = await operation.result;
          await operation.drained;
          final unsupported = fixture['expectedCapability'] == 'unsupported';
          final scene = result.scene;
          final svg = scene.svgScenes.isEmpty ? null : scene.svgScenes.single;
          caseReport.addAll({
            'status': 'prepared',
            'capability': scene.capability.runtimeType.toString(),
            'constructs': scene.capability.constructs
                .map((c) => c.identifier)
                .toList(),
            'picture': true,
            'svgScenes': scene.svgScenes.length,
            'svgElements': svg?.elements.length ?? 0,
            'fragments': scene.geometry.fragments.length,
            'filterFragments': svg == null ? 0 : svg.geometry.fragments.length,
            'filterPaintEvidence': _filterPaintEvidence(svg, {
              for (final node in input.document.nodes)
                if ((node.attribute('filter') ?? '').trim().isNotEmpty &&
                    (node.attribute('filter') ?? '').trim().toLowerCase() !=
                        'none')
                  node.index,
            }),
            'geometryCompleteness': scene.geometry.completeness.runtimeType
                .toString(),
            'geometryIssues': scene.geometry.completeness is IncompleteGeometry
                ? (scene.geometry.completeness as IncompleteGeometry).issues
                      .map((i) => i.reason)
                      .toList()
                : const <String>[],
          });
          final capabilityPass = unsupported
              ? false
              : scene.capability.isComplete;
          Map<String, Object?> geometry = {
            'status': 'not-applicable',
            'pass': unsupported,
          };
          Map<String, Object?> pixels = {
            'status': 'not-applicable',
            'pass': unsupported,
          };
          if (!unsupported) {
            geometry = _geometry(
              scene: scene,
              svg: svg,
              input: input,
              reference: reference,
            );
            pixels = await _pixels(
              scene: scene,
              input: input,
              fixture: fixture,
              reference: reference,
              defects: defects,
              directory: directory,
              id: id,
            );
          }
          final filterEvidence =
              !unsupported &&
              (caseReport['filterPaintEvidence'] as List).isNotEmpty &&
              scene.geometry.completeness is CompleteGeometry;
          final pass =
              capabilityPass &&
              (unsupported ||
                  geometry['pass'] == true &&
                      pixels['pass'] == true &&
                      filterEvidence);
          caseReport.addAll({
            'capabilityPass': capabilityPass,
            'geometry': geometry,
            'pixels': pixels,
            'filterEvidencePass': filterEvidence,
            'pass': pass,
            'verdict': pass ? 'PASS' : 'FAIL',
          });
        } on FixedPreparationFailure catch (error) {
          await operation.drained;
          final capability = error.capability;
          final unsupported = fixture['expectedCapability'] == 'unsupported';
          final pass =
              unsupported && capability is UnsupportedSectionCapability;
          caseReport.addAll({
            'status': 'refused',
            'capability': capability.runtimeType.toString(),
            'constructs': capability.constructs
                .map((c) => c.identifier)
                .toList(),
            'picture': false,
            'fragments': 0,
            'capabilityPass': pass,
            'pass': pass,
            'verdict': pass ? 'PASS' : 'FAIL',
          });
        } finally {
          result?.dispose();
          caseReport['reservation'] = {
            for (final r in shared.peaks.entries) r.key.name: r.value,
          };
          caseReport['budgetUsedZero'] = shared.used.values.every(
            (v) => v == 0,
          );
          if (caseReport['budgetUsedZero'] != true) {
            caseReport['pass'] = false;
            caseReport['verdict'] = 'FAIL';
          }
        }
      } finally {
        input.book.archive.close();
      }
      cases.add(caseReport);
    }
    final report = <String, Object?>{
      'row': 'filters',
      'geometryToleranceCssPx': .5,
      'd7ComponentAlphaThreshold': d4ComponentAlphaThreshold,
      'd10ChangedPixelMinimumDelta': d10ChangedPixelMinimumDelta,
      'corpusSHA256': sha256.convert(corpusBytes).toString(),
      'oracleSHA256': sha256.convert(oracleBytes).toString(),
      'referenceDefectsSHA256': defects.registrySHA256,
      'paintControlsSHA256': defects.controlsSHA256,
      'cases': cases,
      'pass': cases.every((c) => c['pass'] == true),
      'rowVerdict': cases.every((c) => c['pass'] == true) ? 'PASS' : 'FAIL',
    };
    File('${directory.path}/report.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    return report;
  }
}

List<Map<String, Object?>> _filterPaintEvidence(
  SvgGraphicsScene? scene,
  Set<int> filteredNodes,
) {
  if (scene == null) return const [];
  return [
    for (final paint in scene.geometry.paint)
      if (paint.exactCoverage &&
          paint.alphaFootprint != null &&
          filteredNodes.contains(paint.nodeIndex))
        {
          'nodeIndex': paint.nodeIndex,
          'paintOrdinal': paint.paintOrdinal,
          'region': [
            paint.region.left,
            paint.region.top,
            paint.region.width,
            paint.region.height,
          ],
          'exactCoverage': paint.exactCoverage,
          'pixelSize': paint.alphaFootprint!.pixelSize,
          'storageBytes': paint.alphaFootprint!.storageBytes,
          'uniformAlpha': paint.alphaFootprint!.uniformAlpha,
          'sampleWidth': paint.alphaFootprint!.width,
          'sampleHeight': paint.alphaFootprint!.height,
        },
  ];
}

Map<String, Object?> _geometry({
  required FixedScene scene,
  required SvgGraphicsScene? svg,
  required SceneHarnessInput input,
  required Map<String, Object?> reference,
}) {
  final channels = <Map<String, Object?>>[];
  final elements = (reference['elements'] as List).cast<Map>();
  for (final expected in elements) {
    final role = expected['role'] as String?;
    final id = expected['id'] as String?;
    final box = (expected['box'] as List).cast<num>();
    final namespace = expected['namespace'] as String?;
    List<double>? native;
    if (namespace == 'http://www.w3.org/1999/xhtml') {
      final node = input.document.nodes
          .where(
            (n) =>
                n.namespaceUri == namespace &&
                (role == null || n.attribute('data-source') == role),
          )
          .toList();
      if (node.length == 1) {
        final matches = scene.boxes
            .where((b) => b.nodeIndex == node.single.index)
            .toList();
        if (matches.length == 1) {
          final box = matches.single;
          final r = _screenBounds(box.transform, box.borderBox);
          native = [r.left, r.top, r.width, r.height];
        }
      }
    } else {
      final nodes = input.document.nodes
          .where(
            (n) =>
                n.namespaceUri == namespace &&
                n.localName != null &&
                (id != null ? n.id == id : n.attribute('data-source') == role),
          )
          .toList();
      if (nodes.length == 1 && svg != null) {
        final matches = svg.elements
            .where(
              (e) =>
                  e.nodeIndex == nodes.single.index && e.instancePath.isEmpty,
            )
            .toList();
        if (matches.length == 1) {
          final r = _screenBounds(
            matches.single.transform,
            matches.single.bounds,
          );
          native = [r.left, r.top, r.width, r.height];
        }
      }
    }
    final delta = native == null
        ? double.infinity
        : List.generate(4, (i) => (native![i] - box[i]).abs()).reduce(math.max);
    channels.add({
      'channel': 'element-box',
      'role': role,
      'id': id,
      'native': native,
      'reference': [for (final v in box) v.toDouble()],
      'maximumCssPxDelta': delta,
      'pass': delta <= .5,
    });
  }
  final maximum = channels.isEmpty
      ? null
      : channels.map((c) => c['maximumCssPxDelta'] as double).reduce(math.max);
  final complete = scene.geometry.completeness is CompleteGeometry;
  final filterPaint = scene.geometry.paint.any(
    (p) =>
        p.exactCoverage &&
        p.alphaFootprint != null &&
        p.alphaFootprint!.pixelSize == 1,
  );
  return {
    'comparisons': channels.length,
    'maximumCssPxDelta': maximum,
    'channels': channels,
    'visibilityEvidenceBounded': complete && filterPaint,
    'pass': channels.isNotEmpty && channels.every((c) => c['pass'] == true),
  };
}

Future<Map<String, Object?>> _pixels({
  required FixedScene scene,
  required SceneHarnessInput input,
  required Map<String, Object?> fixture,
  required Map<String, Object?> reference,
  required SpikeReferenceDefects defects,
  required Directory directory,
  required String id,
}) async {
  final image = await scene.picture.toImage(320, 240);
  late Uint8List actual;
  try {
    actual = (await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    ))!.buffer.asUint8List();
    File('${directory.path}/$id.png').writeAsBytesSync(
      (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
          .asUint8List(),
    );
  } finally {
    image.dispose();
  }
  final expected = await _decode(reference['pngBase64'] as String);
  final scope = defects.scope(fixture, reference, actual, expected);
  final samples = <SpikeSampleRecord>[];
  for (final raw in (reference['samples'] as List? ?? const []).cast<Map>()) {
    final x = raw['x'] as int, y = raw['y'] as int;
    final wanted = (raw['rgba'] as List).cast<int>();
    final offset = (y * 320 + x) * 4;
    final delta = List.generate(
      4,
      (channel) => (actual[offset + channel] - wanted[channel]).abs(),
    ).reduce(math.max);
    samples.add(
      SpikeSampleRecord(
        x: x,
        y: y,
        maximumChannelDelta: delta,
        classification: SpikeSamplePaintClass.solid,
        provenance: {
          'native': actual.sublist(offset, offset + 4),
          'reference': wanted,
          'classification': 'solid filter output; no gradient paint server',
        },
      ),
    );
  }
  final pixels = compareSpikePixels(
    actual,
    expected,
    exemptScope: scope.$1,
    samples: samples,
  );
  return {
    ...pixels,
    'referenceDefects': scope.$2,
    'd4SubRules': {
      for (final key in const [
        'interior',
        'edgeNeighbourhood',
        'supportBounds',
        'components',
        'samples',
      ])
        key: ((pixels['d4'] as Map)[key] as Map)['pass'],
    },
  };
}

Future<Uint8List> _decode(String base64) async {
  final codec = await ui.instantiateImageCodec(base64Decode(base64));
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

ui.Rect _screenBounds(AffineTransform transform, ui.Rect bounds) {
  final points =
      [
        bounds.topLeft,
        bounds.topRight,
        bounds.bottomRight,
        bounds.bottomLeft,
      ].map(
        (p) => ui.Offset(
          transform.a * p.dx + transform.c * p.dy + transform.e,
          transform.b * p.dx + transform.d * p.dy + transform.f,
        ),
      );
  return ui.Rect.fromLTRB(
    points.map((p) => p.dx).reduce(math.min),
    points.map((p) => p.dy).reduce(math.min),
    points.map((p) => p.dx).reduce(math.max),
    points.map((p) => p.dy).reduce(math.max),
  );
}
