import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/layout/reading_unit.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_navigator.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_section.dart';
import 'package:shiori/features/reader/data/layout/section_rendition.dart';
import 'package:shiori/features/reader/data/layout/source_page_slot.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';
import 'package:shiori/features/reader/engine/pagination/anchor.dart';
import 'package:shiori/features/reader/engine/pagination/reading_unit_navigator.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';

import '../../contract_test_values.dart';
import '../layout/layout_test_support.dart';

const _fixtures = [
  'cfi-structure',
  'html-fallback',
  'inert-content',
  'opf-variants',
  'unicode',
  'styles',
  'images',
  'long-content',
  'chapters',
  'one-page',
];

void main() {
  initEngineBinding();
  final preparer = SectionPreparer();
  for (final id in _fixtures) {
    test(
      '$id reflow corpus: one unit per actual page with source/CFI lookup',
      () async {
        final book = openFixture(id);
        for (final setting in gateSettings.values) {
          for (
            var sectionIndex = 0;
            sectionIndex < book.sections.length;
            sectionIndex++
          ) {
            final prepared = await prepareSection(
              book,
              sectionIndex,
              preparer: preparer,
              resolver: fixtureResolver(),
              settings: setting,
            );
            try {
              final source = contractPage(
                section: sectionIndex,
                spine: book.sections[sectionIndex].spine.sectionIndex,
                id: book.sections[sectionIndex].spine.href!,
              );
              final input = ReadingUnitSection(
                page: source,
                href: book.sections[sectionIndex].spine.href!,
                rendition: resolveSectionRendition(package: {}),
                layoutKey: prepared.identity.key,
                reflowPageCount: prepared.pages.length,
              );
              final anchors = PageAnchors(prepared);
              final nav = ComposedReadingUnitNavigator(
                sections: [input],
                viewportWidth: phoneWidth,
                viewportHeight: phoneHeight,
                documents: {source: prepared.document},
                locateReflow: (_, point) => anchors.locate(point)?.pageIndex,
              );
              expect(nav.units.length, prepared.pages.length);
              expect(
                nav.units.map((u) => u.id).toSet().length,
                prepared.pages.length,
              );
              expect(
                nav.units.map((u) => u.kind),
                everyElement(ReadingUnitKind.reflowPage),
              );
              for (final node in prepared.document.nodes.where(
                (n) => n.id?.isNotEmpty ?? false,
              )) {
                final position = SourcePosition(
                  nodeIndex: node.index,
                  offset: 0,
                );
                final target = await nav.forTocTarget(
                  '${input.href}#${node.id}',
                );
                final laidOut = anchors.locate(position);
                if (laidOut == null) {
                  expect(target, isA<UnavailableReadingUnit>());
                } else {
                  expect(
                    (target as LocatedReadingUnit).unit,
                    nav.units[laidOut.pageIndex],
                  );
                }
              }
              for (var page = 0; page < nav.units.length; page++) {
                final unit = nav.units[page];
                final slot = unit.slots.single as RealSourcePageSlot;
                expect(slot.page, source);
                expect(slot.authoredSize, isNull);
                final anchor = anchors.exportVisible(page);
                if (anchor != null) {
                  expect(anchors.prove(anchor.cfi).pageIndex, page);
                  expect(
                    (await nav.forSourcePosition(
                      source,
                      anchor.position,
                    ) as LocatedReadingUnit).unit,
                    unit,
                  );
                }
                if (page + 1 < nav.units.length) {
                  expect(
                    (await nav.adjacent(
                      unit,
                      UnitDirection.next,
                    ) as LocatedReadingUnit).unit,
                    nav.units[page + 1],
                  );
                } else {
                  expect(
                    await nav.adjacent(unit, UnitDirection.next),
                    const ReadingUnitBoundary(UnitBoundary.end),
                  );
                }
                if (page > 0) {
                  expect(
                    (await nav.adjacent(
                      unit,
                      UnitDirection.previous,
                    ) as LocatedReadingUnit).unit,
                    nav.units[page - 1],
                  );
                } else {
                  expect(
                    await nav.adjacent(unit, UnitDirection.previous),
                    const ReadingUnitBoundary(UnitBoundary.start),
                  );
                }
              }
            } finally {
              prepared.dispose();
            }
          }
        }
      },
    );
  }
  test('reflow viewport replacement restores source position through new pagination', () async {
    final book = openFixture('long-content');
    final before = await prepareSection(
      book,
      0,
      preparer: preparer,
      resolver: fixtureResolver(),
    );
    final after = await prepareSection(
      book,
      0,
      preparer: preparer,
      resolver: fixtureResolver(),
      width: 900,
      height: 600,
    );
    try {
      final source = contractPage(id: book.sections.first.spine.href!);
      ReadingUnitSection input(bool changed) {
        final section = changed ? after : before;
        return ReadingUnitSection(
          page: source,
          href: book.sections.first.spine.href!,
          rendition: resolveSectionRendition(package: {}),
          layoutKey: section.identity.key,
          reflowPageCount: section.pages.length,
        );
      }

      final nav = ComposedReadingUnitNavigator(
        sections: [input(false)],
        viewportWidth: phoneWidth,
        viewportHeight: phoneHeight,
        documents: {source: before.document},
        locateReflow: (_, point) =>
            PageAnchors(before).locate(point)?.pageIndex,
      );
      final position = PageAnchors(before)
          .exportVisible(before.pages.length ~/ 2)!;
      final old = (await nav.forSourcePosition(
        source,
        position.position,
      ) as LocatedReadingUnit).unit;
      expect(
        () => nav.withViewport(width: 900, height: 600),
        throwsArgumentError,
      );
      final changed = nav.withViewport(
        width: 900,
        height: 600,
        repaginatedSections: [input(true)],
        reflowLocator: (_, point) =>
            PageAnchors(after).locate(point)?.pageIndex,
      );
      final located = (await changed.forSourcePosition(
        source,
        position.position,
      ) as LocatedReadingUnit).unit;
      expect(located.activeSource, old.activeSource);
      expect(
        located,
        changed.units[PageAnchors(after).locate(position.position)!.pageIndex],
      );
      expect(located.id, isNot(old.id));
    } finally {
      before.dispose();
      after.dispose();
    }
  });
}
