import 'package:shiori/features/reader/data/layout/reading_unit.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_navigator.dart';
import 'package:shiori/features/reader/engine/pagination/anchor.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';
import 'package:shiori/features/reader/engine/pagination/reading_unit_navigator.dart';
import 'package:shiori/features/reader/engine/surface/prepared_page_position.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';

typedef PreparedUnitPage = ({
  ReadingUnit unit,
  PreparedSection section,
  int page,
});

/// Binds A1's detached composition to borrowed reflow pagination. No section
/// cache: the caller's preparation owner retains/drains the actual sections.
final class PreparedUnitNavigation {
  PreparedUnitNavigation(this.navigator, this.loadSection);
  final ComposedReadingUnitNavigator navigator;
  final Future<PreparedSection?> Function(int) loadSection;

  List<ReadingUnit> _pages(int section) => navigator.units
      .where(
        (u) =>
            u.activeSource.sectionIndex == section &&
            u.kind == ReadingUnitKind.reflowPage,
      )
      .toList(growable: false);

  ReadingUnit? unitFor(PreparedSection section, int page) {
    final inputs = navigator.sections.where(
      (s) => s.page.sectionIndex == section.sectionIndex,
    );
    if (inputs.length != 1) return null;
    final input = inputs.single;
    if (input.layoutKey != section.identity.key ||
        input.page.content.sha256 != section.identity.contentId ||
        input.reflowPageCount != section.pageCount ||
        input.rendition.isFixed != false) {
      return null;
    }
    final pages = _pages(section.sectionIndex);
    return page < 0 || page >= pages.length ? null : pages[page];
  }

  Future<PreparedUnitPage?> resolve(
    ReadingUnit unit, {
    PreparedSection? available,
    bool Function()? isCurrent,
  }) async {
    if (isCurrent != null && !isCurrent()) return null;
    // Fixed units cannot borrow the reflow preparer as a successful scene.
    if (unit.kind != ReadingUnitKind.reflowPage) return null;
    final pages = _pages(unit.activeSource.sectionIndex);
    final page = pages.indexOf(unit);
    if (page < 0) return null;
    final section = available?.sectionIndex == unit.activeSource.sectionIndex
        ? available
        : await loadSection(unit.activeSource.sectionIndex);
    if ((isCurrent != null && !isCurrent()) ||
        section == null ||
        unitFor(section, page) != unit) {
      return null;
    }
    return (unit: unit, section: section, page: page);
  }

  Future<TurnPosition?> positionFor(
    PreparedUnitPage target, {
    AnchorProofHook? proofHook,
    bool Function()? isCurrent,
  }) async {
    if (isCurrent != null && !isCurrent()) return null;
    final previous = await navigator.adjacent(
      target.unit,
      UnitDirection.previous,
    );
    if (isCurrent != null && !isCurrent()) return null;
    final next = await navigator.adjacent(target.unit, UnitDirection.next);
    if (isCurrent != null && !isCurrent()) return null;
    if (previous is UnavailableReadingUnit || next is UnavailableReadingUnit) {
      return null;
    }
    return preparedPagePosition(
      target.section,
      target.page,
      atStart:
          previous is ReadingUnitBoundary &&
          previous.boundary == UnitBoundary.start,
      atEnd: next is ReadingUnitBoundary && next.boundary == UnitBoundary.end,
      proofHook: proofHook,
    );
  }
}
