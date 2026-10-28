import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
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

/// Pinned SFNT decoration metrics, in font units.
///
/// Fixed authored scenes draw decoration bands themselves so one line keeps
/// one band across shifted sub/sup runs. Reflow keeps the engine decoration.
final class FontDecorationMetrics {
  const FontDecorationMetrics({
    required this.unitsPerEm,
    required this.underlinePosition,
    required this.underlineThickness,
    required this.strikeoutPosition,
    required this.strikeoutThickness,
  });

  final int unitsPerEm;
  final int underlinePosition;
  final int underlineThickness;
  final int strikeoutPosition;
  final int strikeoutThickness;

  double underlineOffsetPx(double fontSize) =>
      -underlinePosition * fontSize / unitsPerEm;
  double underlineThicknessPx(double fontSize) =>
      underlineThickness * fontSize / unitsPerEm;
  double strikeoutOffsetPx(double fontSize) =>
      -strikeoutPosition * fontSize / unitsPerEm;
  double strikeoutThicknessPx(double fontSize) =>
      strikeoutThickness * fontSize / unitsPerEm;

  /// Reads the SFNT `head`, `post` and `OS/2` tables. WOFF/WOFF2 is not
  /// decoded here; callers fall back to the engine decoration.
  static FontDecorationMetrics? tryParseSfnt(Uint8List bytes) {
    if (bytes.length < 12) return null;
    final data = ByteData.sublistView(bytes);
    final tag = data.getUint32(0);
    if (tag != 0x00010000 && tag != 0x4f54544f && tag != 0x74727565) {
      return null;
    }
    final count = data.getUint16(4);
    if (count == 0 || 12 + count * 16 > bytes.length) return null;
    int? head, post, os2;
    for (var i = 0; i < count; i++) {
      final at = 12 + i * 16;
      final name = data.getUint32(at);
      final offset = data.getUint32(at + 8);
      final length = data.getUint32(at + 12);
      if (offset + length > bytes.length || length < 4) continue;
      if (name == 0x68656164) head = offset;
      if (name == 0x706f7374) post = offset;
      if (name == 0x4f532f32) os2 = offset;
    }
    if (head == null || post == null) return null;
    if (head + 20 > bytes.length || post + 12 > bytes.length) return null;
    final unitsPerEm = data.getUint16(head + 18);
    if (unitsPerEm == 0) return null;
    final underlinePosition = data.getInt16(post + 8);
    final underlineThickness = data.getInt16(post + 10);
    var strikeoutPosition = 0, strikeoutThickness = 0;
    if (os2 != null && os2 + 30 <= bytes.length) {
      strikeoutThickness = data.getInt16(os2 + 26);
      strikeoutPosition = data.getInt16(os2 + 28);
    }
    return FontDecorationMetrics(
      unitsPerEm: unitsPerEm,
      underlinePosition: underlinePosition,
      underlineThickness: underlineThickness,
      strikeoutPosition: strikeoutPosition,
      strikeoutThickness: strikeoutThickness,
    );
  }
}

/// Font facts shared by every paragraph of a section.
final class ParagraphFonts {
  ParagraphFonts({
    this.embedded = const {},
    this.selectFace,
    this.decorationMetrics = const {},
  });

  /// Lowercase CSS family to engine alias (`@font-face`).
  final Map<String, String> embedded;

  /// A3 supplies descriptor-aware selection for admitted embedded faces.
  final ResolvedFontFamilies Function(ParagraphFontRequest)? selectFace;

  /// Engine alias to pinned SFNT decoration metrics for fixed scenes.
  final Map<String, FontDecorationMetrics> decorationMetrics;
  final Map<String, ResolvedFontFamilies> _resolved = {};

  ResolvedFontFamilies resolve(
    List<String> cssFamilies, {
    int weight = 400,
    StyleFontStyle style = StyleFontStyle.normal,
  }) => _resolved.putIfAbsent(
    '${cssFamilies.join('\u0000')}|$weight|${style.name}',
    () =>
        selectFace?.call(ParagraphFontRequest(cssFamilies, weight, style)) ??
        resolveFontFamilies(cssFamilies, embedded: embedded),
  );

  /// The families requested for the chains seen so far, for the report.
  Iterable<ResolvedFontFamilies> get resolvedChains => _resolved.values;
}

