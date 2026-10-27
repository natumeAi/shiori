import 'package:shiori/features/reader/data/resources/reader_resource_budget.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/worker/prepared_publication.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/style_resolver.dart';

/// Detached source/styles and exact resource sizes; no lazy book or archive.
final class PublicationSectionResourcePlan {
  PublicationSectionResourcePlan({
    required this.sectionIndex,
    required this.href,
    required this.cfiBase,
    required this.document,
    required this.styled,
    required List<PublicationResourceReference> references,
    required Map<String, int> lengths,
  }) : references = List.unmodifiable(references),
       lengths = Map.unmodifiable(lengths);
  final int sectionIndex;
  final String href;
  final String cfiBase;
  final SourceDocument document;
  final StyledDocument styled;
  final List<PublicationResourceReference> references;
  final Map<String, int> lengths;
}

/// Consume [resources] once in section preparation, or dispose it if abandoned.
final class PreloadedPublicationSection {
  const PreloadedPublicationSection(this.plan, this.resources);
  final PublicationSectionResourcePlan plan;
  final PreloadedReaderResourceSource resources;
  void dispose() => resources.dispose();
}

/// Freeze only the style lookup contract rather than transfer a resolver or
/// its mutable working lists. Character-data lookups are captured too.
final class PublicationSectionStyles implements StyledDocument {
  factory PublicationSectionStyles(StyledDocument source, int nodeCount) {
    // InlineAccumulator merges adjacent runs by identical style. Preserve the
    // resolver's sharing while freezing; splitting equivalent runs can change
    // native shaping/rounding even when every individual CSS value is equal.
    final frozen = Map<ComputedStyle, ComputedStyle>.identity();
    ComputedStyle freeze(ComputedStyle style) =>
        frozen.putIfAbsent(style, () => _freezeStyle(style));
    return PublicationSectionStyles._(
      List.unmodifiable([
        for (var i = 0; i < nodeCount; i++)
          if (source.styleOf(i) case final style?) freeze(style) else null,
      ]),
      freeze(source.rootStyle),
      List.unmodifiable(source.fontFaces),
    );
  }

  PublicationSectionStyles._(this._styles, this.rootStyle, this.fontFaces);
  final List<ComputedStyle?> _styles;
  @override
  final ComputedStyle rootStyle;
  @override
  final List<StyleFontFace> fontFaces;
  @override
  ComputedStyle? styleOf(int nodeIndex) => _styles[nodeIndex];
}

ComputedStyle _freezeStyle(ComputedStyle style) => ComputedStyle(
  display: style.display,
  margin: style.margin,
  padding: style.padding,
  textIndent: style.textIndent,
  textAlign: style.textAlign,
  fontSize: style.fontSize,
  fontWeight: style.fontWeight,
  fontStyle: style.fontStyle,
  fontFamilies: List.unmodifiable(style.fontFamilies),
  lineHeight: style.lineHeight,
  letterSpacing: style.letterSpacing,
  color: style.color,
  backgroundColor: style.backgroundColor,
  whiteSpace: style.whiteSpace,
  verticalAlign: style.verticalAlign,
  underline: style.underline,
  lineThrough: style.lineThrough,
  overflowWrapAnywhere: style.overflowWrapAnywhere,
  width: style.width,
  height: style.height,
  maxWidth: style.maxWidth,
  maxHeight: style.maxHeight,
  writingMode: style.writingMode,
  direction: style.direction,
  breakBefore: style.breakBefore,
  breakAfter: style.breakAfter,
  listStyleType: style.listStyleType,
);
