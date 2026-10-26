import 'package:shiori/features/reader/data/cfi/cfi_expression.dart';
import 'package:shiori/features/reader/data/cfi/cfi_step.dart';

/// Port of the reference's `compare`. Assertions, temporal and spatial
/// offsets are ignored; a missing offset is JavaScript `undefined`, which is
/// neither greater nor less than any number.
int compareCfi(CfiExpression a, CfiExpression b) {
  if (a.isRange || b.isRange) {
    final byStart = _compareGroups(a.collapse(), b.collapse());
    if (byStart != 0) return byStart;
    return _compareGroups(a.collapse(toEnd: true), b.collapse(toEnd: true));
  }
  return _compareGroups(a.groups, b.groups);
}

int _compareGroups(CfiGroups a, CfiGroups b) {
  final groupCount = a.length > b.length ? a.length : b.length;
  for (var g = 0; g < groupCount; g++) {
    final p = g < a.length ? a[g] : const <CfiStep>[];
    final q = g < b.length ? b[g] : const <CfiStep>[];
    final maxIndex = (p.length > q.length ? p.length : q.length) - 1;
    for (var i = 0; i <= maxIndex; i++) {
      if (i >= p.length) return -1;
      if (i >= q.length) return 1;
      final x = p[i];
      final y = q[i];
      if (x.index > y.index) return 1;
      if (x.index < y.index) return -1;
      if (i == maxIndex) {
        final xo = x.offset;
        final yo = y.offset;
        if (xo != null && yo != null) {
          if (xo > yo) return 1;
          if (xo < yo) return -1;
        }
      }
    }
  }
  return 0;
}

/// Stable sort by [compare], matching JavaScript's guaranteed-stable
/// `Array.prototype.sort` for consistent comparators.
List<T> stableSort<T>(Iterable<T> items, int Function(T, T) compare) {
  final list = items.toList();
  if (list.length < 2) return list;
  final buffer = List<T>.of(list);
  _mergeSort(list, buffer, 0, list.length, compare);
  return list;
}

void _mergeSort<T>(
  List<T> list,
  List<T> buffer,
  int start,
  int end,
  int Function(T, T) compare,
) {
  if (end - start < 2) return;
  final middle = (start + end) ~/ 2;
  _mergeSort(list, buffer, start, middle, compare);
  _mergeSort(list, buffer, middle, end, compare);
  var left = start;
  var right = middle;
  var out = start;
  while (left < middle && right < end) {
    // Take from the right only when strictly smaller, keeping stability.
    if (compare(list[right], list[left]) < 0) {
      buffer[out++] = list[right++];
    } else {
      buffer[out++] = list[left++];
    }
  }
  while (left < middle) {
    buffer[out++] = list[left++];
  }
  while (right < end) {
    buffer[out++] = list[right++];
  }
  for (var i = start; i < end; i++) {
    list[i] = buffer[i];
  }
}
