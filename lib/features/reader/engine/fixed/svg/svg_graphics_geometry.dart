part of 'svg_graphics.dart';

/// Exact authored AA: rasterize once, then copy native pixels without filtering.
/// The caller owns [picture]/[image]; only this helper's raster and tiles are
/// disposed here. A supplied ledger may be a prepaid SVG subdivision.
abstract final class AuthoredEvidenceRaster {
  static const tileSide = 512;
  static const maxTilePixels = tileSide * tileSide;
  static int tilePixels(int width, int height) =>
      (width < tileSide ? width : tileSide) *
      (height < tileSide ? height : tileSide) *
      2;

  /// One native authored raster plus a tile image and its RGBA readback.
  static int scratchPixels(int width, int height) =>
      width * height + tilePixels(width, height);

  static Future<GeometryAlphaFootprint> rasterize(
    ui.Picture picture, {
    required int width,
    required int height,
    required SceneResourceBudget budget,
    required void Function(int bytes) reserve,
    void Function()? checkCancellation,
  }) async {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    checkCancellation?.call();
    // Checked multiplication and whole-raster admission precede native work.
    final rasterLease = budget.reserveLayer(width, height);
    ui.Image? image;
    try {
      // Admit the complete concurrent peak before the first native allocation.
      budget
          .reserveLayer(
            math.min(tileSide, width),
            math.min(tileSide, height),
            buffers: 2,
          )
          .release();
      image = await picture.toImage(width, height);
      checkCancellation?.call();
      return await readImage(
        image,
        budget: budget,
        reserve: reserve,
        checkCancellation: checkCancellation,
      );
    } finally {
      image?.dispose();
      rasterLease.release();
    }
  }

  /// The borrowed whole image must already have a live raster/image lease.
  static Future<GeometryAlphaFootprint> readImage(
    ui.Image image, {
    required SceneResourceBudget budget,
    required void Function(int bytes) reserve,
    void Function()? checkCancellation,
  }) => GeometryAlphaFootprint.fromTiles(
    width: image.width,
    height: image.height,
    origin: GeometryPoint(0, 0),
    reserve: reserve,
    visitTiles: (accept) => visitTiles(
      image,
      budget: budget,
      accept: accept,
      checkCancellation: checkCancellation,
    ),
  );

  /// Proves opacity from every decoded alpha sample, never from a file type.
  static Future<bool> isOpaque(
    ui.Image image, {
    required SceneResourceBudget budget,
    void Function()? checkCancellation,
  }) async {
    var opaque = true;
    await visitTiles(
      image,
      budget: budget,
      checkCancellation: checkCancellation,
      accept: (x, y, width, height, rgba) {
        for (var i = 3; i < rgba.length; i += 4) {
          if (rgba[i] != 255) opaque = false;
        }
      },
    );
    return opaque;
  }

  static Future<void> visitTiles(
    ui.Image image, {
    required SceneResourceBudget budget,
    required void Function(int x, int y, int width, int height, List<int> rgba)
    accept,
    void Function()? checkCancellation,
  }) async {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    for (var y = 0; y < image.height; y += tileSide) {
      final h = math.min(tileSide, image.height - y);
      for (var x = 0; x < image.width; x += tileSide) {
        checkCancellation?.call();
        final w = math.min(tileSide, image.width - x);
        final lease = budget.reserveLayer(w, h, buffers: 2);
        ui.Picture? picture;
        ui.Image? tile;
        try {
          final recorder = ui.PictureRecorder();
          ui.Canvas(recorder).drawImageRect(
            image,
            ui.Rect.fromLTWH(
              x.toDouble(),
              y.toDouble(),
              w.toDouble(),
              h.toDouble(),
            ),
            ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
            ui.Paint()
              ..filterQuality = ui.FilterQuality.none
              ..isAntiAlias = false
              ..blendMode = ui.BlendMode.src,
          );
          picture = recorder.endRecording();
          tile = await picture.toImage(w, h);
          checkCancellation?.call();
          final bytes = await tile.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          checkCancellation?.call();
          accept(x, y, w, h, bytes!.buffer.asUint8List());
        } finally {
          tile?.dispose();
          picture?.dispose();
          lease.release();
        }
      }
    }
  }
}

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

List<GeometryPaintRole> _shapePaintRoles(Map<String, String> paint) {
  final roles = [
    if ((paint['fill'] ?? 'black') != 'none') GeometryPaintRole.fill,
    if ((paint['stroke'] ?? 'none') != 'none') GeometryPaintRole.stroke,
  ];
  return roles.isEmpty ? [GeometryPaintRole.combined] : roles;
}

