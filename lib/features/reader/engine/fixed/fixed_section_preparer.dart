import 'dart:async';
import 'dart:ui' as ui;

import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/place_source_geometry.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_preparation_plan.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene_admission.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/layout/font_mapping.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/paragraph_factory.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';

final class FixedPreparationFailure implements Exception {
  const FixedPreparationFailure(this.capability);
  final SectionCapability capability;
}

/// Only this result can publish. Failed/partial scenes are disposed internally.
final class PreparedFixedScene {
  PreparedFixedScene._(this.plan, this.scene, this._images, this._admission);
  final FixedPreparationPlan plan;
  final FixedScene scene;
  final List<FixedImageLease> _images;
  final FixedSceneAdmission _admission;
  bool _disposed = false;
  SourceGeometry get geometry => scene.geometry;

  /// Companion to drawing scene.picture under the same slot matrix once.
  /// A3 caches this prepared value; motion/proof must not reapply the slot.
  SourceGeometry geometryForUnit(
    AffineTransform sourceToUnit, {
    required String registryPrefix,
    int paintOrdinalOffset = 0,
  }) {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    if (_disposed) throw StateError('Fixed scene disposed');
    return placeSourceGeometry(
      geometry,
      sourceToUnit,
      registryPrefix: registryPrefix,
      paintOrdinalOffset: paintOrdinalOffset,
    );
  }

  void dispose() {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    if (_disposed) return;
    _disposed = true;
    scene.dispose();
    for (final image in _images) {
      image.dispose();
    }
    plan.source.dispose();
    _admission.dispose();
  }
}

/// A3 injects its registry, physical registration drain, and face selector.
/// drainFonts must await started/coalesced native registrations, not merely
/// canceled FontRegistry waiter futures. A2 does not own those process loads.
final class FixedSectionPreparer {
  FixedSectionPreparer({
    required this.fonts,
    required this.drainFonts,
    this.selectFace,
  });
  final FontRegistry fonts;
  final Future<void> Function() drainFonts;
  final ResolvedFontFamilies Function(ParagraphFontRequest)? selectFace;
  FixedPreparationPlan plan(FixedSourceLease source) =>
      FixedPreparationPlan.inspect(source);

  FixedPreparationOperation prepare(
    FixedPreparationPlan plan,
    FixedSceneAdmission admission, {
    PublicationCancellation? cancellation,
  }) {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    admission.consume(plan);
    plan.source.transfer();
    return FixedPreparationOperation._(
      this,
      plan,
      admission,
      cancellation ?? PublicationCancellation(),
    );
  }
}

/// result cancels promptly; drained waits for physical work AND destruction.
/// The caller retains its owner until drained, then may reuse the reserve.
final class FixedPreparationOperation {
  FixedPreparationOperation._(
    this._preparer,
    this.plan,
    this._admission,
    this.cancellation,
  ) {
    _unsubscribe = cancellation.listen(() {
      if (!_result.isCompleted) {
        _result.completeError(const PreparationCancelled());
      }
    });
    drained = _run();
  }
  final FixedSectionPreparer _preparer;
  final FixedPreparationPlan plan;
  final FixedSceneAdmission _admission;
  final PublicationCancellation cancellation;
  final _result = Completer<PreparedFixedScene>();
  late final void Function() _unsubscribe;
  late final Future<void> drained;
  Future<PreparedFixedScene> get result => _result.future;
  void cancel() => cancellation.cancel();
  void _check() {
    if (cancellation.isCanceled) throw const PreparationCancelled();
    plan.source.requireLive();
  }

