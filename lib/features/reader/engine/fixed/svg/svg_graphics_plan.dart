part of 'svg_graphics.dart';

/// No native paths, images or pictures are allocated by inspection. The caller
/// can include [resources] in its whole-unit reservation before preparation.
final class SvgGraphicsPlan {
  SvgGraphicsPlan._(
    this.document,
    this.rootIndex,
    this.page,
    this.size,
    this.presentation,
    this.placement,
    this.host,
    this.features,
    this.evidenceSize,
    this.evidenceOrigin,
    this.preparationScale,
  );
  factory SvgGraphicsPlan.inspect({
    required SourceDocument document,
    required int rootIndex,
    required SourcePageId page,
    required AuthoredPageSize size,
    AuthoredPageSize? evidenceSize,
    GeometryPoint? evidenceOrigin,
    FixedPreparationScale preparationScale =
        const FixedPreparationScale.authored(),
    Map<int, Map<String, String>> resolvedPresentation = const {},
    List<String> presentationProblems = const [],
    AffineTransform placement = const AffineTransform.identity(),
    SvgFeatureHost host = const SvgFeatureHost.unavailable(),
    SvgFeatureRegistry? features,
  }) {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    final featureRegistry = features ?? SvgFeatureRegistry.defaults;
    final plan = SvgGraphicsPlan._(
      document,
      rootIndex,
      page,
      size,
      Map.unmodifiable({
        for (final e in resolvedPresentation.entries)
          e.key: Map<String, String>.unmodifiable(e.value),
      }),
      placement,
      host,
      featureRegistry,
      evidenceSize,
      evidenceOrigin,
      preparationScale,
    );
    try {
      if (presentationProblems.isNotEmpty) {
        throw _SvgFailure(rootIndex, presentationProblems.first);
      }
      for (final n in document.nodes) {
        if (n.id != null && n.id!.isNotEmpty) {
          if (plan._ids.containsKey(n.id)) {
            throw _SvgFailure(n.index, 'duplicate-svg-id', malformed: true);
          }
          plan._ids[n.id!] = n.index;
        }
      }
      plan._audit(rootIndex, {}, 0, 0);
      plan.capability = CompleteSectionCapability(
        sectionIndex: page.sectionIndex,
        reason: 'Source-aware SVG input inspected; preparation still required',
      );
    } on _SvgFailure catch (e) {
      plan.capability = plan._failure(e);
    } on SvgFeatureRefusal catch (e) {
      plan.capability = plan._failure(
        _SvgFailure(e.node, e.identifier, malformed: e.malformed),
      );
    } on FormatException {
      plan.capability = plan._failure(
        _SvgFailure(rootIndex, 'svg-path-data', malformed: true),
      );
    } on SceneAdmissionException catch (e) {
      plan.capability = ResourceSectionCapability(
        sectionIndex: page.sectionIndex,
        reason: 'SVG complexity limit refused before allocation',
        constructs: [
          OffendingConstruct(
            kind: CapabilityConstructKind.resource,
            identifier:
                'svg-${e.resource?.name ?? e.depth?.name ?? e.failure.name}',
          ),
        ],
      );
    }
    return plan;
  }
  final SourceDocument document;
  final int rootIndex;
  final SourcePageId page;
  final AuthoredPageSize size;

  /// Enclosing authored raster, independent of the SVG's replaced viewport.
  final AuthoredPageSize? evidenceSize;
  final GeometryPoint? evidenceOrigin;
  final FixedPreparationScale preparationScale;
  int get displayPixels =>
      preparationScale.pixels(size.width) *
      preparationScale.pixels(size.height);

  /// Follow instantiated references as well as children into filtered inputs.
  late final Set<int> authoredImageNodes = _authoredImageNodes();
  Set<int> _authoredImageNodes() {
    final result = <int>{}, visited = <(int, bool)>{};
    void visit(int index, bool filtered) {
      final filter = _attributes(index)['filter'];
      filtered = filtered || filter != null && filter.toLowerCase() != 'none';
      if (!visited.add((index, filtered))) return;
      if (filtered) result.add(index);
      for (final child in document.node(index).children) {
        visit(child, filtered);
      }
      for (final edge in _references.where((r) => r.source == index)) {
        visit(edge.target, filtered);
      }
    }

    visit(rootIndex, false);
    return Set.unmodifiable(result);
  }