/// Family order and the computed CSS descriptors at each painted run.
final class ParagraphFontRequest {
  ParagraphFontRequest(List<String> families, this.weight, this.style)
    : families = List.unmodifiable(families);
  final List<String> families;
  final int weight;
  final StyleFontStyle style;
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
  ParagraphFonts fonts, {
  bool paintBackgrounds = true,
  bool paintText = true,
  bool naturalHeight = false,
  bool paintDecorations = true,
}) {
  final families = fonts.resolve(
    style.fontFamilies,
    weight: style.fontWeight,
    style: style.fontStyle,
  );
  final size = style.fontSize * scale;
  final decorations = <ui.TextDecoration>[
    if (style.underline) ui.TextDecoration.underline,
    if (style.lineThrough) ui.TextDecoration.lineThrough,
  ];
  final background = style.backgroundColor;
  return ui.TextStyle(
    color:
        !paintText ||
            !paintBackgrounds &&
                style.authored.visibility == AuthoredVisibility.hidden
        ? const ui.Color(0x00000000)
        : ui.Color(style.color),
    fontSize: size,
    fontWeight: _weight(style.fontWeight),
    fontStyle: style.fontStyle == StyleFontStyle.italic
        ? ui.FontStyle.italic
        : ui.FontStyle.normal,
    fontFamily: families.primary,
    fontFamilyFallback: families.fallback,
    letterSpacing: style.letterSpacing * scale,
    wordSpacing: style.authored.wordSpacing * scale,
    height: naturalHeight ? null : _heightMultiplier(style, size),
    leadingDistribution: ui.TextLeadingDistribution.even,
    decoration: !paintText || !paintDecorations || decorations.isEmpty
        ? null
        : ui.TextDecoration.combine(decorations),
    background:
        !paintText ||
            !paintBackgrounds ||
            background == null ||
            (background >> 24) == 0
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
  ParagraphFonts fonts, {
  bool paintBackgrounds = true,
  List<ui.TextRange>? paintRanges,
  bool paintDecorations = true,
}) {
  ReaderWorkGuard.check(ReaderWork.paragraphLayout);
  final base = block.baseStyle;
  final baseFamilies = fonts.resolve(
    base.fontFamilies,
    weight: base.fontWeight,
    style: base.fontStyle,
  );
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
    final boundaries = <int>{run.start, run.end};
    if (paintRanges != null && run.placeholderWidth == null) {
      for (final range in paintRanges) {
        if (range.start > run.start && range.start < run.end) {
          boundaries.add(range.start);
        }
        if (range.end > run.start && range.end < run.end) {
          boundaries.add(range.end);
        }
      }
    }
    final cuts = boundaries.toList()..sort();
    for (var i = 0; i + 1 < cuts.length; i++) {
      final start = cuts[i], end = cuts[i + 1];
      final visible =
          paintRanges == null ||
          paintRanges.any((r) => r.start <= start && r.end >= end);
      builder.pushStyle(
        _textStyle(
          run.style,
          run.scale,
          fonts,
          paintBackgrounds: paintBackgrounds,
          paintText: visible,
          paintDecorations: paintDecorations,
        ),
      );
      final placeholder = run.placeholderWidth;
      if (placeholder != null) {
        builder.addPlaceholder(
          placeholder,
          run.placeholderHeight,
          ui.PlaceholderAlignment.baseline,
          baseline: ui.TextBaseline.alphabetic,
          baselineOffset: run.placeholderBaseline,
        );
      } else {
        builder.addText(block.text.substring(start, end));
      }
      builder.pop();
    }
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

/// Natural font metrics for CSS half-leading. The caller admits this temporary
/// Paragraph separately; it is destroyed before returning, including on error.
({double ascent, double descent}) measureInlineFont(
  ComputedStyle style,
  double scale,
  ParagraphFonts fonts,
) {
  ReaderWorkGuard.check(ReaderWork.paragraphLayout);
  final builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(
      textDirection: ui.TextDirection.ltr,
      fontSize: style.fontSize * scale,
    ),
  )..pushStyle(_textStyle(style, scale, fonts, naturalHeight: true));
  builder.addText('M');
  final paragraph = builder.build();
  try {
    paragraph.layout(const ui.ParagraphConstraints(width: 100000));
    final metric = paragraph.computeLineMetrics().single;
    return (ascent: metric.unscaledAscent, descent: metric.descent);
  } finally {
    paragraph.dispose();
  }
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
