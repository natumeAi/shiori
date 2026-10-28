import 'package:shiori/features/reader/data/resources/reader_resource_budget.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_section_preparer.dart';
import 'package:shiori/features/reader/engine/layout/font_format.dart';
import 'package:shiori/features/reader/engine/layout/image_cache.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';

enum ReaderPreparationFailureKind {
  imageAdmission,
  pictureAdmission,
  processFontExhausted,
  requiredFont,
  fixedCapability,
  sceneAdmission,
  encodedAdmission,
}

final class PictureAdmissionException implements Exception {
  const PictureAdmissionException();
}

/// Recovery feedback accompanies the retained accepted page. The original
/// typed cause is preserved; callers must not display arbitrary exception text.
final class ReaderPreparationFailure {
  const ReaderPreparationFailure(this.kind, this.cause);
  final ReaderPreparationFailureKind kind;
  final Object cause;

  static ReaderPreparationFailure? from(Object error) {
    final kind = switch (error) {
      ImageAdmissionException() => ReaderPreparationFailureKind.imageAdmission,
      PictureAdmissionException() =>
        ReaderPreparationFailureKind.pictureAdmission,
      SceneAdmissionException(
        failure: SceneAdmissionFailure.processFontExhausted,
      ) =>
        ReaderPreparationFailureKind.processFontExhausted,
      RequiredFontException() => ReaderPreparationFailureKind.requiredFont,
      FixedPreparationFailure() => ReaderPreparationFailureKind.fixedCapability,
      SceneAdmissionException() => ReaderPreparationFailureKind.sceneAdmission,
      ReaderResourceException() =>
        ReaderPreparationFailureKind.encodedAdmission,
      _ => null,
    };
    return kind == null ? null : ReaderPreparationFailure(kind, error);
  }
}
