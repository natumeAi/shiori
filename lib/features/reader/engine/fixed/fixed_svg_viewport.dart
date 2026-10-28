import 'dart:math' as math;

import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/layout/authored_dimension_resolver.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';

/// SVG user space -> viewport CSS pixels. Placement is composed above this.
final class FixedSvgViewport {
  FixedSvgViewport._(this.dimensions, this.transform);
  final DimensionResolution dimensions;
  final AffineTransform? transform;
  static FixedSvgViewport resolve(SvgSourceDimensions source) {
    final dimensions = resolveSvgDimensions(source);
    if (dimensions is! ResolvedDimensions) {
      return FixedSvgViewport._(dimensions, null);
    }
    final raw = source.preserveAspectRatio?.trim() ?? 'xMidYMid meet';
    final tokens = raw.split(RegExp(r'\s+'));
    if (tokens.first == 'defer') tokens.removeAt(0);
    if (tokens.isEmpty ||
        tokens.length > 2 ||
        !RegExp(r'^(none|x(Min|Mid|Max)Y(Min|Mid|Max))$')
            .hasMatch(tokens.first) ||
        tokens.length == 2 && !const ['meet', 'slice'].contains(tokens[1])) {
      return FixedSvgViewport._(
        MalformedDimensions('Invalid SVG preserveAspectRatio'),
        null,
      );
    }
    if (source.viewBox == null) {
      return FixedSvgViewport._(dimensions, const AffineTransform.identity());
    }
    // A1 validated all four values and positive extents above.
    final v = source.viewBox!
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map(double.parse)
        .toList();
    final sx = dimensions.size.width / v[2], sy = dimensions.size.height / v[3];
    double x = sx, y = sy, dx = 0, dy = 0;
    if (tokens.first != 'none') {
      x = y = tokens.last == 'slice' ? math.max(sx, sy) : math.min(sx, sy);
      double align(String axis) => tokens.first.contains('${axis}Min')
          ? 0
          : tokens.first.contains('${axis}Max')
          ? 1
          : .5;
      dx = (dimensions.size.width - v[2] * x) * align('x');
      dy = (dimensions.size.height - v[3] * y) * align('Y');
    }
    try {
      return FixedSvgViewport._(
        dimensions,
        AffineTransform(x, 0, 0, y, dx - v[0] * x, dy - v[1] * y),
      );
    } on ArgumentError {
      return FixedSvgViewport._(
        MalformedDimensions('SVG transform numeric range'),
        null,
      );
    }
  }
}
