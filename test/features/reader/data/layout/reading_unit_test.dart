import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/layout/reading_unit.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_navigator.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';
import 'package:shiori/features/reader/data/layout/source_page_slot.dart';

import '../../contract_test_values.dart';

void main() {
  ReadingUnit unit(
    List<SourcePageSlot> slots, {
    ReadingUnitKind kind = ReadingUnitKind.fixedSpread,
    SourcePageId? active,
  }) => ReadingUnit(
    id: contractUnitId(),
    kind: kind,
    slots: slots,
    activeSource: active ?? contractPage(),
  );

  test('blank has no source semantics and cannot be active', () {
    const blank = BlankSourcePageSlot();
    final spread = unit([blank, contractSlot(side: SpreadSide.right)]);
    expect(spread.realSourceCount, 1);
    expect(spread.activeSource, contractPage());
    expect(blank, const BlankSourcePageSlot());
    expect(blank.hashCode, const BlankSourcePageSlot().hashCode);
    expect(() => unit([blank, blank]), throwsArgumentError);
    expect(
      () => unit([
        blank,
        contractSlot(side: SpreadSide.right),
      ], active: contractPage(section: 1)),
      throwsArgumentError,
    );
  });

  test('slot counts and unit shape are enforced', () {
    expect(() => unit([]), throwsArgumentError);
    expect(
      () => unit([
        contractSlot(),
        const BlankSourcePageSlot(),
        const BlankSourcePageSlot(),
      ]),
      throwsArgumentError,
    );
    expect(() => unit([contractSlot()]), throwsArgumentError);
    expect(
      () => unit([
        contractSlot(),
        const BlankSourcePageSlot(),
      ], kind: ReadingUnitKind.fixedSingle),
      throwsArgumentError,
    );
    expect(
      () => unit([contractSlot(), contractSlot(side: SpreadSide.right)]),
      throwsArgumentError,
    );
    expect(
      unit([contractSlot()], kind: ReadingUnitKind.fixedSingle).realSourceCount,
      1,
    );
  });

  test('reflow and fixed cannot mix or masquerade as each other', () {
    final reflow = RealSourcePageSlot.reflow(
      page: contractPage(),
      sourceToUnit: const AffineTransform.identity(),
    );
    expect(reflow.authoredSize, isNull);
    expect(
      () => unit([
        reflow,
        contractSlot(page: contractPage(section: 1), side: SpreadSide.right),
      ]),
      throwsArgumentError,
    );
    expect(
      () => unit([contractSlot()], kind: ReadingUnitKind.reflowPage),
      throwsArgumentError,
    );
    expect(
      () => unit([reflow], kind: ReadingUnitKind.fixedSingle),
      throwsArgumentError,
    );
    expect(
      unit([reflow], kind: ReadingUnitKind.reflowPage).activeSource,
      contractPage(),
    );
  });

  test(
    'left/right ordering, unique sources and content identity are enforced',
    () {
      final left = contractSlot(side: SpreadSide.left);
      final right = contractSlot(
        page: contractPage(section: 1),
        side: SpreadSide.right,
      );
      expect(unit([left, right]).realSourceCount, 2);
      expect(() => unit([right, left]), throwsArgumentError);
      expect(
        () => unit([left, contractSlot(side: SpreadSide.right)]),
        throwsArgumentError,
      );
      expect(
        () => unit([
          contractSlot(page: contractPage(content: contractContent(bookId: 2))),
        ], kind: ReadingUnitKind.fixedSingle),
        throwsArgumentError,
      );
    },
  );

  test('source and unit identities have full value equality', () {
    final a = contractPage();
    expect(a, contractPage());
    expect(a.hashCode, contractPage().hashCode);
    expect(a, isNot(contractPage(spine: 7)));
    expect(a, isNot(contractPage(section: 1)));
    expect(a, isNot(contractPage(id: 'other')));
    expect(a, isNot(contractPage(content: contractContent(digest: 'b'))));
    expect(() => contractPage(section: -1), throwsArgumentError);
    expect(() => contractPage(spine: -1), throwsArgumentError);
    expect(() => contractPage(id: ' '), throwsArgumentError);
    expect(
      () => ReadingUnitId(content: contractContent(), stableId: ''),
      throwsArgumentError,
    );
  });

  test(
    'slots are copied and immutable; active-side changes retain unit id',
    () {
      final left = contractSlot(side: SpreadSide.left);
      final right = contractSlot(
        page: contractPage(section: 1),
        side: SpreadSide.right,
      );
      final slots = <SourcePageSlot>[left, right];
      final a = unit(slots);
      final equal = unit([contractSlot(side: SpreadSide.left), right]);
      slots.clear();
      expect(a.slots.length, 2);
      expect(() => a.slots.clear(), throwsUnsupportedError);
      expect(a, equal);
      expect(a.hashCode, equal.hashCode);
      final otherActive = unit([left, right], active: right.page);
      expect(a.id, otherActive.id);
      expect(a, isNot(otherActive));
    },
  );

  test(
    'navigation boundary, unavailable and located values remain distinct',
    () {
      final located = LocatedReadingUnit(
        unit([contractSlot()], kind: ReadingUnitKind.fixedSingle),
      );
      expect(
        located,
        LocatedReadingUnit(
          unit([contractSlot()], kind: ReadingUnitKind.fixedSingle),
        ),
      );
      expect(
        const ReadingUnitBoundary(UnitBoundary.start),
        const ReadingUnitBoundary(UnitBoundary.start),
      );
      expect(
        const ReadingUnitBoundary(UnitBoundary.start),
        isNot(const ReadingUnitBoundary(UnitBoundary.end)),
      );
      expect(
        UnavailableReadingUnit('unresolved-target'),
        UnavailableReadingUnit('unresolved-target'),
      );
      expect(() => UnavailableReadingUnit(''), throwsArgumentError);
    },
  );
}
