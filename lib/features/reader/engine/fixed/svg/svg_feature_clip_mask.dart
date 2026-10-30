part of 'svg_graphics.dart';

const _clipMaskNoEffect = {'none', 'normal', 'auto', 'initial', 'unset'};
const _luminanceToAlpha = <double>[
  0, 0, 0, 0, 0, //
  0, 0, 0, 0, 0, //
  0, 0, 0, 0, 0, //
  .2126, .7152, .0722, 0, 0,
];

/// Owns clipPath/mask definitions and the clip-path/mask paint properties.
///
/// Supported: `clipPathUnits` user/object space, nested `clip-path` on a
/// clipPath, `clip-rule`, child shapes/groups/use; masks with
/// `maskUnits`/`maskContentUnits`, an explicit region, and alpha/luminance
/// `mask-type` (attribute or inline style). Filter/text/foreignObject/image
/// content and CSS shapes stay typed refusals.
final class SvgClipMaskFeature extends SvgFeature {
  const SvgClipMaskFeature();
  @override
  String get key => 'clip-mask';
  @override
  Set<String> get tags => const {'clipPath', 'mask'};
  @override
  Set<String> get definitionTags => tags;
  @override
  Set<String> get attributes => const {
    'clip-path',
    'mask',
    'clipPathUnits',
    'maskUnits',
    'maskContentUnits',
    'mask-type',
    'clip-rule',
  };
  @override
  Set<String> get presentationProperties => const {'clip-path', 'mask'};
  @override
  bool presentationIgnored(String property, String value) =>
      _clipMaskNoEffect.contains(value.toLowerCase());
  @override
  String? presentationRefusal(String property, String value) =>
      RegExp(r'^url\(\s*[\x27\x22]?#').hasMatch(value)
      ? null
      : property == 'clip-path'
      ? 'svg-css-clip-path'
      : 'svg-css-mask';

  @override
  void admit(SvgFeatureAdmission admission) {
    final tag = admission.tag;
    if (tag == 'clipPath') {
      _admitClipPath(admission);
      return;
    }
    if (tag == 'mask') {
      _admitMask(admission);
      return;
    }
    _admitEffect(admission, 'clip-path', 'svg-attribute-clip-path');
    _admitEffect(admission, 'mask', 'svg-attribute-mask');
  }

  void _admitClipPath(SvgFeatureAdmission a) {
    final attrs = a.attributes;
    _validateUnits(a, attrs['clipPathUnits'], 'svg-clipPath-units');
    final content = _contentProblem(a.plan, a.index, clip: true);
    if (content != null) a.refuse(content);
    if (!_hasGeometryChildren(a.plan, a.index)) a.refuse('svg-clipPath');
    if (_invalidClipRule(a.plan, a.index)) a.refuse('svg-clipPath-rule');
    final nested = attrs['clip-path'];
    if (nested != null && !_clipMaskNoEffect.contains(nested.toLowerCase())) {
      _targetOf(a, a.index, nested, 'svg-clipPath');
    }
  }

  void _admitMask(SvgFeatureAdmission a) {
    final attrs = a.attributes;
    _validateUnits(a, attrs['maskUnits'], 'svg-mask-units');
    _validateUnits(a, attrs['maskContentUnits'], 'svg-mask-content-units');
    _maskKind(a.plan, a.index, attrs);
    final content = _contentProblem(a.plan, a.index, clip: false);
    if (content != null) a.refuse(content);
    if (!_hasGeometryChildren(a.plan, a.index)) a.refuse('svg-mask');
  }

  void _admitEffect(SvgFeatureAdmission a, String property, String unresolved) {
    final value = a.attributes[property];
    if (value == null || _clipMaskNoEffect.contains(value.toLowerCase())) {
      return;
    }
    final target = _targetOf(a, a.index, value, unresolved);
    final wanted = property == 'clip-path' ? 'clipPath' : 'mask';
    if (a.plan.document.node(target).localName != wanted) a.refuse(unresolved);
    if (property == 'mask') {
      final pixels = a.plan.size.width.ceil() * a.plan.size.height.ceil();
      final buffers =
          _maskKind(a.plan, target, a.plan._attributes(target)) ==
              GeometryMaskKind.luminance
          ? 3
          : 2;
      // Charge applications, including the luminance conversion layer.
      a.chargeLayers(pixels: buffers * pixels, bytes: buffers * pixels * 4);
    }
  }

