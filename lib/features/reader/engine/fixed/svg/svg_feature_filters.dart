part of 'svg_graphics.dart';

/// Bounded native filter graph. Filter regions and primitive subregions are
/// resolved in the filtered element's user space; every offscreen image is
/// charged to the plan before the graph runs and retained by the scene owner
/// until scene disposal.
final class SvgFilterFeature extends SvgFeature {
  const SvgFilterFeature();
  @override
  String get key => 'filter';
  @override
  Set<String> get tags => const {
    'filter',
    'feGaussianBlur',
    'feOffset',
    'feColorMatrix',
    'feFlood',
    'feComposite',
    'feBlend',
    'feMerge',
    'feMergeNode',
    'feImage',
    'feTile',
    'feTurbulence',
    'feDisplacementMap',
    'feMorphology',
    'feConvolveMatrix',
    'feComponentTransfer',
    'feFuncR',
    'feFuncG',
    'feFuncB',
    'feFuncA',
    'feDiffuseLighting',
    'feSpecularLighting',
    'feDistantLight',
    'fePointLight',
    'feSpotLight',
    'feDropShadow',
  };
  @override
  Set<String> get definitionTags => tags;
  @override
  Set<String> get attributes => const {
    'filter',
    'filterUnits',
    'primitiveUnits',
    'color-interpolation-filters',
    'in',
    'in2',
    'result',
    'stdDeviation',
    'dx',
    'dy',
    'type',
    'values',
    'flood-color',
    'flood-opacity',
    'operator',
    'mode',
    'k1',
    'k2',
    'k3',
    'k4',
  };
  @override
  Set<String> get presentationProperties => const {'filter'};
  @override
  bool presentationIgnored(String property, String value) =>
      property == 'filter' &&
      const {'none', 'initial', 'unset'}.contains(value.trim().toLowerCase());
  @override
  String? presentationRefusal(String property, String value) {
    if (property != 'filter') return null;
    final raw = value.trim();
    if (raw.toLowerCase() == 'none' ||
        _filterUrl.hasMatch(raw) ||
        raw.startsWith('#')) {
      return null;
    }
    return 'svg-filter';
  }

  @override
  void admit(SvgFeatureAdmission admission) {
    final tag = admission.tag;
    if (tag != null && tags.contains(tag)) {
      if (!_supportedTags.contains(tag)) admission.refuse('svg-$tag');
      if (tag != 'filter') {
        final parent = admission.plan.document
            .node(admission.index)
            .parentIndex;
        final parentTag = parent == null
            ? null
            : admission.plan.document.node(parent).localName;
        if (tag == 'feMergeNode'
            ? parentTag != 'feMerge'
            : parentTag != 'filter') {
          admission.refuse('svg-$tag');
        }
      }
      if (tag == 'filter') {
        _validateFilterAttributes(admission.attributes, admission.index);
      } else if (tag != 'feMergeNode') {
        _primitive(admission.plan, admission.index, tag, admission.attributes);
      }
    }
    final raw = admission.attributes['filter']?.trim();
    if (raw == null || raw.isEmpty || raw.toLowerCase() == 'none') return;
    if (!_filterUrl.hasMatch(raw) && !raw.startsWith('#')) {
      admission.refuse('svg-filter');
    }
    int target;
    try {
      target = admission.resolveReference(admission.index, raw);
    } on _SvgFailure {
      // A filter reference outside the admitted document is still the same
      // typed filter capability refusal, not a partial render.
      admission.refuse('svg-filter');
    }
    final targetNode = admission.plan.document.node(target);
    if (targetNode.namespaceUri != 'http://www.w3.org/2000/svg' ||
        targetNode.localName != 'filter') {
      admission.refuse('svg-filter-target');
    }
    final graph = _parseGraph(admission.plan, target);
    // Each primitive and input read executes once, including repeated edges.
    admission.charge(SceneResource.vectorOperations, graph.work);
    final viewport = admission.plan.size;
    // Two cached sources + one image per primitive + at most three scratch/
    // output buffers. Geometry bounds each root-space buffer to 2x viewport.
    final pixels =
        2 *
        viewport.width.ceil() *
        viewport.height.ceil() *
        (graph.primitives.length + 5);
    admission.plan._filterRasterPixels += pixels;
    final area = 2 * viewport.width.ceil() * viewport.height.ceil();
    // All retained DAG caches may coexist with ONE shared evidence raster and
    // its exact tile copy/readback. Shape/placement is unknown until geometry.
    admission.plan._filterEvidencePixels = math.max(
      admission.plan._filterEvidencePixels,
      area + 2 * math.min(area, AuthoredEvidenceRaster.maxTilePixels),
    );
    admission.charge(
      SceneResource.vectorBytes,
      GeometryAlphaFootprint.storageOverhead + area,
    );
  }

  @override
  Future<void> prepare(SvgFeaturePreparation preparation) async {
    final state = preparation.state[this] as _SvgFilterState?;
    if (state != null) return;
    final created = _SvgFilterState();
    preparation.state[this] = created;
    final graphs = <int, _SvgFilterGraph>{};
    for (final node in preparation.nodes) {
      preparation.checkCancellation();
      final raw = node.attributes['filter']?.trim();
      if (raw == null || raw.isEmpty || raw.toLowerCase() == 'none') continue;
      int? target;
      for (final edge in preparation.plan.references) {
        if (edge.source == node.nodeIndex && edge.attribute == 'filter') {
          target = edge.target;
          break;
        }
      }
      if (target == null) continue;
      final graph = graphs.putIfAbsent(
        target,
        () => _parseGraph(preparation.plan, target!),
      );
      final use = _SvgFilterUse(
        graph,
        preparation.rasterBudget,
        preparation.checkCancellation,
        2 *
            preparation.plan.size.width.ceil() *
            preparation.plan.size.height.ceil(),
      );
      created.uses[node.identity] = use;
      preparation.onDispose(use.dispose);
      // Admission audits references recursively, charging each use (including
      // repeated source instances). The base lease already owns these layers.
    }
  }

