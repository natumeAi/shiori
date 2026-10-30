part of 'svg_graphics.dart';

/// One feature seam. Implementations live in their own part file and are
/// registered once in [SvgFeatureRegistry.defaults]; shared plan/tree/prepare
/// code only calls the hooks below.
abstract class SvgFeature {
  const SvgFeature();
  String get key;

  /// Rendered/definition tags and attributes this feature owns.
  Set<String> get tags => const {};
  Set<String> get definitionTags => const {};
  Set<String> get attributes => const {};
  Set<String> get presentationProperties => const {};

  /// Non-null identifier refuses the whole section before allocation.
  String? presentationRefusal(String property, String value) => null;

  /// True when a presentation value has no effect and must not be recorded.
  bool presentationIgnored(String property, String value) => false;

  /// True when the feature owns all descendants (foreignObject XHTML).
  bool get opaqueChildren => false;

  /// Runs once per source node this feature owns, before resource charges.
  void admit(SvgFeatureAdmission admission) {}

  /// Runs after the base ledger reservation and tree construction, before any
  /// painting. Use this for shaping, offscreen layers or other async work.
  Future<void> prepare(SvgFeaturePreparation preparation) async {}

  /// Runs after paint ordinals exist and before scene geometry is assembled.
  void geometry(SvgFeatureGeometryContext context) {}

  /// Wraps this node's default paint (leaf plus children). The default simply
  /// paints the node.
  void paint(SvgFeaturePaint context) => context.paintDefault();

  /// Opt in to a scene-owned isolated capture, after wrappers and own opacity.
  /// Painting still runs exactly once; siblings are never part of the capture.
  bool captureOutput(SvgFeatureNode node) => false;

  /// Awaited after painting, before completeness validation and publication.
  Future<void> postPaint(SvgFeaturePostPaintContext post) async {}
}

final class SvgFeatureRefusal implements Exception {
  const SvgFeatureRefusal(this.node, this.identifier, {this.malformed = false});
  final int node;
  final String identifier;
  final bool malformed;
  @override
  String toString() => 'SvgFeatureRefusal($node, $identifier)';
}

final class SvgFeatureRegistry {
  SvgFeatureRegistry(Iterable<SvgFeature> features)
    : features = List.unmodifiable(features);
  static final defaults = SvgFeatureRegistry(const [
    SvgClipMaskFeature(),
    SvgFilterFeature(),
    SvgForeignObjectFeature(),
    SvgTextFeature(),
  ]);
  final List<SvgFeature> features;

  bool ownsTag(String? tag) => features.any((f) => f.tags.contains(tag));
  bool isDefinitionTag(String? tag) =>
      features.any((f) => f.definitionTags.contains(tag));
  bool ownsAttribute(String attribute) =>
      features.any((f) => f.attributes.contains(attribute));
  bool opaqueChildren(String? tag) =>
      features.any((f) => f.tags.contains(tag) && f.opaqueChildren);
  SvgFeature? presentationOwner(String property) {
    for (final feature in features) {
      if (feature.presentationProperties.contains(property)) return feature;
    }
    return null;
  }

  List<SvgFeature> ownersForNode(String? tag, Iterable<String> attributes) => [
    for (final feature in features)
      if (feature.tags.contains(tag) ||
          attributes.any(
            (a) =>
                feature.attributes.contains(a) ||
                feature.presentationProperties.contains(a),
          ))
        feature,
  ];
}

final class SvgFeatureAdmission {
  SvgFeatureAdmission._(this.plan, this.index, this.tag, this.attributes);
  final SvgGraphicsPlan plan;
  final int index;
  final String? tag;
  final Map<String, String> attributes;
  SvgFeatureHost get host => plan.host;
  void charge(SceneResource resource, int amount) =>
      plan._charge(resource, amount);
  void chargeLayers({required int pixels, required int bytes}) =>
      plan._chargeLayers(pixels: pixels, bytes: bytes);
  int resolveReference(int at, String value) => plan._reference(at, value);
  void addReference({
    required int source,
    required int target,
    required String attribute,
  }) => plan._addReference(source, target, attribute);
  Never refuse(String identifier, {bool malformed = false}) =>
      throw SvgFeatureRefusal(index, identifier, malformed: malformed);
}

