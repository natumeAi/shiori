import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/cfi/cfi.dart';
import 'package:shiori/features/reader/data/layout/reading_unit.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_navigator.dart';
import 'package:shiori/features/reader/data/layout/source_page_slot.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';
import 'package:shiori/features/reader/engine/pagination/reading_unit_composer.dart';
import 'package:shiori/features/reader/engine/pagination/reading_unit_navigator.dart';

import '../../contract_test_values.dart';
import '../../data/layout/fixed_layout_test_support.dart';
import 'reading_unit_test_support.dart';

Future<List<int>> traverse(
  ComposedReadingUnitNavigator nav,
  ReadingUnit start,
  UnitDirection direction,
) async {
  final result = <int>[start.activeSource.sectionIndex];
  var current = start;
  for (var turn = 0; turn <= nav.units.length; turn++) {
    final next = await nav.adjacent(current, direction);
    if (next is ReadingUnitBoundary) {
      expect(
        next.boundary,
        direction == UnitDirection.next ? UnitBoundary.end : UnitBoundary.start,
      );
      return result;
    }
    expect(next, isA<LocatedReadingUnit>());
    current = (next as LocatedReadingUnit).unit;
    result.add(current.activeSource.sectionIndex);
  }
  fail('Navigation did not reach a boundary');
}