  @override
  void geometry(SvgFeatureGeometryContext context) {
    final state = context.state[this] as _SvgFilterState?;
    if (state == null) return;
    void visit(_SvgInstance instance, bool filtered, bool outerEffect) {
      final use =
          state.uses[SvgFeatureNode._(instance, context.state).identity];
      if (use != null) {
        use.intermediate = filtered;
        use.outerEffect = outerEffect;
      }
      final effect = ['clip-path', 'mask'].any((key) {
        final value = instance.attributes[key];
        return value != null &&
            !_clipMaskNoEffect.contains(value.toLowerCase());
      });
      for (final child in instance.children) {
        visit(child, filtered || use != null, outerEffect || effect);
      }
    }

    if (context.nodes.isNotEmpty) {
      visit(context.nodes.first._instance, false, false);
    }
    for (final node in context.nodes) {
      final use = state.uses[node.identity];
      if (use == null) {
        if (tags.contains(node.localName) ||
            node.attributes.keys.any(attributes.contains)) {
          final raw = node.attributes['filter']?.trim();
          if (raw != null && raw.isNotEmpty && raw.toLowerCase() != 'none') {
            context.markIncomplete(
              node,
              GeometryGapKind.paint,
              'Filter source graph unavailable',
            );
          } else {
            context.markCovered(node);
          }
        }
        continue;
      }
      final bounds = node.bounds;
      if (bounds == null) {
        if (node.attributes['display'] == 'none') {
          context.markCovered(node);
        } else {
          context.markIncomplete(
            node,
            GeometryGapKind.paint,
            'Filter source bounds unavailable',
          );
        }
        continue;
      }
      final layout = use.graph.layout(bounds, node.viewport, node.nodeIndex);
      use.layout = layout;
      // Raster caches use root-space pixels. Validate their actual allocation
      // against admission's per-buffer cap before capturing or recording work.
      final raster = _filterRasterRegion(node.transform, layout.region);
      if (!raster.isFinite ||
          raster.width > 4096 ||
          raster.height > 4096 ||
          raster.width * raster.height >
              2 *
                  context.plan.size.width.ceil() *
                  context.plan.size.height.ceil()) {
        throw SvgFeatureRefusal(node.nodeIndex, 'svg-filter-region');
      }
      // Source footprints describe the input, not filtered visibility. Invalidate
      // every paint in this instance's subtree, including group descendants.
      final ordinals = <int>{};
      void collect(_SvgInstance instance) {
        ordinals.add(instance.ordinal);
        for (final child in instance.children) {
          collect(child);
        }
      }

      collect(node._instance);
      use.sourceOrdinals.addAll(ordinals);
      context._paint.removeWhere(
        (paint) => ordinals.contains(paint.paintOrdinal),
      );
      context.geometry.paints.removeWhere(
        (paint) => ordinals.contains(paint.paintOrdinal),
      );
      use.raster = raster;
    }
  }

  @override
  bool captureOutput(SvgFeatureNode node) {
    final use = (node.state[this] as _SvgFilterState?)?.uses[node.identity];
    return use != null && !use.intermediate && use.layout != null;
  }

  @override
  Future<void> postPaint(SvgFeaturePostPaintContext post) async {
    final context = post.geometry;
    final state = context.state[this] as _SvgFilterState?;
    if (state == null) return;
    // Other features can append source paints after geometry(). Remove these
    // too, before any final filter paint is added, including nested results.
    final sourceOrdinals = state.uses.values
        .expand((u) => u.sourceOrdinals)
        .toSet();
    context._paint.removeWhere((p) => sourceOrdinals.contains(p.paintOrdinal));
    context.geometry.paints.removeWhere(
      (p) => sourceOrdinals.contains(p.paintOrdinal),
    );
    void collapseMasks(List<SourceFragment> fragments) {
      for (var i = 0; i < fragments.length; i++) {
        final f = fragments[i];
        if (!sourceOrdinals.contains(f.paintOrdinal) || f.maskIds.isEmpty) {
          continue;
        }
        // Subtree masks are baked into final output, not pending applications.
        // Preserve source identity/geometry without applying those masks twice.
        fragments[i] = SourceFragment(
          page: f.page,
          nodeIndex: f.nodeIndex,
          kind: f.kind,
          textRange: f.textRange,
          clusters: f.clusters,
          elementAnchor: f.elementAnchor,
          sourceToUnit: f.sourceToUnit,
          clipIds: f.clipIds,
          maskIds: const [],
          paintOrdinal: f.paintOrdinal,
          effectiveOpacity: f.effectiveOpacity,
          elementQuad: f.elementQuad,
        );
      }
    }

    collapseMasks(context._fragments);
    collapseMasks(context.geometry.fragments);
    try {
      for (final node in context.nodes) {
        final use = state.uses[node.identity];
        if (use == null || use.layout == null) continue;
        post.checkCancellation();
        if (use.intermediate || node.attributes['display'] == 'none') {
          context.markCovered(node);
          continue;
        }
        final output = post.outputFor(node);
        if (output == null || use.outerEffect) {
          context.markIncomplete(
            node,
            GeometryGapKind.paint,
            output == null
                ? 'Filtered instance output capture unavailable'
                : 'Filtered output has an uncaptured ancestor clip/mask',
          );
          continue;
        }
        final raster = use.raster!;
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.translate(-raster.left, -raster.top);
        // Own opacity is in the capture; replay ancestors in native layer order.
        // The published alpha already contains opacity, so no group applies twice.
        final ownOpacity = _number(
          node.attributes['opacity'],
          node.nodeIndex,
          fallback: 1,
        ).clamp(0.0, 1.0);
        final groups = node._instance.groups;
        final ancestors = groups.take(
          groups.length - (ownOpacity == 1 ? 0 : 1),
        );
        for (final group in ancestors) {
          canvas.saveLayer(
            null,
            ui.Paint()..color = ui.Color.fromRGBO(0, 0, 0, group.opacity),
          );
        }
        canvas.drawPicture(output);
        for (final _ in ancestors) {
          canvas.restore();
        }
        final picture = recorder.endRecording();
        try {
          final alpha = await AuthoredEvidenceRaster.rasterize(
            picture,
            width: raster.width.toInt(),
            height: raster.height.toInt(),
            budget: post.rasterBudget,
            reserve: use.reservePayload,
            checkCancellation: post.checkCancellation,
          );
          post.checkCancellation();
          context.geometry.addPaint(
            GeometryPaint(
              nodeIndex: node.nodeIndex,
              paintOrdinal: node.paintOrdinal,
              region: _region(raster, const AffineTransform.identity()),
              kind: GeometryPaintKind.image,
              effectiveOpacity: 1,
              exactCoverage: true,
              alphaFootprint: alpha.placed(_translate(raster.left, raster.top)),
            ),
          );
          context.markCovered(node);
        } finally {
          picture.dispose();
        }
      }
    } finally {
      // Pictures now own the native image references. Close Dart handles before
      // publication; keep their prepaid leases until those pictures are disposed.
      for (final use in state.uses.values) {
        use.closeImages();
      }
    }
  }

