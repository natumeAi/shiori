import 'package:shiori/features/reader/data/cfi/cfi_exception.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';

/// What a numbered CFI slot of an element refers to.
enum CfiSlotKind {
  /// Virtual slot 0, before the first child.
  before,

  /// The empty text chunk before a leading element.
  first,

  /// A child element.
  element,

  /// A single Text/CDATA child.
  text,

  /// Two or more adjacent Text/CDATA children merged into one chunk.
  chunk,

  /// The absent text chunk between two adjacent elements.
  missing,

  /// The empty text chunk after a trailing element.
  last,

  /// Virtual slot after the last child.
  after,
}

/// One entry of an element's CFI child index.
final class CfiSlot {
  const CfiSlot(this.kind, [this.nodes = const []]);

  final CfiSlotKind kind;

  /// The element, the single text node, or every text node of a chunk.
  final List<int> nodes;

  bool get isChunk => kind == CfiSlotKind.chunk;

  bool holds(int nodeIndex) => nodes.contains(nodeIndex);
}

/// Port of the reference's `indexChildNodes` without a node filter:
/// `[before, first?, element, text, element, ..., last?, after]`.
///
/// Comments and processing instructions are ignored. An element with no
/// element or character-data children raises the reference's `TypeError`,
/// because the pinned function destructures an absent first child.
List<CfiSlot> indexChildNodes(SourceDocument document, int parentIndex) {
  final slots = <CfiSlot>[];
  for (final childIndex in document.node(parentIndex).children) {
    final child = document.node(childIndex);
    final isElement = child.kind == SourceNodeKind.element;
    if (!isElement && !child.isCharacterData) continue;
    if (slots.isEmpty) {
      slots.add(_slotFor(child));
      continue;
    }
    final last = slots.last;
    if (child.isCharacterData) {
      if (last.kind == CfiSlotKind.chunk || last.kind == CfiSlotKind.text) {
        slots[slots.length - 1] = CfiSlot(CfiSlotKind.chunk, [
          ...last.nodes,
          childIndex,
        ]);
      } else {
        slots.add(_slotFor(child));
      }
    } else if (last.kind == CfiSlotKind.element) {
      slots
        ..add(const CfiSlot(CfiSlotKind.missing))
        ..add(_slotFor(child));
    } else {
      slots.add(_slotFor(child));
    }
  }
  if (slots.isEmpty) throw const CfiException('TypeError');
  if (slots.first.kind == CfiSlotKind.element) {
    slots.insert(0, const CfiSlot(CfiSlotKind.first));
  }
  if (slots.last.kind == CfiSlotKind.element) {
    slots.add(const CfiSlot(CfiSlotKind.last));
  }
  slots
    ..insert(0, const CfiSlot(CfiSlotKind.before))
    ..add(const CfiSlot(CfiSlotKind.after));
  return slots;
}

CfiSlot _slotFor(SourceNode node) => CfiSlot(
  node.kind == SourceNodeKind.element ? CfiSlotKind.element : CfiSlotKind.text,
  [node.index],
);
