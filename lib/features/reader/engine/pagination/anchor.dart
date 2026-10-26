import 'dart:ui' as ui;

import 'package:shiori/features/reader/data/cfi/cfi.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/pagination/layout_identity.dart';
import 'package:shiori/features/reader/engine/pagination/page_plan.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';

/// Why an anchor was not accepted. There is no page-one, nearest-paragraph or
/// percentage fallback for any of them.
enum AnchorFailure {
  /// The CFI does not parse or resolve in this section.
  unresolved,

  /// `resolve -> export` did not reproduce the CFI.
  roundTrip,

  /// The resolved source position is not shown by any page (hidden,
  /// unsupported or outside the body).
  notLaidOut,

  /// Its glyph or image box is not inside the page content rectangle.
  notVisible,

  /// The proof ran against a different layout than expected.
  identityMismatch,

  /// A test hook forced the proof to fail.
  injected,
}

/// Result of proving an anchor against a prepared section.
final class AnchorProof {
  const AnchorProof.accepted(String this.cfi, int this.pageIndex)
    : failure = null;
  const AnchorProof.rejected(AnchorFailure this.failure, [this.cfi])
    : pageIndex = null;

  final AnchorFailure? failure;
  final String? cfi;

  /// The page that shows the anchor.
  final int? pageIndex;

  bool get ok => failure == null;
}

/// An exported, proven position.
final class VisibleAnchor {
  const VisibleAnchor({
    required this.cfi,
    required this.position,
    required this.pageIndex,
    required this.isImage,
  });

  final String cfi;
  final SourcePosition position;
  final int pageIndex;
  final bool isImage;
}

/// Test seam: returns a failure to force the proof of [cfi] to fail.
typedef AnchorProofHook = AnchorFailure? Function(
  PreparedSection section,
  String cfi,
);

const _horizontalTolerance = 1.0;
const _verticalTolerance = 0.5;

bool _isJsSpace(int unit) =>
    (unit >= 0x09 && unit <= 0x0d) ||
    unit == 0x20 ||
    unit == 0xa0 ||
    unit == 0x1680 ||
    (unit >= 0x2000 && unit <= 0x200a) ||
    unit == 0x2028 ||
    unit == 0x2029 ||
    unit == 0x202f ||
    unit == 0x205f ||
    unit == 0x3000 ||
    unit == 0xfeff;

const _imageNames = {'svg', 'img', 'image', 'video'};

/// Position anchors on a [PreparedSection]: export of the visible page's
/// anchor with the reference policy, resolution of a CFI to a page, and the
/// proof (structural round trip, identity, visibility inside the foreground
/// content rectangle) that must pass before a position is accepted.
final class PageAnchors {
  const PageAnchors(this.section, {this.proofHook});

  final PreparedSection section;
  final AnchorProofHook? proofHook;

  String _cfi(SourcePosition start, {SourcePosition? end}) => Cfi.export(
    section.document,
    start,
    end: end,
    sectionBase: section.sectionBase,
  );

  /// Port of `getVisiblePageTextAnchor` (`visiblePageAnchor.ts`) plus the
  /// image-element fallback of `foliateEngine.ts:350`. The anchor is verified
  /// before it is returned; null means nothing on the page could be proven.
  VisibleAnchor? exportVisible(int pageIndex) {
    final page = section.pages[pageIndex];
    final pieces = <({int node, int start, int end})>[];
    for (final span in page.map.spans) {
      final node = section.document.node(span.nodeIndex);
      // The reference walks SHOW_TEXT, which excludes CDATA sections.
      if (node.kind != SourceNodeKind.text) continue;
      final text = node.text ?? '';
      var hasContent = false;
      for (var i = span.start; i < span.end && i < text.length; i++) {
        if (!_isJsSpace(text.codeUnitAt(i))) {
          hasContent = true;
          break;
        }
      }
      if (hasContent) {
        pieces.add((node: span.nodeIndex, start: span.start, end: span.end));
      }
    }
    var total = 0;
    for (final piece in pieces) {
      total += piece.end - piece.start;
    }
    var middle = total ~/ 2;
    for (final piece in pieces) {
      final length = piece.end - piece.start;
      if (middle < length) {
        final text = section.document.node(piece.node).text ?? '';
        var offset = piece.start + middle;
        for (var distance = 0; distance < length; distance++) {
          final next = offset + distance;
          final previous = offset - distance;
          if (next < piece.end && !_isJsSpace(text.codeUnitAt(next))) {
            offset = next;
            break;
          }
          if (previous >= piece.start &&
              !_isJsSpace(text.codeUnitAt(previous))) {
            offset = previous;
            break;
          }
        }
        final position = SourcePosition(nodeIndex: piece.node, offset: offset);
        final cfi = _cfi(position);
        final proof = prove(cfi);
        if (!proof.ok || proof.pageIndex != pageIndex) return null;
        return VisibleAnchor(
          cfi: cfi,
          position: position,
          pageIndex: pageIndex,
          isImage: false,
        );
      }
      middle -= length;
    }
    for (final node in page.map.imageNodes) {
      final position = SourcePosition(nodeIndex: node, offset: 0);
      final cfi = _cfi(position);
      final proof = prove(cfi);
      if (proof.ok && proof.pageIndex == pageIndex) {
        return VisibleAnchor(
          cfi: cfi,
          position: position,
          pageIndex: pageIndex,
          isImage: true,
        );
      }
    }
    return null;
  }

