import 'dart:ui' as ui;

import 'package:shiori/features/reader/engine/layout/font_mapping.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';

/// One laid-out line of a paragraph. Boxes tile the paragraph height: line
/// `i` spans `[top, bottom)` and the next line starts where it ends.
final class LineInfo {
  const LineInfo({
    required this.start,
    required this.end,
    required this.top,
    required this.bottom,
    required this.baseline,
    required this.left,
    required this.width,
  });

  /// Paragraph UTF-16 range `[start, end)`; includes a trailing hard break.
  final int start;
  final int end;
  final double top;
  final double bottom;
  final double baseline;
  final double left;
  final double width;

  double get height => bottom - top;
}

/// An engine paragraph laid out once at its final width.
final class BuiltParagraph {
  BuiltParagraph({
    required this.paragraph,
    required this.layoutWidth,
    required this.height,
    required this.lines,
    required this.layoutMicros,
  });

  final ui.Paragraph paragraph;
  final double layoutWidth;
  final double height;
  final List<LineInfo> lines;

  /// Wall time of `Paragraph.layout` on the calling isolate, microseconds.
  final int layoutMicros;

  void dispose() => paragraph.dispose();
}

/// Font facts shared by every paragraph of a section.
final class ParagraphFonts {
  ParagraphFonts({this.embedded = const {}});

  /// Lowercase CSS family to engine alias (`@font-face`).
  final Map<String, String> embedded;
  final Map<String, ResolvedFontFamilies> _resolved = {};

  ResolvedFontFamilies resolve(List<String> cssFamilies) =>
      _resolved.putIfAbsent(
        cssFamilies.join('\u0000'),
        () => resolveFontFamilies(cssFamilies, embedded: embedded),
      );

  /// The families requested for the chains seen so far, for the report.
  Iterable<ResolvedFontFamilies> get resolvedChains => _resolved.values;
}

ui.FontWeight _weight(int weight) {
  final index = (weight / 100).round().clamp(1, 9) - 1;
  return ui.FontWeight.values[index];
}

ui.TextAlign _align(StyleTextAlign align) => switch (align) {
  StyleTextAlign.start || StyleTextAlign.left => ui.TextAlign.left,
  StyleTextAlign.right => ui.TextAlign.right,
  StyleTextAlign.center => ui.TextAlign.center,
  StyleTextAlign.justify => ui.TextAlign.justify,
};

double? _heightMultiplier(ComputedStyle style, double fontSize) {
  final multiplier = style.lineHeight.multiplier;
  if (multiplier != null) return multiplier;
  final px = style.lineHeight.px;
  if (px != null && fontSize > 0) return px / fontSize;
  return null;
}

ui.TextStyle _textStyle(
  ComputedStyle style,
  double scale,
  ParagraphFonts fonts,
) {
  final families = fonts.resolve(style.fontFamilies);
  final size = style.fontSize * scale;
  final decorations = <ui.TextDecoration>[
    if (style.underline) ui.TextDecoration.underline,
    if (style.lineThrough) ui.TextDecoration.lineThrough,
  ];
  final background = style.backgroundColor;
  return ui.TextStyle(
    color: ui.Color(style.color),
    fontSize: size,
    fontWeight: _weight(style.fontWeight),
    fontStyle: style.fontStyle == StyleFontStyle.italic
        ? ui.FontStyle.italic
        : ui.FontStyle.normal,
    fontFamily: families.primary,
    fontFamilyFallback: families.fallback,
    letterSpacing: style.letterSpacing * scale,
    height: _heightMultiplier(style, size),
    leadingDistribution: ui.TextLeadingDistribution.even,
    decoration: decorations.isEmpty
        ? null
        : ui.TextDecoration.combine(decorations),
    background: background == null || (background >> 24) == 0
        ? null
        : (ui.Paint()..color = ui.Color(background)),
  );
}

