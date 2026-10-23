import 'dart:typed_data';

import 'package:shiori/features/reader/data/canonical/fnv1a64.dart';
import 'package:shiori/features/reader/data/canonical/unicode_exclusion_table.g.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';

/// Normalization version shared with the reference server contract.
const canonicalTextVersion = 1;

const _svgNamespace = 'http://www.w3.org/2000/svg';
const _mathNamespace = 'http://www.w3.org/1998/Math/MathML';
const _excludedElements = {'script', 'style', 'noscript', 'template'};

/// `true` when [codePoint] counts under normalization v1: not `White_Space`,
/// `Cc`, `Cf` or an unpaired surrogate (`Cs`). The ranges come from the
/// committed WebKit oracle table, never from the Dart runtime's Unicode data.
bool isCanonicalCodePoint(int codePoint) {
  // Printable ASCII and CJK Unified Ideographs are always canonical.
  if (codePoint > 0x20 && codePoint < 0x7f) return true;
  if (codePoint >= 0x4e00 && codePoint <= 0x9fff) return true;
  var low = 0;
  var high = canonicalExcludedRanges.length ~/ 2 - 1;
  while (low <= high) {
    final mid = (low + high) >> 1;
    if (codePoint < canonicalExcludedRanges[mid * 2]) {
      high = mid - 1;
    } else if (codePoint > canonicalExcludedRanges[mid * 2 + 1]) {
      low = mid + 1;
    } else {
      return false;
    }
  }
  return true;
}

/// Walks [text] by code point: unpaired surrogates are their own code point.
/// Calls [visit] with `(codePoint, utf16Offset)`.
void forEachCodePoint(String text, void Function(int, int) visit) {
  ReaderWorkGuard.check(ReaderWork.canonicalTraversal);
  for (var offset = 0; offset < text.length;) {
    final unit = text.codeUnitAt(offset);
    var codePoint = unit;
    var width = 1;
    if (unit >= 0xd800 && unit <= 0xdbff && offset + 1 < text.length) {
      final next = text.codeUnitAt(offset + 1);
      if (next >= 0xdc00 && next <= 0xdfff) {
        codePoint = 0x10000 + ((unit - 0xd800) << 10) + (next - 0xdc00);
        width = 2;
      }
    }
    visit(codePoint, offset);
    offset += width;
  }
}

/// Canonical characters of [text] under normalization v1.
int countCanonicalCharacters(String text) {
  ReaderWorkGuard.check(ReaderWork.canonicalTraversal);
  var count = 0;
  forEachCodePoint(text, (codePoint, _) {
    if (isCanonicalCodePoint(codePoint)) count++;
  });
  return count;
}

/// One indexed Text node and its canonical range `[start, start + length)`.
final class CanonicalEntry {
  CanonicalEntry({
    required this.nodeIndex,
    required this.start,
    required this.length,
    required this.utf16Length,
    required this.canonicalToUtf16,
  });

  /// Index of the Text node in the [SourceDocument].
  final int nodeIndex;

  /// Canonical offset of the node's first canonical character.
  final int start;

  /// Canonical characters in the node; always positive.
  final int length;

  /// UTF-16 length of the node's data when indexed.
  final int utf16Length;

  /// UTF-16 start offset of canonical character `k` of this node.
  final Uint32List canonicalToUtf16;

  Map<String, Object?> toJson() {
    ReaderWorkGuard.check(ReaderWork.jsonSerialization);
    return {
      'node': nodeIndex,
      'start': start,
      'length': length,
      'utf16Length': utf16Length,
      'canonicalToUtf16': canonicalToUtf16.toList(growable: false),
    };
  }
}

/// Layout-independent text coordinates for one spine document.
final class CanonicalIndex {
  CanonicalIndex._({
    required this.version,
    required List<CanonicalEntry> entries,
    required this.length,
    required this.signature,
  }) : entries = List.unmodifiable(entries);

  /// Indexes the body text (the document element when there is no body).
  /// Only Text nodes count (not CDATA); `script`, `style`, `noscript`,
  /// `template` and SVG/MathML subtrees get no coordinates. CSS visibility
  /// never changes coordinates.
  factory CanonicalIndex.build(SourceDocument document) {
    ReaderWorkGuard.check(ReaderWork.canonicalTraversal);
    final rootIndex = document.bodyIndex ?? document.documentElementIndex;
    final entries = <CanonicalEntry>[];
    final hash = Fnv1a64();
    var length = 0;
    if (!_isExcluded(document.node(rootIndex))) {
      final stack = <int>[rootIndex];
      while (stack.isNotEmpty) {
        final node = document.node(stack.removeLast());
        if (node.kind == SourceNodeKind.text) {
          final data = node.text ?? '';
          final starts = <int>[];
          forEachCodePoint(data, (codePoint, offset) {
            if (!isCanonicalCodePoint(codePoint)) return;
            hash.codePoint(codePoint);
            starts.add(offset);
          });
          if (starts.isEmpty) continue;
          entries.add(
            CanonicalEntry(
              nodeIndex: node.index,
              start: length,
              length: starts.length,
              utf16Length: data.length,
              canonicalToUtf16: Uint32List.fromList(starts),
            ),
          );
          length += starts.length;
        } else if (node.kind == SourceNodeKind.element) {
          if (node.index != rootIndex && _isExcluded(node)) continue;
          for (var k = node.children.length - 1; k >= 0; k--) {
            stack.add(node.children[k]);
          }
        }
      }
    }
    return CanonicalIndex._(
      version: canonicalTextVersion,
      entries: entries,
      length: length,
      signature: 'fnv1a64:${hash.hex()}',
    );
  }

  final int version;
  final List<CanonicalEntry> entries;

  /// Canonical length of the whole section.
  final int length;

  /// Opaque `fnv1a64:<16 hex>` token over the canonical text.
  final String signature;

  Map<String, Object?> toJson() {
    ReaderWorkGuard.check(ReaderWork.jsonSerialization);
    return {
      'version': version,
      'length': length,
      'signature': signature,
      'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
    };
  }

  static bool _isExcluded(SourceNode element) =>
      element.namespaceUri == _svgNamespace ||
      element.namespaceUri == _mathNamespace ||
      _excludedElements.contains(element.localName?.toLowerCase());
}
