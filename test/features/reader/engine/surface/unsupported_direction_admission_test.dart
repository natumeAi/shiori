import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_section.dart';
import 'package:shiori/features/reader/data/worker/publication_import_facts.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';
import 'package:shiori/features/reader/engine/pagination/reading_unit_composer.dart';
import 'package:shiori/features/reader/engine/pagination/reading_unit_navigator.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';

import '../../data/layout/fixed_layout_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'RTL direction is refused before any pool owner or session can open',
    () {
      final fixture = readCases('corpus')
          .singleWhere((c) => c['id'] == 'mixed-navigation-unsupported');
      final input = FixedCorpusInput(fixture);
      addTearDown(input.book.archive.close);
      final facts = importLayoutFacts(
        input.book,
        importMetadata(input.book.archive, input.book.package.opfPath),
        0,
        input.document,
      );
      final issues = {
        for (final section in facts.sections)
          section.sectionIndex: section.directionIssues(
            pageProgressionDirection: facts.pageProgressionDirection,
          ),
      };
      final sections = [
        for (final section in input.sections)
          ReadingUnitSection(
            page: section.page,
            href: section.href,
            rendition: section.rendition,
            layoutKey: section.layoutKey,
            linear: section.linear,
            dimensions: section.dimensions,
            reflowPageCount: section.reflowPageCount,
            directionIssues: issues[section.page.sectionIndex] ?? const {},
          ),
      ];
      final pool = PageSurfacePool();
      expect(
        () => ComposedReadingUnitNavigator(
          sections: sections,
          viewportWidth: 900,
          viewportHeight: 600,
          documents: {
            for (final section in sections) section.page: input.document,
          },
          locateReflow: (_, _) => 0,
        ),
        throwsA(
          isA<UnsupportedDirectionCompositionException>().having(
            (error) => error.issues,
            'issues',
            containsAll([
              SectionDirectionIssue.rtlProgression,
              SectionDirectionIssue.rtlDirection,
            ]),
          ),
        ),
      );
      expect(pool.owners, 0);
    },
  );
}
