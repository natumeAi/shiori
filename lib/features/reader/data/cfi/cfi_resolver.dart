import 'package:shiori/features/reader/data/cfi/cfi_child_index.dart';
import 'package:shiori/features/reader/data/cfi/cfi_exception.dart';
import 'package:shiori/features/reader/data/cfi/cfi_expression.dart';
import 'package:shiori/features/reader/data/cfi/cfi_numbers.dart';
import 'package:shiori/features/reader/data/cfi/cfi_range.dart';
import 'package:shiori/features/reader/data/cfi/cfi_step.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';

/// Resolves [expression] against [document] like the reference's `toRange`
/// (after `resolveCFI` has removed the package path).
///
/// With [skipPackagePath] the first indirection group (the OPF itemref path)
/// is dropped first, as `Epub.resolveCFI` does; the next group is the
/// content-document path. Without it, the expression is already local.
CfiRange resolveCfiRange(
  SourceDocument document,
  CfiExpression expression, {
  required bool skipPackagePath,
}) {
  final local = skipPackagePath ? _withoutFirstGroup(expression) : expression;
  final startParts = local.collapse();
  final endParts = local.collapse(toEnd: true);
  if (startParts.isEmpty || endParts.isEmpty) {
    throw const CfiException('TypeError');
  }
  final root = document.documentElementIndex;
  final start = _partsToNode(document, root, startParts.first);
  final end = _partsToNode(document, root, endParts.first);
  final startBoundary = _boundary(document, start);
  final endBoundary = _boundary(document, end);
  // Range.setEnd moves the start when the end would precede it.
  final reversed =
      _compareBoundaries(
        document,
        endBoundary.node,
        endBoundary.offset,
        startBoundary.node,
        startBoundary.offset,
      ) <
      0;
  return CfiRange(
    start: SourcePosition(
      nodeIndex: (reversed ? endBoundary : startBoundary).node,
      offset: (reversed ? endBoundary : startBoundary).offset,
    ),
    end: SourcePosition(
      nodeIndex: endBoundary.node,
      offset: endBoundary.offset,
    ),
  );
}

/// Resolves the first (package) indirection of [expression] to an element of
/// the OPF [document], like `Epub.resolveCFI`'s `toElement`.
///
/// The pinned reference compares the node name with `idref`, which an
/// `itemref` never has, so it always retries the path with its last ID
/// assertion cleared; this port does the same. Returns null when the path
/// reaches no node.
int? resolvePackageNodeIndex(
  SourceDocument document,
  CfiExpression expression,
) {
  final groups = expression.isRange ? expression.parent! : expression.groups;
  if (groups.isEmpty) throw const CfiException('TypeError');
  final top = groups.first;
  final root = document.documentElementIndex;
  var located = _partsToNode(document, root, top);
  if (located.node != null) {
    if (top.isEmpty) throw const CfiException('TypeError');
    final cleared = [
      ...top.sublist(0, top.length - 1),
      CfiStep(
        index: top.last.index,
        offset: top.last.offset,
        temporal: top.last.temporal,
        spatial: top.last.spatial,
        text: top.last.text,
        side: top.last.side,
      ),
    ];
    located = _partsToNode(document, root, cleared);
  }
  return located.node;
}

CfiExpression _withoutFirstGroup(CfiExpression expression) {
  final parent = expression.parent;
  if (parent == null) {
    return CfiExpression.path(expression.groups.skip(1).toList());
  }
  return CfiExpression.range(
    parent: parent.skip(1).toList(),
    start: expression.start!,
    end: expression.end,
  );
}

final class _Located {
  const _Located(
    this.node, {
    this.offset,
    this.before = false,
    this.after = false,
  });

  final int? node;
  final num? offset;
  final bool before;
  final bool after;
}

_Located _partsToNode(SourceDocument document, int root, List<CfiStep> parts) {
  if (parts.isEmpty) throw const CfiException('TypeError');
  final id = parts.last.id;
  if (id != null && id.isNotEmpty) {
    final element = document.getElementById(id);
    if (element != null) return _Located(element.index, offset: 0);
  }
  CfiSlot? current = CfiSlot(CfiSlotKind.element, [root]);
  for (final step in parts) {
    if (current == null) continue;
    if (current.kind != CfiSlotKind.element) {
      // A text node has no indexable children; the pin raises TypeError.
      throw const CfiException('TypeError');
    }
    final parent = current.nodes.single;
    final slots = indexChildNodes(document, parent);
    final slot = _slotAt(slots, step.index);
    switch (slot?.kind) {
      case CfiSlotKind.first:
        final children = document.node(parent).children;
        return _Located(children.isEmpty ? parent : children.first);
      case CfiSlotKind.last:
        final children = document.node(parent).children;
        return _Located(children.isEmpty ? parent : children.last);
      case CfiSlotKind.before:
        return _Located(parent, before: true);
      case CfiSlotKind.after:
        return _Located(parent, after: true);
      case CfiSlotKind.missing || null:
        current = null;
      case _:
        current = slot;
    }
  }
  final offset = parts.last.offset;
  if (current == null) return const _Located(null);
  if (!current.isChunk) return _Located(current.nodes.single, offset: offset);
  var sum = 0;
  for (final nodeIndex in current.nodes) {
    final length = document.node(nodeIndex).text?.length ?? 0;
    if (offset != null && sum + length >= offset) {
      return _Located(nodeIndex, offset: offset - sum);
    }
    sum += length;
  }
  throw const CfiException('TypeError');
}

CfiSlot? _slotAt(List<CfiSlot> slots, num index) {
  if (!index.isFinite || index != index.truncateToDouble()) return null;
  if (index < 0 || index >= slots.length) return null;
  return slots[index.toInt()];
}

typedef _Boundary = ({int node, int offset});

_Boundary _boundary(SourceDocument document, _Located located) {
  final nodeIndex = located.node;
  if (nodeIndex == null) throw const CfiException('TypeError');
  final node = document.node(nodeIndex);
  if (located.before || located.after) {
    return (
      node: node.parentIndex ?? -1,
      offset: node.childSlot + (located.after ? 1 : 0),
    );
  }
  final offset = jsToUint32(located.offset);
  final length = node.kind == SourceNodeKind.element
      ? node.children.length
      : (node.text?.length ?? 0);
  if (offset > length) throw const CfiException('IndexSizeError');
  return (node: nodeIndex, offset: offset);
}

/// DOM "position of a boundary point relative to another" as -1, 0 or 1.
/// Node indices are depth-first, so a larger index follows; -1 is the document.
int _compareBoundaries(
  SourceDocument document,
  int nodeA,
  int offsetA,
  int nodeB,
  int offsetB,
) {
  if (nodeA == nodeB) return offsetA.compareTo(offsetB);
  if (nodeA > nodeB) {
    return -_compareBoundaries(document, nodeB, offsetB, nodeA, offsetA);
  }
  var child = nodeB;
  while (true) {
    final parent = document.node(child).parentIndex ?? -1;
    if (parent == nodeA) {
      return document.node(child).childSlot < offsetA ? 1 : -1;
    }
    if (parent == -1) return -1;
    child = parent;
  }
}
