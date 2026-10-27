import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/library/data/library_decode_exception.dart';
import 'package:shiori/features/library/data/models/server_timestamp.dart';

void main() {
  const converter = ServerTimestampConverter();
  const fractions = {
    '1': 100000,
    '12': 120000,
    '123': 123000,
    '1234': 123400,
    '12345': 123450,
    '123456': 123456,
    '1234567': 123456,
    '12345678': 123456,
    '123456789': 123456,
  };
  for (final entry in fractions.entries) {
    test(
      '${entry.key.length} fractional digits retain UTC instant and raw',
      () {
        for (final time in [
          '2026-01-02 03:04:05.${entry.key}',
          for (final separator in [' ', 'T']) ...[
            '2026-01-02${separator}03:04:05.${entry.key}Z',
            '2026-01-02${separator}11:04:05.${entry.key}+08:00',
            '2026-01-01${separator}22:04:05.${entry.key}-05:00',
          ],
        ]) {
          final value = converter.fromJson(time);
          expect(
            value.utc,
            DateTime.utc(
              2026,
              1,
              2,
              3,
              4,
              5,
            ).add(Duration(microseconds: entry.value)),
            reason: time,
          );
          expect(value.utc.isUtc, isTrue);
          expect(value.raw, time);
          expect(converter.toJson(value), time);
        }
      },
    );
  }

  test('fraction precision never rounds across a second or day', () {
    for (final prefix in ['1969-12-31', '2026-12-31']) {
      for (final fraction in ['000000001', '999999999']) {
        final value = converter.fromJson('$prefix 23:59:59.$fraction');
        final second = converter.fromJson('$prefix 23:59:59').utc;
        expect(
          value.utc.difference(second).inMicroseconds,
          fraction == '000000001' ? 0 : 999999,
        );
      }
    }
    expect(
      converter.fromJson('2026-01-01T00:00:00.999999999+00:01').utc,
      DateTime.utc(2025, 12, 31, 23, 59, 0, 999, 999),
    );
  });

  test('second-only and fractional timestamps order by UTC instant', () {
    final ordered = [
      '2026-01-02 03:04:05',
      '2026-01-02 03:04:05.000001',
      '2026-01-02T11:04:05.100+08:00',
      '2026-01-02 03:04:05.900',
      '2026-01-02 03:04:05.999999999',
      '2026-01-02 03:04:06',
    ].map(converter.fromJson).toList();
    for (var i = 1; i < ordered.length; i++) {
      expect(ordered[i - 1].utc.compareTo(ordered[i].utc), lessThan(0));
    }
  });

  for (final raw in [
    for (final suffix in ['', 'Z', '+08:00', '-05:00'])
      for (final fraction in ['.', '.1234567890', '.12a', '.1.2', ',123'])
        '2026-01-02 03:04:05$fraction$suffix',
    '2026-01-02T03:04:05.123',
    '2026-02-30 03:04:05.123',
    '2026-00-02 03:04:05.123',
    '2026-01-00 03:04:05.123',
    '2026-01-02 24:04:05.123',
    '2026-01-02 03:60:05.123',
    '2026-01-02 03:04:60.123',
    '2026-01-02T03:04:05.123+24:00',
    '2026-01-02T03:04:05.123-00:60',
    '2026-01-02 03:04:05.123Z\n',
  ]) {
    test('rejects malformed fractional timestamp $raw', () {
      expect(
        () => converter.fromJson(raw),
        throwsA(
          isA<LibraryDecodeException>().having(
            (e) => e.invariant,
            'invariant',
            LibraryInvariant.timestamp,
          ),
        ),
      );
    });
  }
}