  /// Proves [cfi] against this section: it resolves, round-trips to the same
  /// CFI, belongs to [expectedIdentity] (when given) and its start is visible
  /// on exactly the page returned.
  AnchorProof prove(String cfi, {LayoutIdentity? expectedIdentity}) {
    final forced = proofHook?.call(section, cfi);
    if (forced != null) return AnchorProof.rejected(forced, cfi);
    if (expectedIdentity != null && expectedIdentity != section.identity) {
      return AnchorProof.rejected(AnchorFailure.identityMismatch, cfi);
    }
    final CfiRange range;
    try {
      range = Cfi.resolve(section.document, cfi);
    } on CfiException {
      return AnchorProof.rejected(AnchorFailure.unresolved, cfi);
    }
    if (range.start.nodeIndex < 0) {
      return AnchorProof.rejected(AnchorFailure.unresolved, cfi);
    }
    try {
      final exported = _cfi(
        range.start,
        end: range.collapsed ? null : range.end,
      );
      if (Cfi.compare(exported, cfi) != 0) {
        return AnchorProof.rejected(AnchorFailure.roundTrip, cfi);
      }
    } on CfiException {
      return AnchorProof.rejected(AnchorFailure.roundTrip, cfi);
    }
    final located = locate(range.start);
    if (located == null) {
      return AnchorProof.rejected(AnchorFailure.notLaidOut, cfi);
    }
    if (!_inside(located.rect)) {
      return AnchorProof.rejected(AnchorFailure.notVisible, cfi);
    }
    return AnchorProof.accepted(cfi, located.pageIndex);
  }

  bool _inside(ui.Rect rect) =>
      rect.left >= -_horizontalTolerance &&
      rect.right <= section.box.width + _horizontalTolerance &&
      rect.top >= -_verticalTolerance &&
      rect.bottom <= section.box.height + _verticalTolerance;

  /// Page and content-box rectangle of the first box shown for [position];
  /// null when nothing is laid out for it.
  ({int pageIndex, ui.Rect rect})? locate(SourcePosition position) {
    final document = section.document;
    if (position.nodeIndex < 0 || position.nodeIndex >= document.nodes.length) {
      return null;
    }
    final node = document.node(position.nodeIndex);
    if (node.isCharacterData) {
      return _locateText(position.nodeIndex, position.offset);
    }
    if (node.kind != SourceNodeKind.element) return null;
    final name = (node.localName ?? '').toLowerCase();
    if (_imageNames.contains(name)) {
      var target = position.nodeIndex;
      for (
        var parent = node.parentIndex;
        parent != null;
        parent = document.node(parent).parentIndex
      ) {
        if ((document.node(parent).localName ?? '').toLowerCase() == 'svg') {
          target = parent;
        }
      }
      return _locateBox(target);
    }
    final child = position.offset >= 0 && position.offset < node.children.length
        ? node.children[position.offset]
        : position.nodeIndex;
    return _locateFirstIn(child);
  }

  ({int pageIndex, ui.Rect rect})? _locateFirstIn(int root) {
    final document = section.document;
    final stack = <int>[root];
    while (stack.isNotEmpty) {
      final index = stack.removeLast();
      final node = document.node(index);
      if (node.isCharacterData && section.nodeBlock.containsKey(index)) {
        return _locateText(index, 0);
      }
      if (section.imageBlock.containsKey(index)) return _locateBox(index);
      for (var k = node.children.length - 1; k >= 0; k--) {
        stack.add(node.children[k]);
      }
    }
    return null;
  }

