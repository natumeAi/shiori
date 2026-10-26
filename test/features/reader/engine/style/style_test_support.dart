import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';

/// Builds a one-or-more-section EPUB in memory. [sections] maps a path under
/// `OEBPS/` to its XHTML; [files] maps other paths under `OEBPS/` to text or
/// bytes (`String` or `Uint8List`).
Uint8List buildEpub({
  required Map<String, String> sections,
  Map<String, Object> files = const {},
  Map<String, Object> rootFiles = const {},
  String metadata = '',
  Map<String, String> spineProperties = const {},
  String spineAttributes = '',
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
    final properties = spineProperties[path];
    spine.write(
      '<itemref idref="s$index"'
      '${properties == null ? '' : ' properties="$properties"'}/>',
    );
    index++;
  }
  for (final path in files.keys) {
    final lower = path.toLowerCase();
    final type = lower.endsWith('.css')
        ? 'text/css'
        : lower.endsWith('.ttf')
        ? 'font/ttf'
        : 'application/octet-stream';
    manifest.write(
      '<item id="f${path.hashCode}" href="$path" media-type="$type"/>',
    );
  }
  add(
    'OEBPS/content.opf',
    '<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" '
        'version="3.0" unique-identifier="uid"><metadata '
        'xmlns:dc="http://purl.org/dc/elements/1.1/">'
        '<dc:identifier id="uid">urn:test</dc:identifier>'
        '<dc:title>t</dc:title>$metadata</metadata>'
        '<manifest>$manifest</manifest>'
        '<spine $spineAttributes>$spine</spine></package>',
  );
  sections.forEach((path, content) => add('OEBPS/$path', content));
  files.forEach((path, content) => add('OEBPS/$path', content));
  rootFiles.forEach(add);
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

String xhtml({
  String head = '',
  String body = '',
  String htmlAttributes = '',
}) =>
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<html xmlns="http://www.w3.org/1999/xhtml" $htmlAttributes>'
    '<head><title>t</title>$head</head><body>$body</body></html>';

/// A resolved single-section sample with lookups by element `id`.
final class StyleSample {
  StyleSample._(this.book, this.document, this.styled);

  factory StyleSample.fromBook(
    EpubBook book, {
    int section = 0,
    ReaderSettings settings = const ReaderSettings(),
  }) {
    final document = book.loadSection(section);
    final styled = const CssStyleResolver().resolve(
      book,
      section,
      document,
      settings,
    );
    return StyleSample._(book, document, styled);
  }

  /// [css] goes into a `<style>` element; [body] is the body markup.
  factory StyleSample.html(
    String body, {
    String css = '',
    String head = '',
    ReaderSettings settings = const ReaderSettings(),
    Map<String, Object> files = const {},
    String htmlAttributes = '',
    String metadata = '',
  }) {
    final book = EpubBook.open(
      buildEpub(
        sections: {
          'ch1.xhtml': xhtml(
            head: '${css.isEmpty ? '' : '<style>$css</style>'}$head',
            body: body,
            htmlAttributes: htmlAttributes,
          ),
        },
        files: files,
        metadata: metadata,
      ),
    );
    return StyleSample.fromBook(book, settings: settings);
  }

  factory StyleSample.fixture(
    String id, {
    ReaderSettings settings = const ReaderSettings(),
  }) => StyleSample.fromBook(
    EpubBook.open(File('assets/reader_fixtures/$id.epub').readAsBytesSync()),
    settings: settings,
  );

  final EpubBook book;
  final SourceDocument document;
  final CssStyledDocument styled;

  int indexOf(bool Function(SourceNode node) test, {int skip = 0}) {
    var seen = 0;
    for (final node in document.nodes) {
      if (node.kind == SourceNodeKind.element && test(node)) {
        if (seen++ == skip) return node.index;
      }
    }
    throw StateError('element not found');
  }

  int byId(String id) => indexOf((n) => n.id == id);

  /// The `skip`-th element named [name].
  int byName(String name, {int skip = 0}) =>
      indexOf((n) => n.localName == name, skip: skip);

  int byClass(String className, {int skip = 0}) => indexOf(
    (n) => (n.attribute('class') ?? '').split(' ').contains(className),
    skip: skip,
  );

  /// Computed style of the element with the given `id`.
  ComputedStyle operator [](String id) => styled.styleOf(byId(id))!;

  ComputedStyle ofIndex(int index) => styled.styleOf(index)!;
}