  @override
  void paint(SvgFeaturePaint context) {
    final state = context.state[this] as _SvgFilterState?;
    final use = state?.uses[context.node.identity];
    final layout = use?.layout;
    if (state == null || use == null) {
      context.paintDefault();
      return;
    }
    if (layout == null) {
      context.paintDefault();
      return;
    }
    use.admitRasters();
    // Inherited viewport coverage belongs to output, not SourceGraphic. Keep
    // descendant viewport and feature-owned clips inside the input capture.
    final source = context.captureDefault(
      excludeViewportClipIds: {for (final clip in context.node.clips) clip.id},
    );
    if (layout.region.width <= 0 || layout.region.height <= 0) return;
    final inverse = context.node.transform.inverse();
    if (inverse is! InvertedTransform) {
      throw SvgFeatureRefusal(context.node.nodeIndex, 'svg-filter-transform');
    }
    final canvas = context.canvas;
    canvas.save();
    // An outer filter capture owns its deferred viewport clips. Replay only
    // this output's remaining clips, inside the picture consumed by postPaint.
    _clip(
      canvas,
      context.node.clips,
      excludedViewportClipIds: context._excludedViewportClipIds,
    );
    canvas.transform(_matrix(context.node.transform));
    canvas.clipRect(layout.region);
    canvas.transform(_matrix(inverse.transform));
    _drawFilter(canvas, context, source, use, layout);
    canvas.restore();
  }
}

const _supportedTags = {
  'filter',
  'feGaussianBlur',
  'feOffset',
  'feColorMatrix',
  'feFlood',
  'feComposite',
  'feBlend',
  'feMerge',
  'feMergeNode',
};

final _filterUrl = RegExp(r'''^url\(\s*["']?#[^\s"')]+["']?\s*\)$''');

void _validateFilterAttributes(Map<String, String> attributes, int node) {
  for (final key in ['filterUnits', 'primitiveUnits']) {
    final value = attributes[key];
    if (value != null &&
        value != 'userSpaceOnUse' &&
        value != 'objectBoundingBox') {
      throw SvgFeatureRefusal(node, 'svg-filter-units');
    }
  }
  final color = attributes['color-interpolation-filters']?.toLowerCase();
  if (color != null && color != 'srgb' && color != 'linearrgb') {
    throw SvgFeatureRefusal(node, 'svg-filter-color-space');
  }
}

final class _SvgFilterState {
  final uses = <String, _SvgFilterUse>{};
}

final class _SvgFilterUse {
  _SvgFilterUse(this.graph, this.rasterBudget, this.checkCancellation, int area)
    : payloadBudget = SceneResourceBudget(
        limits: {
          ...SceneResourceBudget.provisionalLimits,
          SceneResource.vectorBytes:
              GeometryAlphaFootprint.storageOverhead + area,
        },
      );
  final _SvgFilterGraph graph;
  final SceneResourceBudget rasterBudget, payloadBudget;
  final void Function() checkCancellation;
  _SvgFilterLayout? layout;
  ui.Rect? raster;
  bool intermediate = false, outerEffect = false;
  SceneResourceLease? _rasterLease, _payloadLease;
  final images = <ui.Image>[];
  final sourceOrdinals = <int>{};
  void admitRasters() {
    checkCancellation();
    final region = raster!;
    _rasterLease ??= rasterBudget.reserveLayer(
      region.width.toInt(),
      region.height.toInt(),
      buffers: graph.primitives.length + 5,
    );
  }

  void reservePayload(int bytes) {
    _payloadLease = payloadBudget.reserve({SceneResource.vectorBytes: bytes});
  }

  void closeImages() {
    for (final image in images) {
      image.dispose();
    }
    images.clear();
  }

  void dispose() {
    closeImages();
    _rasterLease?.release();
    _payloadLease?.release();
  }
}

ui.Rect _filterRasterRegion(AffineTransform transform, ui.Rect region) {
  final root = _bounds(transform, region);
  return ui.Rect.fromLTRB(
    root.left.floorToDouble(),
    root.top.floorToDouble(),
    root.right.ceilToDouble(),
    root.bottom.ceilToDouble(),
  );
}

