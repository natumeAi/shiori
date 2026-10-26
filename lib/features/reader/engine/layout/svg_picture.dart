import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart' show SvgStringLoader, vg;
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';

/// A vector SVG compiled to a recorded picture during preparation.
final class VectorSvg {
  VectorSvg(this.picture, this.width, this.height);

  final ui.Picture picture;
  final double width;
  final double height;

  void dispose() => picture.dispose();
}

/// Compiles [markup] with `flutter_svg`/`vector_graphics`. Returns null when
/// the document cannot be compiled; the caller then surfaces the SVG as
/// unsupported instead of dropping it. Text, `foreignObject`, filters and
/// external images are not painted by this renderer: the block builder lists
/// them as partial features before this is called.
Future<VectorSvg?> loadVectorSvg(String markup) async {
  ReaderWorkGuard.check(ReaderWork.imageDecode);
  try {
    final info = await vg.loadPicture(SvgStringLoader(markup), null);
    if (info.size.width <= 0 || info.size.height <= 0) {
      info.picture.dispose();
      return null;
    }
    return VectorSvg(info.picture, info.size.width, info.size.height);
  } on Object {
    return null;
  }
}
