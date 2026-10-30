part of 'svg_graphics.dart';

/// Optional detailed fixed-host evidence. The base host contract remains usable;
/// hosts that cannot supply internal paint evidence report incomplete geometry.
abstract interface class SvgForeignObjectEvidenceLayoutService
    implements SvgForeignObjectLayoutService {
  SvgForeignObjectEvidence evidenceFor(SvgForeignObjectLayout layout);
}

final class SvgForeignObjectEvidence {
  const SvgForeignObjectEvidence({
    required this.geometry,
    required this.dispose,
  });
  final SourceGeometry geometry;
  final void Function() dispose;
}

final class _ForeignPrepared {
  _ForeignPrepared(this.layout, this.evidence, this.ordinals);
  final SvgForeignObjectLayout layout;
  final SvgForeignObjectEvidence? evidence;
  final Map<int, _SvgInstance> ordinals;
}

/// Opaque static XHTML, laid out by the admitted fixed host, never by a browser.
final class SvgForeignObjectFeature extends SvgFeature {
  const SvgForeignObjectFeature();
  @override
  String get key => 'foreign-object';
  @override
  Set<String> get tags => const {'foreignObject'};
  @override
  bool get opaqueChildren => true;
  @override
  Set<String> get attributes => const {'requiredExtensions'};

  @override
  void admit(SvgFeatureAdmission admission) {
    final a = admission;
    if (a.tag != 'foreignObject') {
      a.refuse('svg-${a.tag}-requiredExtensions');
    }
    if ((a.attributes['requiredExtensions'] ?? '').trim().isNotEmpty) {
      a.refuse('svg-foreignObject-requiredExtensions');
    }
    if (!a.host.foreignObject.available) a.refuse('svg-foreignObject');
    if (a.attributes['overflow'] == 'visible') {
      a.refuse('svg-foreignObject-overflow-visible');
    }
    for (final key in ['x', 'y', 'width', 'height']) {
      final value = _number(a.attributes[key], a.index, basis: 1);
      if ((key == 'width' || key == 'height') && value < 0) {
        a.refuse('svg-foreignObject-size', malformed: true);
      }
    }
    final document = a.plan.document;
    var count = 0, units = 0, bytes = 0;
    void audit(int index, int depth) {
      if (depth > SceneResourceBudget.maxSourceDepth) {
        a.refuse('svg-foreignObject-depth');
      }
      final node = document.node(index);
      count++;
      units += node.text?.length ?? 0;
      bytes += (node.text?.length ?? 0) * 2 + 64;
      if (node.localName != null) {
        if (node.namespaceUri != 'http://www.w3.org/1999/xhtml') {
          a.refuse('svg-foreignObject-namespace');
        }
        final tag = node.localName!;
        if (const {
          'script',
          'form',
          'input',
          'button',
          'select',
          'textarea',
          'option',
          'iframe',
          'object',
          'embed',
        }.contains(tag)) {
          a.refuse('svg-foreignObject-$tag');
        }
        if (!const {
          'div',
          'span',
          'p',
          'br',
          'b',
          'i',
          'em',
          'strong',
          'small',
          'sub',
          'sup',
          'u',
          's',
          'a',
          'section',
          'article',
          'header',
          'footer',
          'h1',
          'h2',
          'h3',
          'h4',
          'h5',
          'h6',
          'blockquote',
          'pre',
          'code',
        }.contains(tag)) {
          a.refuse('svg-foreignObject-$tag');
        }
        for (final attr in node.attributes) {
          bytes += (attr.qualifiedName.length + attr.value.length) * 2;
          if (attr.qualifiedName.toLowerCase().startsWith('on') ||
              attr.qualifiedName == 'srcdoc') {
            a.refuse('svg-foreignObject-active-attribute');
          }
        }
      } else if (!node.isCharacterData && node.kind != SourceNodeKind.comment) {
        a.refuse('svg-foreignObject-node-kind');
      }
      for (final child in node.children) {
        audit(child, depth + 1);
      }
    }

    for (final child in document.node(a.index).children) {
      audit(child, 1);
    }
    a.charge(SceneResource.sourceNodes, count);
    a.charge(SceneResource.sourceBytes, bytes);
    // Same bound used by fixed shifted-inline layout: original paragraph,
    // at most one paint group per code unit, and a temporary font probe.
    a.charge(SceneResource.paragraphs, count + units + 1);
    a.charge(SceneResource.textCodeUnits, units + units * units + 1);
    a.charge(SceneResource.vectorOperations, count * 32 + units * 8);
  }

