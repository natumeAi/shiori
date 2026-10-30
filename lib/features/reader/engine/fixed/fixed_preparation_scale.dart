import 'dart:math' as math;

/// Frozen device pixels per authored CSS pixel. Evidence never uses this scale.
final class FixedPreparationScale {
  const FixedPreparationScale.authored() : value = 1;

  factory FixedPreparationScale(double value) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(value, 'scale');
    }
    return FixedPreparationScale._(value);
  }
  const FixedPreparationScale._(this.value);

  factory FixedPreparationScale.fit({
    required double authoredWidth,
    required double authoredHeight,
    required double viewWidth,
    required double viewHeight,
    required double devicePixelRatio,
  }) {
    for (final dimension in [
      authoredWidth,
      authoredHeight,
      viewWidth,
      viewHeight,
      devicePixelRatio,
    ]) {
      if (!dimension.isFinite || dimension <= 0) {
        throw ArgumentError('Fixed fit dimensions must be positive and finite');
      }
    }
    return FixedPreparationScale(
      math.min(viewWidth / authoredWidth, viewHeight / authoredHeight) *
          devicePixelRatio,
    );
  }

  final double value;
  int pixels(double authored) => math.max(1, (authored * value).ceil());

  /// Preserve intrinsic aspect/layout separately from rounded decode dimensions.
  ({int width, int height}) imageTarget(int width, int height) => (
    width: math.min(width, pixels(width.toDouble())),
    height: math.min(height, pixels(height.toDouble())),
  );
}
