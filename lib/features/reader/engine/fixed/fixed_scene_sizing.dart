import 'dart:math' as math;

import 'package:shiori/features/reader/engine/style/computed_style.dart';

/// Content dimensions before children. Null height means indefinite.
final class FixedUsedBoxSize {
  const FixedUsedBoxSize(this.width, this.height);
  final double width;
  final double? height;

  static FixedUsedBoxSize resolve(
    ComputedStyle style,
    double containingWidth,
    double? containingHeight,
  ) {
    final a = style.authored;
    final out =
        a.position == AuthoredPosition.absolute ||
        a.position == AuthoredPosition.fixed;
    double edge(StyleLength l) => l.resolve(containingWidth) ?? 0;
    double border(String e) =>
        a.borderStyle(e) == 'none' ? 0 : edge(a.borderWidth(e));
    final extraW =
        edge(style.padding.left) +
        edge(style.padding.right) +
        border('left') +
        border('right');
    final extraH =
        edge(style.padding.top) +
        edge(style.padding.bottom) +
        border('top') +
        border('bottom');
    final left = a.inset('left').resolve(containingWidth);
    final right = a.inset('right').resolve(containingWidth);
    var width = style.width.resolve(containingWidth);
    if (width != null && a.boxSizing == AuthoredBoxSizing.borderBox) {
      width -= extraW;
    }
    width ??= out && left != null && right != null
        ? containingWidth -
              left -
              right -
              edge(style.margin.left) -
              edge(style.margin.right) -
              extraW
        : containingWidth -
              edge(style.margin.left) -
              edge(style.margin.right) -
              extraW;
    double? vertical(StyleLength l) =>
        l.kind == StyleLengthKind.percent && containingHeight == null
        ? null
        : l.resolve(containingHeight ?? 0);
    var height = vertical(style.height);
    if (height != null && a.boxSizing == AuthoredBoxSizing.borderBox) {
      height -= extraH;
    }
    final top = vertical(a.inset('top'));
    final bottom = vertical(a.inset('bottom'));
    if (height == null &&
        out &&
        top != null &&
        bottom != null &&
        containingHeight != null) {
      height =
          containingHeight -
          top -
          bottom -
          extraH -
          edge(style.margin.top) -
          edge(style.margin.bottom);
    }
    return FixedUsedBoxSize(
      constrain(style, 'width', width, containingWidth, extraW),
      height == null
          ? null
          : constrain(style, 'height', height, containingHeight, extraH),
    );
  }

  static double constrain(
    ComputedStyle style,
    String axis,
    double value,
    double? basis,
    double extra,
  ) {
    double? resolve(StyleLength? l) =>
        l == null || l.kind == StyleLengthKind.percent && basis == null
        ? null
        : l.resolve(basis ?? 0);
    final adjust = style.authored.boxSizing == AuthoredBoxSizing.borderBox
        ? extra
        : 0.0;
    final lower = math.max(
      0.0,
      (resolve(style.authored.minimum(axis)) ?? 0) - adjust,
    );
    final upper = resolve(axis == 'width' ? style.maxWidth : style.maxHeight);
    return math.max(
      lower,
      upper == null
          ? math.max(0, value)
          : math.min(math.max(0, value), math.max(0, upper - adjust)),
    );
  }
}
