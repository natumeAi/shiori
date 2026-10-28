import 'dart:convert';

import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/layout/reading_unit.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_section.dart';
import 'package:shiori/features/reader/data/layout/source_page_slot.dart';

typedef PlannedSlot = ({ReadingUnitSection section, SpreadSide side});
typedef PlannedUnit = ({
  ReadingUnitKind kind,
  List<PlannedSlot?> slots,
  int pageIndex,
});

/// A composition failure publishes no partial units.
final class UnitCompositionException implements Exception {
  const UnitCompositionException(this.reason);
  final String reason;
  @override
  String toString() => 'UnitCompositionException($reason)';
}

/// Pure composition, with no preparation, source loading or resource ownership.
final class ReadingUnitComposer {
  const ReadingUnitComposer();

  /// Diagnostic plan: validates rendition, but does not assert dimensions or
  /// renderer capability. The ordered null entries are explicit blank slots.
  List<PlannedUnit> plan(
    List<ReadingUnitSection> sections, {
    required double viewportWidth,
    required double viewportHeight,
  }) {
    if (!viewportWidth.isFinite ||
        !viewportHeight.isFinite ||
        viewportWidth <= 0 ||
        viewportHeight <= 0) {
      throw ArgumentError('Invalid composition viewport');
    }
    final seen = <int>{};
    var previousSpine = -1;
    for (final section in sections) {
      if (!section.rendition.isValid) {
        throw UnitCompositionException(
          section.rendition.issues.map((i) => i.reason).join('; '),
        );
      }
      if (!seen.add(section.page.sectionIndex) ||
          section.page.spineIndex <= previousSpine ||
          section.page.content != sections.first.page.content) {
        throw ArgumentError(
          'Sections must have unique, ordered source identities',
        );
      }
      previousSpine = section.page.spineIndex;
    }
    final physical = <PlannedUnit>[];
    PlannedSlot? pendingLeft;
    String? pendingSpread;
    void add(
      ReadingUnitKind kind,
      List<PlannedSlot?> slots, [
      int pageIndex = 0,
    ]) {
      physical.add((
        kind: kind,
        slots: List.unmodifiable(slots),
        pageIndex: pageIndex,
      ));
    }

    void flush() {
      if (pendingLeft != null) {
        add(ReadingUnitKind.fixedSpread, [pendingLeft, null]);
      }
      pendingLeft = null;
      pendingSpread = null;
    }

    var firstInRun = true;
    for (final section in sections) {
      final rendition = section.rendition.effective;
      final spread = rendition['spread'];
      if (section.rendition.isFixed == false) {
        flush();
        for (var page = 0; page < section.reflowPageCount; page++) {
          add(ReadingUnitKind.reflowPage, [
            (section: section, side: SpreadSide.center),
          ], page);
        }
        firstInRun = true;
        continue;
      }
      if (pendingLeft != null && pendingSpread != spread) flush();
      final side = rendition['pageSpread'];
      if (spread == 'none' || side == 'center') {
        flush();
        add(ReadingUnitKind.fixedSingle, [
          (section: section, side: SpreadSide.center),
        ]);
      } else if (side == 'left') {
        flush();
        pendingLeft = (section: section, side: SpreadSide.left);
        pendingSpread = spread;
      } else if (side == 'right' || pendingLeft != null || firstInRun) {
        add(ReadingUnitKind.fixedSpread, [
          pendingLeft,
          (section: section, side: SpreadSide.right),
        ]);
        pendingLeft = null;
        pendingSpread = null;
      } else {
        pendingLeft = (section: section, side: SpreadSide.left);
        pendingSpread = spread;
      }
      firstInRun = false;
    }
    flush();
    final displayed = <PlannedUnit>[];
    for (final unit in physical) {
      final spread = unit.slots
          .whereType<PlannedSlot>()
          .first
          .section
          .rendition
          .effective['spread'];
      final portrait =
          viewportHeight > viewportWidth &&
          spread != 'both' &&
          spread != 'portrait';
      if (unit.kind == ReadingUnitKind.fixedSpread && portrait) {
        for (final slot in unit.slots.whereType<PlannedSlot>()) {
          displayed.add((
            kind: ReadingUnitKind.fixedSingle,
            slots: List.unmodifiable([slot]),
            pageIndex: 0,
          ));
        }
      } else {
        displayed.add(unit);
      }
    }
    return List.unmodifiable(displayed);
  }

  List<ReadingUnit> compose(
    List<ReadingUnitSection> sections, {
    required double viewportWidth,
    required double viewportHeight,
  }) {
    final planned = plan(
      sections,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
    );
    // Preflight every real fixed page before constructing any output.
    for (final section in sections.where((s) => s.rendition.isFixed == true)) {
      if (section.dimensions is! ResolvedDimensions) {
        throw UnitCompositionException(
          section.dimensions?.reason ?? 'Missing authored dimensions',
        );
      }
    }
    return List.unmodifiable(
      planned.map((unit) {
        final real = unit.slots.whereType<PlannedSlot>().toList();
        final slots = <SourcePageSlot>[];
        AuthoredPageSize size(PlannedSlot slot) =>
            (slot.section.dimensions as ResolvedDimensions).size;
        final spread = unit.kind == ReadingUnitKind.fixedSpread;
        final leftWidth = spread
            ? size(unit.slots.first ?? real.first).width
            : 0.0;
        final maxHeight = spread
            ? real.map((s) => size(s).height).reduce((a, b) => a > b ? a : b)
            : 0.0;
        for (final slot in unit.slots) {
          if (slot == null) {
            slots.add(const BlankSourcePageSlot());
          } else if (unit.kind == ReadingUnitKind.reflowPage) {
            slots.add(
              RealSourcePageSlot.reflow(
                page: slot.section.page,
                sourceToUnit: const AffineTransform.identity(),
              ),
            );
          } else {
            final authored = size(slot);
            slots.add(
              RealSourcePageSlot.fixed(
                page: slot.section.page,
                authoredSize: authored,
                sourceToUnit: AffineTransform(
                  1,
                  0,
                  0,
                  1,
                  spread && slot.side == SpreadSide.right ? leftWidth : 0,
                  spread ? (maxHeight - authored.height) / 2 : 0,
                ),
                side: slot.side,
              ),
            );
          }
        }
        return ReadingUnit(
          id: ReadingUnitId(
            content: real.first.section.page.content,
            stableId: jsonEncode([
              viewportWidth,
              viewportHeight,
              unit.kind.name,
              unit.pageIndex,
              for (final slot in unit.slots)
                slot == null
                    ? null
                    : [
                        slot.section.page.sectionIndex,
                        slot.section.page.spineIndex,
                        slot.section.page.stableId,
                        slot.section.layoutKey,
                        slot.side.name,
                      ],
            ]),
          ),
          kind: unit.kind,
          slots: slots,
          activeSource: real.first.section.page,
        );
      }),
    );
  }
}
