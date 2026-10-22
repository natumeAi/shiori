import 'package:shiori/features/reader/data/source/source_position.dart';

/// A resolved DOM range; offsets remain exact source UTF-16 coordinates.
///
/// A boundary outside the document element uses node index `-1` (the
/// document itself) with the child slot as its offset.
final class CfiRange {
  const CfiRange({required this.start, required this.end});

  final SourcePosition start;
  final SourcePosition end;

  bool get collapsed => start == end;

  @override
  bool operator ==(Object other) =>
      other is CfiRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() =>
      'CfiRange(${start.nodeIndex}:${start.offset}'
      '..${end.nodeIndex}:${end.offset})';
}
