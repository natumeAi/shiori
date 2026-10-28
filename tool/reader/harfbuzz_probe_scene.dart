// Bounded SVG fixture adapter. Oracle coordinates never enter paint/layout.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:shiori/features/reader/data/cfi/cfi.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';

import 'harfbuzz_probe_shape.dart';
import 'harfbuzz_probe_path.dart';

final class HbScene {
  final runs = <HbRun>[];
  final metricRuns = <HbRun>[];
  final fragments = <Map<String, Object?>>[];
  final clusters = <Map<String, Object?>>[];
  final emitted = <String>[];

  void paint(
    ui.Canvas canvas,
    SourceDocument document,
    HbShaper shaper, {
    bool? ligatures,
    bool componentMetrics = false,
    bool fragmentPainting = false,
    bool gridFit = true,
  }) {
    for (final element in document.nodes.where((n) => n.localName == 'text')) {
      final nodes = _descendantText(document, element);
      final text = nodes.map((n) => n.text!).join();
      final positions = _positions(document, element, nodes);
      final pathNode = element.children
          .map(document.node)
          .where((n) => n.localName == 'textPath')
          .firstOrNull;
      final length = double.tryParse(pathNode?.attribute('textLength') ?? '');
      final mode = pathNode?.attribute('lengthAdjust') ?? 'spacing';
      final run = shaper.shape(
        text,
        ligatures: fragmentPainting ? false : ligatures ?? true,
        gridFit: fragmentPainting && gridFit,
      );
      final runIndex = runs.length;
      runs.add(run);
      final separateMetrics = componentMetrics || fragmentPainting;
      final metrics = separateMetrics ? shaper.shape(text) : run;
      if (separateMetrics) metricRuns.add(metrics);
      // WebKit does not apply parent textLength to this nested textPath.
      final scale = length != null && mode == 'spacingAndGlyphs'
          ? length / metrics.width
          : 1.0;
      final spacing = length != null && mode == 'spacing' && text.length > 1
          ? (length - metrics.width) / (text.length - 1)
          : 0.0;
      ui.PathMetric? metric;
      HbQuadraticTraversal? traversal;
      var startOffset = 0.0;
      if (pathNode != null) {
        final href = pathNode.attribute('href')!;
        final d = document.getElementById(href.substring(1))!.attribute('d')!;
        final points = RegExp(r'[-+]?(?:\d*\.)?\d+')
            .allMatches(d)
            .map((m) => double.parse(m[0]!))
            .toList();
        if (!d.startsWith('M') || !d.contains('Q') || points.length != 6) {
          throw FormatException(
            'Outside bounded quadratic fixture profile: $d',
          );
        }
        metric =
            (ui.Path()
                  ..moveTo(points[0], points[1])
                  ..quadraticBezierTo(
                    points[2],
                    points[3],
                    points[4],
                    points[5],
                  ))
                .computeMetrics()
                .single;
        if (fragmentPainting) traversal = HbQuadraticTraversal(points);
        final raw = pathNode.attribute('startOffset') ?? '0';
        startOffset = raw.endsWith('%')
            ? double.parse(raw.substring(0, raw.length - 1)) *
                  (traversal?.length ?? metric.length) /
                  100
            : double.parse(raw);
      }
      var cursor = 0.0, y = 0.0;
      final anchor = element.attribute('text-anchor') == 'middle'
          ? (metrics.width +
                    positions
                        .skip(1)
                        .fold<double>(0, (s, p) => s + (p['dx'] ?? 0))) /
                2
          : 0.0;
      var pen = 0.0;
      for (final range in run.clusterMap) {
        final first = range[0], end = range[1];
        if (separateMetrics) pen = _metricOffset(metrics, first);
        final glyphs = run.glyphs.where((g) => g.cluster == first).toList();
        final width = glyphs.fold<int>(0, (s, g) => s + g.advance) * run.factor;
        final advance = width * scale;
        final placementAdvance = fragmentPainting
            ? (_metricOffset(metrics, first + 1) - pen) * scale
            : advance;
        final p = positions[first];
        if (p.containsKey('x')) cursor = p['x']! - anchor;
        if (p.containsKey('y')) y = p['y']!;
        cursor += p['dx'] ?? 0;
        y += p['dy'] ?? 0;
        var angle = (p['rotate'] ?? 0) * math.pi / 180;
        ui.Offset origin;
        if (metric != null) {
          final distance =
              startOffset +
              pen * scale +
              first * spacing +
              placementAdvance / 2;
          if (distance < 0 || distance > (traversal?.length ?? metric.length)) {
            throw StateError('Path overflow');
          }
          final tangent =
              traversal?.tangent(distance) ??
              metric.getTangentForOffset(distance)!;
          angle += math.atan2(tangent.vector.dy, tangent.vector.dx);
          origin =
              tangent.position -
              ui.Offset(math.cos(angle), math.sin(angle)) *
                  (placementAdvance / 2);
        } else {
          origin = ui.Offset(cursor + first * spacing, y);
        }
        ui.Rect? ink;
        var glyphPen = 0.0;
        canvas.save();
        canvas.translate(origin.dx, origin.dy);
        canvas.rotate(angle);
        canvas.scale(scale, 1);
        for (final glyph in glyphs) {
          if (run.gridFitted) shaper.fitGlyph(glyph, angle, scale);
          final offset = ui.Offset(
            glyphPen + glyph.xOffset * run.factor,
            -glyph.yOffset * run.factor,
          );
          canvas.save();
          canvas.translate(offset.dx, offset.dy);
          canvas.drawPath(
            glyph.outline.path,
            ui.Paint()..color = const ui.Color(0xff000000),
          );
          canvas.restore();
          emitted.add(
            '$runIndex/${glyph.index}',
          ); // Includes empty-outline spaces.
          if (glyph.outline.operations > 0) {
            final bounds = glyph.outline.path.getBounds().shift(offset);
            ink = ink?.expandToInclude(bounds) ?? bounds;
          }
          glyphPen += glyph.advance * run.factor;
        }
        canvas.restore();
        final rect = ink ?? ui.Rect.zero;
        GeometryPoint point(double x, double yy) {
          final xx = x * scale;
          return GeometryPoint(
            origin.dx + xx * math.cos(angle) - yy * math.sin(angle),
            origin.dy + xx * math.sin(angle) + yy * math.cos(angle),
          );
        }

        final geometry = ClusterGeometry(
          range: Utf16Range(first, end),
          granularity: ClusterGranularity.shapingCluster,
          provenance: ClusterProvenance.shaped,
          quad: [
            point(rect.left, rect.top),
            point(rect.right, rect.top),
            point(rect.right, rect.bottom),
            point(rect.left, rect.bottom),
          ],
          baselineStart: point(0, 0),
          baselineEnd: point(width, 0),
          rotationRadians: angle,
        );
        clusters.add({
          'text': text,
          'utf16': [first, end],
          'provenance': geometry.provenance.name,
          'start': [geometry.baselineStart.x, geometry.baselineStart.y],
          'end': [geometry.baselineEnd.x, geometry.baselineEnd.y],
          'quad': [
            for (final q in geometry.quad) [q.x, q.y],
          ],
          'rotation': angle * 180 / math.pi,
          'glyphIndices': glyphs.map((g) => g.index).toList(),
          'scaleX': scale,
          'runIndex': runIndex,
          'runAdvance': metrics.width * scale,
          'paintedUnit': fragmentPainting
              ? 'component-fragment'
              : 'shaping-cluster',
          'outlineProvenance': run.gridFitted
              ? 'HB glyph ID; GDI transform-aware grid fit; exact pinned font'
              : 'HB OT unhinted glyph outline',
          'paintedUnitRule': fragmentPainting
              ? 'optional ligature components; combining continuation stays with base'
              : 'whole paint-shaping cluster',
          'layoutClusterUtf16': metrics.clusterMap.singleWhere(
            (r) => first >= r[0] && first < r[1],
          ),
          'placementAdvance': placementAdvance,
          'pathTraversal': traversal != null
              ? 'quadratic-256-chords'
              : 'PathMetric',
          'layoutMetrics': separateMetrics
              ? 'default-shaping/equal-component-slots'
              : 'paint-shaping',
          'extraSpacingPerUtf16': spacing,
          'parentTextLengthApplied': false,
          'inkCrossesAdvance':
              ink != null && (ink.left < 0 || ink.right > width),
        });
        // Shared comparator's unit adapter: only whole-cluster outer edges gate.
        for (var i = first; i < end; i++) {
          var offset = 0;
          final node = nodes.firstWhere((n) {
            if (i < offset + n.text!.length) return true;
            offset += n.text!.length;
            return false;
          });
          final local = i - offset;
          final cfi = Cfi.export(
            document,
            SourcePosition(nodeIndex: node.index, offset: local),
          );
          fragments.add({
            'textRun': text,
            'svgIndex': i,
            'node': node.index,
            'utf16Start': local,
            'utf16End': local + 1,
            'sourceText': node.text,
            'cfiRoundTrip':
                Cfi.resolveLocal(document, cfi).start ==
                SourcePosition(nodeIndex: node.index, offset: local),
            'start': i == first
                ? [geometry.baselineStart.x, geometry.baselineStart.y]
                : [geometry.baselineEnd.x, geometry.baselineEnd.y],
            'end': [geometry.baselineEnd.x, geometry.baselineEnd.y],
            'rotation': angle * 180 / math.pi,
            'clusterUtf16': [first, end],
            'provenance': 'shaped',
            'paintedUnit': fragmentPainting
                ? 'component-fragment'
                : 'shaping-cluster',
          });
        }
        cursor += separateMetrics
            ? (_metricOffset(metrics, end) - pen) * scale
            : advance;
        pen += width;
      }
    }
  }