final class _FilterLength {
  const _FilterLength(this.value, this.percent);
  final double value;
  final bool percent;
  double bbox(double reference) => (percent ? value / 100 : value) * reference;
  double user(double reference) => percent ? value / 100 * reference : value;
}

_FilterLength _length(String? raw, int node, {_FilterLength? fallback}) {
  if (raw == null) return fallback ?? const _FilterLength(0, false);
  final value = raw.trim();
  if (value.endsWith('%')) {
    final number = double.tryParse(value.substring(0, value.length - 1));
    if (number == null || !number.isFinite) {
      throw SvgFeatureRefusal(node, 'svg-filter-length', malformed: true);
    }
    return _FilterLength(number, true);
  }
  return _FilterLength(_number(value, node), false);
}

final class _SvgFilterGraph {
  _SvgFilterGraph(
    this.node,
    this.linear,
    this.objectBoundingBox,
    this.primitiveObjectBoundingBox,
    this.defaultInputs,
    this.resultIndex,
    this.x,
    this.y,
    this.width,
    this.height,
    this.primitives,
  );
  final int node;
  final bool linear, objectBoundingBox, primitiveObjectBoundingBox;
  final List<String> defaultInputs;
  final Map<String, int> resultIndex;
  final _FilterLength x, y, width, height;
  final List<_FilterPrimitive> primitives;
  int get work =>
      4 +
      primitives.length +
      primitives.fold<int>(
        0,
        (sum, primitive) => sum + _filterInputCount(primitive),
      );

  ui.Rect regionFor(ui.Rect bounds, ui.Size viewport) {
    if (objectBoundingBox) {
      return ui.Rect.fromLTWH(
        bounds.left + x.bbox(bounds.width),
        bounds.top + y.bbox(bounds.height),
        width.bbox(bounds.width),
        height.bbox(bounds.height),
      );
    }
    return ui.Rect.fromLTWH(
      x.user(viewport.width),
      y.user(viewport.height),
      width.user(viewport.width),
      height.user(viewport.height),
    );
  }

  _SvgFilterLayout layout(ui.Rect bounds, ui.Size viewport, int nodeIndex) {
    final region = regionFor(bounds, viewport);
    if (!region.isFinite) {
      throw SvgFeatureRefusal(nodeIndex, 'svg-filter-region');
    }
    if (region.width <= 0 || region.height <= 0) {
      return _SvgFilterLayout.empty(region);
    }
    final pixelWidth = region.width.ceil(), pixelHeight = region.height.ceil();
    final pixels = pixelWidth * pixelHeight;
    final cap = 2 * viewport.width.ceil() * viewport.height.ceil();
    if (pixelWidth <= 0 ||
        pixelHeight <= 0 ||
        pixelWidth > 4096 ||
        pixelHeight > 4096 ||
        pixels > cap) {
      throw SvgFeatureRefusal(nodeIndex, 'svg-filter-region');
    }
    return _SvgFilterLayout(region, pixelWidth, pixelHeight, [
      for (final primitive in primitives)
        _ResolvedFilterPrimitive(
          primitive,
          primitiveObjectBoundingBox
              ? (primitive.dx?.bbox(bounds.width) ?? 0)
              : (primitive.dx?.user(region.width) ?? 0),
          primitiveObjectBoundingBox
              ? (primitive.dy?.bbox(bounds.height) ?? 0)
              : (primitive.dy?.user(region.height) ?? 0),
          primitiveObjectBoundingBox
              ? primitive.sigmaX * bounds.width
              : primitive.sigmaX,
          primitiveObjectBoundingBox
              ? primitive.sigmaY * bounds.height
              : primitive.sigmaY,
          _subregion(primitive, bounds, region),
        ),
    ]);
  }

  ui.Rect _subregion(
    _FilterPrimitive primitive,
    ui.Rect bounds,
    ui.Rect region,
  ) {
    final x = primitive.x,
        y = primitive.y,
        width = primitive.width,
        height = primitive.height;
    if (x == null && y == null && width == null && height == null) {
      return region;
    }
    double coordinate(
      _FilterLength? length,
      double origin,
      double reference,
      double fallback,
    ) {
      if (length == null) return origin + fallback;
      if (primitiveObjectBoundingBox) return origin + length.bbox(reference);
      return length.percent ? origin + length.user(reference) : length.value;
    }

    double dimension(_FilterLength? length, double reference, double fallback) {
      if (length == null) return fallback;
      return primitiveObjectBoundingBox
          ? length.bbox(reference)
          : length.user(reference);
    }

    final basis = primitiveObjectBoundingBox ? bounds : region;
    return ui.Rect.fromLTWH(
      coordinate(x, basis.left, basis.width, region.left - basis.left),
      coordinate(y, basis.top, basis.height, region.top - basis.top),
      dimension(width, basis.width, region.width),
      dimension(height, basis.height, region.height),
    ).intersect(region);
  }
}

final class _SvgFilterLayout {
  _SvgFilterLayout(
    this.region,
    this.pixelWidth,
    this.pixelHeight,
    this.primitives,
  );
  _SvgFilterLayout.empty(this.region)
    : pixelWidth = 0,
      pixelHeight = 0,
      primitives = const [];
  final ui.Rect region;
  final int pixelWidth, pixelHeight;
  final List<_ResolvedFilterPrimitive> primitives;
}

final class _ResolvedFilterPrimitive {
  const _ResolvedFilterPrimitive(
    this.primitive,
    this.dx,
    this.dy,
    this.sigmaX,
    this.sigmaY,
    this.subregion,
  );
  final _FilterPrimitive primitive;
  final double dx, dy, sigmaX, sigmaY;
  final ui.Rect subregion;
}

