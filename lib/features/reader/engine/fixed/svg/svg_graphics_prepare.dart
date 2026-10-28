part of 'svg_graphics.dart';

extension SvgGraphicsPreparation on SvgGraphicsPlan {
  Future<SvgGraphicsScene> prepare({
    required SceneResourceBudget budget,
    SvgGraphicsImages images = const SvgGraphicsImages(),
    int paintOrdinalOffset = 0,
    double hostOpacity = 1,
    List<GeometryClip> hostClips = const [],
    PublicationCancellation? cancellation,
  }) async {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    final leases = <SceneResourceLease>[], pictures = <ui.Picture>[];
    final elements = <SvgGraphicsElement>[], fragments = <SourceFragment>[];
    final paint = <GeometryPaint>[];
    final clips = <String, GeometryClip>{},
        groups = <String, GeometryOpacityGroup>{};
    var verdict = capability, ordinal = paintOrdinalOffset;
    var canceled = false;
    void checkCancellation() {
      if (cancellation?.isCanceled ?? false) throw const PreparationCancelled();
    }

    ui.Picture? output;
    try {
      checkCancellation();
      if (!capability.isComplete) return _empty(capability);
      final depth = layerDepth + (hostOpacity == 1 ? 0 : 1);
      final request = reservation(hostOpacity: hostOpacity);
      leases.add(
        budget.reserve(
          request,
          sourceDepth: sourceDepth,
          referenceDepth: referenceDepth,
          layerDepth: depth,
        ),
      );
      final hostGroups = hostOpacity == 1
          ? <GeometryOpacityGroup>[]
          : [
              GeometryOpacityGroup(
                id: 'svg-host-group',
                parentId: null,
                opacity: hostOpacity,
              ),
            ];
      final tree = _tree(
        rootIndex,
        const {'fill': 'black', 'stroke': 'none'},
        placement,
        ui.Size(size.width, size.height),
        const [],
        hostClips,
        hostOpacity,
        hostGroups,
      );
      Future<void> prepareNode(_SvgInstance i) async {
        checkCancellation();
        i.ordinal = ordinal++;
        for (final clip in i.clips) {
          clips[clip.id] = clip;
        }
        for (final group in i.groups) {
          groups[group.id] = group;
        }
        if (_shapes.contains(i.node.localName)) {
          i.path = _shape(i);
          i.bounds = i.node.localName == 'path'
              ? _pathBounds(i.attributes['d'] ?? '')
              : i.path!.getBounds();
          if (i.attributes['display'] != 'none') {
            i.picture = await _compile(i, budget, leases, pictures, images);
            i.children.addAll(_markers(i));
          }
        } else if (i.node.localName == 'image') {
          i.path = _shape(i);
          i.bounds = i.path!.getBounds();
          i.picture = _imagePicture(i, images);
          pictures.add(i.picture!);
        }
        for (final child in i.children) {
          await prepareNode(child);
        }
        checkCancellation();
        if (i.bounds == null) {
          final inv = i.transform.inverse();
          ui.Rect? bounds;
          for (final child in i.children) {
            final childBox = child.bounds;
            if (childBox == null) continue;
            if (inv is! InvertedTransform) {
              throw _SvgFailure(i.node.index, 'singular-svg-transform');
            }
            final r = _bounds(inv.transform.compose(child.transform), childBox);
            bounds = bounds == null ? r : bounds.expandToInclude(r);
          }
          i.bounds = bounds ?? ui.Rect.zero;
        }
        elements.add(
          SvgGraphicsElement(
            i.node.index,
            i.instances,
            i.transform,
            i.ordinal,
            i.bounds!,
            i.paint,
            _resourceNodes(i),
          ),
        );
        fragments.add(_fragment(i, page));
        if (i.picture != null) {
          final alpha = await _coverage(i, size);
          checkCancellation();
          paint.add(
            GeometryPaint(
              nodeIndex: i.node.index,
              paintOrdinal: i.ordinal,
              region: _region(i.bounds!, i.transform),
              kind: GeometryPaintKind.image,
              effectiveOpacity:
                  const {'hidden', 'collapse'}.contains(i.paint['visibility'])
                  ? 0
                  : i.opacity,
              exactCoverage: true,
              alphaFootprint: alpha,
              clipIds: i.clips.map((c) => c.id).toList(),
              groupIds: i.groups.map((g) => g.id).toList(),
            ),
          );
        }
      }

      await prepareNode(tree);
      checkCancellation();
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      if (hostOpacity != 1) {
        canvas.saveLayer(
          null,
          ui.Paint()..color = ui.Color.fromRGBO(0, 0, 0, hostOpacity),
        );
      }
      _paintTree(canvas, tree);
      if (hostOpacity != 1) canvas.restore();
      output = recorder.endRecording();
      if (output.approximateBytesUsed +
              pictures.fold(0, (sum, p) => sum + p.approximateBytesUsed) >
          2 * 1024 * 1024) {
        throw const SceneAdmissionException(
          SceneAdmissionFailure.resourceExhausted,
          resource: SceneResource.vectorBytes,
        );
      }
      fragments.sort(
        (a, b) => a.nodeIndex != b.nodeIndex
            ? a.nodeIndex.compareTo(b.nodeIndex)
            : a.paintOrdinal.compareTo(b.paintOrdinal),
      );
      elements.sort((a, b) => a.paintOrdinal.compareTo(b.paintOrdinal));
      paint.sort((a, b) => a.paintOrdinal.compareTo(b.paintOrdinal));
      return SvgGraphicsScene._(
        size,
        output,
        SourceGeometry(
          version: 1,
          fragments: fragments,
          completeness: const CompleteGeometry(),
          clips: clips.values.toList(),
          paint: paint,
          opacityGroups: groups.values.toList(),
        ),
        verdict,
        List.unmodifiable(elements),
        pictures,
        leases,
      );
    } on PreparationCancelled {
      canceled = true;
    } on _SvgFailure catch (e) {
      verdict = _failure(e);
    } on SceneAdmissionException catch (e) {
      verdict = ResourceSectionCapability(
        sectionIndex: page.sectionIndex,
        reason: 'SVG resource admission refused',
        constructs: [
          OffendingConstruct(
            kind: CapabilityConstructKind.resource,
            identifier:
                'svg-${e.resource?.name ?? e.depth?.name ?? e.failure.name}',
          ),
        ],
      );
    } on Object {
      verdict = RenderSectionCapability(
        sectionIndex: page.sectionIndex,
        reason: 'SVG graphics preparation failed',
        constructs: [
          OffendingConstruct(
            kind: CapabilityConstructKind.render,
            identifier: 'svg-graphics',
          ),
        ],
      );
    }
    output?.dispose();
    for (final p in pictures) {
      p.dispose();
    }
    for (final lease in leases.reversed) {
      lease.release();
    }
    if (canceled) throw const PreparationCancelled();
    return _empty(verdict);
  }

