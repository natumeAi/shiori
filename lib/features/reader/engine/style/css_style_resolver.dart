/// Cascade, inheritance and the reference reader overrides for one section.
/// Pure Dart (no `dart:ui`, no Flutter imports); safe in a worker isolate.
library;

import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/epub/epub_url.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/css_properties.dart';
import 'package:shiori/features/reader/engine/style/css_selector.dart';
import 'package:shiori/features/reader/engine/style/css_stylesheet.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/style/reader_stylesheets.dart';
import 'package:shiori/features/reader/engine/style/style_diagnostic.dart';
import 'package:shiori/features/reader/engine/style/style_resolver.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';

/// The result of [CssStyleResolver.resolve].
final class CssStyledDocument implements StyledDocument {
  CssStyledDocument._(
    this._document,
    this._styles,
    this._rootStyle,
    List<StyleFontFace> fontFaces,
    this.diagnostics,
    this.fixedLayout,
  ) : fontFaces = List.unmodifiable(fontFaces);

  final SourceDocument _document;
  final List<ComputedStyle?> _styles;
  final ComputedStyle _rootStyle;

  /// Ignored or approximated CSS, aggregated. Never carries book prose.
  final List<StyleDiagnostic> diagnostics;

  /// True when the reader layout CSS was omitted (fixed-layout section).
  final bool fixedLayout;

  @override
  final List<StyleFontFace> fontFaces;

  @override
  ComputedStyle get rootStyle => _rootStyle;

  @override
  ComputedStyle? styleOf(int nodeIndex) {
    final node = _document.nodes[nodeIndex];
    return switch (node.kind) {
      SourceNodeKind.element => _styles[nodeIndex],
      SourceNodeKind.text || SourceNodeKind.cdata =>
        node.parentIndex == null ? null : _styles[node.parentIndex!],
      _ => null,
    };
  }

  /// Total count of diagnostics of [kind].
  int count(StyleDiagnosticKind kind) => diagnostics
      .where((d) => d.kind == kind)
      .fold(0, (sum, d) => sum + d.count);
}

/// Resolves author CSS (linked, `<style>`, inline, `@import`), a minimal HTML
/// user-agent sheet and the reference reader overrides into [ComputedStyle]s.
final class CssStyleResolver implements StyleResolver {
  const CssStyleResolver();

  @override
  CssStyledDocument resolve(
    EpubBook book,
    int sectionIndex,
    SourceDocument document,
    ReaderSettings settings,
  ) {
    final sink = StyleDiagnosticSink();
    final item = book.sections[sectionIndex].item;
    final fixed = isFixedLayoutSection(book, sectionIndex);
    final tree = StyleTree(document);

    String? read(String path) {
      try {
        return book.archive.text(path);
      } on Object {
        return null;
      }
    }

    final author = CssSheetBuilder(sink: sink, reader: read);
    _collectAuthorSheets(
      book,
      item.href,
      item.mediaType,
      document,
      tree,
      author,
      sink,
      read,
    );
    final override = CssSheetBuilder(firstOrder: author.nextOrder)
      ..addStylesheet(
        readerOverrideCss(settings, fixedLayout: fixed),
        item.href,
      );

    final entries = <_Entry>[
      for (final rule in _userAgentRules) _Entry(rule, isUserAgent: true),
      for (final rule in author.rules) _Entry(rule),
      for (final rule in override.rules) _Entry(rule),
    ];
    final index = _RuleIndex(entries);
    final computed = _Computer(document, tree, index, sink).run();

    final faces = _resolveFontFaces(book, author.fontFaces, sink);
    final root = document.bodyIndex ?? document.documentElementIndex;
    return CssStyledDocument._(
      document,
      computed,
      computed[root] ?? const ComputedStyle(),
      faces,
      sink.diagnostics,
      fixed,
    );
  }
}

final List<CssRule> _userAgentRules =
    (CssSheetBuilder()..addStylesheet(userAgentCss, '')).rules;

final List<CssDeclaration> _paginatorInline = parseInlineStyle(
  'margin: 0 !important',
  null,
);

// ---------------------------------------------------------------------------
// Author sheet discovery.