enum _FilterKind { blur, offset, colorMatrix, flood, composite, blend, merge }

final class _FilterPrimitive {
  const _FilterPrimitive(
    this.kind, {
    this.input,
    this.input2,
    this.result,
    this.sigmaX = 0,
    this.sigmaY = 0,
    this.dx,
    this.dy,
    this.matrix,
    this.floodColor = const ui.Color(0xff000000),
    this.floodOpacity = 1,
    this.operator,
    this.blendMode,
    this.mergeInputs = const [],
    this.x,
    this.y,
    this.width,
    this.height,
  });
  final _FilterKind kind;
  final String? input, input2, result;
  final double sigmaX, sigmaY;
  final _FilterLength? dx, dy;
  final List<double>? matrix;
  final ui.Color floodColor;
  final double floodOpacity;
  final ui.BlendMode? operator, blendMode;
  final List<String?> mergeInputs;
  final _FilterLength? x, y, width, height;
}

int _filterInputCount(_FilterPrimitive primitive) => switch (primitive.kind) {
  _FilterKind.flood => 0,
  _FilterKind.composite || _FilterKind.blend => 2,
  _FilterKind.merge => primitive.mergeInputs.length,
  _ => 1,
};

_SvgFilterGraph _parseGraph(SvgGraphicsPlan plan, int filterIndex) {
  final filter = plan.document.node(filterIndex);
  if (filter.namespaceUri != 'http://www.w3.org/2000/svg' ||
      filter.localName != 'filter') {
    throw SvgFeatureRefusal(filterIndex, 'svg-filter-target');
  }
  final attributes = plan._attributes(filterIndex);
  _validateFilterAttributes(attributes, filterIndex);
  final objectBoundingBox =
      (attributes['filterUnits'] ?? 'objectBoundingBox') != 'userSpaceOnUse';
  final primitiveObjectBoundingBox =
      (attributes['primitiveUnits'] ?? 'userSpaceOnUse') == 'objectBoundingBox';
  final linear =
      (attributes['color-interpolation-filters'] ?? 'linearRGB')
          .toLowerCase() !=
      'srgb';
  final primitives = <_FilterPrimitive>[];
  final available = <String>{'SourceGraphic', 'SourceAlpha'};
  final defaultInputs = <String>[];
  final resultIndex = <String, int>{};
  var previous = 'SourceGraphic';
  var inputCount = 0;
  for (final childIndex in filter.children) {
    final child = plan.document.node(childIndex);
    if (child.localName == null) continue;
    if (child.namespaceUri != 'http://www.w3.org/2000/svg') {
      throw SvgFeatureRefusal(childIndex, 'svg-${child.localName}');
    }
    final tag = child.localName!;
    if (tag == 'title' || tag == 'desc') continue;
    if (!_supportedTags.contains(tag) || tag == 'filter') {
      throw SvgFeatureRefusal(childIndex, 'svg-$tag');
    }
    if (tag == 'feMergeNode') {
      throw SvgFeatureRefusal(childIndex, 'svg-feMergeNode');
    }
    if (primitives.length >= 24) {
      throw SvgFeatureRefusal(filterIndex, 'svg-filter-complexity');
    }
    final primitive = _primitive(
      plan,
      childIndex,
      tag,
      plan._attributes(childIndex),
    );
    inputCount += _filterInputCount(primitive);
    if (inputCount > 256) {
      throw SvgFeatureRefusal(filterIndex, 'svg-filter-complexity');
    }
    final input = primitive.input;
    if (input != null && !available.contains(input)) {
      throw SvgFeatureRefusal(childIndex, 'svg-filter-reference');
    }
    final input2 = primitive.input2;
    if (input2 != null && !available.contains(input2)) {
      throw SvgFeatureRefusal(childIndex, 'svg-filter-reference');
    }
    for (final merge in primitive.mergeInputs) {
      if (merge != null && !available.contains(merge)) {
        throw SvgFeatureRefusal(childIndex, 'svg-filter-reference');
      }
    }
    final name = primitive.result ?? '__result-${primitives.length}';
    if (primitive.result != null && !available.add(name)) {
      throw SvgFeatureRefusal(childIndex, 'svg-filter-result');
    }
    defaultInputs.add(previous);
    resultIndex[name] = primitives.length;
    primitives.add(primitive);
    previous = name;
  }
  return _SvgFilterGraph(
    filterIndex,
    linear,
    objectBoundingBox,
    primitiveObjectBoundingBox,
    defaultInputs,
    resultIndex,
    _length(
      attributes['x'],
      filterIndex,
      fallback: const _FilterLength(-10, true),
    ),
    _length(
      attributes['y'],
      filterIndex,
      fallback: const _FilterLength(-10, true),
    ),
    _length(
      attributes['width'],
      filterIndex,
      fallback: const _FilterLength(120, true),
    ),
    _length(
      attributes['height'],
      filterIndex,
      fallback: const _FilterLength(120, true),
    ),
    primitives,
  );
}

