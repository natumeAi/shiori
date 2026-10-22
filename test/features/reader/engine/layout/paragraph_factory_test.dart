@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';
import 'package:shiori/features/reader/engine/layout/paragraph_factory.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/style/style_resolver.dart';

import 'layout_test_support.dart';

void main() {
  initEngineBinding();

  test('line ranges tile the paragraph text and height exactly', () async {
    final book = openFixture('long-content');
    final section = await prepareSection(
      book,
      1,
      preparer: SectionPreparer(),
      resolver: fixtureResolver(),
    );
    for (final laid in section.blocks) {
      final block = laid.block;
      final built = laid.paragraph;
      if (block is! TextBlock || built == null) continue;
      var cursor = 0;
      var top = 0.0;
      for (final line in built.lines) {
        expect(line.start, cursor);
        expect(line.top, closeTo(top, 1e-6));
        expect(line.end, greaterThanOrEqualTo(line.start));
        cursor = line.end;
        top = line.bottom;
      }
      expect(cursor, block.text.length);
      expect(top, closeTo(built.height, 1e-6));
    }
    section.dispose();
  });

  test('@font-face fonts load from the archive once and are used', () async {
    final book = openFixture('styles');
    final registry = FontRegistry();
    final preparer = SectionPreparer(fonts: registry);
    final first = await prepareSection(
      book,
      0,
      preparer: preparer,
      resolver: fixtureResolver(),
    );
    final loaded = registry.records.where((r) => r.loaded).toList();
    expect(loaded, isNotEmpty);
    expect(
      loaded.every((r) => r.alias.startsWith('shiori-test-content-')),
      isTrue,
    );
    expect(
      first.fontChains,
      contains('FixtureRoboto -> embedded EPUB/fonts/Roboto-Regular.ttf'),
    );
    // Roboto glyphs are not the 18-px squares of the test font, so a line
    // set in the embedded family is not a multiple of 18.
    final styled = first.blocks
        .where((b) => b.paragraph != null)
        .map((b) => b.paragraph!.lines.first.width)
        .where((w) => w % 18 > 0.5 && (w % 18) < 17.5);
    expect(styled, isNotEmpty);
    final count = registry.records.length;
    final second = await prepareSection(
      book,
      0,
      preparer: preparer,
      resolver: fixtureResolver(),
    );
    expect(registry.records.length, count, reason: 'no reload');
    first.dispose();
    second.dispose();
  });

  test('inline <style> and linked @font-face both carry real archive paths '
      'and load', () async {
    final book = openFixture('styles');
    final document = book.loadSection(0);
    final styled = fixtureResolver().resolve(
      book,
      0,
      document,
      const ReaderSettings(),
    );
    final faces = {for (final f in styled.fontFaces) f.family: f.archivePath};
    expect(faces['FixtureRoboto'], 'EPUB/fonts/Roboto-Regular.ttf');
    expect(faces['InlineFixture'], 'EPUB/fonts/Roboto-Regular.ttf');
    final registry = FontRegistry();
    final aliases = await registry.load(
      book.archive,
      styled.fontFaces,
      scope: 'inline',
    );
    expect(aliases.keys, containsAll(['fixtureroboto', 'inlinefixture']));
    expect(
      registry.records.where((r) => r.family == 'InlineFixture').single.loaded,
      isTrue,
    );
  });

  test('a missing or corrupt font is recorded, not fatal', () async {
    final book = openFixture('styles');
    final registry = FontRegistry();
    final aliases = await registry.load(book.archive, const [
      StyleFontFace(family: 'Gone', archivePath: 'EPUB/fonts/missing.ttf'),
      StyleFontFace(family: 'Bad', archivePath: 'EPUB/fonts/NOTICE'),
    ], scope: 'x');
    expect(aliases, isEmpty);
    expect(
      registry.records.every((r) => !r.loaded && r.failure != null),
      isTrue,
    );
  });

  test('the reader line height reaches the paragraph lines', () async {
    final book = openFixture('chapters');
    Future<double> firstLineHeight(ReaderSettings settings) async {
      final section = await prepareSection(
        book,
        0,
        preparer: SectionPreparer(),
        resolver: fixtureResolver(),
        settings: settings,
      );
      final paragraph = section.blocks
          .map((b) => b.paragraph)
          .whereType<BuiltParagraph>()
          .firstWhere((p) => p.lines.length > 1);
      // The engine rounds individual line boxes; the mean is the setting.
      final mean = paragraph.height / paragraph.lines.length;
      section.dispose();
      return mean;
    }

    final tight = await firstLineHeight(const ReaderSettings(lineHeight: 1.3));
    final loose = await firstLineHeight(const ReaderSettings(lineHeight: 2.0));
    expect(tight, closeTo(18 * 1.3, 0.5));
    expect(loose, closeTo(18 * 2.0, 0.5));
  });

  test('rt text is laid out at half size inside the paragraph', () async {
    final book = openFixture('styles');
    final section = await prepareSection(
      book,
      0,
      preparer: SectionPreparer(),
      resolver: fixtureResolver(),
    );
    final ruby = section.blocks
        .map((b) => b.block)
        .whereType<TextBlock>()
        .firstWhere((b) => b.runs.any((r) => r.scale == 0.5));
    expect(ruby.text, contains('かん'));
    // The annotation keeps its source coordinates.
    final rt = ruby.runs.firstWhere((r) => r.scale == 0.5);
    expect(ruby.map.sourceAt(rt.start), isNotNull);
    section.dispose();
  });
}
