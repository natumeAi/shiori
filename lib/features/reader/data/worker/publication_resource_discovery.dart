import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/epub/epub_package.dart';
import 'package:shiori/features/reader/data/epub/epub_url.dart';
import 'package:shiori/features/reader/data/source/dom_node.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
import 'package:shiori/features/reader/data/worker/prepared_publication.dart';

/// Reference inventory of the first source and its CSS/SVG dependencies.
/// Does not keep resource bytes, fetch external URLs, or visit other spine
/// sections merely because they exist in the package.
Future<List<PublicationResourceReference>> discoverPublicationResources(
  EpubArchive archive,
  EpubPackage package,
  EpubManifestItem first,
  Future<void> Function() checkpoint,
) async {
  final pending = <EpubManifestItem>[first];
  final visited = <String>{};
  final seen = <(String, String)>{};
  final result = <PublicationResourceReference>[];
  void reference(String source, String url) {
    if (url.isEmpty || !seen.add((source, url))) return;
    final external =
        isExternalUrl(url) || url.startsWith('//') || url.startsWith('#');
    final path = external ? null : resolveUrl(url, source).split('#').first;
    final item = path == null ? null : package.itemByHref(path);
    result.add(
      PublicationResourceReference(
        sourcePath: source,
        url: url,
        path: path,
        mediaType: item?.mediaType,
        present: path != null && archive.contains(path),
      ),
    );
    if (item != null &&
        !visited.contains(item.href) &&
        {'text/css', svgMediaType}.contains(item.mediaType)) {
      pending.add(item);
    }
  }

  void css(String source, String text) {
    for (final match in _cssUrls.allMatches(text)) {
      reference(source, match[1] ?? match[2] ?? match[3]!);
    }
    for (final match in _cssImports.allMatches(text)) {
      reference(source, match[1]!);
    }
  }

  while (pending.isNotEmpty) {
    final item = pending.removeLast();
    if (!visited.add(item.href)) continue;
    await checkpoint();
    final text = archive.text(item.href);
    if (text == null || text.isEmpty) continue;
    if (item.mediaType == 'text/css') {
      css(item.href, text);
      continue;
    }
    final ParsedSection parsed;
    try {
      parsed = SourceParser.parseTree(text, item.mediaType ?? xhtmlMediaType);
    } on Object {
      // A malformed optional SVG is a resource fact, not an import verdict.
      continue;
    }
    final stack = <DomNode>[parsed.tree];
    while (stack.isNotEmpty) {
      final node = stack.removeLast();
      if (node.kind == DomKind.pi) {
        final href = _processingHref.firstMatch(node.data ?? '')?.group(1);
        if (href != null) reference(item.href, href);
      }
      if (node.isElement) {
        final name = node.localName;
        if (name == 'template' && node.namespaceUri == xhtmlNamespace) continue;
        for (final attribute in node.attributes) {
          final key = attribute.localName;
          if (key == 'src' ||
              key == 'poster' ||
              (key == 'href' &&
                  (name == 'link' ||
                      node.namespaceUri == 'http://www.w3.org/2000/svg')) ||
              (key == 'data' && name == 'object')) {
            reference(item.href, attribute.value);
          } else if (key == 'style') {
            css(item.href, attribute.value);
          } else if (key == 'srcset') {
            for (final match in _srcset.allMatches(attribute.value)) {
              reference(item.href, match[2]!);
            }
          }
        }
        if (name == 'style') css(item.href, node.textContent);
      }
      stack.addAll(node.children.reversed);
    }
  }
  return result;
}

final _cssUrls = RegExp(
  r'''url\(\s*(?:"([^"]*)"|'([^']*)'|([^\s)]*))\s*\)''',
  caseSensitive: false,
);
final _cssImports = RegExp(
  r'''@import\s*["']([^"']*)["']''',
  caseSensitive: false,
);
final _processingHref = RegExp(r'''\bhref\s*=\s*["']([^"']*)["']''');
final _srcset = RegExp(r'(\s*)(.+?)\s*((?:\s[\d.]+[wx])+\s*(?:,|$)|,\s+|$)');
