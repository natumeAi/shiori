import 'dart:math' as math;

import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/epub/epub_url.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';
import 'package:shiori/features/reader/engine/layout/inline_accumulator.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/layout/svg_support.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/style_resolver.dart';

const _tableNames = {
  'table',
  'thead',
  'tbody',
  'tfoot',
  'tr',
  'td',
  'th',
  'caption',
  'colgroup',
};
const _unsupportedAtomicCodes = {
  'math': 'math',
  'video': 'video',
  'audio': 'audio',
  'canvas': 'canvas',
  'object': 'object',
  'embed': 'embed',
  'iframe': 'iframe',
};

class _Edges {
  _Edges(this.top, this.bottom, this.left, this.right);

  final double top;
  final double bottom;

  /// Null means `auto`.
  final double? left;
  final double? right;
}

class _ListState {
  _ListState({required this.counter});

  int counter;
}

/// Generated marker text of a list item, or null for `list-style-type:
/// none`. Markers are synthetic: no CFI and no canonical slot.
String? listMarker(StyleListStyleType type, int number) => switch (type) {
  StyleListStyleType.none => null,
  StyleListStyleType.disc => '• ',
  StyleListStyleType.circle => '◦ ',
  StyleListStyleType.square => '▪ ',
  StyleListStyleType.decimal => '$number. ',
  StyleListStyleType.lowerAlpha => '${_alpha(number, lower: true)}. ',
  StyleListStyleType.upperAlpha => '${_alpha(number, lower: false)}. ',
  StyleListStyleType.lowerRoman => '${_roman(number).toLowerCase()}. ',
  StyleListStyleType.upperRoman => '${_roman(number)}. ',
};

String _alpha(int number, {required bool lower}) {
  if (number < 1) return '$number';
  final base = lower ? 0x61 : 0x41;
  final out = StringBuffer();
  var n = number;
  final digits = <int>[];
  while (n > 0) {
    n--;
    digits.add(base + n % 26);
    n ~/= 26;
  }
  for (final unit in digits.reversed) {
    out.writeCharCode(unit);
  }
  return out.toString();
}

String _roman(int number) {
  if (number < 1 || number > 3999) return '$number';
  const table = [
    (1000, 'M'),
    (900, 'CM'),
    (500, 'D'),
    (400, 'CD'),
    (100, 'C'),
    (90, 'XC'),
    (50, 'L'),
    (40, 'XL'),
    (10, 'X'),
    (9, 'IX'),
    (5, 'V'),
    (4, 'IV'),
    (1, 'I'),
  ];
  var n = number;
  final out = StringBuffer();
  for (final (value, text) in table) {
    while (n >= value) {
      out.write(text);
      n -= value;
    }
  }
  return out.toString();
}

/// Builds the pure block model of one section from its projected source
/// document and computed styles.
///
/// Documented differences, counted in [LayoutDocument.differences]:
/// `list-marker-inline` (marker is generated text inside the item, not a
/// hanging outside box), `inline-image-block` (an image splits the
/// paragraph into text, image block, text), `ruby-inline` (ruby annotation
/// text follows its base at half size in parentheses), `sup-sub-no-shift`
/// (superscript/subscript use the resolved font size without a baseline
/// shift), `table-flattened`, `background-lines-only` (block backgrounds
/// cover the text lines, not padding or margins), `nowrap-wraps` (`white-space:
/// pre`/`nowrap` preserve spaces and line breaks but still wrap at the
/// content width, because engine paragraphs always wrap).
final class LayoutBlockBuilder {
  LayoutBlockBuilder({
    required this.document,
    required this.styled,
    required this.sectionHref,
    required this.archive,
    required this.contentWidth,
  });

  final SourceDocument document;
  final StyledDocument styled;
  final String sectionHref;
  final EpubArchive archive;
  final double contentWidth;

  final List<LayoutBlock> _blocks = [];
  final List<UnsupportedItem> _unsupported = [];
  final Map<String, int> _differences = {};
  final List<BlockBackground> _backgrounds = [];
  final List<ComputedStyle> _blockStyles = [];
  final List<_ListState> _lists = [];
  InlineAccumulator _acc = InlineAccumulator();
  double _left = 0;
  double _right = 0;
  double _pendingMargin = 0;
  double _fixedGap = 0;
  bool _pendingBreak = false;
  String? _pendingMarker;
  ComputedStyle? _markerStyle;
  double _scale = 1;

  double get _avail => math.max(1, contentWidth - _left - _right);

