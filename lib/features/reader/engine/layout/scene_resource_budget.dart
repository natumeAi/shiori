import 'dart:collection' show UnmodifiableMapView;

/// Provisional host limits. A3 must route actual allocations through this owner;
/// these counters alone do not bound VM/native RSS or establish device safety.
enum SceneResource {
  readingUnits,
  sourcePages,
  sourceBytes,
  sourceNodes,
  paragraphs,
  textCodeUnits,
  vectorBytes,
  vectorOperations,
  references,
  gradientStops,
  layerBytes,
  layerPixels,
}

enum SceneAdmissionFailure {
  resourceExhausted,
  complexityExceeded,
  processFontExhausted,
}

enum SceneDepth { source, reference, layer }

final class SceneAdmissionException implements Exception {
  const SceneAdmissionException(this.failure, {this.resource, this.depth});
  final SceneAdmissionFailure failure;
  final SceneResource? resource;
  final SceneDepth? depth;
}

final class SceneResourceBudget {
  SceneResourceBudget({
    Map<SceneResource, int>? limits,
    this.sourceDepthLimit = maxSourceDepth,
    this.referenceDepthLimit = maxReferenceDepth,
    this.layerDepthLimit = maxLayerDepth,
  }) : limits = Map.unmodifiable(limits ?? provisionalLimits) {
    if (this.limits.length != SceneResource.values.length ||
        this.limits.values.any((v) => v <= 0 || v > 0x1fffffffffffff) ||
        sourceDepthLimit <= 0 ||
        referenceDepthLimit <= 0 ||
        layerDepthLimit <= 0) {
      throw ArgumentError('Every scene resource requires a positive limit');
    }
  }

  static const maxSourceDepth = 64;
  static const maxReferenceDepth = 32;
  static const maxLayerDepth = 8;
  static const maxSourcePages = 8;
  static const maxReadingUnits = 4;
  static const provisionalLimits = {
    SceneResource.readingUnits: maxReadingUnits,
    SceneResource.sourcePages: maxSourcePages,
    SceneResource.sourceBytes: 32 * 1024 * 1024,
    SceneResource.sourceNodes: 100000,
    SceneResource.paragraphs: 8192,
    SceneResource.textCodeUnits: 4 * 1024 * 1024,
    SceneResource.vectorBytes: 16 * 1024 * 1024,
    SceneResource.vectorOperations: 100000,
    SceneResource.references: 4096,
    SceneResource.gradientStops: 4096,
    SceneResource.layerBytes: 32 * 1024 * 1024,
    SceneResource.layerPixels: 8 * 1024 * 1024,
  };
  final Map<SceneResource, int> limits;
  final int sourceDepthLimit, referenceDepthLimit, layerDepthLimit;
  final Map<SceneResource, int> _used = {};
  final Map<SceneResource, int> _peaks = {};
  Map<SceneResource, int> get used => Map.unmodifiable(_used);
  Map<SceneResource, int> get peaks => Map.unmodifiable(_peaks);

  /// Reserve all classes before parsing/shaping/vector/layer allocation. Both
  /// old and replacement scenes remain charged until their leases release.
  SceneResourceLease reserve(
    Map<SceneResource, int> request, {
    int sourceDepth = 0,
    int referenceDepth = 0,
    int layerDepth = 0,
  }) {
    _checkDepth(SceneDepth.source, sourceDepth, sourceDepthLimit);
    _checkDepth(SceneDepth.reference, referenceDepth, referenceDepthLimit);
    _checkDepth(SceneDepth.layer, layerDepth, layerDepthLimit);
    for (final entry in request.entries) {
      if (entry.value < 0) throw ArgumentError('Negative scene reservation');
      final remaining = limits[entry.key]! - (_used[entry.key] ?? 0);
      if (entry.value > remaining) {
        throw SceneAdmissionException(
          SceneAdmissionFailure.resourceExhausted,
          resource: entry.key,
        );
      }
    }
    // The held map is the lease's CURRENT charge: shrink lowers it and release
    // returns exactly what is still held, so every unit is returned once.
    final held = Map<SceneResource, int>.of(request);
    for (final entry in held.entries) {
      final total = (_used[entry.key] ?? 0) + entry.value;
      _used[entry.key] = total;
      if (total > (_peaks[entry.key] ?? 0)) _peaks[entry.key] = total;
    }
    return SceneResourceLease._(
      held,
      () {
        for (final entry in held.entries) {
          _used[entry.key] = _used[entry.key]! - entry.value;
        }
      },
      (resource, amount) {
        _used[resource] = _used[resource]! - amount;
        held[resource] = held[resource]! - amount;
      },
    );
  }

