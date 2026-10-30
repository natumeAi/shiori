part of 'svg_graphics.dart';

extension SvgGraphicsPreparation on SvgGraphicsPlan {
  Future<SvgGraphicsScene> prepare({
    required SceneResourceBudget budget,
    SvgGraphicsImages images = const SvgGraphicsImages(),
    int paintOrdinalOffset = 0,
    double hostOpacity = 1,
    List<GeometryClip> hostClips = const [],
    PublicationCancellation? cancellation,
    bool preReserved = false,
    AffineTransform? placement,
    SvgFeatureHost? host,
    SvgFeatureRegistry? features,
  }) async {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    final featureHost = host ?? this.host;
    final registry = features ?? this.features;
    final leases = <SceneResourceLease>[], pictures = <ui.Picture>[];
    final evidencePictures = <ui.Picture>[],
        evidenceLeases = <SceneResourceLease>[];
    final elements = <SvgGraphicsElement>[], fragments = <SourceFragment>[];
    final paint = <GeometryPaint>[];
    final clips = <String, GeometryClip>{},
        groups = <String, GeometryOpacityGroup>{};
    final featureGeometry = SvgFeatureGeometry();
    final featureState = <Object, Object?>{};
    final featureCoverage = _SvgFeatureCoverage();
    final featureOwners = _SvgFeatureOwners();
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
      final evidenceBounds = _evidenceBounds(placement);
      final request = reservation(
        hostOpacity: hostOpacity,
        placement: placement,
      );
      // Local subdivision of the caller's whole-scene admission. Full raster
      // and tile leases are tracked here without charging the shared owner twice.
      final rasterPixels =
          _evidencePixels(evidenceBounds) + _filterRasterPixels;
      final evidenceBudget = SceneResourceBudget(
        limits: {
          ...SceneResourceBudget.provisionalLimits,
          SceneResource.layerPixels: rasterPixels > 0 ? rasterPixels : 1,
          SceneResource.layerBytes: rasterPixels > 0 ? rasterPixels * 4 : 4,
        },
      );
      // A fixed-scene caller already holds the whole-unit reservation, but this
      // ledger must still debit the base so pattern/dash sub-leases can only
      // use the planned remainder. A direct caller reserves the full plan here
      // and refuses when its ledger cannot cover it.
      if (!preReserved) {
        leases.add(
          budget.reserve(
            request,
            sourceDepth: sourceDepth,
            referenceDepth: referenceDepth,
            layerDepth: depth,
          ),
        );
      } else {
        // A pre-reservation covers this request, never an undersized ledger.
        // Existing fixed-scene debits may overlap the SVG base, but cannot make
        // a layer plan larger than the entire local capacity admissible.
        for (final resource in [
          SceneResource.layerPixels,
          SceneResource.layerBytes,
          if (_filterRasterPixels > 0) SceneResource.vectorBytes,
        ]) {
          if (request[resource]! > budget.limits[resource]!) {
            throw SceneAdmissionException(
              SceneAdmissionFailure.resourceExhausted,
              resource: resource,
            );
          }
        }
        // Debit only capacity not already consumed by the fixed scene. Some
        // whole-unit resources are smaller than this plan's repeated-reference
        // charge; the global owner still holds the whole-unit lease.
        final used = budget.used;
        final localRequest = <SceneResource, int>{
          for (final entry in request.entries)
            entry.key: math.max(
              0,
              math.min(
                entry.value,
                budget.limits[entry.key]! - (used[entry.key] ?? 0),
              ),
            ),
        };
        leases.add(
          budget.reserve(
            localRequest,
            sourceDepth: sourceDepth,
            referenceDepth: referenceDepth,
            layerDepth: depth,
          ),
        );
      }
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
        placement ?? this.placement,
        ui.Size(size.width, size.height),
        const [],
        hostClips,
        hostOpacity,
        hostGroups,
      );
      final featureNodes = _featureNodes(tree, featureState);
      for (final feature in registry.features) {
        checkCancellation();
        await feature.prepare(
          SvgFeaturePreparation._(
            this,
            feature,
            budget,
            featureHost,
            cancellation,
            featureNodes,
            featureState,
            featureGeometry,
            featureCoverage,
            pictures,
            leases,
            featureOwners,
            evidenceBudget,
            evidenceBounds,
            images,
          ),
        );
        checkCancellation();
      }
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
        if (images.evidenceRasters.isNotEmpty && i.picture != null) {
          if (i.node.localName == 'image') {
            i.evidencePicture = _imagePicture(i, images.forEvidence);
            evidencePictures.add(i.evidencePicture!);
          } else if (_shapes.contains(i.node.localName)) {
            i.evidencePicture = await _compile(
              i,
              budget,
              evidenceLeases,
              evidencePictures,
              images.forEvidence,
            );
          }
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
            fillPath: i.path,
            clipIds: List.unmodifiable(i.clips.map((c) => c.id)),
          ),
        );
        fragments.add(_fragment(i, page));
        if (i.picture != null) {
          paint.addAll(
            await _paintEvidence(
              i,
              budget,
              evidenceBudget,
              images,
              checkCancellation,
              evidenceBounds,
            ),
          );
        }
      }

      await prepareNode(tree);
      checkCancellation();
      for (final feature in registry.features) {
        feature.geometry(
          SvgFeatureGeometryContext._(
            this,
            feature,
            featureHost,
            featureNodes,
            featureState,
            featureGeometry,
            featureCoverage,
            fragments,
            paint,
          ),
        );
      }
      checkCancellation();
      final capturedOutputs = <String, ui.Picture>{};
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      if (hostOpacity != 1) {
        canvas.saveLayer(
          null,
          ui.Paint()..color = ui.Color.fromRGBO(0, 0, 0, hostOpacity),
        );
      }
      try {
        _paintTree(
          canvas,
          tree,
          registry,
          featureState,
          pictures: pictures,
          capturedOutputs: capturedOutputs,
        );
        checkCancellation();
      } catch (_) {
        recorder.endRecording().dispose();
        rethrow;
      }
      if (hostOpacity != 1) canvas.restore();
      output = recorder.endRecording();
      for (final feature in registry.features) {
        checkCancellation();
        await feature.postPaint(
          SvgFeaturePostPaintContext._(
            SvgFeatureGeometryContext._(
              this,
              feature,
              featureHost,
              featureNodes,
              featureState,
              featureGeometry,
              featureCoverage,
              fragments,
              paint,
            ),
            evidenceBudget,
            evidenceBounds,
            capturedOutputs,
            checkCancellation,
          ),
        );
        checkCancellation();
      }
      featureCoverage.require(registry, featureNodes, featureGeometry);
      for (final picture in evidencePictures) {
        picture.dispose();
      }
      evidencePictures.clear();
      for (final lease in evidenceLeases.reversed) {
        lease.release();
      }
      evidenceLeases.clear();
      if (output.approximateBytesUsed +
              pictures.fold(0, (sum, p) => sum + p.approximateBytesUsed) >
          2 * 1024 * 1024) {
        throw const SceneAdmissionException(
          SceneAdmissionFailure.resourceExhausted,
          resource: SceneResource.vectorBytes,
        );
      }
      final geometryFragments = [...fragments, ...featureGeometry.fragments]
        ..sort(
          (a, b) => a.nodeIndex != b.nodeIndex
              ? a.nodeIndex.compareTo(b.nodeIndex)
              : a.paintOrdinal.compareTo(b.paintOrdinal),
        );
      final geometryPaint = [...paint, ...featureGeometry.paints]
        ..sort((a, b) {
          final ordinal = a.paintOrdinal.compareTo(b.paintOrdinal);
          return ordinal != 0 ? ordinal : a.role.index.compareTo(b.role.index);
        });
      final completeness = featureGeometry.complete
          ? const CompleteGeometry()
          : IncompleteGeometry(List.unmodifiable(featureGeometry.issues));
      elements.sort((a, b) => a.paintOrdinal.compareTo(b.paintOrdinal));
      return SvgGraphicsScene._(
        size,
        output,
        SourceGeometry(
          version: 1,
          fragments: geometryFragments,
          completeness: completeness,
          clips: {...clips, ...featureGeometry.clips}.values.toList(),
          paint: geometryPaint,
          opacityGroups: {...groups, ...featureGeometry.groups}.values.toList(),
        ),
        verdict,
        List.unmodifiable(elements),
        pictures,
        leases,
        featureOwners,
      );
    } on PreparationCancelled {
      canceled = true;
    } on _SvgFailure catch (e) {
      verdict = _failure(e);
    } on SvgFeatureRefusal catch (e) {
      verdict = _failure(
        _SvgFailure(e.node, e.identifier, malformed: e.malformed),
      );
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
    for (final picture in evidencePictures) {
      picture.dispose();
    }
    for (final lease in evidenceLeases.reversed) {
      lease.release();
    }
    for (final p in pictures) {
      p.dispose();
    }
    // Destroy feature-owned filter cache handles before returning their charge.
    featureOwners.dispose();
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
    _SvgFeatureOwners(),
  );
}

