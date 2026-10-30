import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:shiori/features/reader/data/cfi/cfi.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_fragment.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';

import 'fixed_layout_scene_input.dart';

Map<String, Object?> measureSceneGeometry(
  SceneHarnessInput input,
  FixedScene scene,
  Map<String, Object?> reference,
) {
  final comparisons = <Map<String, Object?>>[], missing = <String>[];
  var maximum = 0.0;
  void compare(String channel, String key, List<double> a, List<double> b) {
    if (a.length != b.length || a.any((v) => !v.isFinite)) {
      missing.add('$channel:$key');
      return;
    }
    final delta = List.generate(
      a.length,
      (i) => (a[i] - b[i]).abs(),
    ).reduce(math.max);
    maximum = math.max(maximum, delta);
    comparisons.add({
      'channel': channel,
      'key': key,
      'native': a,
      'reference': b,
      'maximumCssPxDelta': delta,
    });
  }

  final elements = (reference['elements'] as List).cast<Map<String, Object?>>();
  for (var i = 0; i < elements.length; i++) {
    final expected = elements[i];
    final nodes = input.document.nodes.where(
      (n) =>
          n.attribute('data-source') == expected['role'] &&
          (n.id == '' ? null : n.id) == expected['id'],
    );
    if (nodes.length != 1) {
      missing.add('element identity $i');
      continue;
    }
    final node = nodes.single;
    final boxes = scene.boxes.where((b) => b.nodeIndex == node.index);
    SvgGraphicsElement? svg;
    for (final sceneSvg in scene.svgScenes) {
      for (final element in sceneSvg.elements) {
        if (element.nodeIndex == node.index) svg = element;
      }
    }
    final box = boxes.length == 1 ? boxes.single : null;
    if (box == null && svg == null) {
      missing.add('element box $i');
      continue;
    }
    final r = box?.borderBox ?? svg!.bounds;
    final transform = box?.transform ?? svg!.transform;
    final points = [
      r.topLeft,
      r.topRight,
      r.bottomRight,
      r.bottomLeft,
    ].map((p) => fixedMap(transform, p));
    final left = points.map((p) => p.dx).reduce(math.min),
        right = points.map((p) => p.dx).reduce(math.max),
        top = points.map((p) => p.dy).reduce(math.min),
        bottom = points.map((p) => p.dy).reduce(math.max);
    compare('box', i.toString(), [
      left,
      top,
      right - left,
      bottom - top,
    ], (expected['box'] as List).map((n) => (n as num).toDouble()).toList());
    final opacity =
        box?.style.authored.opacity ??
        double.tryParse(svg?.paint['opacity'] ?? '') ??
        1;
    compare(
      'opacity',
      i.toString(),
      [opacity],
      [double.parse(expected['opacity'] as String)],
    );
    final rawTransform = expected['transform'] as String;
    final refMatrix = rawTransform == 'none'
        ? [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]
        : rawTransform.startsWith('matrix(')
        ? rawTransform
              .substring(7, rawTransform.length - 1)
              .split(',')
              .map((v) => double.parse(v.trim()))
              .toList()
        : null;
    if (box != null && refMatrix != null) {
      final t = box.localTransform;
      for (final p in [
        ui.Offset.zero,
        ui.Offset(r.width, 0),
        ui.Offset(0, r.height),
        ui.Offset(r.width, r.height),
      ]) {
        final actual = fixedMap(t, p);
        compare(
          'transform',
          '$i:${p.dx},${p.dy}',
          [actual.dx, actual.dy],
          [
            refMatrix[0] * p.dx + refMatrix[2] * p.dy + refMatrix[4],
            refMatrix[1] * p.dx + refMatrix[3] * p.dy + refMatrix[5],
          ],
        );
      }
      final snap = expected['computedStyle'] as Map<String, Object?>;
      final origin = (snap['transform-origin'] as String)
          .split(' ')
          .take(2)
          .map((v) => double.parse(v.replaceAll('px', '')))
          .toList();
      compare('transform-origin', i.toString(), [
        box.transformOrigin.dx,
        box.transformOrigin.dy,
      ], origin);
    } else if (box == null && rawTransform != 'none') {
      missing.add('svg-css-transform $i');
    } else if (box != null) {
      missing.add('2D transform $i');
    }
    final visibility =
        box?.style.authored.visibility.name ??
        svg?.paint['visibility'] ??
        'visible';
    if (visibility != expected['visibility']) {
      missing.add('visibility $i');
    }
  }
  final body = input.document.bodyIndex ?? input.document.documentElementIndex;
  final nodes = <int>[];
  void walk(int index) {
    final node = input.document.node(index);
    if (node.isCharacterData) nodes.add(index);
    for (final child in node.children) {
      walk(child);
    }
  }

  walk(body);
  final texts = (reference['texts'] as List).cast<Map<String, Object?>>();
  for (var i = 0; i < texts.length; i++) {
    final expected = texts[i],
        baseline = expected['baseline'] as Map<String, Object?>;
    if (baseline['available'] != true) continue;
    final fragments = scene.geometry.fragments.where(
      (f) => f.kind == SourceFragmentKind.xhtmlText && f.nodeIndex == nodes[i],
    );
    if (fragments.length != 1) {
      missing.add('text $i');
      continue;
    }
    final f = fragments.single, first = f.clusters.first;
    if (expected['computedStyle'] case final Map snapshot) {
      final style = inputStyle(scene, nodes[i]);
      if (style == null) {
        missing.add('computed text style $i');
      } else {
        for (final (property, actual) in [
          ('font-size', style.fontSize),
          ('font-weight', style.fontWeight.toDouble()),
          ('letter-spacing', style.letterSpacing),
          ('word-spacing', style.authored.wordSpacing),
          ('text-indent', style.textIndent.resolve(320) ?? 0),
        ]) {
          final raw = snapshot[property] as String;
          final wanted = raw == 'normal'
              ? 0.0
              : double.tryParse(raw.replaceAll('px', ''));
          if (wanted == null) {
            missing.add('computed $property $i');
          } else {
            compare('computed-$property', '$i', [actual], [wanted]);
          }
        }
        final lineHeight =
            style.lineHeight.px ??
            (style.lineHeight.multiplier == null
                ? null
                : style.lineHeight.multiplier! * style.fontSize);
        final expectedHeight = double.tryParse(
          (snapshot['line-height'] as String).replaceAll('px', ''),
        );
        if (lineHeight != null && expectedHeight != null) {
          compare('computed-line-height', '$i', [lineHeight], [expectedHeight]);
        } else if (snapshot['line-height'] != 'normal') {
          missing.add('computed line-height $i');
        }
        for (final (property, actual) in [
          ('font-style', style.fontStyle.name),
          ('text-align', style.textAlign.name),
          (
            'white-space',
            style.whiteSpace.name
                .replaceAll('Wrap', '-wrap')
                .replaceAll('Line', '-line'),
          ),
          (
            'vertical-align',
            style.verticalAlign.name == 'superscript'
                ? 'super'
                : style.verticalAlign.name,
          ),
        ]) {
          if (snapshot[property] != actual) {
            missing.add('computed $property $i');
          }
        }
        final family = (snapshot['font-family'] as String)
            .replaceAll('"', '')
            .replaceAll("'", '')
            .toLowerCase();
        if (style.fontFamilies.map((f) => f.toLowerCase()).join(', ') !=
            family) {
          missing.add('computed font-family $i');
        }
        // Decoration propagation is a paint property: descendant computed
        // text-decoration:none does not cancel the ancestor's underline.
      }
    }
    final actual = fixedMap(
      f.sourceToUnit,
      ui.Offset(first.baselineStart.x, first.baselineStart.y),
    );
    compare(
      'baseline',
      i.toString(),
      [actual.dx, actual.dy],
      [(baseline['x'] as num).toDouble(), (baseline['y'] as num).toDouble()],
    );
    if (expected['boundaryBaselines'] case final List boundaries) {
      for (final raw in (expected['fixtureRun'] as Map)['clusterMap'] as List) {
        final range = (raw as List).cast<int>();
        final clusters = f.clusters
            .where((c) => c.range.start >= range[0] && c.range.end <= range[1])
            .toList();
        if (clusters.isEmpty ||
            clusters.first.range.start != range[0] ||
            clusters.last.range.end != range[1]) {
          missing.add('cluster partition $i:${range[0]}');
          continue;
        }
        for (final (offset, point) in [
          (range[0], clusters.first.baselineStart),
          (range[1], clusters.last.baselineEnd),
        ]) {
          final wanted = boundaries[offset] as Map;
          if (wanted['available'] != true) {
            missing.add('boundary baseline $i:$offset');
            continue;
          }
          final native = fixedMap(f.sourceToUnit, ui.Offset(point.x, point.y));
          compare(
            'cluster-boundary-baseline',
            '$i:$offset',
            [native.dx, native.dy],
            [(wanted['x'] as num).toDouble(), (wanted['y'] as num).toDouble()],
          );
        }
      }
      continue;
    }
    final placement = scene.texts.firstWhere(
      (t) => t.block.map.entries.any((e) => e.nodeIndex == f.nodeIndex),
    );
    final widths =
        (expected['advance'] as Map<String, Object?>)['prefixWidths'] as List;
    // Only contextual endpoints from the painted paragraph are admitted.
    // A wrapped run lacks oracle per-line baselines; keep it unverified.
    final lines = placement.paragraph.lines;
    if (lines.length > 1) {
      missing.add('per-line unsnapped baseline for text $i');
      continue;
    }
    final fixtureRun = expected['fixtureRun'] as Map<String, Object?>;
    for (final range in fixtureRun['clusterMap'] as List) {
      final start = (range as List)[0] as int, end = range[1] as int;
      final clusters = f.clusters
          .where((c) => c.range.start >= start && c.range.end <= end)
          .toList();
      if (clusters.isEmpty ||
          clusters.first.range.start != start ||
          clusters.last.range.end != end) {
        missing.add('cluster partition $i:$start');
        continue;
      }
      final origin = f.clusters.first.baselineStart.x;
      compare(
        'advance',
        '$i:$start-$end',
        [
          clusters.first.baselineStart.x - origin,
          clusters.last.baselineEnd.x - origin,
        ],
        [(widths[start] as num).toDouble(), (widths[end] as num).toDouble()],
      );
    }
  }
  return {
    'maximumCssPxDelta': comparisons.isEmpty ? null : maximum,
    'pass': comparisons.isNotEmpty && maximum <= .5 && missing.isEmpty,
    'comparisons': comparisons,
    'unverified': missing,
    'rangeBoxes': 'diagnostic-only',
    'clusterMap': 'WebKit measured ligature controls; production XHTML exports Paragraph graphemes',
  };
}

