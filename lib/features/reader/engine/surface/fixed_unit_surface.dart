part of 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';

typedef FixedSourceLoader = Future<FixedSourceLease> Function(
  SourcePageId page,
);

extension FixedUnitSurfacePreparation on PageSurfacePool {
  /// Use inspected output dimensions. The shared cache admits the full
  /// intrinsic + output decode peak, including old surfaces and other plans.
  FixedImageRequest fixedImageRequest(
    String key,
    Uint8List bytes, {
    required SourcePageId page,
    required int width,
    required int height,
  }) {
    late final FixedImageRequest request;
    Future<FixedImageLease> acquire(
      PublicationCancellation token,
      int targetWidth,
      int targetHeight,
    ) async {
      if (token.isCanceled) throw const PreparationCancelled();
      final lease = await images.lease(
        '${page.content.bookKey}|${page.content.sha256}|'
        '${page.content.parserVersion}|${page.content.canonicalVersion}|$key',
        bytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
        reservation: _imageCredits[request],
      );
      if (lease == null) {
        throw FixedPreparationFailure(
          RenderSectionCapability(
            sectionIndex: page.sectionIndex,
            reason: 'Required fixed raster could not decode',
            constructs: [
              OffendingConstruct(
                kind: CapabilityConstructKind.render,
                identifier: 'image-decode',
              ),
            ],
          ),
        );
      }
      return FixedImageLease(lease.image, () {
        lease.release(discard: true);
      });
    }

    request = FixedImageRequest(
      width: width,
      height: height,
      acquire: (token) => acquire(token, width, height),
      acquireAt: acquire,
    );
    return request;
  }

  Future<PageSurfaceLease?> prepareFixedUnit(
    ReadingUnit unit, {
    required LayoutIdentity layout,
    required FixedSourceLoader loadSource,
    required FontRegistry fonts,
    FixedPreparationScale? preparationScale,
    PublicationCancellation? cancellation,
  }) async {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    if (unit.kind == ReadingUnitKind.reflowPage ||
        unit.id.content.sha256 != layout.contentId) {
      throw ArgumentError('Expected a matching fixed reading unit');
    }
    final epoch = _epoch;
    final extent = _fixedUnitExtent(unit);
    final scale =
        preparationScale ??
        FixedPreparationScale.fit(
          authoredWidth: extent.width,
          authoredHeight: extent.height,
          viewWidth: layout.viewportWidth,
          viewHeight: layout.viewportHeight,
          devicePixelRatio: layout.devicePixelRatio,
        );
    final token = cancellation ?? PublicationCancellation();
    void check() {
      if (_closed || epoch != _epoch || token.isCanceled) {
        throw const PreparationCancelled();
      }
    }

    final sources = <FixedSourceLease>[];
    final plans = <FixedPreparationPlan>[];
    final preparers = <FixedSectionPreparer>[];
    final scenes = <PreparedFixedScene>[];
    final tickets = <FixedSceneAdmission>[];
    UnitSurfaceReservation? reservation;
    ui.Picture? picture;
    var transferred = false;
    try {
      check();
      for (final slot in unit.slots.whereType<RealSourcePageSlot>()) {
        final source = await loadSource(slot.page);
        sources.add(source);
        check();
        if (source.page != slot.page) {
          throw StateError('Fixed source identity mismatch');
        }
        final preparer = FixedSectionPreparer(
          fonts: fonts,
          drainFonts: fonts.drainFonts,
          selectFace: (request) => fonts.selectFace(
            request.families,
            scope: source.page.content.sha256,
            faces: source.styles.fontFaces,
            weight: request.weight,
            style: request.style,
          ),
        );
        final plan = preparer.plan(source, scale: scale);
        if (!plan.capability.isComplete) {
          throw FixedPreparationFailure(plan.capability);
        }
        if ((plan.dimensions as ResolvedDimensions).size != slot.authoredSize) {
          throw StateError('Composition dimensions differ from source plan');
        }
        plans.add(plan);
        preparers.add(preparer);
      }
      final resources = <SceneResource, int>{};
      var sourceDepth = 0, referenceDepth = 0, layerDepth = 0;
      var pictureBound = 64 * 1024, imageBound = 0;
      for (final plan in plans) {
        for (final entry in plan.resources.entries) {
          resources.update(
            entry.key,
            (n) => n + entry.value,
            ifAbsent: () => entry.value,
          );
        }
        if (plan.sourceDepth > sourceDepth) sourceDepth = plan.sourceDepth;
        if (plan.referenceDepth > referenceDepth) {
          referenceDepth = plan.referenceDepth;
        }
        if (plan.layerDepth > layerDepth) layerDepth = plan.layerDepth;
        pictureBound += plan.pictureBytes;
        imageBound += plan.decodedImageBytes;
      }
      reservation = _reserve(
        unit,
        resources: resources,
        sourceDepth: sourceDepth,
        referenceDepth: referenceDepth,
        layerDepth: layerDepth,
      );
      if (reservation == null) {
        check();
        throw const SceneAdmissionException(
          SceneAdmissionFailure.resourceExhausted,
          resource: SceneResource.readingUnits,
        );
      }
      if (pictureBound > maxPictureBytes - pictureBytes) {
        throw const PictureAdmissionException();
      }
      allocations._pictureBytes += pictureBound;
      reservation._fixedPictureCharge = pictureBound;
      reservation._imageReservation = images.reserveOutput(imageBound);
      reservation._parts = plans.length + 1;
      final owner = reservation;
      for (final plan in plans) {
        var charge = plan.pictureBytes;
        tickets.add(
          FixedSceneAdmission(
            plan: plan,
            sceneLease: owner._resources,
            pictureBytes: plan.pictureBytes,
            decodedImageBytes: plan.decodedImageBytes,
            reconcilePictureBytes: (actual) {
              if (actual > charge) return false;
              allocations._pictureBytes -= charge - actual;
              owner._fixedPictureCharge -= charge - actual;
              charge = actual;
              return true;
            },
            releaseReservations: owner._releasePart,
          ),
        );
        for (final request in plan.source.images.values) {
          _imageCredits[request] = owner._imageReservation;
        }
      }
      for (var i = 0; i < plans.length; i++) {
        check();
        final operation = preparers[i].prepare(
          plans[i],
          tickets[i],
          cancellation: token,
        );
        try {
          scenes.add(await operation.result);
        } finally {
          await operation.drained;
        }
      }
      check();
      // Return unused conservative alpha credit after every physical decode has
      // drained. Retained display entries remain charged by the image cache.
      owner._imageReservation?.release();
      final composed = _composeFixedUnit(unit, scenes, layout);
      picture = composed.picture;
      final actual = picture.approximateBytesUsed;
      if (actual > 64 * 1024) throw const PictureAdmissionException();
      allocations._pictureBytes -= 64 * 1024 - actual;
      owner._fixedPictureCharge -= 64 * 1024 - actual;
      final surface = PreparedPageSurface._fixed(
        picture,
        owner,
        layout,
        scenes,
        composed.geometry,
      );
      _live.add(surface);
      transferred = true;
      return PageSurfaceLease._(this, surface);
    } finally {
      for (final source in sources) {
        for (final request in source.images.values) {
          _imageCredits[request] = null;
        }
      }
      if (!transferred) {
        picture?.dispose();
        for (final scene in scenes) {
          scene.dispose();
        }
        for (final ticket in tickets) {
          ticket.dispose();
        }
        for (final source in sources) {
          source.dispose();
        }
        // Also covers partially constructed ticket lists: no native work remains.
        reservation?.release();
        images.clearUnleased();
      }
    }
  }
}