  late final Set<String> authoredImagePaths = Set.unmodifiable({
    for (final index in authoredImageNodes)
      if (document.node(index).localName == 'image')
        if ((_attributes(index)['href'] ?? _attributes(index)['xlink:href'])
            case final String path)
          path,
  });
  final Map<int, Map<String, String>> presentation;
  final AffineTransform placement;
  final SvgFeatureHost host;
  final SvgFeatureRegistry features;
  final Map<String, int> _ids = {};
  final Map<SceneResource, int> _resources = {};
  var _featureLayerPixels = 0, _featureLayerBytes = 0;
  var _filterRasterPixels = 0, _filterEvidencePixels = 0;
  var _coverageMaps = 0;

  /// Filter payload admitted for retained filtered output footprints.
  var _filterRetainedBytes = 0;
  final List<({int source, int target, String attribute})> _references = [];
  List<({int source, int target, String attribute})> get references =>
      List.unmodifiable(_references);
  Map<SceneResource, int> get resources => Map.unmodifiable(_resources);
  late final SectionCapability capability;
  int sourceDepth = 0, referenceDepth = 0, layerDepth = 0;

  /// Round outwards on the authored root grid, preserving fractional placement.
  ui.Rect _evidenceBounds([AffineTransform? placement]) {
    final enclosing = evidenceSize;
    if (enclosing != null) {
      final x = evidenceOrigin?.x ?? 0, y = evidenceOrigin?.y ?? 0;
      return _checkedEvidenceBounds(
        ui.Rect.fromLTRB(
          x.floorToDouble(),
          y.floorToDouble(),
          (x + enclosing.width).ceilToDouble(),
          (y + enclosing.height).ceilToDouble(),
        ),
      );
    }
    final attrs = _attributes(rootIndex);
    final t = (placement ?? this.placement)
        .compose(_svgTransform(attrs['transform'], rootIndex))
        .compose(
          _translate(
            _number(attrs['x'], rootIndex, basis: size.width),
            _number(attrs['y'], rootIndex, basis: size.height),
          ),
        );
    // Preserve the authored pixel phase and the complete root-coordinate raster.
    var left = 0.0, top = 0.0, right = size.width, bottom = size.height;
    for (final x in [0.0, size.width]) {
      for (final y in [0.0, size.height]) {
        final px = t.a * x + t.c * y + t.e;
        final py = t.b * x + t.d * y + t.f;
        left = math.min(left, px);
        top = math.min(top, py);
        right = math.max(right, px);
        bottom = math.max(bottom, py);
      }
    }
    return _checkedEvidenceBounds(
      ui.Rect.fromLTRB(
        left.floorToDouble(),
        top.floorToDouble(),
        right.ceilToDouble(),
        bottom.ceilToDouble(),
      ),
    );
  }

  ui.Rect _checkedEvidenceBounds(ui.Rect bounds) {
    final cap =
        SceneResourceBudget.provisionalLimits[SceneResource.layerPixels]!;
    if (!bounds.isFinite ||
        bounds.width <= 0 ||
        bounds.height <= 0 ||
        bounds.width > cap ||
        bounds.height > cap ||
        bounds.width > cap ~/ bounds.height.toInt()) {
      throw const SceneAdmissionException(
        SceneAdmissionFailure.resourceExhausted,
        resource: SceneResource.layerPixels,
      );
    }
    return bounds;
  }

  /// Serial whole authored raster plus one bounded tile image/readback pair.
  int get evidencePixels => _evidencePixels(_evidenceBounds());

  int _evidencePixels(ui.Rect bounds) => math.max(
    _filterEvidencePixels,
    _coverageMaps == 0
        ? 0
        : AuthoredEvidenceRaster.scratchPixels(
            bounds.width.toInt(),
            bounds.height.toInt(),
          ),
  );

  /// Safe predecode upper bound of the retained alpha footprints this plan can
  /// publish: one authored-grid map per coverage claim plus the filter outputs.
  /// It is the part of [reservation] that exact reconciliation may shrink to
  /// the stored footprint bytes once preparation has published.
  int get retainedEvidenceBytes =>
      _coverageEvidenceBytes(_evidenceBounds()) + _filterRetainedBytes;

  int _coverageEvidenceBytes(ui.Rect evidence) =>
      _coverageMaps *
      (evidence.width.toInt() * evidence.height.toInt() +
          GeometryAlphaFootprint.storageOverhead);

