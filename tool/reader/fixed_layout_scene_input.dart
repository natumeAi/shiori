import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/content_identity.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_key.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';

/// Actual archived author/import/linked styles, with synthetic pinned identity.
final class SceneHarnessInput {
  SceneHarnessInput(
    Map<String, Object?> fixture,
    Map<String, Object?> corpus,
    Uint8List font,
  ) {
    final archive = Archive();
    void add(String path, Object value) {
      final bytes = value is Uint8List
          ? value
          : Uint8List.fromList(utf8.encode(value as String));
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    add(
      'META-INF/container.xml',
      '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="package.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
    );
    add(
      'package.opf',
      (fixture['publication'] as Map<String, Object?>)['packageSource']!,
    );
    add('p0.xhtml', fixture['source']!);
    add('font.ttf', font);
    for (final entry in (corpus['resources'] as Map<String, Object?>).entries) {
      add(entry.key.substring(1), entry.value!);
    }
    book = EpubBook.open(Uint8List.fromList(ZipEncoder().encode(archive)));
    document = const SourceParser().parse(fixture['source'] as String);
    page = SourcePageId(
      content: ContentIdentity(
        BookKey(
          ServerKey(
            ServerEndpoint.parse('https://scene.example.test/').endpoint!,
          ),
          1,
        ),
        fixture['sha256'] as String,
      ),
      sectionIndex: 0,
      spineIndex: 0,
      stableId: fixture['id'] as String,
    );
  }
  late final EpubBook book;
  late final SourceDocument document;
  late final SourcePageId page;
}