ComputedStyle? inputStyle(FixedScene scene, int node) {
  for (final placement in scene.texts) {
    final offset = placement.block.map.paraOffsetOf(node, 0);
    if (offset == null) continue;
    for (final run in placement.block.runs) {
      if (run.start <= offset && run.end > offset) return run.style;
    }
  }
  return null;
}

/// Native text-only paint coverage for D8, taken from the scene's retained
/// exact text alpha footprints rather than the full composed raster.
Uint8List collectSceneTextCoverage(
  FixedScene scene, {
  int width = 320,
  int height = 240,
}) {
  final coverage = Uint8List(width * height);
  for (final paint in scene.geometry.paint.where(
    (p) => p.kind == GeometryPaintKind.text && p.alphaFootprint != null,
  )) {
    final footprint = paint.alphaFootprint!;
    for (var y = 0; y < footprint.height; y++) {
      for (var x = 0; x < footprint.width; x++) {
        if (footprint.alpha[y * footprint.width + x] == 0) continue;
        final unit = fixedMap(
          footprint.transform,
          ui.Offset(
            footprint.origin.x + (x + .5) * footprint.pixelSize,
            footprint.origin.y + (y + .5) * footprint.pixelSize,
          ),
        );
        final px = unit.dx.floor(), py = unit.dy.floor();
        if (px < 0 || px >= width || py < 0 || py >= height) continue;
        coverage[py * width + px] = 1;
      }
    }
  }
  return coverage;
}

