import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/style/style_resolver.dart';

/// Default phone viewport of the Gate C checks (iPhone 14 Pro Max, logical).
const phoneWidth = 430.0;
const phoneHeight = 932.0;

/// The three settings Gate C requires.
const gateSettings = <String, ReaderSettings>{
  'default': ReaderSettings(),
  'size26-lh2.0': ReaderSettings(fontSize: 26, lineHeight: 2.0),
  'size14-ls0.12-margin48': ReaderSettings(
    fontSize: 14,
    letterSpacing: 0.12,
    horizontalMargin: 48,
  ),
};

/// Builds an EPUB in memory. [sections] maps a path under `OEBPS/` to XHTML;
/// [files] maps other paths to text or bytes.
Uint8List buildEpub({
  required Map<String, String> sections,
  Map<String, Object> files = const {},
}) {
  final archive = Archive();
  void add(String path, Object content) {
    final bytes = content is Uint8List
        ? content
        : Uint8List.fromList(utf8.encode(content as String));
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  add(
    'META-INF/container.xml',
    '<?xml version="1.0"?><container version="1.0" '
        'xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles>'
        '<rootfile full-path="OEBPS/content.opf" '
        'media-type="application/oebps-package+xml"/></rootfiles></container>',
  );
  final manifest = StringBuffer();
  final spine = StringBuffer();
  var index = 0;
  for (final path in sections.keys) {
    manifest.write(
      '<item id="s$index" href="$path" media-type="application/xhtml+xml"/>',
    );
    spine.write('<itemref idref="s$index"/>');
    index++;
  }
  var fileIndex = 0;
  for (final path in files.keys) {
    final lower = path.toLowerCase();
    final type = lower.endsWith('.css')
        ? 'text/css'
        : lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.svg')
        ? 'image/svg+xml'
        : 'application/octet-stream';
    manifest.write(
      '<item id="f${fileIndex++}" href="$path" media-type="$type"/>',
    );
  }
  add(
    'OEBPS/content.opf',
    '<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" '
        'version="3.0" unique-identifier="uid"><metadata '
        'xmlns:dc="http://purl.org/dc/elements/1.1/">'
        '<dc:identifier id="uid">urn:test</dc:identifier>'
        '<dc:title>t</dc:title></metadata>'
        '<manifest>$manifest</manifest><spine>$spine</spine></package>',
  );
  sections.forEach((path, content) => add('OEBPS/$path', content));
  files.forEach((path, content) => add('OEBPS/$path', content));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

String xhtml(String body, {String head = ''}) =>
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>t</title>$head'
    '</head><body>$body</body></html>';

/// Opens a bundled synthetic fixture EPUB.
EpubBook openFixture(String id) {
  final file = File('assets/reader_fixtures/$id.epub');
  return EpubBook.open(file.readAsBytesSync());
}

/// A deterministic, tiny user-agent resolver independent of the CSS engine:
/// block/inline defaults, heading and list boxes, `pre`, and the reader
/// settings. Inline `style` attributes support a handful of properties.
final class UaStyleResolver implements StyleResolver {
  const UaStyleResolver();

  @override
  StyledDocument resolve(
    EpubBook book,
    int sectionIndex,
    SourceDocument document,
    ReaderSettings settings,
  ) => _UaStyled(document, settings);
}

const _blockNames = {
  'html', 'body', 'div', 'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', //
  'blockquote', 'ul', 'ol', 'section', 'article', 'figure', 'pre', 'hr',
  'nav', 'header', 'footer', 'aside', 'dl', 'dt', 'dd', 'table', 'tr', 'td',
  'th', 'tbody', 'thead', 'figcaption',
};
const _hiddenNames = {
  'head',
  'script',
  'style',
  'title',
  'meta',
  'link',
  'template',
  'noscript',
};

final class _UaStyled implements StyledDocument {
  _UaStyled(this.document, this.settings) {
    _walk(document.documentElementIndex, null);
  }

  final SourceDocument document;
  final ReaderSettings settings;
  final Map<int, ComputedStyle> _styles = {};

  @override
  List<StyleFontFace> get fontFaces => const [];

  @override
  ComputedStyle? styleOf(int nodeIndex) => _styles[nodeIndex];

  @override
  ComputedStyle get rootStyle =>
      _styles[document.bodyIndex ?? document.documentElementIndex]!;

  void _walk(int index, ComputedStyle? parent) {
    final node = document.node(index);
    if (node.isCharacterData) {
      if (parent != null) _styles[index] = parent;
      return;
    }
    if (node.kind != SourceNodeKind.element) return;
    final name = (node.localName ?? '').toLowerCase();
    if (_hiddenNames.contains(name)) return;
    final style = _compute(node, name, parent);
    _styles[index] = style;
    if (style.display == StyleDisplay.none) return;
    for (final child in node.children) {
      _walk(child, style);
    }
  }

  ComputedStyle _compute(SourceNode node, String name, ComputedStyle? parent) {
    final inherited = parent;
    final family = readerFontOptions
        .firstWhere(
          (option) => option.id == settings.fontFamilyId,
          orElse: () => readerFontOptions.first,
        )
        .cssFamilies;
    var fontSize = inherited?.fontSize ?? settings.fontSize;
    var weight = inherited?.fontWeight ?? 400;
    var fontStyle = inherited?.fontStyle ?? StyleFontStyle.normal;
    var align = inherited?.textAlign ?? StyleTextAlign.start;
    var indent = inherited?.textIndent ?? StyleLength.zero;
    var whiteSpace = inherited?.whiteSpace ?? StyleWhiteSpace.normal;
    var display = _blockNames.contains(name)
        ? StyleDisplay.block
        : StyleDisplay.inline;
    if (name == 'li') display = StyleDisplay.listItem;
    var verticalAlign = StyleVerticalAlign.baseline;
    var underline = inherited?.underline ?? false;
    var marginTop = 0.0;
    var marginSide = 0.0;
    var paddingLeft = 0.0;
    var width = const StyleLength.auto();
    var listType = inherited?.listStyleType ?? StyleListStyleType.disc;
    if (name == 'ol') listType = StyleListStyleType.decimal;
    if (name == 'ul') listType = StyleListStyleType.disc;
    switch (node.attribute('data-list')) {
      case 'none':
        listType = StyleListStyleType.none;
      case 'lower-alpha':
        listType = StyleListStyleType.lowerAlpha;
      case 'upper-roman':
        listType = StyleListStyleType.upperRoman;
      case 'square':
        listType = StyleListStyleType.square;
    }
    final base = fontSize;
    switch (name) {
      case 'h1':
        fontSize = base * 2;
        marginTop = fontSize * 0.67;
        weight = 700;
      case 'h2':
        fontSize = base * 1.5;
        marginTop = fontSize * 0.83;
        weight = 700;
      case 'h3':
        fontSize = base * 1.17;
        marginTop = fontSize;
        weight = 700;
      case 'h4' || 'h5' || 'h6':
        marginTop = fontSize;
        weight = 700;
      case 'p' || 'pre' || 'figure':
        marginTop = fontSize;
      case 'blockquote':
        marginTop = fontSize;
        marginSide = 40;
      case 'ul' || 'ol':
        marginTop = fontSize;
        paddingLeft = 40;
      case 'b' || 'strong':
        weight = 700;
      case 'i' || 'em' || 'cite':
        fontStyle = StyleFontStyle.italic;
      case 'small':
        fontSize = base * 0.83;
      case 'sup' || 'sub':
        fontSize = base * 0.83;
        verticalAlign = name == 'sup'
            ? StyleVerticalAlign.superscript
            : StyleVerticalAlign.sub;
      case 'a' || 'u':
        underline = true;
      case 'rt':
        break;
      case 'hr':
        marginTop = fontSize * 0.5;
      default:
        break;
    }
    if (name == 'pre') whiteSpace = StyleWhiteSpace.pre;
    if (node.attribute('class') == 'hidden') display = StyleDisplay.none;
    final declarations = <String, String>{};
    for (final part in (node.attribute('style') ?? '').split(';')) {
      final colon = part.indexOf(':');
      if (colon > 0) {
        declarations[part.substring(0, colon).trim()] = part
            .substring(colon + 1)
            .trim();
      }
    }
    double? px(String? value) {
      if (value == null) return null;
      if (value.endsWith('px')) {
        return double.tryParse(value.substring(0, value.length - 2));
      }
      if (value.endsWith('em')) {
        final number = double.tryParse(value.substring(0, value.length - 2));
        return number == null ? null : number * fontSize;
      }
      return null;
    }

    if (declarations['display'] == 'none') display = StyleDisplay.none;
    if (declarations['display'] == 'block') display = StyleDisplay.block;
    if (declarations['display'] == 'inline') display = StyleDisplay.inline;
    switch (declarations['white-space']) {
      case 'pre':
        whiteSpace = StyleWhiteSpace.pre;
      case 'pre-wrap':
        whiteSpace = StyleWhiteSpace.preWrap;
      case 'pre-line':
        whiteSpace = StyleWhiteSpace.preLine;
      case 'normal':
        whiteSpace = StyleWhiteSpace.normal;
    }
    switch (declarations['text-align']) {
      case 'center':
        align = StyleTextAlign.center;
      case 'right':
        align = StyleTextAlign.right;
      case 'justify':
        align = StyleTextAlign.justify;
      case 'left':
        align = StyleTextAlign.left;
    }
    final fontSizeOverride = px(declarations['font-size']);
    if (fontSizeOverride != null) fontSize = fontSizeOverride;
    final indentOverride = px(declarations['text-indent']);
    if (indentOverride != null) indent = StyleLength.px(indentOverride);
    final widthOverride = px(declarations['width']);
    if (widthOverride != null) width = StyleLength.px(widthOverride);
    if (declarations['width']?.endsWith('%') ?? false) {
      final percent = double.tryParse(
        declarations['width']!.replaceAll('%', ''),
      );
      if (percent != null) width = StyleLength.percent(percent);
    }
    final heightOverride = px(declarations['height']);
    final marginOverride = px(declarations['margin-top']);
    if (marginOverride != null) marginTop = marginOverride;
    final backgroundText = declarations['background-color'];
    final background = backgroundText == null ? null : 0xFFFFF3CD;
    return ComputedStyle(
      display: display,
      margin: StyleEdges(
        StyleLength.px(marginTop),
        StyleLength.px(marginSide),
        StyleLength.px(marginTop),
        StyleLength.px(marginSide),
      ),
      padding: StyleEdges(
        StyleLength.zero,
        StyleLength.zero,
        StyleLength.zero,
        StyleLength.px(paddingLeft),
      ),
      textIndent: indent,
      textAlign: align,
      fontSize: fontSize,
      fontWeight: weight,
      fontStyle: fontStyle,
      fontFamilies: family,
      lineHeight: StyleLineHeight.multiplier(settings.lineHeight),
      letterSpacing: settings.letterSpacing * fontSize,
      color: 0xFF1D1D1F,
      backgroundColor: background,
      whiteSpace: whiteSpace,
      verticalAlign: verticalAlign,
      underline: underline,
      width: width,
      height: heightOverride == null
          ? const StyleLength.auto()
          : StyleLength.px(heightOverride),
      listStyleType: listType,
      maxWidth: name == 'img' ? const StyleLength.percent(100) : null,
    );
  }
}

/// The resolver the Gate C checks run with: the real CSS engine.
StyleResolver fixtureResolver() => const CssStyleResolver();

/// Prepares section [index] of [book] with [resolver].
Future<PreparedSection> prepareSection(
  EpubBook book,
  int index, {
  required SectionPreparer preparer,
  StyleResolver resolver = const UaStyleResolver(),
  ReaderSettings settings = const ReaderSettings(),
  double width = phoneWidth,
  double height = phoneHeight,
  String contentId = 'test-content',
  int generation = 0,
}) async {
  final document = book.loadSection(index);
  final styled = resolver.resolve(book, index, document, settings);
  return preparer.prepare(
    PrepareRequest(
      book: book,
      sectionIndex: index,
      document: document,
      styled: styled,
      settings: settings,
      viewportWidth: width,
      viewportHeight: height,
      contentId: contentId,
      generation: generation,
    ),
  );
}

/// Initializes the Flutter binding for plain `test` bodies that use
/// `dart:ui` paragraphs, fonts and image codecs.
void initEngineBinding() {
  TestWidgetsFlutterBinding.ensureInitialized();
}
