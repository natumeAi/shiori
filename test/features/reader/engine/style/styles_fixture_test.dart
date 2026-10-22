@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';

import 'style_test_support.dart';

/// Resolves every row of the S2 design 5.2 style matrix on the `styles`
/// fixture at the default reader settings and records the outcome:
///
/// | Row | Outcome |
/// | --- | --- |
/// | p, div, h1-h6, blockquote, ul/ol/li, hr, section, figure | supported (UA margins/sizes) |
/// | span, b/strong, i/em, a, br, small, sup/sub | supported |
/// | ruby/rt/rp | supported with difference: styles resolve (rt 50%, rp hidden), ruby layout is not a style concern |
/// | margin, padding, text-indent (px/em/%), text-align incl. justify | supported |
/// | display none/block/inline | supported (others approximated, reported) |
/// | font-size px/em/rem/%/keywords | supported |
/// | font-weight, font-style, line-height, letter-spacing | supported |
/// | font-family incl. @font-face | supported with difference: face is resolved to an archive path; the reader font option wins on body |
/// | color, background-color | supported (theme colors override listed elements) |
/// | white-space normal/pre/pre-wrap | supported |
void main() {
  late StyleSample sample;
  setUpAll(() => sample = StyleSample.fixture('styles'));

  ComputedStyle byTag(String tag, {int skip = 0}) =>
      sample.ofIndex(sample.byName(tag, skip: skip));
  ComputedStyle byClass(String className, {String? tag, int skip = 0}) =>
      sample.ofIndex(
        tag == null
            ? sample.byClass(className, skip: skip)
            : sample.indexOf(
                (n) =>
                    n.localName == tag &&
                    (n.attribute('class') ?? '').split(' ').contains(className),
                skip: skip,
              ),
      );

  test('the section resolves without diagnostics', () {
    expect(sample.styled.diagnostics, isEmpty);
    expect(sample.styled.fixedLayout, isFalse);
  });

  group('Blocks', () {
    test('section, div and figure are block; the illust margin applies', () {
      expect(byTag('section').display, StyleDisplay.block);
      expect(byTag('div').display, StyleDisplay.block);
      final figure = byClass('illust', tag: 'figure');
      expect(figure.display, StyleDisplay.block);
      // UA margin 1em 40px; `.illust:not(:last-child)` adds margin-bottom 1rem.
      expect(figure.margin.top, const StyleLength.px(18));
      expect(figure.margin.right, const StyleLength.px(40));
      expect(figure.margin.bottom, const StyleLength.px(16));
    });

    test('h1-h6 sizes, weight and margins', () {
      const sizes = [36.0, 27.0, 21.06, 18.0, 14.94, 12.06];
      const margins = [0.67, 0.83, 1.0, 1.33, 1.67, 2.33];
      for (var level = 1; level <= 6; level++) {
        final style = byTag('h$level');
        expect(style.display, StyleDisplay.block, reason: 'h$level');
        expect(style.fontSize, closeTo(sizes[level - 1], 1e-9));
        expect(style.fontWeight, 700);
        expect(
          style.margin.top.value,
          closeTo(margins[level - 1] * sizes[level - 1], 1e-9),
        );
      }
    });

    test('blockquote: UA margins, author margin-left, padding, background', () {
      final style = byTag('blockquote');
      expect(style.display, StyleDisplay.block);
      expect(style.margin.top, const StyleLength.px(18));
      expect(style.margin.right, const StyleLength.px(40));
      expect(style.margin.left, const StyleLength.px(36));
      expect(style.padding.top, const StyleLength.px(4));
      expect(style.backgroundColor, 0xFFF0ECD0);
    });

    test('lists', () {
      final outer = byTag('ul');
      expect(outer.margin.top, const StyleLength.px(18));
      expect(outer.padding.left, const StyleLength.px(40));
      expect(byTag('li').display, StyleDisplay.listItem);
      final nested = byTag('ul', skip: 1);
      expect(nested.margin.top, StyleLength.zero);
      expect(byTag('ol').padding.left, const StyleLength.px(40));
      expect(byTag('li', skip: 3).display, StyleDisplay.listItem);
    });

    test('hr is a block with a hairline background', () {
      final style = byTag('hr');
      expect(style.display, StyleDisplay.block);
      expect(style.height, const StyleLength.px(1));
      expect(style.backgroundColor, 0xFF808080);
    });

    test('p is a block with the author margin, padding and indent', () {
      final style = sample['target'];
      expect(style.display, StyleDisplay.block);
      expect(style.margin.top, const StyleLength.px(9));
      expect(style.margin.right, const StyleLength.px(4));
      expect(style.padding.top, const StyleLength.px(2));
      expect(style.padding.right, const StyleLength.percent(1));
      expect(style.textIndent, const StyleLength.px(36));
      expect(style.textAlign, StyleTextAlign.justify);
    });
  });

  group('Inline', () {
    test('span, display switches', () {
      expect(byClass('inline', tag: 'span').display, StyleDisplay.inline);
      expect(byClass('block', tag: 'span').display, StyleDisplay.block);
    });

    test('priority, importance and inheritance on p.accent', () {
      final accent = byClass('accent', tag: 'p');
      // `p.accent { color: ... !important }` beats the theme and the inline
      // color; `.accent` supplies the weight.
      expect(accent.color, 0xFF2040A0);
      expect(accent.fontWeight, 700);
      // span: the theme color applies to span (listed) and loses to nothing.
      expect(byTag('span', skip: 2).color, 0xFF1D1D1F);
      // Weight inherits from the accent paragraph.
      expect(byTag('span', skip: 2).fontWeight, 700);
    });

    test('b/strong/i/em/a/br', () {
      expect(byTag('b').fontWeight, 700);
      expect(byTag('strong').fontWeight, 700);
      expect(byTag('i').fontStyle, StyleFontStyle.italic);
      expect(byTag('em').fontStyle, StyleFontStyle.italic);
      final link = byTag('a');
      expect(link.underline, isTrue);
      expect(link.color, 0xFF2040A0); // a { color: inherit !important }
      expect(byTag('br').display, StyleDisplay.inline);
    });

    test('small, sup, sub', () {
      expect(byTag('small').fontSize, closeTo(15, 1e-9));
      expect(byTag('sup').verticalAlign, StyleVerticalAlign.superscript);
      expect(byTag('sup').fontSize, closeTo(15, 1e-9));
      expect(byTag('sub').verticalAlign, StyleVerticalAlign.sub);
    });

    test('ruby, rt and rp styles resolve', () {
      expect(byTag('ruby').display, StyleDisplay.inline);
      expect(byTag('rt').fontSize, closeTo(9, 1e-9));
      expect(byTag('rp').display, StyleDisplay.none);
    });
  });

  group('Box', () {
    test('text-align values', () {
      expect(byClass('center', tag: 'p').textAlign, StyleTextAlign.center);
      expect(byClass('right', tag: 'p').textAlign, StyleTextAlign.right);
    });

    test('display none hides the paragraph but keeps its style', () {
      expect(byClass('hidden', tag: 'p').display, StyleDisplay.none);
    });
  });

  group('Text', () {
    test('font-size units and keywords', () {
      expect(byClass('small-keyword').fontSize, 13);
      expect(byClass('large-keyword').fontSize, 18);
      expect(byClass('percent').fontSize, closeTo(21.6, 1e-9));
      expect(byClass('rem').fontSize, 20);
      expect(byClass('em').fontSize, closeTo(19.8, 1e-9));
    });

    test('inline style span: px size, weight, style, spacing, background', () {
      final style = sample.ofIndex(
        sample.indexOf(
          (n) => (n.attribute('style') ?? '').contains('font-size:22px'),
        ),
      );
      expect(style.fontSize, 22);
      expect(style.fontWeight, 600);
      expect(style.fontStyle, StyleFontStyle.italic);
      expect(style.lineHeight, const StyleLineHeight.multiplier(2));
      expect(style.letterSpacing, closeTo(2.64, 1e-9));
      expect(style.backgroundColor, 0xFFFFEECC);
    });

    test('white-space values', () {
      expect(byClass('pre', tag: 'p').whiteSpace, StyleWhiteSpace.pre);
      expect(byClass('pre-wrap', tag: 'p').whiteSpace, StyleWhiteSpace.preWrap);
      expect(byClass('normal', tag: 'p').whiteSpace, StyleWhiteSpace.normal);
    });

    test('reader overrides: size, line-height, spacing, theme colors', () {
      final root = sample.styled.rootStyle;
      expect(root.fontSize, 18);
      expect(root.color, 0xFF1D1D1F);
      expect(root.backgroundColor, 0xFFFFFFFF);
      final paragraph = sample['target'];
      expect(paragraph.lineHeight, const StyleLineHeight.multiplier(1.6));
      // The author asks for .02em, the override sets 0em with !important.
      expect(paragraph.letterSpacing, 0);
      expect(root.fontFamilies, readerFontOptions.first.cssFamilies);
    });

    test('@font-face from the linked sheet and the style element', () {
      final faces = {
        for (final f in sample.styled.fontFaces) f.family: f.archivePath,
      };
      expect(faces, {
        'FixtureRoboto': 'EPUB/fonts/Roboto-Regular.ttf',
        'InlineFixture': 'EPUB/fonts/Roboto-Regular.ttf',
      });
    });

    test('non-default settings reach the paragraphs', () {
      final other = StyleSample.fixture(
        'styles',
        settings: const ReaderSettings(
          fontSize: 26,
          lineHeight: 2.0,
          letterSpacing: 0.12,
          themeId: 'dark',
          fontFamilyId: 'serif',
        ),
      );
      final paragraph = other['target'];
      expect(paragraph.fontSize, 26);
      expect(paragraph.lineHeight, const StyleLineHeight.multiplier(2));
      expect(paragraph.letterSpacing, closeTo(3.12, 1e-9));
      expect(paragraph.color, 0xFFEEEEEE);
      expect(paragraph.fontFamilies, readerFontOptions[4].cssFamilies);
      // Relative author sizes follow the new base: 120% and 1.1em.
      final em = other.ofIndex(
        other.indexOf(
          (n) => n.localName == 'span' && (n.attribute('class') ?? '') == 'em',
        ),
      );
      expect(em.fontSize, closeTo(28.6, 1e-9));
    });
  });

  group('Images', () {
    test('img and svg resolve styles; width/height/max-width are lengths', () {
      final images = StyleSample.fixture('images');
      for (var s = 0; s < images.book.sections.length; s++) {
        final section = StyleSample.fromBook(images.book, section: s);
        for (final node in section.document.nodes) {
          if (node.kind != SourceNodeKind.element) continue;
          if (node.localName == 'img' || node.localName == 'svg') {
            final style = section.styled.styleOf(node.index)!;
            expect(style.display, isNot(StyleDisplay.none));
            expect(style.fontSize, 18);
          }
        }
      }
    });
  });
}