  LayoutDocument build() {
    final rootIndex = document.bodyIndex ?? document.documentElementIndex;
    final rootStyle = styled.styleOf(rootIndex) ?? styled.rootStyle;
    if (rootStyle.display != StyleDisplay.none) {
      _block(rootIndex, rootStyle);
    }
    return LayoutDocument(
      blocks: _blocks,
      unsupported: _unsupported,
      differences: _differences,
      contentWidth: contentWidth,
    );
  }

  void _note(String code) =>
      _differences.update(code, (count) => count + 1, ifAbsent: () => 1);

  String _name(SourceNode node) => (node.localName ?? '').toLowerCase();

  _Edges _edges(StyleEdges margin) {
    final width = _avail;
    double px(StyleLength length) => length.resolve(width) ?? 0;
    return _Edges(
      px(margin.top),
      px(margin.bottom),
      margin.left.resolve(width),
      margin.right.resolve(width),
    );
  }

  void _addMargin(double value) {
    if (value > _pendingMargin) _pendingMargin = value;
  }

  double _takeGap() {
    final gap = _fixedGap + _pendingMargin;
    _fixedGap = 0;
    _pendingMargin = 0;
    return gap;
  }

  bool _takeBreak() {
    final value = _pendingBreak;
    _pendingBreak = false;
    return value;
  }

  void _block(int index, ComputedStyle style) {
    final node = document.node(index);
    final name = _name(node);
    final margin = _edges(style.margin);
    final padding = _edges(style.padding);
    final avail = _avail;
    final savedLeft = _left;
    final savedRight = _right;
    final isTable = _tableNames.contains(name);
    if (name == 'table') {
      _unsupported.add(
        UnsupportedItem(code: 'table', nodeIndex: index, textFlows: true),
      );
      _note('table-flattened');
      _flush();
      _addMargin(margin.top);
      _blocks.add(
        UnsupportedBlock(
          index: _blocks.length,
          gapBefore: _takeGap(),
          breakBefore: _takeBreak(),
          leftInset: _left,
          rightInset: _right,
          nodeIndex: index,
          code: 'table',
        ),
      );
    }
    if (style.breakBefore) _pendingBreak = true;

    _addMargin(margin.top);
    final paddingTop = padding.top;
    if (paddingTop > 0) {
      _fixedGap += _pendingMargin + paddingTop;
      _pendingMargin = 0;
    }

    var marginLeft = margin.left;
    var marginRight = margin.right;
    final paddingLeft = padding.left ?? 0;
    final paddingRight = padding.right ?? 0;
    final specifiedWidth = style.width.resolve(avail);
    if (specifiedWidth != null && !isTable) {
      var width = specifiedWidth;
      final maxWidth = style.maxWidth?.resolve(avail);
      if (maxWidth != null && width > maxWidth) width = maxWidth;
      final total = width + paddingLeft + paddingRight;
      final free = math.max(
        0.0,
        avail - (marginLeft ?? 0) - (marginRight ?? 0) - total,
      );
      if (marginLeft == null && marginRight == null) {
        marginLeft = free / 2;
        marginRight = free / 2;
      } else if (marginLeft == null) {
        marginLeft = free;
      } else {
        marginRight = (marginRight ?? 0) + free;
      }
    }
    _left += (marginLeft ?? 0) + paddingLeft;
    _right += (marginRight ?? 0) + paddingRight;

    // The root's background is the page itself, painted by the page painter.
    final background = _blockStyles.isEmpty ? null : style.backgroundColor;
    if (background != null && (background >> 24) != 0) {
      _backgrounds.add(
        BlockBackground(
          color: background,
          left: _left - paddingLeft,
          right: _right - paddingRight,
        ),
      );
      _note('background-lines-only');
    }

    final isList = name == 'ol' || name == 'ul';
    if (isList) {
      final start = int.tryParse(node.attribute('start') ?? '');
      _lists.add(_ListState(counter: (start ?? 1) - 1));
    }
    if (style.display == StyleDisplay.listItem || name == 'li') {
      final list = _lists.isEmpty ? null : _lists.last;
      final value = int.tryParse(node.attribute('value') ?? '');
      if (list != null) {
        list.counter = value ?? list.counter + 1;
      }
      final marker = listMarker(style.listStyleType, list?.counter ?? 1);
      if (marker != null) {
        _pendingMarker = marker;
        _markerStyle = style;
        _note('list-marker-inline');
      }
    }

    _flush();
    _blockStyles.add(style);
    _walkChildren(index);
    _flush();
    _blockStyles.removeLast();

    if (isList) _lists.removeLast();
    if (background != null && (background >> 24) != 0) {
      _backgrounds.removeLast();
    }
    if (padding.bottom > 0) {
      _fixedGap += _pendingMargin + padding.bottom;
      _pendingMargin = 0;
    }
    _addMargin(margin.bottom);
    _left = savedLeft;
    _right = savedRight;
    if (style.breakAfter) _pendingBreak = true;
    _pendingMarker = null;
  }