void _collectAuthorSheets(
  EpubBook book,
  String sectionPath,
  String? mediaType,
  SourceDocument document,
  StyleTree tree,
  CssSheetBuilder builder,
  StyleDiagnosticSink sink,
  String? Function(String path) read,
) {
  List<String>? originalStyles;
  final projectedStyleCount = document.nodes
      .where((n) => n.kind == SourceNodeKind.element && n.localName == 'style')
      .length;
  if (projectedStyleCount > 0) {
    originalStyles = _originalStyleTexts(book, sectionPath, mediaType);
    if (originalStyles != null &&
        originalStyles.length != projectedStyleCount) {
      originalStyles = null;
    }
  }
  var styleOrdinal = 0;
  for (final node in document.nodes) {
    if (node.kind != SourceNodeKind.element) continue;
    final name = node.localName?.toLowerCase();
    if (name == 'link') {
      final rel = node.attribute('rel')?.toLowerCase().split(RegExp(r'\s+'));
      final href = node.attribute('href');
      if (rel == null || !rel.contains('stylesheet') || href == null) continue;
      if (rel.contains('alternate')) continue;
      if (!_screenMedia(node.attribute('media'))) {
        sink.add(StyleDiagnosticKind.stylesheetSkipped, 'media');
        continue;
      }
      if (isExternalUrl(href)) {
        sink.add(StyleDiagnosticKind.stylesheetSkipped, 'external');
        continue;
      }
      final path = _stripFragment(resolveUrl(href, sectionPath));
      final text = read(path);
      if (text == null) {
        sink.add(StyleDiagnosticKind.stylesheetNotFound, 'link');
        continue;
      }
      builder.addStylesheet(text, path);
    } else if (name == 'style') {
      final ordinal = styleOrdinal++;
      final type = node.attribute('type')?.trim().toLowerCase();
      if (type != null && type.isNotEmpty && type != 'text/css') continue;
      if (!_screenMedia(node.attribute('media'))) {
        sink.add(StyleDiagnosticKind.stylesheetSkipped, 'media');
        continue;
      }
      final text = originalStyles != null
          ? originalStyles[ordinal]
          : _textOf(document, node);
      if (text.isNotEmpty) builder.addStylesheet(text, sectionPath);
    }
  }
}

/// `<style>` texts of the section as written in the package. The projected
/// document carries length-neutral resource tokens instead of `url()` targets
/// in `<style>` text, which cannot be resolved to archive paths.
List<String>? _originalStyleTexts(
  EpubBook book,
  String sectionPath,
  String? mediaType,
) {
  try {
    final raw = book.archive.text(sectionPath);
    if (raw == null) return null;
    final original = const SourceParser().parse(
      raw,
      mediaType: mediaType ?? xhtmlMediaType,
      protect: false,
    );
    return [
      for (final node in original.nodes)
        if (node.kind == SourceNodeKind.element &&
            node.localName?.toLowerCase() == 'style')
          _textOf(original, node),
    ];
  } on Object {
    return null;
  }
}

String _textOf(SourceDocument document, SourceNode element) {
  final buffer = StringBuffer();
  for (final child in element.children) {
    final node = document.nodes[child];
    if (node.isCharacterData) buffer.write(node.text ?? '');
  }
  return buffer.toString();
}

bool _screenMedia(String? media) {
  if (media == null || media.trim().isEmpty) return true;
  for (final query in media.split(',')) {
    final text = query.trim().toLowerCase();
    if (text.startsWith('not ') || text.contains('(')) continue;
    final type = text.replaceFirst(RegExp(r'^only\s+'), '');
    if (type == 'all' || type == 'screen') return true;
  }
  return false;
}

String _stripFragment(String path) {
  final hash = path.indexOf('#');
  return hash < 0 ? path : path.substring(0, hash);
}

