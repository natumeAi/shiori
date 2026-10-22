import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/engine/layout/block_builder.dart';
import 'package:shiori/features/reader/engine/layout/font_mapping.dart';
import 'package:shiori/features/reader/engine/layout/image_sizing.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/layout/paragraph_map.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';

import 'layout_test_support.dart';

final _png = Uint8List.fromList(const [0x89, 0x50, 0x4e, 0x47]);

LayoutDocument _build(
  String body, {
  Map<String, Object> files = const {},
  double width = 334,
}) {
  final book = EpubBook.open(
    buildEpub(
      sections: {'ch.xhtml': xhtml(body)},
      files: {'img/a.png': _png, ...files},
    ),
  );
  final document = book.loadSection(0);
  final styled = const UaStyleResolver().resolve(
    book,
    0,
    document,
    const ReaderSettings(),
  );
  return LayoutBlockBuilder(
    document: document,
    styled: styled,
    sectionHref: book.sections[0].item.href,
    archive: book.archive,
    contentWidth: width,
  ).build();
}

List<TextBlock> _texts(LayoutDocument d) =>
    d.blocks.whereType<TextBlock>().toList();

void main() {
  group('blocks and inline flow', () {
    test('block children split the surrounding inline content', () {
      final doc = _build(
        '<div>one <b>two</b><p>mid</p>three <i>four</i></div>',
      );
      expect(
        [for (final t in _texts(doc)) t.text],
        ['one two', 'mid', 'three four'],
      );
    });

    test('margins collapse between siblings and the first gap is kept', () {
      final doc = _build('<p>a</p><p>b</p>');
      expect(doc.blocks[0].gapBefore, 18); // 1em of the first paragraph
      expect(doc.blocks[1].gapBefore, 18); // collapsed, not 36
    });

    test('display none removes the subtree; script and style never flow', () {
      final doc = _build(
        '<p>shown</p><p class="hidden">gone</p><script>x</script>'
        '<style>y</style><p>after</p>',
      );
      expect([for (final t in _texts(doc)) t.text], ['shown', 'after']);
    });

    test('text-indent becomes a synthetic placeholder run', () {
      final doc = _build('<p style="text-indent:36px">abc</p>');
      final block = _texts(doc).single;
      expect(block.text, '￼abc');
      expect(block.runs.first.placeholderWidth, 36);
      expect(block.map.sourceAt(0), isNull);
      expect(block.map.sourceAt(1)!.offset, 0);
    });

    test(
      'lists get inline synthetic markers and are counted as a difference',
      () {
        final doc = _build(
          '<ol start="3"><li>x</li><li>y</li></ol><ul><li>z</li></ul>',
        );
        expect([for (final t in _texts(doc)) t.text], ['3. x', '4. y', '• z']);
        for (final block in _texts(doc)) {
          expect(block.map.sourceAt(0), isNull, reason: 'marker is synthetic');
        }
        expect(doc.differences['list-marker-inline'], 3);
      },
    );

    test(
      'ruby keeps rp and rt as source text and adds only generated parens',
      () {
        final withRp = _build(
          '<p><ruby>漢<rp>(</rp><rt>かん</rt><rp>)</rp></ruby>字</p>',
        );
        final a = _texts(withRp).single;
        expect(a.text, '漢(かん)字');
        expect(
          a.map.entries.where((e) => e.kind == MapKind.synthetic),
          isEmpty,
        );
        final rt = a.runs.singleWhere((r) => r.scale == 0.5);
        expect(a.text.substring(rt.start, rt.end), 'かん');

        final noRp = _build('<p><ruby>漢<rt>かん</rt></ruby>字</p>');
        final b = _texts(noRp).single;
        expect(b.text, '漢(かん)字');
        expect(
          b.map.entries.where((e) => e.kind == MapKind.synthetic).length,
          2,
          reason: 'only the generated parentheses are synthetic',
        );
        expect(noRp.differences['ruby-inline'], 1);
      },
    );

    test('sup/sub are reported as supported with a difference', () {
      final doc = _build('<p>x<sup>2</sup></p>');
      expect(doc.differences['sup-sub-no-shift'], 1);
    });

    test('pre blocks are reported as wrapping', () {
      final doc = _build('<pre>a  b\nc</pre>');
      expect(_texts(doc).single.text, 'a  b\nc');
      expect(doc.differences['nowrap-wraps'], 1);
    });

    test('tables flatten to blocks with a marker and an unsupported entry', () {
      final doc = _build(
        '<table><tr><td>a</td><td>b</td></tr></table><p>after</p>',
      );
      expect(doc.unsupported.single.code, 'table');
      expect(doc.unsupported.single.textFlows, isTrue);
      expect(doc.blocks.first, isA<UnsupportedBlock>());
      expect([for (final t in _texts(doc)) t.text], ['a', 'b', 'after']);
      expect(doc.differences['table-flattened'], 1);
    });

    test('hr is a rule block', () {
      final doc = _build('<p>a</p><hr/><p>b</p>');
      expect(doc.blocks[1], isA<RuleBlock>());
    });

    test('percent widths and auto margins inset a block', () {
      final doc = _build('<div style="width:100px"><p>a</p></div>', width: 300);
      final block = _texts(doc).single;
      // Left aligned by default: the unused width goes to the right.
      expect(block.leftInset, 0);
      expect(block.rightInset, 200);
    });
  });

  group('images and SVG', () {
    test('img resolves its archive path; missing and remote are surfaced', () {
      final doc = _build(
        '<img src="img/a.png" alt="x"/><img src="img/none.png"/>'
        '<img src="http://example.com/a.png"/><img/>',
      );
      expect(doc.blocks.length, 4);
      final first = doc.blocks[0] as ImageBlock;
      expect(first.kind, ImageKind.raster);
      expect(first.resourcePath, 'OEBPS/img/a.png');
      expect(first.alt, 'x');
      expect(
        [for (final u in doc.unsupported) u.code],
        ['image-missing', 'image-external', 'image-missing'],
      );
      expect(doc.blocks.sublist(1), everyElement(isA<UnsupportedBlock>()));
    });

    String svg({
      String extra = '',
      String imageAttrs = 'width="64" height="96"',
      String children = '',
    }) =>
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'xmlns:xlink="http://www.w3.org/1999/xlink" id="s" width="100%" '
        'height="100%" viewBox="0 0 64 96" $extra>'
        '<image $imageAttrs xlink:href="img/a.png"/>$children</svg>';

    test('the wrapper fast path applies to a single full-size image', () {
      final doc = _build(svg());
      final block = doc.blocks.single as ImageBlock;
      expect(block.kind, ImageKind.svgWrapper);
      expect(block.resourcePath, 'OEBPS/img/a.png');
      expect(block.hintWidth, 64);
      expect(block.hintHeight, 96);
      expect(doc.unsupported, isEmpty);
    });

    for (final (name, markup) in [
      (
        'a transform on the image',
        svg(imageAttrs: 'width="64" height="96" transform="scale(2)"'),
      ),
      (
        'a clip path',
        svg(imageAttrs: 'width="64" height="96" clip-path="url(#c)"'),
      ),
      ('a mask', svg(imageAttrs: 'width="64" height="96" mask="url(#m)"')),
      ('a filter', svg(imageAttrs: 'width="64" height="96" filter="url(#f)"')),
      (
        'a slice aspect ratio',
        svg(
          imageAttrs:
              'width="64" height="96" preserveAspectRatio="xMidYMid slice"',
        ),
      ),
      ('an offset', svg(imageAttrs: 'x="3" width="64" height="96"')),
      ('a partial image', svg(imageAttrs: 'width="32" height="96"')),
      ('a second graphic', svg(children: '<rect width="4" height="4"/>')),
      (
        'a transformed ancestor',
        '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 64 96"><g transform="scale(2)"><image width="64" height="96" xlink:href="img/a.png"/></g></svg>',
      ),
    ]) {
      test('the wrapper guard refuses $name', () {
        final doc = _build(markup);
        final block = doc.blocks.single as ImageBlock;
        expect(block.kind, ImageKind.svgVector);
        expect(block.svgMarkup, contains('<svg'));
        expect(block.svgMarkup, contains('xmlns="http://www.w3.org/2000/svg"'));
      });
    }

    test('vector SVG with text is listed as partially supported', () {
      final doc = _build(
        '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="40">'
        '<rect width="80" height="40"/><text y="10">t</text></svg>',
      );
      final block = doc.blocks.single as ImageBlock;
      expect(block.kind, ImageKind.svgVector);
      expect(block.partialFeatures, ['text']);
      expect(doc.unsupported.single.code, 'svg-partial');
      expect(doc.unsupported.single.detail, 'text');
    });

    test('atomic unsupported elements get a marker, not silence', () {
      final doc = _build(
        '<video src="v.mp4"></video><p>x</p>'
        '<math xmlns="http://www.w3.org/1998/Math/MathML"><mi>x</mi></math>',
      );
      expect([for (final u in doc.unsupported) u.code], ['video', 'math']);
      expect(_texts(doc).map((t) => t.text), ['x']);
    });

    test('inline images split the paragraph and are counted', () {
      final doc = _build('<p>before <img src="img/a.png"/> after</p>');
      expect(doc.blocks.map((b) => b.runtimeType), [
        TextBlock,
        ImageBlock,
        TextBlock,
      ]);
      expect(doc.differences['inline-image-block'], 1);
    });
  });

  group('image sizing', () {
    ImageBlock block({
      ComputedStyle style = const ComputedStyle(),
      String? attrWidth,
      String? attrHeight,
    }) => ImageBlock(
      index: 0,
      gapBefore: 0,
      breakBefore: false,
      leftInset: 0,
      rightInset: 0,
      anchorNodeIndex: 1,
      kind: ImageKind.raster,
      style: style,
      align: BlockAlign.start,
      attrWidth: attrWidth,
      attrHeight: attrHeight,
    );

    test('a raster keeps its size unless it overflows the content box', () {
      final small = resolveImageBox(
        block(),
        (width: 100, height: 50),
        contentWidth: 334,
        contentHeight: 812,
      );
      expect((small.width, small.height), (100, 50));
      final wide = resolveImageBox(
        block(),
        (width: 668, height: 100),
        contentWidth: 334,
        contentHeight: 812,
      );
      expect((wide.width, wide.height), (334, 50));
    });

    test('a tall image is contained to the page height', () {
      final tall = resolveImageBox(
        block(),
        (width: 1000, height: 4000),
        contentWidth: 334,
        contentHeight: 812,
      );
      expect(tall.height, closeTo(812, 1e-9));
      expect(tall.width, closeTo(203, 1e-9));
    });

    test('css and attribute sizes apply, percentages use the line', () {
      final css = resolveImageBox(
        block(
          style: const ComputedStyle(
            width: StyleLength.px(48),
            height: StyleLength.px(72),
          ),
        ),
        (width: 1000, height: 1000),
        contentWidth: 334,
        contentHeight: 812,
      );
      expect((css.width, css.height), (48, 72));
      final attr = resolveImageBox(
        block(attrWidth: '50%'),
        (width: 100, height: 200),
        contentWidth: 334,
        contentHeight: 812,
      );
      expect(attr.width, 167);
      expect(attr.height, 334);
    });
  });

  group('font mapping', () {
    test('reader font options map to recorded iOS families', () {
      final system = resolveFontFamilies(readerFontOptions[0].cssFamilies);
      expect(system.primary, isNull);
      expect(system.chain, ['(system)']);
      final yahei = resolveFontFamilies(readerFontOptions[2].cssFamilies);
      expect(yahei.primary, 'PingFang SC');
      expect(yahei.notes, contains('Microsoft YaHei -> PingFang SC'));
      final songti = resolveFontFamilies(readerFontOptions[4].cssFamilies);
      expect(songti.primary, 'Songti SC');
      expect(songti.fallback, contains('Times New Roman'));
      final kai = resolveFontFamilies(readerFontOptions[5].cssFamilies);
      expect(kai.primary, 'Kaiti SC');
    });

    test('embedded families win and unknown families pass through', () {
      final resolved = resolveFontFamilies(
        ['"My Font"', 'Georgia', 'Unknown Face'],
        embedded: {'my font': 'shiori-abc-my font'},
      );
      expect(resolved.primary, 'shiori-abc-my font');
      expect(resolved.fallback, ['Georgia', 'Unknown Face']);
    });
  });
}
