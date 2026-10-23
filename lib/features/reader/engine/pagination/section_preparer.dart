import 'dart:math' as math;

import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/engine/layout/block_builder.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/image_cache.dart';
import 'package:shiori/features/reader/engine/layout/image_sizing.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/layout/paragraph_factory.dart';
import 'package:shiori/features/reader/engine/layout/svg_picture.dart';
import 'package:shiori/features/reader/engine/pagination/content_box.dart';
import 'package:shiori/features/reader/engine/pagination/layout_identity.dart';
import 'package:shiori/features/reader/engine/pagination/page_plan.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/pagination/section_paginator.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/style/style_resolver.dart';

const _markerWidth = 240.0;
const _markerHeight = 32.0;

/// Inputs of one section preparation.
final class PrepareRequest {
  const PrepareRequest({
    required this.book,
    required this.sectionIndex,
    required this.document,
    required this.styled,
    required this.settings,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.contentId,
    this.devicePixelRatio = 3,
    this.generation = 0,
  });

  final EpubBook book;
  final int sectionIndex;
  final SourceDocument document;
  final StyledDocument styled;
  final ReaderSettings settings;
  final double viewportWidth;
  final double viewportHeight;

  /// Digest of the book or fixture, part of the layout identity.
  final String contentId;
  final double devicePixelRatio;
  final int generation;
}

/// Builds a [PreparedSection]: block model, fonts, paragraph layout (each
/// paragraph exactly once, at its final width), image and SVG sizing, and the
/// page packing with its page map. Work is cooperative: it checkpoints
/// between blocks and between images so the isolate stays responsive.
final class SectionPreparer {
  SectionPreparer({FontRegistry? fonts, ReaderImageCache? images})
    : fonts = fonts ?? FontRegistry(),
      images = images ?? ReaderImageCache();

  final FontRegistry fonts;
  final ReaderImageCache images;

  Future<PreparedSection> prepare(
    PrepareRequest request, {
    PreparationControl? control,
    void Function(ReaderPage page)? onPageReady,
  }) async {
    ReaderWorkGuard.check(ReaderWork.pagination);
    final checkpoint = control ?? PreparationControl();
    final box = ContentBox.fromViewport(
      request.viewportWidth,
      request.viewportHeight,
      request.settings,
    );
    final scope = request.contentId.length > 12
        ? request.contentId.substring(0, 12)
        : request.contentId;
    final aliases = await fonts.load(
      request.book.archive,
      request.styled.fontFaces,
      scope: scope,
    );
    await checkpoint.checkpoint();
    final paragraphFonts = ParagraphFonts(embedded: aliases);
    final section = request.book.sections[request.sectionIndex];
    final model = LayoutBlockBuilder(
      document: request.document,
      styled: request.styled,
      sectionHref: section.item.href,
      archive: request.book.archive,
      contentWidth: box.width,
    ).build();
    final identity = LayoutIdentity(
      contentId: request.contentId,
      sectionIndex: request.sectionIndex,
      viewportWidth: request.viewportWidth,
      viewportHeight: request.viewportHeight,
      devicePixelRatio: request.devicePixelRatio,
      settings: request.settings,
      fontSignature: (aliases.values.toList()..sort()).join(','),
      generation: request.generation,
    );
    final paginator = SectionPaginator(
      sectionIndex: request.sectionIndex,
      layoutKey: identity.key,
      pageHeight: box.height,
      onPage: onPageReady,
    );
    final laidOut = <LaidOutBlock>[];
    final extraUnsupported = <UnsupportedItem>[];
    final costs = <ParagraphCost>[];
    try {
      for (final block in model.blocks) {
        await checkpoint.checkpoint();
        final laid = await _layoutBlock(
          block,
          box,
          paragraphFonts,
          request,
          extraUnsupported,
          costs,
        );
        laidOut.add(laid);
        paginator.add(laid);
      }
      paginator.finish();
    } on Object {
      for (final laid in laidOut) {
        laid.dispose();
      }
      rethrow;
    }
    final notes = <String>{
      for (final chain in paragraphFonts.resolvedChains) ...chain.notes,
      for (final record in fonts.records)
        if (aliases.containsValue(record.alias))
          '${record.family} -> embedded ${record.archivePath}',
    };
    return PreparedSection(
      sectionIndex: request.sectionIndex,
      identity: identity,
      box: box,
      document: request.document,
      archive: request.book.archive,
      sectionBase: section.spine.cfiBase,
      model: model,
      blocks: laidOut,
      pages: paginator.pages,
      unsupported: [...model.unsupported, ...extraUnsupported],
      fontChains: notes.toList()..sort(),
      paragraphCosts: costs,
    );
  }