  void _validateUnits(SvgFeatureAdmission a, String? value, String identifier) {
    if (value == null) return;
    if (!const {'userSpaceOnUse', 'objectBoundingBox'}.contains(value)) {
      a.refuse(identifier);
    }
  }

  int _targetOf(
    SvgFeatureAdmission a,
    int source,
    String value,
    String identifier,
  ) {
    try {
      return a.plan._reference(source, value);
    } on _SvgFailure {
      a.refuse(identifier);
    }
  }

  @override
  Future<void> prepare(SvgFeaturePreparation preparation) async {
    final state = _ClipMaskState(preparation);
    preparation.state[this] = state;
    final maskApplications = <int>{};
    for (final node in preparation.nodes) {
      final clipValue = node.attributes['clip-path'];
      final maskValue = node.attributes['mask'];
      final clips = <_ClipLayer>[];
      final masks = <_MaskLayer>[];
      if (clipValue != null &&
          !_clipMaskNoEffect.contains(clipValue.toLowerCase())) {
        _buildClip(preparation, node, clipValue, clips);
      }
      if (maskValue != null &&
          !_clipMaskNoEffect.contains(maskValue.toLowerCase())) {
        // Admission charges one application per source; <use> can instantiate
        // it again. Reserve the additional instance before building its mask.
        if (!maskApplications.add(node.nodeIndex)) {
          final pixels = preparation.plan.displayPixels;
          preparation.reserve({
            SceneResource.layerPixels: 3 * pixels,
            SceneResource.layerBytes: 12 * pixels,
          });
        }
        await _buildMask(preparation, node, maskValue, masks);
      }
      if (clips.isNotEmpty || masks.isNotEmpty) {
        state.effects[node.identity] = _NodeEffect(clips, masks);
      }
    }
  }

  @override
  void paint(SvgFeaturePaint context) {
    final state = context.state[this] as _ClipMaskState?;
    final effect = state?.effects[context.node.identity];
    if (effect == null) {
      context.paintDefault();
      return;
    }
    final canvas = context.canvas;
    if (effect.clips.isNotEmpty) {
      canvas.save();
      for (final clip in effect.clips) {
        canvas.clipPath(clip.path);
      }
    }
    for (final mask in effect.masks) {
      canvas.save();
      canvas.clipPath(mask.regionPath);
      canvas.saveLayer(mask.region, ui.Paint());
    }
    context.paintDefault();
    for (final mask in effect.masks.reversed) {
      canvas.saveLayer(mask.region, ui.Paint()..blendMode = ui.BlendMode.dstIn);
      if (mask.kind == GeometryMaskKind.luminance) {
        canvas.saveLayer(
          mask.region,
          ui.Paint()
            ..colorFilter = const ui.ColorFilter.matrix(_luminanceToAlpha),
        );
      }
      canvas.drawPicture(mask.picture);
      if (mask.kind == GeometryMaskKind.luminance) canvas.restore();
      canvas.restore();
      canvas.restore();
      canvas.restore();
    }
    if (effect.clips.isNotEmpty) canvas.restore();
  }

  void _buildClip(
    SvgFeaturePreparation prep,
    SvgFeatureNode node,
    String value,
    List<_ClipLayer> out,
  ) {
    final plan = prep.plan;
    final target = _runtimeTarget(
      plan,
      node.nodeIndex,
      value,
      'svg-attribute-clip-path',
    );
    if (plan.document.node(target).localName != 'clipPath') {
      throw _SvgFailure(node.nodeIndex, 'svg-attribute-clip-path');
    }
    final bounds = _localBounds(plan, node);
    final paths = <ui.Path>[];
    _collectClip(
      plan,
      target,
      node.transform,
      bounds,
      node.viewport,
      paths,
      {},
    );
    for (final path in paths) {
      final box = path.getBounds();
      final id = 'svg-clip-${node.identity.replaceAll('/', '-')}-${out.length}';
      out.add(
        _ClipLayer(
          clip: GeometryClip(
            id: id,
            region: _region(box, const AffineTransform.identity()),
          ),
          path: path,
        ),
      );
    }
  }

  AffineTransform _unitsTransform(
    SvgGraphicsPlan plan,
    int target,
    ui.Rect bounds,
  ) {
    final attrs = plan._attributes(target);
    final transform = _svgTransform(attrs['transform'], target);
    if (attrs['clipPathUnits'] != 'objectBoundingBox') return transform;
    return _translate(
      bounds.left,
      bounds.top,
    ).compose(_scale(bounds.width, bounds.height)).compose(transform);
  }