final class SvgFeatureNode {
  SvgFeatureNode._(this._instance, this.state);
  final _SvgInstance _instance;
  final Map<Object, Object?> state;
  int get nodeIndex => _instance.node.index;
  List<int> get instancePath => _instance.instances;
  String? get id => _instance.node.id;
  String? get localName => _instance.node.localName;
  SourceNode get sourceNode => _instance.node;
  Map<String, String> get attributes => _instance.attributes;
  Map<String, String> get paint => _instance.paint;
  AffineTransform get transform => _instance.transform;
  ui.Size get viewport => _instance.viewport;
  double get opacity => _instance.opacity;
  List<GeometryClip> get clips => _instance.clips;
  List<GeometryOpacityGroup> get groups => _instance.groups;
  ui.Rect? get bounds => _instance.bounds;
  ui.Picture? get picture => _instance.picture;
  int get paintOrdinal => _instance.ordinal;
  String get identity => '$nodeIndex/${instancePath.join('/')}';
  bool get paints =>
      _instance.picture != null &&
      _instance.attributes['display'] != 'none' &&
      !const {'hidden', 'collapse'}.contains(_instance.paint['visibility']);
}

final class SvgFeaturePreparation {
  SvgFeaturePreparation._(
    this.plan,
    this.feature,
    this.budget,
    this.host,
    this.cancellation,
    this.nodes,
    this.state,
    this.geometry,
    this._coverage,
    this._pictures,
    this._leases,
    this._owners,
    this.rasterBudget,
    this.evidenceExtent,
    this.images,
  );
  final SvgGraphicsPlan plan;
  final SvgFeature feature;
  final SceneResourceBudget budget;
  final SvgFeatureHost host;
  final PublicationCancellation? cancellation;
  final List<SvgFeatureNode> nodes;
  final Map<Object, Object?> state;
  final SvgFeatureGeometry geometry;
  final _SvgFeatureCoverage _coverage;
  final List<ui.Picture> _pictures;
  final List<SceneResourceLease> _leases;
  final _SvgFeatureOwners _owners;

  /// Prepaid subdivision shared by evidence rasters and retained filter caches.
  final SceneResourceBudget rasterBudget;

  /// Effective outward-rounded root-space evidence bounds, including origin.
  /// Computed for this preparation's placement and admitted with rasterBudget.
  final ui.Rect evidenceExtent;
  final SvgGraphicsImages images;
  void checkCancellation() {
    if (cancellation?.isCanceled ?? false) throw const PreparationCancelled();
  }

  /// Every node instance this feature owns must report one of these.
  void markCovered(SvgFeatureNode node) => _coverage.cover(feature, node);
  void markIncomplete(
    SvgFeatureNode node,
    GeometryGapKind kind,
    String reason,
  ) => _coverage.incomplete(feature, node, kind, reason);

  SceneResourceLease reserve(Map<SceneResource, int> request) {
    final lease = budget.reserve(request);
    _leases.add(lease);
    return lease;
  }

  void addPicture(ui.Picture picture) => _pictures.add(picture);
  void setPicture(SvgFeatureNode node, ui.Picture picture, {ui.Rect? bounds}) {
    addPicture(picture);
    node._instance.picture = picture;
    if (bounds != null) node._instance.bounds = bounds;
  }

  void setBounds(SvgFeatureNode node, ui.Rect bounds) =>
      node._instance.bounds = bounds;

  /// Feature-owned non-picture resources release exactly once on success,
  /// failure and cancellation.
  void onDispose(void Function() dispose) => _owners.add(dispose);
}

final class SvgFeatureGeometryContext {
  SvgFeatureGeometryContext._(
    this.plan,
    this.feature,
    this.host,
    this.nodes,
    this.state,
    this.geometry,
    this._coverage,
    this._fragments,
    this._paint,
  );
  final SvgGraphicsPlan plan;
  final SvgFeature feature;
  final SvgFeatureHost host;
  final List<SvgFeatureNode> nodes;
  final Map<Object, Object?> state;
  final SvgFeatureGeometry geometry;
  final _SvgFeatureCoverage _coverage;
  final List<SourceFragment> _fragments;
  final List<GeometryPaint> _paint;

  void markCovered(SvgFeatureNode node) => _coverage.cover(feature, node);
  void markIncomplete(
    SvgFeatureNode node,
    GeometryGapKind kind,
    String reason,
  ) => _coverage.incomplete(feature, node, kind, reason);

  /// Attach a registered clip to every fragment/paint produced for [nodeIndex].
  void addClipTo(int nodeIndex, String clipId) =>
      _annotate(nodeIndex, clipId: clipId);

  /// Attach a mask to fragments for [nodeIndex]. Complete geometry still
  /// requires the owner to mark mask evidence incomplete until supported.
  void addMaskTo(int nodeIndex, String maskId) =>
      _annotate(nodeIndex, maskId: maskId);

