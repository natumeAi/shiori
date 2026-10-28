part of 'fixed_scene.dart';

extension _FixedGeometry on FixedSceneBuilder {
  SourceGeometry _export() {
    final fragments = <SourceFragment>[];
    for (final box in _boxes) {
      if (!box.hasVisibleTransform) continue;
      final id = document.node(box.nodeIndex).id;
      final r = box.borderBox;
      fragments.add(
        SourceFragment(
          page: page,
          nodeIndex: box.nodeIndex,
          kind: SourceFragmentKind.element,
          textRange: null,
          clusters: const [],
          elementAnchor: SourceElementAnchor(
            nodeIndex: box.nodeIndex,
            elementId: id == '' ? null : id,
          ),
          elementQuad: [
            for (final p in [
              r.topLeft,
              r.topRight,
              r.bottomRight,
              r.bottomLeft,
            ])
              GeometryPoint(p.dx, p.dy),
          ],
          sourceToUnit: box.transform,
          clipIds: box.clipIds,
          maskIds: const [],
          paintOrdinal: box.paintOrdinal,
          effectiveOpacity:
              box.style.authored.visibility == AuthoredVisibility.visible
              ? box.effectiveOpacity
              : 0,
        ),
      );
    }
    final textNodes = <int, FixedText>{};
    for (final text in _texts) {
      if (!text.owner.hasVisibleTransform) continue;
      for (final entry in text.block.map.entries.where((e) => e.hasSource)) {
        textNodes[entry.nodeIndex] = text;
      }
    }
    for (final entry in textNodes.entries) {
      final index = entry.key,
          text = entry.value,
          data = document.node(index).text ?? '',
          style = styles.styleOf(index)!;
      if (data.isEmpty) continue;
      final paragraph = text.paragraph.paragraph, map = text.block.map;
      final clusters = <ClusterGeometry>[];
      var offset = 0;
      while (offset < data.length) {
        final startPara = map.paraOffsetOf(index, offset);
        final glyph = startPara == null
            ? null
            : paragraph.getGlyphInfoAt(startPara);
        final end = math
            .min(
              data.length,
              offset +
                  math.max(
                    1,
                    (glyph?.graphemeClusterCodeUnitRange.end ??
                            (startPara ?? 0) + 1) -
                        (startPara ?? 0),
                  ),
            )
            .toInt();
        final endPara = map.paraOffsetOf(index, end);
        if (startPara == null || endPara == null) {
          _issues.add(
            GeometryIssue(GeometryGapKind.source, 'Unmapped XHTML grapheme'),
          );
          break;
        }
        final boxes = paragraph.getBoxesForRange(startPara, endPara);
        final lineIndex =
            paragraph.getLineNumberAt(
              math.min(startPara, math.max(0, text.block.text.length - 1)),
            ) ??
            0;
        final metrics = paragraph.computeLineMetrics();
        final delta = text._offsetAt(startPara);
        final baseline =
            (metrics.isEmpty
                ? 0.0
                : metrics[lineIndex.clamp(0, metrics.length - 1)].baseline) +
            delta.dy;
        ui.Rect rect;
        if (boxes.isEmpty) {
          final next = paragraph.getGlyphInfoAt(
            math.min(startPara, math.max(0, text.block.text.length - 1)),
          );
          final caret = next?.graphemeClusterLayoutBounds.left ?? 0;
          rect = ui.Rect.fromLTWH(caret + delta.dx, baseline, 0, 0);
        } else {
          rect = boxes
              .map((b) => b.toRect())
              .reduce((a, b) => a.expandToInclude(b));
          rect = rect.shift(delta);
        }
        GeometryPoint point(double x, double y) =>
            GeometryPoint(x + text.origin.dx, y + text.origin.dy);
        clusters.add(
          ClusterGeometry(
            range: Utf16Range(offset, end),
            granularity: ClusterGranularity.grapheme,
            provenance: ClusterProvenance.paragraph,
            quad: [
              point(rect.left, rect.top),
              point(rect.right, rect.top),
              point(rect.right, rect.bottom),
              point(rect.left, rect.bottom),
            ],
            baselineStart: point(rect.left, baseline),
            baselineEnd: point(rect.right, baseline),
            rotationRadians: 0,
          ),
        );
        offset = end;
      }
      if (offset != data.length) continue;
      fragments.add(
        SourceFragment(
          page: page,
          nodeIndex: index,
          kind: SourceFragmentKind.xhtmlText,
          textRange: Utf16Range(0, data.length),
          clusters: clusters,
          elementAnchor: null,
          sourceToUnit: text.owner.transform,
          clipIds: [
            ...text.owner.clipIds,
            if (text.owner.style.authored.overflow != AuthoredOverflow.visible)
              'box-${text.owner.nodeIndex}',
          ],
          maskIds: const [],
          paintOrdinal: text.paintOrdinal,
          effectiveOpacity:
              style.authored.visibility == AuthoredVisibility.visible
              ? text.owner.effectiveOpacity
              : 0,
        ),
      );
    }
    for (final p in _paint.where((p) => !p.exactCoverage)) {
      _issues.add(
        GeometryIssue(
          GeometryGapKind.occlusion,
          'Exact ${p.kind.name} alpha footprint unavailable at node ${p.nodeIndex}',
        ),
      );
    }
    final boxNodes = _boxes.map((b) => b.nodeIndex).toSet();
    final inlineBounds = <int, (ui.Rect, FixedText)>{};
    for (final f in fragments.where(
      (f) => f.kind == SourceFragmentKind.xhtmlText,
    )) {
      final text = textNodes[f.nodeIndex]!;
      final points = f.clusters.expand((c) => c.quad);
      if (points.isEmpty) continue;
      final left = points.map((p) => p.x).reduce(math.min),
          right = points.map((p) => p.x).reduce(math.max),
          top = points.map((p) => p.y).reduce(math.min),
          bottom = points.map((p) => p.y).reduce(math.max);
      var parent = document.node(f.nodeIndex).parentIndex;
      while (parent != null && !boxNodes.contains(parent)) {
        final bounds = ui.Rect.fromLTRB(left, top, right, bottom),
            old = inlineBounds[parent];
        inlineBounds[parent] = (
          old == null ? bounds : old.$1.expandToInclude(bounds),
          text,
        );
        parent = document.node(parent).parentIndex;
      }
    }
    for (final e in inlineBounds.entries) {
      final node = document.node(e.key), r = e.value.$1, text = e.value.$2;
      fragments.add(
        SourceFragment(
          page: page,
          nodeIndex: e.key,
          kind: SourceFragmentKind.element,
          textRange: null,
          clusters: const [],
          elementAnchor: SourceElementAnchor(
            nodeIndex: e.key,
            elementId: node.id == '' ? null : node.id,
          ),
          elementQuad: [
            for (final p in [
              r.topLeft,
              r.topRight,
              r.bottomRight,
              r.bottomLeft,
            ])
              GeometryPoint(p.dx, p.dy),
          ],
          sourceToUnit: text.owner.transform,
          clipIds: text.owner.clipIds,
          maskIds: const [],
          paintOrdinal: text.paintOrdinal,
          effectiveOpacity:
              styles.styleOf(e.key)!.authored.visibility ==
                  AuthoredVisibility.visible
              ? text.owner.effectiveOpacity
              : 0,
        ),
      );
    }
    fragments.sort((a, b) => a.nodeIndex.compareTo(b.nodeIndex));
    return SourceGeometry(
      version: 1,
      fragments: fragments,
      clips: _clips,
      paint: _paint,
      opacityGroups: _groups,
      completeness: _issues.isEmpty
          ? const CompleteGeometry()
          : IncompleteGeometry(_issues),
    );
  }
}
