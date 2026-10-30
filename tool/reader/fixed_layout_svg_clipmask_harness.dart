import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_fragment.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/resources/archive_reader_resource_source.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_preparation_plan.dart';
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

/// Production clip/mask row proof through `FixedSectionPreparer`.
final class FixedLayoutSvgClipMaskHarness {
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
    final directory = Directory('build/fixed-layout-svg-clipmask')
      ..createSync(recursive: true);
    final cases = <Map<String, Object?>>[];
    for (final fixture
        in (corpus['cases'] as List).cast<Map<String, Object?>>().where(
          (c) => c['row'] == 'clip-mask',
        )) {
      final id = fixture['id'] as String;
      final reference = (oracle['cases'] as List)
          .cast<Map<String, Object?>>()
          .singleWhere((c) => c['id'] == id);
      final input = SceneHarnessInput(fixture, corpus, font);
      final budget = SceneResourceBudget();
      Uint8List? actual;
      Map<String, Object?>? pixels;
      Map<String, Object?>? geometry;
      Map<String, Object?>? fixedGeometry;
      List<Map<String, Object?>> pixelScope = const [];
      String? errorText;
      var status = 'prepared';
      SectionCapability? capability;
      PreparedFixedScene? result;
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
        final lease = budget.reserveUnit(
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
        try {
          result = await operation.result;
          await operation.drained;
          capability = result.scene.capability;
          final svg = result.scene.svgScenes.isEmpty
              ? null
              : result.scene.svgScenes.single;
          geometry = svg == null
              ? {'pass': false, 'reason': 'no SVG scene'}
              : _geometry(
                  fixture: fixture,
                  input: input,
                  reference: reference,
                  scene: svg,
                  fixed: result.geometry,
                );
          fixedGeometry = _fixedEvidence(
            result.geometry,
            slotPrefix: 'slot',
            result: result,
          );
          if (reference['pngBase64'] != null) {
            final image = await result.scene.picture.toImage(320, 240);
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
            pixels = compareSpikePixels(
              actual,
              expected,
              exemptScope: scope.$1,
              samples: _samples(input, reference, actual),
            );
            pixelScope = scope.$2;
          } else {
            pixels = {'status': 'not-applicable', 'pass': false};
          }
        } on FixedPreparationFailure catch (error) {
          await operation.drained;
          status = 'refused';
          capability = error.capability;
          pixels = {'status': 'not-applicable', 'pass': false};
          geometry = {'pass': false, 'reason': 'typed refusal'};
          fixedGeometry = {'pass': true, 'refused': true};
        }
      } on Object catch (error) {
        status = 'error';
        errorText = error.toString();
        pixels = {'status': 'error', 'pass': false};
        geometry = {'pass': false, 'reason': errorText};
        fixedGeometry = {'pass': false, 'reason': errorText};
      } finally {
        result?.dispose();
        input.book.archive.close();
        if (budget.used.values.any((value) => value != 0)) {
          throw StateError('Clip/mask resource leak');
        }
      }
      final required = fixture['expectedCapability'] == 'required';
      final capabilityPass = required
          ? capability is CompleteSectionCapability &&
                result?.scene.geometry.completeness is CompleteGeometry
          : capability is UnsupportedSectionCapability;
      final rowPass = required
          ? geometry['pass'] == true &&
                fixedGeometry['pass'] == true &&
                pixels['pass'] == true &&
                pixels['d4'] != null
          : status == 'refused' && result == null;
      cases.add({
        'id': id,
        'variant': fixture['variant'],
        'required': required,
        'status': status,
        'error': errorText,
        'capability': capability?.runtimeType.toString(),
        'constructs': capability?.constructs.map((c) => c.identifier).toList(),
        'typedCapabilityPass': capabilityPass,
        'sourceGeometryComplete':
            result?.scene.geometry.completeness is CompleteGeometry,
        'geometry': geometry,
        'fixedGeometry': fixedGeometry,
        'pixels': pixels,
        'referenceDefects': pixelScope,
        'pass': capabilityPass && rowPass,
      });
    }
    final report = <String, Object?>{
      'row': 'clip-mask',
      'geometryToleranceCssPx': .5,
      'd7ComponentAlphaThreshold': d4ComponentAlphaThreshold,
      'd9GradientSampleMaximumDelta': d9GradientSampleMaximumDelta,
      'd10ChangedPixelMinimumDelta': d10ChangedPixelMinimumDelta,
      'corpusSHA256': sha256.convert(corpusBytes).toString(),
      'oracleSHA256': sha256.convert(oracleBytes).toString(),
      'referenceDefectsSHA256': defects.registrySHA256,
      'paintControlsSHA256': defects.controlsSHA256,
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

List<SpikeSampleRecord> _samples(
  SceneHarnessInput input,
  Map<String, Object?> reference,
  Uint8List actual,
) => [
  for (final sample in (reference['samples'] as List? ?? const []).cast<Map>())
    _sample(
      x: sample['x'] as int,
      y: sample['y'] as int,
      rgba: (sample['rgba'] as List).cast<int>(),
      actual: actual,
    ),
];

SpikeSampleRecord _sample({
  required int x,
  required int y,
  required List<int> rgba,
  required Uint8List actual,
}) {
  final offset = (y * 320 + x) * 4;
  final delta = List.generate(
    4,
    (channel) => (actual[offset + channel] - rgba[channel]).abs(),
  ).reduce(math.max);
  return SpikeSampleRecord(
    x: x,
    y: y,
    maximumChannelDelta: delta,
    classification: SpikeSamplePaintClass.solid,
    provenance: {'reason': 'clip/mask solid red paint'},
  );
}

Map<String, Object?> _geometry({
  required Map<String, Object?> fixture,
  required SceneHarnessInput input,
  required Map<String, Object?> reference,
  required SvgGraphicsScene scene,
  required SourceGeometry fixed,
}) {
  final channels = <Map<String, Object?>>[];
  final expected = (reference['elements'] as List).cast<Map>();
  var identity = true;
  for (final want in expected) {
    final id = want['id'] as String?;
    if (id == null) continue;
    final nodes = input.document.nodes.where((n) => n.id == id).toList();
    if (nodes.length != 1) {
      identity = false;
      continue;
    }
    final node = nodes.single;
    final source = node.namespaceUri == 'http://www.w3.org/2000/svg'
        ? scene.geometry
        : fixed;
    final fragments = source.fragments
        .where((f) => f.nodeIndex == node.index)
        .toList();
    if (fragments.length != 1) {
      identity = false;
      continue;
    }
    final fragment = fragments.single;
    final unit = _quadBounds(fragment);
    final box = (want['box'] as List).cast<num>();
    final delta = [
      unit.left - box[0],
      unit.top - box[1],
      unit.width - box[2],
      unit.height - box[3],
    ].map((v) => v.abs()).reduce(math.max);
    channels.add({
      'channel': 'source-box',
      'node': node.index,
      'tag': node.localName,
      'id': id,
      'native': [unit.left, unit.top, unit.width, unit.height],
      'reference': box,
      'maximumCssPxDelta': delta,
      'pass': delta <= .5,
    });
  }
  final clipPass = _evidence(
    geometry: scene.geometry,
    expectedClips: 2,
    expectedMasks: 1,
  );
  final maskCheck = _maskCheck(fixture, input, reference, scene);
  channels.addAll(maskCheck.$1);
  final maskPass = maskCheck.$2;
  final maximum = channels.isEmpty
      ? null
      : channels.map((c) => c['maximumCssPxDelta'] as double).reduce(math.max);
  return {
    'pass':
        identity &&
        scene.geometry.completeness is CompleteGeometry &&
        clipPass['pass'] == true &&
        maskPass &&
        channels.isNotEmpty &&
        channels.every((c) => c['pass'] == true),
    'identityPass': identity,
    'sourceGeometryComplete': scene.geometry.completeness is CompleteGeometry,
    'evidence': clipPass,
    'maximumCssPxDelta': maximum,
    'comparisons': channels.length,
    'channels': channels,
  };
}

ui.Rect _quadBounds(SourceFragment fragment) {
  final points = fragment.elementQuad
      .map(
        (p) => ui.Offset(
          fragment.sourceToUnit.a * p.x +
              fragment.sourceToUnit.c * p.y +
              fragment.sourceToUnit.e,
          fragment.sourceToUnit.b * p.x +
              fragment.sourceToUnit.d * p.y +
              fragment.sourceToUnit.f,
        ),
      )
      .toList();
  return ui.Rect.fromLTRB(
    points.map((p) => p.dx).reduce(math.min),
    points.map((p) => p.dy).reduce(math.min),
    points.map((p) => p.dx).reduce(math.max),
    points.map((p) => p.dy).reduce(math.max),
  );
}

Map<String, Object?> _evidence({
  required SourceGeometry geometry,
  required int expectedClips,
  required int expectedMasks,
}) {
  final clipIds = geometry.clips.map((c) => c.id).toSet();
  final maskIds = {for (final mask in geometry.masks) mask.id};
  final unresolvedClips = <String>[];
  final unresolvedMasks = <String>[];
  for (final fragment in geometry.fragments) {
    for (final id in fragment.clipIds) {
      if (!clipIds.contains(id)) unresolvedClips.add(id);
    }
    for (final id in fragment.maskIds) {
      if (!maskIds.contains(id)) unresolvedMasks.add(id);
    }
  }
  return {
    'pass':
        geometry.completeness is CompleteGeometry &&
        geometry.clips.length == expectedClips &&
        geometry.masks.length == expectedMasks &&
        unresolvedClips.isEmpty &&
        unresolvedMasks.isEmpty,
    'clips': geometry.clips.length,
    'masks': geometry.masks.length,
    'unresolvedClips': unresolvedClips,
    'unresolvedMasks': unresolvedMasks,
    'maskKinds': [for (final mask in geometry.masks) mask.kind.name],
  };
}

(List<Map<String, Object?>>, bool) _maskCheck(
  Map<String, Object?> fixture,
  SceneHarnessInput input,
  Map<String, Object?> reference,
  SvgGraphicsScene scene,
) {
  final masks = scene.geometry.masks;
  if (masks.length != 1) {
    return (
      [
        {
          'channel': 'mask-evidence',
          'native': masks.length,
          'reference': 1,
          'maximumCssPxDelta': 1.0,
          'pass': false,
        },
      ],
      false,
    );
  }
  final mask = masks.single;
  final maskNode = input.document.nodes.singleWhere(
    (n) => n.localName == 'mask' && n.id == 'm',
  );
  final kind = _maskKind(maskNode.attribute('style'));
  final expectedKind = switch (fixture['variant']) {
    'boundary' => 'alpha',
    _ => 'luminance',
  };
  final nested = fixture['variant'] == 'nested';
  final expectedLeft = nested ? 7.0 : 0.0;
  final expectedTop = nested ? 9.0 : 0.0;
  final regionDelta = [
    mask.region.left - expectedLeft,
    mask.region.top - expectedTop,
    mask.region.width - 320,
    mask.region.height - 240,
  ].map((v) => v.abs()).reduce(math.max);
  final expectedAlpha = kind == 'luminance' ? 128 : 255;
  final sampleAlpha = [
    mask.coverage.alphaAt(GeometryPoint(60.5, 60.5)),
    mask.coverage.alphaAt(GeometryPoint(132.5, 100.5)),
    mask.coverage.alphaAt(GeometryPoint(170.5, 90.5)),
  ];
  final pass =
      mask.kind.name == expectedKind &&
      mask.sourceNode == maskNode.index &&
      regionDelta <= .5 &&
      sampleAlpha[0] == expectedAlpha &&
      sampleAlpha[1] == expectedAlpha &&
      sampleAlpha[2] == 0;
  return (
    [
      {
        'channel': 'mask-region',
        'node': mask.sourceNode,
        'native': [
          mask.region.left,
          mask.region.top,
          mask.region.width,
          mask.region.height,
        ],
        'reference': [expectedLeft, expectedTop, 320, 240],
        'maximumCssPxDelta': regionDelta,
        'pass': regionDelta <= .5,
      },
      {
        'channel': 'mask-coverage',
        'kind': mask.kind.name,
        'referenceKind': expectedKind,
        'samples': sampleAlpha,
        'referenceSamples': [expectedAlpha, expectedAlpha, 0],
        'maximumCssPxDelta': mask.kind.name == expectedKind ? 0.0 : 1.0,
        'pass': mask.kind.name == expectedKind && pass,
      },
    ],
    pass,
  );
}

String _maskKind(String? style) {
  if (style == null) return 'luminance';
  for (final part in style.split(';')) {
    final colon = part.indexOf(':');
    if (colon < 0) continue;
    if (part.substring(0, colon).trim() != 'mask-type') continue;
    return part.substring(colon + 1).trim();
  }
  return 'luminance';
}

Map<String, Object?> _fixedEvidence(
  SourceGeometry geometry, {
  required String slotPrefix,
  required PreparedFixedScene result,
}) {
  // The fixed merged scene is the production handoff. Mask ids must resolve
  // after the slot transform; placement is checked on the module scene because
  // fixed_scene_geometry also composes the box transform for nested SVG.
  final placed = result.geometryForUnit(
    AffineTransform(1, 0, 0, 1, 0, 0),
    registryPrefix: slotPrefix,
  );
  final clipIds = placed.clips.map((c) => c.id).toSet();
  final maskIds = placed.masks.map((m) => m.id).toSet();
  return {
    'pass':
        placed.completeness is CompleteGeometry &&
        placed.fragments.every(
          (f) =>
              f.clipIds.every(clipIds.contains) &&
              f.maskIds.every(maskIds.contains),
        ) &&
        placed.masks.every((m) => m.id.startsWith('$slotPrefix:')),
    'clips': placed.clips.length,
    'masks': placed.masks.length,
    'maskIds': maskIds.toList(),
    'fragmentMaskIds': [
      for (final fragment in placed.fragments)
        if (fragment.maskIds.isNotEmpty) fragment.maskIds,
    ],
    'maskRegions': [
      for (final mask in placed.masks)
        [
          mask.region.left,
          mask.region.top,
          mask.region.width,
          mask.region.height,
        ],
    ],
  };
}
