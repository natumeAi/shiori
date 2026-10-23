import 'dart:ui' as ui;

import 'package:shiori/features/reader/engine/layout/image_cache.dart';

import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/pagination/page_plan.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';

/// Colors the engine itself needs for generated page furniture. Document
/// content takes its colors from the computed styles.
final class PagePaintTheme {
  const PagePaintTheme({
    required this.background,
    this.marker = 0xFFB3261E,
    this.imagePlaceholder = 0x33808080,
  });

  final int background;

  /// Unsupported-content markers and the partial-SVG badge.
  final int marker;

  /// Fill of a raster whose pixels are not ready.
  final int imagePlaceholder;
}

/// Paints prepared pages. Everything here only replays prepared geometry,
/// decoded images and recorded pictures: no parsing, layout or decoding.
abstract final class PagePainter {
  /// Paints page [pageIndex] with the content box origin at the canvas
  /// origin.
  static void paintContent(
    ui.Canvas canvas,
    PreparedSection section,
    int pageIndex,
    PagePaintTheme theme, {
    ImageLease? Function(int)? imageOf,
  }) {
    final width = section.box.width;
    for (final fragment in section.pages[pageIndex].fragments) {
      final laid = section.blocks[fragment.blockIndex];
      final block = laid.block;
      switch (fragment) {
        case TextFragment():
          if (block is! TextBlock) continue;
          for (final background in block.backgrounds) {
            canvas.drawRect(
              ui.Rect.fromLTRB(
                background.left,
                fragment.top,
                width - background.right,
                fragment.top + fragment.height,
              ),
              ui.Paint()..color = ui.Color(background.color),
            );
          }
          canvas
            ..save()
            ..clipRect(
              ui.Rect.fromLTWH(
                laid.x - 4,
                fragment.top,
                laid.width + 8,
                fragment.height,
              ),
            )
            ..translate(laid.x, fragment.top - fragment.sliceTop)
            ..drawParagraph(laid.paragraph!.paragraph, ui.Offset.zero)
            ..restore();
        case BoxFragment():
          _paintBox(canvas, section, laid, fragment, theme, imageOf);
      }
    }
  }

  static void _paintBox(
    ui.Canvas canvas,
    PreparedSection section,
    LaidOutBlock laid,
    BoxFragment fragment,
    PagePaintTheme theme,
    ImageLease? Function(int)? imageOf,
  ) {
    final rect = ui.Rect.fromLTWH(
      fragment.left,
      fragment.top,
      fragment.width,
      fragment.height,
    );
    final stroke = ui.Paint()
      ..color = ui.Color(theme.marker)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1;
    switch (laid.block) {
      case RuleBlock(:final color):
        canvas.drawRect(rect, ui.Paint()..color = ui.Color(color));
      case UnsupportedBlock():
        canvas
          ..drawRect(rect, stroke)
          ..drawLine(rect.topLeft, rect.bottomRight, stroke)
          ..drawLine(rect.topRight, rect.bottomLeft, stroke);
      case ImageBlock(:final partialFeatures):
        final vector = laid.vector;
        if (vector != null) {
          canvas
            ..save()
            ..clipRect(rect)
            ..translate(rect.left, rect.top)
            ..scale(rect.width / vector.width, rect.height / vector.height)
            ..drawPicture(vector.picture)
            ..restore();
        } else {
          final lease = imageOf == null
              ? section.leaseOf(laid.index)
              : imageOf(laid.index);
          if (lease == null) {
            canvas.drawRect(
              rect,
              ui.Paint()..color = ui.Color(theme.imagePlaceholder),
            );
          } else {
            canvas.drawImageRect(
              lease.image,
              ui.Rect.fromLTWH(
                0,
                0,
                lease.image.width.toDouble(),
                lease.image.height.toDouble(),
              ),
              rect,
              ui.Paint()..filterQuality = ui.FilterQuality.medium,
            );
          }
        }
        if (partialFeatures.isNotEmpty) {
          canvas.drawRect(
            ui.Rect.fromLTWH(rect.right - 12, rect.top, 12, 12),
            ui.Paint()..color = ui.Color(theme.marker),
          );
        }
      case TextBlock():
        break;
    }
  }

  /// Records page [pageIndex] as a picture the size of the viewport: theme
  /// background, then the content translated to the content box.
  static ui.Picture record(
    PreparedSection section,
    int pageIndex,
    PagePaintTheme theme, {
    ImageLease? Function(int)? imageOf,
  }) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas
      ..drawRect(
        ui.Rect.fromLTWH(
          0,
          0,
          section.box.viewportWidth,
          section.box.viewportHeight,
        ),
        ui.Paint()..color = ui.Color(theme.background),
      )
      ..save()
      ..translate(section.box.left, section.box.top);
    paintContent(canvas, section, pageIndex, theme, imageOf: imageOf);
    canvas.restore();
    return recorder.endRecording();
  }
}
