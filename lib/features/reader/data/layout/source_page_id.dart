import 'package:shiori/core/config/content_identity.dart';

/// Source identity survives viewport changes and spread recomposition.
final class SourcePageId {
  SourcePageId({
    required this.content,
    required this.sectionIndex,
    required this.spineIndex,
    required this.stableId,
  }) {
    if (sectionIndex < 0 || spineIndex < 0 || stableId.trim().isEmpty) {
      throw ArgumentError('Invalid source page identity');
    }
  }

  final ContentIdentity content;

  /// Filtered publication section index, distinct from the original OPF slot.
  final int sectionIndex;
  final int spineIndex;

  /// Producer-owned document identifier, never a display slot or page number.
  final String stableId;

  @override
  bool operator ==(Object other) =>
      other is SourcePageId &&
      content == other.content &&
      sectionIndex == other.sectionIndex &&
      spineIndex == other.spineIndex &&
      stableId == other.stableId;

  @override
  int get hashCode => Object.hash(content, sectionIndex, spineIndex, stableId);
}