/// Oracle XHTML text geometry as LTRB viewport CSS-pixel boxes.
List<List<double>> referenceSceneTextBoxes(Map<String, Object?> reference) => [
  for (final rawNode in (reference['texts'] as List? ?? []))
    for (final rawCluster in ((rawNode as Map)['clusters'] as List? ?? []))
      for (final rawBox in ((rawCluster as Map)['boxes'] as List? ?? []))
        () {
          final box = (rawBox as List).cast<num>();
          final left = box[0].toDouble(), top = box[1].toDouble();
          return [left, top, left + box[2].toDouble(), top + box[3].toDouble()];
        }(),
];

/// D8 text-presence gate: every XHTML grapheme is painted exactly once with an
/// exact source mapping. Geometry stays at 0.5 CSS px; raster parity is A5.
Map<String, Object?> measureSceneTextConservation(
  SceneHarnessInput input,
  FixedScene scene,
) {
  final fragments = scene.geometry.fragments
      .where((f) => f.kind == SourceFragmentKind.xhtmlText)
      .toList();
  if (fragments.isEmpty) {
    return {
      'applicable': false,
      'pass': true,
      'reason': 'no authored XHTML text',
    };
  }
  final textPaints = scene.geometry.paint
      .where((p) => p.kind == GeometryPaintKind.text)
      .toList();
  var clusterCount = 0;
  var partitions = true, paintedOnce = true, sourceMapped = true;
  final seen = <String>{};
  final mismatches = <Map<String, Object?>>[];
  final runs = <Map<String, Object?>>[];
  for (final fragment in fragments) {
    final text = input.document.node(fragment.nodeIndex).text ?? '';
    final ranges = [
      for (final cluster in fragment.clusters)
        [cluster.range.start, cluster.range.end],
    ];
    var cursor = 0;
    for (final range in ranges) {
      if (range[0] != cursor || range[1] <= range[0]) partitions = false;
      cursor = range[1];
      final key = '${fragment.nodeIndex}:${range[0]}-${range[1]}';
      if (!seen.add(key)) paintedOnce = false;
      final position = SourcePosition(
        nodeIndex: fragment.nodeIndex,
        offset: range[0],
      );
      final cfi = Cfi.export(input.document, position);
      if (Cfi.resolveLocal(input.document, cfi).start != position) {
        sourceMapped = false;
      }
    }
    final range = fragment.textRange;
    if (range == null ||
        range.start != 0 ||
        range.end != text.length ||
        cursor != text.length) {
      partitions = false;
    }
    final matching = textPaints
        .where((p) => p.paintOrdinal == fragment.paintOrdinal)
        .toList();
    final exactPaint =
        matching.length == 1 &&
        matching.single.exactCoverage &&
        matching.single.alphaFootprint != null;
    if (!exactPaint) paintedOnce = false;
    clusterCount += ranges.length;
    runs.add({
      'node': fragment.nodeIndex,
      'textLength': text.length,
      'ranges': ranges,
      'paintOrdinal': fragment.paintOrdinal,
      'paintMatches': matching.length,
      'exactCoverage': matching.length == 1
          ? matching.single.exactCoverage
          : false,
      'exactSourceMapping': sourceMapped,
    });
    if (!partitions || !exactPaint) {
      mismatches.add({
        'node': fragment.nodeIndex,
        'ranges': ranges,
        'paintOrdinal': fragment.paintOrdinal,
        'paintMatches': matching.length,
        'partition': partitions,
        'exactPaint': exactPaint,
      });
    }
  }
  final pass =
      fragments.isNotEmpty &&
      clusterCount > 0 &&
      partitions &&
      paintedOnce &&
      sourceMapped &&
      mismatches.isEmpty;
  return {
    'applicable': true,
    'definition':
        'every XHTML grapheme painted exactly once with exact source mapping',
    'pass': pass,
    'textNodes': fragments.length,
    'graphemes': clusterCount,
    'exactlyOnce': paintedOnce,
    'exactSourceMapping': sourceMapped,
    'partition': partitions,
    'runs': runs,
    'mismatches': mismatches,
  };
}