({ui.Picture picture, List<SourceGeometry> geometry}) _composeFixedUnit(
  ReadingUnit unit,
  List<PreparedFixedScene> scenes,
  LayoutIdentity layout,
) {
  final slots = unit.slots.whereType<RealSourcePageSlot>().toList();
  final extent = _fixedUnitExtent(unit);
  final width = extent.width, height = extent.height;
  final sx = layout.viewportWidth / width, sy = layout.viewportHeight / height;
  final scale = sx < sy ? sx : sy;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final geometry = <SourceGeometry>[];
  var ordinal = 0;
  try {
    canvas.clipRect(
      ui.Rect.fromLTWH(0, 0, layout.viewportWidth, layout.viewportHeight),
    );
    canvas.translate(
      (layout.viewportWidth - width * scale) / 2,
      (layout.viewportHeight - height * scale) / 2,
    );
    canvas.scale(scale);
    for (var i = 0; i < scenes.length; i++) {
      final matrix = slots[i].sourceToUnit;
      canvas.save();
      canvas.transform(
        Float64List.fromList([
          matrix.a,
          matrix.b,
          0,
          0,
          matrix.c,
          matrix.d,
          0,
          0,
          0,
          0,
          1,
          0,
          matrix.e,
          matrix.f,
          0,
          1,
        ]),
      );
      canvas.drawPicture(scenes[i].scene.picture);
      canvas.restore();
      final placed = scenes[i].geometryForUnit(
        matrix,
        registryPrefix: 'source-${slots[i].page.sectionIndex}',
        paintOrdinalOffset: ordinal,
      );
      geometry.add(placed);
      for (final paint in placed.paint) {
        if (paint.paintOrdinal >= ordinal) ordinal = paint.paintOrdinal + 1;
      }
    }
    return (
      picture: recorder.endRecording(),
      geometry: List.unmodifiable(geometry),
    );
  } on Object {
    recorder.endRecording().dispose();
    rethrow;
  }
}

({double width, double height}) _fixedUnitExtent(ReadingUnit unit) {
  final slots = unit.slots.whereType<RealSourcePageSlot>();
  var width = 0.0, height = 0.0;
  for (final slot in slots) {
    final right = slot.sourceToUnit.e + slot.authoredSize!.width;
    final bottom = slot.sourceToUnit.f + slot.authoredSize!.height;
    if (right > width) width = right;
    if (bottom > height) height = bottom;
  }
  if (unit.slots.last is BlankSourcePageSlot) width *= 2;
  return (width: width, height: height);
}