  void _collectClip(
    SvgGraphicsPlan plan,
    int target,
    AffineTransform ownerUnit,
    ui.Rect ownerBounds,
    ui.Size viewport,
    List<ui.Path> paths,
    Set<int> active,
  ) {
    if (!active.add(target) || active.length > 16) {
      throw _SvgFailure(target, 'svg-clipPath-cycle', malformed: true);
    }
    final unit = ownerUnit.compose(_unitsTransform(plan, target, ownerBounds));
    final attrs = plan._attributes(target);
    final nested = attrs['clip-path'];
    if (nested != null && !_clipMaskNoEffect.contains(nested.toLowerCase())) {
      final nestedTarget = _runtimeTarget(
        plan,
        target,
        nested,
        'svg-clipPath-nested',
      );
      if (plan.document.node(nestedTarget).localName != 'clipPath') {
        throw _SvgFailure(target, 'svg-clipPath-nested');
      }
      _collectClip(
        plan,
        nestedTarget,
        ownerUnit,
        ownerBounds,
        viewport,
        paths,
        active,
      );
    }
    final inherited = _clipRule(plan, target, 'nonzero');
    final children = <ui.Path>[];
    final contentViewport = attrs['clipPathUnits'] == 'objectBoundingBox'
        ? const ui.Size(1, 1)
        : viewport;
    for (final child in plan.document.node(target).children) {
      if (plan.document.node(child).localName == null) continue;
      final root = plan._tree(
        child,
        const {'fill': 'black', 'stroke': 'none'},
        unit,
        contentViewport,
        const [],
        const [],
        1,
        const [],
      );
      _collectClipInstances(plan, root, children, inherited);
    }
    // Siblings form a union; nested clipPath references intersect that union.
    var combined = ui.Path();
    for (final child in children) {
      combined = ui.Path.combine(ui.PathOperation.union, combined, child);
    }
    paths.add(combined);
    active.remove(target);
  }

  void _collectClipInstances(
    SvgGraphicsPlan plan,
    _SvgInstance instance,
    List<ui.Path> paths,
    String inheritedRule,
  ) {
    if (instance.attributes['display'] == 'none') return;
    if (!_shapes.contains(instance.node.localName) &&
        !const {
          'g',
          'use',
          'symbol',
          'svg',
        }.contains(instance.node.localName)) {
      throw _SvgFailure(instance.node.index, 'svg-clipPath-content');
    }
    if (_hasUnpreparedEffect(instance.attributes)) {
      throw _SvgFailure(instance.node.index, 'svg-clipPath-content');
    }
    final rule = _clipRule(plan, instance.node.index, inheritedRule);
    if (_shapes.contains(instance.node.localName)) {
      final path = _shape(instance)
        ..fillType = rule == 'evenodd'
            ? ui.PathFillType.evenOdd
            : ui.PathFillType.nonZero;
      paths.add(path.transform(_matrix(instance.transform)));
    }
    for (final child in instance.children) {
      _collectClipInstances(plan, child, paths, rule);
    }
  }

