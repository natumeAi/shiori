import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/layout/section_rendition.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';

/// Detached composition inputs. Reflow page count/key come from pagination.
/// Fixed failures remain failures; a diagnostic slot plan needs no guessed size.
final class ReadingUnitSection {
  ReadingUnitSection({
    required this.page,
    required this.href,
    required this.rendition,
    required this.layoutKey,
    this.linear = true,
    this.dimensions,
    this.reflowPageCount = 1,
    Set<SectionDirectionIssue> directionIssues = const {},
  }) : directionIssues = Set.unmodifiable(directionIssues) {
    if (href.isEmpty || layoutKey.trim().isEmpty || reflowPageCount < 1) {
      throw ArgumentError('Invalid reading section inputs');
    }
    if (rendition.isFixed == false && dimensions != null) {
      throw ArgumentError('Reflow does not have authored dimensions');
    }
  }

  final SourcePageId page;
  final String href;
  final SectionRendition rendition;
  final String layoutKey;
  final bool linear;
  final DimensionResolution? dimensions;
  final int reflowPageCount;

  /// Typed import facts; the composer refuses nonempty values before units.
  final Set<SectionDirectionIssue> directionIssues;

  @override
  bool operator ==(Object other) =>
      other is ReadingUnitSection &&
      page == other.page &&
      href == other.href &&
      rendition == other.rendition &&
      layoutKey == other.layoutKey &&
      linear == other.linear &&
      dimensions == other.dimensions &&
      reflowPageCount == other.reflowPageCount &&
      _sameIssues(directionIssues, other.directionIssues);
  @override
  int get hashCode => Object.hash(
    page,
    href,
    rendition,
    layoutKey,
    linear,
    dimensions,
    reflowPageCount,
    Object.hashAllUnordered(directionIssues),
  );
}

bool _sameIssues(Set<SectionDirectionIssue> a, Set<SectionDirectionIssue> b) =>
    a.length == b.length && a.containsAll(b);