/// Builds and lays out the paragraph of [block] at [layoutWidth].
///
/// Runs on the root isolate; this is the only place text is shaped. The line
/// table is read once here so pagination and anchors never touch the engine
/// for geometry again.
BuiltParagraph buildParagraph(
  TextBlock block,
  double layoutWidth,
  ParagraphFonts fonts,
) {
  final base = block.baseStyle;
  final baseFamilies = fonts.resolve(base.fontFamilies);
  final baseHeight = _heightMultiplier(base, base.fontSize);
  final builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(
      textAlign: _align(base.textAlign),
      textDirection: ui.TextDirection.ltr,
      fontFamily: baseFamilies.primary,
      fontSize: base.fontSize,
      height: baseHeight,
      textHeightBehavior: const ui.TextHeightBehavior(
        leadingDistribution: ui.TextLeadingDistribution.even,
      ),
      strutStyle: baseHeight == null
          ? null
          : ui.StrutStyle(
              fontFamily: baseFamilies.primary,
              fontFamilyFallback: baseFamilies.fallback,
              fontSize: base.fontSize,
              height: baseHeight,
              leadingDistribution: ui.TextLeadingDistribution.even,
            ),
    ),
  );
  for (final run in block.runs) {
    builder.pushStyle(_textStyle(run.style, run.scale, fonts));
    final placeholder = run.placeholderWidth;
    if (placeholder != null) {
      builder.addPlaceholder(
        placeholder,
        1,
        ui.PlaceholderAlignment.baseline,
        baseline: ui.TextBaseline.alphabetic,
        baselineOffset: 1,
      );
    } else {
      builder.addText(block.text.substring(run.start, run.end));
    }
    builder.pop();
  }
  final paragraph = builder.build();
  final width = layoutWidth < 1 ? 1.0 : layoutWidth;
  final watch = Stopwatch()..start();
  paragraph.layout(ui.ParagraphConstraints(width: width));
  watch.stop();
  return BuiltParagraph(
    paragraph: paragraph,
    layoutWidth: width,
    height: paragraph.height,
    lines: _readLines(paragraph, block.text.length),
    layoutMicros: watch.elapsedMicroseconds,
  );
}

/// Reads the line table once. Line ranges come from `getLineNumberAt`, found
/// by galloping and bisection from each line start: `getLineBoundary` costs
/// time linear in the paragraph per call (about 2 ms at 100,000 code units on
/// the host), which made a long paragraph minutes of work.
List<LineInfo> _readLines(ui.Paragraph paragraph, int textLength) {
  final metrics = paragraph.computeLineMetrics();
  final lines = <LineInfo>[];
  var cursor = 0;
  for (var i = 0; i < metrics.length; i++) {
    final metric = metrics[i];
    final top = i == 0 ? 0.0 : metric.baseline - metric.ascent;
    final bottom = i + 1 < metrics.length
        ? metrics[i + 1].baseline - metrics[i + 1].ascent
        : paragraph.height;
    final start = cursor;
    var end = start;
    if (i == metrics.length - 1) {
      end = textLength;
    } else if (start < textLength) {
      end = _lineEnd(paragraph, i, start, textLength);
    }
    lines.add(
      LineInfo(
        start: start,
        end: end,
        top: top,
        bottom: bottom < top ? top : bottom,
        baseline: metric.baseline,
        left: metric.left,
        width: metric.width,
      ),
    );
    cursor = end;
  }
  return lines;
}

/// First offset after [start] that is not on line [line], or [textLength].
int _lineEnd(ui.Paragraph paragraph, int line, int start, int textLength) {
  bool onLine(int offset) {
    final number = paragraph.getLineNumberAt(offset);
    return number != null && number <= line;
  }

  if (!onLine(start)) return start;
  var low = start;
  var step = 16;
  var high = start + 1;
  while (high < textLength && onLine(high)) {
    low = high;
    high = high + step > textLength ? textLength : high + step;
    step *= 2;
  }
  var lo = low;
  var hi = high > textLength ? textLength : high;
  while (hi - lo > 1) {
    final mid = (lo + hi) >> 1;
    if (onLine(mid)) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return hi;
}