  void _walkChildren(int parentIndex) {
    for (final child in document.node(parentIndex).children) {
      final node = document.node(child);
      switch (node.kind) {
        case SourceNodeKind.text || SourceNodeKind.cdata:
          final style = styled.styleOf(child);
          if (style == null || style.display == StyleDisplay.none) continue;
          final text = node.text ?? '';
          if (text.isEmpty) continue;
          _acc.addText(child, text, style, scale: _scale);
        case SourceNodeKind.element:
          _element(child);
        case SourceNodeKind.comment || SourceNodeKind.processingInstruction:
          break;
      }
    }
  }

  bool _isBlockLevel(SourceNode node, ComputedStyle style) {
    final name = _name(node);
    if (_tableNames.contains(name)) return true;
    if (name == 'ruby' || name == 'rt' || name == 'rp') return false;
    return style.display == StyleDisplay.block ||
        style.display == StyleDisplay.listItem;
  }

  void _element(int index) {
    final node = document.node(index);
    final name = _name(node);
    if (nonRenderedElementNames.contains(name) &&
        node.namespaceUri != svgNamespace) {
      return;
    }
    final style = styled.styleOf(index);
    if (style == null || style.display == StyleDisplay.none) return;
    if (name == 'br') {
      _acc.addBreak(index, style);
      return;
    }
    if (node.namespaceUri == svgNamespace || name == 'svg') {
      if (name == 'svg') _svg(index, style);
      return;
    }
    if (name == 'img') {
      _image(index, style);
      return;
    }
    if (name == 'hr') {
      _flush();
      final margin = _edges(style.margin);
      _addMargin(margin.top);
      _blocks.add(
        RuleBlock(
          index: _blocks.length,
          gapBefore: _takeGap(),
          breakBefore: _takeBreak(),
          leftInset: _left,
          rightInset: _right,
          nodeIndex: index,
          color: style.color,
        ),
      );
      _addMargin(margin.bottom);
      return;
    }
    final unsupportedCode = _unsupportedAtomicCodes[name];
    if (unsupportedCode != null) {
      _unsupportedBlock(index, unsupportedCode);
      return;
    }
    if (name == 'ruby') {
      _note('ruby-inline');
      _walkChildren(index);
      return;
    }
    if (name == 'rt') {
      final parent = node.parentIndex;
      final hasRp =
          parent != null &&
          document
              .node(parent)
              .children
              .any(
                (sibling) =>
                    document.node(sibling).kind == SourceNodeKind.element &&
                    _name(document.node(sibling)) == 'rp',
              );
      if (!hasRp) _acc.addSynthetic('(', style, scale: _scale * 0.5);
      final saved = _scale;
      _scale = saved * 0.5;
      _walkChildren(index);
      _scale = saved;
      if (!hasRp) _acc.addSynthetic(')', style, scale: _scale * 0.5);
      return;
    }
    if (name == 'rp') {
      _walkChildren(index);
      return;
    }
    if ((name == 'sup' || name == 'sub') &&
        style.verticalAlign != StyleVerticalAlign.baseline) {
      _note('sup-sub-no-shift');
    }
    if (_isBlockLevel(node, style)) {
      _flush();
      _block(index, style);
    } else {
      _walkChildren(index);
    }
  }

  BlockAlign get _containerAlign => switch (_blockStyles.isEmpty
      ? StyleTextAlign.start
      : _blockStyles.last.textAlign) {
    StyleTextAlign.center => BlockAlign.center,
    StyleTextAlign.right => BlockAlign.end,
    _ => BlockAlign.start,
  };

