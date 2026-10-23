import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
import 'package:shiori/features/reader/engine/layout/block_builder.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/layout/svg_support.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';

import 'layout_test_support.dart';

LayoutDocument _build(String body) {
  final book = EpubBook.open(
    buildEpub(
      sections: {'chapters/ch.xhtml': xhtml(body)},
      files: {
        'assets/plate.png': Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]),
      },
    ),
  );
  final document = book.loadSection(0);
  return LayoutBlockBuilder(
    document: document,
    styled: fixtureResolver().resolve(
      book,
      0,
      document,
      const ReaderSettings(),
    ),
    sectionHref: book.sections.single.item.href,
    archive: book.archive,
    contentWidth: 400,
  ).build();
}

void main() {
  // Source-side subjects of contentImage.test.ts:196 and :309. S4 owns the
  // reader hit testing, viewer resources and cursor used by the other cases.
  test('serializes an inline SVG content image without rasterizing it', () {
    final image = _build(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 600" '
      'aria-label="chart"><path d="M0 0 L800 600"/></svg>',
    ).blocks.whereType<ImageBlock>().single;
    expect(image.kind, ImageKind.svgVector);
    expect(image.resourcePath, isNull);
    expect(image.svgMarkup, startsWith('<svg'));
    expect(image.svgMarkup, contains('xmlns="http://www.w3.org/2000/svg"'));
    expect(image.svgMarkup, contains('d="M0 0 L800 600"'));
    expect(image.svgMarkup, contains('aria-label="chart"'));
    expect(image.hintWidth, 800);
    expect(image.hintHeight, 600);
  });

  test('uses the original archive resource from an SVG-wrapped image', () {
    final image = _build(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1600 1200" '
      'aria-label="star chart"><image width="1600" height="1200" '
      'href="../assets/plate.png"/></svg>',
    ).blocks.whereType<ImageBlock>().single;
    expect(image.kind, ImageKind.svgWrapper);
    expect(image.resourcePath, 'OEBPS/assets/plate.png');
    expect(image.svgMarkup, isNull);
    expect(image.hintWidth, 1600);
    expect(image.hintHeight, 1200);
  });

  test('linked raster preserves the original resource before product hit testing', () {
    final image = _build(
      '<a href="other.xhtml"><img src="../assets/plate.png" alt="chart"/></a>',
    ).blocks.whereType<ImageBlock>().single;
    expect(image.resourcePath, 'OEBPS/assets/plate.png');
    expect(image.kind, ImageKind.raster);
  });

  test('CSS backgrounds never become content image blocks', () {
    expect(
      _build('<p style="background-image:url(../assets/plate.png)">text</p>')
          .blocks
          .whereType<ImageBlock>(),
      isEmpty,
    );
  });

  test('CSS-hidden images have no prepared content image block', () {
    expect(
      _build('<img src="../assets/plate.png" style="display:none"/>').blocks
          .whereType<ImageBlock>(),
      isEmpty,
    );
  });

  test(
    'SVG dimensions retain viewBox precedence and finite fallback rules',
    () {
      final document = const SourceParser().parse(
        xhtml(
          '<svg xmlns="http://www.w3.org/2000/svg" width="40px" height="30px" '
          'viewBox="0 0 800 600"><path d="M0 0 L800 600"/></svg>',
        ),
      );
      final svg = document.nodes.firstWhere((node) => node.localName == 'svg');
      expect(svgIntrinsicSize(document, svg.index), (
        width: 800.0,
        height: 600.0,
      ));
    },
  );
}
