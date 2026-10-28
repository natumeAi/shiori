part of 'svg_graphics.dart';

extension _SvgPatternPaint on SvgGraphicsPlan {
  Future<ui.Picture> _compile(
    _SvgInstance i,
    SceneResourceBudget budget,
    List<SceneResourceLease> leases,
    List<ui.Picture> pictures,
    SvgGraphicsImages images,
  ) async {
    final targets = <String, int>{};
    for (final channel in ['fill', 'stroke']) {
      final value = i.paint[channel];
      if (value != null && value.startsWith('url(')) {
        final target = _reference(i.node.index, value);
        if (document.node(target).localName == 'pattern') {
          targets[channel] = target;
        }
      }
    }
    final dash = i.paint['stroke-dasharray'];
    final dashed =
        dash != null &&
        dash != 'none' &&
        (i.paint['stroke'] ?? 'none') != 'none' &&
        !targets.containsKey('stroke');
    final markup = _leafMarkup(
      i,
      overrides: {
        for (final key in targets.keys) key: 'none',
        if (dashed) 'stroke': 'none',
      },
    );
    final bytes = vc.encodeSvg(
      xml: markup,
      debugName: 'svg-node-${i.node.index}',
      warningsAsErrors: true,
      enableClippingOptimizer: false,
      enableMaskingOptimizer: false,
      enableOverdrawOptimizer: false,
    );
    final info = await vg.loadPicture(
      _SvgBytes(ByteData.sublistView(bytes)),
      null,
      clipViewbox: false,
    );
    pictures.add(info.picture);
    if (targets.isEmpty && !dashed) return info.picture;
    final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
    try {
      if (targets['fill'] != null) {
        await _pattern(
          canvas,
          i,
          targets['fill']!,
          budget,
          leases,
          pictures,
          images,
        );
      }
      canvas.drawPicture(info.picture);
      if (dashed) {
        final strokeMarkup = _leafMarkup(
          i,
          overrides: const {
            'fill': 'none',
            'stroke-dasharray': 'none',
            'stroke-dashoffset': '0',
          },
        );
        final strokeBytes = vc.encodeSvg(
          xml: strokeMarkup,
          debugName: 'svg-dash-${i.node.index}',
          warningsAsErrors: true,
          enableClippingOptimizer: false,
          enableMaskingOptimizer: false,
          enableOverdrawOptimizer: false,
        );
        final stroke = await vg.loadPicture(
          _SvgBytes(ByteData.sublistView(strokeBytes)),
          null,
          clipViewbox: false,
        );
        pictures.add(stroke.picture);
        final region = i.bounds!.inflate(
          _number(i.paint['stroke-width'], i.node.index, fallback: 1) *
              _number(i.paint['stroke-miterlimit'], i.node.index, fallback: 4),
        );
        canvas.saveLayer(region, ui.Paint());
        canvas.drawPicture(stroke.picture);
        canvas.saveLayer(region, ui.Paint()..blendMode = ui.BlendMode.dstIn);
        canvas.drawPath(_dashPath(i, budget, leases), _strokePaint(i));
        canvas.restore();
        canvas.restore();
      }
      if (targets['stroke'] != null) {
        await _pattern(
          canvas,
          i,
          targets['stroke']!,
          budget,
          leases,
          pictures,
          images,
          stroke: true,
        );
      }
      final picture = recorder.endRecording();
      pictures.add(picture);
      return picture;
    } on Object {
      recorder.endRecording().dispose();
      rethrow;
    }
  }