  Future<void> _buildMask(
    SvgFeaturePreparation prep,
    SvgFeatureNode node,
    String value,
    List<_MaskLayer> out,
  ) async {
    final plan = prep.plan;
    final target = _runtimeTarget(
      plan,
      node.nodeIndex,
      value,
      'svg-attribute-mask',
    );
    if (plan.document.node(target).localName != 'mask') {
      throw _SvgFailure(node.nodeIndex, 'svg-attribute-mask');
    }
    final attrs = plan._attributes(target);
    final units = attrs['maskUnits'] ?? 'objectBoundingBox';
    final contentUnits = attrs['maskContentUnits'] ?? 'userSpaceOnUse';
    final kind = _maskKind(plan, target, attrs);
    final bounds = _localBounds(plan, node);
    final boxMapping = _translate(
      bounds.left,
      bounds.top,
    ).compose(_scale(bounds.width, bounds.height));
    final regionMapping = units == 'objectBoundingBox'
        ? boxMapping
        : const AffineTransform.identity();
    final contentMapping = contentUnits == 'objectBoundingBox'
        ? boxMapping
        : const AffineTransform.identity();
    final transform = _svgTransform(attrs['transform'], target);
    final contentTransform = node.transform
        .compose(contentMapping)
        .compose(transform);
    final region = _maskRegion(plan, target, attrs, units, node.viewport);
    final regionUnit = _bounds(
      node.transform.compose(regionMapping).compose(transform),
      region,
    );
    final regionPath = (ui.Path()..addRect(region)).transform(
      _matrix(node.transform.compose(regionMapping).compose(transform)),
    );
    if (region.width <= 0 || region.height <= 0) {
      throw _SvgFailure(target, 'svg-mask-region', malformed: true);
    }
    final roots = <_SvgInstance>[];
    final contentViewport = contentUnits == 'objectBoundingBox'
        ? const ui.Size(1, 1)
        : node.viewport;
    for (final child in plan.document.node(target).children) {
      if (plan.document.node(child).localName == null) continue;
      roots.add(
        plan._tree(
          child,
          const {'fill': 'black', 'stroke': 'none'},
          contentTransform,
          contentViewport,
          const [],
          const [],
          1,
          const [],
        ),
      );
    }
    for (final root in roots) {
      await _prepareMaskContent(prep, root);
    }
    final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
    final content = SvgFeatureRegistry(const []);
    for (final root in roots) {
      _paintTree(canvas, root, content, const <Object, Object?>{});
    }
    final picture = recorder.endRecording();
    prep.addPicture(picture);
    final coverage = await _maskCoverage(prep, picture, regionPath, kind);
    final regionGeometry = _region(
      regionUnit,
      const AffineTransform.identity(),
    );
    final mask = GeometryMask(
      id: 'svg-mask-${node.identity.replaceAll('/', '-')}-${out.length}',
      sourceNode: target,
      units: units == 'objectBoundingBox'
          ? GeometryMaskUnits.objectBoundingBox
          : GeometryMaskUnits.userSpaceOnUse,
      contentUnits: contentUnits == 'objectBoundingBox'
          ? GeometryMaskUnits.objectBoundingBox
          : GeometryMaskUnits.userSpaceOnUse,
      kind: kind,
      region: regionGeometry,
      coverage: coverage,
    );
    out.add(_MaskLayer(mask, picture, regionUnit, regionPath, kind));
  }

  Future<void> _prepareMaskContent(
    SvgFeaturePreparation prep,
    _SvgInstance instance,
  ) async {
    final plan = prep.plan;
    if (_hasUnpreparedEffect(instance.attributes)) {
      throw _SvgFailure(instance.node.index, 'svg-mask-content');
    }
    if (_shapes.contains(instance.node.localName)) {
      instance.path = _shape(instance);
      instance.bounds = instance.path!.getBounds();
      instance.picture = await plan._compile(
        instance,
        prep.budget,
        prep._leases,
        prep._pictures,
        prep.images.forEvidence,
      );
      instance.children.addAll(plan._markers(instance));
    } else if (const {
      'image',
      'text',
      'tspan',
      'textPath',
      'foreignObject',
      'filter',
    }.contains(instance.node.localName)) {
      throw _SvgFailure(instance.node.index, 'svg-mask-content');
    }
    for (final child in instance.children) {
      await _prepareMaskContent(prep, child);
    }
  }

  Future<GeometryAlphaFootprint> _maskCoverage(
    SvgFeaturePreparation prep,
    ui.Picture picture,
    ui.Path regionPath,
    GeometryMaskKind kind,
  ) async {
    prep.checkCancellation();
    final extent = prep.evidenceExtent;
    final width = extent.width.toInt(), height = extent.height.toInt();
    // The whole SVG reservation prepays one serial evidence peak. Mask
    // preparation finishes before leaf coverage starts, so subdivide that
    // same capacity rather than charging the outer ledger a second time.
    final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
    // Same authored root-coordinate raster as unclipped paint evidence.
    canvas.translate(-extent.left, -extent.top);
    canvas.clipPath(regionPath);
    if (kind == GeometryMaskKind.luminance) {
      canvas.saveLayer(
        regionPath.getBounds(),
        ui.Paint()
          ..colorFilter = const ui.ColorFilter.matrix(_luminanceToAlpha),
      );
    }
    canvas.drawPicture(picture);
    if (kind == GeometryMaskKind.luminance) canvas.restore();
    final recorded = recorder.endRecording();
    try {
      final footprint = await AuthoredEvidenceRaster.rasterize(
        recorded,
        width: width,
        height: height,
        budget: prep.rasterBudget,
        // Covered by the feature payload bound in the SVG reservation.
        reserve: (_) {},
        checkCancellation: prep.checkCancellation,
      );
      return footprint.placed(_translate(extent.left, extent.top));
    } finally {
      recorded.dispose();
    }
  }

