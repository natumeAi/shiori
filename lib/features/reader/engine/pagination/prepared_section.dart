import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/engine/layout/image_cache.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/pagination/content_box.dart';
import 'package:shiori/features/reader/engine/pagination/layout_identity.dart';
import 'package:shiori/features/reader/engine/pagination/page_plan.dart';

/// Layout cost of one paragraph, for the diagnostic record.
final class ParagraphCost {
  const ParagraphCost({
    required this.codeUnits,
    required this.lines,
    required this.layoutMicros,
  });

  final int codeUnits;
  final int lines;
  final int layoutMicros;
}

/// A section that has been laid out and paginated at one layout identity.
/// Immutable apart from lazily leased images; everything geometric is ready
/// before the first frame that shows it.
final class PreparedSection {
  PreparedSection({
    required this.sectionIndex,
    required this.identity,
    required this.box,
    required this.document,
    required this.archive,
    required this.sectionBase,
    required this.model,
    required this.blocks,
    required this.pages,
    required this.unsupported,
    required this.fontChains,
    required this.paragraphCosts,
  }) {
    for (final laid in blocks) {
      switch (laid.block) {
        case TextBlock(:final map):
          for (final entry in map.entries) {
            if (entry.hasSource) {
              nodeBlock.putIfAbsent(entry.nodeIndex, () => laid.index);
            }
          }
        case ImageBlock(:final anchorNodeIndex):
          imageBlock[anchorNodeIndex] = laid.index;
        case UnsupportedBlock(:final nodeIndex):
          imageBlock[nodeIndex] = laid.index;
        case RuleBlock(:final nodeIndex):
          imageBlock[nodeIndex] = laid.index;
      }
    }
  }

  final int sectionIndex;
  final LayoutIdentity identity;
  final ContentBox box;
  final SourceDocument document;
  final EpubArchive archive;

  /// Package CFI of the spine item (`epubcfi(/6/4[id])`), from the OPF.
  final String? sectionBase;
  final LayoutDocument model;
  final List<LaidOutBlock> blocks;
  final List<ReaderPage> pages;

  /// Unsupported or partially supported content, including images that
  /// failed to decode during preparation.
  final List<UnsupportedItem> unsupported;

  /// Font chains requested by the section's paragraphs, `css -> mapped`.
  final List<String> fontChains;
  final List<ParagraphCost> paragraphCosts;

  /// Source Text/CDATA node index to block index.
  final Map<int, int> nodeBlock = {};

  /// Image/marker/rule anchor node index to block index.
  final Map<int, int> imageBlock = {};
  final Map<int, ImageLease> _leases = {};
  bool _disposed = false;

  int get pageCount => pages.length;

  int get totalLayoutMicros =>
      paragraphCosts.fold(0, (sum, cost) => sum + cost.layoutMicros);

  /// Leases decoded rasters for the image boxes of page [pageIndex] at the
  /// device pixel size. Call during preparation, never from paint.
  Future<void> ensureImages(int pageIndex, ReaderImageCache cache) async {
    for (final fragment in pages[pageIndex].fragments) {
      if (fragment is! BoxFragment) continue;
      final laid = blocks[fragment.blockIndex];
      final block = laid.block;
      if (block is! ImageBlock || block.resourcePath == null) continue;
      if (_leases.containsKey(laid.index)) continue;
      final bytes = archive.bytes(block.resourcePath!);
      if (bytes == null) continue;
      final dpr = identity.devicePixelRatio;
      final lease = await cache.lease(
        '${identity.contentId}:${block.resourcePath}',
        bytes,
        targetWidth: (fragment.width * dpr).ceil().clamp(1, 8192),
        targetHeight: (fragment.height * dpr).ceil().clamp(1, 8192),
      );
      if (lease == null) continue;
      if (_disposed || _leases.containsKey(laid.index)) {
        lease.release();
      } else {
        _leases[laid.index] = lease;
      }
    }
  }

  /// The decoded raster leased for block [blockIndex], if prepared.
  ImageLease? leaseOf(int blockIndex) => _leases[blockIndex];

  void releaseImages() {
    for (final lease in _leases.values) {
      lease.release();
    }
    _leases.clear();
  }

  void dispose() {
    _disposed = true;
    releaseImages();
    for (final laid in blocks) {
      laid.dispose();
    }
  }
}
