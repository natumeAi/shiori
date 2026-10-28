import 'package:shiori/core/config/content_identity.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';
import 'package:shiori/features/reader/data/layout/source_page_slot.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';

final class ReadingUnitId {
  ReadingUnitId({required this.content, required this.stableId}) {
    if (stableId.trim().isEmpty) throw ArgumentError('A unit id is required');
  }
  final ContentIdentity content;

  /// Composition key supplied by the navigator; includes the reflow page when
  /// applicable. Active-side changes within the same spread retain this key.
  final String stableId;
  @override
  bool operator ==(Object other) =>
      other is ReadingUnitId &&
      content == other.content &&
      stableId == other.stableId;
  @override
  int get hashCode => Object.hash(content, stableId);
}

enum ReadingUnitKind { reflowPage, fixedSingle, fixedSpread }

/// Source composition only: no surface, resource ownership or accepted CFI.
final class ReadingUnit {
  ReadingUnit({
    required this.id,
    required this.kind,
    required List<SourcePageSlot> slots,
    required this.activeSource,
  }) : slots = List.unmodifiable(slots) {
    if (this.slots.isEmpty || this.slots.length > 2) {
      throw ArgumentError('A unit requires one or two ordered slots');
    }
    final real = this.slots.whereType<RealSourcePageSlot>().toList();
    if (real.isEmpty ||
        !real.any((slot) => slot.page == activeSource) ||
        real.any((slot) => slot.page.content != id.content) ||
        real.map((slot) => slot.page).toSet().length != real.length) {
      throw ArgumentError('Active source must be a unique real constituent');
    }
    final mode = kind == ReadingUnitKind.reflowPage
        ? PublicationLayoutMode.reflowable
        : PublicationLayoutMode.fixed;
    if (real.any((slot) => slot.mode != mode)) {
      throw ArgumentError('Reflow and fixed sources cannot mix');
    }
    if (kind == ReadingUnitKind.fixedSpread) {
      if (this.slots.length != 2) {
        throw ArgumentError('A spread needs two slots');
      }
      for (var i = 0; i < 2; i++) {
        final slot = this.slots[i];
        if (slot is RealSourcePageSlot &&
            slot.side != (i == 0 ? SpreadSide.left : SpreadSide.right)) {
          throw ArgumentError('Spread slots are ordered left then right');
        }
      }
    } else if (this.slots.length != 1 || real.length != 1) {
      throw ArgumentError('Single-page units require exactly one real slot');
    }
  }

  final ReadingUnitId id;
  final ReadingUnitKind kind;
  final List<SourcePageSlot> slots;
  final SourcePageId activeSource;
  int get realSourceCount => slots.whereType<RealSourcePageSlot>().length;

  @override
  bool operator ==(Object other) =>
      other is ReadingUnit &&
      id == other.id &&
      kind == other.kind &&
      activeSource == other.activeSource &&
      slots.length == other.slots.length &&
      Iterable<int>.generate(slots.length)
          .every((i) => slots[i] == other.slots[i]);
  @override
  int get hashCode =>
      Object.hash(id, kind, activeSource, Object.hashAll(slots));
}
