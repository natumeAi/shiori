part of 'svg_graphics.dart';

SourceFragment _fragment(_SvgInstance i, SourcePageId page) {
  final r = i.bounds!;
  return SourceFragment(
    page: page,
    nodeIndex: i.node.index,
    kind: SourceFragmentKind.element,
    textRange: null,
    clusters: const [],
    elementAnchor: SourceElementAnchor(
      nodeIndex: i.node.index,
      elementId: i.node.id == '' ? null : i.node.id,
    ),
    elementQuad: [
      for (final p in [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft])
        GeometryPoint(p.dx, p.dy),
    ],
    sourceToUnit: i.transform,
    clipIds: i.clips.map((c) => c.id).toList(),
    maskIds: const [],
    paintOrdinal: i.ordinal,
    effectiveOpacity:
        const {'hidden', 'collapse'}.contains(i.paint['visibility'])
        ? 0
        : i.opacity,
  );
}

Future<GeometryAlphaFootprint> _coverage(
  _SvgInstance i,
  AuthoredPageSize size,
) async {
  final recorder = ui.PictureRecorder();
  _paintLeaf(ui.Canvas(recorder), i);
  final picture = recorder.endRecording();
  ui.Image? image;
  try {
    image = await picture.toImage(size.width.ceil(), size.height.ceil());
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer
        .asUint8List();
    return GeometryAlphaFootprint(
      width: image.width,
      height: image.height,
      pixelSize: 1,
      origin: GeometryPoint(0, 0),
      alpha: [for (var j = 3; j < bytes.length; j += 4) bytes[j]],
    );
  } finally {
    image?.dispose();
    picture.dispose();
  }
}

ui.Picture _imagePicture(_SvgInstance i, SvgGraphicsImages images) {
  final path = i.attributes['href'] ?? i.attributes['xlink:href'];
  final raster = images.rasters[path], vector = images.vectors[path];
  if (raster == null &&
      (vector?.picture == null || !vector!.capability.isComplete)) {
    throw _SvgFailure(i.node.index, 'missing-admitted-svg-image');
  }
  final w = raster?.width.toDouble() ?? vector!.size.width;
  final h = raster?.height.toDouble() ?? vector!.size.height;
  final target = i.bounds!;
  final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
  canvas.clipRect(target);
  final viewport = FixedSvgViewport.resolve(
    SvgSourceDimensions(
      nodeIndex: i.node.index,
      width: '${target.width}',
      height: '${target.height}',
      viewBox: '0 0 $w $h',
      preserveAspectRatio: i.attributes['preserveAspectRatio'],
    ),
  );
  if (viewport.transform == null) {
    recorder.endRecording().dispose();
    throw _SvgFailure(i.node.index, 'svg-image-viewport', malformed: true);
  }
  canvas.translate(target.left, target.top);
  canvas.transform(_matrix(viewport.transform!));
  if (raster != null) {
    canvas.drawImage(raster, ui.Offset.zero, ui.Paint());
  } else {
    canvas.drawPicture(vector!.picture!);
  }
  return recorder.endRecording();
}