  void _annotate(int nodeIndex, {String? clipId, String? maskId}) {
    for (var i = 0; i < _fragments.length; i++) {
      final f = _fragments[i];
      if (f.nodeIndex != nodeIndex) continue;
      final clips = clipId == null || f.clipIds.contains(clipId)
          ? f.clipIds
          : [...f.clipIds, clipId];
      final masks = maskId == null || f.maskIds.contains(maskId)
          ? f.maskIds
          : [...f.maskIds, maskId];
      if (identical(clips, f.clipIds) && identical(masks, f.maskIds)) continue;
      _fragments[i] = SourceFragment(
        page: f.page,
        nodeIndex: f.nodeIndex,
        kind: f.kind,
        textRange: f.textRange,
        clusters: f.clusters,
        elementAnchor: f.elementAnchor,
        sourceToUnit: f.sourceToUnit,
        clipIds: clips,
        maskIds: masks,
        paintOrdinal: f.paintOrdinal,
        effectiveOpacity: f.effectiveOpacity,
        elementQuad: f.elementQuad,
      );
    }
    if (clipId == null) return;
    for (var i = 0; i < _paint.length; i++) {
      final p = _paint[i];
      if (p.nodeIndex != nodeIndex || p.clipIds.contains(clipId)) continue;
      _paint[i] = GeometryPaint(
        nodeIndex: p.nodeIndex,
        paintOrdinal: p.paintOrdinal,
        region: p.region,
        innerRegion: p.innerRegion,
        kind: p.kind,
        role: p.role,
        effectiveOpacity: p.effectiveOpacity,
        exactCoverage: p.exactCoverage,
        argb: p.argb,
        alphaFootprint: p.alphaFootprint,
        clipIds: [...p.clipIds, clipId],
        groupIds: p.groupIds,
        textRanges: p.textRanges,
      );
    }
  }
}

final class SvgFeaturePostPaintContext {
  SvgFeaturePostPaintContext._(
    this.geometry,
    this.rasterBudget,
    this.evidenceExtent,
    this._outputs,
    this.checkCancellation,
  );
  final SvgFeatureGeometryContext geometry;
  final SceneResourceBudget rasterBudget;
  final ui.Rect evidenceExtent;
  final Map<String, ui.Picture> _outputs;
  final void Function() checkCancellation;

  /// Borrowed root-space output including this instance's wrappers/opacity.
  /// Ancestor effects are deliberately not folded into this isolated picture.
  ui.Picture? outputFor(SvgFeatureNode node) => _outputs[node.identity];
}

final class SvgFeaturePaint {
  SvgFeaturePaint._(
    this.canvas,
    this.node,
    this.state,
    this._paintDefault,
    this._pictures,
    this._excludedViewportClipIds,
  );
  final ui.Canvas canvas;
  final SvgFeatureNode node;
  final Map<Object, Object?> state;
  final void Function(ui.Canvas, Set<String>) _paintDefault;
  final List<ui.Picture>? _pictures;
  final Set<String> _excludedViewportClipIds;
  ui.Picture? _source;
  var _calls = 0;
  int get paintDefaultCalls => _calls;
  void paintDefault() {
    _calls++;
    if (_calls != 1) {
      throw SvgFeatureRefusal(node.nodeIndex, 'svg-feature-paint-default');
    }
    _paintDefault(canvas, _excludedViewportClipIds);
  }

  /// Records the next wrapper/default once in root coordinates. Repeated calls
  /// return the same scene-owned picture without painting or counting again.
  /// Borrow the picture for replay; the scene releases it on every exit path.
  /// [excludeViewportClipIds] defers those viewport clips to this feature's
  /// output. Ancestor capture exclusions remain active; descendant clips and
  /// feature-owned clip-path/mask wrappers are preserved.
  ui.Picture captureDefault({Set<String> excludeViewportClipIds = const {}}) {
    if (_source case final source?) return source;
    if (_calls != 0 || _pictures == null) {
      throw SvgFeatureRefusal(node.nodeIndex, 'svg-feature-paint-default');
    }
    _calls++;
    final recorder = ui.PictureRecorder();
    try {
      _paintDefault(ui.Canvas(recorder), {
        ..._excludedViewportClipIds,
        ...excludeViewportClipIds,
      });
      final source = recorder.endRecording();
      _pictures.add(source);
      return _source = source;
    } catch (_) {
      if (recorder.isRecording) recorder.endRecording().dispose();
      rethrow;
    }
  }
}

final class SvgFeatureGeometry {
  final fragments = <SourceFragment>[];
  final clips = <String, GeometryClip>{};
  final paints = <GeometryPaint>[];
  final groups = <String, GeometryOpacityGroup>{};
  final issues = <GeometryIssue>[];
  bool get complete => issues.isEmpty;
  void addFragment(SourceFragment fragment) => fragments.add(fragment);
  void addPaint(GeometryPaint paint) => paints.add(paint);
  void addClip(GeometryClip clip) => clips[clip.id] = clip;
  void addGroup(GeometryOpacityGroup group) => groups[group.id] = group;
  void incomplete(GeometryGapKind kind, String reason) =>
      issues.add(GeometryIssue(kind, reason));
}