  GeometryMaskKind _maskKind(
    SvgGraphicsPlan plan,
    int target,
    Map<String, String> attrs,
  ) {
    final raw = _inlineValue(plan, target, 'mask-type') ?? attrs['mask-type'];
    final value = (raw ?? 'luminance').toLowerCase();
    if (value != 'alpha' && value != 'luminance') {
      throw SvgFeatureRefusal(target, 'svg-mask-type');
    }
    return value == 'alpha'
        ? GeometryMaskKind.alpha
        : GeometryMaskKind.luminance;
  }

  ui.Rect _maskRegion(
    SvgGraphicsPlan plan,
    int target,
    Map<String, String> attrs,
    String units,
    ui.Size viewport,
  ) {
    final object = units == 'objectBoundingBox';
    double value(String key, double fallback, double basis) =>
        _number(attrs[key], target, fallback: fallback, basis: basis);
    final x = value(
      'x',
      object ? -.1 : -.1 * viewport.width,
      object ? 1 : viewport.width,
    );
    final y = value(
      'y',
      object ? -.1 : -.1 * viewport.height,
      object ? 1 : viewport.height,
    );
    final w = value(
      'width',
      object ? 1.2 : 1.2 * viewport.width,
      object ? 1 : viewport.width,
    );
    final h = value(
      'height',
      object ? 1.2 : 1.2 * viewport.height,
      object ? 1 : viewport.height,
    );
    if (w < 0 || h < 0) {
      throw _SvgFailure(target, 'svg-mask-region', malformed: true);
    }
    // objectBoundingBox values stay normalized; the caller applies the box
    // mapping exactly once.
    return ui.Rect.fromLTWH(x, y, w, h);
  }

  ui.Rect _localBounds(SvgGraphicsPlan plan, SvgFeatureNode node) {
    final inverse = node.transform.inverse();
    if (inverse is! InvertedTransform) {
      throw _SvgFailure(node.nodeIndex, 'singular-svg-transform');
    }
    // Use the expanded chain, including use x/y and symbol viewports. Map each
    // descendant directly into owner space, without double-applying transforms.
    return _instanceBounds(node._instance, inverse.transform) ?? ui.Rect.zero;
  }

  ui.Rect? _instanceBounds(_SvgInstance instance, AffineTransform unitToLocal) {
    ui.Rect? result;
    if (_shapes.contains(instance.node.localName) ||
        instance.node.localName == 'image') {
      result = _transformedShapeBounds(
        instance,
        unitToLocal.compose(instance.transform),
      );
    }
    for (final child in instance.children) {
      final box = _instanceBounds(child, unitToLocal);
      if (box == null) continue;
      result = result == null ? box : result.expandToInclude(box);
    }
    return result;
  }

  ui.Rect _transformedShapeBounds(_SvgInstance instance, AffineTransform t) {
    final tag = instance.node.localName;
    if (tag == 'path') {
      // Transform the actual cubic geometry before solving its extrema. Native
      // Path.getBounds also includes off-curve control points after transform.
      final path = vc
          .parseSvgPathData(instance.attributes['d'] ?? '')
          .transformed(vc.AffineMatrix(t.a, t.b, t.c, t.d, t.e, t.f));
      final data = StringBuffer();
      for (final command in path.commands) {
        switch (command) {
          case vc.MoveToCommand():
            data.write('M${command.x} ${command.y}');
          case vc.LineToCommand():
            data.write('L${command.x} ${command.y}');
          case vc.CubicToCommand():
            data.write(
              'C${command.x1} ${command.y1} ${command.x2} '
              '${command.y2} ${command.x3} ${command.y3}',
            );
          case vc.CloseCommand():
            data.write('Z');
        }
      }
      return _pathBounds(data.toString());
    }
    final path = _shape(instance);
    final bounds = path.getBounds();
    ui.Offset ellipseExtent(double rx, double ry) => ui.Offset(
      math.sqrt(t.a * t.a * rx * rx + t.c * t.c * ry * ry),
      math.sqrt(t.b * t.b * rx * rx + t.d * t.d * ry * ry),
    );
    if (tag == 'circle' || tag == 'ellipse') {
      final center = _point(t, bounds.center);
      final extent = ellipseExtent(bounds.width / 2, bounds.height / 2);
      return ui.Rect.fromLTRB(
        center.dx - extent.dx,
        center.dy - extent.dy,
        center.dx + extent.dx,
        center.dy + extent.dy,
      );
    }
    if (tag == 'rect' || tag == 'image') {
      final attrs = instance.attributes, index = instance.node.index;
      final rx = math.min(
        bounds.width / 2,
        _number(
          attrs['rx'] ?? attrs['ry'],
          index,
          basis: instance.viewport.width,
        ),
      );
      final ry = math.min(
        bounds.height / 2,
        _number(
          attrs['ry'] ?? attrs['rx'],
          index,
          basis: instance.viewport.height,
        ),
      );
      if (rx > 0 && ry > 0) {
        // A rounded rectangle is an inset rectangle plus an ellipse. Their
        // transformed support extents add, including rotation and shear.
        final inner = _bounds(
          t,
          ui.Rect.fromLTRB(
            bounds.left + rx,
            bounds.top + ry,
            bounds.right - rx,
            bounds.bottom - ry,
          ),
        );
        final extent = ellipseExtent(rx, ry);
        return ui.Rect.fromLTRB(
          inner.left - extent.dx,
          inner.top - extent.dy,
          inner.right + extent.dx,
          inner.bottom + extent.dy,
        );
      }
    }
    // Rectangles, lines and polygons have no off-curve control points.
    return path.transform(_matrix(t)).getBounds();
  }

