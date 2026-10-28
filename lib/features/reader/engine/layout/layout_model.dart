import 'package:shiori/features/reader/engine/layout/paragraph_map.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';

/// Pure block/inline model built from a styled source document. No
/// `dart:ui`: it can be produced in a worker isolate and tested without an
/// engine. Paragraph building and pagination consume it.

/// How a block aligns inside its available width when narrower than it.
enum BlockAlign { start, center, end }

/// A background painted behind a text block (an ancestor's or its own).
final class BlockBackground {
  const BlockBackground({
    required this.color,
    required this.left,
    required this.right,
  });

  /// 0xAARRGGBB.
  final int color;

  /// Horizontal insets from the content box, CSS px.
  final double left;
  final double right;
}

/// A style span over paragraph code units. [scale] multiplies the font size
/// (ruby annotation text); [placeholderWidth] marks a one-code-unit inline
/// placeholder (first-line indent) instead of text.
final class TextStyleRun {
  const TextStyleRun({
    required this.start,
    required this.end,
    required this.style,
    this.scale = 1,
    this.placeholderWidth,
    this.placeholderHeight = 1,
    this.placeholderBaseline = 1,
  });

  final int start;
  final int end;
  final ComputedStyle style;
  final double scale;
  final double? placeholderWidth;
  final double placeholderHeight, placeholderBaseline;
}

sealed class LayoutBlock {
  const LayoutBlock({
    required this.index,
    required this.gapBefore,
    required this.breakBefore,
    required this.leftInset,
    required this.rightInset,
  });

  /// Position in [LayoutDocument.blocks].
  final int index;

  /// Vertical space before the block, CSS px; dropped at the top of a page.
  final double gapBefore;

  /// Starts a new page.
  final bool breakBefore;

  /// Horizontal insets from the content box, CSS px.
  final double leftInset;
  final double rightInset;
}

/// A paragraph of inline content.
final class TextBlock extends LayoutBlock {
  const TextBlock({
    required super.index,
    required super.gapBefore,
    required super.breakBefore,
    required super.leftInset,
    required super.rightInset,
    required this.text,
    required this.runs,
    required this.map,
    required this.baseStyle,
    required this.backgrounds,
    required this.firstNodeIndex,
    required this.lastNodeIndex,
    this.align = BlockAlign.start,
  });

  /// Paragraph text, UTF-16, including generated code units.
  final String text;
  final List<TextStyleRun> runs;
  final ParagraphMap map;

  /// Style of the block container (alignment, line height, strut).
  final ComputedStyle baseStyle;
  final List<BlockBackground> backgrounds;
  final BlockAlign align;

  /// Smallest and largest source node index mapped by this block.
  final int firstNodeIndex;
  final int lastNodeIndex;
}

enum ImageKind { raster, svgWrapper, svgVector }

/// An image or SVG occupying its own block box.
final class ImageBlock extends LayoutBlock {
  const ImageBlock({
    required super.index,
    required super.gapBefore,
    required super.breakBefore,
    required super.leftInset,
    required super.rightInset,
    required this.anchorNodeIndex,
    required this.kind,
    required this.style,
    required this.align,
    this.resourcePath,
    this.svgMarkup,
    this.attrWidth,
    this.attrHeight,
    this.hintWidth,
    this.hintHeight,
    this.alt = '',
    this.partialFeatures = const [],
  });

  /// The `img` element, or the outer `svg` element (the CFI and anchor
  /// identity, also for the wrapper fast path).
  final int anchorNodeIndex;
  final ImageKind kind;
  final ComputedStyle style;
  final BlockAlign align;

  /// Archive path of the raster (raster and wrapper kinds).
  final String? resourcePath;

  /// Serialized outer `svg` (vector kind).
  final String? svgMarkup;

  /// Raw `width`/`height` attribute values.
  final String? attrWidth;
  final String? attrHeight;

  /// Intrinsic size hint from the SVG `viewBox`/size attributes.
  final double? hintWidth;
  final double? hintHeight;
  final String alt;

  /// SVG constructs the renderer drops; non-empty makes the block
  /// supported-with-difference and shows a marker.
  final List<String> partialFeatures;
}

/// A visible marker standing for content that cannot be rendered.
final class UnsupportedBlock extends LayoutBlock {
  const UnsupportedBlock({
    required super.index,
    required super.gapBefore,
    required super.breakBefore,
    required super.leftInset,
    required super.rightInset,
    required this.nodeIndex,
    required this.code,
  });

  final int nodeIndex;
  final String code;
}

/// A horizontal rule.
final class RuleBlock extends LayoutBlock {
  const RuleBlock({
    required super.index,
    required super.gapBefore,
    required super.breakBefore,
    required super.leftInset,
    required super.rightInset,
    required this.nodeIndex,
    required this.color,
  });

  final int nodeIndex;
  final int color;
}

/// Content the engine could not render faithfully. Listed, never dropped.
final class UnsupportedItem {
  const UnsupportedItem({
    required this.code,
    required this.nodeIndex,
    required this.textFlows,
    this.detail = '',
  });

  /// Stable code, for example `svg-partial`, `image-missing`, `table`.
  final String code;
  final int nodeIndex;

  /// True when the element's text still flows into the pages.
  final bool textFlows;
  final String detail;
}

/// The block model of one section.
final class LayoutDocument {
  LayoutDocument({
    required List<LayoutBlock> blocks,
    required List<UnsupportedItem> unsupported,
    required Map<String, int> differences,
    required this.contentWidth,
  }) : blocks = List.unmodifiable(blocks),
       unsupported = List.unmodifiable(unsupported),
       differences = Map.unmodifiable(differences);

  final List<LayoutBlock> blocks;
  final List<UnsupportedItem> unsupported;

  /// Documented rendering differences that occurred, code to count, for
  /// example `ruby-inline`, `list-marker-inline`, `inline-image-block`.
  final Map<String, int> differences;
  final double contentWidth;
}

/// Element names the layout treats as one atomic box. Their descendants
/// never flow as text.
const atomicElementNames = {
  'img',
  'svg',
  'math',
  'video',
  'audio',
  'canvas',
  'object',
  'embed',
  'iframe',
};

/// Elements whose text never flows.
const nonRenderedElementNames = {
  'script',
  'style',
  'noscript',
  'template',
  'head',
  'title',
  'meta',
  'link',
  'base',
};
