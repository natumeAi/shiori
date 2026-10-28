import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';

void main() {
  test('singular inversion returns a typed result without throwing', () {
    final result = AffineTransform(1, 2, 2, 4, 5, 6).inverse();
    expect(result, const NonInvertibleTransform(InversionFailure.singular));
    expect(AffineTransform(0, 0, 0, 0, 0, 0).inverse(), result);
  });

  test('inverse and composition round trip shear, scale and translation', () {
    final transform = AffineTransform(2, 1, 1, 3, 7, -4);
    final result = transform.inverse();
    expect(result, isA<InvertedTransform>());
    final inverse = (result as InvertedTransform).transform;
    for (final product in [
      transform.compose(inverse),
      inverse.compose(transform),
    ]) {
      expect(product.a, closeTo(1, 1e-12));
      expect(product.d, closeTo(1, 1e-12));
      for (final value in [product.b, product.c, product.e, product.f]) {
        expect(value, closeTo(0, 1e-12));
      }
    }
    final translation = AffineTransform(1, 0, 0, 1, 10, 20);
    final scale = AffineTransform(2, 0, 0, 3, 0, 0);
    expect(translation.compose(scale), AffineTransform(2, 0, 0, 3, 10, 20));
    expect(scale.compose(translation), AffineTransform(2, 0, 0, 3, 20, 60));
  });

  test(
    'nonfinite input is rejected and numeric range failures are explicit',
    () {
      expect(
        () => AffineTransform(double.nan, 0, 0, 1, 0, 0),
        throwsArgumentError,
      );
      expect(
        () => AffineTransform(1, 0, 0, 1, double.infinity, 0),
        throwsArgumentError,
      );
      for (final transform in [
        AffineTransform(1e308, 0, 0, 1e308, 0, 0),
        AffineTransform(1e-200, 0, 0, 1e-200, 0, 0),
        AffineTransform(1e308, 0, 0, 1e-308, 0, 0),
      ]) {
        final result = transform.inverse();
        expect(result, isA<InvertedTransform>());
        final product = transform.compose(
          (result as InvertedTransform).transform,
        );
        expect(product.a, closeTo(1, 1e-12));
        expect(product.d, closeTo(1, 1e-12));
      }
      expect(
        AffineTransform(1e-310, 0, 0, 1, 0, 0).inverse(),
        const NonInvertibleTransform(InversionFailure.numericRange),
      );
    },
  );

  test('matrix and inversion values use exact value equality', () {
    const identity = AffineTransform.identity();
    final equal = AffineTransform(1, 0, 0, 1, 0, 0);
    expect(identity, equal);
    expect(identity.hashCode, equal.hashCode);
    expect(identity, isNot(AffineTransform(1, 0, 0, 1, 1, 0)));
    expect(identity.inverse(), const InvertedTransform(identity));
    expect(
      identity.inverse().hashCode,
      const InvertedTransform(identity).hashCode,
    );
  });
}
