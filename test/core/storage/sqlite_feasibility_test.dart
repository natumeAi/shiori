import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

// A1 driver proof only; production storage and its isolate belong to Phase B.
const _v1Schema = [
  'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
  "INSERT INTO settings VALUES ('fixture', 'v1')",
];

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('shiori-sqlite-a1-');
    addTearDown(() async => directory.delete(recursive: true));
    file = File.fromUri(directory.uri.resolve('feasibility.sqlite'));
  });

  test(
    'commits, rolls back a failed transaction and reopens committed data',
    () {
      _withDatabase(file.path, (db) {
        _expectDurabilitySettings(db);
        db.execute('CREATE TABLE entries (id INTEGER PRIMARY KEY, value TEXT)');
        _transaction(db, () {
          db.execute('INSERT INTO entries VALUES (?, ?)', [1, 'committed']);
        });
        expect(
          () => _transaction(db, () {
            db.execute('INSERT INTO entries VALUES (?, ?)', [2, 'rolled back']);
            db.execute('INSERT INTO entries VALUES (?, ?)', [1, 'duplicate']);
          }),
          throwsA(isA<SqliteException>()),
        );
        expect(db.select('SELECT id FROM entries').map((row) => row['id']), [
          1,
        ]);
      });

      _withDatabase(file.path, (db) {
        _expectDurabilitySettings(db);
        expect(db.select('SELECT * FROM entries').single['value'], 'committed');
        expect(
          db.select('SELECT COUNT(*) AS count FROM entries').single['count'],
          1,
        );
      });
    },
  );

  test('migrates v0 to v1 once and preserves unrelated durable data', () {
    _withDatabase(file.path, (db) {
      _seedSentinel(db);
      expect(_userVersion(db), 0);
      _migrateToV1(db);
      expect(_userVersion(db), 1);
      _expectSentinel(db);
      db.execute("UPDATE settings SET value = 'retained'");
      // Replaying the CREATE TABLE would fail; an existing v1 must be a no-op.
      _migrateToV1(db);
    });

    _withDatabase(file.path, (db) {
      expect(_userVersion(db), 1);
      expect(
        db.select('SELECT value FROM settings').single['value'],
        'retained',
      );
      _expectSentinel(db);
    });
  });

  test(
    'failed migration rolls back schema, data and user_version, then retries',
    () {
      _withDatabase(file.path, (db) {
        _seedSentinel(db);
        expect(
          () => _migrateToV1(
            db,
            statements: [
              ..._v1Schema,
              'PRAGMA user_version = 1',
              'INSERT INTO missing_table VALUES (1)',
            ],
          ),
          throwsA(isA<SqliteException>()),
        );
        expect(_userVersion(db), 0);
        expect(
          db.select("SELECT name FROM sqlite_schema WHERE name = 'settings'"),
          isEmpty,
        );
        _expectSentinel(db);
      });

      _withDatabase(file.path, (db) {
        expect(_userVersion(db), 0);
        expect(
          db.select("SELECT name FROM sqlite_schema WHERE name = 'settings'"),
          isEmpty,
        );
        _expectSentinel(db);
        _migrateToV1(db);
        expect(_userVersion(db), 1);
        expect(db.select('SELECT value FROM settings').single['value'], 'v1');
      });
    },
  );

  test(
    'refuses a future schema without changing file bytes or leaving sidecars',
    () async {
      _withDatabase(file.path, (db) {
        _seedSentinel(db);
        db.execute('PRAGMA user_version = 2');
      });
      final before = await file.readAsBytes();
      final filesBefore = await directory
          .list()
          .map((entry) => entry.path)
          .toList();

      expect(
        () => _withDatabase(file.path, _migrateToV1),
        throwsA(
          isA<_FutureSchema>().having((error) => error.version, 'version', 2),
        ),
      );

      expect(await file.readAsBytes(), orderedEquals(before));
      expect(
        await directory.list().map((entry) => entry.path).toList(),
        unorderedEquals(filesBefore),
      );
      _withDatabase(file.path, (db) {
        expect(_userVersion(db), 2);
        _expectSentinel(db);
      });
      expect(await file.readAsBytes(), orderedEquals(before));
    },
  );
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

int _userVersion(Database db) =>
    db.select('PRAGMA user_version').single['user_version'] as int;

void _migrateToV1(Database db, {List<String> statements = _v1Schema}) {
  final version = _userVersion(db);
  // Check before any write, including schema, settings or journal changes.
  if (version > 1) throw _FutureSchema(version);
  _transaction(db, () {
    // Recheck under the write lock before deciding whether to migrate.
    final lockedVersion = _userVersion(db);
    if (lockedVersion > 1) throw _FutureSchema(lockedVersion);
    if (lockedVersion == 1) return;
    for (final statement in statements) {
      db.execute(statement);
    }
    db.execute('PRAGMA user_version = 1');
  });
}

void _expectDurabilitySettings(Database db) {
  expect(db.select('PRAGMA journal_mode').single['journal_mode'], 'delete');
  expect(db.select('PRAGMA synchronous').single['synchronous'], 2); // FULL.
}

void _seedSentinel(Database db) {
  db.execute('CREATE TABLE sentinel (value TEXT NOT NULL)');
  db.execute('INSERT INTO sentinel VALUES (?)', ['preserve']);
}

void _expectSentinel(Database db) {
  expect(db.select('SELECT value FROM sentinel').single['value'], 'preserve');
}

final class _FutureSchema implements Exception {
  const _FutureSchema(this.version);

  final int version;
}
