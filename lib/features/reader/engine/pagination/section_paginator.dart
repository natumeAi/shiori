import 'package:shiori/features/reader/data/source/source_position.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/layout/paragraph_map.dart';
import 'package:shiori/features/reader/engine/pagination/page_plan.dart';

const _epsilon = 0.01;

/// Packs laid-out blocks into pages: whole lines, block gaps and image boxes
/// are placed top to bottom; a paragraph splits between lines with orphan and
/// widow control (two lines), as browsers do. Paragraphs are never laid out
/// again; slices are painted clipped.
final class SectionPaginator {
  SectionPaginator({
    required this.sectionIndex,
    required this.layoutKey,
    required this.pageHeight,
    this.onPage,
  });

  final int sectionIndex;
  final String layoutKey;
  final double pageHeight;

  /// Called when a page is finished.
  final void Function(ReaderPage page)? onPage;

  final List<ReaderPage> pages = [];
  final List<LaidOutBlock> _blocks = [];
  List<PageFragment> _fragments = [];
  double _y = 0;

  bool get _pageEmpty => _fragments.isEmpty;

  /// Adds the next block in reading order.
  void add(LaidOutBlock laid) {
    _blocks.add(laid);
    final block = laid.block;
    if (block.breakBefore && !_pageEmpty) _closePage();
    switch (block) {
      case TextBlock():
        _addText(laid);
      case ImageBlock() || UnsupportedBlock() || RuleBlock():
        _addBox(laid);
    }
  }

  /// Finishes the last page. A section without content still has one page.
  void finish() {
    if (!_pageEmpty || pages.isEmpty) _closePage();
  }

  double _gap(LayoutBlock block) => _pageEmpty ? 0 : block.gapBefore;

  void _addBox(LaidOutBlock laid) {
    final gap = _gap(laid.block);
    if (!_pageEmpty && _y + gap + laid.height > pageHeight + _epsilon) {
      _closePage();
    }
    final top = _y + _gap(laid.block);
    _fragments.add(
      BoxFragment(
        blockIndex: laid.index,
        top: top,
        height: laid.height,
        left: laid.x,
        width: laid.width,
      ),
    );
    laid.linePage.add(pages.length);
    _y = top + laid.height;
  }

  void _addText(LaidOutBlock laid) {
    final lines = laid.paragraph!.lines;
    final total = lines.length;
    var start = 0;
    while (start < total) {
      final gap = _gap(laid.block);
      final available = pageHeight - _y - gap;
      var fit = 0;
      while (start + fit < total &&
          lines[start + fit].bottom - lines[start].top <=
              available + _epsilon) {
        fit++;
      }
      final remaining = total - start;
      if (fit < remaining) {
        // Widows: leave at least two lines for the next page.
        if (remaining - fit < 2) fit = remaining - 2;
        if (fit < 0) fit = 0;
        // Orphans: do not strand a single first line at the page bottom.
        if (start == 0 && fit < 2 && !_pageEmpty && remaining >= 2) fit = 0;
        if (fit == 0) {
          if (!_pageEmpty) {
            _closePage();
            continue;
          }
          fit = 1;
        }
      }
      final end = start + fit;
      final top = _y + gap;
      final height = lines[end - 1].bottom - lines[start].top;
      _fragments.add(
        TextFragment(
          blockIndex: laid.index,
          top: top,
          height: height,
          firstLine: start,
          endLine: end,
          sliceTop: lines[start].top,
        ),
      );
      for (var line = start; line < end; line++) {
        laid.linePage.add(pages.length);
      }
      _y = top + height;
      start = end;
      if (start < total) _closePage();
    }
  }

  void _closePage() {
    final index = pages.length;
    final fragments = _fragments;
    _fragments = [];
    _y = 0;
    final spans = <SourceSpan>[];
    final images = <int>[];
    for (final fragment in fragments) {
      final laid = _blocks[fragment.blockIndex];
      final block = laid.block;
      if (fragment is TextFragment && block is TextBlock) {
        final lines = laid.paragraph!.lines;
        spans.addAll(
          block.map.sourceSpans(
            lines[fragment.firstLine].start,
            lines[fragment.endLine - 1].end,
          ),
        );
      } else if (block is ImageBlock) {
        images.add(block.anchorNodeIndex);
      }
    }
    final merged = <SourceSpan>[];
    for (final span in spans) {
      if (merged.isNotEmpty) {
        final last = merged.last;
        if (last.nodeIndex == span.nodeIndex && last.end >= span.start) {
          merged[merged.length - 1] = SourceSpan(
            span.nodeIndex,
            last.start,
            span.end > last.end ? span.end : last.end,
          );
          continue;
        }
      }
      merged.add(span);
    }
    final page = ReaderPage(
      index: index,
      fragments: List.unmodifiable(fragments),
      map: PageMapEntry(
        sectionIndex: sectionIndex,
        pageIndex: index,
        layoutKey: layoutKey,
        spans: List.unmodifiable(merged),
        imageNodes: List.unmodifiable(images),
        first: merged.isEmpty
            ? null
            : SourcePosition(
                nodeIndex: merged.first.nodeIndex,
                offset: merged.first.start,
              ),
        last: merged.isEmpty
            ? null
            : SourcePosition(
                nodeIndex: merged.last.nodeIndex,
                offset: merged.last.end,
              ),
      ),
    );
    pages.add(page);
    onPage?.call(page);
  }
}
