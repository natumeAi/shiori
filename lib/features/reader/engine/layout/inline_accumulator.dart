import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/layout/paragraph_map.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';

class _MutableEntry {
  _MutableEntry(
    this.kind,
    this.paraStart,
    this.paraEnd,
    this.nodeIndex,
    this.sourceStart,
    this.sourceEnd,
  );

  MapKind kind;
  int paraStart;
  int paraEnd;
  final int nodeIndex;
  final int sourceStart;
  int sourceEnd;
}

/// A finished inline formatting result: paragraph text plus its mappings.
final class InlineResult {
  const InlineResult({
    required this.text,
    required this.runs,
    required this.map,
    required this.firstNodeIndex,
    required this.lastNodeIndex,
  });

  final String text;
  final List<TextStyleRun> runs;
  final ParagraphMap map;
  final int firstNodeIndex;
  final int lastNodeIndex;
}

/// Generated text placed before the source content of a paragraph.
final class InlinePrefix {
  const InlinePrefix.text(String this.text, this.style, {this.scale = 1})
    : placeholderWidth = null;
  const InlinePrefix.placeholder(double this.placeholderWidth, this.style)
    : text = null,
      scale = 1;

  final String? text;
  final double? placeholderWidth;
  final ComputedStyle style;
  final double scale;
}

bool _isCssSpace(int unit) =>
    unit == 0x20 ||
    unit == 0x09 ||
    unit == 0x0a ||
    unit == 0x0c ||
    unit == 0x0d;

/// Collects the inline content of one paragraph, applying CSS white-space
/// processing and recording an explicit [ParagraphMapEntry] for every source
/// code unit that is collapsed, removed or generated.
final class InlineAccumulator {
  final StringBuffer _text = StringBuffer();
  int _length = 0;
  final List<_MutableEntry> _entries = [];
  final List<_RunBuilder> _runs = [];
  bool _atLineStart = true;
  bool _endsWithSpace = false;
  bool _sawBreak = false;

  /// True when something visible (text, break, generated text) was added.
  bool get hasContent => _entries.any(
    (entry) => entry.kind != MapKind.removed && entry.paraEnd > entry.paraStart,
  );

  bool get sawBreak => _sawBreak;

  void _appendText(String value, ComputedStyle style, double scale) {
    if (value.isEmpty) return;
    _text.write(value);
    final start = _length;
    _length += value.length;
    if (_runs.isNotEmpty) {
      final last = _runs.last;
      if (identical(last.style, style) &&
          last.scale == scale &&
          last.placeholderWidth == null &&
          last.end == start) {
        last.end = _length;
        return;
      }
    }
    _runs.add(_RunBuilder(start, _length, style, scale));
  }

  void _extendOrAdd(
    MapKind kind,
    int paraStart,
    int paraEnd,
    int node,
    int sourceStart,
    int sourceEnd,
  ) {
    if (_entries.isNotEmpty && kind == MapKind.exact) {
      final last = _entries.last;
      if (last.kind == MapKind.exact &&
          last.nodeIndex == node &&
          last.sourceEnd == sourceStart &&
          last.paraEnd == paraStart) {
        last.paraEnd = paraEnd;
        last.sourceEnd = sourceEnd;
        return;
      }
    }
    _entries.add(
      _MutableEntry(kind, paraStart, paraEnd, node, sourceStart, sourceEnd),
    );
  }

  /// Adds character data of source node [nodeIndex].
  void addText(
    int nodeIndex,
    String data,
    ComputedStyle style, {
    double scale = 1,
  }) {
    final mode = style.whiteSpace;
    final keepSpaces =
        mode == StyleWhiteSpace.pre || mode == StyleWhiteSpace.preWrap;
    final keepNewlines = keepSpaces || mode == StyleWhiteSpace.preLine;
    var i = 0;
    while (i < data.length) {
      final unit = data.codeUnitAt(i);
      if (keepSpaces) {
        _emitExact(nodeIndex, data, i, i + 1, style, scale);
        i++;
        _atLineStart = unit == 0x0a;
        _endsWithSpace = false;
        continue;
      }
      if (unit == 0x0a && keepNewlines) {
        _emitExact(nodeIndex, data, i, i + 1, style, scale);
        i++;
        _atLineStart = true;
        _endsWithSpace = false;
        continue;
      }
      if (_isCssSpace(unit) && !(keepNewlines && unit == 0x0a)) {
        var j = i + 1;
        while (j < data.length &&
            _isCssSpace(data.codeUnitAt(j)) &&
            !(keepNewlines && data.codeUnitAt(j) == 0x0a)) {
          j++;
        }
        if (_atLineStart || _endsWithSpace) {
          _entries.add(
            _MutableEntry(MapKind.removed, _length, _length, nodeIndex, i, j),
          );
        } else {
          final start = _length;
          _appendText(' ', style, scale);
          _entries.add(
            _MutableEntry(MapKind.collapsed, start, _length, nodeIndex, i, j),
          );
          _endsWithSpace = true;
        }
        i = j;
        continue;
      }
      var j = i + 1;
      while (j < data.length) {
        final next = data.codeUnitAt(j);
        if (_isCssSpace(next)) break;
        j++;
      }
      _emitExact(nodeIndex, data, i, j, style, scale);
      i = j;
      _atLineStart = false;
      _endsWithSpace = false;
    }
  }

