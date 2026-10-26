import 'package:shiori/features/reader/data/cfi/cfi_child_index.dart';
import 'package:shiori/features/reader/data/cfi/cfi_exception.dart';
import 'package:shiori/features/reader/data/cfi/cfi_expression.dart';
import 'package:shiori/features/reader/data/cfi/cfi_numbers.dart';
import 'package:shiori/features/reader/data/cfi/cfi_step.dart';
import 'package:shiori/features/reader/data/cfi/cfi_writer.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';

/// Port of the reference's `fromRange` without a node filter: the local CFI of
/// a collapsed [start], or of the range from [start] to [end].
///
/// Positions follow the DOM: UTF-16 offsets in character data, child offsets
/// in elements. [end] must not precede [start].
String exportLocalCfi(
  SourceDocument document,
  SourcePosition start, {
  SourcePosition? end,
}) {
  final startParts = _nodeToParts(document, start.nodeIndex, start.offset);
  if (end == null || end == start) return serializeGroups([startParts]);
  final endParts = _nodeToParts(document, end.nodeIndex, end.offset);
  return _buildRange(startParts, endParts);
}

String _buildRange(List<CfiStep> from, List<CfiStep> to) {
  final parent = <CfiStep>[];
  final start = <CfiStep>[];
  final end = <CfiStep>[];
  var pushToParent = true;
  final length = from.length > to.length ? from.length : to.length;
  for (var i = 0; i < length; i++) {
    final a = i < from.length ? from[i] : null;
    final b = i < to.length ? to[i] : null;
    pushToParent =
        pushToParent &&
        a != null &&
        b != null &&
        a.index == b.index &&
        !jsTruthy(a.offset) &&
        !jsTruthy(b.offset);
    if (pushToParent) {
      parent.add(a);
    } else {
      if (a != null) start.add(a);
      if (b != null) end.add(b);
    }
  }
  return serializeCfi(
    CfiExpression.range(parent: [parent], start: [start], end: [end]),
  );
}

List<CfiStep> _nodeToParts(
  SourceDocument document,
  int nodeIndex,
  num? offset,
) {
  final node = document.node(nodeIndex);
  final parentIndex = node.parentIndex;
  // The document element has no step; asking for one makes the pin walk
  // into the Document and fail.
  if (parentIndex == null) throw const CfiException('TypeError');
  final indexed = indexChildNodes(document, parentIndex);
  final index = indexed.indexWhere((slot) => slot.holds(nodeIndex));
  var adjusted = offset;
  final slot = index < 0 ? null : indexed[index];
  if (slot != null && slot.isChunk) {
    var sum = 0;
    for (final sibling in slot.nodes) {
      if (sibling == nodeIndex) {
        sum += offset?.toInt() ?? 0;
        break;
      }
      sum += document.node(sibling).text?.length ?? 0;
    }
    adjusted = sum;
  }
  final id = node.id;
  final part = CfiStep(
    index: index,
    id: id == null || id.isEmpty ? null : id,
    offset: adjusted,
  );
  final parts = parentIndex == document.documentElementIndex
      ? [part]
      : [..._nodeToParts(document, parentIndex, null), part];
  return parts.where((step) => step.index != -1).toList();
}