extension _SvgPaintEvidence on SvgGraphicsPlan {
  Future<List<GeometryPaint>> _paintEvidence(
    _SvgInstance instance,
    SceneResourceBudget budget,
    SceneResourceBudget evidenceBudget,
    SvgGraphicsImages images,
    void Function() checkCancellation,
    ui.Rect evidenceBounds,
  ) async {
    final roles = _shapes.contains(instance.node.localName)
        ? _shapePaintRoles(instance.paint)
        : [GeometryPaintRole.combined];
    final result = <GeometryPaint>[];
    for (final role in roles) {
      checkCancellation();
      final pictures = <ui.Picture>[], leases = <SceneResourceLease>[];
      try {
        var leaf = instance;
        if (roles.length > 1) {
          // Replay the same compiler, pattern and dash construction as paint.
          // Never estimate stroke support from the path's centreline/bounds.
          final overrides = {
            if (role == GeometryPaintRole.fill) 'stroke': 'none',
            if (role == GeometryPaintRole.stroke) 'fill': 'none',
          };
          leaf =
              _SvgInstance(
                  instance.node,
                  {...instance.attributes, ...overrides},
                  {...instance.paint, ...overrides},
                  instance.transform,
                  instance.viewport,
                  instance.instances,
                  instance.clips,
                  instance.opacity,
                  instance.groups,
                )
                ..bounds = instance.bounds
                ..path = instance.path;
          leaf.picture = await _compile(
            leaf,
            budget,
            leases,
            pictures,
            images.forEvidence,
          );
        }
        final alpha = await _coverage(
          leaf,
          size,
          evidenceBudget,
          checkCancellation,
          evidenceBounds,
        );
        checkCancellation();
        result.add(
          GeometryPaint(
            nodeIndex: instance.node.index,
            paintOrdinal: instance.ordinal,
            role: role,
            region: _region(instance.bounds!, instance.transform),
            kind: GeometryPaintKind.image,
            effectiveOpacity:
                const {
                  'hidden',
                  'collapse',
                }.contains(instance.paint['visibility'])
                ? 0
                : instance.opacity,
            exactCoverage: true,
            alphaFootprint: alpha,
            clipIds: instance.clips.map((c) => c.id).toList(),
            groupIds: instance.groups.map((g) => g.id).toList(),
          ),
        );
      } finally {
        for (final picture in pictures) {
          picture.dispose();
        }
        for (final lease in leases.reversed) {
          lease.release();
        }
      }
    }
    return result;
  }
}

Future<GeometryAlphaFootprint> _coverage(
  _SvgInstance i,
  AuthoredPageSize size, [
  SceneResourceBudget? evidenceBudget,
  void Function()? checkCancellation,
  ui.Rect? evidenceBounds,
]) async {
  final extent =
      evidenceBounds ??
      ui.Rect.fromLTWH(
        0,
        0,
        size.width.ceilToDouble(),
        size.height.ceilToDouble(),
      );
  final uniform = _uniformSvgRectangle(i, extent);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final raster = uniform == null
      ? extent
      : ui.Rect.fromLTWH(uniform.left, uniform.top, 1, 1);
  canvas.translate(-raster.left, -raster.top);
  _paintLeaf(canvas, i, evidence: true);
  final picture = recorder.endRecording();
  try {
    final footprint = await AuthoredEvidenceRaster.rasterize(
      picture,
      width: raster.width.toInt(),
      height: raster.height.toInt(),
      budget: evidenceBudget ?? SceneResourceBudget(),
      // Retained payload is prepaid by SvgGraphicsPlan.reservation().
      reserve: (_) {},
      checkCancellation: checkCancellation,
    );
    if (uniform != null) {
      return GeometryAlphaFootprint.uniform(
        width: math.max(1, uniform.width.toInt()),
        height: math.max(1, uniform.height.toInt()),
        pixelSize: 1,
        origin: GeometryPoint(uniform.left, uniform.top),
        alpha: uniform.width == 0 || uniform.height == 0
            ? 0
            : footprint.alpha[0],
      );
    }
    return footprint.placed(_translate(raster.left, raster.top));
  } finally {
    picture.dispose();
  }
}

GeometryRegion? _uniformSvgRectangle(_SvgInstance i, ui.Rect evidenceBounds) {
  if (i.node.localName != 'rect' ||
      (i.paint['stroke'] ?? 'none') != 'none' ||
      (i.paint['fill'] ?? '').startsWith('url(') ||
      _number(i.attributes['rx'], i.node.index) != 0 ||
      _number(i.attributes['ry'], i.node.index) != 0) {
    return null;
  }
  return uniformPixelRectangle([
    _region(i.bounds!, i.transform),
    for (final clip in i.clips) clip.region,
    _region(evidenceBounds, const AffineTransform.identity()),
  ]);
}

ui.Picture _imagePicture(_SvgInstance i, SvgGraphicsImages images) {
  final path = i.attributes['href'] ?? i.attributes['xlink:href'];
  final raster = images.rasters[path], vector = images.vectors[path];
  if (raster == null &&
      (vector?.picture == null || !vector!.capability.isComplete)) {
    throw _SvgFailure(i.node.index, 'missing-admitted-svg-image');
  }
  final intrinsic = images.intrinsicSizes[path];
  final w = intrinsic?.width ?? raster?.width.toDouble() ?? vector!.size.width;
  final h =
      intrinsic?.height ?? raster?.height.toDouble() ?? vector!.size.height;
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
    canvas.drawImageRect(
      raster,
      ui.Rect.fromLTWH(0, 0, raster.width.toDouble(), raster.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, w, h),
      ui.Paint(),
    );
  } else {
    canvas.drawPicture(vector!.picture!);
  }
  return recorder.endRecording();
}
