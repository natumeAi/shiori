import 'dart:math' as math;

import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/layout/authored_dimension_resolver.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene_sizing.dart';

/// SVG user space -> viewport CSS pixels. Placement is composed above this.
final class FixedSvgViewport {
  FixedSvgViewport._(this.dimensions, this.transform);
  final DimensionResolution dimensions;
  final AffineTransform? transform;
  static FixedSvgViewport unsupportedContainingBlock() => FixedSvgViewport._(
    UnsupportedDimensions(
      'Inline SVG requires intrinsic containing-block layout',
    ),
    null,
  );

  /// CSS replaced-element used size. A viewBox supplies only an intrinsic
  /// ratio, never an XHTML page size or a containing-block extent.
  static FixedSvgViewport resolveInline(
    SvgSourceDimensions source, {
    required ComputedStyle style,
    required double containingWidth,
    required double? containingHeight,
    bool cssWidth = false,
    bool cssHeight = false,
  }) {
    DimensionResolution? failure;
    double? length(String? raw, StyleLength css, bool declared, double? basis) {
      if (declared || css.kind != StyleLengthKind.auto) {
        return css.kind == StyleLengthKind.percent && basis == null
            ? null
            : css.resolve(basis ?? 0);
      }
      if (raw == null || raw.trim() == 'auto') return null;
      final match = RegExp(
        r'^([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)\s*([a-zA-Z%]*)$',
      ).firstMatch(raw.trim());
      if (match == null) {
        failure = MalformedDimensions('Invalid inline SVG length');
        return null;
      }
      final value = double.parse(match[1]!);
      if (!value.isFinite || value <= 0) {
        failure = MalformedDimensions('Nonpositive inline SVG length');
        return null;
      }
      if (match[2] == '%') return basis == null ? null : value * basis / 100;
      const units = {
        '': 1.0,
        'px': 1.0,
        'in': 96.0,
        'cm': 96 / 2.54,
        'mm': 96 / 25.4,
        'q': 96 / 101.6,
        'pt': 96 / 72,
        'pc': 16.0,
      };
      final factor = units[match[2]];
      if (factor == null) {
        failure = UnsupportedDimensions('Unsupported inline SVG length unit');
        return null;
      }
      return value * factor;
    }

    var w = length(source.width, style.width, cssWidth, containingWidth);
    var h = length(source.height, style.height, cssHeight, containingHeight);
    double? ratio;
    if (source.viewBox != null) {
      final validation = resolveSvgDimensions(
        SvgSourceDimensions(
          nodeIndex: source.nodeIndex,
          width: null,
          height: null,
          viewBox: source.viewBox,
        ),
      );
      if (validation is! ResolvedDimensions) {
        return FixedSvgViewport._(validation, null);
      }
      ratio = validation.size.width / validation.size.height;
    }
    if (failure != null) return FixedSvgViewport._(failure!, null);
    final autoWidth = w == null, autoHeight = h == null;
    // CSS 2.1 replaced sizing: auto axis uses the intrinsic ratio; without
    // intrinsic dimensions the default object box is 300x150 CSS pixels.
    if (w == null && h == null) {
      w = ratio == null ? 300 : math.min(300, 150 * ratio);
      h = ratio == null ? 150 : w / ratio;
    } else if (w == null) {
      w = ratio == null ? 300 : h! * ratio;
    } else {
      h ??= ratio == null ? 150 : w / ratio;
    }
    double constrain(String axis, double value) => FixedUsedBoxSize.constrain(
      style,
      axis,
      value,
      axis == 'width' ? containingWidth : containingHeight,
      0,
    );
    if (ratio != null && autoWidth && autoHeight) {
      // CSS 2.2 10.4: choose the common scale satisfying both axes. If their
      // limits conflict, honor each limit and let the ratio be broken.
      final lower = math.max(
        constrain('width', 0) / w,
        constrain('height', 0) / h!,
      );
      final upper = math.min(
        constrain('width', double.infinity) / w,
        constrain('height', double.infinity) / h,
      );
      final scale = math.max(lower, math.min(1.0, upper));
      w *= scale;
      h *= scale;
    } else if (ratio != null && autoHeight) {
      w = constrain('width', w);
      h = w / ratio;
    } else if (ratio != null && autoWidth) {
      h = constrain('height', h!);
      w = h * ratio;
    }
    w = constrain('width', w);
    h = constrain('height', h!);
    return resolve(
      SvgSourceDimensions(
        nodeIndex: source.nodeIndex,
        width: '$w',
        height: '$h',
        viewBox: source.viewBox,
        preserveAspectRatio: source.preserveAspectRatio,
      ),
    );
  }

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
