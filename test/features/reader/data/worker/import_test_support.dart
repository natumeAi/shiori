import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;
import 'package:crypto/crypto.dart' as crypto;
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/content_identity.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_key.dart';

import '../epub/raw_zip_test_support.dart';

final importBookKey = BookKey(
  ServerKey(ServerEndpoint.parse('https://fixture.invalid/library').endpoint!),
  7,
);

ContentIdentity identityFor(File file, {BookKey? key}) => ContentIdentity(
  key ?? importBookKey,
  crypto.sha256.convert(file.readAsBytesSync()).toString(),
);

String sourcePage({
  String body = '<p>First text😀</p>',
  String css = '',
  String head = '',
  String rootAttributes = '',
  String bodyAttributes = '',
}) =>
    '<html xmlns="http://www.w3.org/1999/xhtml" $rootAttributes>'
    '<head><title>Fixture</title>$head<style>$css</style></head>'
    '<body $bodyAttributes>$body</body></html>';

const viewportHead =
    '<meta name="viewport" content="width=600,height=800"/>'
    '<meta name="source-viewport" content="width=1200,height=1600"/>';
const simpleFixedBody = '<img src="page.png" width="600" height="800"/>';
const complexFixedBody =
    '<div style="position:absolute;left:12px;top:20px">'
    'Positioned<span> text</span></div>'
    '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="800" '
    'viewBox="0 0 600 800"><rect width="40" height="50"/>'
    '<image href="page.png" width="600" height="800"/></svg>';

Map<String, String> importEntries({
  List<String>? sources,
  String layout = 'reflowable',
  List<String> properties = const [],
  List<bool> linear = const [],
  String progression = 'ltr',
  String language = 'en',
  String mediaType = 'application/xhtml+xml',
}) {
  final pages = sources ?? [sourcePage()];
  return {
    'mimetype': 'application/epub+zip',
    'META-INF/container.xml':
        '<container '
        'xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
        '<rootfiles><rootfile full-path="EPUB/package.opf" '
        'media-type="application/oebps-package+xml"/></rootfiles></container>',
    'EPUB/package.opf':
        '<package xmlns="http://www.idpf.org/2007/opf" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" version="3.0">'
        '<metadata><dc:title>Generated import</dc:title><dc:creator>Test</dc:creator>'
        '<dc:identifier>fixture</dc:identifier><dc:language>$language</dc:language>'
        '<meta property="rendition:layout">$layout</meta>'
        '<meta property="rendition:orientation">portrait</meta>'
        '<meta property="rendition:spread">auto</meta>'
        '<meta property="rendition:viewport">width=600,height=800</meta>'
        '</metadata><manifest>'
        '${[for (var i = 0; i < pages.length; i++) '<item id="s$i" href="s$i.xhtml" media-type="$mediaType"/>'].join()}'
        '<item id="image" href="page.png" media-type="image/png"/>'
        '<item id="sheet" href="style.css" media-type="text/css"/>'
        '<item id="nested" href="nested.css" media-type="text/css"/>'
        '<item id="svg" href="art.svg" media-type="image/svg+xml"/>'
        '</manifest><spine page-progression-direction="$progression">'
        '${[for (var i = 0; i < pages.length; i++) '<itemref id="ref$i" idref="s$i" properties="${i < properties.length ? properties[i] : ''}" linear="${i < linear.length && !linear[i] ? 'no' : 'yes'}"/>'].join()}'
        '</spine></package>',
    for (var i = 0; i < pages.length; i++) 'EPUB/s$i.xhtml': pages[i],
    'EPUB/page.png': 'synthetic-image-bytes',
    'EPUB/style.css':
        '@import "nested.css"; body { background: url(page.png); }',
    'EPUB/nested.css': '@import "style.css"; p { direction: rtl; }',
    'EPUB/art.svg':
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'width="600" height="800"><image href="page.png"/></svg>',
  };
}

Uint8List importZip(Map<String, String> entries, {String? badCrc}) => rawZip([
  for (final entry in entries.entries)
    RawZipEntry(
      entry.key,
      entry.key == 'EPUB/page.png' ? _pagePng() : utf8.encode(entry.value),
      method: entry.key == 'mimetype' ? 0 : 8,
      crc: entry.key == badCrc ? 0 : null,
    ),
]);

/// One opaque black RGBA pixel; valid image bytes without Flutter decoding.
List<int> _pagePng() {
  List<int> uint32(int value) =>
      (ByteData(4)..setUint32(0, value)).buffer.asUint8List();
  List<int> chunk(String type, List<int> data) {
    final payload = [...ascii.encode(type), ...data];
    return [...uint32(data.length), ...payload, ...uint32(getCrc32(payload))];
  }

  return [
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    ...chunk('IHDR', [...uint32(1), ...uint32(1), 8, 6, 0, 0, 0]),
    ...chunk('IDAT', ZLibEncoder().convert([0, 0, 0, 0, 255])),
    ...chunk('IEND', []),
  ];
}

File writeImport(
  Directory directory,
  Map<String, String> entries, {
  String name = 'fixture',
  String? badCrc,
}) =>
    File('${directory.path}/$name.epub')
      ..writeAsBytesSync(importZip(entries, badCrc: badCrc));