  /// Emits the pending inline content as a paragraph block.
  void _flush() {
    final acc = _acc;
    _acc = InlineAccumulator();
    final blockStyle = _blockStyles.isEmpty
        ? styled.rootStyle
        : _blockStyles.last;
    if (!acc.hasContent && !acc.sawBreak) return;
    final prefixes = <InlinePrefix>[];
    final marker = _pendingMarker;
    final markerStyle = _markerStyle;
    if (marker != null && markerStyle != null) {
      prefixes.add(InlinePrefix.text(marker, markerStyle));
      _pendingMarker = null;
    }
    final indent = blockStyle.textIndent.resolve(_avail) ?? 0;
    if (indent > 0) {
      prefixes.add(InlinePrefix.placeholder(indent, blockStyle));
    }
    final result = acc.finish(blockStyle, prefixes);
    if (result == null) return;
    if (result.runs.any(
      (run) =>
          run.style.whiteSpace == StyleWhiteSpace.pre ||
          run.style.whiteSpace == StyleWhiteSpace.nowrap,
    )) {
      _note('nowrap-wraps');
    }
    _blocks.add(
      TextBlock(
        index: _blocks.length,
        gapBefore: _takeGap(),
        breakBefore: _takeBreak(),
        leftInset: _left,
        rightInset: _right,
        text: result.text,
        runs: result.runs,
        map: result.map,
        baseStyle: blockStyle,
        backgrounds: List.of(_backgrounds),
        firstNodeIndex: result.firstNodeIndex,
        lastNodeIndex: result.lastNodeIndex,
      ),
    );
  }

  void _unsupportedBlock(int index, String code, {bool textFlows = false}) {
    _flush();
    _unsupported.add(
      UnsupportedItem(code: code, nodeIndex: index, textFlows: textFlows),
    );
    _blocks.add(
      UnsupportedBlock(
        index: _blocks.length,
        gapBefore: _takeGap(),
        breakBefore: _takeBreak(),
        leftInset: _left,
        rightInset: _right,
        nodeIndex: index,
        code: code,
      ),
    );
  }

  void _image(int index, ComputedStyle style) {
    final node = document.node(index);
    final source = (node.attribute('src') ?? '').trim();
    if (source.isEmpty) {
      _unsupportedBlock(index, 'image-missing');
      return;
    }
    if (isExternalUrl(source)) {
      _unsupportedBlock(index, 'image-external');
      return;
    }
    final path = resolveUrl(source, sectionHref);
    if (!archive.contains(path)) {
      _unsupportedBlock(index, 'image-missing');
      return;
    }
    _imageBlock(
      ImageKind.raster,
      index,
      style,
      resourcePath: path,
      attrWidth: node.attribute('width'),
      attrHeight: node.attribute('height'),
      alt: node.attribute('alt') ?? '',
    );
  }

  void _svg(int index, ComputedStyle style) {
    final node = document.node(index);
    final size = svgIntrinsicSize(document, index);
    final wrapper = svgWrapperResource(document, index, sectionHref);
    if (wrapper != null) {
      if (!archive.contains(wrapper)) {
        _unsupportedBlock(index, 'image-missing');
        return;
      }
      _imageBlock(
        ImageKind.svgWrapper,
        index,
        style,
        resourcePath: wrapper,
        attrWidth: node.attribute('width'),
        attrHeight: node.attribute('height'),
        hintWidth: size.width,
        hintHeight: size.height,
      );
      return;
    }
    final partial = svgPartialFeatures(document, index);
    if (partial.isNotEmpty) {
      _unsupported.add(
        UnsupportedItem(
          code: 'svg-partial',
          nodeIndex: index,
          textFlows: false,
          detail: partial.join(','),
        ),
      );
    }
    _imageBlock(
      ImageKind.svgVector,
      index,
      style,
      svgMarkup: serializeSvg(document, index),
      attrWidth: node.attribute('width'),
      attrHeight: node.attribute('height'),
      hintWidth: size.width,
      hintHeight: size.height,
      partial: partial,
    );
  }

  void _imageBlock(
    ImageKind kind,
    int index,
    ComputedStyle style, {
    String? resourcePath,
    String? svgMarkup,
    String? attrWidth,
    String? attrHeight,
    double? hintWidth,
    double? hintHeight,
    String alt = '',
    List<String> partial = const [],
  }) {
    if (_acc.hasContent) _note('inline-image-block');
    _flush();
    final margin = _edges(style.margin);
    _addMargin(margin.top);
    final left = margin.left ?? 0;
    final right = margin.right ?? 0;
    _blocks.add(
      ImageBlock(
        index: _blocks.length,
        gapBefore: _takeGap(),
        breakBefore: _takeBreak(),
        leftInset: _left + left,
        rightInset: _right + right,
        anchorNodeIndex: index,
        kind: kind,
        style: style,
        align: margin.left == null && margin.right == null
            ? BlockAlign.center
            : _containerAlign,
        resourcePath: resourcePath,
        svgMarkup: svgMarkup,
        attrWidth: attrWidth,
        attrHeight: attrHeight,
        hintWidth: hintWidth,
        hintHeight: hintHeight,
        alt: alt,
        partialFeatures: partial,
      ),
    );
    _addMargin(margin.bottom);
  }
}
