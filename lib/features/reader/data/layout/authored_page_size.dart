/// Positive finite dimensions in authored CSS pixels; viewBox origin belongs
/// in the transform, never in the width or height.
final class AuthoredPageSize {
  AuthoredPageSize(this.width, this.height) {
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      throw ArgumentError('Invalid authored page dimensions');
    }
  }

  final double width, height;

  @override
  bool operator ==(Object other) =>
      other is AuthoredPageSize &&
      width == other.width &&
      height == other.height;
  @override
  int get hashCode => Object.hash(width, height);
}

enum DimensionSource { viewportMeta, svgViewBox, svgSize, rasterIntrinsic }

/// A result contract, not a dimension resolver. Failure variants have no size.
sealed class DimensionResolution {
  DimensionResolution(this.reason) {
    if (reason.trim().isEmpty) {
      throw ArgumentError('A dimension reason is required');
    }
  }
  final String reason;
}

final class ResolvedDimensions extends DimensionResolution {
  ResolvedDimensions({
    required this.size,
    required this.source,
    required String reason,
  }) : super(reason);
  final AuthoredPageSize size;
  final DimensionSource source;

  @override
  bool operator ==(Object other) =>
      other is ResolvedDimensions &&
      size == other.size &&
      source == other.source &&
      reason == other.reason;
  @override
  int get hashCode => Object.hash(runtimeType, size, source, reason);
}

final class MalformedDimensions extends DimensionResolution {
  MalformedDimensions(super.reason);
  @override
  bool operator ==(Object other) =>
      other is MalformedDimensions && reason == other.reason;
  @override
  int get hashCode => Object.hash(runtimeType, reason);
}

final class UnsupportedDimensions extends DimensionResolution {
  UnsupportedDimensions(super.reason);
  @override
  bool operator ==(Object other) =>
      other is UnsupportedDimensions && reason == other.reason;
  @override
  int get hashCode => Object.hash(runtimeType, reason);
}
