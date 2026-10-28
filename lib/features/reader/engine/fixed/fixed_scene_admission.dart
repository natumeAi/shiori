import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_preparation_plan.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';

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
  bool _consumed = false;
  void consume(FixedPreparationPlan expected) {
    if (_consumed ||
        _releaseSurfaceReservation == null ||
        sceneLease.isReleased ||
        !identical(plan, expected)) {
      throw StateError('Fixed admission is stale, mismatched or consumed');
    }
    _consumed = true;
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
