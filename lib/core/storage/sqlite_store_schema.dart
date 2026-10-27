part of 'sqlite_store.dart';

const _migrations = <({int from, int to, List<String> statements})>[
  (from: 0, to: 1, statements: _schemaV1),
  (
    from: 1,
    to: 2,
    statements: [
      'ALTER TABLE cached_publications ADD COLUMN canonical_version INTEGER NOT NULL DEFAULT 1 CHECK (canonical_version > 0)',
    ],
  ),
];

const _schemaV1 = [
  '''CREATE TABLE servers (
    server_key TEXT PRIMARY KEY NOT NULL,
    canonical_endpoint TEXT NOT NULL UNIQUE,
    created_at INTEGER NOT NULL,
    last_used_at INTEGER NOT NULL
  )''',
  '''CREATE TABLE app_state (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    active_server_key TEXT REFERENCES servers(server_key) ON DELETE RESTRICT,
    schema_version INTEGER NOT NULL CHECK (schema_version > 0)
  )''',
  'INSERT INTO app_state (id, schema_version) VALUES (1, 1)',
  '''CREATE TABLE library_snapshots (
    server_key TEXT PRIMARY KEY NOT NULL
      REFERENCES servers(server_key) ON DELETE RESTRICT,
    payload TEXT NOT NULL,
    schema_version INTEGER NOT NULL CHECK (schema_version > 0),
    etag TEXT,
    revision INTEGER NOT NULL CHECK (revision BETWEEN 0 AND 9007199254740991),
    fetched_at INTEGER NOT NULL
  )''',
  '''CREATE TABLE cached_publications (
    server_key TEXT NOT NULL REFERENCES servers(server_key) ON DELETE RESTRICT,
    book_id INTEGER NOT NULL CHECK (book_id BETWEEN 1 AND 9007199254740991),
    byte_digest TEXT NOT NULL CHECK (length(byte_digest) = 64
      AND byte_digest NOT GLOB '*[^0-9a-f]*'),
    relative_path TEXT NOT NULL,
    actual_bytes INTEGER NOT NULL CHECK (actual_bytes >= 0),
    etag TEXT,
    last_modified TEXT,
    parser_version INTEGER NOT NULL CHECK (parser_version > 0),
    validation_status TEXT NOT NULL
      CHECK (validation_status IN ('validated', 'invalid')),
    accessed_at INTEGER NOT NULL,
    PRIMARY KEY (server_key, book_id, byte_digest),
    UNIQUE (server_key, book_id, byte_digest, validation_status)
  )''',
  '''CREATE TABLE book_cache_heads (
    server_key TEXT NOT NULL,
    book_id INTEGER NOT NULL,
    byte_digest TEXT NOT NULL,
    validation_status TEXT NOT NULL DEFAULT 'validated'
      CHECK (validation_status = 'validated'),
    PRIMARY KEY (server_key, book_id),
    FOREIGN KEY (server_key, book_id, byte_digest, validation_status)
      REFERENCES cached_publications
        (server_key, book_id, byte_digest, validation_status) ON DELETE RESTRICT
  )''',
  'CREATE INDEX cached_publications_lru ON cached_publications(accessed_at)',
  'CREATE INDEX app_state_active ON app_state(active_server_key)',
];

int _version(Database db) => db.userVersion;

