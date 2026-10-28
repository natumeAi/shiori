import 'package:shiori/features/reader/data/layout/reading_unit.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';

enum UnitDirection { previous, next }

enum UnitBoundary { start, end }

/// Lookup/preparation port only. Implementations preserve nonlinear TOC targets
/// and same-spread active-side changes. Results are candidates, never proof.
abstract interface class ReadingUnitNavigator {
  Future<UnitNavigationResult> adjacent(
    ReadingUnit origin,
    UnitDirection direction,
  );
  Future<UnitNavigationResult> forSourcePosition(
    SourcePageId page,
    SourcePosition position,
  );

  /// Package-resolved TOC href including its fragment, from EpubTocItem.href.
  Future<UnitNavigationResult> forTocTarget(String href);
}

sealed class UnitNavigationResult {
  const UnitNavigationResult();
}

final class LocatedReadingUnit extends UnitNavigationResult {
  const LocatedReadingUnit(this.unit);
  final ReadingUnit unit;
  @override
  bool operator ==(Object other) =>
      other is LocatedReadingUnit && unit == other.unit;
  @override
  int get hashCode => Object.hash(runtimeType, unit);
}

final class ReadingUnitBoundary extends UnitNavigationResult {
  const ReadingUnitBoundary(this.boundary);
  final UnitBoundary boundary;
  @override
  bool operator ==(Object other) =>
      other is ReadingUnitBoundary && boundary == other.boundary;
  @override
  int get hashCode => Object.hash(runtimeType, boundary);
}

/// Unresolved targets or failed preparation are distinct from a book boundary.
final class UnavailableReadingUnit extends UnitNavigationResult {
  UnavailableReadingUnit(this.reason) {
    if (reason.trim().isEmpty) {
      throw ArgumentError('A navigation reason is required');
    }
  }
  final String reason;
  @override
  bool operator ==(Object other) =>
      other is UnavailableReadingUnit && reason == other.reason;
  @override
  int get hashCode => Object.hash(runtimeType, reason);
}