  ({int pageIndex, ui.Rect rect})? _locateBox(int anchorNode) {
    final blockIndex = section.imageBlock[anchorNode];
    if (blockIndex == null) return null;
    final laid = section.blocks[blockIndex];
    if (laid.linePage.isEmpty) return null;
    final pageIndex = laid.linePage.first;
    for (final fragment in section.pages[pageIndex].fragments) {
      if (fragment is BoxFragment && fragment.blockIndex == blockIndex) {
        return (
          pageIndex: pageIndex,
          rect: ui.Rect.fromLTWH(
            fragment.left,
            fragment.top,
            fragment.width,
            fragment.height,
          ),
        );
      }
    }
    return null;
  }

  ({int pageIndex, ui.Rect rect})? _locateText(int nodeIndex, int offset) {
    final blockIndex = section.nodeBlock[nodeIndex];
    if (blockIndex == null) return null;
    final laid = section.blocks[blockIndex];
    final block = laid.block;
    final built = laid.paragraph;
    if (block is! TextBlock || built == null) return null;
    var paraOffset = block.map.paraOffsetOf(nodeIndex, offset);
    if (paraOffset == null || block.text.isEmpty) return null;
    if (paraOffset >= block.text.length) paraOffset = block.text.length - 1;
    // Owning line: the last whose start is <= the offset.
    final lines = built.lines;
    var low = 0;
    var high = lines.length - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (lines[mid].start <= paraOffset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    final line = low;
    final pageIndex = laid.linePage[line];
    TextFragment? fragment;
    for (final candidate in section.pages[pageIndex].fragments) {
      if (candidate is TextFragment &&
          candidate.blockIndex == blockIndex &&
          candidate.firstLine <= line &&
          line < candidate.endLine) {
        fragment = candidate;
        break;
      }
    }
    if (fragment == null) return null;
    // The complete cluster owning the offset, not a partial glyph.
    final glyph = built.paragraph.getGlyphInfoAt(paraOffset);
    ui.Rect local;
    if (glyph != null) {
      local = glyph.graphemeClusterLayoutBounds;
    } else {
      final boxes = built.paragraph.getBoxesForRange(
        paraOffset,
        paraOffset + 1,
      );
      if (boxes.isEmpty) {
        local = ui.Rect.fromLTWH(
          lines[line].left,
          lines[line].top,
          lines[line].width,
          lines[line].height,
        );
      } else {
        local = boxes.first.toRect();
      }
    }
    return (
      pageIndex: pageIndex,
      rect: local.shift(ui.Offset(laid.x, fragment.top - fragment.sliceTop)),
    );
  }
}

/// Holds the accepted position of a reading session. The accepted CFI only
/// changes after a proof succeeds; a failed proof (including after a reflow)
/// keeps the previous CFI and reports why.
final class AnchorKeeper {
  AnchorKeeper({this.proofHook});

  final AnchorProofHook? proofHook;
  String? _accepted;

  /// The accepted CFI (with its package base), if any.
  String? get acceptedCfi => _accepted;

  /// Proves [cfi] and accepts it on success.
  AnchorProof accept(PreparedSection section, String cfi) {
    final proof = PageAnchors(
      section,
      proofHook: proofHook,
    ).prove(cfi, expectedIdentity: section.identity);
    if (proof.ok) _accepted = cfi;
    return proof;
  }

  /// Exports and proves the anchor of page [pageIndex], then accepts it.
  VisibleAnchor? acceptPage(PreparedSection section, int pageIndex) {
    final anchors = PageAnchors(section, proofHook: proofHook);
    final anchor = anchors.exportVisible(pageIndex);
    if (anchor == null) return null;
    _accepted = anchor.cfi;
    return anchor;
  }

  /// After a settings or viewport change: proves the accepted CFI on the
  /// newly prepared [section]. The accepted CFI is never replaced here.
  AnchorProof reflow(PreparedSection section) {
    final cfi = _accepted;
    if (cfi == null) {
      return const AnchorProof.rejected(AnchorFailure.unresolved);
    }
    return PageAnchors(
      section,
      proofHook: proofHook,
    ).prove(cfi, expectedIdentity: section.identity);
  }
}
