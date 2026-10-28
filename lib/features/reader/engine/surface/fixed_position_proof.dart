import 'package:shiori/features/reader/data/cfi/cfi.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_section_preparer.dart';

/// Round-trip an actual source CFI and require an unobscured native alpha
/// sample for its fragment. This is display proof, not S4b dwell/coverage proof.
/// Conservative overlapping/translucent paint can refuse a candidate.
bool proveFixedAnchor(
  PreparedFixedScene scene,
  String cfi,
  String sectionBase,
) {
  final source = scene.plan.source;
  if (source.isDisposed || scene.geometry.completeness is! CompleteGeometry) {
    return false;
  }
  try {
    final range = Cfi.resolve(source.document, cfi);
    final exported = Cfi.export(
      source.document,
      range.start,
      end: range.collapsed ? null : range.end,
      sectionBase: sectionBase,
    );
    if (Cfi.compare(exported, cfi) != 0) return false;
    for (final fragment in scene.geometry.fragments) {
      if (fragment.nodeIndex != range.start.nodeIndex ||
          fragment.effectiveOpacity <= 0) {
        continue;
      }
      final text = fragment.textRange;
      if (text != null &&
          (range.start.offset < text.start || range.start.offset >= text.end)) {
        continue;
      }
      for (final paint in scene.geometry.paint) {
        if (paint.nodeIndex != fragment.nodeIndex ||
            paint.effectiveOpacity <= 0) {
          continue;
        }
        final alpha = paint.alphaFootprint;
        if (alpha == null) continue;
        for (var i = 0; i < alpha.alpha.length; i++) {
          if (alpha.alpha[i] == 0) continue;
          final localX =
              alpha.origin.x + (i % alpha.width + .5) * alpha.pixelSize;
          final localY =
              alpha.origin.y + (i ~/ alpha.width + .5) * alpha.pixelSize;
          final m = alpha.transform;
          final x = m.a * localX + m.c * localY + m.e;
          final y = m.b * localX + m.d * localY + m.f;
          if (text != null) {
            final clusters = fragment.clusters.where(
              (c) =>
                  range.start.offset >= c.range.start &&
                  range.start.offset < c.range.end,
            );
            if (clusters.isEmpty) continue;
            final inverse = fragment.sourceToUnit.inverse();
            if (inverse is! InvertedTransform) continue;
            final t = inverse.transform;
            final px = t.a * x + t.c * y + t.e, py = t.b * x + t.d * y + t.f;
            final quad = clusters.first.quad;
            var positive = false, negative = false;
            for (var j = 0; j < quad.length; j++) {
              final a = quad[j], b = quad[(j + 1) % quad.length];
              final cross = (b.x - a.x) * (py - a.y) - (b.y - a.y) * (px - a.x);
              positive |= cross > 0;
              negative |= cross < 0;
            }
            if (positive && negative) continue;
          }
          if (!scene.geometry.paint.any(
            (later) =>
                later.paintOrdinal > paint.paintOrdinal &&
                later.effectiveOpacity > 0 &&
                _covers(later, x, y),
          )) {
            return true;
          }
        }
      }
    }
  } on Object {
    return false;
  }
  return false;
}

bool _covers(GeometryPaint paint, double x, double y) {
  final alpha = paint.alphaFootprint;
  if (alpha != null) {
    final inverse = alpha.transform.inverse();
    if (inverse is! InvertedTransform) return true;
    final m = inverse.transform;
    final col = ((m.a * x + m.c * y + m.e - alpha.origin.x) / alpha.pixelSize)
        .floor();
    final row = ((m.b * x + m.d * y + m.f - alpha.origin.y) / alpha.pixelSize)
        .floor();
    return col >= 0 &&
        col < alpha.width &&
        row >= 0 &&
        row < alpha.height &&
        alpha.alpha[row * alpha.width + col] > 0;
  }
  final region = paint.region;
  final inverse = region.transform.inverse();
  if (inverse is! InvertedTransform) return true;
  final m = inverse.transform;
  final px = m.a * x + m.c * y + m.e, py = m.b * x + m.d * y + m.f;
  // Overestimate un-sampled solid/border coverage: it can refuse a candidate,
  // never invent visible source through an occluder or rounded corner.
  return px >= region.left &&
      px <= region.left + region.width &&
      py >= region.top &&
      py <= region.top + region.height;
}