  Future<LaidOutBlock> _layoutBlock(
    LayoutBlock block,
    ContentBox box,
    ParagraphFonts paragraphFonts,
    PrepareRequest request,
    List<UnsupportedItem> extraUnsupported,
    List<ParagraphCost> costs,
  ) async {
    final available = math.max(
      1.0,
      box.width - block.leftInset - block.rightInset,
    );
    switch (block) {
      case TextBlock():
        final built = buildParagraph(block, available, paragraphFonts);
        costs.add(
          ParagraphCost(
            codeUnits: block.text.length,
            lines: built.lines.length,
            layoutMicros: built.layoutMicros,
          ),
        );
        return LaidOutBlock(
          block: block,
          x: block.leftInset,
          width: available,
          paragraph: built,
        );
      case UnsupportedBlock():
        return _marker(block, available);
      case RuleBlock():
        return LaidOutBlock(
          block: block,
          x: block.leftInset,
          width: available,
          height: 1,
        );
      case ImageBlock():
        return _layoutImage(block, box, available, request, extraUnsupported);
    }
  }

  LaidOutBlock _marker(UnsupportedBlock block, double available) =>
      LaidOutBlock(
        block: block,
        x: block.leftInset,
        width: math.min(available, _markerWidth),
        height: _markerHeight,
      );

  Future<LaidOutBlock> _layoutImage(
    ImageBlock block,
    ContentBox box,
    double available,
    PrepareRequest request,
    List<UnsupportedItem> extraUnsupported,
  ) async {
    double intrinsicWidth;
    double intrinsicHeight;
    VectorSvg? vector;
    if (block.kind == ImageKind.svgVector) {
      vector = await loadVectorSvg(block.svgMarkup ?? '');
      if (vector == null) {
        extraUnsupported.add(
          UnsupportedItem(
            code: 'svg-unrenderable',
            nodeIndex: block.anchorNodeIndex,
            textFlows: false,
          ),
        );
        return _marker(_asMarker(block, 'svg-unrenderable'), available);
      }
      intrinsicWidth = block.hintWidth != null && block.hintWidth! > 0
          ? block.hintWidth!
          : vector.width;
      intrinsicHeight = block.hintHeight != null && block.hintHeight! > 0
          ? block.hintHeight!
          : vector.height;
    } else {
      final path = block.resourcePath!;
      final bytes = request.book.archive.bytes(path);
      final size = bytes == null
          ? null
          : await images.intrinsicSize('${request.contentId}:$path', bytes);
      if (size == null) {
        extraUnsupported.add(
          UnsupportedItem(
            code: 'image-decode-failed',
            nodeIndex: block.anchorNodeIndex,
            textFlows: false,
          ),
        );
        return _marker(_asMarker(block, 'image-decode-failed'), available);
      }
      final useHint =
          block.kind == ImageKind.svgWrapper &&
          (block.hintWidth ?? 0) > 0 &&
          (block.hintHeight ?? 0) > 0;
      intrinsicWidth = useHint ? block.hintWidth! : size.width;
      intrinsicHeight = useHint ? block.hintHeight! : size.height;
    }
    final size = resolveImageBox(
      block,
      (width: intrinsicWidth, height: intrinsicHeight),
      contentWidth: box.width,
      contentHeight: box.height,
    );
    final x = switch (block.align) {
      BlockAlign.start => block.leftInset,
      BlockAlign.center => block.leftInset + (available - size.width) / 2,
      BlockAlign.end => block.leftInset + available - size.width,
    };
    return LaidOutBlock(
      block: block,
      x: x,
      width: size.width,
      height: size.height,
      vector: vector,
      intrinsicWidth: intrinsicWidth,
      intrinsicHeight: intrinsicHeight,
    );
  }

  UnsupportedBlock _asMarker(ImageBlock block, String code) => UnsupportedBlock(
    index: block.index,
    gapBefore: block.gapBefore,
    breakBefore: block.breakBefore,
    leftInset: block.leftInset,
    rightInset: block.rightInset,
    nodeIndex: block.anchorNodeIndex,
    code: code,
  );
}