List<Map<String, Object?>> exportSceneFragments(FixedScene scene) => [
  for (final f in scene.geometry.fragments)
    {
      'nodeIndex': f.nodeIndex,
      'kind': f.kind.name,
      'paintOrdinal': f.paintOrdinal,
      'effectiveOpacity': f.effectiveOpacity,
      'clipIds': f.clipIds,
      'sourceToUnit': [
        f.sourceToUnit.a,
        f.sourceToUnit.b,
        f.sourceToUnit.c,
        f.sourceToUnit.d,
        f.sourceToUnit.e,
        f.sourceToUnit.f,
      ],
      'textRange': f.textRange == null
          ? null
          : [f.textRange!.start, f.textRange!.end],
      'clusters': [
        for (final c in f.clusters)
          {
            'range': [c.range.start, c.range.end],
            'provenance': c.provenance.name,
            'quad': [
              for (final p in c.quad) [p.x, p.y],
            ],
            'baselineStart': [c.baselineStart.x, c.baselineStart.y],
            'baselineEnd': [c.baselineEnd.x, c.baselineEnd.y],
          },
      ],
    },
];

bool sceneCfiRoundTrips(SceneHarnessInput input, FixedScene scene) {
  for (final f in scene.geometry.fragments) {
    final position = SourcePosition(
      nodeIndex: f.nodeIndex,
      offset: f.textRange?.start ?? 0,
    );
    final cfi = Cfi.export(input.document, position);
    if (Cfi.resolveLocal(input.document, cfi).start != position) return false;
  }
  return true;
}
