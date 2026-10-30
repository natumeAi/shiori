import 'dart:collection' show HashSet;

import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_preparation_plan.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';

/// Retained alpha evidence of one published scene, measured from the footprints
/// it actually holds. Footprints are counted once by identity; samples that two
/// footprint objects share are counted per object (safe, never an undercharge).
final class RetainedEvidence {
  const RetainedEvidence._(this.footprints, this.storageBytes, this.wrappers);

  /// Distinct footprint objects reachable from the published geometry: paint
  /// footprints and the mask coverage they carry.
  final int footprints;

  /// Sum of [GeometryAlphaFootprint.storageBytes] over those footprints.
  final int storageBytes;

  /// Footprint objects the single unit placement of the scene creates (one per
  /// paint footprint plus one per mask application). They share the samples, so
  /// each costs only [GeometryAlphaFootprint.storageOverhead].
  final int wrappers;
  int get placementBytes => wrappers * GeometryAlphaFootprint.storageOverhead;

  /// What the unit ledger holds for this scene's evidence after reconciliation.
  int get chargedBytes => storageBytes + placementBytes;

  /// [published] includes merged/SVG geometry and original foreignObject host
  /// geometry retained by disposal callbacks. [placed] is the geometry the unit
  /// placement copies.
  static RetainedEvidence measure(
    Iterable<SourceGeometry> published, {
    required SourceGeometry placed,
  }) {
    final seen = HashSet<GeometryAlphaFootprint>.identity();
    var bytes = 0;
    void count(GeometryAlphaFootprint footprint) {
      if (seen.add(footprint)) bytes += footprint.storageBytes;
    }

    for (final geometry in published) {
      for (final paint in geometry.paint) {
        final footprint = paint.alphaFootprint;
        if (footprint == null) continue;
        count(footprint);
        for (final mask in footprint.masks) {
          count(mask.coverage);
        }
      }
    }
    var wrappers = 0;
    for (final paint in placed.paint) {
      final footprint = paint.alphaFootprint;
      if (footprint != null) wrappers += 1 + footprint.masks.length;
    }
    return RetainedEvidence._(seen.length, bytes, wrappers);
  }
}

/// A3 reserves the plan through its shared SceneResourceBudget and existing
/// picture/decoded owners BEFORE creating this ticket. No second unit owner.
/// A spread shares one aggregate owner using A3's independent reference releases.
final class FixedSceneAdmission {
  FixedSceneAdmission({
    required this.plan,
    required this.sceneLease,
    required this.pictureBytes,
    required this.decodedImageBytes,
    required this.reconcilePictureBytes,
    required void Function() releaseReservations,
  }) : _releaseSurfaceReservation = releaseReservations {
    if (pictureBytes < plan.pictureBytes ||
        decodedImageBytes < plan.decodedImageBytes ||
        sceneLease.isReleased ||
        plan.resources.entries.any(
          (e) => (sceneLease.charge[e.key] ?? 0) < e.value,
        )) {
      throw ArgumentError(
        'Fixed plan must be fully reserved before preparation',
      );
    }
  }
  final FixedPreparationPlan plan;
  final SceneResourceLease sceneLease;
  final int pictureBytes, decodedImageBytes;
  final bool Function(int actualBytes) reconcilePictureBytes;
  void Function()? _releaseSurfaceReservation;
  bool _consumed = false, _evidenceReconciled = false;
  int _evidenceReleased = 0;
  RetainedEvidence? _evidence;

  /// Measured evidence once reconciled, else null.
  RetainedEvidence? get evidence => _evidence;

  /// Bytes of the vector reservation returned by reconciliation.
  int get evidenceReleased => _evidenceReleased;
  void consume(FixedPreparationPlan expected) {
    if (_consumed ||
        _releaseSurfaceReservation == null ||
        sceneLease.isReleased ||
        !identical(plan, expected)) {
      throw StateError('Fixed admission is stale, mismatched or consumed');
    }
    _consumed = true;
  }

  /// Final step of a successful preparation, before publication. The unit
  /// holds the plan's safe upper bound for retained evidence until here; this
  /// shrinks that part of the shared reservation to the footprint bytes actually
  /// stored (plus their single placement wrappers) and releases only the excess.
  /// It is the last allocation-free step: no footprint may be created later, so
  /// a second call is a defect. When the stored bytes do not fall below the
  /// bound nothing is released. Failure and cancellation never reach this call;
  /// they release the whole remaining charge once through [dispose].
  int reconcileEvidence(RetainedEvidence evidence) {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    if (_evidenceReconciled ||
        !_consumed ||
        _releaseSurfaceReservation == null ||
        sceneLease.isReleased) {
      throw StateError('Evidence reconciliation is stale or repeated');
    }
    _evidenceReconciled = true;
    _evidence = evidence;
    final excess = plan.retainedEvidenceBytes - evidence.chargedBytes;
    if (excess <= 0) return 0;
    sceneLease.shrink(SceneResource.vectorBytes, excess);
    return _evidenceReleased = excess;
  }

  bool reconcilePicture(int bytes) =>
      bytes <= pictureBytes && bytes >= 0 && reconcilePictureBytes(bytes);
  void dispose() {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    final release = _releaseSurfaceReservation;
    if (release == null) return;
    _releaseSurfaceReservation = null;
    // A3 owns the aggregate lease. The callback releases this constituent's
    // reference; only its last reference may release the shared unit charge.
    release();
  }
}
