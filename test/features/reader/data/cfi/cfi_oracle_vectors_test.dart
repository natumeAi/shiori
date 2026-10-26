import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/cfi/cfi.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';

import 'cfi_vector_support.dart';

void main() {
  for (final fixtureId in oracleFixtureIds) {
    group('oracle vectors: $fixtureId', () {
      final vectors = loadWebkitVectors(fixtureId);
      final grammar = (vectors['grammar']! as List<Object?>)
          .cast<Map<String, Object?>>();
      final sections = (vectors['sections']! as List<Object?>)
          .cast<Map<String, Object?>>();

      test('grammar vectors match parse, serialize, collapse and errors', () {
        for (final vector in grammar) {
          final input = vector['input']! as String;
          final error = vector['error'] as Map<String, Object?>?;
          if (error != null) {
            expect(
              () {
                Cfi.parse(input);
                Cfi.collapse(input);
                Cfi.collapse(input, toEnd: true);
              },
              throwsA(
                isA<CfiException>().having(
                  (e) => e.referenceErrorName,
                  'referenceErrorName',
                  error['name'],
                ),
              ),
              reason: 'input: $input',
            );
            continue;
          }
          final parsed = Cfi.parse(input);
          expect(
            canonicalJson(parsed.toJson()),
            canonicalJson(vector['parsed']),
            reason: 'AST of $input',
          );
          expect(
            Cfi.collapse(input),
            vector['collapsedStart'],
            reason: 'start of $input',
          );
          expect(
            Cfi.collapse(input, toEnd: true),
            vector['collapsedEnd'],
            reason: 'end of $input',
          );
        }
      });

      for (final section in sections) {
        final href = section['href']! as String;
        group('section $href', () {
          final document = documentFromProjection(
            section['projection']! as List<Object?>,
          );
          final base = section['cfiBase']! as String;
          final samples = (section['samples']! as List<Object?>)
              .cast<Map<String, Object?>>();

          test('parse, serialize round trip and collapse', () {
            var failures = 0;
            for (final sample in samples) {
              final cfi = sample['cfi']! as String;
              final parsed = Cfi.parse(cfi);
              if (!_same(parsed.toJson(), sample['parsed']) ||
                  Cfi.serialize(parsed) != cfi ||
                  Cfi.collapse(cfi) != sample['collapsedStart'] ||
                  Cfi.collapse(cfi, toEnd: true) != sample['collapsedEnd']) {
                failures++;
                if (failures < 4) {
                  // Structural coordinates only: never book prose.
                  printOnFailure('mismatch for $cfi');
                }
              }
            }
            expect(failures, 0);
          });

          test('resolve matches the browser range for every sample', () {
            var failures = 0;
            for (final sample in samples) {
              final cfi = sample['cfi']! as String;
              final expected = sample['resolved']! as Map<String, Object?>;
              final range = Cfi.resolve(document, cfi);
              final ok =
                  range.start == _position(expected['start']) &&
                  range.end == _position(expected['end']) &&
                  range.collapsed == expected['collapsed'];
              if (!ok) {
                failures++;
                if (failures < 4) printOnFailure('mismatch for $cfi: $range');
              }
            }
            expect(failures, 0);
          });

          test('export reproduces each vector CFI', () {
            var failures = 0;
            for (final sample in samples) {
              final input = sample['input']! as Map<String, Object?>;
              final collapsed = input['collapsed']! as bool;
              final exported = Cfi.export(
                document,
                _position(input['start']),
                end: collapsed ? null : _position(input['end']),
                sectionBase: base,
              );
              final cfi = sample['cfi']! as String;
              if (exported != cfi || Cfi.compare(exported, cfi) != 0) {
                failures++;
                if (failures < 4) {
                  printOnFailure('export $exported differs from $cfi');
                }
              }
            }
            expect(failures, 0);
          });

          test('sort reproduces the reference order', () {
            final comparison = section['comparison']! as Map<String, Object?>;
            final input = (comparison['input']! as List<Object?>)
                .cast<String>();
            final sorted = (comparison['sorted']! as List<Object?>)
                .cast<String>();
            expect(Cfi.sort(input), sorted);
          });
        });
      }
    });
  }
}

SourcePosition _position(Object? json) {
  final map = json! as Map<String, Object?>;
  return SourcePosition(
    nodeIndex: map['node']! as int,
    offset: map['offset']! as int,
  );
}

bool _same(Object? a, Object? b) =>
    equals(canonicalJson(b)).matches(canonicalJson(a), <Object?, Object?>{});
