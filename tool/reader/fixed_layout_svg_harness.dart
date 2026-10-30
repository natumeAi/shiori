import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';
import 'package:shiori/features/reader/data/cfi/cfi.dart';
import 'package:shiori/features/reader/data/resources/archive_reader_resource_source.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_fragment.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_preparation_plan.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene_admission.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_section_preparer.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_presentation.dart';
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
import 'fixed_layout_svg_samples.dart';

/// Dedicated production SVG row proof; failed fidelity remains a failed verdict.
final class FixedLayoutSvgHarness {
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
          preparationScale: const FixedPreparationScale.authored(),
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
          preparationScale: const FixedPreparationScale.authored(),
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
        var decisions = defects.unmeasured('No native SVG scene picture');
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
          // D3 eligibility is decided only by the shared evidence rules; the
          // scene harness passes the same scope through unchanged.
          final scope = defects.scope(fixture, reference, actual, expected);
          decisions = scope.$2;
          pixels = compareSpikePixels(
            actual,
            expected,
            exemptScope: scope.$1,
            samples: classifySvgSamples(
              document: input.document,
              elements: scene.elements,
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
        } else if (unsupported) {
          pixels = {'status': 'not-applicable', 'pass': false};
        }
        final capabilityPass = unsupported
            ? scene.capability is UnsupportedSectionCapability &&
                  scene.picture == null
            : scene.capability.isComplete &&
                  scene.geometry.completeness is CompleteGeometry;
        final tileImage = tile.picture == null
            ? null
            : await tile.picture!.toImage(320, 240);
        Map<String, Object?>? fixed;
        if (tileImage != null) {
          final tileRequest = FixedImageRequest(
            width: 320,
            height: 240,
            acquire: (_) async => FixedImageLease(tileImage, () {}),
          );
          fixed = await _fixedScene(
            fixture: fixture,
            input: input,
            reference: reference,
            dedicated: scene,
            dedicatedPixels: pixels,
            expectedCapability: fixture['expectedCapability'] as String,
            registry: registry,
            defects: defects,
            tile: tileRequest,
            directory: directory,
          );
        }
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
                  geometry['pass'] == true && pixels['pass'] == true) &&
              fixed?['pass'] == true,
          'reservation': {
            for (final r in budget.peaks.entries) r.key.name: r.value,
          },
          'fixed': fixed,
        });
        tileImage?.dispose();
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
      'd10ChangedPixelMinimumDelta': d10ChangedPixelMinimumDelta,
      'corpusSHA256': sha256.convert(corpusBytes).toString(),
      'oracleSHA256': sha256.convert(oracleBytes).toString(),
      'referenceDefectsSHA256': defects.registrySHA256,
      'paintControlsSHA256': defects.controlsSHA256,
      'cases': cases,
      'fixedPass': cases.every((c) => (c['fixed'] as Map?)?['pass'] == true),
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
) => compareSvgGeometryEvidence(
  document: input.document,
  page: input.page,
  elements: scene.elements,
  fragments: scene.geometry.fragments,
  completeness: scene.geometry.completeness,
  reference: reference,
);