_FilterPrimitive _primitive(
  SvgGraphicsPlan plan,
  int node,
  String tag,
  Map<String, String> attributes,
) {
  String? input = attributes['in'];
  String? input2 = attributes['in2'];
  final result = attributes['result'];
  if (result != null && result.trim().isEmpty) {
    throw SvgFeatureRefusal(node, 'svg-filter-result');
  }
  final x = attributes.containsKey('x') ? _length(attributes['x'], node) : null;
  final y = attributes.containsKey('y') ? _length(attributes['y'], node) : null;
  final width = attributes.containsKey('width')
      ? _length(attributes['width'], node)
      : null;
  final height = attributes.containsKey('height')
      ? _length(attributes['height'], node)
      : null;
  switch (tag) {
    case 'feGaussianBlur':
      final raw = attributes['stdDeviation'];
      final values = raw == null
          ? const <double>[]
          : raw
                .trim()
                .split(RegExp(r'[\s,]+'))
                .where((v) => v.isNotEmpty)
                .map((v) => _number(v, node))
                .toList();
      if (values.length > 2 || values.any((v) => v < 0)) {
        throw SvgFeatureRefusal(node, 'svg-feGaussianBlur-stdDeviation');
      }
      return _FilterPrimitive(
        _FilterKind.blur,
        input: input,
        result: result,
        sigmaX: values.isEmpty ? 0 : values[0],
        sigmaY: values.length < 2
            ? (values.isEmpty ? 0 : values[0])
            : values[1],
        x: x,
        y: y,
        width: width,
        height: height,
      );
    case 'feOffset':
      return _FilterPrimitive(
        _FilterKind.offset,
        input: input,
        result: result,
        dx: _length(attributes['dx'], node),
        dy: _length(attributes['dy'], node),
        x: x,
        y: y,
        width: width,
        height: height,
      );
    case 'feColorMatrix':
      final type = (attributes['type'] ?? 'matrix').toLowerCase();
      final matrix = _colorMatrix(type, attributes['values'], node);
      return _FilterPrimitive(
        _FilterKind.colorMatrix,
        input: input,
        result: result,
        matrix: matrix,
        x: x,
        y: y,
        width: width,
        height: height,
      );
    case 'feFlood':
      final color = _filterColor(attributes['flood-color'] ?? 'black', node);
      final opacity = _number(
        attributes['flood-opacity'],
        node,
        fallback: 1,
        basis: 1,
      ).clamp(0.0, 1.0);
      return _FilterPrimitive(
        _FilterKind.flood,
        result: result,
        floodColor: color,
        floodOpacity: opacity,
        x: x,
        y: y,
        width: width,
        height: height,
      );
    case 'feComposite':
      final name = (attributes['operator'] ?? 'over').toLowerCase();
      final operator = _compositeMode[name];
      if (operator == null) {
        throw SvgFeatureRefusal(node, 'svg-feComposite-operator');
      }
      if (attributes.keys.any(const {'k1', 'k2', 'k3', 'k4'}.contains)) {
        throw SvgFeatureRefusal(node, 'svg-feComposite-arithmetic');
      }
      return _FilterPrimitive(
        _FilterKind.composite,
        input: input,
        input2: input2,
        result: result,
        operator: operator,
        x: x,
        y: y,
        width: width,
        height: height,
      );
    case 'feBlend':
      final mode = (attributes['mode'] ?? 'normal').toLowerCase();
      final blend = _blendModes[mode];
      if (blend == null) throw SvgFeatureRefusal(node, 'svg-feBlend-mode');
      return _FilterPrimitive(
        _FilterKind.blend,
        input: input,
        input2: input2,
        result: result,
        blendMode: blend,
        x: x,
        y: y,
        width: width,
        height: height,
      );
    case 'feMerge':
      final mergeInputs = <String?>[];
      for (final childIndex in plan.document.node(node).children) {
        final child = plan.document.node(childIndex);
        if (child.localName == null) continue;
        if (child.localName != 'feMergeNode') {
          throw SvgFeatureRefusal(childIndex, 'svg-${child.localName}');
        }
        if (mergeInputs.length >= 256) {
          throw SvgFeatureRefusal(node, 'svg-filter-complexity');
        }
        mergeInputs.add(child.attribute('in'));
      }
      return _FilterPrimitive(
        _FilterKind.merge,
        result: result,
        mergeInputs: mergeInputs,
        x: x,
        y: y,
        width: width,
        height: height,
      );
  }
  throw SvgFeatureRefusal(node, 'svg-$tag');
}