final class _SvgFeatureCoverage {
  final _covered = <(SvgFeature, String)>{};
  final _incomplete = <(SvgFeature, String), GeometryIssue>{};
  void cover(SvgFeature feature, SvgFeatureNode node) =>
      _covered.add((feature, node.identity));
  void incomplete(
    SvgFeature feature,
    SvgFeatureNode node,
    GeometryGapKind kind,
    String reason,
  ) => _incomplete[(feature, node.identity)] = GeometryIssue(kind, reason);

  /// A feature-owned instance without a completion call stays incomplete.
  void require(
    SvgFeatureRegistry registry,
    List<SvgFeatureNode> nodes,
    SvgFeatureGeometry sink,
  ) {
    for (final node in nodes) {
      for (final feature in registry.ownersForNode(
        node.localName,
        node.attributes.keys,
      )) {
        final key = (feature, node.identity);
        final issue = _incomplete[key];
        if (issue != null) {
          sink.incomplete(issue.kind, issue.reason);
        } else if (!_covered.contains(key)) {
          sink.incomplete(
            GeometryGapKind.paint,
            'Feature ${feature.key} did not report completion for ${node.identity}',
          );
        }
      }
    }
  }
}

final class _SvgFeatureOwners {
  final _callbacks = <void Function()>[];
  bool _disposed = false;
  void add(void Function() callback) {
    if (_disposed) throw StateError('Feature owners already disposed');
    _callbacks.add(callback);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    Object? error;
    StackTrace? stack;
    for (final callback in _callbacks.reversed) {
      try {
        callback();
      } catch (e, s) {
        error ??= e;
        stack ??= s;
      }
    }
    _callbacks.clear();
    if (error != null) Error.throwWithStackTrace(error, stack!);
  }
}

abstract interface class SvgForeignObjectLayoutService {
  bool get available;
  Future<SvgForeignObjectLayout?> layout(SvgForeignObjectRequest request);
}

final class SvgForeignObjectRequest {
  const SvgForeignObjectRequest({
    required this.document,
    required this.nodeIndex,
    required this.viewport,
    required this.transform,
    this.cancellation,
  });
  final SourceDocument document;
  final int nodeIndex;
  final ui.Size viewport;
  final AffineTransform transform;
  final PublicationCancellation? cancellation;
}

/// Host-owned picture; the adopting feature must transfer it through
/// [SvgFeaturePreparation.addPicture] so the scene disposes it exactly once.
final class SvgForeignObjectLayout {
  const SvgForeignObjectLayout({
    required this.picture,
    required this.bounds,
    this.fragments = const [],
    this.clips = const [],
  });
  final ui.Picture picture;
  final ui.Rect bounds;
  final List<SourceFragment> fragments;
  final List<GeometryClip> clips;
}

final class SvgUnavailableForeignObjectLayoutService
    implements SvgForeignObjectLayoutService {
  const SvgUnavailableForeignObjectLayoutService();
  @override
  bool get available => false;
  @override
  Future<SvgForeignObjectLayout?> layout(
    SvgForeignObjectRequest request,
  ) async => null;
}

abstract interface class SvgTextFontService {
  bool get available;
  Future<SvgTextFontLease?> acquire(SvgTextFontRequest request);
}

final class SvgTextFontRequest {
  const SvgTextFontRequest({
    required this.document,
    required this.nodeIndex,
    required this.families,
    required this.textCodeUnits,
  });
  final SourceDocument document;
  final int nodeIndex;
  final Set<String> families;
  final int textCodeUnits;
}

/// Admitted face bytes; [release] returns the host lease and the host owns the
/// physical registration drain barrier.
abstract interface class SvgTextFontLease {
  List<SvgTextFontAsset> get fonts;
  int get bytes;
  void release();
}

final class SvgTextFontAsset {
  const SvgTextFontAsset({
    required this.family,
    required this.bytes,
    this.faceIndex = 0,
    this.weight = 400,
    this.italic = false,
  });
  final String family;
  final ByteData bytes;
  final int faceIndex, weight;
  final bool italic;
}

final class SvgUnavailableTextFontService implements SvgTextFontService {
  const SvgUnavailableTextFontService();
  @override
  bool get available => false;
  @override
  Future<SvgTextFontLease?> acquire(SvgTextFontRequest request) async => null;
}

List<SvgFeatureNode> _featureNodes(
  _SvgInstance root,
  Map<Object, Object?> state,
) {
  final nodes = <SvgFeatureNode>[];
  void visit(_SvgInstance instance) {
    nodes.add(SvgFeatureNode._(instance, state));
    for (final child in instance.children) {
      visit(child);
    }
  }

  visit(root);
  return nodes;
}
