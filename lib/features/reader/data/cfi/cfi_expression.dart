import 'package:shiori/features/reader/data/cfi/cfi_exception.dart';
import 'package:shiori/features/reader/data/cfi/cfi_step.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';

/// Indirection groups of steps, as the reference's nested arrays.
typedef CfiGroups = List<List<CfiStep>>;

/// A parsed CFI: either a path or a `parent,start,end` range.
final class CfiExpression {
  CfiExpression.path(CfiGroups groups)
    : groups = _freeze(groups),
      parent = null,
      start = null,
      end = null;

  CfiExpression.range({
    required CfiGroups parent,
    required CfiGroups start,
    CfiGroups? end,
  }) : groups = const [],
       parent = _freeze(parent),
       start = _freeze(start),
       end = end == null ? null : _freeze(end);

  /// Path groups; empty for a range.
  final CfiGroups groups;
  final CfiGroups? parent;
  final CfiGroups? start;

  /// Null when the source had a single comma; collapsing to the end then
  /// fails like the reference.
  final CfiGroups? end;

  bool get isRange => parent != null;

  /// The reference's `collapse(parsed, toEnd)`: ranges join the parent's last
  /// group with the endpoint's first group.
  CfiGroups collapse({bool toEnd = false}) {
    final parent = this.parent;
    if (parent == null) return groups;
    final endpoint = toEnd ? end : start;
    if (endpoint == null || parent.isEmpty || endpoint.isEmpty) {
      throw const CfiException('TypeError');
    }
    return [
      ...parent.sublist(0, parent.length - 1),
      [...parent.last, ...endpoint.first],
      ...endpoint.sublist(1),
    ];
  }

  /// The reference's `JSON.stringify` of the parse result.
  Object toJson() {
    ReaderWorkGuard.check(ReaderWork.jsonSerialization);
    return isRange
        ? <String, Object?>{
            'parent': _groupsJson(parent!),
            'start': _groupsJson(start!),
            if (end != null) 'end': _groupsJson(end!),
          }
        : _groupsJson(groups);
  }
}

CfiGroups _freeze(CfiGroups groups) =>
    List.unmodifiable(groups.map((group) => List<CfiStep>.unmodifiable(group)));

List<Object?> _groupsJson(CfiGroups groups) => groups
    .map((group) => group.map((step) => step.toJson()).toList(growable: false))
    .toList(growable: false);
