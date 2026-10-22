import 'package:shiori/features/reader/data/source/source_position.dart';

/// What a run of paragraph code units stands for in the source.
enum MapKind {
  /// One paragraph code unit per source code unit.
  exact,

  /// One paragraph space standing for a collapsed source whitespace span.
  collapsed,

  /// Source whitespace that produced no paragraph code unit (`paraStart ==
  /// paraEnd`): collapsed away or trimmed at a line/block edge.
  removed,

  /// Generated text (list marker, indent placeholder, ruby fallback
  /// parentheses, empty-line filler). It has no CFI and no canonical slot.
  synthetic,

  /// A `<br>`: one `\n` that is generated, not source text.
  lineBreak,
}

/// One contiguous correspondence between paragraph and source code units.
final class ParagraphMapEntry {
  const ParagraphMapEntry({
    required this.kind,
    required this.paraStart,
    required this.paraEnd,
    this.nodeIndex = -1,
    this.sourceStart = 0,
    this.sourceEnd = 0,
  });

  final MapKind kind;
  final int paraStart;
  final int paraEnd;

  /// Source Text/CDATA node (or the `br` element for [MapKind.lineBreak]).
  final int nodeIndex;
  final int sourceStart;
  final int sourceEnd;

  bool get hasSource =>
      kind == MapKind.exact ||
      kind == MapKind.collapsed ||
      kind == MapKind.removed;
}

/// A source UTF-16 interval inside one character-data node.
final class SourceSpan {
  const SourceSpan(this.nodeIndex, this.start, this.end);

  final int nodeIndex;
  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is SourceSpan &&
      other.nodeIndex == nodeIndex &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(nodeIndex, start, end);
}

/// Mapping between one paragraph's UTF-16 offsets and source coordinates.
/// Entries are contiguous and ordered by [ParagraphMapEntry.paraStart].
final class ParagraphMap {
  ParagraphMap(List<ParagraphMapEntry> entries, this.length)
    : entries = List.unmodifiable(entries);

  final List<ParagraphMapEntry> entries;

  /// Paragraph length in UTF-16 code units.
  final int length;
  Map<int, List<int>>? _byNode;

  Map<int, List<int>> get _nodeEntries {
    final existing = _byNode;
    if (existing != null) return existing;
    final result = <int, List<int>>{};
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].hasSource) {
        result.putIfAbsent(entries[i].nodeIndex, () => []).add(i);
      }
    }
    return _byNode = result;
  }

  /// First entry whose `paraEnd > offset`, or `entries.length`.
  int _firstEndingAfter(int offset) {
    var low = 0;
    var high = entries.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (entries[mid].paraEnd > offset) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    return low;
  }

  /// Source position of the paragraph code unit at [paraOffset]; null for
  /// generated text. A collapsed space maps to the start of its span.
  SourcePosition? sourceAt(int paraOffset) {
    final i = _firstEndingAfter(paraOffset);
    if (i >= entries.length) return null;
    final entry = entries[i];
    if (entry.paraStart > paraOffset) return null;
    return switch (entry.kind) {
      MapKind.exact => SourcePosition(
        nodeIndex: entry.nodeIndex,
        offset: entry.sourceStart + (paraOffset - entry.paraStart),
      ),
      MapKind.collapsed => SourcePosition(
        nodeIndex: entry.nodeIndex,
        offset: entry.sourceStart,
      ),
      _ => null,
    };
  }

  /// Paragraph offset that shows source UTF-16 [offset] of [nodeIndex], or
  /// null when the node is not in this paragraph. An offset inside collapsed
  /// or removed whitespace maps to the paragraph position of that whitespace.
  int? paraOffsetOf(int nodeIndex, int offset) {
    final indices = _nodeEntries[nodeIndex];
    if (indices == null) return null;
    for (final i in indices) {
      final entry = entries[i];
      if (offset < entry.sourceStart || offset >= entry.sourceEnd) continue;
      return switch (entry.kind) {
        MapKind.exact => entry.paraStart + (offset - entry.sourceStart),
        _ => entry.paraStart,
      };
    }
    final last = entries[indices.last];
    if (offset == last.sourceEnd) return last.paraEnd;
    return null;
  }

  /// Source intervals shown by paragraph range `[paraStart, paraEnd)`,
  /// merged per node. Removed whitespace at a boundary belongs to the range
  /// that contains its position; the paragraph end belongs to the last range.
  List<SourceSpan> sourceSpans(int paraStart, int paraEnd) {
    final spans = <SourceSpan>[];
    void add(int node, int start, int end) {
      if (spans.isNotEmpty) {
        final last = spans.last;
        if (last.nodeIndex == node && last.end == start) {
          spans[spans.length - 1] = SourceSpan(node, last.start, end);
          return;
        }
      }
      spans.add(SourceSpan(node, start, end));
    }

    // First entry ending at or after paraStart: includes removed entries
    // located exactly at paraStart.
    for (var i = _firstEndingAfter(paraStart - 1); i < entries.length; i++) {
      final entry = entries[i];
      if (entry.paraStart > paraEnd) break;
      if (!entry.hasSource) continue;
      if (entry.kind == MapKind.removed) {
        final at = entry.paraStart;
        final inside = at >= paraStart && (at < paraEnd || paraEnd >= length);
        if (inside) add(entry.nodeIndex, entry.sourceStart, entry.sourceEnd);
        continue;
      }
      final from = entry.paraStart > paraStart ? entry.paraStart : paraStart;
      final to = entry.paraEnd < paraEnd ? entry.paraEnd : paraEnd;
      if (to <= from) continue;
      if (entry.kind == MapKind.exact) {
        add(
          entry.nodeIndex,
          entry.sourceStart + (from - entry.paraStart),
          entry.sourceStart + (to - entry.paraStart),
        );
      } else {
        add(entry.nodeIndex, entry.sourceStart, entry.sourceEnd);
      }
    }
    return spans;
  }
}
