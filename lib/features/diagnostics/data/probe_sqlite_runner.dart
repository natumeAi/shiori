import 'dart:io';
import 'dart:isolate';

import 'package:shiori/core/config/env.dart';
import 'package:shiori/features/diagnostics/data/probe_sqlite_result.dart';
import 'package:sqlite3/sqlite3.dart';

// sqlite3 exposes its native library version, but no Dart package version API.
// Keep this lockfile snapshot honest with the repository test when upgrading.
const probeSqlitePackageVersion = '3.8.0';

ProbeSqliteResult runProbeSqliteCheck(String supportPath, SendPort rootPort) {
  final watch = Stopwatch()..start();
  final checkedAt = DateTime.now().toUtc();
  final offRoot = Isolate.current.controlPort != rootPort;
  final steps = {
    for (final name in ProbeSqliteResult.stepNames) name: null as bool?,
  };
  var step = 'open';
  Directory? scratch;
  String? libraryVersion, sourceId, journalMode, failure;
  int? synchronous;
  var compileOptions = <String>[];
  try {
    _require(offRoot);
    final parent = Directory(
      '$supportPath${Platform.pathSeparator}probe-sqlite-self-check',
    );
    parent.createSync(recursive: true);
    scratch = parent.createTempSync('run-');
    libraryVersion = sqlite3.version.libVersion;
    sourceId = sqlite3.version.sourceId;
    compileOptions = sqlite3.compileOptions.toList()..sort();
    final path = '${scratch.path}${Platform.pathSeparator}check.sqlite';
    _withDatabase(path, (db) {
      _require(db.userVersion == 0);
      journalMode =
          db.select('PRAGMA journal_mode').single['journal_mode'] as String;
      synchronous =
          db.select('PRAGMA synchronous').single['synchronous'] as int;
    });
    steps[step] = true;
    step = 'commit';
    _withDatabase(path, (db) {
      _transaction(db, () {
        db.execute('CREATE TABLE entries (id INTEGER PRIMARY KEY, value TEXT)');
        db.execute("INSERT INTO entries VALUES (1, 'committed')");
        db.userVersion = 1;
      });
    });
    steps[step] = true;
    step = 'reopen';
    _withDatabase(path, _expectCommitted);
    steps[step] = true;
    step = 'rollback';
    _withDatabase(path, (db) {
      var rejected = false;
      try {
        _transaction(db, () {
          db.execute('CREATE TABLE rolled_back (id INTEGER)');
          db.execute("INSERT INTO entries VALUES (2, 'rollback')");
          db.userVersion = 99;
          db.execute("INSERT INTO entries VALUES (1, 'duplicate')");
        });
      } on SqliteException {
        rejected = true;
      }
      _require(rejected);
      _expectRolledBack(db);
    });
    _withDatabase(path, _expectRolledBack);
    steps[step] = true;
    step = 'futureSchema';
    _checkFutureSchema(scratch);
    steps[step] = true;
  } catch (error) {
    // Failure is evidence, including native-loader errors. Never export paths,
    // SQL text, stack traces or arbitrary exception messages.
    steps[step] = false;
    failure = _failureCode(error);
  } finally {
    try {
      scratch?.deleteSync(recursive: true);
      steps['cleanup'] = true;
    } on FileSystemException {
      steps['cleanup'] = false;
      failure = failure == null ? 'cleanup_failed' : '$failure;cleanup_failed';
    }
    watch.stop();
  }
  return ProbeSqliteResult(
    checkedAt: checkedAt,
    buildId: Env.buildId,
    buildNumber: Env.buildNumber,
    packageVersion: probeSqlitePackageVersion,
    ranOffRootIsolate: offRoot,
    steps: steps,
    elapsedUs: watch.elapsedMicroseconds,
    libraryVersion: libraryVersion,
    sourceId: sourceId,
    compileOptions: compileOptions,
    journalMode: journalMode,
    synchronous: synchronous,
    failure: failure,
  );
}

String _failureCode(Object error) => switch (error) {
  SqliteException(:final extendedResultCode) => 'sqlite_$extendedResultCode',
  FileSystemException() => 'filesystem_error',
  ArgumentError() => 'native_library_or_argument_error',
  _ => 'check_failed',
};

void _require(bool condition) {
  if (!condition) throw StateError('SQLite self-check invariant failed');
}

void _withDatabase(String path, void Function(Database) action) {
  final db = sqlite3.open(path);
  try {
    action(db);
  } finally {
    db.close();
  }
}

void _transaction(Database db, void Function() action) {
  db.execute('BEGIN IMMEDIATE');
  try {
    action();
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

void _expectCommitted(Database db) {
  _require(db.userVersion == 1);
  final row = db.select('SELECT id, value FROM entries').single;
  _require(row['id'] == 1 && row['value'] == 'committed');
}

void _expectRolledBack(Database db) {
  _expectCommitted(db);
  _require(
    db
        .select("SELECT name FROM sqlite_schema WHERE name = 'rolled_back'")
        .isEmpty,
  );
}

void _checkFutureSchema(Directory scratch) {
  final file = File('${scratch.path}${Platform.pathSeparator}future.sqlite');
  _withDatabase(file.path, (db) {
    db.execute('CREATE TABLE sentinel (value TEXT)');
    db.execute("INSERT INTO sentinel VALUES ('preserve')");
    db.userVersion = 2;
  });
  final before = file.readAsBytesSync();
  String files() =>
      (scratch.listSync().map((entry) => entry.path).toList()..sort()).join(
        '\n',
      );
  final filesBefore = files();
  var refused = false;
  try {
    _withDatabase(file.path, _acceptSupportedSchema);
  } on _FutureProbeSchema {
    refused = true;
  }
  _require(refused);
  _withDatabase(file.path, (db) {
    _require(db.userVersion == 2);
    _require(
      db.select('SELECT value FROM sentinel').single['value'] == 'preserve',
    );
  });
  final after = file.readAsBytesSync();
  _require(before.length == after.length);
  for (var i = 0; i < before.length; i++) {
    _require(before[i] == after[i]);
  }
  _require(filesBefore == files());
}

void _acceptSupportedSchema(Database db) {
  // Probe-only guard; no product schema/migration owner exists before Phase B.
  // Refuse before any transaction, journal setting, DDL or version write.
  if (db.userVersion > 1) throw const _FutureProbeSchema();
  _transaction(db, () {
    if (db.userVersion > 1) throw const _FutureProbeSchema();
    if (db.userVersion == 0) {
      db.execute('CREATE TABLE probe_v1 (id INTEGER PRIMARY KEY)');
      db.userVersion = 1;
    }
  });
}

final class _FutureProbeSchema implements Exception {
  const _FutureProbeSchema();
}