  /// Reserve every real constituent together with the whole required plan.
  /// Blank slots have no source charge. Old/new units overlap until release.
  SceneResourceLease reserveUnit({
    required int sourcePages,
    Map<SceneResource, int> resources = const {},
    int sourceDepth = 0,
    int referenceDepth = 0,
    int layerDepth = 0,
  }) {
    if (sourcePages < 1 ||
        sourcePages > 2 ||
        resources.containsKey(SceneResource.readingUnits) ||
        resources.containsKey(SceneResource.sourcePages)) {
      throw ArgumentError('A unit requires one or two real pages');
    }
    return reserve(
      {
        ...resources,
        SceneResource.readingUnits: 1,
        SceneResource.sourcePages: sourcePages,
      },
      sourceDepth: sourceDepth,
      referenceDepth: referenceDepth,
      layerDepth: layerDepth,
    );
  }

  /// Physical pixels include scale, filter bounds and padding; [buffers]
  /// counts all simultaneous intermediates. These are RGBA8 payload charges.
  SceneResourceLease reserveLayer(
    int width,
    int height, {
    int buffers = 1,
    int depth = 1,
  }) {
    if (width <= 0 || height <= 0 || buffers <= 0) {
      throw ArgumentError('Invalid layer dimensions');
    }
    // Division checks precede multiplication/native allocation.
    final cap = limits[SceneResource.layerPixels]!;
    if (width > cap ~/ height || width * height > cap ~/ buffers) {
      throw const SceneAdmissionException(
        SceneAdmissionFailure.resourceExhausted,
        resource: SceneResource.layerPixels,
      );
    }
    final pixels = width * height * buffers;
    if (pixels > limits[SceneResource.layerBytes]! ~/ 4) {
      throw const SceneAdmissionException(
        SceneAdmissionFailure.resourceExhausted,
        resource: SceneResource.layerBytes,
      );
    }
    return reserve({
      SceneResource.layerPixels: pixels,
      SceneResource.layerBytes: pixels * 4,
    }, layerDepth: depth);
  }

  void _checkDepth(SceneDepth kind, int value, int limit) {
    if (value < 0) throw ArgumentError('Negative scene depth');
    if (value > limit) {
      throw SceneAdmissionException(
        SceneAdmissionFailure.complexityExceeded,
        depth: kind,
      );
    }
  }
}

final class SceneResourceLease {
  SceneResourceLease._(this._charge, this._release, this._shrink);
  final Map<SceneResource, int> _charge;
  final void Function(SceneResource resource, int amount) _shrink;
  void Function()? _release;

  /// What this lease holds now: the reserved request minus any shrink.
  Map<SceneResource, int> get charge => UnmodifiableMapView(_charge);
  bool get isReleased => _release == null;

  /// Return part of one class's charge while the lease stays live. The caller
  /// must already have destroyed or never made the allocation it covered; the
  /// remainder is released exactly once by [release]. Never grows a charge.
  void shrink(SceneResource resource, int amount) {
    if (_release == null) throw StateError('Scene lease already released');
    if (amount < 0 || amount > (_charge[resource] ?? 0)) {
      throw ArgumentError('Shrink exceeds the held scene charge');
    }
    if (amount > 0) _shrink(resource, amount);
  }

  /// Release after allocation destruction or canceled work has drained.
  void release() {
    final callback = _release;
    _release = null;
    callback?.call();
  }
}
