import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/style_diagnostic.dart';

import 'style_test_support.dart';

StyleLength _px(double value) => StyleLength.px(value);

/// Left margin is not touched by the reader overrides or inherited, so it
/// isolates the cascade.
StyleLength _left(StyleSample sample, String id) => sample[id].margin.left;

/// A sample whose section is fixed layout, so the reader layout CSS is
/// omitted (the theme CSS still applies).
StyleSample _fixed(String body, String css) {
  final book = EpubBook.open(
    buildEpub(
      sections: {
        'ch1.xhtml': xhtml(
          head: css.isEmpty ? '' : '<style>$css</style>',
          body: body,
        ),
      },
      spineProperties: const {'ch1.xhtml': 'rendition:layout-pre-paginated'},
    ),
  );
  return StyleSample.fromBook(book);
}

void main() {
  group('cascade order', () {
    test('specificity beats source order', () {
      final sample = StyleSample.html(
        '<div><p id="x" class="k">t</p></div>',
        css:
            '#x { margin-left: 3px } .k { margin-left: 2px } '
            'p { margin-left: 1px } div p { margin-left: 4px }',
      );
      expect(_left(sample, 'x'), _px(3));
    });

    test('equal specificity: the later rule wins', () {
      final sample = StyleSample.html(
        '<p id="x" class="a b">t</p>',
        css:
            '.a { margin-left: 1px } .b { margin-left: 2px } '
            '.a { margin-left: 3px }',
      );
      expect(_left(sample, 'x'), _px(3));
    });

    test('author rules beat the user-agent sheet', () {
      final sample = StyleSample.html(
        '<ul id="x"><li>a</li></ul>',
        css: 'ul { padding-left: 5px }',
      );
      expect(sample['x'].padding.left, _px(5));
      final plain = StyleSample.html('<ul id="x"><li>a</li></ul>');
      expect(plain['x'].padding.left, _px(40));
    });

    test('!important beats a more specific normal declaration', () {
      final sample = StyleSample.html(
        '<div><p id="x" class="k">t</p></div>',
        css: 'p { margin-left: 1px !important } div p.k { margin-left: 9px }',
      );
      expect(_left(sample, 'x'), _px(1));
    });

    test('!important vs !important: specificity then order', () {
      final sample = StyleSample.html(
        '<p id="x" class="k">t</p><p id="y" class="k">t</p>',
        css:
            'p.k { margin-left: 1px !important } '
            'p { margin-left: 2px !important } '
            '#y { margin-left: 3px !important } '
            '.k { margin-left: 4px !important }',
      );
      expect(_left(sample, 'x'), _px(1));
      expect(_left(sample, 'y'), _px(3));
    });

    test('inline style beats rules; !important beats inline', () {
      final sample = StyleSample.html(
        '<p id="a" style="margin-left: 6px">t</p>'
        '<p id="b" style="margin-left: 6px">t</p>'
        '<p id="c" style="margin-left: 6px !important">t</p>',
        css:
            '#a { margin-left: 1px } '
            '#b { margin-left: 2px !important } '
            '#c { margin-left: 3px !important }',
      );
      expect(_left(sample, 'a'), _px(6));
      expect(_left(sample, 'b'), _px(2));
      expect(_left(sample, 'c'), _px(6));
    });

    test('an invalid later declaration keeps an earlier valid one', () {
      final sample = StyleSample.html(
        '<p id="x">t</p>',
        css: 'p { margin-left: 4px; margin-left: bogus }',
      );
      expect(_left(sample, 'x'), _px(4));
      expect(sample.styled.count(StyleDiagnosticKind.invalidValue), 1);
    });

    test('shorthand and longhand follow source order', () {
      final sample = StyleSample.html(
        '<p id="x">t</p><p id="y">t</p>',
        css:
            '#x { margin-left: 1px; margin: 2px } '
            '#y { margin: 2px; margin-left: 1px }',
      );
      expect(_left(sample, 'x'), _px(2));
      expect(_left(sample, 'y'), _px(1));
    });

    test('linked stylesheets and style elements keep document order', () {
      final sample = StyleSample.html(
        '<p id="x">t</p>',
        head:
            '<link rel="stylesheet" href="a.css"/>'
            '<style>p { margin-left: 2px }</style>'
            '<link rel="stylesheet" href="b.css"/>',
        files: const {
          'a.css': 'p { margin-left: 1px }',
          'b.css': 'p { margin-left: 3px }',
        },
      );
      expect(_left(sample, 'x'), _px(3));
    });

    test('@import is resolved relative to the importing sheet', () {
      final sample = StyleSample.html(
        '<p id="x">t</p>',
        head: '<link rel="stylesheet" href="css/main.css"/>',
        files: const {
          'css/main.css': '@import "base/b.css"; p { margin-top: 5px }',
          'css/base/b.css': 'p { margin-left: 7px; margin-top: 1px }',
        },
      );
      expect(_left(sample, 'x'), _px(7));
      expect(sample['x'].margin.top, _px(5));
    });

    test('missing and external stylesheets are reported, not fatal', () {
      final sample = StyleSample.html(
        '<p id="x">t</p>',
        head:
            '<link rel="stylesheet" href="missing.css"/>'
            '<link rel="stylesheet" href="https://example.com/a.css"/>'
            '<link rel="stylesheet" media="print" href="a.css"/>',
        files: const {'a.css': 'p { margin-left: 9px }'},
      );
      expect(_left(sample, 'x'), StyleLength.zero);
      expect(sample.styled.count(StyleDiagnosticKind.stylesheetNotFound), 1);
      expect(sample.styled.count(StyleDiagnosticKind.stylesheetSkipped), 2);
    });

    test('@media screen applies, print does not', () {
      final sample = StyleSample.html(
        '<p id="x">t</p><p id="y" class="k">t</p>',
        css:
            '@media screen { p { margin-left: 2px } } '
            '@media print { .k { margin-left: 9px } }',
      );
      expect(_left(sample, 'x'), _px(2));
      expect(_left(sample, 'y'), _px(2));
    });
  });

  group('inheritance', () {
    test('inherited properties flow to descendants', () {
      final sample = StyleSample.html(
        '<div id="d"><p id="p"><span id="s">t</span></p></div>',
        css:
            'div { font-style: italic; text-align: center; '
            'text-indent: 12px; white-space: pre; font-weight: 600 }',
      );
      expect(sample['s'].fontStyle, StyleFontStyle.italic);
      expect(sample['s'].textAlign, StyleTextAlign.center);
      expect(sample['s'].textIndent, _px(12));
      expect(sample['s'].whiteSpace, StyleWhiteSpace.pre);
      expect(sample['s'].fontWeight, 600);
    });

    test('non-inherited properties do not flow', () {
      final sample = StyleSample.html(
        '<div id="d"><p id="p">t</p></div>',
        css:
            'div { margin-left: 5px; padding-left: 6px; '
            'background-color: #ff0000; width: 50% }',
      );
      expect(sample['p'].margin.left, StyleLength.zero);
      expect(sample['p'].padding.left, StyleLength.zero);
      expect(sample['p'].backgroundColor, isNull);
      expect(sample['p'].width, const StyleLength.auto());
      expect(sample['d'].backgroundColor, 0xFFFF0000);
      expect(sample['d'].width, const StyleLength.percent(50));
    });

    test('line-height: multiplier inherits as is, lengths as px', () {
      final sample = _fixed(
        '<div id="a"><span id="a2" style="font-size: 40px">t</span></div>'
            '<div id="b"><span id="b2" style="font-size: 40px">t</span></div>'
            '<div id="c"><span id="c2" style="font-size: 40px">t</span></div>',
        '#a { line-height: 1.5 } #b { line-height: 150% } '
            '#c { line-height: 2em }',
      );
      expect(sample['a2'].lineHeight, const StyleLineHeight.multiplier(1.5));
      // 150% of the div's 16 px font size, inherited as a length.
      expect(sample['b2'].lineHeight, const StyleLineHeight.px(24));
      expect(sample['c2'].lineHeight, const StyleLineHeight.px(32));
    });

    test('letter-spacing em is resolved at the declaring element', () {
      final sample = _fixed(
        '<div id="d"><span id="s" style="font-size: 40px">t</span></div>',
        'div { letter-spacing: 0.5em; font-size: 20px }',
      );
      expect(sample['d'].letterSpacing, 10);
      expect(sample['s'].letterSpacing, 10);
    });

    test('inherit, initial and unset', () {
      final sample = StyleSample.html(
        '<div id="d"><p id="a">t</p><p id="b">t</p><p id="c">t</p></div>',
        css:
            'div { margin-left: 8px; font-style: italic } '
            '#a { margin-left: inherit; font-style: initial } '
            '#b { margin-left: unset; font-style: unset } '
            '#c { font-style: inherit }',
      );
      expect(_left(sample, 'a'), _px(8));
      expect(sample['a'].fontStyle, StyleFontStyle.normal);
      expect(_left(sample, 'b'), StyleLength.zero);
      expect(sample['b'].fontStyle, StyleFontStyle.italic);
      expect(sample['c'].fontStyle, StyleFontStyle.italic);
    });

    test('text-decoration propagates visually to descendants', () {
      final sample = StyleSample.html(
        '<p id="p"><u id="u">a<span id="s">b</span></u></p>'
        '<a id="a" href="#p">c</a>'
        '<a id="b" href="#p" style="text-decoration: none">d</a>',
      );
      expect(sample['u'].underline, isTrue);
      expect(sample['s'].underline, isTrue);
      expect(sample['p'].underline, isFalse);
      expect(sample['a'].underline, isTrue);
      expect(sample['b'].underline, isFalse);
    });

    test('currentcolor background takes the element color', () {
      final sample = _fixed(
        '<p id="x" style="color: #112233; background-color: currentcolor">t'
            '</p>',
        '',
      );
      // Fixed layout still gets the theme: the span/p color override wins.
      expect(sample['x'].backgroundColor, sample['x'].color);
    });
  });

  group('shorthands', () {
    test('margin and padding expand one to four values', () {
      final sample = StyleSample.html(
        '<p id="a">t</p><p id="b">t</p><p id="c">t</p><p id="d">t</p>',
        css:
            '#a { margin: 1px } #b { margin: 1px 2px } '
            '#c { margin: 1px 2px 3px } '
            '#d { margin: 1px 2px 3px 4px; padding: 5px 6px }',
      );
      expect(sample['a'].margin, StyleEdges(_px(1), _px(1), _px(1), _px(1)));
      expect(sample['b'].margin, StyleEdges(_px(1), _px(2), _px(1), _px(2)));
      expect(sample['c'].margin, StyleEdges(_px(1), _px(2), _px(3), _px(2)));
      expect(sample['d'].margin, StyleEdges(_px(1), _px(2), _px(3), _px(4)));
      expect(sample['d'].padding, StyleEdges(_px(5), _px(6), _px(5), _px(6)));
    });

    test('font shorthand', () {
      final sample = _fixed(
        '<p id="x">t</p>',
        'p { font: italic bold 20px/1.5 "Foo Bar", serif }',
      );
      final style = sample['x'];
      expect(style.fontStyle, StyleFontStyle.italic);
      expect(style.fontWeight, 700);
      expect(style.fontSize, 20);
      expect(style.lineHeight, const StyleLineHeight.multiplier(1.5));
      expect(style.fontFamilies, ['Foo Bar', 'serif']);
    });

    test('background and text-decoration shorthands', () {
      final sample = StyleSample.html(
        '<p id="x">t</p><p id="y">t</p>',
        css:
            '#x { background: url(a.png) #102030 no-repeat; '
            'text-decoration: underline line-through } '
            '#y { text-decoration: none }',
      );
      expect(sample['x'].backgroundColor, 0xFF102030);
      expect(sample['x'].underline, isTrue);
      expect(sample['x'].lineThrough, isTrue);
      expect(sample['y'].underline, isFalse);
    });

    test('page-break and break properties', () {
      final sample = StyleSample.html(
        '<p id="a">t</p><p id="b">t</p><p id="c">t</p>',
        css:
            '#a { page-break-before: always } #b { break-after: page } '
            '#c { page-break-after: avoid }',
      );
      expect(sample['a'].breakBefore, isTrue);
      expect(sample['b'].breakAfter, isTrue);
      expect(sample['c'].breakAfter, isFalse);
      expect(sample['a'].breakAfter, isFalse);
    });
  });

  group('diagnostics', () {
    test('unsupported properties and at-rules are counted without prose', () {
      final sample = StyleSample.html(
        '<p id="x">hidden prose</p>',
        css:
            'p { float: left; float: right; border: 1px solid red; '
            'margin-left: 3px } @page { margin: 1px } '
            '@keyframes k { from { top: 0 } to { top: 1px } } '
            'p::after { content: "x" }',
      );
      expect(_left(sample, 'x'), _px(3));
      final byDetail = {
        for (final d in sample.styled.diagnostics)
          '${d.kind.name}:${d.detail}': d.count,
      };
      expect(byDetail['unsupportedProperty:float'], 2);
      expect(byDetail['unsupportedProperty:border'], 1);
      expect(byDetail['unsupportedAtRule:@page'], 1);
      expect(
        sample.styled.diagnostics.map((d) => d.detail).join(),
        isNot(contains('prose')),
      );
    });

    test('unsupported units are reported and ignored', () {
      final sample = StyleSample.html(
        '<p id="x">t</p>',
        css:
            'p { margin-left: 3px; margin-left: 5vw; '
            'padding-left: calc(1px + 2px); text-indent: 2ch }',
      );
      expect(_left(sample, 'x'), _px(3));
      expect(sample['x'].padding.left, StyleLength.zero);
      expect(sample.styled.count(StyleDiagnosticKind.unsupportedUnit), 3);
    });

    test('display values outside the matrix are approximated, reported', () {
      final sample = StyleSample.html(
        '<span id="a">t</span><span id="b">t</span>',
        css: '#a { display: inline-block } #b { display: flex }',
      );
      expect(sample['a'].display, StyleDisplay.inline);
      expect(sample['b'].display, StyleDisplay.block);
      expect(sample.styled.count(StyleDiagnosticKind.approximatedValue), 2);
    });

    test('broken CSS never crashes and keeps content styled', () {
      final sample = StyleSample.html(
        '<p id="x">t</p>',
        css: 'p { margin-left: 4px; } }}} {{ ;; p { color',
      );
      expect(_left(sample, 'x'), _px(4));
      expect(sample.styled.diagnostics, isNotEmpty);
    });
  });
}
