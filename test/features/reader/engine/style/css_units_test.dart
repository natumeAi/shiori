import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';

import 'style_test_support.dart';

/// Fixed-layout sample (no reader layout override): html font-size 20px so
/// rem differs from the 16 px default, body font-size 10px so em differs
/// from rem, and `#t` inherits the body size.
StyleSample _sample(String css, {String body = '<p id="t">t</p>'}) {
  final book = EpubBook.open(
    buildEpub(
      sections: {
        'ch1.xhtml': xhtml(
          head:
              '<style>html { font-size: 20px } body { font-size: 10px } '
              '$css</style>',
          body: body,
        ),
      },
      spineProperties: const {'ch1.xhtml': 'rendition:layout-pre-paginated'},
    ),
  );
  return StyleSample.fromBook(book);
}

void main() {
  group('lengths resolve to CSS px', () {
    final cases = <String, StyleLength>{
      '12px': const StyleLength.px(12),
      '9pt': const StyleLength.px(12),
      '1pc': const StyleLength.px(16),
      '1in': const StyleLength.px(96),
      '2.54cm': const StyleLength.px(96),
      '25.4mm': const StyleLength.px(96),
      '2em': const StyleLength.px(20),
      '1.5rem': const StyleLength.px(30),
      '4ex': const StyleLength.px(20),
      '25%': const StyleLength.percent(25),
      '0': StyleLength.zero,
      '-3px': const StyleLength.px(-3),
      'auto': const StyleLength.auto(),
    };
    cases.forEach((value, expected) {
      test('margin-left: $value', () {
        final sample = _sample('p { margin-left: $value }');
        final actual = sample['t'].margin.left;
        expect(actual.kind, expected.kind);
        expect(actual.value, closeTo(expected.value, 1e-9));
      });
    });

    test('padding rejects negative and auto', () {
      final sample = _sample(
        'p { padding-left: 4px; padding-left: -1px; padding-left: auto }',
      );
      expect(sample['t'].padding.left, const StyleLength.px(4));
    });

    test('text-indent keeps percentages and resolves em', () {
      expect(
        _sample('p { text-indent: 2em }')['t'].textIndent,
        const StyleLength.px(20),
      );
      expect(
        _sample('p { text-indent: 10% }')['t'].textIndent,
        const StyleLength.percent(10),
      );
    });

    test('width, height and max-* lengths', () {
      final style = _sample(
        'p { width: 50%; height: 3em; max-width: 100%; max-height: 40px }',
      )['t'];
      expect(style.width, const StyleLength.percent(50));
      expect(style.height, const StyleLength.px(30));
      expect(style.maxWidth, const StyleLength.percent(100));
      expect(style.maxHeight, const StyleLength.px(40));
      final none = _sample('p { max-width: none }')['t'];
      expect(none.maxWidth, isNull);
    });
  });

  group('font-size', () {
    final cases = <String, double>{
      '24px': 24,
      '12pt': 16,
      '2em': 20,
      '1.5rem': 30,
      '150%': 15,
      'xx-small': 9,
      'x-small': 10,
      'small': 13,
      'medium': 16,
      'large': 18,
      'x-large': 24,
      'xx-large': 32,
      'xxx-large': 48,
      'larger': 12,
      'smaller': 10 / 1.2,
    };
    cases.forEach((value, expected) {
      test(value, () {
        final sample = _sample('p { font-size: $value }');
        expect(sample['t'].fontSize, closeTo(expected, 1e-9));
      });
    });

    test('negative sizes are invalid', () {
      expect(_sample('p { font-size: -5px }')['t'].fontSize, 10);
    });

    test('em margins use the element own computed font size', () {
      final style = _sample('p { font-size: 30px; margin-left: 2em }')['t'];
      expect(style.margin.left, const StyleLength.px(60));
    });
  });

  group('line-height', () {
    test('normal, unitless, px, em and percent', () {
      expect(
        _sample('p { line-height: normal }')['t'].lineHeight,
        const StyleLineHeight.normal(),
      );
      expect(
        _sample('p { line-height: 1.75 }')['t'].lineHeight,
        const StyleLineHeight.multiplier(1.75),
      );
      expect(
        _sample('p { line-height: 21px }')['t'].lineHeight,
        const StyleLineHeight.px(21),
      );
      expect(
        _sample('p { line-height: 2em }')['t'].lineHeight,
        const StyleLineHeight.px(20),
      );
      expect(
        _sample('p { line-height: 200% }')['t'].lineHeight,
        const StyleLineHeight.px(20),
      );
    });
  });

  group('letter-spacing', () {
    test('px, em, normal', () {
      expect(_sample('p { letter-spacing: 3px }')['t'].letterSpacing, 3);
      expect(_sample('p { letter-spacing: 0.1em }')['t'].letterSpacing, 1);
      expect(
        _sample(
          'p { letter-spacing: 0.1em; font-size: 30px }',
        )['t'].letterSpacing,
        closeTo(3, 1e-9),
      );
      expect(_sample('p { letter-spacing: normal }')['t'].letterSpacing, 0);
    });
  });

  group('colors', () {
    test('hex, short hex, rgb, rgba, names, transparent', () {
      final sample = _sample(
        '#a { background-color: #a02020 } #b { background-color: #0f8 } '
        '#c { background-color: rgb(1, 2, 3) } '
        '#d { background-color: rgba(255, 0, 0, 0.5) } '
        '#e { background-color: red } #f { background-color: transparent } '
        '#g { background-color: #11223344 }',
        body:
            '<p id="a">1</p><p id="b">2</p><p id="c">3</p><p id="d">4</p>'
            '<p id="e">5</p><p id="f">6</p><p id="g">7</p>',
      );
      expect(sample['a'].backgroundColor, 0xFFA02020);
      expect(sample['b'].backgroundColor, 0xFF00FF88);
      expect(sample['c'].backgroundColor, 0xFF010203);
      expect(sample['d'].backgroundColor, 0x80FF0000);
      expect(sample['e'].backgroundColor, 0xFFFF0000);
      expect(sample['f'].backgroundColor, isNull);
      expect(sample['g'].backgroundColor, 0x44112233);
    });
  });

  group('font-weight, font-style, font-family', () {
    test('keywords and numbers', () {
      final sample = _sample(
        '#a { font-weight: bold } #b { font-weight: 300 } '
        '#c { font-weight: 450 } #d { font-weight: normal }',
        body: '<p id="a">1</p><p id="b">2</p><p id="c">3</p><p id="d">4</p>',
      );
      expect(sample['a'].fontWeight, 700);
      expect(sample['b'].fontWeight, 300);
      expect(sample['c'].fontWeight, 500);
      expect(sample['d'].fontWeight, 400);
    });

    test('bolder and lighter are relative to the parent', () {
      final sample = _sample(
        '#o { font-weight: 300 } #i1 { font-weight: bolder } '
        '#p { font-weight: 700 } #i2 { font-weight: lighter }',
        body:
            '<div id="o"><span id="i1">a</span></div>'
            '<div id="p"><span id="i2">b</span></div>',
      );
      expect(sample['i1'].fontWeight, 400);
      expect(sample['i2'].fontWeight, 400);
    });

    test('font-family keeps order, case, quoted names and generics', () {
      final style = _sample(
        'p { font-family: "My Font", Georgia, \'Times New Roman\', serif }',
      )['t'];
      expect(style.fontFamilies, [
        'My Font',
        'Georgia',
        'Times New Roman',
        'serif',
      ]);
    });

    test('italic and oblique', () {
      final sample = _sample(
        '#a { font-style: italic } #b { font-style: oblique }',
        body: '<p id="a">1</p><p id="b">2</p>',
      );
      expect(sample['a'].fontStyle, StyleFontStyle.italic);
      expect(sample['b'].fontStyle, StyleFontStyle.italic);
    });
  });

  group('white-space, display, vertical-align, text-align', () {
    test('white-space values', () {
      final sample = _sample(
        '#a { white-space: pre } #b { white-space: pre-wrap } '
        '#c { white-space: normal } #d { white-space: pre-line } '
        '#e { white-space: nowrap }',
        body:
            '<p id="a">1</p><p id="b">2</p><p id="c">3</p><p id="d">4</p>'
            '<p id="e">5</p>',
      );
      expect(sample['a'].whiteSpace, StyleWhiteSpace.pre);
      expect(sample['b'].whiteSpace, StyleWhiteSpace.preWrap);
      expect(sample['c'].whiteSpace, StyleWhiteSpace.normal);
      expect(sample['d'].whiteSpace, StyleWhiteSpace.preLine);
      expect(sample['e'].whiteSpace, StyleWhiteSpace.nowrap);
    });

    test('display none, block and inline', () {
      final sample = _sample(
        '#a { display: none } #b { display: inline } #c { display: block }',
        body: '<p id="a">1</p><p id="b">2</p><span id="c">3</span>',
      );
      expect(sample['a'].display, StyleDisplay.none);
      expect(sample['b'].display, StyleDisplay.inline);
      expect(sample['c'].display, StyleDisplay.block);
    });

    test('the hidden attribute hides', () {
      final sample = _sample('', body: '<p id="a" hidden="hidden">1</p>');
      expect(sample['a'].display, StyleDisplay.none);
    });

    test('text-align values incl. justify', () {
      final sample = _sample(
        '#a { text-align: justify } #b { text-align: right } '
        '#c { text-align: center } #d { text-align: left }',
        body: '<p id="a">1</p><p id="b">2</p><p id="c">3</p><p id="d">4</p>',
      );
      expect(sample['a'].textAlign, StyleTextAlign.justify);
      expect(sample['b'].textAlign, StyleTextAlign.right);
      expect(sample['c'].textAlign, StyleTextAlign.center);
      expect(sample['d'].textAlign, StyleTextAlign.left);
    });

    test('sub and sup', () {
      final sample = _sample(
        '',
        body: '<p><sub id="a">1</sub><sup id="b">2</sup></p>',
      );
      expect(sample['a'].verticalAlign, StyleVerticalAlign.sub);
      expect(sample['b'].verticalAlign, StyleVerticalAlign.superscript);
    });
  });

  group('presentational hints', () {
    test('font element and img dimensions sit below author rules', () {
      final sample = _sample(
        '#c { font-size: 30px }',
        body:
            '<font id="a" color="#336699" size="5">x</font>'
            '<font id="c" size="5">y</font>'
            '<img id="i" width="120" height="40%" alt=""/>',
      );
      expect(sample['a'].fontSize, 24);
      expect(sample['c'].fontSize, 30);
      expect(sample['i'].width, const StyleLength.px(120));
      expect(sample['i'].height, const StyleLength.percent(40));
    });

    test('align attribute maps to text-align', () {
      final sample = _sample('', body: '<p id="a" align="center">x</p>');
      expect(sample['a'].textAlign, StyleTextAlign.center);
    });
  });

  group('direction and writing mode', () {
    test('dir attribute and vendor writing-mode aliases', () {
      final sample = _sample(
        '#b { -epub-writing-mode: vertical-rl } #c { writing-mode: tb-rl }',
        body:
            '<p id="a" dir="rtl">1</p><p id="b">2</p><p id="c">3</p>'
            '<p id="d">4</p>',
      );
      expect(sample['a'].direction, StyleDirection.rtl);
      expect(sample['b'].writingMode, StyleWritingMode.verticalRl);
      expect(sample['c'].writingMode, StyleWritingMode.verticalRl);
      expect(sample['d'].writingMode, StyleWritingMode.horizontalTb);
      expect(sample['d'].direction, StyleDirection.ltr);
    });
  });
}
