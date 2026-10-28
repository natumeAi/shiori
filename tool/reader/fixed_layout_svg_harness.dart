import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';
import 'package:shiori/features/reader/data/cfi/cfi.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_presentation.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';

import 'fixed_layout_scene_input.dart';
import 'fixed_layout_spike_defects.dart';
import 'fixed_layout_spike_pixels.dart';

/// Dedicated production SVG row proof; failed fidelity remains a failed verdict.
final class FixedLayoutSvgHarness {
  Future<Map<String, Object?>> run() async {
    const folder = 'test/fixtures/reader/fixed_layout';
    final corpusBytes = File('$folder/corpus.json').readAsBytesSync();
    final oracleBytes = File('$folder/oracle.json').readAsBytesSync();
    final corpus = jsonDecode(utf8.decode(corpusBytes)) as Map<String, Object?>;
    final oracle = jsonDecode(utf8.decode(oracleBytes)) as Map<String, Object?>;
    final font = File((corpus['font'] as Map)['path'] as String)
        .readAsBytesSync();
    final defects = SpikeReferenceDefects(oracle);
    await defects.load();
    final cases = <Map<String, Object?>>[];
    final directory = Directory('build/fixed-layout-svg')
      ..createSync(recursive: true);
    for (final fixture
        in (corpus['cases'] as List).cast<Map<String, Object?>>().where(
          (c) => c['row'] == 'svg-graphics',
        )) {
      final id = fixture['id'] as String;
      final reference = (oracle['cases'] as List)
          .cast<Map<String, Object?>>()
          .singleWhere((c) => c['id'] == id);
      final input = SceneHarnessInput(fixture, corpus, font);
      final budget = SceneResourceBudget();
      SvgGraphicsScene? scene, tile;
      try {
        final resource = (corpus['resources'] as Map)['/tile.svg'] as String;
        final tileDocument = const SourceParser().parse(
          resource,
          mediaType: 'image/svg+xml',
        );
        tile = await SvgGraphicsPlan.inspect(
          document: tileDocument,
          rootIndex: tileDocument.documentElementIndex,
          page: input.page,
          size: AuthoredPageSize(320, 240),
        ).prepare(budget: budget);
        final raw = XmlDocument.parse(fixture['source'] as String);
        final sheets = [
          for (final entry in (corpus['resources'] as Map).entries)
            if ((entry.key as String).endsWith('.css')) entry.value as String,
          for (final e in raw.descendants.whereType<XmlElement>())
            if (e.name.local == 'style') e.innerText,
        ];
        final presentation = SvgPresentation.resolve(
          input.document,
          sheets,
          viewportWidth: 320,
          viewportHeight: 240,
        );
        final root = input.document.nodes
            .firstWhere((n) => n.localName == 'svg')
            .index;
        final nested = fixture['variant'] == 'nested';
        final plan = SvgGraphicsPlan.inspect(
          document: input.document,
          rootIndex: root,
          page: input.page,
          size: AuthoredPageSize(320, 240),
          resolvedPresentation: presentation.values,
          presentationProblems: presentation.problems,
          placement: nested
              ? AffineTransform(1, 0, 0, 1, 7, 9)
              : const AffineTransform.identity(),
        );
        scene = await plan.prepare(
          budget: budget,
          images: SvgGraphicsImages(vectors: {'/tile.svg': tile}),
          hostOpacity: nested ? .8 : 1,
          hostClips: nested
              ? [
                  GeometryClip(
                    id: 'svg-host-clip',
                    region: GeometryRegion(
                      left: 0,
                      top: 0,
                      width: 300,
                      height: 220,
                      transform: AffineTransform(1, 0, 0, 1, 7, 9),
                    ),
                  ),
                ]
              : const [],
        );
        final unsupported = fixture['variant'] == 'unsupported';
        final geometry = _geometry(scene, input, reference);
        var pixels = <String, Object?>{'status': 'unverified', 'pass': false};
        var decisions = <Map<String, Object?>>[];
        if (scene.picture != null && reference['pngBase64'] != null) {
          final nativeImage = await scene.picture!.toImage(320, 240);
          late Uint8List actual;
          try {
            actual = (await nativeImage.toByteData(
              format: ui.ImageByteFormat.rawStraightRgba,
            ))!.buffer.asUint8List();
            File('${directory.path}/$id.png').writeAsBytesSync(
              (await nativeImage.toByteData(format: ui.ImageByteFormat.png))!
                  .buffer
                  .asUint8List(),
            );
          } finally {
            nativeImage.dispose();
          }
          final expected = await _decode(reference['pngBase64'] as String);
          final scope = defects.scope(fixture, reference, actual, expected);
          decisions = scope.$2;
          final allowed = (defects.registry['exceptions'] as List)
              .cast<Map>()
              .where((rule) => (rule['cases'] as List).contains(id))
              .map((rule) => rule['id'])
              .toSet();
          final exempt = {
            for (final entry in scope.$1.entries)
              if (allowed.contains(entry.value)) entry.key: entry.value,
          };
          for (final decision in decisions) {
            if (!allowed.contains(decision['id'])) {
              decision['eligible'] = false;
              decision['caseAuthorized'] = false;
            }
          }
          var sampleDelta = 0;
          for (final sample in (reference['samples'] as List).cast<Map>()) {
            final offset =
                ((sample['y'] as int) * 320 + (sample['x'] as int)) * 4;
            for (var channel = 0; channel < 4; channel++) {
              sampleDelta = math.max(
                sampleDelta,
                (actual[offset + channel] - (sample['rgba'] as List)[channel])
                    .abs()
                    .toInt(),
              );
            }
          }
          pixels = compareSpikePixels(
            actual,
            expected,
            exemptScope: exempt,
            maximumSampleDelta: sampleDelta,
          );
        } else if (unsupported) {
          pixels = {'status': 'not-applicable', 'pass': false};
        }
        final capabilityPass = unsupported
            ? scene.capability is UnsupportedSectionCapability &&
                  scene.picture == null
            : scene.capability.isComplete &&
                  scene.geometry.completeness is CompleteGeometry;
        cases.add({
          'id': id,
          'required': !unsupported,
          'capability': scene.capability.runtimeType.toString(),
          'constructs': scene.capability.constructs
              .map((c) => c.identifier)
              .toList(),
          'typedCapabilityPass': capabilityPass,
          'sourceGeometryComplete':
              scene.geometry.completeness is CompleteGeometry,
          'sourceFragments': scene.geometry.fragments.length,
          'paintElements': scene.geometry.paint.length,
          'geometry': geometry,
          'pixels': pixels,
          'referenceDefects': decisions,
          'referencePaintStability': reference['paintStability'],
          'pass':
              capabilityPass &&
              (unsupported ||
                  geometry['pass'] == true && pixels['pass'] == true),
          'reservation': {
            for (final r in budget.peaks.entries) r.key.name: r.value,
          },
        });
      } finally {
        scene?.dispose();
        tile?.dispose();
        input.book.archive.close();
      }
      if (budget.used.values.any((value) => value != 0)) {
        throw StateError('SVG resource leak');
      }
    }
    final report = <String, Object?>{
      'row': 'svg-graphics',
      'geometryToleranceCssPx': .5,
      'd7ComponentAlphaThreshold': d4ComponentAlphaThreshold,
      'corpusSHA256': sha256.convert(corpusBytes).toString(),
      'oracleSHA256': sha256.convert(oracleBytes).toString(),
      'cases': cases,
      'pass': cases.every((c) => c['pass'] == true),
    };
    File('${directory.path}/report.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    return report;
  }
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

Map<String, Object?> _geometry(
  SvgGraphicsScene scene,
  SceneHarnessInput input,
  Map<String, Object?> reference,
) {
  final channels = <Map<String, Object?>>[];
  final svgNodes = input.document.nodes
      .where(
        (n) =>
            n.namespaceUri == 'http://www.w3.org/2000/svg' &&
            n.localName != null,
      )
      .toList();
  final expected = ((reference['graphics'] as Map)['elements'] as List)
      .cast<Map>();
  var identity = svgNodes.length == expected.length;
  for (final fragment in scene.geometry.fragments) {
    final position = SourcePosition(nodeIndex: fragment.nodeIndex, offset: 0);
    final cfi = Cfi.export(input.document, position);
    if (Cfi.resolveLocal(input.document, cfi).start != position ||
        fragment.page != input.page) {
      identity = false;
    }
  }
  var requiredCount = 0;
  for (var j = 0; j < svgNodes.length; j++) {
    final node = svgNodes[j];
    if (expected[j]['tag'] != node.localName ||
        expected[j]['id'] != (node.id == '' ? null : node.id)) {
      identity = false;
    }
    if (!const {
      'svg',
      'g',
      'use',
      'rect',
      'circle',
      'ellipse',
      'line',
      'polyline',
      'polygon',
      'path',
      'image',
    }.contains(node.localName)) {
      continue;
    }
    var parent = node.parentIndex, definition = false;
    while (parent != null) {
      final n = input.document.node(parent);
      if (const {'defs', 'symbol', 'marker', 'pattern'}.contains(n.localName)) {
        definition = true;
      }
      parent = n.parentIndex;
    }
    if (definition) continue;
    requiredCount++;
    final matches = scene.elements
        .where((e) => e.nodeIndex == node.index && e.instancePath.isEmpty)
        .toList();
    if (matches.length != 1) {
      identity = false;
      continue;
    }
    final native = matches.single, b = expected[j]['bounds'] as List?;
    if (b != null) {
      final r = native.bounds, values = [r.left, r.top, r.width, r.height];
      final delta = List.generate(
        4,
        (k) => (values[k] - (b[k] as num)).abs(),
      ).reduce(math.max);
      channels.add({
        'channel': 'svg-fill-bounds',
        'node': node.index,
        'tag': node.localName,
        'native': values,
        'reference': b,
        'maximumCssPxDelta': delta,
        'pass': delta <= .5,
      });
    }
    final ctm = expected[j]['screenCTM'] as List?;
    if (ctm != null) {
      final t = native.transform;
      final values = [t.a, t.b, t.c, t.d, t.e, t.f];
      // Compare displacement at all fill-box corners in authored CSS pixels.
      var delta = 0.0;
      for (final p in [
        native.bounds.topLeft,
        native.bounds.topRight,
        native.bounds.bottomLeft,
        native.bounds.bottomRight,
      ]) {
        final actual = ui.Offset(
          t.a * p.dx + t.c * p.dy + t.e,
          t.b * p.dx + t.d * p.dy + t.f,
        );
        final target = ui.Offset(
          (ctm[0] as num) * p.dx + (ctm[2] as num) * p.dy + (ctm[4] as num),
          (ctm[1] as num) * p.dx + (ctm[3] as num) * p.dy + (ctm[5] as num),
        );
        delta = math.max(delta, (actual - target).distance);
      }
      channels.add({
        'channel': 'svg-transform-corner-displacement',
        'node': node.index,
        'native': values,
        'reference': ctm,
        'maximumCssPxDelta': delta,
        'pass': delta <= .5,
      });
    }
  }
  final complete = scene.geometry.completeness is CompleteGeometry;
  final maximum = channels.isEmpty
      ? null
      : channels.map((c) => c['maximumCssPxDelta'] as double).reduce(math.max);
  return {
    'pass':
        identity &&
        complete &&
        channels.isNotEmpty &&
        channels.every((c) => c['pass'] == true),
    'identityPass': identity,
    'sourceGeometryComplete': complete,
    'requiredElements': requiredCount,
    'maximumCssPxDelta': maximum,
    'comparisons': channels.length,
    'channels': channels,
  };
}
