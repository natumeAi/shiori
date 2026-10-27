import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';

import 'import_test_support.dart';

void main() {
  late Directory directory;
  late PublicationWorker worker;
  setUp(() async {
    directory = Directory.systemTemp.createTempSync('shiori-import-metadata-');
    worker = await PublicationWorker.spawn();
  });
  tearDown(() async {
    await worker.close();
    directory.deleteSync(recursive: true);
  });

  test(
    'a valid SVG first source prepares with dimensions and zero canonical text',
    () async {
      final file = writeImport(
        directory,
        importEntries(
          layout: 'pre-paginated',
          mediaType: 'image/svg+xml',
          sources: [
            '<svg xmlns="http://www.w3.org/2000/svg" width="900px" height="1200px" viewBox="0 0 900 1200">'
                '<image href="page.png" width="900" height="1200"/></svg>',
          ],
        ),
      );
      final result = await worker.prepare(file.path, identityFor(file));
      final dimensions =
          result.layoutFacts.sections.single.source!.svgDimensions.single;
      expect(
        [dimensions.width, dimensions.height, dimensions.viewBox],
        ['900px', '1200px', '0 0 900 1200'],
      );
      expect(result.firstSection.canonicalLength, 0);
      expect(result.firstSection.resources.single.path, 'EPUB/page.png');
      expect(
        result.layoutFacts.sections.single.mode,
        PublicationLayoutMode.fixed,
      );
    },
  );

  test('legacy display options supply fixed mode without replacing raw rendition metadata', () async {
    final entries = importEntries(
      sources: [
        sourcePage(body: simpleFixedBody),
        sourcePage(),
      ],
      properties: ['', 'rendition:layout-reflowable'],
    );
    entries['EPUB/package.opf'] = entries['EPUB/package.opf']!.replaceFirst(
      '<meta property="rendition:layout">reflowable</meta>',
      '',
    );
    entries['META-INF/com.apple.ibooks.display-options.xml'] =
        '<display_options><platform name="*">'
        '<option name="fixed-layout">true</option></platform></display_options>';
    final file = writeImport(directory, entries);
    final result = await worker.prepare(file.path, identityFor(file));
    expect(result.layoutFacts.packageRendition.containsKey('layout'), isFalse);
    expect(result.layoutFacts.sections.map((e) => e.mode), [
      PublicationLayoutMode.fixed,
      PublicationLayoutMode.reflowable,
    ]);
    expect(
      result.layoutFacts.sections.last.inspection,
      SectionInspection.notInspected,
    );
  });

  test(
    'unloaded vertical/RTL section has no invented style or viewport facts',
    () async {
      final file = writeImport(
        directory,
        importEntries(
          sources: [
            sourcePage(),
            sourcePage(
              css: 'body { direction: rtl; writing-mode: vertical-lr }',
              head: viewportHead,
            ),
          ],
        ),
      );
      final result = await worker.prepare(file.path, identityFor(file));
      expect(result.layoutFacts.sections.last.style, isNull);
      expect(result.layoutFacts.sections.last.source, isNull);
      expect(
        result.layoutFacts.sections.last.inspection,
        SectionInspection.notInspected,
      );
      // A later source read does not mutate the detached import summary.
      expect((await worker.loadSection(1)).nodes, isNotEmpty);
      expect(
        result.layoutFacts.sections.last.inspection,
        SectionInspection.notInspected,
      );
    },
  );

  test('raw package viewport, language and section side/orientation/spread overrides survive', () async {
    final entries = importEntries(
      language: 'ja-JP',
      properties: [
        'rendition:orientation-auto rendition:spread-both page-spread-right',
      ],
    );
    entries['EPUB/package.opf'] = entries['EPUB/package.opf']!.replaceFirst(
      '</metadata>',
      '<meta property="rendition:source-viewport">width=1200,height=1600</meta>'
          '<dc:language>en</dc:language></metadata>',
    );
    final file = writeImport(directory, entries);
    final result = await worker.prepare(file.path, identityFor(file));
    expect(result.metadata.languages, ['ja-JP', 'en']);
    expect(result.layoutFacts.primaryLanguage, 'ja-JP');
    expect(
      result.layoutFacts.packageRendition['viewport'],
      'width=600,height=800',
    );
    expect(
      result.layoutFacts.packageRendition['sourceViewport'],
      'width=1200,height=1600',
    );
    final resolved = result.layoutFacts.sections.single.rendition;
    expect(resolved['orientation'], 'auto');
    expect(resolved['spread'], 'both');
    expect(resolved['pageSpread'], 'right');
  });
}
