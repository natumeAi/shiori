import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/canonical/canonical_text.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';

import 'import_test_support.dart';

void main() {
  late Directory directory;
  late PublicationWorker worker;
  setUp(() async {
    directory = Directory.systemTemp.createTempSync('shiori-import-');
    worker = await PublicationWorker.spawn();
  });
  tearDown(() async {
    await worker.close();
    directory.deleteSync(recursive: true);
  });

  final cases =
      <
        String,
        (String, List<String>, List<String>, List<PublicationLayoutMode>)
      >{
        'simple fixed single-image': (
          'pre-paginated',
          [sourcePage(body: simpleFixedBody, head: viewportHead)],
          [],
          [.fixed],
        ),
        'complex static fixed': (
          'pre-paginated',
          [sourcePage(body: complexFixedBody, head: viewportHead)],
          [],
          [.fixed],
        ),
        'mixed reflowable then fixed': (
          'reflowable',
          [sourcePage(), sourcePage(body: simpleFixedBody)],
          ['', 'rendition:layout-pre-paginated'],
          [.reflowable, .fixed],
        ),
        'package fixed overridden both ways': (
          'pre-paginated',
          [sourcePage(), sourcePage(body: complexFixedBody)],
          ['rendition:layout-reflowable', 'rendition:layout-pre-paginated'],
          [.reflowable, .fixed],
        ),
        'valid fixed first with reflowable second': (
          'pre-paginated',
          [sourcePage(body: simpleFixedBody, head: viewportHead), sourcePage()],
          ['', 'rendition:layout-reflowable'],
          [.fixed, .reflowable],
        ),
        'package reflowable overridden fixed first': (
          'reflowable',
          [
            sourcePage(body: complexFixedBody, head: viewportHead),
            sourcePage(),
          ],
          [
            'rendition:layout-pre-paginated rendition:orientation-landscape rendition:spread-none page-spread-left',
            '',
          ],
          [.fixed, .reflowable],
        ),
      };
  for (final entry in cases.entries) {
    test('${entry.key} prepares with layout facts', () async {
      final (layout, sources, properties, modes) = entry.value;
      final file = writeImport(
        directory,
        importEntries(layout: layout, sources: sources, properties: properties),
      );
      final identity = identityFor(file);
      final result = await worker.prepare(file.path, identity);
      expect(result.identity, identity);
      expect(result.metadata.titles, ['Generated import']);
      expect(result.metadata.creators, ['Test']);
      expect(result.metadata.identifiers, ['fixture']);
      expect(result.layoutFacts.primaryLanguage, 'en');
      expect(result.layoutFacts.packageRendition['layout'], layout);
      expect(result.layoutFacts.sections.map((s) => s.mode), modes);
      expect(
        result.layoutFacts.sections.first.inspection,
        SectionInspection.inspected,
      );
      for (final section in result.layoutFacts.sections.skip(1)) {
        expect(section.inspection, SectionInspection.notInspected);
        expect(section.style, isNull);
        expect(section.source, isNull);
      }
      final first = result.layoutFacts.sections.first;
      expect(
        first.itemrefProperties,
        properties.isEmpty ? [''] : properties.first.split(' '),
      );
      if (sources.first.contains('name="viewport"')) {
        expect(first.source!.viewports, ['width=600,height=800']);
        expect(first.source!.sourceViewports, ['width=1200,height=1600']);
      }
      if (sources.first.contains('<svg')) {
        final svg = first.source!.svgDimensions.single;
        expect(
          [svg.width, svg.height, svg.viewBox],
          ['600', '800', '0 0 600 800'],
        );
      }
      if (properties.firstOrNull?.contains('orientation-landscape') ?? false) {
        expect(first.rendition['orientation'], 'landscape');
        expect(first.rendition['spread'], 'none');
        expect(first.rendition['pageSpread'], 'left');
        expect(result.layoutFacts.packageRendition['orientation'], 'portrait');
      }
      final direct = EpubBook.open(file.readAsBytesSync());
      final expected = direct.loadSection(0);
      final canonical = CanonicalIndex.build(expected);
      expect(result.firstSection.canonicalLength, canonical.length);
      expect(result.firstSection.canonicalSignature, canonical.signature);
      expect(result.firstSection.canonicalVersion, canonicalTextVersion);
      expect(
        (await worker.loadSection(0)).toProjectionJson(),
        expected.toProjectionJson(),
      );
      if (modes.first == PublicationLayoutMode.fixed &&
          sources.first.contains('<img')) {
        expect(result.firstSection.canonicalLength, 0);
        expect(result.firstSection.resources.single.path, 'EPUB/page.png');
      }
    });
  }

  test(
    'RTL progression and language are package facts without a refusal',
    () async {
      for (final language in ['en', 'ar-SA', 'he']) {
        final file = writeImport(
          directory,
          importEntries(
            progression: 'rtl',
            language: language,
            sources: [
              sourcePage(),
              sourcePage(css: 'body { writing-mode: vertical-rl }'),
            ],
          ),
          name: language,
        );
        final result = await worker.prepare(file.path, identityFor(file));
        expect(result.layoutFacts.pageProgressionDirection, 'rtl');
        expect(result.layoutFacts.primaryLanguage, language);
        expect(
          result.layoutFacts.sections.last.inspection,
          SectionInspection.notInspected,
        );
      }
    },
  );

  test(
    'vertical first section and RTL runs retain computed and declared facts',
    () async {
      final file = writeImport(
        directory,
        importEntries(
          sources: [
            sourcePage(
              rootAttributes: 'dir="rtl"',
              bodyAttributes: 'dir="ltr"',
              css: 'body { writing-mode: vertical-rl } .rtl { direction: rtl }',
              body: '<p class="rtl">RTL</p><p style="display:none;writing-mode:vertical-lr;direction:rtl">hidden</p>',
            ),
            sourcePage(),
          ],
        ),
      );
      final result = await worker.prepare(file.path, identityFor(file));
      final style = result.layoutFacts.sections.first.style!;
      expect(style.rootDirection, 'rtl');
      expect(style.bodyDirection, 'ltr');
      expect(style.declaredRootDirection, 'rtl');
      expect(style.declaredBodyDirection, 'ltr');
      expect(style.bodyWritingMode, 'vertical-rl');
      expect(style.writingModes, {'horizontal-tb', 'vertical-rl'});
      expect(style.rtlRunCount, 1);
    },
  );

  final manifest = jsonDecode(
    File('assets/reader_fixtures/manifest.json').readAsStringSync(),
  ) as Map;
  for (final entry in manifest['fixtures'] as List) {
    final id = (entry as Map)['id'];
    test(
      'existing oracle fixture $id prepares without changing projection',
      () async {
        final file = File('assets/reader_fixtures/${entry['file']}');
        final result = await worker.prepare(file.path, identityFor(file));
        final direct = EpubBook.open(file.readAsBytesSync());
        final index = result.firstSection.sectionIndex;
        final expected = direct.loadSection(index);
        expect(
          (await worker.loadSection(index)).toProjectionJson(),
          expected.toProjectionJson(),
        );
        expect(
          result.firstSection.canonicalSignature,
          CanonicalIndex.build(expected).signature,
        );
        if (id == 'unsupported-fixed') {
          expect(
            result.layoutFacts.sections.first.mode,
            PublicationLayoutMode.fixed,
          );
        }
        if (id == 'unsupported-rtl') {
          expect(result.layoutFacts.pageProgressionDirection, 'rtl');
        }
        if (id == 'unsupported-vertical') {
          expect(
            result.layoutFacts.sections.first.style!.writingModes,
            contains('vertical-rl'),
          );
        }
      },
    );
  }
}
