part of 'fixed_scene.dart';

extension _FixedCoverage on FixedSceneBuilder {
  Future<void> _resolveCoverage() async {
    final width = size.width.ceil(), height = size.height.ceil();
    while (_coveragePictures.isNotEmpty) {
      _checkCancellation();
      final (index, picture) = _coveragePictures.removeAt(0);
      SceneResourceLease? scratch;
      ui.Image? image;
      try {
        scratch = budget.reserveLayer(width, height, buffers: 2);
        final retained = budget.reserve({
          SceneResource.vectorBytes: width * height,
        });
        _leases.add(retained);
        image = await picture.toImage(width, height);
        _checkCancellation();
        final rgba = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        _checkCancellation();
        final alpha = Uint8List(width * height);
        for (var i = 0; i < alpha.length; i++) {
          alpha[i] = rgba[i * 4 + 3];
        }
        final p = _paint[index];
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
          alphaFootprint: GeometryAlphaFootprint(
            width: width,
            height: height,
            pixelSize: 1,
            origin: GeometryPoint(0, 0),
            alpha: alpha,
          ),
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
        image?.dispose();
        scratch?.release();
        picture.dispose();
      }
    }
    _coveragePictures.clear();
  }
}