  /// Base payload/alpha/scratch reservation. Pattern tiles and dash expansion
  /// make additional admissions in the supplied ledger before their recording.
  Map<SceneResource, int> reservation({
    double hostOpacity = 1,
    AffineTransform? placement,
  }) {
    final width = preparationScale.pixels(size.width),
        height = preparationScale.pixels(size.height);
    final evidence = _evidenceBounds(placement);
    final evidencePixels = _evidencePixels(evidence);
    final buffers = layerDepth + (hostOpacity == 1 ? 0 : 1);
    final cap =
        SceneResourceBudget.provisionalLimits[SceneResource.layerPixels]!;
    if (width > cap ||
        height > cap ||
        width > cap ~/ height ||
        (buffers > 0 && width * height > cap ~/ buffers)) {
      throw const SceneAdmissionException(
        SceneAdmissionFailure.resourceExhausted,
        resource: SceneResource.layerPixels,
      );
    }
    final pixels = width * height;
    final layerPixels =
            pixels * buffers +
            evidencePixels +
            _featureLayerPixels +
            _filterRasterPixels,
        layerBytes =
            (pixels * buffers + evidencePixels + _filterRasterPixels) * 4 +
            _featureLayerBytes;
    if (layerPixels >
            SceneResourceBudget.provisionalLimits[SceneResource.layerPixels]! ||
        layerBytes >
            SceneResourceBudget.provisionalLimits[SceneResource.layerBytes]!) {
      throw const SceneAdmissionException(
        SceneAdmissionFailure.resourceExhausted,
        resource: SceneResource.layerPixels,
      );
    }
    return Map.unmodifiable({
      ...resources,
      SceneResource.vectorBytes:
          (resources[SceneResource.vectorBytes] ?? 0) +
          _coverageEvidenceBytes(evidence) +
          2 * 1024 * 1024,
      SceneResource.layerPixels: layerPixels,
      SceneResource.layerBytes: layerBytes,
    });
  }

  SectionCapability _failure(_SvgFailure e) {
    final constructs = [
      OffendingConstruct(
        kind: CapabilityConstructKind.svg,
        identifier: e.identifier,
        nodeIndex: e.node,
      ),
    ];
    return e.malformed
        ? MalformedSectionCapability(
            sectionIndex: page.sectionIndex,
            reason: 'Malformed SVG graphics input',
            constructs: constructs,
          )
        : UnsupportedSectionCapability(
            sectionIndex: page.sectionIndex,
            reason: 'Unsupported SVG graphics input',
            constructs: constructs,
          );
  }

  Map<String, String> _attributes(int index) => {
    for (final a in document.node(index).attributes)
      if (a.qualifiedName != 'style') a.qualifiedName: a.value,
    ...?presentation[index],
  };
  int _reference(int index, String value) {
    final match = RegExp(r'''^url\(\s*["']?#([^\s"')]+)["']?\s*\)$''')
        .firstMatch(value);
    final id = value.startsWith('#') ? value.substring(1) : match?.group(1);
    if (id == null || !_ids.containsKey(id)) {
      throw _SvgFailure(index, 'unresolved-or-external-svg-reference');
    }
    return _ids[id]!;
  }

  void _charge(SceneResource resource, int amount) {
    final total = (_resources[resource] ?? 0) + amount;
    if (total > SceneResourceBudget.provisionalLimits[resource]!) {
      throw SceneAdmissionException(
        SceneAdmissionFailure.complexityExceeded,
        resource: resource,
      );
    }
    _resources[resource] = total;
  }

  void _chargeLayers({required int pixels, required int bytes}) {
    if (pixels < 0 || bytes < 0) {
      throw ArgumentError('Negative feature layer reservation');
    }
    final authoredPixels = size.width.ceil() * size.height.ceil();
    _featureLayerPixels += (pixels * displayPixels / authoredPixels).ceil();
    _featureLayerBytes += (bytes * displayPixels / authoredPixels).ceil();
  }

  void _addReference(int source, int target, String attribute) =>
      _references.add((source: source, target: target, attribute: attribute));

  /// Marker/pattern content builders do not run the feature lifecycle yet.
  void _refuseFeatureExclusion(int index, Set<int> active) {
    var marker = false, pattern = false;
    for (final ancestor in active) {
      final tag = document.node(ancestor).localName;
      if (tag == 'marker') marker = true;
      if (tag == 'pattern') pattern = true;
    }
    if (marker) {
      throw SvgFeatureRefusal(index, 'svg-feature-in-marker');
    }
    if (pattern) {
      throw SvgFeatureRefusal(index, 'svg-feature-in-pattern');
    }
  }

