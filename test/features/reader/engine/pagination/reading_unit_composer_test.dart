import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/layout/reading_unit.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_section.dart';
import 'package:shiori/features/reader/data/layout/section_rendition.dart';
import 'package:shiori/features/reader/data/layout/source_page_slot.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';
import 'package:shiori/features/reader/engine/pagination/reading_unit_composer.dart';

import '../../data/layout/fixed_layout_test_support.dart';
import 'reading_unit_test_support.dart';

List<Map<String, Object?>> planSlots(List<PlannedUnit> units) => [
  for (var i = 0; i < units.length; i++)
    for (final slot in units[i].slots.whereType<PlannedSlot>())
      {
        'index': i,
        'side': slot.side.name,
        'source': slot.section.page.sectionIndex,
      },
];

List<Map<String, Object?>> realSlots(List<ReadingUnit> units) => [
  for (var i = 0; i < units.length; i++)
    for (final slot in units[i].slots.whereType<RealSourcePageSlot>())
      {'index': i, 'side': slot.side.name, 'source': slot.page.sectionIndex},
];

void main() {
  const composer = ReadingUnitComposer();
  final corpus = readCases('corpus');
  final oracle = {for (final c in readCases('oracle')) c['id']: c};
  test('all 52 corpus compositions compare against pinned getSpreadOf', () {
    var matches = 0;
    var materialized = 0;
    final differences = <String>[];
    expect(corpus.length, 52);
    for (final fixture in corpus) {
      final input = FixedCorpusInput(fixture);
      final expected = (oracle[fixture['id']]!['referenceSpreadSlots'] as List)
          .map(jsonObject)
          .toList();
      if (input.sections.any((s) => !s.rendition.isValid)) {
        expect(fixture['id'], 'metadata-unsupported');
        expect(expected, isNotEmpty);
        expect(
          () => composer.plan(
            input.sections,
            viewportWidth: 900,
            viewportHeight: 600,
          ),
          throwsA(isA<UnitCompositionException>()),
        );
        differences.add(
          '${fixture['id']}: typed rejection of future rendition',
        );
        continue;
      }
      final plan = composer.plan(
        input.sections,
        viewportWidth: 900,
        viewportHeight: 600,
      );
      final actual = planSlots(plan);
      if (equals(expected).matches(actual, {})) {
        matches++;
      } else {
        expect(fixture['row'], 'mixed-navigation');
        expect(actual.length, expected.length);
        for (var i = 0; i < actual.length; i++) {
          expect(actual[i]['source'], expected[i]['source']);
          expect(actual[i]['index'], expected[i]['index']);
          if (input.sections[i].rendition.isFixed == false) {
            expect(actual[i]['side'], 'center');
            expect(expected[i]['side'], isIn(['left', 'right']));
          } else {
            expect(actual[i], expected[i]);
          }
        }
        differences.add(
          '${fixture['id']}: reflow sources 0/5 center; oracle right/left',
        );
      }
      final invalidSize = input.sections.any(
        (s) =>
            s.rendition.isFixed == true && s.dimensions is! ResolvedDimensions,
      );
      if (invalidSize) {
        expect(
          fixture['id'],
          isIn(['dimensions-boundary', 'dimensions-unsupported']),
        );
        expect(
          () => composer.compose(
            input.sections,
            viewportWidth: 900,
            viewportHeight: 600,
          ),
          throwsA(isA<UnitCompositionException>()),
        );
      } else {
        final units = composer.compose(
          input.sections,
          viewportWidth: 900,
          viewportHeight: 600,
        );
        expect(realSlots(units), actual);
        expect(
          units.fold<int>(0, (sum, u) => sum + u.realSourceCount),
          input.sections.length,
        );
        materialized++;
      }
    }
    expect(matches, 48);
    expect(materialized, 49);
    expect(differences.length, 4);
    // ignore: avoid_print, synthetic case names and counts only.
    print(
      'A1 composition: $matches/52 exact; $materialized materialized; ${differences.join('; ')}',
    );
  });
  test(
    'implicit cover, paired pages, explicit left/right and consecutive centers',
    () {
      final sections = [
        unitSection(0),
        unitSection(1),
        unitSection(2),
        unitSection(3, side: 'left'),
        unitSection(4, side: 'left'),
        unitSection(5, side: 'right'),
        unitSection(6, side: 'center'),
        unitSection(7, side: 'center'),
      ];
      final units = composer.compose(
        sections,
        viewportWidth: 900,
        viewportHeight: 600,
      );
      expect(
        units.map(
          (u) => u.slots
              .map((s) => s is RealSourcePageSlot ? s.page.sectionIndex : null)
              .toList(),
        ),
        [
          [null, 0],
          [1, 2],
          [3, null],
          [4, 5],
          [6],
          [7],
        ],
      );
      final portrait = composer.compose(
        sections,
        viewportWidth: 400,
        viewportHeight: 600,
      );
      expect(portrait.length, 8);
      expect(portrait.map((u) => u.activeSource), sections.map((s) => s.page));
    },
  );
  test('spread compatibility values, unequal sizes and blank placement', () {
    for (final spread in ['both', 'portrait']) {
      final units = composer.compose(
        [
          unitSection(0, side: 'left', spread: spread, height: 400),
          unitSection(
            1,
            side: 'right',
            spread: spread,
            width: 200,
            height: 200,
          ),
        ],
        viewportWidth: 400,
        viewportHeight: 600,
      );
      expect(units.length, 1);
      final right = units.single.slots.last as RealSourcePageSlot;
      expect(right.sourceToUnit.e, 320);
      expect(right.sourceToUnit.f, 100);
    }
    final blank = composer
        .compose(
          [unitSection(0, side: 'right', width: 123)],
          viewportWidth: 900,
          viewportHeight: 600,
        )
        .single;
    expect(blank.slots.first, isA<BlankSourcePageSlot>());
    expect((blank.slots.last as RealSourcePageSlot).sourceToUnit.e, 123);
    expect(blank.realSourceCount, 1);
    final none = composer.compose(
      [
        unitSection(0, spread: 'none', side: 'left'),
        unitSection(1, spread: 'none', side: 'right'),
      ],
      viewportWidth: 900,
      viewportHeight: 600,
    );
    expect(
      none.map((u) => (u.slots.single as RealSourcePageSlot).side),
      everyElement(SpreadSide.center),
    );
  });
  test('flush fixed/reflow boundaries and per-item spread changes', () {
    final units = composer.compose(
      [
        unitSection(0, side: 'left'),
        unitSection(1, fixed: false, pages: 2),
        unitSection(2, side: 'right'),
        unitSection(3, side: 'left'),
        unitSection(4, spread: 'none'),
      ],
      viewportWidth: 900,
      viewportHeight: 600,
    );
    expect(units.map((u) => u.realSourceCount), everyElement(1));
    expect(units.length, 6);
    expect(units[1].id, isNot(units[2].id));
    expect(units[1].activeSource, units[2].activeSource);
    expect(
      units[1].slots.single,
      isA<RealSourcePageSlot>().having((s) => s.authoredSize, 'size', isNull),
    );
  });
  test('invalid identity order and viewport are rejected', () {
    expect(
      () => composer.plan(
        [unitSection(0), unitSection(0)],
        viewportWidth: 900,
        viewportHeight: 600,
      ),
      throwsArgumentError,
    );
    expect(
      () => composer.plan([], viewportWidth: double.nan, viewportHeight: 600),
      throwsArgumentError,
    );
    expect(
      composer.compose([], viewportWidth: 900, viewportHeight: 600),
      isEmpty,
    );
  });
  test('direction facts refuse before units and stay distinct', () {
    for (final issue in SectionDirectionIssue.values) {
      final sections = [
        unitSection(0, directionIssues: {issue}),
      ];
      expect(
        () => composer.plan(sections, viewportWidth: 900, viewportHeight: 600),
        throwsA(
          isA<UnsupportedDirectionCompositionException>().having(
            (error) => error.issues,
            'issues',
            contains(issue),
          ),
        ),
      );
      expect(
        () =>
            composer.compose(sections, viewportWidth: 900, viewportHeight: 600),
        throwsA(isA<UnsupportedDirectionCompositionException>()),
      );
    }
    expect(
      composer.compose(
        [unitSection(0, fixed: false)],
        viewportWidth: 900,
        viewportHeight: 600,
      ),
      hasLength(1),
    );
    final noDimensions = ReadingUnitSection(
      page: unitSection(0).page,
      href: 'EPUB/p0.xhtml',
      rendition: resolveSectionRendition(package: {'layout': 'pre-paginated'}),
      layoutKey: 'no-dimensions',
    );
    expect(
      () => composer.compose(
        [noDimensions],
        viewportWidth: 900,
        viewportHeight: 600,
      ),
      throwsA(
        isA<UnitCompositionException>().having(
          (error) => error is UnsupportedDirectionCompositionException,
          'isDirection',
          false,
        ),
      ),
    );
    final malformed = ReadingUnitSection(
      page: unitSection(0).page,
      href: 'EPUB/p0.xhtml',
      rendition: resolveSectionRendition(package: {'layout': 'future'}),
      layoutKey: 'malformed',
      directionIssues: {SectionDirectionIssue.rtlProgression},
    );
    expect(
      () => composer.plan([malformed], viewportWidth: 900, viewportHeight: 600),
      throwsA(
        isA<UnitCompositionException>().having(
          (error) => error is UnsupportedDirectionCompositionException,
          'isDirection',
          false,
        ),
      ),
    );
  });
}