void _drawFilter(
  ui.Canvas canvas,
  SvgFeaturePaint context,
  ui.Picture source,
  _SvgFilterUse use,
  _SvgFilterLayout layout,
) {
  final node = context.node;
  final graph = use.graph;
  final inverse = node.transform.inverse();
  if (inverse is! InvertedTransform) {
    throw SvgFeatureRefusal(node.nodeIndex, 'svg-filter-transform');
  }
  final regionRoot = _filterRasterRegion(node.transform, layout.region);
  final outputCanvas = canvas;
  final results = <int, ui.Image>{};
  final sources = <String, ui.Image>{};
  ui.Image rasterize(void Function() draw) {
    use.checkCancellation();
    final recorder = ui.PictureRecorder();
    final previous = canvas;
    canvas = ui.Canvas(recorder);
    canvas.translate(-regionRoot.left, -regionRoot.top);
    canvas.clipRect(regionRoot);
    ui.Picture? picture;
    try {
      draw();
      picture = recorder.endRecording();
      final image = picture.toImageSync(
        regionRoot.width.toInt(),
        regionRoot.height.toInt(),
      );
      use.images.add(image);
      return image;
    } finally {
      canvas = previous;
      if (recorder.isRecording) recorder.endRecording().dispose();
      picture?.dispose();
    }
  }

  void drawImage(ui.Image image) => canvas.drawImage(
    image,
    regionRoot.topLeft,
    ui.Paint()..filterQuality = ui.FilterQuality.none,
  );
  final scaleX = math.sqrt(
    node.transform.a * node.transform.a + node.transform.b * node.transform.b,
  );
  final scaleY = math.sqrt(
    node.transform.c * node.transform.c + node.transform.d * node.transform.d,
  );

  // The paint wrapper is called in root space. Clip with the local region then
  // return to root coordinates so the captured source keeps its own mapping.
  void withLocalClip(ui.Rect local, void Function() draw) {
    canvas.save();
    canvas.transform(_matrix(node.transform));
    canvas.clipRect(local);
    canvas.transform(_matrix(inverse.transform));
    draw();
    canvas.restore();
  }

  void drawSource() {
    if (!graph.linear) {
      canvas.drawPicture(source);
      return;
    }
    canvas.saveLayer(
      regionRoot,
      ui.Paint()..colorFilter = const ui.ColorFilter.srgbToLinearGamma(),
    );
    canvas.drawPicture(source);
    canvas.restore();
  }

  void drawSourceAlpha() {
    canvas.saveLayer(
      regionRoot,
      ui.Paint()..colorFilter = ui.ColorFilter.matrix(_alphaMatrix),
    );
    canvas.drawPicture(source);
    canvas.restore();
  }

  late void Function(String) drawInput;

  void drawPrimitive(int index) {
    final resolved = layout.primitives[index];
    final primitive = resolved.primitive;
    final sub = resolved.subregion;
    if (sub.isEmpty) return;
    final bounds = _bounds(node.transform, sub);
    final input = primitive.input ?? graph.defaultInputs[index];
    final input2 = primitive.input2 ?? graph.defaultInputs[index];
    withLocalClip(sub, () {
      switch (primitive.kind) {
        case _FilterKind.blur:
          canvas.saveLayer(
            bounds,
            ui.Paint()
              ..imageFilter = ui.ImageFilter.blur(
                sigmaX: resolved.sigmaX * scaleX,
                sigmaY: resolved.sigmaY * scaleY,
                tileMode: ui.TileMode.decal,
              ),
          );
          drawInput(input);
          canvas.restore();
        case _FilterKind.offset:
          canvas.translate(
            node.transform.a * resolved.dx + node.transform.c * resolved.dy,
            node.transform.b * resolved.dx + node.transform.d * resolved.dy,
          );
          drawInput(input);
        case _FilterKind.colorMatrix:
          canvas.saveLayer(
            bounds,
            ui.Paint()..colorFilter = ui.ColorFilter.matrix(primitive.matrix!),
          );
          drawInput(input);
          canvas.restore();
        case _FilterKind.flood:
          canvas.save();
          canvas.transform(_matrix(node.transform));
          canvas.drawRect(
            sub,
            ui.Paint()..color = _filterPaintColor(primitive, graph.linear),
          );
          canvas.restore();
        case _FilterKind.composite:
          canvas.saveLayer(bounds, ui.Paint());
          drawInput(input2);
          canvas.saveLayer(bounds, ui.Paint()..blendMode = primitive.operator!);
          drawInput(input);
          canvas.restore();
          canvas.restore();
        case _FilterKind.blend:
          canvas.saveLayer(bounds, ui.Paint());
          drawInput(input2);
          canvas.saveLayer(
            bounds,
            ui.Paint()..blendMode = primitive.blendMode!,
          );
          drawInput(input);
          canvas.restore();
          canvas.restore();
        case _FilterKind.merge:
          canvas.saveLayer(bounds, ui.Paint());
          for (final merge in primitive.mergeInputs) {
            drawInput(merge ?? graph.defaultInputs[index]);
          }
          canvas.restore();
      }
    });
  }

  drawInput = (String name) {
    if (name == 'SourceGraphic') {
      drawImage(sources[name]!);
      return;
    }
    if (name == 'SourceAlpha') {
      drawImage(sources[name]!);
      return;
    }
    final index = graph.resultIndex[name];
    if (index == null) {
      throw SvgFeatureRefusal(node.nodeIndex, 'svg-filter-reference');
    }
    final image = results[index];
    if (image == null) {
      throw SvgFeatureRefusal(node.nodeIndex, 'svg-filter-reference');
    }
    drawImage(image);
  };

  // Graph admission only permits preceding results. Materializing each stage
  // breaks recursive picture replay as well as repeated dependency evaluation.
  sources['SourceGraphic'] = rasterize(drawSource);
  sources['SourceAlpha'] = rasterize(drawSourceAlpha);
  for (var index = 0; index < layout.primitives.length; index++) {
    results[index] = rasterize(() => drawPrimitive(index));
  }
  canvas = outputCanvas;
  canvas.saveLayer(regionRoot, ui.Paint());
  if (graph.linear) {
    canvas.saveLayer(
      regionRoot,
      ui.Paint()..colorFilter = const ui.ColorFilter.linearToSrgbGamma(),
    );
  }
  if (layout.primitives.isEmpty) {
    drawImage(sources['SourceGraphic']!);
  } else {
    drawImage(results[layout.primitives.length - 1]!);
  }
  if (graph.linear) canvas.restore();
  canvas.restore();
}

ui.Color _filterPaintColor(_FilterPrimitive primitive, bool linear) {
  final alpha = primitive.floodColor.a * primitive.floodOpacity;
  if (!linear) return primitive.floodColor.withValues(alpha: alpha);
  double channel(double value) => value <= .04045
      ? value / 12.92
      : math.pow((value + .055) / 1.055, 2.4).toDouble();
  return ui.Color.fromRGBO(
    (channel(primitive.floodColor.r) * 255).round(),
    (channel(primitive.floodColor.g) * 255).round(),
    (channel(primitive.floodColor.b) * 255).round(),
    alpha,
  );
}

