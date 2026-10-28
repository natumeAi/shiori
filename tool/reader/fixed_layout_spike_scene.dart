// Deliberately bounded fixture-profile experiment, not a second CSS parser.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:shiori/features/reader/data/cfi/cfi.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';

/// Paints the text/mask/foreignObject feasibility subset and records independent
/// source identity. Oracle coordinates are never inputs to this renderer.
void paintSpikeScene(
  ui.Canvas canvas,
  SourceDocument document,
  String row,
  List<Map<String, Object?>> fragments,
  List<ui.Paragraph> paragraphs, {
  bool applyParentTextLength = true,
  bool textOnly = false,
}) {
  switch (row) {
    case 'clip-mask':
      if (!textOnly) _mask(canvas, document, fragments);
    case 'foreign-object':
      _foreign(canvas, document, fragments, paragraphs, textOnly: textOnly);
    case 'svg-text':
      _svgText(
        canvas,
        document,
        fragments,
        paragraphs,
        applyParentTextLength,
        textOnly: textOnly,
      );
    default:
      throw FormatException('Unprobed scene row: $row');
  }
}

/// Retains a source element independently of opaque filter raster intermediates.
Map<String, Object?> spikeElementIdentity(SourceDocument document) {
  final node = document.getElementById('source')!;
  return {
    ..._identity(document, node, 0, 0, 0),
    'kind': 'filtered-source-rect',
    'box': [
      for (final attribute in ['x', 'y', 'width', 'height'])
        double.parse(node.attribute(attribute)!),
    ],
    'filter': node.attribute('filter'),
    'geometryCompleteness': 'source-box-with-filter-region',
  };
}

ui.Paragraph _paragraph(
  String text,
  List<ui.Paragraph> owners, {
  ui.Color color = const ui.Color(0xff000000),
  double? height,
}) {
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            textDirection: ui.TextDirection.ltr,
            fontFamily: 'FixedLayoutSpikeRoboto',
            fontSize: 20,
            height: height,
          ),
        )
        ..pushStyle(
          ui.TextStyle(
            fontFamily: 'FixedLayoutSpikeRoboto',
            fontSize: 20,
            color: color,
            height: height,
          ),
        )
        ..addText(text);
  final paragraph = builder.build()
    ..layout(const ui.ParagraphConstraints(width: 10000));
  owners.add(paragraph);
  return paragraph;
}

List<SourceNode> _textNodes(SourceDocument document, SourceNode parent) {
  final result = <SourceNode>[];
  void visit(SourceNode node) {
    if (node.isCharacterData) {
      result.add(node);
      return;
    }
    for (final child in node.children) {
      visit(document.node(child));
    }
  }

  visit(parent);
  return result;
}

Map<String, Object?> _identity(
  SourceDocument document,
  SourceNode node,
  int start,
  int end,
  int ordinal,
) {
  final position = SourcePosition(nodeIndex: node.index, offset: start);
  final cfi = Cfi.export(document, position);
  final resolved = Cfi.resolveLocal(document, cfi).start;
  return {
    'node': node.index,
    'utf16Start': start,
    'utf16End': end,
    'sourceText': node.text,
    'cfi': cfi,
    'cfiRoundTrip': resolved == position,
    'paintOrdinal': ordinal,
  };
}

void _mask(
  ui.Canvas canvas,
  SourceDocument document,
  List<Map<String, Object?>> fragments,
) {
  const region = ui.Rect.fromLTWH(0, 0, 320, 240);
  final group = document.nodes.firstWhere((n) => n.localName == 'g');
  final mask = document.nodes.firstWhere((n) => n.localName == 'mask');
  final shape = document.getElementById('source')!;
  final luminance = mask.attribute('style')!.contains('luminance');
  canvas.saveLayer(
    region,
    ui.Paint()
      ..color = const ui.Color(0xffffffff)
          .withValues(alpha: double.parse(group.attribute('opacity')!)),
  );
  canvas.clipPath(
    ui.Path()..addOval(
      ui.Rect.fromCircle(center: const ui.Offset(90, 90), radius: 60),
    ),
  );
  canvas.saveLayer(region, ui.Paint());
  canvas.drawRect(
    const ui.Rect.fromLTWH(20, 20, 160, 160),
    ui.Paint()..color = const ui.Color(0xffff0000),
  );
  canvas.saveLayer(region, ui.Paint()..blendMode = ui.BlendMode.dstIn);
  if (luminance) {
    canvas.saveLayer(
      region,
      ui.Paint()
        ..colorFilter = const ui.ColorFilter.matrix([
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          .2126,
          .7152,
          .0722,
          0,
          0,
        ]),
    );
  }
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 160, 240),
    ui.Paint()..color = const ui.Color(0xff808080),
  );
  if (luminance) canvas.restore();
  canvas.restore();
  canvas.restore();
  canvas.restore();
  fragments.add({
    ..._identity(document, shape, 0, 0, 0),
    'kind': 'rect',
    'box': [20, 20, 160, 160],
    'clip': {
      'kind': 'circle',
      'center': [90, 90],
      'radius': 60,
    },
    'mask': {
      'kind': luminance ? 'luminance' : 'alpha',
      'box': [0, 0, 160, 240],
      'sampleCoverage': luminance ? 128 / 255 : 1,
    },
    'effectiveOpacity': .5,
    'geometryCompleteness': 'finite-analytic-mask-and-clip',
  });
}