List<StyleFontFace> _resolveFontFaces(
  EpubBook book,
  List<CssFontFace> faces,
  StyleDiagnosticSink sink,
) {
  final result = <StyleFontFace>[];
  final seen = <String>{};
  for (final face in faces) {
    String? chosen;
    String? fallback;
    for (final url in face.urls) {
      if (isExternalUrl(url) || url.startsWith('data:')) continue;
      final path = _stripFragment(resolveUrl(url, face.basePath));
      if (!book.archive.contains(path)) continue;
      fallback ??= path;
      final lower = path.toLowerCase();
      if (lower.endsWith('.ttf') ||
          lower.endsWith('.otf') ||
          lower.endsWith('.ttc')) {
        chosen = path;
        break;
      }
    }
    if (chosen == null && fallback != null) {
      sink.add(StyleDiagnosticKind.approximatedValue, '@font-face format');
      chosen = fallback;
    }
    if (chosen == null) {
      sink.add(StyleDiagnosticKind.stylesheetNotFound, '@font-face');
      continue;
    }
    final key = '${face.family}|${face.weight}|${face.style.name}|$chosen';
    if (!seen.add(key)) continue;
    result.add(
      StyleFontFace(
        family: face.family,
        archivePath: chosen,
        weight: face.weight,
        style: face.style,
      ),
    );
  }
  return result;
}

// ---------------------------------------------------------------------------
// Rule index and cascade.

final class _Entry {
  const _Entry(this.rule, {this.isUserAgent = false});
  final CssRule rule;
  final bool isUserAgent;
}

final class _RuleIndex {
  _RuleIndex(List<_Entry> entries) {
    for (final entry in entries) {
      final selector = entry.rule.selector;
      switch (selector.bucketKind) {
        case '#':
          byId.putIfAbsent(selector.bucketKey, () => []).add(entry);
        case '.':
          byClass.putIfAbsent(selector.bucketKey, () => []).add(entry);
        case 't':
          byType.putIfAbsent(selector.bucketKey, () => []).add(entry);
        default:
          universal.add(entry);
      }
    }
  }

  final Map<String, List<_Entry>> byId = {};
  final Map<String, List<_Entry>> byClass = {};
  final Map<String, List<_Entry>> byType = {};
  final List<_Entry> universal = [];
}

final class _Candidate {
  const _Candidate(
    this.level,
    this.inline,
    this.specificity,
    this.order,
    this.declaration,
  );

  final int level;
  final int inline;
  final int specificity;
  final int order;
  final CssDeclaration declaration;

  static int compare(_Candidate a, _Candidate b) {
    var c = a.level.compareTo(b.level);
    if (c != 0) return c;
    c = a.inline.compareTo(b.inline);
    if (c != 0) return c;
    c = a.specificity.compareTo(b.specificity);
    if (c != 0) return c;
    return a.order.compareTo(b.order);
  }
}

final class _Computer {
  _Computer(this.document, this.tree, this.index, this.sink);

  final SourceDocument document;
  final StyleTree tree;
  final _RuleIndex index;
  final StyleDiagnosticSink sink;
  final Map<String, List<CssDeclaration>> _inlineCache = {};
  double _rootFontSize = 16;

