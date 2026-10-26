import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/canonical/canonical_text.dart';
import 'package:shiori/features/reader/data/cfi/cfi.dart';
import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/epub/epub_loader.dart';
import 'package:shiori/features/reader/data/epub/epub_package.dart';
import 'package:shiori/features/reader/data/source/html_adapter.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
import 'package:shiori/features/reader/data/source/xml_parser.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/image_cache.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/layout/paragraph_factory.dart';
import 'package:shiori/features/reader/engine/layout/svg_picture.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';
import 'package:shiori/features/reader/engine/pagination/section_paginator.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';
import 'package:shiori/features/reader/engine/style/css_stylesheet.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';

import '../layout/layout_test_support.dart';

void main() {
  initEngineBinding();
  late Uint8List bytes;
  late EpubBook book;
  late SourceDocument document;
  late PreparedSection section;
  late CanonicalIndex index;
  late PrepareRequest request;
  final images = ReaderImageCache();
  final preparer = SectionPreparer();
  final source = xhtml('<p>Guarded text.</p>');
  final expression = Cfi.parse('epubcfi(/6/2)');
  setUpAll(() async {
    bytes = buildEpub(sections: {'s.xhtml': source});
    book = EpubBook.open(bytes);
    document = book.loadSection(0);
    index = CanonicalIndex.build(document);
    request = PrepareRequest(
      book: book,
      sectionIndex: 0,
      document: document,
      styled: fixtureResolver().resolve(
        book,
        0,
        document,
        const ReaderSettings(),
      ),
      settings: const ReaderSettings(),
      viewportWidth: 400,
      viewportHeight: 600,
      contentId: 'guard-test',
    );
    section = await preparer.prepare(request);
  });
  tearDownAll(() {
    section.dispose();
    images.clearUnleased();
  });

  final entries = <String, FutureOr<Object?> Function()>{
    'source parse': () => const SourceParser().parse(source),
    'source parseTree': () => SourceParser.parseTree(source, xhtmlMediaType),
    'HTML parse': () => parseHtmlDocument('<p>Text</p>'),
    'XML parse': () => parseXmlDocument(source),
    'CFI parse': () => Cfi.parse('epubcfi(/6/2!/4/2/1:0)'),
    'ZIP parse': () => EpubArchive.open(bytes),
    'archive bytes': () => book.archive.bytes('OEBPS/s.xhtml'),
    'archive text': () => book.archive.text('OEBPS/s.xhtml'),
    'stylesheet parse': () {
      final builder = CssSheetBuilder();
      builder.addStylesheet('p { color: red }', 's.css');
      return builder.rules;
    },
    'inline style parse': () => parseInlineStyle('color: red', null),
    'canonical code points': () {
      var count = 0;
      forEachCodePoint('text', (_, _) => count++);
      return count;
    },
    'canonical count': () => countCanonicalCharacters('text'),
    'canonical index': () => CanonicalIndex.build(document),
    'canonical entry JSON': () => index.entries.single.toJson(),
    'canonical index JSON': () => index.toJson(),
    'source projection JSON': () => document.toProjectionJson(),
    'CFI step JSON': () => CfiStep(index: 2).toJson(),
    'CFI expression JSON': expression.toJson,
    'TOC JSON': () => const EpubTocItem(href: 's.xhtml').toJson(),
    'settings JSON': () => const ReaderSettings().toJson(),
    'resource graph JSON': () =>
        EpubSectionLoader(book.archive, book.package).graph,
    'paragraph layout': () {
      final block = section.blocks.first.block as TextBlock;
      final built = buildParagraph(block, 350, ParagraphFonts());
      final height = built.height;
      built.dispose();
      return height;
    },
    'font load': () => FontRegistry().load(book.archive, [], scope: 'guard'),
    'image header decode': () => images.intrinsicSize('bad', Uint8List(0)),
    'image pixel decode': () =>
        images.lease('bad', Uint8List(0), targetWidth: 1, targetHeight: 1),
    'SVG decode': () async {
      final vector = await loadVectorSvg(
        '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">'
        '<rect width="10" height="10"/></svg>',
      );
      expect(vector, isNotNull);
      vector!.dispose();
      return true;
    },
    'section preparation': () async {
      final prepared = await preparer.prepare(request);
      final count = prepared.pageCount;
      prepared.dispose();
      return count;
    },
    'pagination add': () {
      final paginator = SectionPaginator(
        sectionIndex: 0,
        layoutKey: 'guard',
        pageHeight: 600,
      );
      paginator.add(section.blocks.first);
      return true;
    },
    'pagination finish': () {
      final paginator = SectionPaginator(
        sectionIndex: 0,
        layoutKey: 'guard',
        pageHeight: 600,
      );
      paginator.finish();
      return paginator.pages.length;
    },
  };
  for (final entry in entries.entries) {
    test('${entry.key} rejects callback work and works outside it', () async {
      await expectLater(
        Future<Object?>.sync(() => ReaderWorkGuard.callback(entry.value)),
        throwsAssertionError,
      );
      expect(ReaderWorkGuard.inCallback, isFalse);
      await entry.value();
    });
  }
  for (final work in ReaderWork.values) {
    test('${work.name} guard is scoped to callbacks', () {
      ReaderWorkGuard.check(work);
      expect(
        () => ReaderWorkGuard.callback(() => ReaderWorkGuard.check(work)),
        throwsAssertionError,
      );
      expect(ReaderWorkGuard.inCallback, isFalse);
    });
  }
}
