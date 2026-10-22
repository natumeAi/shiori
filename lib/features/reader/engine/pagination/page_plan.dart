import 'package:shiori/features/reader/data/canonical/canonical_text.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/layout/paragraph_factory.dart';
import 'package:shiori/features/reader/engine/layout/paragraph_map.dart';
import 'package:shiori/features/reader/engine/layout/svg_picture.dart';

/// A laid-out block: the model block plus its engine geometry.
final class LaidOutBlock {
  LaidOutBlock({
    required this.block,
    required this.x,
    required this.width,
    this.paragraph,
    this.height = 0,
    this.vector,
    this.intrinsicWidth = 0,
    this.intrinsicHeight = 0,
  });

  final LayoutBlock block;

  /// Left edge and width inside the content box, CSS px.
  final double x;
  final double width;

  /// Text blocks only.
  final BuiltParagraph? paragraph;

  /// Image, marker and rule blocks only.
  final double height;
  final VectorSvg? vector;
  final double intrinsicWidth;
  final double intrinsicHeight;

  /// Page index of every line (text) or the single box (others), filled by
  /// the paginator.
  final List<int> linePage = [];

  int get index => block.index;

  void dispose() {
    paragraph?.dispose();
    vector?.dispose();
  }
}

/// A piece of a page, in content-box coordinates.
sealed class PageFragment {
  const PageFragment({
    required this.blockIndex,
    required this.top,
    required this.height,
  });

  final int blockIndex;
  final double top;
  final double height;
}

/// Lines `[firstLine, endLine)` of a paragraph, painted clipped.
final class TextFragment extends PageFragment {
  const TextFragment({
    required super.blockIndex,
    required super.top,
    required super.height,
    required this.firstLine,
    required this.endLine,
    required this.sliceTop,
  });

  final int firstLine;
  final int endLine;

  /// Paragraph y of the first line's top.
  final double sliceTop;
}

/// An image, marker or rule box.
final class BoxFragment extends PageFragment {
  const BoxFragment({
    required super.blockIndex,
    required super.top,
    required super.height,
    required this.left,
    required this.width,
  });

  final double left;
  final double width;
}

/// Source facts of one page.
final class PageMapEntry {
  const PageMapEntry({
    required this.sectionIndex,
    required this.pageIndex,
    required this.layoutKey,
    required this.spans,
    required this.imageNodes,
    required this.first,
    required this.last,
  });

  final int sectionIndex;
  final int pageIndex;
  final String layoutKey;

  /// Source character-data intervals shown on the page, in reading order.
  /// Every interval consists of complete lines, so each cluster in it lies
  /// inside the page content rectangle.
  final List<SourceSpan> spans;

  /// Anchor node indices (`img` or outer `svg`) of image boxes on the page.
  final List<int> imageNodes;

  /// First and last source position of the page, if it has any.
  final SourcePosition? first;
  final SourcePosition? last;

  /// Page identity: layout key plus page index.
  String get identity => '$layoutKey#$pageIndex';

  /// Candidate canonical intervals `[start, end)` (normalization v1) of the
  /// text on this page. These are geometry facts about what the page can
  /// show, not reading observations.
  List<(int, int)> canonicalIntervals(CanonicalIndex index) {
    final entries = <int, CanonicalEntry>{
      for (final entry in index.entries) entry.nodeIndex: entry,
    };
    final result = <(int, int)>[];
    for (final span in spans) {
      final entry = entries[span.nodeIndex];
      if (entry == null) continue;
      final starts = entry.canonicalToUtf16;
      // First canonical char whose UTF-16 start >= span.start.
      var low = 0;
      var high = starts.length;
      while (low < high) {
        final mid = (low + high) >> 1;
        if (starts[mid] < span.start) {
          low = mid + 1;
        } else {
          high = mid;
        }
      }
      final from = low;
      low = from;
      high = starts.length;
      while (low < high) {
        final mid = (low + high) >> 1;
        if (starts[mid] < span.end) {
          low = mid + 1;
        } else {
          high = mid;
        }
      }
      if (low > from) {
        final start = entry.start + from;
        final end = entry.start + low;
        if (result.isNotEmpty && result.last.$2 == start) {
          result[result.length - 1] = (result.last.$1, end);
        } else {
          result.add((start, end));
        }
      }
    }
    return result;
  }
}

/// One finished page.
final class ReaderPage {
  const ReaderPage({
    required this.index,
    required this.fragments,
    required this.map,
  });

  final int index;
  final List<PageFragment> fragments;
  final PageMapEntry map;
}