  void close() {
    for (final run in runs) {
      run.close();
    }
    for (final run in metricRuns) {
      run.close();
    }
  }
}

double _metricOffset(HbRun run, int index) {
  var offset = 0.0;
  for (final range in run.clusterMap) {
    final width =
        run.glyphs
            .where((g) => g.cluster == range[0])
            .fold<int>(0, (sum, g) => sum + g.advance) *
        run.factor;
    if (index < range[1]) {
      return offset + width * (index - range[0]) / (range[1] - range[0]);
    }
    offset += width;
  }
  return offset;
}

List<SourceNode> _descendantText(SourceDocument document, SourceNode parent) {
  final nodes = <SourceNode>[];
  void visit(SourceNode node) {
    if (node.isCharacterData) {
      nodes.add(node);
      return;
    }
    for (final child in node.children) {
      visit(document.node(child));
    }
  }

  visit(parent);
  return nodes;
}

List<Map<String, double>> _positions(
  SourceDocument document,
  SourceNode root,
  List<SourceNode> nodes,
) {
  final firstIndex = <int, int>{};
  var global = 0;
  for (final node in nodes) {
    SourceNode? ancestor = node;
    while (ancestor != null) {
      firstIndex.putIfAbsent(ancestor.index, () => global);
      if (ancestor.index == root.index) break;
      ancestor = ancestor.parentIndex == null
          ? null
          : document.node(ancestor.parentIndex!);
    }
    global += node.text!.length;
  }
  final result = <Map<String, double>>[];
  global = 0;
  for (final node in nodes) {
    final ancestors = <SourceNode>[];
    var ancestor = document.node(node.parentIndex!);
    while (true) {
      ancestors.add(ancestor);
      if (ancestor.index == root.index) break;
      ancestor = document.node(ancestor.parentIndex!);
    }
    for (var local = 0; local < node.text!.length; local++) {
      final position = <String, double>{};
      for (final a in ancestors.reversed) {
        final index = global + local - firstIndex[a.index]!;
        for (final key in ['x', 'y', 'dx', 'dy', 'rotate']) {
          final raw = a.attribute(key);
          if (raw == null || raw.trim().isEmpty) continue;
          final values = raw
              .trim()
              .split(RegExp(r'[\s,]+'))
              .map(double.parse)
              .toList();
          if (index < values.length || key == 'rotate') {
            position[key] = values[math.min(index, values.length - 1)];
          }
        }
      }
      result.add(position);
    }
    global += node.text!.length;
  }
  return result;
}
