import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/layout/section_rendition.dart';
import 'package:shiori/features/reader/data/worker/publication_import_facts.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';

import '../worker/import_test_support.dart';
import 'fixed_layout_test_support.dart';

void main() {
  test(
    'typed rendition diagnostics cross the worker as immutable values',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'shiori-rendition-',
      );
      final worker = await PublicationWorker.spawn();
      try {
        final entries = importEntries(
          layout: 'future-layout',
          properties: ['rendition:layout-pre-paginated page-spread-right'],
        );
        final file = writeImport(directory, entries);
        final imported = await worker.prepare(file.path, identityFor(file));
        final value = imported.layoutFacts.sections.single.renditionResolution!;
        expect(value.rawPackage['layout'], 'future-layout');
        expect(value.effective['layout'], 'pre-paginated');
        expect(value.issues.single.kind, RenditionIssueKind.unsupported);
        expect(value.issues.single.property, 'layout');
        expect(() => value.rawPackage.clear(), throwsUnsupportedError);
        expect(() => value.rawItemref.clear(), throwsUnsupportedError);
        expect(() => value.effective.clear(), throwsUnsupportedError);
        expect(() => value.issues.clear(), throwsUnsupportedError);
      } finally {
        await worker.close();
        directory.deleteSync(recursive: true);
      }
    },
  );
  for (final fixture in readCases(
    'corpus',
  ).where((c) => c['row'] == 'metadata' || c['row'] == 'mixed-navigation')) {
    test(
      '${fixture['id']} raw/effective rendition and filtered source sequence',
      () {
        final input = FixedCorpusInput(fixture);
        final imported = importLayoutFacts(
          input.book,
          importMetadata(input.book.archive, input.book.package.opfPath),
          0,
          input.document,
        );
        final publication = jsonObject(fixture['publication']);
        final sequence = (publication['sequence'] as List)
            .map(jsonObject)
            .toList();
        for (final key in ['layout', 'orientation', 'spread']) {
          expect(imported.packageRendition[key], publication[key]);
        }
        expect(imported.sections.length, sequence.length);
        for (var i = 0; i < sequence.length; i++) {
          final facts = imported.sections[i];
          final resolved = facts.renditionResolution!;
          expect(resolved.rawPackage, input.book.package.rendition);
          expect(resolved.rawItemref, input.book.sections[i].spine.properties);
          expect(resolved.effective['layout'], sequence[i]['layout']);
          expect(resolved.effective['orientation'], publication['orientation']);
          expect(resolved.effective['spread'], publication['spread']);
          expect(resolved.effective['pageSpread'], sequence[i]['side']);
          expect(facts.rendition, resolved.effective);
          expect(input.sections[i].linear, sequence[i]['linear']);
          expect(facts.sectionIndex, i);
          expect(facts.spineIndex, input.book.sections[i].spine.sectionIndex);
          expect(resolved.isValid, fixture['id'] != 'metadata-unsupported');
          if (fixture['id'] == 'metadata-unsupported') {
            expect(
              resolved.issues.map((i) => i.kind),
              everyElement(RenditionIssueKind.unsupported),
            );
            expect(resolved.issues.map((i) => i.property), [
              'layout',
              'orientation',
              'spread',
            ]);
            expect(facts.resolvedMode, isNull);
          } else {
            expect(
              facts.resolvedMode,
              sequence[i]['layout'] == 'pre-paginated'
                  ? PublicationLayoutMode.fixed
                  : PublicationLayoutMode.reflowable,
            );
          }
        }
        if (fixture['id'] == 'mixed-navigation-unsupported') {
          expect(
            imported.sections.first.directionIssues(
              pageProgressionDirection: imported.pageProgressionDirection,
            ),
            containsAll([
              SectionDirectionIssue.rtlProgression,
              SectionDirectionIssue.rtlDirection,
            ]),
          );
        }
      },
    );
  }
  test(
    'all itemref overrides, defaults, raw preservation and value equality',
    () {
      final package = <String, String?>{
        'layout': 'pre-paginated',
        'orientation': 'landscape',
        'spread': 'both',
        'pageSpread': 'left',
      };
      final tokens = [
        'rendition:layout-reflowable',
        'rendition:orientation-portrait',
        'rendition:spread-none',
        'rendition:page-spread-center',
      ];
      final result = resolveSectionRendition(package: package, itemref: tokens);
      final equal = resolveSectionRendition(package: package, itemref: tokens);
      expect(result, equal);
      expect(result.hashCode, equal.hashCode);
      expect(result.effective, {
        'layout': 'reflowable',
        'orientation': 'portrait',
        'spread': 'none',
        'pageSpread': 'center',
      });
      package.clear();
      tokens.clear();
      expect(result.rawPackage['layout'], 'pre-paginated');
      expect(result.rawItemref.length, 4);
      expect(() => result.effective.clear(), throwsUnsupportedError);
      expect(resolveSectionRendition(package: {}).effective, {
        'layout': 'reflowable',
        'orientation': 'auto',
        'spread': 'auto',
      });
      expect(
        resolveSectionRendition(
          package: {},
          legacyLayout: 'pre-paginated',
        ).isFixed,
        true,
      );
      expect(
        resolveSectionRendition(package: {'spread': 'portrait'}).isValid,
        true,
      );
    },
  );
  test(
    'conflicts, empty and unknown values are typed, never accepted defaults',
    () {
      final result = resolveSectionRendition(
        package: {'orientation': ''},
        itemref: [
          'rendition:layout-pre-paginated',
          'rendition:layout-reflowable',
          'page-spread-future',
        ],
      );
      expect(result.isValid, false);
      expect(
        result.issues
            .where((i) => i.kind == RenditionIssueKind.malformed)
            .length,
        2,
      );
      expect(
        result.issues
            .singleWhere((i) => i.kind == RenditionIssueKind.unsupported)
            .property,
        'pageSpread',
      );
      expect(
        resolveSectionRendition(package: {'layout': 'future'}).isFixed,
        isNull,
      );
      expect(
        resolveSectionRendition(package: {}, legacyLayout: 'future').isValid,
        false,
      );
      for (final token in [
        'rendition:layout',
        'rendition:orientation',
        'rendition:spread',
        'page-spread',
      ]) {
        expect(
          resolveSectionRendition(
            package: {},
            itemref: [token],
          ).issues.single.kind,
          RenditionIssueKind.malformed,
        );
      }
    },
  );
  test('fixed metadata and vertical/RTL are independent facts', () {
    final book = EpubBook.open(
      importZip(
        importEntries(
          layout: 'pre-paginated',
          progression: 'rtl',
          sources: [
            sourcePage(
              css: 'body { writing-mode: vertical-rl; direction: rtl; }',
            ),
          ],
        ),
      ),
    );
    final facts = importLayoutFacts(
      book,
      importMetadata(book.archive, book.package.opfPath),
      0,
      book.loadSection(0),
    );
    final section = facts.sections.single;
    expect(section.renditionResolution!.issues, isEmpty);
    expect(section.resolvedMode, PublicationLayoutMode.fixed);
    expect(
      section.directionIssues(
        pageProgressionDirection: facts.pageProgressionDirection,
      ),
      containsAll(SectionDirectionIssue.values),
    );
  });
  test('filtered section index retains original OPF spine slot', () {
    final entries = importEntries(layout: 'pre-paginated');
    entries['EPUB/package.opf'] = entries['EPUB/package.opf']!.replaceFirst(
      '<itemref id="ref0"',
      '<itemref idref="missing" linear="no"/><itemref id="ref0"',
    );
    final book = EpubBook.open(importZip(entries));
    final facts = importLayoutFacts(
      book,
      importMetadata(book.archive, book.package.opfPath),
      0,
      book.loadSection(0),
    );
    expect(facts.sections.single.sectionIndex, 0);
    expect(facts.sections.single.spineIndex, 1);
  });
}
