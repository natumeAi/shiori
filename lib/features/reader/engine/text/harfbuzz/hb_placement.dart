part of 'harfbuzz.dart';

HarfBuzzPlacedRun _placeRun(
  HarfBuzzRun run,
  List<HarfBuzzPosition> positions,
  double x,
  double y,
  bool middle,
  double? textLength,
  HarfBuzzLengthAdjust adjust,
  HarfBuzzQuadraticPath? traversal,
  HarfBuzzStartOffset startOffset,
  int sourceOffset,
  PublicationCancellation? cancellation,
) {
  final scale =
      textLength != null && adjust == HarfBuzzLengthAdjust.spacingAndGlyphs
      ? textLength / run.advance
      : 1.0;
  final spacing =
      textLength != null &&
          adjust == HarfBuzzLengthAdjust.spacing &&
          run.text.length > 1
      ? (textLength - run.advance) / (run.text.length - 1)
      : 0.0;
  final anchor = middle
      ? (run.advance * scale +
                positions.skip(1).fold<double>(0, (s, p) => s + p.dx)) /
            2
      : 0.0;
  var cursor = x - anchor;
  final start = traversal == null
      ? 0.0
      : startOffset._resolve(traversal.length);
  final charge = run.resources._reserve('placed-run', {
    SceneResource.sourceBytes: run.paintClusters.length * 256,
    SceneResource.sourceNodes: run.paintClusters.length,
  });
  final fragments = <HarfBuzzFragment>[];
  try {
    for (final range in run.paintClusters) {
      _checkCancellation(cancellation);
      final first = range.start, end = range.end;
      final pen = run._metricOffset(first);
      final slot = (run._metricOffset(first + 1) - pen) * scale;
      final position = positions.isEmpty
          ? HarfBuzzPosition()
          : positions[first];
      if (position.x case final px?) {
        cursor = px - anchor;
      }
      if (position.y case final py?) {
        y = py;
      }
      cursor += position.dx;
      y += position.dy;
      var angle = position.rotationDegrees * math.pi / 180;
      var origin = ui.Offset(cursor + first * spacing, y);
      if (traversal != null) {
        final tangent = traversal._tangent(
          start + pen * scale + first * spacing + slot / 2,
        );
        angle += math.atan2(tangent.vector.dy, tangent.vector.dx);
        origin =
            tangent.position -
            ui.Offset(math.cos(angle), math.sin(angle)) * (slot / 2);
      }
      final indices = run._paintIndices[first]!;
      final width =
          indices.fold<int>(0, (s, i) => s + run.paintGlyphs[i].advance) *
          run.factor;
      final bytes = indices.fold<int>(0, (s, i) => s + run._outlines[i].bytes);
      final operations = indices.fold<int>(
        0,
        (s, i) => s + run._outlines[i].operations,
      );
      final outlineCharge = run.resources._reserve('placed-outline', {
        SceneResource.vectorBytes: bytes,
        SceneResource.vectorOperations: operations,
        SceneResource.sourceNodes: 1,
      });
      ui.Path? path;
      try {
        path = ui.Path();
        var glyphPen = 0.0;
        ui.Rect? ink;
        final c = math.cos(angle), s = math.sin(angle);
        for (final index in indices) {
          final glyph = run.paintGlyphs[index], outline = run._outlines[index];
          final offset = ui.Offset(
            glyphPen + glyph.xOffset * run.factor,
            -glyph.yOffset * run.factor,
          );
          final tx = origin.dx + offset.dx * scale * c - offset.dy * s;
          final ty = origin.dy + offset.dx * scale * s + offset.dy * c;
          path.addPath(
            outline.path,
            ui.Offset.zero,
            matrix4: Float64List.fromList([
              scale * c,
              scale * s,
              0,
              0,
              -s,
              c,
              0,
              0,
              0,
              0,
              1,
              0,
              tx,
              ty,
              0,
              1,
            ]),
          );
          if (outline.operations > 0) {
            final rect = outline.path.getBounds().shift(offset);
            ink = ink?.expandToInclude(rect) ?? rect;
          }
          glyphPen += glyph.advance * run.factor;
        }
        GeometryPoint point(double px, double py) => GeometryPoint(
          origin.dx + px * scale * c - py * s,
          origin.dy + px * scale * s + py * c,
        );
        final rect = ink ?? ui.Rect.zero;
        final geometry = ClusterGeometry(
          range: Utf16Range(sourceOffset + first, sourceOffset + end),
          granularity: ClusterGranularity.shapingCluster,
          provenance: ClusterProvenance.shaped,
          quad: [
            point(rect.left, rect.top),
            point(rect.right, rect.top),
            point(rect.right, rect.bottom),
            point(rect.left, rect.bottom),
          ],
          baselineStart: point(0, 0),
          baselineEnd: point(width, 0),
          rotationRadians: angle,
        );
        final layout = run._layoutByPaint[first]!;
        fragments.add(
          HarfBuzzFragment._(
            geometry,
            Utf16Range(sourceOffset + layout.start, sourceOffset + layout.end),
            List.unmodifiable(indices),
            slot,
            _HbOutline(path, operations, bytes, outlineCharge),
          ),
        );
      } catch (_) {
        path?.reset();
        outlineCharge.release();
        rethrow;
      }
      cursor += (run._metricOffset(end) - pen) * scale;
    }
    _checkCancellation(cancellation);
    return HarfBuzzPlacedRun._(
      List.unmodifiable(fragments),
      run.advance * scale,
      charge,
    );
  } catch (_) {
    for (final fragment in fragments.reversed) {
      fragment._outline.dispose();
    }
    charge.release();
    rethrow;
  }
}
