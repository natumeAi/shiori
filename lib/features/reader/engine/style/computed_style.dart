/// Computed style of one element after cascade, inheritance and the reader
/// overrides. Shared contract between the style resolver (engine/style) and
/// the layout engine (engine/layout). Pure Dart: no `dart:ui`.
///
/// Lengths that depend on the containing block stay unresolved
/// ([StyleLength] percent/auto); font-relative units (`em`, `rem`, keywords)
/// are already resolved to CSS px. Add fields here additively when the style
/// matrix in the S2 design (§5.2) needs them; never repurpose a field.
library;

part 'authored_style.dart';

enum StyleDisplay { none, block, inline, listItem, inlineBlock }

enum StyleTextAlign { start, left, right, center, justify }

enum StyleFontStyle { normal, italic }

enum StyleWhiteSpace { normal, pre, preWrap, preLine, nowrap }

/// CSS `list-style-type` (inherited). `none` shows no marker.
enum StyleListStyleType {
  none,
  disc,
  circle,
  square,
  decimal,
  lowerAlpha,
  upperAlpha,
  lowerRoman,
  upperRoman,
}

enum StyleVerticalAlign { baseline, sub, superscript }

enum StyleWritingMode { horizontalTb, verticalRl, verticalLr }

enum StyleDirection { ltr, rtl }

enum StyleLengthKind { px, percent, auto }

/// A length that layout resolves against the containing block.
final class StyleLength {
  const StyleLength.px(this.value) : kind = StyleLengthKind.px;
  const StyleLength.percent(this.value) : kind = StyleLengthKind.percent;
  const StyleLength.auto() : value = 0, kind = StyleLengthKind.auto;

  static const zero = StyleLength.px(0);

  final StyleLengthKind kind;

  /// CSS px for [StyleLengthKind.px], percent (0–100) for
  /// [StyleLengthKind.percent], unused for auto.
  final double value;

  /// Resolved CSS px, or null for auto.
  double? resolve(double containingBlockWidth) => switch (kind) {
    StyleLengthKind.px => value,
    StyleLengthKind.percent => containingBlockWidth * value / 100,
    StyleLengthKind.auto => null,
  };

  @override
  bool operator ==(Object other) =>
      other is StyleLength && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() => switch (kind) {
    StyleLengthKind.px => '${value}px',
    StyleLengthKind.percent => '$value%',
    StyleLengthKind.auto => 'auto',
  };
}

/// CSS `line-height`: `normal`, a unitless multiplier or a px value.
final class StyleLineHeight {
  const StyleLineHeight.normal() : multiplier = null, px = null;
  const StyleLineHeight.multiplier(double this.multiplier) : px = null;
  const StyleLineHeight.px(double this.px) : multiplier = null;

  final double? multiplier;
  final double? px;

  bool get isNormal => multiplier == null && px == null;

  @override
  bool operator ==(Object other) =>
      other is StyleLineHeight &&
      other.multiplier == multiplier &&
      other.px == px;

  @override
  int get hashCode => Object.hash(multiplier, px);
}

/// Four box edges, in the CSS order top/right/bottom/left.
final class StyleEdges {
  const StyleEdges(this.top, this.right, this.bottom, this.left);

  static const zero = StyleEdges(
    StyleLength.zero,
    StyleLength.zero,
    StyleLength.zero,
    StyleLength.zero,
  );

  final StyleLength top;
  final StyleLength right;
  final StyleLength bottom;
  final StyleLength left;

  @override
  bool operator ==(Object other) =>
      other is StyleEdges &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom &&
      other.left == left;

  @override
  int get hashCode => Object.hash(top, right, bottom, left);
}

final class ComputedStyle {
  const ComputedStyle({
    this.authored = const AuthoredStyle.empty(),
    this.display = StyleDisplay.inline,
    this.margin = StyleEdges.zero,
    this.padding = StyleEdges.zero,
    this.textIndent = StyleLength.zero,
    this.textAlign = StyleTextAlign.start,
    this.fontSize = 16,
    this.fontWeight = 400,
    this.fontStyle = StyleFontStyle.normal,
    this.fontFamilies = const [],
    this.lineHeight = const StyleLineHeight.normal(),
    this.letterSpacing = 0,
    this.color = 0xFF000000,
    this.backgroundColor,
    this.whiteSpace = StyleWhiteSpace.normal,
    this.verticalAlign = StyleVerticalAlign.baseline,
    this.underline = false,
    this.lineThrough = false,
    this.overflowWrapAnywhere = false,
    this.width = const StyleLength.auto(),
    this.height = const StyleLength.auto(),
    this.maxWidth,
    this.maxHeight,
    this.writingMode = StyleWritingMode.horizontalTb,
    this.direction = StyleDirection.ltr,
    this.breakBefore = false,
    this.breakAfter = false,
    this.listStyleType = StyleListStyleType.disc,
  });

  final StyleDisplay display;
  final AuthoredStyle authored;
  final StyleEdges margin;
  final StyleEdges padding;
  final StyleLength textIndent;
  final StyleTextAlign textAlign;

  /// Resolved CSS px.
  final double fontSize;

  /// 100–900.
  final int fontWeight;
  final StyleFontStyle fontStyle;

  /// CSS `font-family` list in order, unquoted; generic families keep their
  /// CSS names (`serif`, `sans-serif`, `-apple-system`).
  final List<String> fontFamilies;
  final StyleLineHeight lineHeight;

  /// Resolved CSS px (`em` already multiplied by the effective font size).
  final double letterSpacing;

  /// 0xAARRGGBB.
  final int color;

  /// 0xAARRGGBB, or null for transparent.
  final int? backgroundColor;
  final StyleWhiteSpace whiteSpace;
  final StyleVerticalAlign verticalAlign;
  final bool underline;
  final bool lineThrough;
  final bool overflowWrapAnywhere;
  final StyleLength width;
  final StyleLength height;
  final StyleLength? maxWidth;
  final StyleLength? maxHeight;
  final StyleWritingMode writingMode;
  final StyleDirection direction;

  /// `break-before`/`page-break-before` forces a new page.
  final bool breakBefore;

  /// `break-after`/`page-break-after` forces a new page.
  final bool breakAfter;

  /// Marker type of a list item (inherited from its list).
  final StyleListStyleType listStyleType;
}
