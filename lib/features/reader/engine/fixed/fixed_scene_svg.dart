part of 'fixed_scene.dart';

extension _FixedSvg on FixedSceneBuilder {
  FixedBox? _layoutSvg(
    int index,
    FixedBox? parent,
    ui.Rect containing,
    ui.Offset flow,
    FixedBox? positioned,
  ) {
    final style = styles.styleOf(index)!;
    final facts = extractSectionSourceFacts(document).svgDimensions
        .singleWhere((s) => s.nodeIndex == index);
    final plan = svgPlans[index];
    // The allocation-free plan freezes the CSS used viewport, including CSS
    // overrides and indefinite height. Reuse it verbatim for scene layout.
    final viewport = plan == null
        ? FixedSvgViewport.resolve(facts)
        : FixedSvgViewport.resolve(
            SvgSourceDimensions(
              nodeIndex: index,
              width: '${plan.size.width}',
              height: '${plan.size.height}',
              viewBox: facts.viewBox,
              preserveAspectRatio: facts.preserveAspectRatio,
            ),
          );
    if (viewport.dimensions is! ResolvedDimensions) {
      final failure = OffendingConstruct(
        kind: CapabilityConstructKind.dimensions,
        identifier: 'svg-viewport',
        nodeIndex: index,
      );
      (viewport.dimensions is MalformedDimensions
              ? _malformed
              : _dimensionFailures)
          .add(failure);
      return null;
    }
    // General SVG text/vector adoption remains gated on A0b. This admitted
    // primitive route conserves every child or refuses the complete scene.
    final size = (viewport.dimensions as ResolvedDimensions).size;
    final box = FixedBox._(index, style, parent);
    // The sizing pass already uses the initial containing block when an
    // absolute replaced root has no positioned ancestor. A static wrapper's
    // flow rectangle must not become a different percentage/inset basis here.
    final cb = _positioningBlock(
      style,
      style.authored.position == AuthoredPosition.absolute && positioned == null
          ? ui.Rect.fromLTWH(0, 0, this.size.width, this.size.height)
          : containing,
      positioned,
    );
    final origin = _positionedOrigin(
      style,
      cb,
      flow,
      ui.Size(size.width, size.height),
    );
    box.borderBox = box.contentBox = ui.Rect.fromLTWH(
      origin.dx,
      origin.dy,
      size.width,
      size.height,
    );
    // The SVG plan applies the root viewBox/preserveAspectRatio itself; the
    // fixed box contributes the resolved CSS placement and ancestor transform.
    // Preparation derives both sourceToUnit and evidenceExtent from this.
    box.svgContentTransform = _translation(origin.dx, origin.dy);
    box.definiteContentHeight = size.height;
    if (plan == null) {
      _reject(index, 'svg-plan-missing');
      return null;
    }
    box.svgPlan = plan;
    if (!plan.capability.isComplete) _svgFailure ??= plan.capability;
    _boxes.add(box);
    parent?.children.add(box);
    parent?.contents.add(box);
    return box;
  }

  Future<void> _prepareSvgScenes() async {
    for (final box in _boxes) {
      final plan = box.svgPlan;
      if (plan == null) continue;
      _checkCancellation();
      final viewportClip = 'box-${box.nodeIndex}';
      if (_clips.any((clip) => clip.id == viewportClip)) {
        box.clipIds = [...box.clipIds, viewportClip];
      }
      final foreignHost =
          plan.host.foreignObject is FixedForeignObjectLayoutService
          ? FixedForeignObjectLayoutService(
              styles: styles,
              page: page,
              fonts: fonts,
              backgroundImages: backgroundImages,
              evidenceImages: evidenceImages,
              intrinsicImageSizes: intrinsicImageSizes,
              preparationScale: preparationScale,
              // A subdivision of the enclosing prepaid SVG reservation.
              budget: SceneResourceBudget(
                limits: {
                  for (final r in SceneResource.values)
                    r: math.max(1, plan.reservation()[r] ?? 0),
                },
              ),
            )
          : plan.host.foreignObject;
      final scene = await plan.prepare(
        budget: budget,
        images: SvgGraphicsImages(
          rasters: backgroundImages,
          evidenceRasters: evidenceImages,
          intrinsicSizes: intrinsicImageSizes,
        ),
        cancellation: cancellation,
        preReserved: true,
        placement: box.transform.compose(box.svgContentTransform!),
        host: SvgFeatureHost(foreignObject: foreignHost, text: plan.host.text),
      );
      _svgScenes.add(scene);
      if (foreignHost is FixedForeignObjectLayoutService) {
        _retainedHostGeometries.addAll(foreignHost.retainedGeometries);
      }
      box.svgScene = scene;
      if (!scene.capability.isComplete) {
        _svgFailure ??= scene.capability;
      }
      if (scene.picture == null) {
        _svgFailure ??= RenderSectionCapability(
          sectionIndex: page.sectionIndex,
          reason: 'Inline SVG prepared no picture',
          constructs: [
            OffendingConstruct(
              kind: CapabilityConstructKind.render,
              identifier: 'svg-picture-missing',
            ),
          ],
        );
      }
      if (scene.geometry.completeness is IncompleteGeometry) {
        _issues.addAll(
          (scene.geometry.completeness as IncompleteGeometry).issues,
        );
      }
    }
  }
}
