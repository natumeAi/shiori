@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/engine/support/unsupported_layout.dart';

import '../style/style_test_support.dart';

const _supportedFixtures = [
  'cfi-structure',
  'chapters',
  'html-fallback',
  'images',
  'inert-content',
  'long-content',
  'one-page',
  'opf-variants',
  'styles',
  'unicode',
];

EpubBook _fixture(String id) =>
    EpubBook.open(File('assets/reader_fixtures/$id.epub').readAsBytesSync());

EpubBook _book(
  String body, {
  String head = '',
  String htmlAttributes = '',
  String metadata = '',
  Map<String, String> spineProperties = const {},
  String spineAttributes = '',
  Map<String, Object> files = const {},
}) => EpubBook.open(
  buildEpub(
    sections: {
      'ch1.xhtml': xhtml(
        head: head,
        body: body,
        htmlAttributes: htmlAttributes,
      ),
    },
    metadata: metadata,
    spineProperties: spineProperties,
    spineAttributes: spineAttributes,
    files: files,
  ),
);

void main() {
  group('synthetic fixtures', () {
    for (final id in _supportedFixtures) {
      test('$id is supported', () {
        final support = detectBookLayout(_fixture(id));
        expect(support.supported, isTrue, reason: support.reasons.toString());
        expect(support.reasons, isEmpty);
        expect(support.unsupportedSectionIndices, isEmpty);
        support.requireSupported();
      });
    }

    test('unsupported-fixed: fixed layout', () {
      final support = detectBookLayout(_fixture('unsupported-fixed'));
      expect(support.supported, isFalse);
      expect(support.reasons, {UnsupportedLayoutReason.fixedLayout});
      expect(support.bookReasons, {UnsupportedLayoutReason.fixedLayout});
      expect(support.unsupportedSectionIndices, [0]);
      expect(
        support.requireSupported,
        throwsA(isA<UnsupportedLayoutException>()),
      );
    });

    test('unsupported-vertical: vertical writing mode, rtl progression', () {
      final support = detectBookLayout(_fixture('unsupported-vertical'));
      expect(support.supported, isFalse);
      expect(support.reasons, {
        UnsupportedLayoutReason.verticalWritingMode,
        UnsupportedLayoutReason.rtlPageProgression,
      });
      expect(support.sections.single.reasons, support.reasons);
    });

    test('unsupported-rtl: rtl direction, rtl progression', () {
      final support = detectBookLayout(_fixture('unsupported-rtl'));
      expect(support.supported, isFalse);
      expect(support.reasons, {
        UnsupportedLayoutReason.rtlDirection,
        UnsupportedLayoutReason.rtlPageProgression,
      });
      expect(
        support.requireSupported,
        throwsA(isA<UnsupportedLayoutException>()),
      );
    });
  });

  group('package-level cues', () {
    test('rendition:layout pre-paginated', () {
      final support = detectBookLayout(
        _book(
          '<p>t</p>',
          metadata: '<meta property="rendition:layout">pre-paginated</meta>',
        ),
      );
      expect(support.reasons, {UnsupportedLayoutReason.fixedLayout});
    });

    test('rendition:layout reflowable is supported', () {
      final support = detectBookLayout(
        _book(
          '<p>t</p>',
          metadata: '<meta property="rendition:layout">reflowable</meta>',
        ),
      );
      expect(support.supported, isTrue);
    });

    test('itemref property marks only that section fixed', () {
      final book = EpubBook.open(
        buildEpub(
          sections: {
            'a.xhtml': xhtml(body: '<p>a</p>'),
            'b.xhtml': xhtml(body: '<p>b</p>'),
          },
          spineProperties: const {'b.xhtml': 'rendition:layout-pre-paginated'},
        ),
      );
      final support = detectBookLayout(book);
      expect(support.supported, isFalse);
      expect(support.unsupportedSectionIndices, [1]);
      expect(support.sections[0].supported, isTrue);
      expect(support.sections[1].reasons, {
        UnsupportedLayoutReason.fixedLayout,
      });
      expect(support.bookReasons, isEmpty);
    });

    test('an itemref can opt out of a fixed package', () {
      final support = detectBookLayout(
        _book(
          '<p>t</p>',
          metadata: '<meta property="rendition:layout">pre-paginated</meta>',
          spineProperties: const {'ch1.xhtml': 'rendition:layout-reflowable'},
        ),
      );
      // The package still says fixed, so the book-level reason stays.
      expect(support.bookReasons, {UnsupportedLayoutReason.fixedLayout});
      expect(support.sections.single.supported, isFalse);
    });

    test('a display-options file declaring fixed-layout', () {
      final book = EpubBook.open(
        buildEpub(
          sections: {'ch1.xhtml': xhtml(body: '<p>t</p>')},
          rootFiles: const {
            'META-INF/com.apple.ibooks.display-options.xml':
                '<display_options><platform name="*">'
                '<option name="fixed-layout">true</option></platform>'
                '</display_options>',
          },
        ),
      );
      expect(detectBookLayout(book).reasons, {
        UnsupportedLayoutReason.fixedLayout,
      });
    });

    test('page-progression-direction rtl', () {
      final support = detectBookLayout(
        _book('<p>t</p>', spineAttributes: 'page-progression-direction="rtl"'),
      );
      expect(support.reasons, {UnsupportedLayoutReason.rtlPageProgression});
      expect(support.bookReasons, {UnsupportedLayoutReason.rtlPageProgression});
    });

    test('rtl publication language without explicit direction', () {
      final support = detectBookLayout(
        _book('<p>t</p>', metadata: '<dc:language>he</dc:language>'),
      );
      expect(support.reasons, {UnsupportedLayoutReason.rtlLanguage});
    });

    test('a ltr language is supported', () {
      final support = detectBookLayout(
        _book('<p>t</p>', metadata: '<dc:language>zh-CN</dc:language>'),
      );
      expect(support.supported, isTrue);
    });
  });

  group('section-level cues', () {
    test('writing-mode on the body, a block and with vendor aliases', () {
      for (final css in const [
        'body { writing-mode: vertical-rl }',
        'html { writing-mode: vertical-lr }',
        'div.v { writing-mode: tb-rl }',
        'div.v { -epub-writing-mode: vertical-rl }',
        'div.v { -webkit-writing-mode: vertical-rl }',
      ]) {
        final support = detectBookLayout(
          _book('<div class="v"><p>t</p></div>', head: '<style>$css</style>'),
        );
        expect(support.reasons, {
          UnsupportedLayoutReason.verticalWritingMode,
        }, reason: css);
      }
    });

    test('a vertical block that is not displayed does not count', () {
      final support = detectBookLayout(
        _book(
          '<div class="v"><p>t</p></div><p>u</p>',
          head:
              '<style>.v { writing-mode: vertical-rl; display: none }</style>',
        ),
      );
      expect(support.supported, isTrue);
    });

    test('a vertical rule in a linked stylesheet is found', () {
      final support = detectBookLayout(
        _book(
          '<p>t</p>',
          head: '<link rel="stylesheet" href="v.css"/>',
          files: const {'v.css': 'body { writing-mode: vertical-rl }'},
        ),
      );
      expect(support.reasons, {UnsupportedLayoutReason.verticalWritingMode});
    });

    test('dir attribute and computed direction on the root', () {
      final cases = <String, String>{
        'html dir': '<p>t</p>|dir="rtl"|',
        'css direction': '<p>t</p>||html { direction: rtl }',
        'body direction': '<p>t</p>||body { direction: rtl }',
      };
      cases.forEach((name, spec) {
        final parts = spec.split('|');
        final support = detectBookLayout(
          _book(
            parts[0],
            htmlAttributes: parts[1],
            head: parts[2].isEmpty ? '' : '<style>${parts[2]}</style>',
          ),
        );
        expect(support.reasons, {
          UnsupportedLayoutReason.rtlDirection,
        }, reason: name);
      });
    });

    test('an isolated rtl run inside a ltr section is supported', () {
      final support = detectBookLayout(
        _book('<p>t <span dir="rtl">abc</span></p><p dir="rtl">x</p>'),
      );
      expect(support.supported, isTrue);
      expect(support.sections.single.rtlBlockCount, 2);
    });

    test('mixed books name the offending section only', () {
      final book = EpubBook.open(
        buildEpub(
          sections: {
            'a.xhtml': xhtml(body: '<p>a</p>'),
            'b.xhtml': xhtml(
              head: '<style>body { writing-mode: vertical-rl }</style>',
              body: '<p>b</p>',
            ),
            'c.xhtml': xhtml(body: '<p>c</p>'),
          },
        ),
      );
      final support = detectBookLayout(book);
      expect(support.supported, isFalse);
      expect(support.unsupportedSectionIndices, [1]);
      expect(support.bookReasons, isEmpty);
      expect(support.sections[1].reasons, {
        UnsupportedLayoutReason.verticalWritingMode,
      });
    });
  });
}