  bool _invalidClipRule(SvgGraphicsPlan plan, int index) {
    for (final child in plan.document.node(index).children) {
      final tag = plan.document.node(child).localName;
      if (tag == null) continue;
      if (_shapes.contains(tag) || tag == 'g' || tag == 'use') {
        final raw =
            plan._attributes(child)['clip-rule'] ??
            _inlineValue(plan, child, 'clip-rule');
        if (raw != null &&
            raw.toLowerCase() != 'nonzero' &&
            raw.toLowerCase() != 'evenodd') {
          return true;
        }
        if (tag == 'g' && _invalidClipRule(plan, child)) return true;
      }
    }
    return false;
  }

  int _runtimeTarget(
    SvgGraphicsPlan plan,
    int source,
    String value,
    String identifier,
  ) {
    try {
      return plan._reference(source, value);
    } on _SvgFailure {
      throw SvgFeatureRefusal(source, identifier);
    }
  }

  String _clipRule(SvgGraphicsPlan plan, int index, String fallback) {
    final raw =
        plan._attributes(index)['clip-rule'] ??
        _inlineValue(plan, index, 'clip-rule');
    if (raw == null) return fallback;
    final value = raw.toLowerCase();
    if (value != 'nonzero' && value != 'evenodd') {
      throw SvgFeatureRefusal(index, 'svg-clipPath-rule');
    }
    return value;
  }

