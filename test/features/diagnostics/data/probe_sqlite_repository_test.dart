import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shiori/core/diagnostics/diagnostic_record.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/diagnostics/data/diagnostic_export_repository.dart';
import 'package:shiori/features/diagnostics/data/probe_sqlite_repository.dart';
import 'package:shiori/features/diagnostics/data/probe_sqlite_result.dart';
import 'package:shiori/features/diagnostics/data/probe_sqlite_runner.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../helpers/probe_storage_fixtures.dart';

void main() {
  late Directory root;
  late TestDirectories directories;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('shiori-sqlite-a6-');
    directories = TestDirectories(root);
  });
  tearDown(() async => root.delete(recursive: true));

  test('real isolated check commits, reopens, rolls back and refuses future schema', () async {
    final support = await directories.applicationSupport();
    await support.create();
    final sentinel = File('${support.path}/probe-marker.txt');
    await sentinel.writeAsString('preserve');
    final repository = ProbeSqliteRepository(directories);
    for (var run = 0; run < 2; run++) {
      final result = await repository.run();
      expect(result.ranOffRootIsolate, isTrue);
      expect(result.passed, isTrue);
      expect(result.steps.keys, unorderedEquals(ProbeSqliteResult.stepNames));
      expect(result.steps.values, everyElement(isTrue));
      expect(result.failure, isNull);
      expect(result.libraryVersion, sqlite3.version.libVersion);
      expect(result.sourceId, sqlite3.version.sourceId);
      expect(result.compileOptions, unorderedEquals(sqlite3.compileOptions));
      expect(result.journalMode, 'delete');
      expect(result.synchronous, 2);
      expect(result.elapsedUs, greaterThan(0));
      expect(result.checkedAt.isUtc, isTrue);
      expect(
        await Directory('${support.path}/probe-sqlite-self-check')
            .list()
            .toList(),
        isEmpty,
      );
      expect(await sentinel.readAsString(), 'preserve');
      expect(await (await directories.documents()).exists(), isFalse);
    }
  });

  test('package version snapshot matches the resolved lockfile', () async {
    final lock = await File('pubspec.lock').readAsString();
    final sqlite = RegExp(r'  sqlite3:\r?\n[\s\S]*?    version: "([^"]+)"')
        .firstMatch(lock);
    expect(sqlite?.group(1), probeSqlitePackageVersion);
  });

  test(
    'scratch directory failure is exported as failed and unrun steps',
    () async {
      final support = await directories.applicationSupport();
      await support.create();
      await File('${support.path}/probe-sqlite-self-check')
          .writeAsString('blocked');
      final result = await ProbeSqliteRepository(directories).run();
      expect(result.passed, isFalse);
      expect(result.steps['open'], isFalse);
      expect(result.steps['commit'], isNull);
      expect(result.steps['cleanup'], isTrue);
      expect(result.failure, 'filesystem_error');
      expect(jsonEncode(result.toJson()), isNot(contains(root.path)));
      expect(await (await directories.documents()).exists(), isFalse);
    },
  );

  test('runner refuses root isolate before touching SQLite or disk', () {
    final result = runProbeSqliteCheck(root.path, Isolate.current.controlPort);
    expect(result.ranOffRootIsolate, isFalse);
    expect(result.steps['open'], isFalse);
    expect(result.passed, isFalse);
    expect(root.listSync(), isEmpty);
  });

  test('directory lookup failures remain typed storage errors', () async {
    final mock = MockDirectories();
    when(mock.applicationSupport)
        .thenThrow(const FileSystemException('unavailable'));
    await expectLater(
      ProbeSqliteRepository(mock).run(),
      throwsA(isA<ParseException>()),
    );
    verifyNever(mock.documents);
  });

  test('directory failure logs and causes contain no private path', () async {
    const privatePath = '/private/sqlite-check-sensitive-directory';
    const original = FileSystemException(
      'Cannot access $privatePath',
      privatePath,
    );
    final mock = MockDirectories();
    when(mock.applicationSupport).thenAnswer(
      (_) => Future<Directory>.error(
        original,
        StackTrace.fromString('lookup at $privatePath'),
      ),
    );
    final records = <LogRecord>[];
    final logger = Logger.root;
    final previousLevel = logger.level;
    logger.level = Level.ALL;
    final subscription = logger.onRecord.listen(records.add);
    addTearDown(() async {
      await subscription.cancel();
      logger.level = previousLevel;
    });

    await expectLater(
      ProbeSqliteRepository(mock).run(),
      throwsA(
        isA<ParseException>()
            .having(
              (error) => error.toString(),
              'string',
              isNot(contains(privatePath)),
            )
            .having((error) => error.cause, 'cause', isNot(same(original)))
            .having(
              (error) => error.cause.toString(),
              'sanitized cause',
              'FormatException: sqlite_directory_unavailable',
            ),
      ),
    );
    expect(records, hasLength(2));
    expect(records.first.loggerName, 'DirectoryAccess');
    expect(records.first.message, 'directory_filesystem_unavailable');
    expect(records.last.loggerName, 'ProbeSqliteRepository');
    expect(records.last.message, 'sqlite_directory_unavailable');
    for (final record in records) {
      expect(record.error, isNull);
      expect(record.stackTrace, isNull);
      expect(record.object, isNull);
      for (final field in [
        record.level,
        record.message,
        record.object,
        record.loggerName,
        record.time,
        record.sequenceNumber,
        record.error,
        record.stackTrace,
        record.zone,
        record,
      ]) {
        expect(field.toString(), isNot(contains(privatePath)));
      }
    }
    verifyNever(mock.documents);
  });

  test(
    'directory plugin failures redact paths before repository mapping',
    () async {
      const privatePath = '/private/sqlite-plugin-sensitive-directory';
      final original = PlatformException(
        code: privatePath,
        message: privatePath,
        details: privatePath,
        stacktrace: privatePath,
      );
      final mock = MockDirectories();
      when(mock.applicationSupport).thenAnswer(
        (_) => Future<Directory>.error(
          original,
          StackTrace.fromString('lookup at $privatePath'),
        ),
      );
      final records = <LogRecord>[];
      final previousLevel = Logger.root.level;
      Logger.root.level = Level.ALL;
      final subscription = Logger.root.onRecord.listen(records.add);
      addTearDown(() async {
        await subscription.cancel();
        Logger.root.level = previousLevel;
      });
      await expectLater(
        ProbeSqliteRepository(mock).run(),
        throwsA(
          isA<ParseException>()
              .having(
                (e) => e.toString(),
                'string',
                isNot(contains(privatePath)),
              )
              .having((e) => e.cause, 'cause', isNot(same(original)))
              .having(
                (e) => e.cause.toString(),
                'sanitized cause',
                'FormatException: directory_platform_unavailable',
              ),
        ),
      );
      expect(records, hasLength(1));
      expect(records.single.loggerName, 'DirectoryAccess');
      expect(records.single.message, 'directory_platform_unavailable');
      expect(records.single.error, isNull);
      expect(records.single.stackTrace, isNull);
      expect(records.single.object, isNull);
      for (final record in records) {
        for (final field in [
          record.level,
          record.message,
          record.object,
          record.loggerName,
          record.time,
          record.sequenceNumber,
          record.error,
          record.stackTrace,
          record.zone,
          record,
        ]) {
          expect(field.toString(), isNot(contains(privatePath)));
        }
      }
      verifyNever(mock.documents);
    },
  );

  test(
    'SQLite export round-trips and old exports have no self-check',
    () async {
      final result = await ProbeSqliteRepository(directories).run();
      final repository = DiagnosticExportRepository(directories);
      final oldRecord = storageRecord();
      final record = oldRecord.copyWith(
        metadata: {
          ...oldRecord.metadata,
          ProbeSqliteResult.metadataKey: result.toJson(),
        },
      );
      final path = await repository.export(record);
      final json =
          jsonDecode(await File(path).readAsString()) as Map<String, Object?>;
      final decoded = DiagnosticRecord.fromJson(json);
      expect(json['schemaVersion'], 1);
      expect(ProbeSqliteResult.fromMetadata(decoded.metadata), result);
      expect(await DiagnosticExportRepository(directories).loadLast(), record);
      await repository.export(oldRecord);
      final loaded = await repository.loadLast();
      expect(loaded, oldRecord);
      expect(ProbeSqliteResult.fromMetadata(loaded!.metadata), isNull);
    },
  );

  test(
    'saved SQLite extension requires supported version and valid shape',
    () async {
      final result = await ProbeSqliteRepository(directories).run();
      final repository = DiagnosticExportRepository(directories);
      for (final invalid in <Object?>[
        null,
        [],
        {...result.toJson()}..remove('schemaVersion'),
        {...result.toJson(), 'schemaVersion': 2},
        {...result.toJson(), 'schemaVersion': '1'},
        {...result.toJson()}..remove('packageVersionSource'),
        {...result.toJson(), 'elapsedUs': -0.5},
        {
          ...result.toJson(),
          'steps': {'open': true},
        },
        {...result.toJson(), 'elapsedUs': -1},
      ]) {
        await repository.export(
          storageRecord().copyWith(
            metadata: {ProbeSqliteResult.metadataKey: invalid},
          ),
        );
        await expectLater(
          repository.loadLast(),
          throwsA(isA<ParseException>()),
        );
      }
    },
  );
}
