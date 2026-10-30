part of 'fixed_scene.dart';

extension _FixedCoverage on FixedSceneBuilder {
  Future<void> _resolveCoverage() async {
    final width = size.width.ceil(), height = size.height.ceil();
    while (_coveragePictures.isNotEmpty) {
      _checkCancellation();
      final (index, picture) = _coveragePictures.removeAt(0);
      try {
        final p = _paint[index];
        void reserve(int bytes) =>
            _leases.add(budget.reserve({SceneResource.vectorBytes: bytes}));
        final uniform = _uniformBackground(p);
        GeometryAlphaFootprint footprint;
        if (uniform != null) {
          reserve(GeometryAlphaFootprint.storageOverhead);
          final (r, alpha) = uniform;
          footprint = GeometryAlphaFootprint.uniform(
            width: math.max(1, r.width.toInt()),
            height: math.max(1, r.height.toInt()),
            pixelSize: 1,
            origin: GeometryPoint(r.left, r.top),
            alpha: alpha,
          );
        } else {
          footprint = await AuthoredEvidenceRaster.rasterize(
            picture,
            width: width,
            height: height,
            budget: evidenceBudget ?? budget,
            reserve: reserve,
            checkCancellation: _checkCancellation,
          );
        }
        _paint[index] = GeometryPaint(
          nodeIndex: p.nodeIndex,
          paintOrdinal: p.paintOrdinal,
          region: p.region,
          innerRegion: p.innerRegion,
          kind: p.kind,
          effectiveOpacity: p.effectiveOpacity,
          exactCoverage: true,
          argb: p.argb,
          clipIds: p.clipIds,
          groupIds: p.groupIds,
          textRanges: p.textRanges,
          alphaFootprint: footprint,
        );
      } on SceneAdmissionException catch (error) {
        _resourceFailures.add(
          OffendingConstruct(
            kind: CapabilityConstructKind.resource,
            identifier: 'alpha-${error.resource?.name ?? error.failure.name}',
          ),
        );
        _issues.add(
          GeometryIssue(
            GeometryGapKind.occlusion,
            'Alpha evidence reservation refused',
          ),
        );
      } finally {
        picture.dispose();
      }
    }
    _coveragePictures.clear();
  }

  (GeometryRegion, int)? _uniformBackground(GeometryPaint paint) {
    if (paint.kind != GeometryPaintKind.decoration) return null;
    final style = styles.styleOf(paint.nodeIndex), a = style?.authored;
    if (style?.backgroundColor == null ||
        a == null ||
        a.backgroundImage != null ||
        const ['top', 'right', 'bottom', 'left'].any(
          (edge) =>
              a.borderStyle(edge) != 'none' &&
              (a.borderWidth(edge).resolve(paint.region.width) ?? 0) > 0,
        )) {
      return null;
    }
    final clips = <GeometryRegion>[];
    for (final id in paint.clipIds) {
      final clip = _clips.where((c) => c.id == id).firstOrNull;
      if (clip == null) return null;
      clips.add(clip.region);
    }
    final r = uniformPixelRectangle([paint.region, ...clips]);
    if (r == null) return null;
    return (
      r,
      r.width == 0 || r.height == 0 ? 0 : style!.backgroundColor! >>> 24,
    );
  }
}