  void _audit(
    int index,
    Set<int> active,
    int depth,
    int refs, {
    Map<String, String> inherited = const {},
  }) {
    if (depth > SceneResourceBudget.maxSourceDepth ||
        refs > SceneResourceBudget.maxReferenceDepth) {
      throw SceneAdmissionException(
        SceneAdmissionFailure.complexityExceeded,
        depth: refs > SceneResourceBudget.maxReferenceDepth
            ? SceneDepth.reference
            : SceneDepth.source,
      );
    }
    sourceDepth = math.max(sourceDepth, depth);
    referenceDepth = math.max(referenceDepth, refs);
    if (active.contains(index)) {
      throw _SvgFailure(index, 'svg-reference-cycle', malformed: true);
    }
    final n = document.node(index);
    if (n.isCharacterData && (n.text ?? '').trim().isEmpty) return;
    final localName = n.localName;
    if (n.namespaceUri != 'http://www.w3.org/2000/svg' ||
        (!_svgTags.contains(localName) && !features.ownsTag(localName))) {
      throw _SvgFailure(index, 'svg-${localName ?? 'node'}');
    }
    final attrs = {...inherited, ..._attributes(index)};
    final admitted = <SvgFeature>{};
    for (final feature in features.ownersForNode(localName, const [])) {
      admitted.add(feature);
      feature.admit(SvgFeatureAdmission._(this, index, localName, attrs));
      _refuseFeatureExclusion(index, active);
    }
    _validateSvgValues(index, attrs);
    if ((_shapes.contains(n.localName) ||
            const {'image', 'stop'}.contains(n.localName)) &&
        n.children.any((child) => document.node(child).localName != null)) {
      throw _SvgFailure(index, 'svg-leaf-children', malformed: true);
    }
    if (n.attribute('style') != null && !presentation.containsKey(index)) {
      throw _SvgFailure(index, 'svg-style-resolution-required');
    }
    final layers = [...active, index].fold<int>(0, (sum, node) {
      final a = _attributes(node), opacity = a['opacity'];
      final paintLayer =
          a.values.any((v) => v.startsWith('url(')) ||
          a['stroke-dasharray'] != null && a['stroke-dasharray'] != 'none';
      return sum +
          (opacity != null && _number(opacity, node, fallback: 1) != 1
              ? 1
              : 0) +
          (paintLayer ? 2 : 0);
    });
    layerDepth = math.max(layerDepth, layers);
    if (layerDepth > SceneResourceBudget.maxLayerDepth) {
      throw const SceneAdmissionException(
        SceneAdmissionFailure.complexityExceeded,
        depth: SceneDepth.layer,
      );
    }
    for (final a in attrs.entries) {
      if (!_svgAttributes.contains(a.key) &&
          !a.key.startsWith('xmlns') &&
          !features.ownsAttribute(a.key)) {
        throw _SvgFailure(index, 'svg-attribute-${a.key}');
      }
    }
    for (final feature in features.ownersForNode(localName, attrs.keys)) {
      if (admitted.add(feature)) {
        final payload = _resources[SceneResource.vectorBytes] ?? 0;
        feature.admit(SvgFeatureAdmission._(this, index, localName, attrs));
        if (feature is SvgFilterFeature) {
          _filterRetainedBytes +=
              (_resources[SceneResource.vectorBytes] ?? 0) - payload;
        }
        _refuseFeatureExclusion(index, active);
      }
    }
    _charge(SceneResource.sourceNodes, 1);
    // Containers, whitespace, titles and gradient stops retain no leaf alpha.
    // Auditing follows references, so repeated instances remain charged. Mask
    // evidence and clip-filtered copies need their own simultaneous payloads.
    if (_shapes.contains(localName) ||
        const {'image', 'mask', 'text', 'foreignObject'}.contains(localName)) {
      _coverageMaps += _shapes.contains(localName)
          ? _shapePaintRoles(attrs).length
          : 1;
    }
    if (attrs['clip-path'] != null && attrs['clip-path'] != 'none') {
      // A container clip may filter every descendant's footprint. Keep the
      // source-node upper bound for feature effects until instance preparation.
      _coverageMaps += 2 * document.nodes.length;
    }
    _charge(
      SceneResource.sourceBytes,
      attrs.entries.fold(
        64,
        (sum, a) => sum + 2 * (a.key.length + a.value.length),
      ),
    );
    _charge(
      SceneResource.vectorBytes,
      512 + attrs.values.fold(0, (sum, v) => sum + v.length * 32),
    );
    _charge(
      SceneResource.vectorOperations,
      4 + attrs.values.fold(0, (sum, v) => sum + v.length),
    );
    if (n.localName == 'stop') _charge(SceneResource.gradientStops, 1);
    final next = {...active, index};
    for (final a in attrs.entries) {
      if (a.key != 'href' &&
          a.key != 'xlink:href' &&
          !a.value.startsWith('url(')) {
        continue;
      }
      if (n.localName == 'image' &&
          (a.key == 'href' || a.key == 'xlink:href')) {
        if (Uri.tryParse(a.value)?.hasScheme != false ||
            a.value.startsWith('//')) {
          throw _SvgFailure(index, 'nonlocal-svg-image');
        }
        continue;
      }
      if (_svgPaint.contains(a.key) && !_shapes.contains(n.localName)) continue;
      final repetitions = a.key.startsWith('marker-')
          ? _markerReferenceCount(n.localName!, a.key, attrs, index)
          : 1;
      for (var j = 0; j < repetitions; j++) {
        _charge(SceneResource.references, 1);
        final target = _reference(index, a.value);
        _references.add((source: index, target: target, attribute: a.key));
        _audit(
          target,
          next,
          depth + 1,
          refs + 1,
          inherited: n.localName == 'use'
              ? {
                  for (final a in attrs.entries)
                    if (_svgPaint.contains(a.key)) a.key: a.value,
                }
              : const {},
        );
      }
    }
    if (features.opaqueChildren(localName)) return;
    for (final child in n.children) {
      _audit(
        child,
        next,
        depth + 1,
        refs,
        inherited: {
          for (final a in attrs.entries)
            if (_svgPaint.contains(a.key)) a.key: a.value,
        },
      );
    }
  }