  Future<void> _pattern(
    ui.Canvas canvas,
    _SvgInstance shape,
    int index,
    SceneResourceBudget budget,
    List<SceneResourceLease> leases,
    List<ui.Picture> pictures,
    SvgGraphicsImages images, {
    bool stroke = false,
  }) async {
    var a = _attributes(index), content = index;
    final own = a;
    var inherited = index;
    while (a['href'] != null || a['xlink:href'] != null) {
      inherited = _reference(inherited, a['href'] ?? a['xlink:href']!);
      final parent = _attributes(inherited);
      a = {...parent, ...a}
        ..remove('href')
        ..remove('xlink:href');
      if (document.node(content).children.isEmpty) content = inherited;
      if (parent['href'] != null) a['href'] = parent['href']!;
      if (parent['xlink:href'] != null) a['xlink:href'] = parent['xlink:href']!;
    }
    a = {...a, ...own}
      ..remove('href')
      ..remove('xlink:href');
    final bounds = shape.bounds!;
    final units = a['patternUnits'] ?? 'objectBoundingBox';
    if (!const {'objectBoundingBox', 'userSpaceOnUse'}.contains(units)) {
      throw _SvgFailure(index, 'svg-pattern-units');
    }
    final object = units == 'objectBoundingBox';
    final x = _number(a['x'], index, basis: object ? 1 : shape.viewport.width);
    final y = _number(a['y'], index, basis: object ? 1 : shape.viewport.height);
    final width = _number(
      a['width'],
      index,
      basis: object ? 1 : shape.viewport.width,
    );
    final height = _number(
      a['height'],
      index,
      basis: object ? 1 : shape.viewport.height,
    );
    if (width < 0 || height < 0) {
      throw _SvgFailure(index, 'svg-pattern-size', malformed: true);
    }
    if (width == 0 || height == 0 || bounds.isEmpty) {
      return;
    }
    var tileToUser = _svgTransform(a['patternTransform'], index);
    if (object) {
      tileToUser = tileToUser
          .compose(_translate(bounds.left, bounds.top))
          .compose(_scale(bounds.width, bounds.height));
    }
    final inverse = tileToUser.inverse();
    if (inverse is! InvertedTransform) {
      throw _SvgFailure(index, 'svg-pattern-transform');
    }
    final strokeWidth = _number(
      shape.paint['stroke-width'],
      shape.node.index,
      fallback: 1,
    );
    final paintBounds = stroke
        ? bounds.inflate(
            strokeWidth *
                _number(
                  shape.paint['stroke-miterlimit'],
                  shape.node.index,
                  fallback: 4,
                ),
          )
        : bounds;
    final box = _bounds(inverse.transform, paintBounds);
    final left = ((box.left - x) / width).floor(),
        right = ((box.right - x) / width).ceil();
    final top = ((box.top - y) / height).floor(),
        bottom = ((box.bottom - y) / height).ceil();
    final columns = right - left, rows = bottom - top;
    final available = budget.limits[SceneResource.vectorOperations]!;
    if (columns < 0 ||
        rows < 0 ||
        columns > available ||
        rows > available ||
        columns > available ~/ math.max(1, rows)) {
      throw const SceneAdmissionException(
        SceneAdmissionFailure.complexityExceeded,
        resource: SceneResource.vectorOperations,
      );
    }
    // Admit every expanded tile before compiling its content or recording loops.
    int contentOperations(int node) =>
        4 +
        _attributes(node).values.fold<int>(0, (sum, v) => sum + v.length) +
        document
            .node(node)
            .children
            .fold<int>(
              0,
              (sum, child) =>
                  sum +
                  (document.node(child).localName == null
                      ? 0
                      : contentOperations(child)),
            );
    leases.add(
      budget.reserve({
        SceneResource.vectorOperations:
            columns * rows * contentOperations(content),
        SceneResource.references: columns * rows,
        SceneResource.vectorBytes: columns * rows * 64,
      }),
    );
    var contentToTile = const AffineTransform.identity();
    if (a['viewBox'] != null) {
      final view = FixedSvgViewport.resolve(
        SvgSourceDimensions(
          nodeIndex: index,
          width: '$width',
          height: '$height',
          viewBox: a['viewBox'],
          preserveAspectRatio: a['preserveAspectRatio'],
        ),
      );
      if (view.transform == null) {
        throw _SvgFailure(index, 'svg-pattern-viewbox', malformed: true);
      }
      contentToTile = view.transform!;
    } else {
      final contentUnits = a['patternContentUnits'] ?? 'userSpaceOnUse';
      if (!const {
        'objectBoundingBox',
        'userSpaceOnUse',
      }.contains(contentUnits)) {
        throw _SvgFailure(index, 'svg-pattern-content-units');
      }
      if (contentUnits == 'objectBoundingBox' && !object) {
        contentToTile = _scale(bounds.width, bounds.height);
      } else if (contentUnits == 'userSpaceOnUse' && object) {
        contentToTile = _scale(1 / bounds.width, 1 / bounds.height);
      }
    }
    final contentTree = _tree(
      content,
      const {'fill': 'black', 'stroke': 'none'},
      contentToTile,
      shape.viewport,
      [...shape.instances, shape.node.index],
      const [],
      1,
      const [],
    );
    Future<void> prepareContent(_SvgInstance instance) async {
      if (_shapes.contains(instance.node.localName)) {
        instance.path = _shape(instance);
        instance.bounds = instance.path!.getBounds();
        instance.picture = await _compile(
          instance,
          budget,
          leases,
          pictures,
          images,
        );
        instance.children.addAll(_markers(instance));
      } else if (instance.node.localName == 'image') {
        instance.path = _shape(instance);
        instance.bounds = instance.path!.getBounds();
        instance.picture = _imagePicture(instance, images);
        pictures.add(instance.picture!);
      }
      for (final child in instance.children) {
        await prepareContent(child);
      }
    }

    await prepareContent(contentTree);
    final tileRecorder = ui.PictureRecorder();
    _paintTree(ui.Canvas(tileRecorder), contentTree);
    final tile = tileRecorder.endRecording();
    pictures.add(tile);
    canvas.saveLayer(
      paintBounds,
      ui.Paint()
        ..color = ui.Color.fromRGBO(
          0,
          0,
          0,
          _number(
            shape.paint[stroke ? 'stroke-opacity' : 'fill-opacity'],
            shape.node.index,
            fallback: 1,
          ).clamp(0.0, 1.0),
        ),
    );
    canvas.save();
    if (!stroke) canvas.clipPath(shape.path!);
    canvas.transform(_matrix(tileToUser));
    for (var row = top; row < bottom; row++) {
      for (var column = left; column < right; column++) {
        canvas.save();
        canvas.translate(x + column * width, y + row * height);
        canvas.clipRect(ui.Rect.fromLTWH(0, 0, width, height));
        canvas.drawPicture(tile);
        canvas.restore();
      }
    }
    canvas.restore();
    if (stroke) {
      canvas.saveLayer(paintBounds, ui.Paint()..blendMode = ui.BlendMode.dstIn);
      canvas.drawPath(_dashPath(shape, budget, leases), _strokePaint(shape));
      canvas.restore();
    }
    canvas.restore();
  }
}

ui.Paint _strokePaint(_SvgInstance shape) => ui.Paint()
  ..color = const ui.Color(0xffffffff)
  ..style = ui.PaintingStyle.stroke
  ..strokeWidth = _number(
    shape.paint['stroke-width'],
    shape.node.index,
    fallback: 1,
  )
  ..strokeMiterLimit = _number(
    shape.paint['stroke-miterlimit'],
    shape.node.index,
    fallback: 4,
  )
  ..strokeCap = switch (shape.paint['stroke-linecap']) {
    'round' => ui.StrokeCap.round,
    'square' => ui.StrokeCap.square,
    _ => ui.StrokeCap.butt,
  }
  ..strokeJoin = switch (shape.paint['stroke-linejoin']) {
    'round' => ui.StrokeJoin.round,
    'bevel' => ui.StrokeJoin.bevel,
    _ => ui.StrokeJoin.miter,
  };
