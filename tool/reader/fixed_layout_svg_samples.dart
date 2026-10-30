import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_fragment.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';

import 'fixed_layout_spike_pixels.dart';

/// Builds the D9 oracle-sample records from effective native paint.
///
/// [referenceComputedPaint] maps a source SVG node index to its oracle
/// `computedPaint` map. Callers that cannot resolve a node leave it absent,
/// which classifies that sample as solid.
/// [paints] must include all published paints in the sampled scene. Missing or
/// unknown alpha evidence requires exact samples; it cannot expose a gradient
/// underneath text, foreignObject content, images, clips or masks.
List<SpikeSampleRecord> classifySvgSamples({
  required SourceDocument document,
  required List<SvgGraphicsElement> elements,
  required List<GeometryClip> clips,
  required List<SourceFragment> fragments,
  List<GeometryPaint>? paints,
  required Map<int, Map<String, Object?>> referenceComputedPaint,
  required List<Map> samples,
  required Uint8List actual,
}) {
  final clipById = {for (final clip in clips) clip.id: clip};
  final fragmentByKey = {
    for (final fragment in fragments)
      '${fragment.nodeIndex}:${fragment.paintOrdinal}': fragment,
  };
  final ordered = [...?paints]
    ..sort((a, b) {
      final ordinal = b.paintOrdinal.compareTo(a.paintOrdinal);
      return ordinal != 0 ? ordinal : b.role.index.compareTo(a.role.index);
    });
  return [
    for (final sample in samples)
      _classify(
        document: document,
        sample: sample,
        actual: actual,
        elements: elements,
        paints: ordered,
        clips: clipById,
        fragments: fragmentByKey,
        referenceComputedPaint: referenceComputedPaint,
      ),
  ];
}

/// Oracle `graphics.elements[]` is in SVG document order.
Map<int, Map<String, Object?>> svgReferenceComputedPaint({
  required SourceDocument document,
  required Map<String, Object?> reference,
}) {
  final nodes = document.nodes
      .where(
        (n) =>
            n.namespaceUri == 'http://www.w3.org/2000/svg' &&
            n.localName != null,
      )
      .toList();
  final graphics = reference['graphics'] as Map?;
  final expected = (graphics?['elements'] as List? ?? const []).cast<Map>();
  if (nodes.length != expected.length) return const {};
  return {
    for (var i = 0; i < nodes.length; i++)
      nodes[i].index:
          (expected[i]['computedPaint'] as Map?)?.cast<String, Object?>() ??
          const {},
  };
}