  SvgGraphicsScene _empty(SectionCapability verdict) => SvgGraphicsScene._(
    size,
    null,
    SourceGeometry(
      version: 1,
      fragments: const [],
      completeness: IncompleteGeometry([
        GeometryIssue(
          GeometryGapKind.paint,
          'SVG section refused; no partial scene published',
        ),
      ]),
    ),
    verdict,
    const [],
    [],
    [],
  );
}

void _clip(ui.Canvas canvas, List<GeometryClip> clips) {
  for (final clip in clips) {
    final r = clip.region;
    canvas.clipPath(
      (ui.Path()..addRect(ui.Rect.fromLTWH(r.left, r.top, r.width, r.height)))
          .transform(_matrix(r.transform)),
    );
  }
}

void _paintLeaf(ui.Canvas canvas, _SvgInstance i) {
  if (i.picture == null ||
      i.attributes['display'] == 'none' ||
      const {'hidden', 'collapse'}.contains(i.paint['visibility'])) {
    return;
  }
  canvas.save();
  _clip(canvas, i.clips);
  canvas.transform(_matrix(i.transform));
  canvas.drawPicture(i.picture!);
  canvas.restore();
}

void _paintTree(ui.Canvas canvas, _SvgInstance i) {
  if (i.attributes['display'] == 'none') return;
  final opacity = _number(
    i.attributes['opacity'],
    i.node.index,
    fallback: 1,
  ).clamp(0.0, 1.0);
  if (opacity != 1) {
    canvas.saveLayer(
      null,
      ui.Paint()..color = ui.Color.fromRGBO(0, 0, 0, opacity),
    );
  }
  _paintLeaf(canvas, i);
  for (final child in i.children) {
    _paintTree(canvas, child);
  }
  if (opacity != 1) canvas.restore();
}