const _alphaMatrix = <double>[
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

const _compositeMode = <String, ui.BlendMode>{
  'over': ui.BlendMode.srcOver,
  'in': ui.BlendMode.srcIn,
  'out': ui.BlendMode.srcOut,
  'atop': ui.BlendMode.srcATop,
  'xor': ui.BlendMode.xor,
  'lighter': ui.BlendMode.plus,
};

const _blendModes = <String, ui.BlendMode>{
  'normal': ui.BlendMode.srcOver,
  'multiply': ui.BlendMode.multiply,
  'screen': ui.BlendMode.screen,
  'overlay': ui.BlendMode.overlay,
  'darken': ui.BlendMode.darken,
  'lighten': ui.BlendMode.lighten,
  'color-dodge': ui.BlendMode.colorDodge,
  'color-burn': ui.BlendMode.colorBurn,
  'hard-light': ui.BlendMode.hardLight,
  'soft-light': ui.BlendMode.softLight,
  'difference': ui.BlendMode.difference,
  'exclusion': ui.BlendMode.exclusion,
  'hue': ui.BlendMode.hue,
  'saturation': ui.BlendMode.saturation,
  'color': ui.BlendMode.color,
  'luminosity': ui.BlendMode.luminosity,
};

List<double> _colorMatrix(String type, String? raw, int node) {
  if (type == 'matrix') {
    if (raw == null) throw SvgFeatureRefusal(node, 'svg-feColorMatrix-values');
    final values = _numbers(raw, node);
    if (values.length != 20) {
      throw SvgFeatureRefusal(node, 'svg-feColorMatrix-values');
    }
    for (final offset in const [4, 9, 14, 19]) {
      values[offset] *= 255;
    }
    return values;
  }
  final values = raw == null ? <double>[] : _numbers(raw, node);
  if (type == 'saturate') {
    final s = values.length == 1 ? values.single : null;
    if (s == null) throw SvgFeatureRefusal(node, 'svg-feColorMatrix-values');
    return [
      0.213 + 0.787 * s,
      0.715 - 0.715 * s,
      0.072 - 0.072 * s,
      0,
      0,
      0.213 - 0.213 * s,
      0.715 + 0.285 * s,
      0.072 - 0.072 * s,
      0,
      0,
      0.213 - 0.213 * s,
      0.715 - 0.715 * s,
      0.072 + 0.928 * s,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }
  if (type == 'huerotate') {
    final angle = values.length == 1 ? values.single : null;
    if (angle == null) {
      throw SvgFeatureRefusal(node, 'svg-feColorMatrix-values');
    }
    final radians = angle * math.pi / 180, cos = math.cos(radians);
    final sin = math.sin(radians);
    return [
      0.213 + cos * 0.787 - sin * 0.213,
      0.715 - cos * 0.715 - sin * 0.715,
      0.072 - cos * 0.072 + sin * 0.928,
      0,
      0,
      0.213 - cos * 0.213 + sin * 0.143,
      0.715 + cos * 0.285 + sin * 0.140,
      0.072 - cos * 0.072 - sin * 0.283,
      0,
      0,
      0.213 - cos * 0.213 - sin * 0.787,
      0.715 - cos * 0.715 + sin * 0.715,
      0.072 + cos * 0.928 + sin * 0.072,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }
  if (type == 'luminancetoalpha') {
    return [
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0.2125,
      0.7154,
      0.0721,
      0,
      0,
    ];
  }
  throw SvgFeatureRefusal(node, 'svg-feColorMatrix-type');
}

const _namedColors = <String, int>{
  'black': 0xff000000,
  'silver': 0xffc0c0c0,
  'gray': 0xff808080,
  'grey': 0xff808080,
  'white': 0xffffffff,
  'maroon': 0xff800000,
  'red': 0xffff0000,
  'purple': 0xff800080,
  'fuchsia': 0xffff00ff,
  'magenta': 0xffff00ff,
  'green': 0xff008000,
  'lime': 0xff00ff00,
  'olive': 0xff808000,
  'yellow': 0xffffff00,
  'navy': 0xff000080,
  'blue': 0xff0000ff,
  'teal': 0xff008080,
  'aqua': 0xff00ffff,
  'cyan': 0xff00ffff,
  'orange': 0xffffa500,
  'transparent': 0x00000000,
};

ui.Color _filterColor(String raw, int node) {
  final value = raw.trim().toLowerCase();
  final named = _namedColors[value];
  if (named != null) return ui.Color(named);
  if (value.startsWith('#')) {
    final body = value.substring(1);
    if (!RegExp(r'^[0-9a-f]+$').hasMatch(body)) {
      throw SvgFeatureRefusal(node, 'svg-feFlood-color');
    }
    final expanded = switch (body.length) {
      3 => 'ff${body[0]}${body[0]}${body[1]}${body[1]}${body[2]}${body[2]}',
      4 =>
        '${body[3]}${body[3]}${body[0]}${body[0]}${body[1]}${body[1]}'
            '${body[2]}${body[2]}',
      6 => 'ff$body',
      8 => '${body.substring(6)}${body.substring(0, 6)}',
      _ => throw SvgFeatureRefusal(node, 'svg-feFlood-color'),
    };
    return ui.Color(int.parse(expanded, radix: 16));
  }
  final match = RegExp(r'^rgba?\(\s*([^)]*)\)$').firstMatch(value);
  if (match != null) {
    final parts = match[1]!
        .split(RegExp(r'[\s,\/]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length < 3 || parts.length > 4) {
      throw SvgFeatureRefusal(node, 'svg-feFlood-color');
    }
    int channel(String raw) {
      final numeric = raw.endsWith('%')
          ? _number(raw, node, basis: 255)
          : _number(raw, node);
      return numeric.round().clamp(0, 255);
    }

    final alpha = parts.length == 4
        ? (parts[3].endsWith('%')
                  ? _number(parts[3], node, basis: 1)
                  : _number(parts[3], node))
              .clamp(0.0, 1.0)
        : 1.0;
    return ui.Color.fromARGB(
      (alpha * 255).round(),
      channel(parts[0]),
      channel(parts[1]),
      channel(parts[2]),
    );
  }
  throw SvgFeatureRefusal(node, 'svg-feFlood-color');
}
