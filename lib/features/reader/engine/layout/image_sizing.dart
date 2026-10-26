import 'dart:math' as math;

import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';

/// A box size in CSS px.
typedef BoxSize = ({double width, double height});

double? _attrLength(
  String? value,
  double available, {
  bool allowPercent = true,
}) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  if (text.endsWith('%')) {
    if (!allowPercent) return null;
    final percent = double.tryParse(text.substring(0, text.length - 1));
    return percent == null ? null : available * percent / 100;
  }
  final number = double.tryParse(
    text.endsWith('px') ? text.substring(0, text.length - 2) : text,
  );
  return number != null && number > 0 ? number : null;
}

/// Size of an image block's box, contained in the available width and the
/// page content height (the reference caps `max-height` at the content
/// height and `max-width` at 100%, `object-fit: contain`).
///
/// [intrinsic] is the raster's pixel size or the SVG's view-box size. An SVG
/// with a percentage width fills that share of the line, upscaling if
/// needed; a raster never upscales unless its own CSS or attributes ask.
BoxSize resolveImageBox(
  ImageBlock block,
  BoxSize intrinsic, {
  required double contentWidth,
  required double contentHeight,
}) {
  final available = math.max(
    1.0,
    contentWidth - block.leftInset - block.rightInset,
  );
  final style = block.style;
  double? cssLength(StyleLength length, double reference) =>
      length.kind == StyleLengthKind.auto ? null : length.resolve(reference);
  var width =
      cssLength(style.width, available) ??
      _attrLength(block.attrWidth, available);
  var height =
      (style.height.kind == StyleLengthKind.percent
          ? null
          : cssLength(style.height, contentHeight)) ??
      _attrLength(block.attrHeight, contentHeight, allowPercent: false);
  final iw = intrinsic.width > 0 ? intrinsic.width : 1.0;
  final ih = intrinsic.height > 0 ? intrinsic.height : 1.0;
  if (width == null && height == null) {
    width = iw;
    height = ih;
  } else if (width == null) {
    width = height! * iw / ih;
  } else {
    height ??= width * ih / iw;
  }
  final maxWidth = math.min(
    available,
    style.maxWidth?.resolve(available) ?? double.infinity,
  );
  final maxHeight = math.min(
    contentHeight,
    style.maxHeight?.resolve(contentHeight) ?? double.infinity,
  );
  final scale = math.min(1.0, math.min(maxWidth / width, maxHeight / height));
  return (
    width: math.max(1.0, width * scale),
    height: math.max(1.0, height * scale),
  );
}