  String? _inlineValue(SvgGraphicsPlan plan, int index, String property) {
    final style = plan.document.node(index).attribute('style');
    if (style == null) return null;
    for (final part in style.split(';')) {
      final colon = part.indexOf(':');
      if (colon < 0) continue;
      if (part.substring(0, colon).trim().toLowerCase() != property) continue;
      var value = part.substring(colon + 1).trim();
      value = value.replaceFirst(
        RegExp(r'!\s*important\s*$', caseSensitive: false),
        '',
      );
      value = value.trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  @override
  void geometry(SvgFeatureGeometryContext context) {
    final state = context.state[this] as _ClipMaskState?;
    if (state == null || context.nodes.isEmpty) return;
    final active = <String, List<_NodeEffect>>{};
    void visit(SvgFeatureNode node, List<_NodeEffect> inherited) {
      final own = state.effects[node.identity];
      final all = own == null ? inherited : [...inherited, own];
      active[node.identity] = all;
      for (final child in node._instance.children) {
        visit(SvgFeatureNode._(child, context.state), all);
      }
    }

    visit(context.nodes.first, const []);
    state.active.addAll(active);
    final byNode = <int, List<_NodeEffect>>{};
    final instances = <int, int>{};
    final gaps = <_NodeEffect, GeometryIssue>{};
    void incomplete(
      List<_NodeEffect> effects,
      GeometryGapKind kind,
      String reason,
    ) {
      for (final effect in effects) {
        gaps[effect] = GeometryIssue(kind, reason);
      }
    }

    for (final node in context.nodes) {
      instances.update(node.nodeIndex, (n) => n + 1, ifAbsent: () => 1);
    }
    for (final entry in active.entries) {
      final index = int.parse(entry.key.substring(0, entry.key.indexOf('/')));
      byNode.putIfAbsent(index, () => []).addAll(entry.value);
    }
    for (final node in context.nodes) {
      for (final effect in active[node.identity] ?? const <_NodeEffect>[]) {
        for (final clip in effect.clips) {
          context.geometry.addClip(clip.clip);
          context.addClipTo(node.nodeIndex, clip.clip.id);
        }
        for (final mask in effect.masks) {
          context.addMaskTo(node.nodeIndex, mask.mask.id);
        }
      }
    }
    final evidenced = <String>{};
    final paints = context._paint;
    for (var i = 0; i < paints.length; i++) {
      final paint = paints[i];
      final effects = byNode[paint.nodeIndex];
      if (effects == null || effects.isEmpty) continue;
      if (instances[paint.nodeIndex] != 1) {
        incomplete(
          effects,
          GeometryGapKind.paint,
          'Clip/mask evidence cannot distinguish repeated node ${paint.nodeIndex}',
        );
      }
      final clips = [
        for (final effect in effects)
          for (final clip in effect.clips) clip.path,
      ];
      final masks = [
        for (final effect in effects)
          for (final mask in effect.masks) mask.mask,
      ];
      if (clips.isEmpty && masks.isEmpty) continue;
      final footprint = paint.alphaFootprint;
      if (footprint == null) {
        incomplete(
          effects,
          masks.isNotEmpty ? GeometryGapKind.mask : GeometryGapKind.clip,
          'Clip/mask coverage has no retained paint footprint at node ${paint.nodeIndex}',
        );
        continue;
      }
      // Native clipped coverage is awaited in postPaint, after leaf pictures
      // and per-role paint records exist. Never point-sample a clip path.
      var placed = footprint;
      if (masks.isNotEmpty) {
        placed = _withMasks(placed, masks);
        evidenced.addAll(masks.map((mask) => mask.id));
      }
      paints[i] = _copyPaint(paint, placed);
    }
    for (final effect in state.effects.values) {
      for (final mask in effect.masks) {
        if (!evidenced.contains(mask.mask.id)) {
          incomplete(
            [effect],
            GeometryGapKind.mask,
            'Mask evidence for ${mask.mask.id} has no retained paint footprint',
          );
        }
      }
    }
    for (final node in context.nodes) {
      final own = state.effects[node.identity];
      final issue = gaps[own];
      if (issue != null) {
        context.markIncomplete(node, issue.kind, issue.reason);
      } else {
        context.markCovered(node);
      }
    }
  }

  @override
  Future<void> postPaint(SvgFeaturePostPaintContext post) async {
    final context = post.geometry;
    final state = context.state[this] as _ClipMaskState?;
    if (state == null) return;
    for (final node in context.nodes) {
      final effects = state.active[node.identity] ?? const <_NodeEffect>[];
      final paths = [
        for (final e in effects)
          for (final c in e.clips) c.path,
      ];
      if (paths.isEmpty) continue;
      final paints = context._paint;
      for (var i = 0; i < paints.length; i++) {
        final paint = paints[i];
        if (paint.nodeIndex != node.nodeIndex ||
            paint.paintOrdinal != node.paintOrdinal) {
          continue;
        }
        final clipped = await _clipFootprint(
          node._instance,
          paint.role,
          paths,
          state.preparation,
          post,
        );
        post.checkCancellation();
        paints[i] = _copyPaint(paint, _withMasks(clipped, paint.masks));
      }
      // A combined feature picture cannot prove its separate source paints.
      if (context.geometry.paints.any(
        (p) => p.paintOrdinal == node.paintOrdinal && p.alphaFootprint != null,
      )) {
        context.markIncomplete(
          node,
          GeometryGapKind.clip,
          'Per-source clipped feature coverage is unavailable',
        );
      }
    }
  }
}

Future<GeometryAlphaFootprint> _clipFootprint(
  _SvgInstance instance,
  GeometryPaintRole role,
  List<ui.Path> paths,
  SvgFeaturePreparation prep,
  SvgFeaturePostPaintContext post,
) async {
  post.checkCancellation();
  final pictures = <ui.Picture>[], leases = <SceneResourceLease>[];
  try {
    var leaf = instance;
    if (_shapes.contains(instance.node.localName) &&
        _shapePaintRoles(instance.paint).length > 1) {
      // Use the native compiler for each role, including gradients, patterns
      // and dash/cap/join construction. Alpha-grid clipping cannot reproduce
      // coincident native AA edges.
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
      leaf.picture = await prep.plan._compile(
        leaf,
        prep.budget,
        leases,
        pictures,
        prep.images.forEvidence,
      );
      post.checkCancellation();
    }
    final extent = post.evidenceExtent;
    final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
    // Same placed root-coordinate raster and origin as unclipped evidence;
    // fractional host offsets stay in the native matrix and clip paths.
    canvas.translate(-extent.left, -extent.top);
    for (final path in paths) {
      canvas.clipPath(path);
    }
    _paintLeaf(canvas, leaf, evidence: true);
    final picture = recorder.endRecording();
    pictures.add(picture);
    final footprint = await AuthoredEvidenceRaster.rasterize(
      picture,
      width: extent.width.toInt(),
      height: extent.height.toInt(),
      // Serial with leaf/mask evidence: this is the shared, prepaid peak.
      budget: post.rasterBudget,
      // The plan already prepays the additional retained clip-copy payload.
      reserve: (_) {},
      checkCancellation: post.checkCancellation,
    );
    return footprint.placed(_translate(extent.left, extent.top));
  } finally {
    for (final picture in pictures) {
      picture.dispose();
    }
    for (final lease in leases.reversed) {
      lease.release();
    }
  }
}

GeometryAlphaFootprint _withMasks(
  GeometryAlphaFootprint footprint,
  List<GeometryMask> masks,
) {
  final ids = {for (final mask in footprint.masks) mask.id};
  final added = [
    for (final mask in masks)
      if (ids.add(mask.id)) mask,
  ];
  if (added.isEmpty) return footprint;
  return footprint.withMasks([...footprint.masks, ...added]);
}

GeometryPaint _copyPaint(
  GeometryPaint paint,
  GeometryAlphaFootprint footprint,
) => GeometryPaint(
  nodeIndex: paint.nodeIndex,
  paintOrdinal: paint.paintOrdinal,
  region: paint.region,
  innerRegion: paint.innerRegion,
  kind: paint.kind,
  role: paint.role,
  effectiveOpacity: paint.effectiveOpacity,
  exactCoverage: paint.exactCoverage,
  argb: paint.argb,
  alphaFootprint: footprint,
  clipIds: paint.clipIds,
  groupIds: paint.groupIds,
  textRanges: paint.textRanges,
);

final class _ClipMaskState {
  _ClipMaskState(this.preparation);
  final SvgFeaturePreparation preparation;
  final effects = <String, _NodeEffect>{};
  final active = <String, List<_NodeEffect>>{};
}

final class _NodeEffect {
  const _NodeEffect(this.clips, this.masks);
  final List<_ClipLayer> clips;
  final List<_MaskLayer> masks;
}

final class _ClipLayer {
  const _ClipLayer({required this.clip, required this.path});
  final GeometryClip clip;
  final ui.Path path;
}

final class _MaskLayer {
  const _MaskLayer(
    this.mask,
    this.picture,
    this.region,
    this.regionPath,
    this.kind,
  );
  final GeometryMask mask;
  final ui.Picture picture;
  final ui.Rect region;
  final ui.Path regionPath;
  final GeometryMaskKind kind;
}

String? _contentProblem(SvgGraphicsPlan plan, int index, {required bool clip}) {
  for (final child in plan.document.node(index).children) {
    final node = plan.document.node(child), tag = node.localName;
    if (tag == null) continue;
    if (const {
      'defs',
      'title',
      'desc',
      'metadata',
      'style',
      'linearGradient',
      'radialGradient',
      'stop',
      'pattern',
      'marker',
      'symbol',
      'clipPath',
      'mask',
    }.contains(tag)) {
      continue;
    }
    if (_shapes.contains(tag) || tag == 'g' || tag == 'use') {
      final attrs = plan._attributes(child);
      if (attrs['clip-path'] != null || attrs['mask'] != null) {
        return clip ? 'svg-clipPath-content' : 'svg-mask-content';
      }
      final nested = _contentProblem(plan, child, clip: clip);
      if (nested != null) return nested;
      continue;
    }
    return clip ? 'svg-clipPath-content' : 'svg-mask-content';
  }
  return null;
}

bool _hasGeometryChildren(SvgGraphicsPlan plan, int index) {
  for (final child in plan.document.node(index).children) {
    final tag = plan.document.node(child).localName;
    if (tag == null) continue;
    if (_shapes.contains(tag) || tag == 'use') return true;
    if (tag == 'g' && _hasGeometryChildren(plan, child)) return true;
  }
  return false;
}

bool _hasUnpreparedEffect(Map<String, String> attributes) =>
    const ['clip-path', 'mask', 'filter'].any((property) {
      final value = attributes[property];
      return value != null && !_clipMaskNoEffect.contains(value.toLowerCase());
    });