void _clip(
  ui.Canvas canvas,
  List<GeometryClip> clips, {
  Set<String> excludedViewportClipIds = const {},
}) {
  for (final clip in clips) {
    if (excludedViewportClipIds.contains(clip.id)) continue;
    final r = clip.region;
    canvas.clipPath(
      (ui.Path()..addRect(ui.Rect.fromLTWH(r.left, r.top, r.width, r.height)))
          .transform(_matrix(r.transform)),
    );
  }
}

void _paintLeaf(
  ui.Canvas canvas,
  _SvgInstance i, {
  bool evidence = false,
  Set<String> excludedViewportClipIds = const {},
}) {
  if (i.picture == null ||
      i.attributes['display'] == 'none' ||
      const {'hidden', 'collapse'}.contains(i.paint['visibility'])) {
    return;
  }
  canvas.save();
  _clip(canvas, i.clips, excludedViewportClipIds: excludedViewportClipIds);
  canvas.transform(_matrix(i.transform));
  canvas.drawPicture(evidence ? i.evidencePicture ?? i.picture! : i.picture!);
  canvas.restore();
}

void _paintTree(
  ui.Canvas canvas,
  _SvgInstance i,
  SvgFeatureRegistry features,
  Map<Object, Object?> state, {
  List<ui.Picture>? pictures,
  Map<String, ui.Picture>? capturedOutputs,
  Set<String> excludedViewportClipIds = const {},
}) {
  if (i.attributes['display'] == 'none') return;
  final node = SvgFeatureNode._(i, state);
  final capture =
      capturedOutputs != null &&
      pictures != null &&
      features.features.any((feature) => feature.captureOutput(node));
  final outputCanvas = canvas;
  final recorder = capture ? ui.PictureRecorder() : null;
  if (recorder != null) canvas = ui.Canvas(recorder);
  void defaultPaint(ui.Canvas canvas, Set<String> excludedClips) {
    _paintLeaf(canvas, i, excludedViewportClipIds: excludedClips);
    for (final child in i.children) {
      _paintTree(
        canvas,
        child,
        features,
        state,
        pictures: pictures,
        capturedOutputs: capturedOutputs,
        excludedViewportClipIds: excludedClips,
      );
    }
  }

  final painters = features.ownersForNode(i.node.localName, i.attributes.keys);
  void paintAt(int index, ui.Canvas target, Set<String> excludedClips) {
    if (index == painters.length) {
      defaultPaint(target, excludedClips);
      return;
    }
    final paint = SvgFeaturePaint._(
      target,
      SvgFeatureNode._(i, state),
      state,
      (nextCanvas, nextExcludedClips) =>
          paintAt(index + 1, nextCanvas, nextExcludedClips),
      pictures,
      excludedClips,
    );
    painters[index].paint(paint);
    if (paint.paintDefaultCalls != 1) {
      throw _SvgFailure(i.node.index, 'svg-feature-paint-default');
    }
  }

  // Element/group opacity composites the filtered, clipped and masked output.
  // Child opacity remains inside its parent's captured SourceGraphic.
  final opacity = _number(
    i.attributes['opacity'],
    i.node.index,
    fallback: 1,
  ).clamp(0.0, 1.0);
  try {
    if (opacity != 1) {
      canvas.saveLayer(
        null,
        ui.Paint()..color = ui.Color.fromRGBO(0, 0, 0, opacity),
      );
    }
    paintAt(0, canvas, excludedViewportClipIds);
    if (opacity != 1) canvas.restore();
    if (recorder != null) {
      final picture = recorder.endRecording();
      pictures!.add(picture);
      capturedOutputs![node.identity] = picture;
      outputCanvas.drawPicture(picture);
    }
  } finally {
    if (recorder?.isRecording ?? false) recorder!.endRecording().dispose();
  }
}
