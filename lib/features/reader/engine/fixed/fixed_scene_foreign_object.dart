part of 'fixed_scene.dart';

/// The fixed host uses the same layout, paragraph, paint and alpha-evidence
/// routines for the opaque XHTML subtree as for the surrounding fixed page.
final class FixedForeignObjectLayoutService
    implements SvgForeignObjectEvidenceLayoutService {
  FixedForeignObjectLayoutService({
    required this.styles,
    required this.page,
    ParagraphFonts? fonts,
    this.backgroundImages = const {},
    this.evidenceImages = const {},
    this.intrinsicImageSizes = const {},
    this.preparationScale = const FixedPreparationScale.authored(),
    this.budget,
  }) : fonts = fonts ?? ParagraphFonts();
  final CssStyledDocument styles;
  final SourcePageId page;
  final ParagraphFonts fonts;
  final Map<String, ui.Image> backgroundImages;
  final Map<String, ui.Image> evidenceImages;
  final Map<String, ui.Size> intrinsicImageSizes;
  final FixedPreparationScale preparationScale;
  final SceneResourceBudget? budget;
  final _evidence = Expando<SvgForeignObjectEvidence>();
  final List<SourceGeometry> retainedGeometries = [];
  int _serial = 0;
  @override
  bool get available => true;
  @override
  SvgForeignObjectEvidence evidenceFor(SvgForeignObjectLayout layout) =>
      _evidence[layout]!;

  @override
  Future<SvgForeignObjectLayout?> layout(
    SvgForeignObjectRequest request,
  ) async {
    final size = AuthoredPageSize(
      request.viewport.width,
      request.viewport.height,
    );
    final builder = FixedSceneBuilder(
      document: request.document,
      styles: styles,
      page: page,
      size: size,
      fonts: fonts,
      backgroundImages: backgroundImages,
      evidenceImages: evidenceImages,
      intrinsicImageSizes: intrinsicImageSizes,
      preparationScale: preparationScale,
      budget: budget,
      cancellation: request.cancellation,
    );
    // Validate the native evidence grid before allocating paragraphs/pictures.
    builder.budget
        .reserveLayer(size.width.ceil(), size.height.ceil(), buffers: 2)
        .release();
    final recorder = ui.PictureRecorder();
    FixedScene? scene;
    try {
      builder._checkCancellation();
      final viewport = ui.Rect.fromLTWH(0, 0, size.width, size.height);
      // A neutral containing box supplies the foreign viewport. The source
      // foreignObject's SVG transform/opacity are applied by the SVG module.
      builder._foreignRoot = request.nodeIndex;
      final root = builder._layout(
        request.nodeIndex,
        null,
        viewport,
        ui.Offset.zero,
        null,
        0,
      )!;
      builder._clips.add(
        GeometryClip(
          id: 'foreign-viewport',
          region: GeometryRegion(
            left: 0,
            top: 0,
            width: size.width,
            height: size.height,
            transform: const AffineTransform.identity(),
          ),
        ),
      );
      builder._transforms(root, const AffineTransform.identity(), 1, const [
        'foreign-viewport',
      ]);
      final canvas = ui.Canvas(recorder)..clipRect(viewport);
      builder._paintContext(canvas, root);
      await builder._resolveCoverage();
      builder._checkCancellation();
      builder._checkContentConservation();
      final capability = builder._capability();
      final geometry = builder._export();
      scene = FixedScene._(
        recorder.endRecording(),
        builder._boxes,
        builder._texts,
        geometry,
        capability,
        const [],
        builder._leases,
        builder._retainedHostGeometries,
      );
      if (!capability.isComplete ||
          geometry.completeness is! CompleteGeometry) {
        throw SvgFeatureRefusal(
          request.nodeIndex,
          capability.constructs.firstOrNull?.identifier ??
              'svg-foreignObject-incomplete-geometry',
        );
      }
      final placed = placeSourceGeometry(
        geometry,
        request.transform,
        registryPrefix: 'foreign-${request.nodeIndex}-${_serial++}',
      );
      final result = SvgForeignObjectLayout(
        picture: scene.picture,
        bounds: viewport,
        fragments: placed.fragments
            .where((f) => f.nodeIndex != request.nodeIndex)
            .toList(),
        clips: placed.clips,
      );
      _evidence[result] = SvgForeignObjectEvidence(
        geometry: placed,
        dispose: scene.dispose,
      );
      // Transfer the actual payload (not a wrapper) to the SVG picture owner,
      // whose retained-picture byte reconciliation now includes this picture.
      scene._ownsPicture = false;
      retainedGeometries.addAll([geometry, ...scene.retainedHostGeometries]);
      return result;
    } catch (_) {
      if (scene != null) {
        scene.dispose();
      } else {
        if (recorder.isRecording) recorder.endRecording().dispose();
        for (final text in builder._texts) {
          text.paragraph.dispose();
          text._inline?.dispose();
        }
        for (final pair in builder._coveragePictures) {
          pair.$2.dispose();
        }
        for (final lease in builder._leases) {
          lease.release();
        }
      }
      rethrow;
    }
  }
}

ComputedStyle _foreignRootStyle(
  ComputedStyle inherited,
  AuthoredPageSize size,
) => ComputedStyle(
  display: StyleDisplay.block,
  width: StyleLength.px(size.width),
  height: StyleLength.px(size.height),
  fontSize: inherited.fontSize,
  fontFamilies: inherited.fontFamilies,
  fontWeight: inherited.fontWeight,
  fontStyle: inherited.fontStyle,
  color: inherited.color,
  lineHeight: inherited.lineHeight,
  letterSpacing: inherited.letterSpacing,
  whiteSpace: inherited.whiteSpace,
  textAlign: inherited.textAlign,
  writingMode: inherited.writingMode,
  direction: inherited.direction,
);
