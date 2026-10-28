@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/engine/layout/image_cache.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/pagination/conservation.dart';
import 'package:shiori/features/reader/engine/pagination/content_box.dart';
import 'package:shiori/features/reader/engine/pagination/page_painter.dart';
import 'package:shiori/features/reader/engine/pagination/page_plan.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/style/style_resolver.dart';

import '../layout/layout_test_support.dart';

/// A viewport whose content box is 104 x 180: with the Ahem test font at
/// 18 px, 5 characters fit on a line and 6 lines (1.6 line height) on a page.
const _w = 200.0;
const _h = 300.0;

String _words(int count) => List.filled(count, 'abcde').join(' ');

Future<PreparedSection> _prepare(
  String body, {
  Map<String, Object> files = const {},
  StyleResolver resolver = const UaStyleResolver(),
  ReaderSettings settings = const ReaderSettings(),
  double width = _w,
  double height = _h,
}) async {
  final book = EpubBook.open(
    buildEpub(sections: {'ch.xhtml': xhtml(body)}, files: files),
  );
  return prepareSection(
    book,
    0,
    preparer: SectionPreparer(),
    resolver: resolver,
    settings: settings,
    width: width,
    height: height,
  );
}

void main() {
  initEngineBinding();

  group('content box', () {
    test('uses the Foliate gap and margin as insets', () {
      final box = ContentBox.fromViewport(430, 932, const ReaderSettings());
      expect(box.left, 48);
      expect(box.top, 60);
      expect(box.width, 334);
      expect(box.height, 812);
      final wide = ContentBox.fromViewport(
        430,
        932,
        const ReaderSettings(horizontalMargin: 48, verticalMargin: 48),
      );
      expect(wide.left, 96);
      expect(wide.top, 108);
      expect(wide.width, 238);
    });

    test('the gap is capped at 40% of the width', () {
      final box = ContentBox.fromViewport(100, 400, const ReaderSettings());
      expect(box.left, 40);
      expect(box.width, 20);
    });
  });

  group('page packing', () {
    test(
      'lines are packed whole and every page fits the content height',
      () async {
        final section = await _prepare('<p>${_words(60)}</p>');
        expect(section.pageCount, greaterThan(2));
        final report = checkConservation(
          section,
          const UaStyleResolver().resolve(
            openBook(),
            0,
            section.document,
            const ReaderSettings(),
          ),
        );
        expect(report.failures, isEmpty);
        for (final page in section.pages) {
          for (final fragment in page.fragments) {
            expect(
              fragment.top + fragment.height,
              lessThanOrEqualTo(section.box.height + 0.01),
            );
          }
        }
        section.dispose();
      },
    );

    test('a split paragraph keeps at least two lines on each side', () async {
      // Many paragraphs of 3 and 5 lines so that breaks fall mid-paragraph.
      final body = [
        for (var i = 0; i < 12; i++) '<p>${_words(i.isEven ? 3 : 5)}</p>',
      ].join();
      final section = await _prepare(body);
      final fragmentsByBlock = <int, List<TextFragment>>{};
      for (final page in section.pages) {
        for (final fragment in page.fragments) {
          if (fragment is TextFragment) {
            fragmentsByBlock
                .putIfAbsent(fragment.blockIndex, () => [])
                .add(fragment);
          }
        }
      }
      var split = 0;
      for (final fragments in fragmentsByBlock.values) {
        if (fragments.length > 1) {
          split++;
          for (final fragment in fragments) {
            expect(
              fragment.endLine - fragment.firstLine,
              greaterThanOrEqualTo(2),
            );
          }
        }
      }
      expect(
        split,
        greaterThan(0),
        reason: 'the fixture must split a paragraph',
      );
      section.dispose();
    });

    test(
      'an oversized image is contained and a non-fitting one moves on',
      () async {
        final png = openFixture('images').archive
            .bytes('EPUB/images/generated.png')!;
        final section = await _prepare(
          '<p>${_words(8)}</p><img src="img/a.png" style="width:80px"/>'
          '<img src="img/a.png" style="height:2000px;width:1333px"/>',
          files: {'img/a.png': png},
        );
        final images = section.blocks
            .where((b) => b.block is ImageBlock)
            .toList();
        expect(images.length, 2);
        for (final image in images) {
          expect(image.height, lessThanOrEqualTo(section.box.height));
          expect(image.width, lessThanOrEqualTo(section.box.width));
        }
        // Each image box appears once, and the tall one is alone on its page.
        final tallPage = images[1].linePage.single;
        expect(
          section.pages[tallPage].fragments.whereType<BoxFragment>().length,
          1,
        );
        section.dispose();
      },
    );

    test('page-break-before starts a page without an empty page', () async {
      final section = await _prepare(
        '<p style="page-break-before:always">first</p>'
        '<p>second</p><p style="page-break-before:always">third</p>',
        resolver: fixtureResolver(),
      );
      expect(section.pageCount, 2);
      section.dispose();
    });

    test('an empty body still has one page', () async {
      final section = await _prepare('<p>   </p>');
      expect(section.pageCount, 1);
      expect(section.pages.single.fragments, isEmpty);
      section.dispose();
    });
  });

  group('page map', () {
    test('candidate canonical intervals tile the section text', () async {
      final book = openFixture('chapters');
      final section = await prepareSection(
        book,
        0,
        preparer: SectionPreparer(),
        resolver: fixtureResolver(),
        settings: const ReaderSettings(fontSize: 26, lineHeight: 2),
      );
      final index = book.canonicalIndex(section.document);
      expect(section.pageCount, greaterThan(1));
      var cursor = 0;
      for (final page in section.pages) {
        for (final (start, end) in page.map.canonicalIntervals(index)) {
          expect(start, cursor, reason: 'page ${page.index}');
          cursor = end;
        }
      }
      expect(cursor, index.length);
      section.dispose();
    });

    test('page identity includes the layout key', () async {
      final a = await _prepare('<p>${_words(20)}</p>');
      final b = await _prepare(
        '<p>${_words(20)}</p>',
        settings: const ReaderSettings(fontSize: 20),
      );
      expect(a.pages.first.map.identity, isNot(b.pages.first.map.identity));
      expect(a.identity.key, contains('L1'));
      a.dispose();
      b.dispose();
    });
  });

  group('layout identity', () {
    test(
      'theme changes keep the key; layout settings and generation change it',
      () async {
        Future<String> key(ReaderSettings settings) async {
          final s = await _prepare('<p>x</p>', settings: settings);
          final k = s.identity.key;
          s.dispose();
          return k;
        }

        final base = await key(const ReaderSettings());
        expect(await key(const ReaderSettings(themeId: 'dark')), base);
        expect(await key(const ReaderSettings(fontSize: 20)), isNot(base));
        expect(await key(const ReaderSettings(lineHeight: 1.8)), isNot(base));
        expect(
          await key(const ReaderSettings(letterSpacing: 0.04)),
          isNot(base),
        );
        expect(
          await key(const ReaderSettings(horizontalMargin: 6)),
          isNot(base),
        );
      },
    );
  });

  group('preparation control', () {
    test('yields between blocks and stops when cancelled', () async {
      final book = EpubBook.open(
        buildEpub(
          sections: {
            'ch.xhtml': xhtml(
              [for (var i = 0; i < 30; i++) '<p>${_words(6)}</p>'].join(),
            ),
          },
        ),
      );
      final document = book.loadSection(0);
      final request = PrepareRequest(
        book: book,
        sectionIndex: 0,
        document: document,
        styled: const UaStyleResolver().resolve(
          book,
          0,
          document,
          const ReaderSettings(),
        ),
        settings: const ReaderSettings(),
        viewportWidth: _w,
        viewportHeight: _h,
        contentId: 'c',
      );
      var yields = 0;
      final control = PreparationControl(
        slice: Duration.zero,
        yielder: () async => yields++,
      );
      final pages = <int>[];
      final section = await SectionPreparer().prepare(
        request,
        control: control,
        onPageReady: (page) => pages.add(page.index),
      );
      expect(yields, greaterThan(20));
      expect(control.yieldCount, yields);
      expect(pages, [for (var i = 0; i < section.pageCount; i++) i]);
      section.dispose();

      final cancelled = PreparationControl(slice: Duration.zero);
      final future = SectionPreparer().prepare(request, control: cancelled);
      cancelled.cancel();
      await expectLater(future, throwsA(isA<PreparationCancelled>()));
    });
  });

  group('images and painting', () {
    late Uint8List png;
    setUp(() {
      png = openFixture('images').archive.bytes('EPUB/images/generated.png')!;
    });

    test(
      'the image cache stays within its byte bound and keeps leased images',
      () async {
        const outputBytes = 64 * 64 * 4;
        const intrinsicBytes = 64 * 96 * 4;
        final cache = ReaderImageCache(
          maxBytes: intrinsicBytes + outputBytes * 2,
        );
        // An impossible target is refused before invalid encoded data is
        // inspected (a decode failure would return null).
        await expectLater(
          cache.lease(
            'oversized',
            Uint8List(8),
            targetWidth: cache.maxBytes,
            targetHeight: 1,
          ),
          throwsA(isA<ImageAdmissionException>()),
        );
        expect(cache.totalBytes, 0);
        expect(cache.entryCount, 0);
        final a = (await cache.lease(
          'a',
          png,
          targetWidth: 64,
          targetHeight: 64,
        ))!;
        final b = (await cache.lease(
          'b',
          png,
          targetWidth: 64,
          targetHeight: 64,
        ))!;
        await expectLater(
          cache.lease('c', png, targetWidth: 64, targetHeight: 64),
          throwsA(isA<ImageAdmissionException>()),
        );
        // The full decode peak cannot fit while both old entries are leased.
        expect(cache.entryCount, 2);
        expect(cache.pendingBytes, 0);
        expect(cache.totalBytes, a.bytes + b.bytes);
        expect(a.image.debugDisposed, isFalse);
        expect(b.image.debugDisposed, isFalse);
        a.release();
        final c = (await cache.lease(
          'c',
          png,
          targetWidth: 64,
          targetHeight: 64,
        ))!;
        expect(
          cache.entryCount,
          2,
          reason: 'unleased entry evicted to admit the pending decode peak',
        );
        expect(a.image.debugDisposed, isTrue);
        expect(b.image.debugDisposed, isFalse);
        expect(cache.totalBytes, lessThanOrEqualTo(cache.maxBytes));
        final again = (await cache.lease(
          'b',
          Uint8List(8),
          targetWidth: 64,
          targetHeight: 64,
        ))!;
        expect(again.image, same(b.image), reason: 'leased entry was retained');
        again.release();
        b.release();
        c.release();
        cache.clearUnleased();
        expect(cache.totalBytes, 0);
        expect(
          await cache.lease('x', Uint8List(8), targetWidth: 4, targetHeight: 4),
          isNull,
        );
        expect(await cache.intrinsicSize('a', png), (
          width: 64.0,
          height: 96.0,
        ));
      },
    );

    test('vector SVG and raster images paint real pixels', () async {
      final cache = ReaderImageCache();
      final book = openFixture('images');
      final section = await prepareSection(
        book,
        0,
        preparer: SectionPreparer(images: cache),
        resolver: fixtureResolver(),
      );
      const theme = PagePaintTheme(background: 0xFFFFFFFF);
      final vectorBlock = section.blocks.firstWhere((b) => b.vector != null);
      final pageIndex = vectorBlock.linePage.single;
      await section.ensureImages(pageIndex, cache);
      final picture = PagePainter.record(section, pageIndex, theme);
      final image = await picture.toImage(430, 932);
      final data = (await image.toByteData())!;
      int pixel(double x, double y) {
        final offset = ((y.round() * 430) + x.round()) * 4;
        return (data.getUint8(offset) << 16) |
            (data.getUint8(offset + 1) << 8) |
            data.getUint8(offset + 2);
      }

      final fragment = section.pages[pageIndex].fragments
          .whereType<BoxFragment>()
          .firstWhere((f) => f.blockIndex == vectorBlock.index);
      final left = section.box.left + fragment.left;
      final top = section.box.top + fragment.top;
      // The circle (45, 45) is #5070c0 in the SVG source.
      final center = pixel(left + 45, top + 45);
      expect(center, 0x5070c0);
      // The rect background is #eff4ff.
      expect(pixel(left + 100, top + 10), 0xeff4ff);
      // The partial-support badge (SVG text is not painted) sits top right.
      expect(pixel(left + 154, top + 6), theme.marker & 0xffffff);

      // The raster inside the wrapper is drawn, not left as a placeholder.
      final wrapper = section.blocks.firstWhere(
        (b) =>
            b.block is ImageBlock &&
            (b.block as ImageBlock).kind == ImageKind.svgWrapper,
      );
      final wrapperPage = wrapper.linePage.single;
      await section.ensureImages(wrapperPage, cache);
      expect(section.leaseOf(wrapper.index), isNotNull);
      final wrapperPicture = PagePainter.record(section, wrapperPage, theme);
      final wrapperImage = await wrapperPicture.toImage(430, 932);
      final wrapperData = (await wrapperImage.toByteData())!;
      final wrapperFragment = section.pages[wrapperPage].fragments
          .whereType<BoxFragment>()
          .firstWhere((f) => f.blockIndex == wrapper.index);
      final cx =
          (section.box.left + wrapperFragment.left + wrapperFragment.width / 2)
              .round();
      final cy =
          (section.box.top + wrapperFragment.top + wrapperFragment.height / 2)
              .round();
      final o = (cy * 430 + cx) * 4;
      final rgb =
          (wrapperData.getUint8(o) << 16) |
          (wrapperData.getUint8(o + 1) << 8) |
          wrapperData.getUint8(o + 2);
      expect(rgb, isNot(0xffffff));
      expect(rgb, isNot(theme.imagePlaceholder & 0xffffff));
      section.releaseImages();
      expect(cache.totalBytes, greaterThan(0));
      image.dispose();
      wrapperImage.dispose();
      picture.dispose();
      wrapperPicture.dispose();
      section.dispose();
    });

    test('an undecodable image becomes a listed marker, not a gap', () async {
      final section = await _prepare(
        '<p>a</p><img src="img/a.png"/><p>b</p>',
        files: {'img/a.png': Uint8List.fromList(List.filled(32, 7))},
      );
      expect(section.unsupported.single.code, 'image-decode-failed');
      expect(section.blocks[1].block, isA<UnsupportedBlock>());
      final styled = const UaStyleResolver().resolve(
        openBook(),
        0,
        section.document,
        const ReaderSettings(),
      );
      expect(checkConservation(section, styled).failures, isEmpty);
      section.dispose();
    });

    test(
      'recording a page replays prepared geometry without new layout',
      () async {
        final section = await _prepare('<p>${_words(30)}</p>');
        final before = section.totalLayoutMicros;
        final picture = PagePainter.record(
          section,
          0,
          const PagePaintTheme(background: 0xFFFFFFFF),
        );
        expect(section.totalLayoutMicros, before);
        final image = await picture.toImage(200, 300);
        expect(image.width, 200);
        image.dispose();
        picture.dispose();
        section.dispose();
      },
    );
  });

  group('conservation detects loss', () {
    test(
      'hiding source text that the pages still show fails the check',
      () async {
        final section = await _prepare('<p>keep</p><p>drop</p>');
        final styled = _HidingStyled(
          const UaStyleResolver().resolve(
            openBook(),
            0,
            section.document,
            const ReaderSettings(),
          ),
          hide: (index) => section.document.node(index).text == 'drop',
        );
        final report = checkConservation(section, styled);
        expect(report.ok, isFalse);
        expect(report.failures.join(), contains('code units'));
        section.dispose();
      },
    );
  });
}

final class _HidingStyled implements StyledDocument {
  _HidingStyled(this.inner, {required this.hide});

  final StyledDocument inner;
  final bool Function(int index) hide;

  @override
  List<StyleFontFace> get fontFaces => inner.fontFaces;

  @override
  ComputedStyle get rootStyle => inner.rootStyle;

  @override
  ComputedStyle? styleOf(int nodeIndex) => hide(nodeIndex)
      ? const ComputedStyle(display: StyleDisplay.none)
      : inner.styleOf(nodeIndex);
}

/// A throwaway book only to satisfy the resolver signature of the UA test
/// resolver, which ignores it.
EpubBook openBook() =>
    EpubBook.open(buildEpub(sections: {'x.xhtml': xhtml('<p>x</p>')}));