void main() {
  for (final fixture in readCases(
    'corpus',
  ).where((c) => c['row'] == 'mixed-navigation')) {
    for (final portrait in [false, true]) {
      test(
        '${fixture['id']} ${portrait ? 'portrait' : 'landscape'} reverse/TOC/nonlinear',
        () async {
          final input = FixedCorpusInput(fixture);
          final nav = ComposedReadingUnitNavigator(
            sections: input.sections,
            viewportWidth: portrait ? 400 : 900,
            viewportHeight: 600,
            documents: {for (final s in input.sections) s.page: input.document},
            locateReflow: (_, _) => 0,
          );
          final spread = jsonObject(fixture['publication'])['spread'];
          final single = spread == 'none' || (portrait && spread != 'both');
          expect(
            await traverse(nav, nav.units.first, UnitDirection.next),
            single ? [0, 1, 2, 3, 5] : [0, 1, 2, 5],
          );
          expect(
            await traverse(nav, nav.units.last, UnitDirection.previous),
            single ? [5, 3, 2, 1, 0] : [5, 3, 1, 0],
          );
          for (var i = 0; i < input.sections.length; i++) {
            final section = input.sections[i];
            final target = await nav.forTocTarget('${section.href}#source');
            expect(target, isA<LocatedReadingUnit>());
            expect(
              (target as LocatedReadingUnit).unit.activeSource,
              section.page,
            );
            final node = input.document.getElementById('source')!;
            final position = SourcePosition(nodeIndex: node.index, offset: 0);
            final cfi = Cfi.export(
              input.document,
              position,
              sectionBase: input.book.sections[i].spine.cfiBase,
            );
            final resolved = Cfi.resolveLocal(
              input.document,
              Cfi.export(input.document, position),
            );
            expect(resolved.start, position);
            expect(
              cfi,
              contains(
                input.book.sections[i].spine.cfiBase.substring(
                  0,
                  input.book.sections[i].spine.cfiBase.length - 1,
                ),
              ),
            );
            expect(await nav.forSourcePosition(section.page, position), target);
          }
          final nonlinear = (await nav.forTocTarget(
            'EPUB/p4.xhtml#source',
          ) as LocatedReadingUnit).unit;
          expect(
            (await nav.adjacent(
              nonlinear,
              UnitDirection.next,
            ) as LocatedReadingUnit).unit.activeSource.sectionIndex,
            5,
          );
          expect(
            (await nav.adjacent(
              nonlinear,
              UnitDirection.previous,
            ) as LocatedReadingUnit).unit.activeSource.sectionIndex,
            3,
          );
          expect(
            await nav.forTocTarget('EPUB/p4.xhtml#missing'),
            isA<UnavailableReadingUnit>(),
          );
        },
      );
    }
  }
  test('landscape nonlinear landing retains its linear partner', () async {
    final sections = [
      unitSection(0),
      unitSection(1),
      unitSection(2, linear: false),
      unitSection(3),
    ];
    final nav = ComposedReadingUnitNavigator(
      sections: sections,
      viewportWidth: 900,
      viewportHeight: 600,
    );
    final last =
        (await nav.forTocTarget(sections.last.href) as LocatedReadingUnit).unit;
    final previous = (await nav.adjacent(
      last,
      UnitDirection.previous,
    ) as LocatedReadingUnit).unit;
    expect(previous.activeSource, sections[1].page);
    expect(previous.realSourceCount, 2);
    expect(
      (await nav.adjacent(
        previous,
        UnitDirection.next,
      ) as LocatedReadingUnit).unit.activeSource,
      sections[3].page,
    );
  });
  test(
    'nonlinear at both ends yields boundaries, explicit targets stay reachable',
    () async {
      final sections = [
        unitSection(0, side: 'center', linear: false),
        unitSection(1, side: 'center'),
        unitSection(2, side: 'center', linear: false),
      ];
      final nav = ComposedReadingUnitNavigator(
        sections: sections,
        viewportWidth: 900,
        viewportHeight: 600,
      );
      expect(
        await nav.adjacent(nav.units[1], UnitDirection.next),
        const ReadingUnitBoundary(UnitBoundary.end),
      );
      expect(
        await nav.adjacent(nav.units[1], UnitDirection.previous),
        const ReadingUnitBoundary(UnitBoundary.start),
      );
      expect(
        (await nav.forTocTarget(
          sections[0].href,
        ) as LocatedReadingUnit).unit.activeSource,
        sections[0].page,
      );
      expect(
        (await nav.forTocTarget(
          sections[2].href,
        ) as LocatedReadingUnit).unit.activeSource,
        sections[2].page,
      );
    },
  );
  test('fragment decoding, exact offsets, foreign content and same-spread activation', () async {
    final doc = navigationDocument();
    final sections = [
      unitSection(0, side: 'left'),
      unitSection(1, side: 'right'),
    ];
    final nav = ComposedReadingUnitNavigator(
      sections: sections,
      viewportWidth: 900,
      viewportHeight: 600,
      documents: {for (final section in sections) section.page: doc},
    );
    final left = (await nav.forTocTarget(
      '${sections[0].href}#target',
    ) as LocatedReadingUnit).unit;
    final right = (await nav.forTocTarget(
      '${sections[1].href}#target%20space',
    ) as LocatedReadingUnit).unit;
    expect(left.id, right.id);
    expect(left.activeSource, sections[0].page);
    expect(right.activeSource, sections[1].page);
    expect(
      right.slots.whereType<RealSourcePageSlot>().map((s) => s.page),
      sections.map((s) => s.page),
    );
    final text = doc.nodes.firstWhere(
      (n) => n.isCharacterData && n.text == 'Target text',
    );
    for (var offset = 0; offset <= text.text!.length; offset++) {
      final position = SourcePosition(nodeIndex: text.index, offset: offset);
      expect(Cfi.resolveLocal(doc, Cfi.export(doc, position)).start, position);
      expect(
        (await nav.forSourcePosition(
          sections[1].page,
          position,
        ) as LocatedReadingUnit).unit.activeSource,
        sections[1].page,
      );
    }
    for (final position in [
      const SourcePosition(nodeIndex: -1, offset: 0),
      SourcePosition(nodeIndex: text.index, offset: text.text!.length + 1),
    ]) {
      expect(
        await nav.forSourcePosition(sections[0].page, position),
        isA<UnavailableReadingUnit>(),
      );
    }
    expect(
      await nav.forSourcePosition(
        contractPage(content: contractContent(digest: 'b')),
        SourcePosition(nodeIndex: text.index, offset: 0),
      ),
      isA<UnavailableReadingUnit>(),
    );
    expect(
      await nav.forTocTarget('missing.xhtml#target'),
      isA<UnavailableReadingUnit>(),
    );
    expect(
      await nav.forTocTarget('${sections[0].href}#%invalid'),
      isA<UnavailableReadingUnit>(),
    );
  });
  test(
    'viewport recomposition keeps source identity and rejects old units',
    () async {
      final doc = navigationDocument();
      final sections = [
        unitSection(0, side: 'left'),
        unitSection(1, side: 'right'),
      ];
      final nav = ComposedReadingUnitNavigator(
        sections: sections,
        viewportWidth: 900,
        viewportHeight: 600,
        documents: {for (final s in sections) s.page: doc},
      );
      final origin = (await nav.forTocTarget(
        '${sections[1].href}#target',
      ) as LocatedReadingUnit).unit;
      final next = nav.withViewport(width: 400, height: 600);
      expect(next.units.length, 2);
      final point = SourcePosition(
        nodeIndex: doc.getElementById('target')!.index,
        offset: 0,
      );
      final relocated = (await next.forSourcePosition(
        origin.activeSource,
        point,
      ) as LocatedReadingUnit).unit;
      expect(relocated.activeSource, origin.activeSource);
      expect(relocated.id, isNot(origin.id));
      expect(
        await next.adjacent(origin, UnitDirection.previous),
        isA<UnavailableReadingUnit>(),
      );
      final back = next.withViewport(width: 900, height: 600);
      expect(
        (await back.forSourcePosition(
          origin.activeSource,
          point,
        ) as LocatedReadingUnit).unit,
        origin,
      );
    },
  );
  test('direction admission prevents navigator construction', () {
    expect(
      () => ComposedReadingUnitNavigator(
        sections: [
          unitSection(
            0,
            directionIssues: {SectionDirectionIssue.rtlProgression},
          ),
        ],
        viewportWidth: 900,
        viewportHeight: 600,
      ),
      throwsA(isA<UnsupportedDirectionCompositionException>()),
    );
  });
}