SpikeSampleRecord _classify({
  required SourceDocument document,
  required Map sample,
  required Uint8List actual,
  required List<SvgGraphicsElement> elements,
  required List<GeometryPaint> paints,
  required Map<String, GeometryClip> clips,
  required Map<String, SourceFragment> fragments,
  required Map<int, Map<String, Object?>> referenceComputedPaint,
}) {
  final x = sample['x'] as int, y = sample['y'] as int;
  final rgba = (sample['rgba'] as List).cast<int>();
  final offset = (y * 320 + x) * 4;
  final delta = List.generate(
    4,
    (channel) => (actual[offset + channel] - rgba[channel]).abs(),
  ).reduce(math.max);
  SpikeSampleRecord solid(String reason, [Map<String, Object?>? provenance]) =>
      SpikeSampleRecord(
        x: x,
        y: y,
        maximumChannelDelta: delta,
        classification: SpikeSamplePaintClass.solid,
        provenance: {...?provenance, 'reason': reason},
      );
  final centre = ui.Offset(x + .5, y + .5);
  final point = GeometryPoint(centre.dx, centre.dy);
  for (final paint in paints) {
    if (paint.effectiveOpacity <= 0) continue;
    final clipsCover = _clipsCover(paint.clipIds, clips, centre);
    if (clipsCover == null) {
      return solid('native paint clip evidence is unknown');
    }
    if (!clipsCover) continue;
    if (!paint.exactCoverage) return solid('native paint coverage is unknown');
    final footprint = paint.alphaFootprint;
    final alpha = footprint?.alphaAt(point);
    if (alpha == null) return solid('native paint coverage is unknown');
    if (alpha == 0) continue;
    var maskedOut = false;
    for (final mask in footprint!.masks) {
      final maskAlpha = mask.coverage.alphaAt(point);
      if (maskAlpha == null) return solid('native mask coverage is unknown');
      if (maskAlpha == 0) maskedOut = true;
    }
    if (maskedOut) continue;
    final matches = elements
        .where(
          (element) =>
              element.nodeIndex == paint.nodeIndex &&
              element.paintOrdinal == paint.paintOrdinal,
        )
        .toList();
    if (matches.length != 1 ||
        paint.kind == GeometryPaintKind.text ||
        document.node(paint.nodeIndex).localName == 'image') {
      return solid('topmost paint has no unambiguous SVG gradient role', {
        'native': {
          'nodeIndex': paint.nodeIndex,
          'paintOrdinal': paint.paintOrdinal,
        },
      });
    }
    final element = matches.single;
    final filterNode = _filterOwner(document, [
      element.nodeIndex,
      ...element.instancePath,
    ], referenceComputedPaint);
    if (filterNode != null) {
      // Output alpha proves coverage, not that a filter preserved its input's
      // fill/stroke paint server. Never resolve combined output back to it.
      return solid('filtered output has no proven SVG gradient role', {
        'native': {
          'nodeIndex': paint.nodeIndex,
          'paintOrdinal': paint.paintOrdinal,
          'kind': paint.kind.name,
          'role': paint.role.name,
          'filterNodeIndex': filterNode,
        },
      });
    }
    final fragment = fragments['${element.nodeIndex}:${element.paintOrdinal}'];
    if (fragment == null) {
      return solid('missing native paint evidence for the topmost element');
    }
    if (_hidden(document, element, fragment)) continue;
    final local = _localPoint(element.transform, centre);
    if (local == null) return solid('native paint transform is singular');
    final coverage = switch (paint.role) {
      GeometryPaintRole.fill => _SvgCoverage.fill,
      GeometryPaintRole.stroke => _SvgCoverage.stroke,
      GeometryPaintRole.combined => _coverage(element, local),
    };
    if (coverage == _SvgCoverage.none || coverage == _SvgCoverage.ambiguous) {
      return solid('native paint coverage is ambiguous');
    }
    final role = coverage == _SvgCoverage.fill ? 'fill' : 'stroke';
    final nativePaint = element.paint[role];
    final computed = referenceComputedPaint[element.nodeIndex] ?? const {};
    final referencePaint = computed[role] as String?;
    final provenance = <String, Object?>{
      'native': {
        'nodeIndex': element.nodeIndex,
        'paintOrdinal': element.paintOrdinal,
        'role': role,
        'paint': nativePaint,
        'effectiveOpacity': fragment.effectiveOpacity,
        'visibility': element.paint['visibility'],
        'display': document.attribute(element.nodeIndex, 'display'),
        'clipIds': element.clipIds,
      },
      'reference': {'computedPaint': referencePaint},
    };
    if (!_isGradientPaint(document, nativePaint)) {
      return solid('native paint is not a gradient paint server', provenance);
    }
    if (!_isGradientPaint(document, referencePaint)) {
      return solid('reference computed paint is not a gradient', provenance);
    }
    return SpikeSampleRecord(
      x: x,
      y: y,
      maximumChannelDelta: delta,
      classification: SpikeSamplePaintClass.gradient,
      provenance: provenance,
    );
  }
  return solid('no effective native paint covers the pixel centre');
}

int? _filterOwner(
  SourceDocument document,
  Iterable<int> nodes,
  Map<int, Map<String, Object?>> referenceComputedPaint,
) {
  final visited = <int>{};
  for (final start in nodes) {
    int? index = start;
    while (index != null && visited.add(index)) {
      // Raw attributes also fail closed when reference filter evidence is
      // absent; computed filters catch CSS declarations on either ancestor.
      for (final value in [
        document.attribute(index, 'filter'),
        referenceComputedPaint[index]?['filter'] as String?,
      ]) {
        final filter = value?.trim().toLowerCase();
        if (filter != null && filter.isNotEmpty && filter != 'none') {
          return index;
        }
      }
      index = document.node(index).parentIndex;
    }
  }
  return null;
}

bool _hidden(
  SourceDocument document,
  SvgGraphicsElement element,
  SourceFragment? fragment,
) {
  if (document.attribute(element.nodeIndex, 'display') == 'none') return true;
  final visibility = element.paint['visibility'];
  if (visibility == 'hidden' || visibility == 'collapse') return true;
  return fragment != null && fragment.effectiveOpacity <= 0;
}