  @override
  Future<void> prepare(SvgFeaturePreparation preparation) async {
    final p = preparation;
    for (final node in p.nodes.where((n) => n.localName == 'foreignObject')) {
      p.checkCancellation();
      final a = node.attributes, index = node.nodeIndex;
      final x = _number(a['x'], index, basis: node.viewport.width);
      final y = _number(a['y'], index, basis: node.viewport.height);
      final width = _number(a['width'], index, basis: node.viewport.width);
      final height = _number(a['height'], index, basis: node.viewport.height);
      if (width < 0 || height < 0) {
        throw SvgFeatureRefusal(
          index,
          'svg-foreignObject-size',
          malformed: true,
        );
      }
      final bounds = ui.Rect.fromLTWH(x, y, width, height);
      p.setBounds(node, bounds);
      if (width == 0 || height == 0 || a['display'] == 'none') {
        p.markCovered(node);
        continue;
      }
      final service = p.host.foreignObject;
      final layout = await service.layout(
        SvgForeignObjectRequest(
          document: p.plan.document,
          nodeIndex: index,
          viewport: ui.Size(width, height),
          transform: node.transform.compose(_translate(x, y)),
          cancellation: p.cancellation,
        ),
      );
      if (layout == null) {
        throw SvgFeatureRefusal(index, 'svg-foreignObject-host');
      }
      p.addPicture(layout.picture);
      final evidence = service is SvgForeignObjectEvidenceLayoutService
          ? service.evidenceFor(layout)
          : null;
      if (evidence != null) p.onDispose(evidence.dispose);
      p.checkCancellation();
      final descendants = <int>{};
      final pending = [...node.sourceNode.children];
      while (pending.isNotEmpty) {
        final index = pending.removeLast();
        descendants.add(index);
        pending.addAll(p.plan.document.node(index).children);
      }
      if (layout.fragments.any(
        (f) => !descendants.contains(f.nodeIndex) || f.page != p.plan.page,
      )) {
        throw SvgFeatureRefusal(index, 'svg-foreignObject-source-identity');
      }
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)..translate(x, y);
      canvas.clipRect(ui.Rect.fromLTWH(0, 0, width, height));
      canvas.drawPicture(layout.picture);
      p.setPicture(node, recorder.endRecording(), bounds: bounds);
      final ordinals = <int, _SvgInstance>{};
      if (evidence != null) {
        // Expand the real host paint sources into this owned opaque subtree.
        // Shared traversal assigns their ordinals before the next SVG sibling.
        final sources = <int, int>{
          for (final f in layout.fragments) f.paintOrdinal: f.nodeIndex,
          for (final paint in evidence.geometry.paint)
            paint.paintOrdinal: paint.nodeIndex,
        };
        final order = sources.keys.toList()..sort();
        for (final ordinal in order) {
          final fragment = layout.fragments
              .where(
                (f) =>
                    f.nodeIndex == sources[ordinal] &&
                    f.paintOrdinal == ordinal,
              )
              .firstOrNull;
          final paint = evidence.geometry.paint
              .where(
                (p) =>
                    p.nodeIndex == sources[ordinal] &&
                    p.paintOrdinal == ordinal,
              )
              .firstOrNull;
          final points = fragment == null
              ? <GeometryPoint>[]
              : [
                  ...fragment.elementQuad,
                  ...fragment.clusters.expand((c) => c.quad),
                ];
          final region = paint?.region;
          final bounds = points.isNotEmpty
              ? ui.Rect.fromLTRB(
                  points.map((p) => p.x).reduce(math.min),
                  points.map((p) => p.y).reduce(math.min),
                  points.map((p) => p.x).reduce(math.max),
                  points.map((p) => p.y).reduce(math.max),
                )
              : ui.Rect.fromLTWH(
                  region!.left,
                  region.top,
                  region.width,
                  region.height,
                );
          final child = _SvgInstance(
            p.plan.document.node(sources[ordinal]!),
            const {},
            const {'fill': 'none', 'stroke': 'none'},
            fragment?.sourceToUnit ?? region!.transform,
            node.viewport,
            node.instancePath,
            const [],
            node.opacity,
            const [],
          )..bounds = bounds;
          node._instance.children.add(child);
          ordinals[ordinal] = child;
        }
      }
      p.state[(this, node.identity)] = _ForeignPrepared(
        layout,
        evidence,
        ordinals,
      );
      if (evidence == null) {
        p.markIncomplete(
          node,
          GeometryGapKind.occlusion,
          'foreignObject host supplied no internal paint evidence',
        );
      } else {
        p.markCovered(node);
      }
    }
  }

  @override
  void geometry(SvgFeatureGeometryContext context) {
    final c = context;
    for (final node in c.nodes.where((n) => n.localName == 'foreignObject')) {
      final prepared = c.state[(this, node.identity)] as _ForeignPrepared?;
      if (prepared == null) continue;
      final evidence = prepared.evidence;
      final opacity = node.paints ? node.opacity : 0.0;
      final geometry = evidence?.geometry;
      final parentFragment = c._fragments
          .where(
            (f) =>
                f.nodeIndex == node.nodeIndex &&
                f.paintOrdinal == node.paintOrdinal,
          )
          .first;
      final ancestors = <int>{node.nodeIndex, ...node.instancePath};
      int? parent = node.sourceNode.parentIndex;
      while (parent != null) {
        ancestors.add(parent);
        parent = c.plan.document.node(parent).parentIndex;
      }
      // Other feature wrappers currently publish their evidence before this
      // host's per-source paints. Never attest unprocessed child coverage as
      // complete when a mask/custom SVG clip/filter changes that coverage.
      if (parentFragment.maskIds.isNotEmpty ||
          parentFragment.clipIds.length != node.clips.length ||
          c.geometry.paints.any(
            (p) =>
                ancestors.contains(p.nodeIndex) &&
                p.kind == GeometryPaintKind.solid,
          )) {
        c.markIncomplete(
          node,
          GeometryGapKind.occlusion,
          'foreignObject SVG effects require a shared per-source evidence postpass',
        );
      }
      final removedOrdinals = prepared.ordinals.values
          .map((i) => i.ordinal)
          .toSet();
      c._fragments.removeWhere((f) => removedOrdinals.contains(f.paintOrdinal));
      if (geometry != null) {
        c._paint.removeWhere((p) => p.paintOrdinal == node.paintOrdinal);
        for (final group in geometry.opacityGroups) {
          c.geometry.addGroup(
            GeometryOpacityGroup(
              id: group.id,
              parentId: group.parentId ?? node.groups.lastOrNull?.id,
              opacity: group.opacity,
            ),
          );
        }
        for (final p in geometry.paint) {
          c.geometry.addPaint(
            GeometryPaint(
              nodeIndex: p.nodeIndex,
              paintOrdinal: prepared.ordinals[p.paintOrdinal]!.ordinal,
              region: p.region,
              innerRegion: p.innerRegion,
              kind: p.kind,
              effectiveOpacity: opacity * p.effectiveOpacity,
              exactCoverage: p.exactCoverage,
              argb: p.argb,
              alphaFootprint: p.alphaFootprint,
              clipIds: [...node.clips.map((clip) => clip.id), ...p.clipIds],
              groupIds: [...node.groups.map((g) => g.id), ...p.groupIds],
              textRanges: p.textRanges,
            ),
          );
        }
      }
      final descendants = <int>{};
      void collect(int index) {
        for (final child in c.plan.document.node(index).children) {
          descendants.add(child);
          collect(child);
        }
      }

      collect(node.nodeIndex);
      for (final clip in prepared.layout.clips) {
        c.geometry.addClip(clip);
      }
      for (final f in prepared.layout.fragments) {
        if (!descendants.contains(f.nodeIndex) || f.page != c.plan.page) {
          throw SvgFeatureRefusal(
            node.nodeIndex,
            'svg-foreignObject-source-identity',
          );
        }
        c.geometry.addFragment(
          SourceFragment(
            page: f.page,
            nodeIndex: f.nodeIndex,
            kind: f.kind,
            textRange: f.textRange,
            clusters: f.clusters,
            elementAnchor: f.elementAnchor,
            elementQuad: f.elementQuad,
            sourceToUnit: f.sourceToUnit,
            clipIds: [...node.clips.map((clip) => clip.id), ...f.clipIds],
            maskIds: f.maskIds,
            paintOrdinal:
                prepared.ordinals[f.paintOrdinal]?.ordinal ?? node.paintOrdinal,
            effectiveOpacity: opacity * f.effectiveOpacity,
          ),
        );
      }
    }
  }
}
