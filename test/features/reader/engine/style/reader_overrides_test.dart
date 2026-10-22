import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/style/reader_stylesheets.dart';

import 'style_test_support.dart';

const _body =
    '<div id="d"><p id="p">t <span id="s">s</span> <b id="b">b</b> '
    '<a id="a" href="#p">a</a></p><h1 id="h">h</h1></div>'
    '<blockquote id="q">q</blockquote><ul><li id="li">l</li></ul>';

StyleSample _html(String css, ReaderSettings settings, {bool fixed = false}) {
  final book = EpubBook.open(
    buildEpub(
      sections: {
        'ch1.xhtml': xhtml(
          head: css.isEmpty ? '' : '<style>$css</style>',
          body: _body,
        ),
      },
      spineProperties: fixed
          ? const {'ch1.xhtml': 'rendition:layout-pre-paginated'}
          : const {},
    ),
  );
  return StyleSample.fromBook(book, settings: settings);
}

void main() {
  group('layout overrides (getReaderLayoutCss)', () {
    test('body font size, line height and letter spacing apply', () {
      final sample = _html(
        '',
        const ReaderSettings(
          fontSize: 26,
          lineHeight: 2.0,
          letterSpacing: 0.06,
        ),
      );
      expect(sample.styled.rootStyle.fontSize, 26);
      expect(sample['d'].fontSize, 26);
      expect(sample['p'].fontSize, 26);
      expect(sample['p'].lineHeight, const StyleLineHeight.multiplier(2.0));
      expect(sample['p'].letterSpacing, closeTo(0.06 * 26, 1e-9));
      expect(sample['li'].lineHeight, const StyleLineHeight.multiplier(2.0));
      expect(sample['q'].letterSpacing, closeTo(0.06 * 26, 1e-9));
    });

    test('the override sets em letter-spacing on the listed blocks only', () {
      final sample = _html(
        'h1 { font-size: 40px }',
        const ReaderSettings(letterSpacing: 0.1),
      );
      // h1 is not in the override selector list: it inherits the body px.
      expect(sample['h'].letterSpacing, closeTo(0.1 * 18, 1e-9));
      expect(sample['h'].fontSize, 40);
      // p, div, blockquote, li resolve em at their own font size.
      expect(sample['p'].letterSpacing, closeTo(1.8, 1e-9));
    });

    test('author !important on body loses, html body !important wins', () {
      final sample = _html(
        'body { font-size: 12px !important } '
        'p { line-height: 3 !important }',
        const ReaderSettings(),
      );
      // Same specificity, later wins: the reader override.
      expect(sample.styled.rootStyle.fontSize, 18);
      // p { ... !important } vs the override p-list: same specificity, later.
      expect(sample['p'].lineHeight, const StyleLineHeight.multiplier(1.6));
      final stronger = _html(
        'html body { font-size: 12px !important }',
        const ReaderSettings(),
      );
      expect(stronger.styled.rootStyle.fontSize, 12);
    });

    test('non-important author declarations on overridden targets lose', () {
      final sample = _html(
        'body { font-size: 12px; line-height: 3 } '
        'p { line-height: 3; letter-spacing: 5px }',
        const ReaderSettings(),
      );
      expect(sample.styled.rootStyle.fontSize, 18);
      expect(sample['p'].lineHeight, const StyleLineHeight.multiplier(1.6));
      expect(sample['p'].letterSpacing, 0);
    });

    test('elements outside the selector list keep author line-height', () {
      final sample = _html(
        'span { line-height: 3 } h1 { line-height: 2.5 }',
        const ReaderSettings(),
      );
      expect(sample['s'].lineHeight, const StyleLineHeight.multiplier(3));
      expect(sample['h'].lineHeight, const StyleLineHeight.multiplier(2.5));
    });

    test('an author font-size on a descendant still applies', () {
      final sample = _html('p { font-size: 30px }', const ReaderSettings());
      expect(sample['p'].fontSize, 30);
      expect(sample['s'].fontSize, 30);
    });

    test('body margin and padding are zero; html padding is zero', () {
      final sample = _html(
        'body { margin: 20px; padding: 9px } html { padding: 7px }',
        const ReaderSettings(),
      );
      final body = sample.styled.rootStyle;
      expect(body.margin, StyleEdges.zero);
      expect(body.padding, StyleEdges.zero);
      expect(
        sample.styled.styleOf(sample.document.documentElementIndex)!.padding,
        StyleEdges.zero,
      );
    });

    test('overflow-wrap anywhere reaches blocks and inherits', () {
      final sample = _html('', const ReaderSettings());
      expect(sample['p'].overflowWrapAnywhere, isTrue);
      expect(sample['h'].overflowWrapAnywhere, isTrue);
      expect(sample['s'].overflowWrapAnywhere, isTrue);
    });
  });

  group('font families', () {
    for (final option in readerFontOptions) {
      test('option ${option.id} sets the reference family list', () {
        final sample = _html('', ReaderSettings(fontFamilyId: option.id));
        expect(sample.styled.rootStyle.fontFamilies, option.cssFamilies);
        expect(sample['p'].fontFamilies, option.cssFamilies);
      });
    }

    test(
      'an author font-family on a descendant wins over the inherited one',
      () {
        final sample = _html(
          'p { font-family: Georgia, serif }',
          const ReaderSettings(),
        );
        expect(sample['p'].fontFamilies, ['Georgia', 'serif']);
      },
    );
  });

  group('theme CSS (getReaderThemeCss)', () {
    for (final theme in readerThemes) {
      test('theme ${theme.id}: colors and background', () {
        final sample = _html('', ReaderSettings(themeId: theme.id));
        expect(sample.styled.rootStyle.color, theme.text);
        expect(sample.styled.rootStyle.backgroundColor, theme.background);
        for (final id in const ['d', 'p', 's', 'q', 'li']) {
          expect(sample[id].color, theme.text, reason: id);
        }
        // Not in the p/div/section/article/blockquote/li/span list: inherited
        // from the container (here p), which has the theme color.
        expect(sample['b'].color, theme.text);
        expect(sample['h'].color, theme.text);
        // a { color: inherit !important }
        expect(sample['a'].color, theme.text);
      });
    }

    test('theme colors beat author colors on listed elements', () {
      final sample = _html(
        'p { color: #ff0000 } span { color: #00ff00 } h1 { color: #0000ff } '
        'body { background-color: #123456 } a { color: #abcdef }',
        const ReaderSettings(themeId: 'dark'),
      );
      expect(sample['p'].color, 0xFFEEEEEE);
      expect(sample['s'].color, 0xFFEEEEEE);
      // h1 is not listed: the author color applies.
      expect(sample['h'].color, 0xFF0000FF);
      expect(sample.styled.rootStyle.backgroundColor, 0xFF171717);
      expect(sample['a'].color, 0xFFEEEEEE);
    });

    test('inline non-important color still loses to the theme', () {
      final book = EpubBook.open(
        buildEpub(
          sections: {
            'ch1.xhtml': xhtml(body: '<p id="p" style="color: #ff0000">t</p>'),
          },
        ),
      );
      final sample = StyleSample.fromBook(book);
      expect(sample['p'].color, 0xFF1D1D1F);
    });
  });

  group('fixed layout', () {
    test('layout CSS is omitted, theme CSS stays', () {
      final sample = _html(
        'body { font-size: 12px; line-height: 3 } p { letter-spacing: 5px }',
        const ReaderSettings(
          fontSize: 30,
          lineHeight: 1.3,
          letterSpacing: 0.12,
          fontFamilyId: 'kai',
          themeId: 'warm',
        ),
        fixed: true,
      );
      expect(sample.styled.fixedLayout, isTrue);
      expect(sample.styled.rootStyle.fontSize, 12);
      expect(sample['p'].lineHeight, const StyleLineHeight.multiplier(3));
      expect(sample['p'].letterSpacing, 5);
      expect(sample.styled.rootStyle.fontFamilies, isEmpty);
      // Theme stays.
      expect(sample['p'].color, 0xFF2F271D);
      expect(sample.styled.rootStyle.backgroundColor, 0xFFF4ECD9);
    });

    test('the reference CSS text omits the layout part for fixed books', () {
      const settings = ReaderSettings();
      final reflowable = readerOverrideCss(settings, fixedLayout: false);
      final fixed = readerOverrideCss(settings, fixedLayout: true);
      expect(reflowable, contains('font-size: 18px'));
      expect(fixed, isNot(contains('font-size')));
      expect(fixed, isNot(contains('line-height')));
      expect(fixed, contains('background: #ffffff'));
      expect(reflowable, endsWith(fixed));
    });

    test('rendition:layout in the package marks every section fixed', () {
      final book = EpubBook.open(
        buildEpub(
          sections: {'ch1.xhtml': xhtml(body: '<p id="p">t</p>')},
          metadata: '<meta property="rendition:layout">pre-paginated</meta>',
        ),
      );
      final sample = StyleSample.fromBook(
        book,
        settings: const ReaderSettings(fontSize: 30),
      );
      expect(sample.styled.fixedLayout, isTrue);
      expect(sample['p'].fontSize, 16);
    });

    test('an itemref can opt a section back to reflowable', () {
      final book = EpubBook.open(
        buildEpub(
          sections: {'ch1.xhtml': xhtml(body: '<p id="p">t</p>')},
          metadata: '<meta property="rendition:layout">pre-paginated</meta>',
          spineProperties: const {'ch1.xhtml': 'rendition:layout-reflowable'},
        ),
      );
      final sample = StyleSample.fromBook(book);
      expect(sample.styled.fixedLayout, isFalse);
      expect(sample['p'].fontSize, 18);
    });
  });

  group('embedded fonts', () {
    test('@font-face resolves to archive paths with weight and style', () {
      final sample = StyleSample.html(
        '<p id="p">t</p>',
        css:
            '@font-face { font-family: "Body Font"; font-weight: bold; '
            'font-style: italic; src: url(fonts/a.woff2), url("fonts/a.ttf") }',
        files: {'fonts/a.ttf': 'font', 'fonts/a.woff2': 'font'},
      );
      expect(sample.styled.fontFaces, hasLength(1));
      final face = sample.styled.fontFaces.single;
      expect(face.family, 'Body Font');
      expect(face.archivePath, 'OEBPS/fonts/a.ttf');
      expect(face.weight, 700);
      expect(face.style, StyleFontStyle.italic);
    });

    test('an unresolvable face is reported and omitted', () {
      final sample = StyleSample.html(
        '<p id="p">t</p>',
        css: '@font-face { font-family: X; src: url(fonts/none.ttf) }',
      );
      expect(sample.styled.fontFaces, isEmpty);
      expect(sample.styled.diagnostics, isNotEmpty);
    });
  });
}