ui.Offset? _localPoint(AffineTransform transform, ui.Offset unit) {
  final inverse = transform.inverse();
  if (inverse is! InvertedTransform) return null;
  final matrix = inverse.transform;
  return ui.Offset(
    matrix.a * unit.dx + matrix.c * unit.dy + matrix.e,
    matrix.b * unit.dx + matrix.d * unit.dy + matrix.f,
  );
}

enum _SvgCoverage { none, ambiguous, fill, stroke }

_SvgCoverage _coverage(SvgGraphicsElement element, ui.Offset local) {
  final path = element.fillPath;
  if (path == null) return _SvgCoverage.none;
  final fillValue = element.paint['fill'];
  final strokeValue = element.paint['stroke'];
  final fillVisible = fillValue == null
      ? null
      : _visiblePaint(fillValue, element.paint['fill-opacity']);
  final strokeVisible = strokeValue == null
      ? false
      : _visiblePaint(strokeValue, element.paint['stroke-opacity']);
  if (fillVisible == null || strokeVisible == null) {
    return _SvgCoverage.ambiguous;
  }
  if (!fillVisible && !strokeVisible) return _SvgCoverage.none;
  final inFill = fillVisible && path.contains(local);
  if (!strokeVisible) return inFill ? _SvgCoverage.fill : _SvgCoverage.none;
  final width = _strokeWidth(element.paint['stroke-width']);
  if (width == null) return _SvgCoverage.ambiguous;
  if (width <= 0) return inFill ? _SvgCoverage.fill : _SvgCoverage.none;
  // Published alpha is the combined fill/stroke coverage. A centreline-distance
  // approximation cannot distinguish dash gaps, caps or joins from the fill.
  // Require exact samples unless a single visible role owns that coverage.
  return fillVisible ? _SvgCoverage.ambiguous : _SvgCoverage.stroke;
}

bool? _visiblePaint(String value, String? opacity) {
  final paint = value.trim().toLowerCase();
  if (paint.isEmpty || paint == 'none' || paint == 'transparent') return false;
  final alpha = _number(opacity);
  if (opacity != null && alpha == null) return null;
  if (alpha != null && alpha <= 0) return false;
  if (_colorAlphaZero(paint)) return false;
  return true;
}

double? _number(String? value) {
  if (value == null) return null;
  final text = value.trim();
  if (text.endsWith('%')) {
    final percent = double.tryParse(text.substring(0, text.length - 1));
    return percent == null ? null : percent / 100;
  }
  return double.tryParse(text);
}

bool _colorAlphaZero(String paint) {
  final rgba = RegExp(r'^rgba\(\s*[^)]*,\s*([0-9.]+)\s*\)$').firstMatch(paint);
  if (rgba != null) return (double.tryParse(rgba.group(1)!) ?? 1) <= 0;
  return RegExp(r'^#[0-9a-f]{6}00$').hasMatch(paint) || paint == '#00000000';
}

double? _strokeWidth(String? value) {
  if (value == null || value.trim().isEmpty) return 1;
  final match = RegExp(r'^\s*([0-9]*\.?[0-9]+)').firstMatch(value);
  return match == null ? null : double.tryParse(match.group(1)!);
}

bool? _clipsCover(
  List<String> ids,
  Map<String, GeometryClip> clips,
  ui.Offset unit,
) {
  for (final id in ids) {
    final clip = clips[id];
    if (clip == null) return null;
    final region = clip.region;
    final inverse = region.transform.inverse();
    if (inverse is! InvertedTransform) return null;
    final matrix = inverse.transform;
    final x = matrix.a * unit.dx + matrix.c * unit.dy + matrix.e;
    final y = matrix.b * unit.dx + matrix.d * unit.dy + matrix.f;
    const epsilon = 1e-9;
    if (x < region.left - epsilon ||
        x > region.left + region.width + epsilon ||
        y < region.top - epsilon ||
        y > region.top + region.height + epsilon) {
      return false;
    }
  }
  return true;
}

final _gradientUrlPattern = RegExp(r'''url\(\s*["']?#([^)"']+)''');

bool _isGradientPaint(SourceDocument document, String? value) {
  if (value == null) return false;
  final match = _gradientUrlPattern.firstMatch(value);
  final id = match?.group(1);
  if (id == null) return false;
  final targets = document.nodes
      .where((node) => node.id == id && node.localName != null)
      .toList();
  if (targets.length != 1) return false;
  return const {
    'linearGradient',
    'radialGradient',
  }.contains(targets.single.localName);
}