void _foreign(
  ui.Canvas canvas,
  SourceDocument document,
  List<Map<String, Object?>> fragments,
  List<ui.Paragraph> owners, {
  bool textOnly = false,
}) {
  final foreign = document.getElementById('source')!;
  final nodes = _textNodes(document, foreign);
  final text = nodes.map((n) => n.text!).join();
  final paragraph = _paragraph(
    text,
    owners,
    color: const ui.Color(0xffff0000),
    height: 1.2,
  );
  // Authored g translation + foreignObject origin; border and padding are CSS.
  final origin = ui.Offset(
    10 + double.parse(foreign.attribute('x')!),
    15 + double.parse(foreign.attribute('y')!),
  );
  final box = ui.Rect.fromLTWH(origin.dx, origin.dy, 180, 36);
  canvas.save();
  canvas.clipRect(ui.Rect.fromLTWH(origin.dx, origin.dy, 180, 120));
  if (!textOnly) {
    canvas.drawRect(
      box.deflate(1),
      ui.Paint()
        ..color = const ui.Color(0xff0000ff)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
  var offset = 0;
  for (final node in nodes) {
    final style = document.node(node.parentIndex!).attribute('style') ?? '';
    final y = style.contains('top:3px') ? 3.0 : 0.0;
    final boxes = paragraph.getBoxesForRange(
      offset,
      offset + node.text!.length,
    );
    final nodeAdvance = boxes.fold<double>(
      0,
      (sum, box) => sum + box.right - box.left,
    );
    // Contextual positions: standalone prefixes would reshape ligatures.
    final boundaries = <double>[
      for (var i = 0; i <= node.text!.length; i++)
        origin.dx +
            6 +
            (i == 0
                ? boxes.first.left
                : paragraph.getBoxesForRange(offset, offset + i).last.right),
    ];
    canvas.save();
    canvas.translate(origin.dx + 6, origin.dy + 6 + y);
    final paintedGraphemes = <(int, int)>{};
    for (var i = 0; i < node.text!.length; i++) {
      final glyph = paragraph.getGlyphInfoAt(offset + i);
      final cluster = glyph?.graphemeClusterCodeUnitRange;
      final start = cluster?.start ?? offset + i;
      final end = cluster?.end ?? offset + i + 1;
      final painted = paintedGraphemes.add((start, end));
      if (painted) {
        // XHTML text is conserved per grapheme, never per UTF-16 unit.
        for (final box in paragraph.getBoxesForRange(start, end)) {
          canvas.save();
          canvas.clipRect(ui.Rect.fromLTRB(box.left, -30, box.right, 60));
          canvas.drawParagraph(paragraph, ui.Offset.zero);
          canvas.restore();
        }
      }
      final rects = paragraph.getBoxesForRange(offset + i, offset + i + 1);
      fragments.add({
        ..._identity(document, node, i, i + 1, fragments.length),
        'kind': 'foreign-text',
        'sourceNodeShapedAdvance': nodeAdvance,
        'boundaryPositions': boundaries,
        'text': node.text!.substring(i, i + 1),
        'graphemeUtf16': [start - offset, end - offset],
        'graphemePaint': painted,
        'boxes': [
          for (final rect in rects)
            _rect(rect.toRect().shift(origin + ui.Offset(6, 6 + y))),
        ],
        'baseline': paragraph.alphabeticBaseline + origin.dy + 6 + y,
      });
    }
    canvas.restore();
    offset += node.text!.length;
  }
  canvas.restore();
}

void _svgText(
  ui.Canvas canvas,
  SourceDocument document,
  List<Map<String, Object?>> fragments,
  List<ui.Paragraph> owners,
  bool adjust, {
  bool textOnly = false,
}) {
  final elements = document.nodes.where((n) => n.localName == 'text');
  final nominalMetrics = <String, double>{};
  for (final element in elements) {
    final nodes = _textNodes(document, element);
    final text = nodes.map((n) => n.text!).join();
    final paragraph = _paragraph(text, owners);
    final pathText = element.children
        .map(document.node)
        .where((n) => n.localName == 'textPath')
        .firstOrNull;
    final span = element.children
        .map(document.node)
        .where((n) => n.localName == 'tspan')
        .firstOrNull;
    final dx = _numbers(span?.attribute('dx'));
    final dy = _numbers(span?.attribute('dy'));
    final rotation = _numbers(span?.attribute('rotate'));
    final metrics = paragraph.computeLineMetrics().single;
    final natural = paragraph.longestLine;
    final lengthNode = pathText?.attribute('textLength') == null
        ? element
        : pathText!;
    final requested = double.tryParse(lengthNode.attribute('textLength') ?? '');
    final adjustment = lengthNode.attribute('lengthAdjust') ?? 'spacing';
    final spacingOnly = adjustment == 'spacing';
    final scale = adjust && requested != null && !spacingOnly
        ? requested / natural
        : 1.0;
    final extraSpacing =
        adjust && requested != null && spacingOnly && text.length > 1
        ? (requested - natural) / (text.length - 1)
        : 0.0;
    // PathMetrics uses Skia's native curve measurement, not oracle coordinates.
    final path = ui.Path()
      ..moveTo(20, 100)
      ..quadraticBezierTo(160, 10, 290, 120);
    final metric = path.computeMetrics().single;
    var x = double.tryParse(element.attribute('x') ?? '') ?? 0;
    var y = double.tryParse(element.attribute('y') ?? '') ?? 0;
    if (element.attribute('text-anchor') == 'middle') {
      // The first dx moves the anchored chunk; later dx values extend it.
      x -= (natural + dx.skip(1).fold<double>(0, (a, b) => a + b)) / 2;
    }
    var globalOffset = 0;
    final painted = <(int, int)>{};
    for (final node in nodes) {
      for (var local = 0; local < node.text!.length; local++) {
        final i = globalOffset + local;
        final glyph = paragraph.getGlyphInfoAt(i);
        final cluster = glyph?.graphemeClusterCodeUnitRange;
        final start = cluster?.start ?? i;
        final end = cluster?.end ?? i + 1;
        final clusterBoxes = paragraph.getBoxesForRange(start, end);
        final slot = clusterBoxes.isEmpty
            ? ui.Rect.zero
            : clusterBoxes.first.toRect();
        final clusterText = text.substring(start, end);
        // Keep whole-run shaping for paint. SVG DOM character extents report
        // nominal character advances even when paragraph selection subdivides
        // a ligature. These small paragraphs measure that distinct metric;
        // they never replace the contextual shaped paragraph.
        final nominalAdvance = nominalMetrics.putIfAbsent(
          clusterText,
          () => _paragraph(clusterText, owners).longestLine,
        );
        final advance = nominalAdvance * scale;
        ui.Offset base;
        double angle;
        if (pathText != null) {
          final rawOffset = pathText.attribute('startOffset') ?? '0';
          final offset = rawOffset.endsWith('%')
              ? double.parse(rawOffset.substring(0, rawOffset.length - 1)) *
                    metric.length /
                    100
              : double.parse(rawOffset);
          final tangent = metric.getTangentForOffset(
            offset + slot.left * scale + start * extraSpacing + advance / 2,
          );
          if (tangent == null) {
            throw const FormatException('Text exceeded bounded path');
          }
          angle = math.atan2(tangent.vector.dy, tangent.vector.dx);
          base =
              tangent.position -
              ui.Offset(
                math.cos(angle) * advance / 2,
                math.sin(angle) * advance / 2,
              );
        } else {
          if (i < dx.length) x += dx[i];
          if (i < dy.length) y += dy[i];
          angle = rotation.isEmpty
              ? 0
              : rotation[math.min(i, rotation.length - 1)] * math.pi / 180;
          base = ui.Offset(x + slot.left + start * extraSpacing, y);
        }
        final secondaryUnit = i > start;
        final visibleAdvance = secondaryUnit ? 0.0 : advance;
        final localLeft = secondaryUnit ? advance : 0.0;
        final extent = _transformedRect(
          ui.Rect.fromLTRB(
            localLeft,
            -metrics.ascent,
            localLeft + visibleAdvance,
            metrics.descent,
          ),
          base,
          angle,
        );
        // A combining UTF-16 unit can have an empty selection while sharing
        // its preceding glyph. Its source point is at that glyph's end.
        final charOffset = localLeft;
        final charStart =
            base +
            ui.Offset(
              math.cos(angle) * charOffset,
              math.sin(angle) * charOffset,
            );
        final charAdvance = visibleAdvance;
        final endPoint =
            charStart +
            ui.Offset(
              math.cos(angle) * charAdvance,
              math.sin(angle) * charAdvance,
            );
        final paintedAdvance = slot.width * scale;
        final actualLeft = secondaryUnit ? paintedAdvance : 0.0;
        final actualWidth = secondaryUnit ? 0.0 : paintedAdvance;
        final actualStart =
            base +
            ui.Offset(
              math.cos(angle) * actualLeft,
              math.sin(angle) * actualLeft,
            );
        final actualEnd =
            actualStart +
            ui.Offset(
              math.cos(angle) * actualWidth,
              math.sin(angle) * actualWidth,
            );
        final actualExtent = _transformedRect(
          ui.Rect.fromLTRB(
            actualLeft,
            -metrics.ascent,
            actualLeft + actualWidth,
            metrics.descent,
          ),
          base,
          angle,
        );
        final firstPaint = painted.add((start, end));
        fragments.add({
          ..._identity(document, node, local, local + 1, fragments.length),
          'kind': 'svg-character',
          'textRun': text,
          'svgIndex': i,
          'graphemeUtf16': [start, end],
          'graphemePaint': firstPaint,
          'start': [actualStart.dx, actualStart.dy],
          'end': [actualEnd.dx, actualEnd.dy],
          'rotation': angle * 180 / math.pi,
          'extent': _rect(actualExtent),
          'paintSlice': [slot.left, slot.top, slot.width, slot.height],
          'geometryDefinition': 'Actually painted whole-paragraph slice at Unicode grapheme boundaries; glyph IDs and shaping-run ligatures unavailable.',
          'nominalDiagnosticGeometry': {
            'start': [charStart.dx, charStart.dy],
            'end': [endPoint.dx, endPoint.dy],
            'extent': _rect(extent),
          },
          'naturalTextLength': natural,
          'nominalCharacterAdvance': nominalAdvance,
          'requestedTextLength': requested,
          'lengthAdjust': adjustment,
          'extraSpacing': extraSpacing,
          'parentTextLengthApplied': adjust,
          'baselineMetrics': [metrics.ascent, metrics.descent],
        });
        if (firstPaint) {
          canvas.save();
          canvas.translate(base.dx, base.dy);
          canvas.rotate(angle);
          canvas.scale(scale, 1);
          canvas.clipRect(ui.Rect.fromLTRB(0, -40, slot.width, 40));
          canvas.drawParagraph(
            paragraph,
            ui.Offset(-slot.left, -paragraph.alphabeticBaseline),
          );
          canvas.restore();
        }
      }
      globalOffset += node.text!.length;
    }
  }
}

List<double> _numbers(String? input) => input == null
    ? []
    : input.trim().split(RegExp(r'[\s,]+')).map(double.parse).toList();
List<double> _rect(ui.Rect rect) => [
  rect.left,
  rect.top,
  rect.width,
  rect.height,
];
ui.Rect _transformedRect(ui.Rect rect, ui.Offset origin, double angle) {
  final points =
      [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight].map(
        (p) =>
            origin +
            ui.Offset(
              p.dx * math.cos(angle) - p.dy * math.sin(angle),
              p.dx * math.sin(angle) + p.dy * math.cos(angle),
            ),
      );
  final xs = points.map((p) => p.dx), ys = points.map((p) => p.dy);
  return ui.Rect.fromLTRB(
    xs.reduce(math.min),
    ys.reduce(math.min),
    xs.reduce(math.max),
    ys.reduce(math.max),
  );
}
