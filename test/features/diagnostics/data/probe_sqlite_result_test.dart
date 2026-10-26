import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/diagnostics/data/probe_sqlite_result.dart';

void main() {
  final result = ProbeSqliteResult(
    checkedAt: DateTime.utc(2026, 10, 26),
    buildId: 'test-build',
    buildNumber: '1',
    packageVersion: '3.8.0',
    ranOffRootIsolate: true,
    steps: {for (final name in ProbeSqliteResult.stepNames) name: true},
    elapsedUs: 42,
    libraryVersion: 'test-library',
    sourceId: 'test-source',
    compileOptions: ['OPTION_A', 'OPTION_B'],
    journalMode: 'delete',
    synchronous: 2,
  );

  test('valid SQLite result round-trips through JSON and metadata', () {
    final json =
        jsonDecode(jsonEncode(result.toJson())) as Map<String, Object?>;
    expect(ProbeSqliteResult.fromJson(json), result);
    expect(
      ProbeSqliteResult.fromMetadata({ProbeSqliteResult.metadataKey: json}),
      result,
    );
    expect(ProbeSqliteResult.fromJson(json).passed, isTrue);
  });

  test('missing required SQLite fields cannot be defaulted', () {
    for (final key in [
      'schemaVersion',
      'checkedAt',
      'buildId',
      'buildNumber',
      'packageVersion',
      'packageVersionSource',
      'ranOffRootIsolate',
      'steps',
      'elapsedUs',
    ]) {
      final json = {...result.toJson()}..remove(key);
      expect(
        () => ProbeSqliteResult.fromJson(json),
        throwsFormatException,
        reason: key,
      );
      expect(
        () => ProbeSqliteResult.fromMetadata({
          ProbeSqliteResult.metadataKey: json,
        }),
        throwsFormatException,
        reason: key,
      );
    }
  });

  test('SQLite elapsed time rejects fractional and negative raw numbers', () {
    for (final elapsedUs in [-0.5, 0.5, 1.0, -1, '0', null]) {
      final json = {...result.toJson(), 'elapsedUs': elapsedUs};
      expect(
        () => ProbeSqliteResult.fromJson(json),
        throwsFormatException,
        reason: '$elapsedUs',
      );
    }
    expect(
      ProbeSqliteResult.fromJson({...result.toJson(), 'elapsedUs': 0})
          .elapsedUs,
      0,
    );
  });

  test('SQLite raw field types are validated before generated decoding', () {
    for (final fields in <Map<String, Object?>>[
      {'schemaVersion': 1.0},
      {'checkedAt': 42},
      {'checkedAt': '2026-10-26T00:00:00'},
      {'buildId': 1},
      {'buildNumber': 1},
      {'packageVersion': 3.8},
      {'packageVersionSource': null},
      {'ranOffRootIsolate': 'true'},
      {
        'steps': <String, Object?>{...result.steps, 'open': 1},
      },
      {'synchronous': 1.5},
      {'libraryVersion': 1},
      {'sourceId': false},
      {'journalMode': 1},
      {'failure': <String>[]},
      {
        'compileOptions': [1],
      },
    ]) {
      expect(
        () => ProbeSqliteResult.fromJson({...result.toJson(), ...fields}),
        throwsFormatException,
        reason: '$fields',
      );
    }
  });
}