  Future<void> _run() async {
    FixedScene? scene;
    final images = <FixedImageLease>[];
    var published = false, fontWork = false;
    try {
      _check();
      if (!plan.capability.isComplete) {
        throw FixedPreparationFailure(plan.capability);
      }
      final faces = plan.source.styles.fontFaces;
      final families = <String>{};
      if (_preparer.selectFace == null &&
          faces.any((f) => !families.add(f.family.toLowerCase()))) {
        throw FixedPreparationFailure(
          UnsupportedSectionCapability(
            sectionIndex: plan.source.page.sectionIndex,
            reason: 'Descriptor-aware font selection required',
            constructs: [
              OffendingConstruct(
                kind: CapabilityConstructKind.font,
                identifier: 'descriptor-selection-required',
              ),
            ],
          ),
        );
      }
      fontWork = true;
      final aliases = await _preparer.fonts.loadResources(
        plan.source.resources,
        faces,
        scope: plan.source.page.content.sha256,
        requiredFonts: true,
        cancellation: cancellation,
      );
      _check();
      // Fixed decoration bands need the pinned SFNT post/OS/2 metrics. WOFF
      // faces remain on the engine decoration fallback.
      final decorationMetrics = <String, FontDecorationMetrics>{};
      for (final face in faces) {
        final alias = aliases[face.family.toLowerCase()];
        final bytes = plan.source.resources.bytes(face.archivePath);
        if (alias == null || bytes == null) continue;
        final metrics = FontDecorationMetrics.tryParseSfnt(bytes);
        if (metrics != null) decorationMetrics[alias] = metrics;
      }
      final backgroundImages = <String, ui.Image>{};
      for (final entry in plan.source.images.entries) {
        final image = await entry.value.acquire(cancellation);
        images.add(image);
        _check();
        if (image.image.width != entry.value.width ||
            image.image.height != entry.value.height) {
          throw const SceneAdmissionException(
            SceneAdmissionFailure.resourceExhausted,
          );
        }
        backgroundImages[entry.key] = image.image;
      }
      // Local suballocation ledger is prepaid by the caller's shared lease.
      // It is not another process/unit reservation; no double shared charge.
      final limits = {
        for (final r in SceneResource.values)
          r: (plan.resources[r] ?? 0) > 0 ? plan.resources[r]! : 1,
      };
      scene = await FixedSceneBuilder(
        document: plan.source.document,
        styles: plan.source.styles,
        page: plan.source.page,
        size: (plan.dimensions as ResolvedDimensions).size,
        fonts: ParagraphFonts(
          embedded: aliases,
          selectFace: _preparer.selectFace,
          decorationMetrics: decorationMetrics,
        ),
        backgroundImages: backgroundImages,
        cancellation: cancellation,
        budget: SceneResourceBudget(
          limits: limits,
          sourceDepthLimit: plan.sourceDepth,
          layerDepthLimit: plan.layerDepth,
        ),
      ).build();
      _check();
      if (!scene.capability.isComplete ||
          scene.geometry.completeness is! CompleteGeometry) {
        throw FixedPreparationFailure(
          scene.capability.isComplete
              ? RenderSectionCapability(
                  sectionIndex: plan.source.page.sectionIndex,
                  reason: 'Fixed source geometry incomplete',
                  constructs: [
                    OffendingConstruct(
                      kind: CapabilityConstructKind.render,
                      identifier: 'incomplete-geometry',
                    ),
                  ],
                )
              : scene.capability,
        );
      }
      if (!_admission.reconcilePicture(scene.picture.approximateBytesUsed)) {
        throw const SceneAdmissionException(
          SceneAdmissionFailure.resourceExhausted,
        );
      }
      _check();
      _unsubscribe();
      _result.complete(PreparedFixedScene._(plan, scene, images, _admission));
      published = true;
    } on Object catch (error, stack) {
      if (!_result.isCompleted) _result.completeError(error, stack);
    } finally {
      _unsubscribe();
      if (!published) {
        try {
          if (fontWork) await _preparer.drainFonts();
        } finally {
          scene?.dispose();
          for (final image in images) {
            image.dispose();
          }
          plan.source.dispose();
          _admission.dispose();
        }
      }
    }
  }
}
