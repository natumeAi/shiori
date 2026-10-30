import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/resources/archive_reader_resource_source.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_svg_text_fonts.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';

import '../../contract_test_values.dart';
import '../style/style_test_support.dart';

final class _ReadSpy implements ReaderResourceSource {
  int reads = 0;
  @override
  Uint8List? bytes(String path) {
    reads++;
    throw StateError('Unexpected resource read');
  }

  @override
  bool contains(String path) => false;
  @override
  int size(String path) => 0;
  @override
  void dispose() {}
}

void main() {
  for (final attributes in [
    'rel="stylesheet" type="text/plain"',
    'rel="alternate stylesheet" type="text/css"',
    'rel="icon" type="text/css"',
  ]) {
    test('ineligible link $attributes is ignored without reading', () {
      final sample = StyleSample.html(
        '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="80">'
        '<text id="t" x="10" y="30">AVATAR</text></svg>',
        head:
            '<meta name="viewport" content="width=320,height=240"/>'
            '<link $attributes href="absent.css"/>',
        css: 'text{fill:red}',
        metadata: '<meta property="rendition:layout">pre-paginated</meta>',
      );
      addTearDown(sample.book.archive.close);
      final resources = _ReadSpy();
      final source = FixedSourceLease(
        page: contractPage(id: sample.book.sections.single.item.href),
        document: sample.document,
        styles: sample.styled,
        rendition: sectionRendition(sample.book, 0),
        resources: resources,
        retainedSourceBytes: 1024,
        releaseSource: () {},
      );
      addTearDown(source.dispose);
      final presentation = FixedSvgTextFontService(
        source,
        FontRegistry(),
      ).presentation;
      expect(presentation.problems, isEmpty);
      expect(
        presentation.values[sample.byId('t')],
        containsPair('fill', '#f00'),
      );
      expect(resources.reads, 0);
    });
  }

  test('projected inline rules need no raw section or unused sheet reads', () {
    final sample = StyleSample.html(
      '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="80">'
      '<text id="t" x="10" y="30">AVATAR</text></svg>',
      head:
          '<meta name="viewport" content="width=320,height=240"/>'
          '<style media="print">@import "absent.css";</style>'
          '<style type="text/plain">@import "absent.css";</style>',
      css:
          '@font-face{font-family:Fixture;src:url(font.ttf)}'
          'text{font-kerning:none;fill:red}',
      metadata: '<meta property="rendition:layout">pre-paginated</meta>',
    );
    addTearDown(sample.book.archive.close);
    final resources = _ReadSpy();
    final source = FixedSourceLease(
      page: contractPage(id: sample.book.sections.single.item.href),
      document: sample.document,
      styles: sample.styled,
      rendition: sectionRendition(sample.book, 0),
      resources: resources,
      retainedSourceBytes: 1024,
      releaseSource: () {},
    );
    addTearDown(source.dispose);
    final presentation = FixedSvgTextFontService(
      source,
      FontRegistry(),
    ).presentation;
    expect(presentation.problems, isEmpty);
    expect(
      presentation.values[sample.byId('t')],
      containsPair('font-kerning', 'none'),
    );
    expect(presentation.values[sample.byId('t')], containsPair('fill', '#f00'));
    expect(resources.reads, 0);
  });

  for (final kind in [
    'linked sheet',
    'linked empty type',
    'linked CSS type',
    'inline import',
    'inline url import',
  ]) {
    final inline = kind.startsWith('inline');
    final type = switch (kind) {
      'linked empty type' => 'type=""',
      'linked CSS type' => 'type=" TeXt/CsS "',
      _ => '',
    };
    test('$kind resolves nested bases and media', () {
      final sample = StyleSample.html(
        '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="80">'
        '<text id="t" x="10" y="30">AVATAR</text></svg>',
        head:
            '<meta name="viewport" content="width=320,height=240"/>'
            '<link rel="alternate stylesheet" href="absent.css"/>'
            '<link rel="stylesheet" href="print.css" media="print"/>'
            '<style type="text/plain">@import "absent.css";</style>'
            '<style media="print">text{font-kerning:none}</style>'
            '${inline ? '' : '<link rel="stylesheet" $type href="styles/main.css#sheet" media="screen and (min-width:300px)"/>'}',
        css: inline
            ? '@import ${kind == 'inline url import' ? 'url("styles/main.css")' : '"styles/main.css"'} screen and (min-width:300px);'
            : '',
        files: {
          'styles/main.css':
              '@import "nested/text.css#rules" screen;'
              '@import "absent.css" print;'
              'text{fill:red}',
          'styles/nested/text.css': 'text{font-kerning:normal;stroke:blue}',
        },
        metadata: '<meta property="rendition:layout">pre-paginated</meta>',
      );
      addTearDown(sample.book.archive.close);
      final source = FixedSourceLease(
        page: contractPage(id: sample.book.sections.single.item.href),
        document: sample.document,
        styles: sample.styled,
        rendition: sectionRendition(sample.book, 0),
        resources: ArchiveReaderResourceSource(sample.book.archive),
        retainedSourceBytes: 1024,
        releaseSource: () {},
      );
      addTearDown(source.dispose);
      final presentation = FixedSvgTextFontService(
        source,
        FontRegistry(),
      ).presentation;
      expect(presentation.problems, isEmpty);
      expect(
        presentation.values[sample.byId('t')],
        containsPair('font-kerning', 'normal'),
      );
      expect(
        presentation.values[sample.byId('t')],
        containsPair('fill', '#f00'),
      );
      expect(
        presentation.values[sample.byId('t')],
        containsPair('stroke', '#00f'),
      );
    });
  }
}