/// Independent source-channel comparison, shared with the negative tests.
Map<String, Object?> compareSvgGeometryEvidence({
  required SourceDocument document,
  required SourcePageId page,
  required List<SvgGraphicsElement> elements,
  required List<SourceFragment> fragments,
  required GeometryCompleteness completeness,
  required Map<String, Object?> reference,
}) {
  final channels = <Map<String, Object?>>[];
  final svgNodes = document.nodes
      .where(
        (n) =>
            n.namespaceUri == 'http://www.w3.org/2000/svg' &&
            n.localName != null,
      )
      .toList();
  final expected = ((reference['graphics'] as Map)['elements'] as List)
      .cast<Map>();
  var identity = svgNodes.length == expected.length;
  for (var j = 0; j < svgNodes.length && j < expected.length; j++) {
    final node = svgNodes[j], want = expected[j];
    if (want['tag'] != node.localName ||
        want['id'] != (node.id == '' ? null : node.id)) {
      identity = false;
    }
  }
  for (final fragment in fragments) {
    final position = SourcePosition(nodeIndex: fragment.nodeIndex, offset: 0);
    final cfi = Cfi.export(document, position);
    if (Cfi.resolveLocal(document, cfi).start != position ||
        fragment.page != page) {
      identity = false;
    }
  }
  const supported = {
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
  };
  var requiredCount = 0;
  for (var j = 0; j < svgNodes.length; j++) {
    final node = svgNodes[j];
    if (!supported.contains(node.localName)) continue;
    if (_insideDefinition(document, node.index)) continue;
    requiredCount++;
    final matches = elements
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
  final elementKeys = <String, int>{};
  for (final element in elements) {
    final key = _evidenceKey(element.nodeIndex, element.paintOrdinal);
    elementKeys[key] = (elementKeys[key] ?? 0) + 1;
  }
  final fragmentKeys = <String, int>{};
  for (final fragment in fragments) {
    final key = _evidenceKey(fragment.nodeIndex, fragment.paintOrdinal);
    fragmentKeys[key] = (fragmentKeys[key] ?? 0) + 1;
  }
  final fragmentCoverage =
      elements.isNotEmpty &&
      elements.length == fragments.length &&
      elements.every(
        (e) => fragmentKeys[_evidenceKey(e.nodeIndex, e.paintOrdinal)] == 1,
      ) &&
      fragments.every(
        (f) => elementKeys[_evidenceKey(f.nodeIndex, f.paintOrdinal)] == 1,
      );
  final expectedInstances = _expectedUseInstances(document);
  final useNodes = {
    for (final node in document.nodes)
      if (node.localName == 'use') node.index,
  };
  final actualInstances = elements
      .where((e) => e.instancePath.isNotEmpty)
      .toList();
  // Marker instances are owned by the marker feature; only use-rooted chains
  // belong to this source mapping.
  final useInstances = actualInstances
      .where((e) => e.instancePath.any(useNodes.contains))
      .toList();
  final useInstanceCoverage =
      useInstances.every(
        (e) => expectedInstances.any(
          (r) => r.node == e.nodeIndex && _samePath(r.path, e.instancePath),
        ),
      ) &&
      expectedInstances.every(
        (r) =>
            elements
                .where(
                  (e) =>
                      e.nodeIndex == r.node &&
                      _samePath(e.instancePath, r.path),
                )
                .length ==
            1,
      );
  int? rootIndex;
  for (final node in svgNodes) {
    if (node.localName == 'svg') {
      rootIndex = node.index;
      break;
    }
  }
  final paintOrderEvidence = rootIndex == null
      ? <String, Object?>{'pass': false, 'reason': 'no SVG root'}
      : _globalPaintOrderEvidence(document, rootIndex, elements);
  final paintOrder = paintOrderEvidence['pass'] == true;
  final complete = completeness is CompleteGeometry;
  final maximum = channels.isEmpty
      ? null
      : channels.map((c) => c['maximumCssPxDelta'] as double).reduce(math.max);
  return {
    'pass':
        identity &&
        complete &&
        fragmentCoverage &&
        useInstanceCoverage &&
        paintOrder &&
        channels.isNotEmpty &&
        channels.every((c) => c['pass'] == true),
    'identityPass': identity,
    'fragmentCoveragePass': fragmentCoverage,
    'useInstancePass': useInstanceCoverage,
    'paintOrderPass': paintOrder,
    'paintOrderEvidence': paintOrderEvidence,
    'sourceGeometryComplete': complete,
    'requiredElements': requiredCount,
    'requiredInstances': expectedInstances.length,
    'requiredInstanceKeys': [
      for (final r in expectedInstances) '${r.node}:${r.path.join('.')}',
    ],
    'actualInstanceKeys': [
      for (final e in useInstances)
        '${e.nodeIndex}:${e.instancePath.join('.')}',
    ],
    'maximumCssPxDelta': maximum,
    'comparisons': channels.length,
    'channels': channels,
  };
}

String _evidenceKey(int node, int ordinal) => '$node:$ordinal';

bool _samePath(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

final class _SvgRequiredInstance {
  _SvgRequiredInstance(this.node, this.path);
  final int node;
  final List<int> path;
}

List<_SvgRequiredInstance> _expectedUseInstances(SourceDocument document) {
  final result = <_SvgRequiredInstance>[];
  void walk(int index, List<int> path) {
    final node = document.node(index);
    if (node.localName == 'use') {
      final target = _useTarget(
        document,
        node.attribute('href') ?? node.attribute('xlink:href'),
      );
      if (target == null) return;
      walk(target, [...path, index]);
      return;
    }
    result.add(_SvgRequiredInstance(index, path));
    if (!const {
      'svg',
      'g',
      'symbol',
      'marker',
      'pattern',
    }.contains(node.localName)) {
      return;
    }
    for (final child in node.children) {
      final childNode = document.node(child);
      if (childNode.localName == null ||
          const {
            'defs',
            'symbol',
            'linearGradient',
            'radialGradient',
            'pattern',
            'marker',
            'title',
            'desc',
          }.contains(childNode.localName)) {
        continue;
      }
      walk(child, path);
    }
  }

  for (final node in document.nodes) {
    if (node.localName != 'use' || _insideDefinition(document, node.index)) {
      continue;
    }
    walk(node.index, const []);
  }
  return result;
}

int? _useTarget(SourceDocument document, String? href) {
  if (href == null || !href.startsWith('#') || href.length == 1) return null;
  final id = href.substring(1);
  final matches = document.nodes
      .where((node) => node.id == id && node.localName != null)
      .toList();
  return matches.length == 1 ? matches.single.index : null;
}

bool _insideDefinition(SourceDocument document, int index) {
  var parent = document.node(index).parentIndex;
  while (parent != null) {
    final node = document.node(parent);
    if (const {
      'defs',
      'symbol',
      'marker',
      'pattern',
    }.contains(node.localName)) {
      return true;
    }
    parent = node.parentIndex;
  }
  return false;
}

final class _SvgPaintRef {
  _SvgPaintRef(this.node, this.path);
  final int node;
  final List<int> path;
}

/// One expanded global paint sequence: source order with use targets expanded
/// at the referencing node. Marker instances are excluded as before.
Map<String, Object?> _globalPaintOrderEvidence(
  SourceDocument document,
  int rootIndex,
  List<SvgGraphicsElement> elements,
) {
  final expected = _expectedPaintSequence(document, rootIndex);
  final ranks = <String, int>{
    for (var i = 0; i < expected.length; i++)
      _paintKey(expected[i].node, expected[i].path): i,
  };
  final markerNodes = {
    for (final node in document.nodes)
      if (const {'marker-start', 'marker-mid', 'marker-end'}.any(
        (attribute) => node.attribute(attribute)?.startsWith('url(') == true,
      ))
        node.index,
  };
  final useNodes = {
    for (final node in document.nodes)
      if (node.localName == 'use') node.index,
  };
  final ordered = elements.where((element) {
    if (element.instancePath.isEmpty) return true;
    final root = element.instancePath.first;
    if (useNodes.contains(root)) return true;
    return !markerNodes.contains(root);
  }).toList()..sort((a, b) => a.paintOrdinal.compareTo(b.paintOrdinal));
  final nativeOrder = <String>[];
  var pass = ordered.isNotEmpty && ranks.isNotEmpty;
  int? previous;
  for (final element in ordered) {
    final key = _paintKey(element.nodeIndex, element.instancePath);
    nativeOrder.add(key);
    final rank = ranks[key];
    if (rank == null) {
      pass = false;
      continue;
    }
    if (previous != null && rank <= previous) pass = false;
    previous = rank;
  }
  return {
    'pass': pass,
    'expected': [for (final ref in expected) _paintKey(ref.node, ref.path)],
    'native': nativeOrder,
  };
}

String _paintKey(int node, List<int> path) => '$node:${path.join('.')}';

List<_SvgPaintRef> _expectedPaintSequence(
  SourceDocument document,
  int rootIndex,
) {
  final result = <_SvgPaintRef>[];
  const containers = {'svg', 'g', 'symbol', 'marker', 'pattern'};
  const skipped = {
    'defs',
    'symbol',
    'linearGradient',
    'radialGradient',
    'pattern',
    'marker',
    'title',
    'desc',
  };
  void walk(int index, List<int> path) {
    result.add(_SvgPaintRef(index, List.unmodifiable(path)));
    final node = document.node(index);
    if (document.attribute(index, 'display') == 'none') return;
    if (node.localName == 'use') {
      final target = _useTarget(
        document,
        node.attribute('href') ?? node.attribute('xlink:href'),
      );
      if (target != null) walk(target, [...path, index]);
      return;
    }
    if (!containers.contains(node.localName)) return;
    for (final child in node.children) {
      final childNode = document.node(child);
      if (childNode.localName == null ||
          skipped.contains(childNode.localName)) {
        continue;
      }
      walk(child, path);
    }
  }

  walk(rootIndex, const []);
  return result;
}

/// Runs the same fixture through the production fixed-scene route and compares
/// the module scene, source geometry and D4 sub-rules with the dedicated path.
Future<Map<String, Object?>> _fixedScene({
  required Map<String, Object?> fixture,
  required SceneHarnessInput input,
  required Map<String, Object?> reference,
  required SvgGraphicsScene dedicated,
  required Map<String, Object?> dedicatedPixels,
  required String expectedCapability,
  required FontRegistry registry,
  required SpikeReferenceDefects defects,
  required FixedImageRequest tile,
  required Directory directory,
}) async {
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
    images: {'/tile.svg': tile},
  );
  final plan = FixedPreparationPlan.inspect(
    source,
    scale: const FixedPreparationScale.authored(),
  );
  String? refusedCapability;
  final fixed = <String, Object?>{
    'status': 'plan',
    'expectedCapability': expectedCapability,
    'capability': plan.capability.runtimeType.toString(),
    'constructs': plan.capability.constructs.map((c) => c.identifier).toList(),
    'svgPlans': plan.svgPlans.length,
    'svgPlanCapabilities': [
      for (final p in plan.svgPlans)
        {
          'capability': p.capability.runtimeType.toString(),
          'constructs': p.capability.constructs
              .map((c) => c.identifier)
              .toList(),
          'resources': {
            for (final r in SceneResource.values) r.name: p.resources[r] ?? 0,
          },
        },
    ],
    'resources': {
      for (final r in SceneResource.values) r.name: plan.resources[r] ?? 0,
    },
    'picture': false,
    'elements': 0,
    'fragments': 0,
    'svgFragments': 0,
    'elementPass': false,
    'fragmentPass': false,
    'pixelPass': false,
    'd4Parity': false,
    'capabilityPass': false,
    'parityPass': false,
  };
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
    final svg = result.scene.svgScenes.isEmpty
        ? null
        : result.scene.svgScenes.single;
    fixed['status'] = 'prepared';
    fixed['capability'] = result.scene.capability.runtimeType.toString();
    fixed['constructs'] = result.scene.capability.constructs
        .map((c) => c.identifier)
        .toList();
    fixed['picture'] = true;
    fixed['fragments'] = result.scene.geometry.fragments.length;
    fixed['sourceGeometryComplete'] =
        result.scene.geometry.completeness is CompleteGeometry;
    fixed['geometry'] = svg == null
        ? <String, Object?>{'pass': false, 'reason': 'no fixed SVG scene'}
        : _geometry(svg, input, reference);
    final dedicatedElements = dedicated.elements;
    final fixedElements = svg?.elements ?? const <SvgGraphicsElement>[];
    fixed['elements'] = fixedElements.length;
    var elementPass = dedicatedElements.length == fixedElements.length;
    final elementDiffs = <Map<String, Object?>>[];
    for (
      var i = 0;
      i < fixedElements.length && i < dedicatedElements.length;
      i++
    ) {
      final delta = _elementDelta(dedicatedElements[i], fixedElements[i]);
      if (delta > 1e-6) {
        elementPass = false;
        elementDiffs.add({
          'index': i,
          'node': dedicatedElements[i].nodeIndex,
          'maximumDelta': delta,
        });
      }
    }
    fixed['elementPass'] = elementPass;
    fixed['elementDiffs'] = elementDiffs;
    final wanted = <int, int>{};
    for (final element in dedicatedElements) {
      wanted[element.nodeIndex] = (wanted[element.nodeIndex] ?? 0) + 1;
    }
    final actual = <int, int>{};
    for (final fragment in result.scene.geometry.fragments) {
      if (wanted.containsKey(fragment.nodeIndex)) {
        actual[fragment.nodeIndex] = (actual[fragment.nodeIndex] ?? 0) + 1;
      }
    }
    final fragmentPass =
        wanted.length == actual.length &&
        wanted.entries.every((e) => actual[e.key] == e.value);
    fixed['fragmentPass'] = fragmentPass;
    fixed['svgFragments'] = actual.values.fold<int>(0, (a, b) => a + b);
    final capabilityPass = switch (expectedCapability) {
      'required' => result.scene.capability.isComplete,
      'unsupported' => result.scene.capability is UnsupportedSectionCapability,
      'malformed' => result.scene.capability is MalformedSectionCapability,
      _ => false,
    };
    fixed['capabilityPass'] = capabilityPass;
    var d4Parity = false, pixelPass = false;
    if (reference['pngBase64'] != null) {
      final native = await result.scene.picture.toImage(320, 240);
      late Uint8List actualBytes;
      try {
        actualBytes = (await native.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        ))!.buffer.asUint8List();
        File('${directory.path}/fixed-${fixture['id']}.png').writeAsBytesSync(
          (await native.toByteData(format: ui.ImageByteFormat.png))!.buffer
              .asUint8List(),
        );
      } finally {
        native.dispose();
      }
      final expectedBytes = await _decode(reference['pngBase64'] as String);
      final scope = defects.scope(
        fixture,
        reference,
        actualBytes,
        expectedBytes,
      );
      final pixels = compareSpikePixels(
        actualBytes,
        expectedBytes,
        exemptScope: scope.$1,
        samples: svg == null
            ? null
            : classifySvgSamples(
                document: input.document,
                elements: svg.elements,
                clips: svg.geometry.clips,
                fragments: svg.geometry.fragments,
                paints: svg.geometry.paint,
                referenceComputedPaint: svgReferenceComputedPaint(
                  document: input.document,
                  reference: reference,
                ),
                samples: (reference['samples'] as List).cast<Map>(),
                actual: actualBytes,
              ),
      );
      fixed['pixels'] = pixels;
      pixelPass = pixels['pass'] == true;
      d4Parity = _sameD4(pixels, dedicatedPixels);
    }
    fixed['pixelPass'] = pixelPass;
    fixed['d4Parity'] = d4Parity;
    fixed['parityPass'] =
        capabilityPass &&
        elementPass &&
        fragmentPass &&
        (reference['pngBase64'] == null || d4Parity);
  } on FixedPreparationFailure catch (error) {
    refusedCapability = error.capability.runtimeType.toString();
    await operation.drained;
    fixed['status'] = 'refused';
    fixed['capability'] = refusedCapability;
    fixed['constructs'] = error.capability.constructs
        .map((c) => c.identifier)
        .toList();
    final capabilityPass = switch (expectedCapability) {
      'unsupported' => error.capability is UnsupportedSectionCapability,
      'malformed' => error.capability is MalformedSectionCapability,
      _ => false,
    };
    final dedicatedConstructs = dedicated.capability.constructs
        .map((c) => c.identifier)
        .toSet();
    final fixedConstructs = error.capability.constructs
        .map((c) => c.identifier)
        .toSet();
    fixed['capabilityPass'] = capabilityPass;
    fixed['parityPass'] =
        capabilityPass &&
        dedicated.capability is UnsupportedSectionCapability &&
        dedicated.picture == null &&
        (fixedConstructs.containsAll(dedicatedConstructs) ||
            dedicatedConstructs.containsAll(fixedConstructs));
  } on Object catch (error) {
    try {
      await operation.drained;
    } on Object {
      // The result error is already recorded below.
    }
    fixed['status'] = 'error';
    fixed['error'] = error.toString();
    fixed['parityPass'] = false;
  } finally {
    result?.dispose();
    fixed['budgetUsedZero'] = shared.used.values.every((v) => v == 0);
  }
  fixed['pass'] =
      fixed['capabilityPass'] == true &&
      fixed['parityPass'] == true &&
      fixed['budgetUsedZero'] == true &&
      (expectedCapability == 'required'
          ? (fixed['status'] == 'prepared' &&
                fixed['sourceGeometryComplete'] == true &&
                (fixed['geometry'] as Map?)?['pass'] == true &&
                fixed['pixelPass'] == true)
          : fixed['status'] == 'refused');
  return fixed;
}

double _elementDelta(SvgGraphicsElement a, SvgGraphicsElement b) {
  final values = <double>[
    a.transform.a - b.transform.a,
    a.transform.b - b.transform.b,
    a.transform.c - b.transform.c,
    a.transform.d - b.transform.d,
    a.transform.e - b.transform.e,
    a.transform.f - b.transform.f,
    a.bounds.left - b.bounds.left,
    a.bounds.top - b.bounds.top,
    a.bounds.right - b.bounds.right,
    a.bounds.bottom - b.bounds.bottom,
  ];
  return values.map((v) => v.abs()).reduce(math.max);
}

bool _sameD4(Map<String, Object?> a, Map<String, Object?> b) {
  final ad = a['d4'] as Map?, bd = b['d4'] as Map?;
  if (ad == null || bd == null) return false;
  for (final key in const [
    'interior',
    'edgeNeighbourhood',
    'supportBounds',
    'components',
    'samples',
  ]) {
    final x = ad[key] as Map?, y = bd[key] as Map?;
    if (x == null || y == null || x['pass'] != y['pass']) return false;
  }
  return true;
}