  void _emitExact(
    int node,
    String data,
    int from,
    int to,
    ComputedStyle style,
    double scale,
  ) {
    final start = _length;
    _appendText(data.substring(from, to), style, scale);
    _extendOrAdd(MapKind.exact, start, _length, node, from, to);
  }

  /// A `<br>`: one generated line break; spaces before it are removed.
  void addBreak(int brIndex, ComputedStyle style) {
    _trimTrailingSpace();
    final start = _length;
    _appendText('\n', style, 1);
    _entries.add(
      _MutableEntry(MapKind.lineBreak, start, _length, brIndex, 0, 0),
    );
    _atLineStart = true;
    _endsWithSpace = false;
    _sawBreak = true;
  }

  /// Generated text with no source coordinates.
  void addSynthetic(String value, ComputedStyle style, {double scale = 1}) {
    final start = _length;
    _appendText(value, style, scale);
    _entries.add(_MutableEntry(MapKind.synthetic, start, _length, -1, 0, 0));
    _atLineStart = false;
    _endsWithSpace = false;
  }

  void _trimTrailingSpace() {
    var at = _entries.length - 1;
    while (at >= 0 && _entries[at].kind == MapKind.removed) {
      at--;
    }
    if (at < 0) return;
    final last = _entries[at];
    if (last.kind != MapKind.collapsed || last.paraEnd != _length) return;
    final text = _text.toString();
    _text
      ..clear()
      ..write(text.substring(0, text.length - 1));
    _length--;
    last
      ..kind = MapKind.removed
      ..paraEnd = last.paraStart;
    // Removed entries after it sat at the old end; follow the new one.
    for (var k = at + 1; k < _entries.length; k++) {
      _entries[k]
        ..paraStart = _length
        ..paraEnd = _length;
    }
    if (_runs.isNotEmpty) {
      final run = _runs.last;
      run.end = run.end - 1;
      if (run.end <= run.start) _runs.removeLast();
    }
    _endsWithSpace = false;
  }

  /// Finishes the paragraph. Returns null when nothing visible remains.
  /// [prefixes] are generated pieces (list marker, first-line indent) placed
  /// before the content.
  InlineResult? finish(ComputedStyle blockStyle, List<InlinePrefix> prefixes) {
    _trimTrailingSpace();
    // A trailing `<br>` ends its line without opening another one.
    var strippedBreak = false;
    var at = _entries.length - 1;
    while (at >= 0 && _entries[at].kind == MapKind.removed) {
      at--;
    }
    if (at >= 0 &&
        _entries[at].kind == MapKind.lineBreak &&
        _entries[at].paraEnd == _length) {
      final text = _text.toString();
      _text
        ..clear()
        ..write(text.substring(0, text.length - 1));
      _length--;
      _entries.removeAt(at);
      // Removed entries that followed the break move to the new end.
      for (var k = at; k < _entries.length; k++) {
        _entries[k]
          ..paraStart = _length
          ..paraEnd = _length;
      }
      strippedBreak = true;
      if (_runs.isNotEmpty) {
        final run = _runs.last;
        run.end = run.end - 1;
        if (run.end <= run.start) _runs.removeLast();
      }
    }
    if (_length == 0 && strippedBreak) {
      addSynthetic('​', blockStyle);
    }
    if (_length == 0) return null;

    final shiftText = StringBuffer();
    final entries = <ParagraphMapEntry>[];
    final runs = <TextStyleRun>[];
    var shift = 0;
    for (final prefix in prefixes) {
      final value = prefix.text ?? '￼';
      entries.add(
        ParagraphMapEntry(
          kind: MapKind.synthetic,
          paraStart: shift,
          paraEnd: shift + value.length,
        ),
      );
      runs.add(
        TextStyleRun(
          start: shift,
          end: shift + value.length,
          style: prefix.style,
          scale: prefix.scale,
          placeholderWidth: prefix.placeholderWidth,
        ),
      );
      shiftText.write(value);
      shift += value.length;
    }
    shiftText.write(_text);
    var firstNode = 1 << 30;
    var lastNode = -1;
    for (final entry in _entries) {
      entries.add(
        ParagraphMapEntry(
          kind: entry.kind,
          paraStart: entry.paraStart + shift,
          paraEnd: entry.paraEnd + shift,
          nodeIndex: entry.nodeIndex,
          sourceStart: entry.sourceStart,
          sourceEnd: entry.sourceEnd,
        ),
      );
      if (entry.nodeIndex >= 0) {
        if (entry.nodeIndex < firstNode) firstNode = entry.nodeIndex;
        if (entry.nodeIndex > lastNode) lastNode = entry.nodeIndex;
      }
    }
    for (final run in _runs) {
      runs.add(
        TextStyleRun(
          start: run.start + shift,
          end: run.end + shift,
          style: run.style,
          scale: run.scale,
        ),
      );
    }
    if (lastNode < 0) {
      firstNode = 0;
      lastNode = 0;
    }
    return InlineResult(
      text: shiftText.toString(),
      runs: runs,
      map: ParagraphMap(entries, _length + shift),
      firstNodeIndex: firstNode,
      lastNodeIndex: lastNode,
    );
  }
}

class _RunBuilder {
  _RunBuilder(this.start, this.end, this.style, this.scale);

  final int start;
  int end;
  final ComputedStyle style;
  final double scale;
  final double? placeholderWidth = null;
}
