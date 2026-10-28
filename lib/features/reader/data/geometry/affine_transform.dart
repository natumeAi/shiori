/// Column-vector affine matrix [a c e; b d f; 0 0 1]. No native objects.
final class AffineTransform {
  AffineTransform(this.a, this.b, this.c, this.d, this.e, this.f) {
    if (![a, b, c, d, e, f].every((v) => v.isFinite)) {
      throw ArgumentError('Affine coefficients must be finite');
    }
  }
  const AffineTransform.identity() : a = 1, b = 0, c = 0, d = 1, e = 0, f = 0;

  final double a, b, c, d, e, f;

  /// Normalize each column before testing singularity, avoiding determinant
  /// overflow/underflow for independently scaled authored axes.
  TransformInversion inverse() {
    final firstScale = a.abs() > b.abs() ? a.abs() : b.abs();
    final secondScale = c.abs() > d.abs() ? c.abs() : d.abs();
    if (firstScale == 0 || secondScale == 0) {
      return const NonInvertibleTransform(InversionFailure.singular);
    }
    final na = a / firstScale, nb = b / firstScale;
    final nc = c / secondScale, nd = d / secondScale;
    final determinant = na * nd - nb * nc;
    if (determinant == 0) {
      return const NonInvertibleTransform(InversionFailure.singular);
    }
    final ia = nd / determinant / firstScale;
    final ib = -nb / determinant / secondScale;
    final ic = -nc / determinant / firstScale;
    final id = na / determinant / secondScale;
    final values = [ia, ib, ic, id, -(ia * e + ic * f), -(ib * e + id * f)];
    if (!values.every((v) => v.isFinite)) {
      return const NonInvertibleTransform(InversionFailure.numericRange);
    }
    return InvertedTransform(
      AffineTransform(
        values[0],
        values[1],
        values[2],
        values[3],
        values[4],
        values[5],
      ),
    );
  }

  /// this * inner: apply inner first. Final viewport fit is a separate matrix.
  AffineTransform compose(AffineTransform inner) => AffineTransform(
    a * inner.a + c * inner.b,
    b * inner.a + d * inner.b,
    a * inner.c + c * inner.d,
    b * inner.c + d * inner.d,
    a * inner.e + c * inner.f + e,
    b * inner.e + d * inner.f + f,
  );

  @override
  bool operator ==(Object other) =>
      other is AffineTransform &&
      (a, b, c, d, e, f) ==
          (other.a, other.b, other.c, other.d, other.e, other.f);
  @override
  int get hashCode => Object.hash(a, b, c, d, e, f);
}

enum InversionFailure { singular, numericRange }

sealed class TransformInversion {
  const TransformInversion();
}

final class InvertedTransform extends TransformInversion {
  const InvertedTransform(this.transform);
  final AffineTransform transform;
  @override
  bool operator ==(Object other) =>
      other is InvertedTransform && transform == other.transform;
  @override
  int get hashCode => Object.hash(runtimeType, transform);
}

final class NonInvertibleTransform extends TransformInversion {
  const NonInvertibleTransform(this.reason);
  final InversionFailure reason;
  @override
  bool operator ==(Object other) =>
      other is NonInvertibleTransform && reason == other.reason;
  @override
  int get hashCode => Object.hash(runtimeType, reason);
}
