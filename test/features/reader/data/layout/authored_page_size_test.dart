import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';

void main() {
  test('authored size rejects zero, negative and nonfinite dimensions', () {
    for (final invalid in [0.0, -1.0, double.nan, double.infinity]) {
      expect(() => AuthoredPageSize(invalid, 240), throwsArgumentError);
      expect(() => AuthoredPageSize(320, invalid), throwsArgumentError);
    }
    expect(AuthoredPageSize(320, 240), AuthoredPageSize(320, 240));
    expect(
      AuthoredPageSize(320, 240).hashCode,
      AuthoredPageSize(320, 240).hashCode,
    );
    expect(AuthoredPageSize(320, 240), isNot(AuthoredPageSize(240, 320)));
  });

  test('each resolved source is explicit and has a reason', () {
    for (final source in DimensionSource.values) {
      final result = ResolvedDimensions(
        size: AuthoredPageSize(320, 240),
        source: source,
        reason: 'validated',
      );
      final same = ResolvedDimensions(
        size: AuthoredPageSize(320, 240),
        source: source,
        reason: 'validated',
      );
      expect(result, same);
      expect(result.hashCode, same.hashCode);
      expect(result.source, source);
      expect(result.size.width, 320);
    }
    expect(
      () => ResolvedDimensions(
        size: AuthoredPageSize(1, 1),
        source: DimensionSource.svgSize,
        reason: '',
      ),
      throwsArgumentError,
    );
  });

  test('malformed and unsupported have reasons without a guessed size', () {
    final DimensionResolution malformed = MalformedDimensions('invalid-number');
    final DimensionResolution unsupported = UnsupportedDimensions(
      'unresolved-percentage',
    );
    String outcome(DimensionResolution result) => switch (result) {
      ResolvedDimensions(:final size) => '${size.width}',
      MalformedDimensions(:final reason) => 'malformed:$reason',
      UnsupportedDimensions(:final reason) => 'unsupported:$reason',
    };
    expect(outcome(malformed), 'malformed:invalid-number');
    expect(outcome(unsupported), 'unsupported:unresolved-percentage');
    expect(malformed, MalformedDimensions('invalid-number'));
    expect(unsupported, UnsupportedDimensions('unresolved-percentage'));
    expect(MalformedDimensions('same'), isNot(UnsupportedDimensions('same')));
    expect(() => MalformedDimensions(' '), throwsArgumentError);
    expect(() => UnsupportedDimensions(''), throwsArgumentError);
  });
}
