import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';

enum SpreadSide { left, right, center }

sealed class SourcePageSlot {
  const SourcePageSlot();
}

/// Positional padding only. No section, CFI, source, geometry or coverage API.
final class BlankSourcePageSlot extends SourcePageSlot {
  const BlankSourcePageSlot();
  @override
  bool operator ==(Object other) => other is BlankSourcePageSlot;
  @override
  int get hashCode => runtimeType.hashCode;
}

final class RealSourcePageSlot extends SourcePageSlot {
  RealSourcePageSlot.fixed({
    required this.page,
    required AuthoredPageSize this.authoredSize,
    required this.sourceToUnit,
    required this.side,
  }) : mode = PublicationLayoutMode.fixed;

  /// Reflow dimensions belong to the actual layout, not authored-size metadata.
  RealSourcePageSlot.reflow({required this.page, required this.sourceToUnit})
    : authoredSize = null,
      mode = PublicationLayoutMode.reflowable,
      side = SpreadSide.center;

  final SourcePageId page;
  final PublicationLayoutMode mode;
  final AuthoredPageSize? authoredSize;
  final AffineTransform sourceToUnit;
  final SpreadSide side;

  @override
  bool operator ==(Object other) =>
      other is RealSourcePageSlot &&
      page == other.page &&
      mode == other.mode &&
      authoredSize == other.authoredSize &&
      sourceToUnit == other.sourceToUnit &&
      side == other.side;
  @override
  int get hashCode => Object.hash(page, mode, authoredSize, sourceToUnit, side);
}