  List<ComputedStyle?> run() {
    final nodes = document.nodes;
    final styles = List<ComputedStyle?>.filled(nodes.length, null);
    final skipped = List<bool>.filled(nodes.length, false);
    final rootIndex = document.documentElementIndex;
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node.kind != SourceNodeKind.element) continue;
      final parentIndex = node.parentIndex;
      if (parentIndex != null && skipped[parentIndex]) {
        skipped[i] = true;
        continue;
      }
      if (parentIndex == rootIndex && tree.nameOf(i) == 'head') {
        skipped[i] = true;
        continue;
      }
      final parentStyle = parentIndex == null ? null : styles[parentIndex];
      final spec = _cascade(i);
      final style = _compute(i, spec, parentStyle);
      styles[i] = style;
      if (i == rootIndex) _rootFontSize = style.fontSize;
    }
    return styles;
  }

  Map<String, Object> _cascade(int element) {
    final node = tree.node(element);
    final candidates = <_Candidate>[];

    void addEntry(_Entry entry) {
      final rule = entry.rule;
      if (!rule.selector.matches(tree, element)) return;
      for (final declaration in rule.declarations) {
        candidates.add(
          _Candidate(
            entry.isUserAgent ? 0 : (declaration.important ? 3 : 2),
            0,
            rule.selector.specificity,
            rule.order,
            declaration,
          ),
        );
      }
    }

    final name = tree.nameOf(element);
    final id = node.id;
    if (id != null && id.isNotEmpty) {
      index.byId[id]?.forEach(addEntry);
    }
    for (final className in tree.classesOf(element)) {
      index.byClass[className]?.forEach(addEntry);
    }
    if (name != null) index.byType[name]?.forEach(addEntry);
    index.universal.forEach(addEntry);

    for (final declaration in _presentationalHints(element, name)) {
      candidates.add(_Candidate(2, 0, -1, -1, declaration));
    }
    final inlineStyle = node.attribute('style');
    if (inlineStyle != null && inlineStyle.trim().isNotEmpty) {
      final declarations = _inlineCache.putIfAbsent(
        inlineStyle,
        () => parseInlineStyle(inlineStyle, sink),
      );
      for (final declaration in declarations) {
        candidates.add(
          _Candidate(declaration.important ? 3 : 2, 1, 0, 0, declaration),
        );
      }
    }
    if (element == document.documentElementIndex ||
        element == document.bodyIndex) {
      for (final declaration in _paginatorInline) {
        candidates.add(_Candidate(3, 1, 0, 1, declaration));
      }
    }

    candidates.sort(_Candidate.compare);
    final spec = <String, Object>{};
    for (final candidate in candidates) {
      spec[candidate.declaration.property] = candidate.declaration.value;
    }
    return spec;
  }

  Iterable<CssDeclaration> _presentationalHints(int element, String? name) {
    final node = tree.node(element);
    final text = StringBuffer();
    if (name == 'font') {
      final color = node.attribute('color');
      if (color != null) text.write('color:${_attr(color)};');
      final face = node.attribute('face');
      if (face != null) text.write('font-family:${_attr(face)};');
      final size = node.attribute('size');
      if (size != null) {
        final keyword = _fontSizeKeyword(size.trim());
        if (keyword != null) text.write('font-size:$keyword;');
      }
    } else if (name == 'img') {
      final width = _dimension(node.attribute('width'));
      if (width != null) text.write('width:$width;');
      final height = _dimension(node.attribute('height'));
      if (height != null) text.write('height:$height;');
    }
    if (text.isEmpty) return const [];
    return _inlineCache.putIfAbsent(
      text.toString(),
      () => parseInlineStyle(text.toString(), null),
    );
  }

  String _attr(String value) => value.replaceAll(RegExp(r'[;{}]'), '');

  String? _dimension(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^\s*(\d+(?:\.\d+)?)(%?)\s*$').firstMatch(value);
    if (match == null) return null;
    return match.group(2) == '%' ? '${match.group(1)}%' : '${match.group(1)}px';
  }

  String? _fontSizeKeyword(String value) {
    const keywords = [
      'x-small',
      'small',
      'medium',
      'large',
      'x-large',
      'xx-large',
      'xxx-large',
    ];
    final relative = value.startsWith('+') || value.startsWith('-');
    final number = int.tryParse(value);
    if (number == null) return null;
    final step = relative ? 3 + number : number;
    return keywords[(step.clamp(1, 7)) - 1];
  }

  // -------------------------------------------------------------------------

  ComputedStyle _compute(
    int element,
    Map<String, Object> spec,
    ComputedStyle? parent,
  ) {
    const initial = ComputedStyle(fontSize: 16);
    final base = parent ?? initial;

    /// Looks up [property]; null means "take the parent's value (inherited) or
    /// the initial value", resolved by the caller through [mode].
    Object? value(String property, {required bool inherited}) {
      final specified = spec[property];
      if (specified == null) return inherited ? _inherit : _initial;
      if (specified is CssKeyword) {
        return switch (specified) {
          CssKeyword.inherit => _inherit,
          CssKeyword.initial => _initial,
          CssKeyword.unset => inherited ? _inherit : _initial,
        };
      }
      return specified;
    }

    // font-size first: em units of every other property use it.
    final fontSizeValue = value('font-size', inherited: true);
    final fontSize = identical(fontSizeValue, _inherit)
        ? base.fontSize
        : identical(fontSizeValue, _initial)
        ? 16.0
        : _fontSizePx(fontSizeValue as CssLength, base.fontSize);

    /// Non-inherited length: `inherit` takes the parent's value for the
    /// property, `initial` the initial one.
    StyleLength boxLength(
      String property,
      StyleLength Function(ComputedStyle s) fromParent,
      StyleLength initialValue,
    ) {
      final v = value(property, inherited: false);
      if (identical(v, _inherit)) return fromParent(base);
      if (identical(v, _initial)) return initialValue;
      return _styleLength(v! as CssLength, fontSize);
    }

    final margin = StyleEdges(
      boxLength('margin-top', (s) => s.margin.top, StyleLength.zero),
      boxLength('margin-right', (s) => s.margin.right, StyleLength.zero),
      boxLength('margin-bottom', (s) => s.margin.bottom, StyleLength.zero),
      boxLength('margin-left', (s) => s.margin.left, StyleLength.zero),
    );
    final padding = StyleEdges(
      boxLength('padding-top', (s) => s.padding.top, StyleLength.zero),
      boxLength('padding-right', (s) => s.padding.right, StyleLength.zero),
      boxLength('padding-bottom', (s) => s.padding.bottom, StyleLength.zero),
      boxLength('padding-left', (s) => s.padding.left, StyleLength.zero),
    );

    final indentValue = value('text-indent', inherited: true);
    final textIndent = identical(indentValue, _inherit)
        ? base.textIndent
        : identical(indentValue, _initial)
        ? StyleLength.zero
        : _styleLength(indentValue! as CssLength, fontSize);

    T pick<T>(String property, T inheritedValue, T initialValue) {
      final v = value(
        property,
        inherited: inheritedProperties.contains(property),
      );
      if (identical(v, _inherit)) return inheritedValue;
      if (identical(v, _initial)) return initialValue;
      return v! as T;
    }

    final display = pick<StyleDisplay>(
      'display',
      base.display,
      StyleDisplay.inline,
    );
    final textAlign = pick<StyleTextAlign>(
      'text-align',
      base.textAlign,
      StyleTextAlign.start,
    );
    final fontStyle = pick<StyleFontStyle>(
      'font-style',
      base.fontStyle,
      StyleFontStyle.normal,
    );
    final families = pick<List<String>>(
      'font-family',
      base.fontFamilies,
      const [],
    );
    final whiteSpace = pick<StyleWhiteSpace>(
      'white-space',
      base.whiteSpace,
      StyleWhiteSpace.normal,
    );
    final verticalAlign = pick<StyleVerticalAlign>(
      'vertical-align',
      base.verticalAlign,
      StyleVerticalAlign.baseline,
    );
    final overflowWrap = pick<bool>(
      'overflow-wrap',
      base.overflowWrapAnywhere,
      false,
    );
    final writingMode = pick<StyleWritingMode>(
      'writing-mode',
      base.writingMode,
      StyleWritingMode.horizontalTb,
    );
    final direction = pick<StyleDirection>(
      'direction',
      base.direction,
      StyleDirection.ltr,
    );
    final breakBefore = pick<bool>('break-before', base.breakBefore, false);
    final breakAfter = pick<bool>('break-after', base.breakAfter, false);
    final listStyleType = pick<StyleListStyleType>(
      'list-style-type',
      base.listStyleType,
      StyleListStyleType.disc,
    );

    // font-weight
    final weightValue = value('font-weight', inherited: true);
    final int fontWeight;
    if (identical(weightValue, _inherit)) {
      fontWeight = base.fontWeight;
    } else if (identical(weightValue, _initial)) {
      fontWeight = 400;
    } else {
      final w = weightValue! as CssFontWeight;
      fontWeight = w.weight ?? _relativeWeight(base.fontWeight, w.relative);
    }

    // line-height
    final lineValue = value('line-height', inherited: true);
    final StyleLineHeight lineHeight;
    if (identical(lineValue, _inherit)) {
      lineHeight = base.lineHeight;
    } else if (identical(lineValue, _initial)) {
      lineHeight = const StyleLineHeight.normal();
    } else {
      final l = lineValue! as CssLineHeight;
      if (l.multiplier != null) {
        lineHeight = StyleLineHeight.multiplier(l.multiplier!);
      } else if (l.length != null) {
        final px = _styleLength(l.length!, fontSize);
        lineHeight = px.kind == StyleLengthKind.percent
            ? StyleLineHeight.px(fontSize * px.value / 100)
            : StyleLineHeight.px(px.value);
      } else {
        lineHeight = const StyleLineHeight.normal();
      }
    }

    // letter-spacing (px; em uses this element's font size)
    final spacingValue = value('letter-spacing', inherited: true);
    final double letterSpacing;
    if (identical(spacingValue, _inherit)) {
      letterSpacing = base.letterSpacing;
    } else if (identical(spacingValue, _initial)) {
      letterSpacing = 0;
    } else {
      letterSpacing = _styleLength(spacingValue! as CssLength, fontSize).value;
    }

    // color
    final colorValue = value('color', inherited: true);
    final int color;
    if (identical(colorValue, _inherit) || identical(colorValue, _initial)) {
      color = identical(colorValue, _inherit) ? base.color : 0xFF000000;
    } else {
      final c = colorValue! as CssColor;
      color = c.isCurrent ? base.color : c.argb;
    }

    // background-color (not inherited)
    final backgroundValue = value('background-color', inherited: false);
    final int? backgroundColor;
    if (identical(backgroundValue, _inherit)) {
      backgroundColor = base.backgroundColor;
    } else if (identical(backgroundValue, _initial)) {
      backgroundColor = null;
    } else {
      final c = backgroundValue! as CssColor;
      final argb = c.isCurrent ? color : c.argb;
      backgroundColor = (argb >> 24) == 0 ? null : argb;
    }

    // text decoration (visually propagates to descendants)
    final decorationValue = value('text-decoration-line', inherited: false);
    var underline = false;
    var lineThrough = false;
    if (identical(decorationValue, _inherit)) {
      underline = base.underline;
      lineThrough = base.lineThrough;
    } else if (!identical(decorationValue, _initial)) {
      final d = decorationValue! as CssDecoration;
      underline = d.underline;
      lineThrough = d.lineThrough;
    }
    underline = underline || base.underline;
    lineThrough = lineThrough || base.lineThrough;

    StyleLength? maxLength(
      String property,
      StyleLength? Function(ComputedStyle) parentValue,
    ) {
      final v = value(property, inherited: false);
      if (identical(v, _inherit)) return parentValue(base);
      if (identical(v, _initial)) return null;
      final l = v! as CssLength;
      return l.unit == CssLengthUnit.none ? null : _styleLength(l, fontSize);
    }

    return ComputedStyle(
      display: display,
      margin: margin,
      padding: padding,
      textIndent: textIndent,
      textAlign: textAlign,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      fontFamilies: families,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      color: color,
      backgroundColor: backgroundColor,
      whiteSpace: whiteSpace,
      verticalAlign: verticalAlign,
      underline: underline,
      lineThrough: lineThrough,
      overflowWrapAnywhere: overflowWrap,
      width: boxLength('width', (s) => s.width, const StyleLength.auto()),
      height: boxLength('height', (s) => s.height, const StyleLength.auto()),
      maxWidth: maxLength('max-width', (s) => s.maxWidth),
      maxHeight: maxLength('max-height', (s) => s.maxHeight),
      writingMode: writingMode,
      direction: direction,
      breakBefore: breakBefore,
      breakAfter: breakAfter,
      listStyleType: listStyleType,
    );
  }

  double _fontSizePx(CssLength length, double parentFontSize) =>
      switch (length.unit) {
        CssLengthUnit.px => length.value,
        CssLengthUnit.em => length.value * parentFontSize,
        CssLengthUnit.rem => length.value * _rootFontSize,
        CssLengthUnit.percent => length.value / 100 * parentFontSize,
        CssLengthUnit.auto || CssLengthUnit.none => parentFontSize,
      };

  StyleLength _styleLength(CssLength length, double fontSize) =>
      switch (length.unit) {
        CssLengthUnit.px => StyleLength.px(length.value),
        CssLengthUnit.em => StyleLength.px(length.value * fontSize),
        CssLengthUnit.rem => StyleLength.px(length.value * _rootFontSize),
        CssLengthUnit.percent => StyleLength.percent(length.value),
        CssLengthUnit.auto || CssLengthUnit.none => const StyleLength.auto(),
      };

  int _relativeWeight(int parent, int relative) {
    if (relative > 0) {
      if (parent < 350) return 400;
      if (parent < 550) return 700;
      return 900;
    }
    if (parent < 550) return 100;
    if (parent < 750) return 400;
    return 700;
  }
}

const Object _inherit = _Marker('inherit');
const Object _initial = _Marker('initial');

final class _Marker {
  const _Marker(this.name);
  final String name;
}
