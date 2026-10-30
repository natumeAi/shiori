import 'dart:async';

import 'package:shiori/features/reader/data/layout/reading_unit.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_navigator.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_section.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';
import 'package:shiori/features/reader/data/layout/source_page_slot.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';
import 'package:shiori/features/reader/engine/pagination/reading_unit_composer.dart';

/// Adapt PageAnchors.locate(position)?.pageIndex for prepared reflow sections.
typedef ReflowUnitLocator = FutureOr<int?> Function(
  SourcePageId page,
  SourcePosition position,
);

/// Immutable navigation snapshot. The session owns preparation and replacement.
final class ComposedReadingUnitNavigator implements ReadingUnitNavigator {
  ComposedReadingUnitNavigator({
    required List<ReadingUnitSection> sections,
    required this.viewportWidth,
    required this.viewportHeight,
    Map<SourcePageId, SourceDocument> documents = const {},
    this.locateReflow,
  }) : sections = List.unmodifiable(sections),
       documents = Map.unmodifiable(documents),
       units = const ReadingUnitComposer().compose(
         sections,
         viewportWidth: viewportWidth,
         viewportHeight: viewportHeight,
       ) {
    for (var i = 0; i < units.length; i++) {
      _unitIndices[units[i].id] = i;
      for (final slot in units[i].slots.whereType<RealSourcePageSlot>()) {
        (_sourceUnits[slot.page] ??= []).add(i);
      }
    }
  }

  final List<ReadingUnitSection> sections;
  final List<ReadingUnit> units;
  final double viewportWidth, viewportHeight;
  final Map<SourcePageId, SourceDocument> documents;
  final ReflowUnitLocator? locateReflow;
  final _unitIndices = <ReadingUnitId, int>{};
  final _sourceUnits = <SourcePageId, List<int>>{};

  ReadingUnit _activate(int index, SourcePageId page) {
    final unit = units[index];
    return ReadingUnit(
      id: unit.id,
      kind: unit.kind,
      slots: unit.slots,
      activeSource: page,
    );
  }

  @override
  Future<UnitNavigationResult> adjacent(
    ReadingUnit origin,
    UnitDirection direction,
  ) async {
    final index = _unitIndices[origin.id];
    if (index == null ||
        !_sourceUnits.containsKey(origin.activeSource) ||
        !units[index].slots.whereType<RealSourcePageSlot>().any(
          (s) => s.page == origin.activeSource,
        ) ||
        _activate(index, origin.activeSource) != origin) {
      return UnavailableReadingUnit(
        'Origin does not belong to this composition',
      );
    }
    final delta = direction == UnitDirection.next ? 1 : -1;
    UnitNavigationResult boundary() =>
        ReadingUnitBoundary(delta > 0 ? UnitBoundary.end : UnitBoundary.start);
    final targetIndex = index + delta;
    if (targetIndex < 0 || targetIndex >= units.length) return boundary();
    final candidates = units[targetIndex].slots
        .whereType<RealSourcePageSlot>()
        .toList();
    final target = (delta > 0 ? candidates.first : candidates.last).page;
    var sectionIndex = sections.indexWhere((s) => s.page == target);
    // Follow the reference physical turn first. If it lands on a nonlinear
    // source, scan from that source; another physical turn could skip its partner.
    if (!sections[sectionIndex].linear && target != origin.activeSource) {
      do {
        sectionIndex += delta;
      } while (sectionIndex >= 0 &&
          sectionIndex < sections.length &&
          !sections[sectionIndex].linear);
      if (sectionIndex < 0 || sectionIndex >= sections.length) {
        return boundary();
      }
      final page = sections[sectionIndex].page;
      final indices = _sourceUnits[page]!;
      return LocatedReadingUnit(
        _activate(delta > 0 ? indices.first : indices.last, page),
      );
    }
    return LocatedReadingUnit(_activate(targetIndex, target));
  }

  @override
  Future<UnitNavigationResult> forSourcePosition(
    SourcePageId page,
    SourcePosition position,
  ) async {
    final indices = _sourceUnits[page];
    final document = documents[page];
    if (indices == null || document == null) {
      return UnavailableReadingUnit('Source is unavailable');
    }
    if (!_validPosition(document, position)) {
      return UnavailableReadingUnit('Invalid source position');
    }
    if (units[indices.first].kind != ReadingUnitKind.reflowPage) {
      return LocatedReadingUnit(_activate(indices.single, page));
    }
    final pageIndex = await locateReflow?.call(page, position);
    if (pageIndex == null || pageIndex < 0 || pageIndex >= indices.length) {
      return UnavailableReadingUnit(
        'Source position has no laid-out reflow page',
      );
    }
    return LocatedReadingUnit(_activate(indices[pageIndex], page));
  }

  @override
  Future<UnitNavigationResult> forTocTarget(String href) async {
    final hash = href.indexOf('#');
    final path = hash < 0 ? href : href.substring(0, hash);
    final matches = sections.where((s) => s.href == path).toList();
    if (matches.length != 1) {
      return UnavailableReadingUnit('TOC document is missing or ambiguous');
    }
    final section = matches.single;
    final fragment = hash < 0 ? '' : href.substring(hash + 1);
    if (fragment.isEmpty) {
      return LocatedReadingUnit(
        _activate(_sourceUnits[section.page]!.first, section.page),
      );
    }
    final document = documents[section.page];
    if (document == null) {
      return UnavailableReadingUnit('TOC source is unavailable');
    }
    var element = document.getElementById(fragment);
    if (element == null) {
      try {
        element = document.getElementById(Uri.decodeComponent(fragment));
      } on FormatException {
        return UnavailableReadingUnit('Malformed TOC fragment');
      } on ArgumentError {
        return UnavailableReadingUnit('Malformed TOC fragment');
      }
    }
    if (element == null) {
      return UnavailableReadingUnit('TOC fragment is missing');
    }
    return forSourcePosition(
      section.page,
      SourcePosition(nodeIndex: element.index, offset: 0),
    );
  }

  /// Caller supplies fresh pagination inputs/locator for reflow. Fixed sources
  /// reuse their authored inputs. Restore via forSourcePosition on the result;
  /// an old unit is deliberately not a valid origin in the new composition.
  ComposedReadingUnitNavigator withViewport({
    required double width,
    required double height,
    List<ReadingUnitSection>? repaginatedSections,
    ReflowUnitLocator? reflowLocator,
  }) {
    if (sections.any((s) => s.rendition.isFixed == false) &&
        (repaginatedSections == null || reflowLocator == null)) {
      throw ArgumentError('Viewport change requires fresh reflow pagination');
    }
    final next = repaginatedSections ?? sections;
    if (next.length != sections.length ||
        Iterable<int>.generate(next.length)
            .any((i) => next[i].page != sections[i].page)) {
      throw ArgumentError(
        'Recomposition must retain source identity and order',
      );
    }
    return ComposedReadingUnitNavigator(
      sections: next,
      viewportWidth: width,
      viewportHeight: height,
      documents: documents,
      locateReflow: reflowLocator ?? locateReflow,
    );
  }
}

bool _validPosition(SourceDocument document, SourcePosition position) {
  if (position.nodeIndex < 0 ||
      position.nodeIndex >= document.nodes.length ||
      position.offset < 0) {
    return false;
  }
  final node = document.node(position.nodeIndex);
  if (node.isCharacterData) return position.offset <= (node.text?.length ?? 0);
  return node.kind == SourceNodeKind.element &&
      position.offset <= node.children.length;
}