void _refuseFuture(Database db) {
  final version = _version(db);
  if (version > SqliteStore.schemaVersion) {
    throw StorageException(StorageFailure.newerSchema, schemaVersion: version);
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

void _migrate(Database db, SqliteStoreTestHooks? hooks) {
  var expected = 0;
  for (final migration in _migrations) {
    if (migration.from != expected || migration.to != expected + 1) {
      throw const StorageException(StorageFailure.migration);
    }
    expected = migration.to;
  }
  if (expected != SqliteStore.schemaVersion) {
    throw const StorageException(StorageFailure.migration);
  }
  _refuseFuture(db);
  while (_version(db) < SqliteStore.schemaVersion) {
    _transaction(db, () {
      _refuseFuture(db);
      final current = _version(db);
      final migration = _migrations.singleWhere((step) => step.from == current);
      for (final sql in migration.statements) {
        db.execute(sql);
      }
      // Schema and version change commit together, including fault injection.
      db.userVersion = migration.to;
      db.execute('UPDATE app_state SET schema_version = ? WHERE id = 1', [
        migration.to,
      ]);
      if (hooks?.failMigration ?? false) {
        throw const StorageException(StorageFailure.migration);
      }
      if (_version(db) != migration.to ||
          db.select('PRAGMA foreign_key_check').isNotEmpty) {
        throw const StorageException(StorageFailure.migration);
      }
    });
  }
}

Database _openDatabase(String path, SqliteStoreTestHooks? hooks) {
  // A non-mutating preflight precedes writable open and persistent PRAGMAs.
  // In particular, switching a future WAL database to DELETE would mutate it.
  if (File(path).existsSync()) {
    _preflight(path);
  }
  Directory(File(path).parent.path).createSync(recursive: true);
  final db = sqlite3.open(path);
  try {
    _refuseFuture(db);
    db.execute('PRAGMA foreign_keys = ON');
    db.execute('PRAGMA journal_mode = DELETE');
    db.execute('PRAGMA synchronous = FULL');
    if (db.select('PRAGMA foreign_keys').single.values.single != 1 ||
        db.select('PRAGMA journal_mode').single.values.single != 'delete' ||
        db.select('PRAGMA synchronous').single.values.single != 2) {
      throw const StorageException(StorageFailure.open);
    }
    try {
      _migrate(db, hooks);
    } on StorageException {
      rethrow;
    } catch (_) {
      throw const StorageException(StorageFailure.migration);
    }
    // Detect malformed current schemas now, preserving their file for recovery.
    final state = db.select(
      'SELECT id, active_server_key, schema_version FROM app_state',
    );
    if (state.length != 1 ||
        state.single['id'] != 1 ||
        state.single['schema_version'] != SqliteStore.schemaVersion ||
        db.select('PRAGMA foreign_key_check').isNotEmpty) {
      throw const StorageException(StorageFailure.open);
    }
    db.select(
      'SELECT server_key, canonical_endpoint, created_at, last_used_at FROM servers LIMIT 0',
    );
    db.select(
      'SELECT server_key, payload, schema_version, etag, revision, fetched_at FROM library_snapshots LIMIT 0',
    );
    db.select(
      '''SELECT server_key, book_id, byte_digest, relative_path, actual_bytes,
      etag, last_modified, parser_version, canonical_version, validation_status, accessed_at
      FROM cached_publications LIMIT 0''',
    );
    db.select(
      'SELECT server_key, book_id, byte_digest, validation_status FROM book_cache_heads LIMIT 0',
    );
    return db;
  } catch (_) {
    db.close();
    rethrow;
  }
}

void _preflight(String path) {
  final file = File(path);
  final handle = file.openSync();
  late List<int> header;
  try {
    header = handle.readSync(20);
  } finally {
    handle.closeSync();
  }
  final hasSidecars =
      File('$path-wal').existsSync() || File('$path-journal').existsSync();
  final needsRecoveryView =
      (header.length >= 20 && (header[18] == 2 || header[19] == 2)) ||
      hasSidecars;
  Directory? scratch;
  try {
    var checkPath = path;
    if (needsRecoveryView) {
      // Read-only WAL opens can still create/write shared-memory sidecars.
      // Recover only disposable copies before deciding whether the original
      // schema may be opened. File.copySync streams without a whole-DB buffer.
      scratch = file.parent.createTempSync('.schema-check-');
      checkPath = '${scratch.path}${Platform.pathSeparator}state.db';
      file.copySync(checkPath);
      for (final suffix in ['-wal', '-journal']) {
        final sidecar = File('$path$suffix');
        if (sidecar.existsSync()) sidecar.copySync('$checkPath$suffix');
      }
    }
    final preflight = sqlite3.open(
      checkPath,
      mode: scratch == null ? OpenMode.readOnly : OpenMode.readWrite,
    );
    try {
      _refuseFuture(preflight);
    } finally {
      preflight.close();
    }
  } finally {
    // Delete only the newly created, task-owned inspection copy, never the
    // original database, its sidecars or any last-known application state.
    scratch?.deleteSync(recursive: true);
  }
}
