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
  );
  factory SvgGraphicsPlan.inspect({
    required SourceDocument document,
    required int rootIndex,
    required SourcePageId page,
    required AuthoredPageSize size,
    Map<int, Map<String, String>> resolvedPresentation = const {},
    List<String> presentationProblems = const [],
    AffineTransform placement = const AffineTransform.identity(),
  }) {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
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
    } on FormatException {
      plan.capability=plan._failure(_SvgFailure(rootIndex,'svg-path-data',malformed:true));
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
  final Map<int, Map<String, String>> presentation;
  final AffineTransform placement;
  final Map<String, int> _ids = {};
  final Map<SceneResource, int> _resources = {};
  final List<({int source, int target, String attribute})> _references = [];
  List<({int source, int target, String attribute})> get references =>
      List.unmodifiable(_references);
  Map<SceneResource, int> get resources => Map.unmodifiable(_resources);
  late final SectionCapability capability;
  int sourceDepth = 0, referenceDepth = 0, layerDepth = 0;

  /// Base payload/alpha/scratch reservation. Pattern tiles and dash expansion
  /// make additional admissions in the supplied ledger before their recording.
  Map<SceneResource, int> reservation({double hostOpacity = 1}) {
    final width = size.width.ceil(), height = size.height.ceil();
    final buffers = layerDepth + (hostOpacity == 1 ? 0 : 1) + 2;
    final cap =
        SceneResourceBudget.provisionalLimits[SceneResource.layerPixels]!;
    if (width > cap ||
        height > cap ||
        width > cap ~/ height ||
        width * height > cap ~/ buffers) {
      throw const SceneAdmissionException(
        SceneAdmissionFailure.resourceExhausted,
        resource: SceneResource.layerPixels,
      );
    }
    final pixels = width * height,
        count = resources[SceneResource.sourceNodes] ?? 0;
    return Map.unmodifiable({
      ...resources,
      SceneResource.vectorBytes:
          (resources[SceneResource.vectorBytes] ?? 0) +
          count * pixels +
          2 * 1024 * 1024,
      SceneResource.layerPixels: pixels * buffers,
      SceneResource.layerBytes: pixels * buffers * 4,
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

  void _audit(int index, Set<int> active, int depth, int refs,
    {Map<String,String> inherited=const {}}) {
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
    if (n.namespaceUri != 'http://www.w3.org/2000/svg' ||
        !_svgTags.contains(n.localName)) {
      throw _SvgFailure(index, 'svg-${n.localName ?? 'node'}');
    }
    final attrs = {...inherited,..._attributes(index)};
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
      if (!_svgAttributes.contains(a.key) && !a.key.startsWith('xmlns')) {
        throw _SvgFailure(index, 'svg-attribute-${a.key}');
      }
      if (a.key == 'filter' && a.value != 'none') {
        throw _SvgFailure(index, 'svg-filter');
      }
    }
    _charge(SceneResource.sourceNodes, 1);
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
          ? _markerReferenceCount(n.localName!,a.key,attrs,index) : 1;
      for (var j = 0; j < repetitions; j++) {
        _charge(SceneResource.references, 1);
        final target = _reference(index, a.value);
        _references.add((source: index, target: target, attribute: a.key));
        _audit(target, next, depth + 1, refs + 1,inherited:n.localName=='use'
          ? {for (final a in attrs.entries) if (_svgPaint.contains(a.key)) a.key:a.value}
          :const {});
      }
    }
    for (final child in n.children) {
      _audit(child, next, depth + 1, refs,inherited:{for (final a in attrs.entries)
        if (_svgPaint.contains(a.key)) a.key:a.value});
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