  List<int> _resourceNodes(_SvgInstance instance) {
    final result = <int>{};
    void add(int index) {
      if (!result.add(index)) return;
      for (final child in document.node(index).children) {
        if (document.node(child).localName != null) add(child);
      }
      for (final edge in _references.where((e) => e.source == index)) {
        add(edge.target);
      }
    }

    for (final value in instance.paint.values.where(
      (v) => v.startsWith('url('),
    )) {
      add(_reference(instance.node.index, value));
    }
    return List.unmodifiable(result);
  }
}

const _svgTags = {
  'svg',
  'g',
  'defs',
  'symbol',
  'use',
  'rect',
  'circle',
  'ellipse',
  'line',
  'polyline',
  'polygon',
  'path',
  'linearGradient',
  'radialGradient',
  'stop',
  'pattern',
  'marker',
  'image',
  'title',
  'desc',
};
const _svgPaint = {
  'fill',
  'fill-rule',
  'fill-opacity',
  'stroke',
  'stroke-width',
  'stroke-linecap',
  'stroke-linejoin',
  'stroke-miterlimit',
  'stroke-dasharray',
  'stroke-dashoffset',
  'stroke-opacity',
  'color',
  'visibility',
  'marker-start',
  'marker-mid',
  'marker-end',
};
const _svgAttributes = {
  'xmlns',
  'xmlns:xlink',
  // Legacy SVG version/profile metadata has no rendering effect.
  'version',
  'baseProfile',
  'id',
  'class',
  'data-source',
  'x',
  'y',
  'width',
  'height',
  'viewBox',
  'preserveAspectRatio',
  'transform',
  'fill',
  'fill-rule',
  'fill-opacity',
  'stroke',
  'stroke-width',
  'stroke-linecap',
  'stroke-linejoin',
  'stroke-miterlimit',
  'stroke-dasharray',
  'stroke-dashoffset',
  'stroke-opacity',
  'color',
  'opacity',
  'visibility',
  'display',
  'overflow',
  'filter',
  'rx',
  'ry',
  'cx',
  'cy',
  'r',
  'x1',
  'x2',
  'y1',
  'y2',
  'points',
  'd',
  'href',
  'xlink:href',
  'gradientUnits',
  'gradientTransform',
  'spreadMethod',
  'fx',
  'fy',
  'fr',
  'offset',
  'stop-color',
  'stop-opacity',
  'patternUnits',
  'patternContentUnits',
  'patternTransform',
  'markerWidth',
  'markerHeight',
  'markerUnits',
  'refX',
  'refY',
  'orient',
  'marker-start',
  'marker-mid',
  'marker-end',
};
