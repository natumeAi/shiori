import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/storage/cache_budget.dart';

void main() {
  test('default 512 MiB and inclusive reservation charge/release', () {
    expect(CacheBudget().limit, 512 * 1024 * 1024);
    final budget = CacheBudget(limit: 10);
    final first = budget.reserve(4, usedBytes: 6);
    expect(budget.reservedBytes, 4);
    expect(budget.fits(1, 6), isFalse);
    expect(() => budget.reserve(1, usedBytes: 6), throwsStateError);
    first.release();
    first.release();
    expect(budget.reservedBytes, 0);
    expect(budget.fits(10, 0), isTrue);
  });

  test(
    'invalid limits and negative reservations fail without changing charge',
    () {
      expect(() => CacheBudget(limit: 0), throwsArgumentError);
      final budget = CacheBudget(limit: 10);
      expect(() => budget.reserve(-1, usedBytes: 0), throwsStateError);
      expect(budget.reservedBytes, 0);
    },
  );
}
