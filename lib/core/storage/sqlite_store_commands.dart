part of 'sqlite_store.dart';

ServerRecord? _readServer(Database db, ServerKey key) {
  final rows = db.select('SELECT * FROM servers WHERE server_key = ?', [
    key.value,
  ]);
  if (rows.isEmpty) return null;
  final row = rows.single;
  if (row['canonical_endpoint'] != key.canonicalRoot) {
    throw const StorageException(StorageFailure.canonicalMismatch);
  }
  return ServerRecord(
    key: key,
    createdAt: _date(row['created_at'] as int),
    lastUsedAt: _date(row['last_used_at'] as int),
  );
}

DateTime _date(int micros) =>
    DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);

void _requireServer(Database db, ServerKey key) {
  if (_readServer(db, key) == null) {
    throw const StorageException(StorageFailure.invalidRecord);
  }
}

void _upsertServer(Database db, ServerRecord record) {
  _readServer(db, record.key); // Verify canonical identity before any write.
  db.execute(
    '''INSERT INTO servers
    (server_key, canonical_endpoint, created_at, last_used_at) VALUES (?, ?, ?, ?)
    ON CONFLICT(server_key) DO UPDATE SET last_used_at = excluded.last_used_at''',
    [
      record.key.value,
      record.key.canonicalRoot,
      record.createdAt.microsecondsSinceEpoch,
      record.lastUsedAt.microsecondsSinceEpoch,
    ],
  );
}

void _setActive(Database db, ServerKey? key) {
  if (key != null) _requireServer(db, key);
  db.execute('UPDATE app_state SET active_server_key = ? WHERE id = 1', [
    key?.value,
  ]);
}

ServerRecord? _readActive(Database db) {
  final rows = db.select('''SELECT servers.* FROM app_state
    JOIN servers ON servers.server_key = app_state.active_server_key
    WHERE app_state.id = 1''');
  if (rows.isEmpty) return null;
  final row = rows.single;
  final canonical = row['canonical_endpoint'] as String;
  final endpoint = ServerEndpoint.parse(canonical).endpoint;
  if (endpoint == null || endpoint.canonicalRoot != canonical) {
    throw const StorageException(StorageFailure.canonicalMismatch);
  }
  final key = ServerKey(endpoint);
  if (key.value != row['server_key']) {
    throw const StorageException(StorageFailure.canonicalMismatch);
  }
  return _readServer(db, key);
}

void _replaceSnapshot(Database db, ServerKey key, StoredSnapshot snapshot) {
  _requireServer(db, key);
  db.execute(
    '''INSERT INTO library_snapshots
    (server_key, payload, schema_version, etag, revision, fetched_at)
    VALUES (?, ?, ?, ?, ?, ?)
    ON CONFLICT(server_key) DO UPDATE SET
      payload = excluded.payload, schema_version = excluded.schema_version,
      etag = excluded.etag, revision = excluded.revision,
      fetched_at = excluded.fetched_at''',
    [
      key.value,
      snapshot.payload,
      snapshot.schemaVersion,
      snapshot.etag,
      snapshot.revision,
      snapshot.fetchedAt.microsecondsSinceEpoch,
    ],
  );
}

StoredSnapshot? _readSnapshot(Database db, ServerKey key) {
  if (_readServer(db, key) == null) return null;
  final rows = db.select(
    'SELECT * FROM library_snapshots WHERE server_key = ?',
    [key.value],
  );
  if (rows.isEmpty) return null;
  final row = rows.single;
  return StoredSnapshot(
    payload: row['payload'] as String,
    schemaVersion: row['schema_version'] as int,
    etag: row['etag'] as String?,
    revision: row['revision'] as int,
    fetchedAt: _date(row['fetched_at'] as int),
  );
}

Object? _dispatch(
  Database db,
  _Operation operation,
  SqliteStoreTestHooks? hooks,
) {
  switch (operation) {
    case _UpsertServer(:final record):
      _transaction(db, () => _upsertServer(db, record));
    case _ReadServer(:final key):
      return _readServer(db, key);
    case _ReadActive():
      return _readActive(db);
    case _SetActive(:final key):
      _transaction(db, () => _setActive(db, key));
    case _Activate(:final record, :final snapshot):
      _transaction(db, () {
        _upsertServer(db, record);
        _replaceSnapshot(db, record.key, snapshot);
        if (hooks?.failActivation ?? false) {
          throw const StorageException(StorageFailure.command);
        }
        _setActive(db, record.key);
      });
    case _ReadSnapshot(:final key):
      return _readSnapshot(db, key);
    case _ReplaceSnapshot(:final key, :final snapshot):
      _transaction(db, () => _replaceSnapshot(db, key, snapshot));
    case _Touch(:final key, :final at):
      _transaction(db, () {
        _requireServer(db, key);
        db.execute('UPDATE servers SET last_used_at = ? WHERE server_key = ?', [
          at.microsecondsSinceEpoch,
          key.value,
        ]);
      });
    case _WorkerIdentity():
      return true; // The worker checks the bootstrap root on every dispatch.
    case _PublishGeneration(:final value):
      _publishGeneration(db, value, hooks);
    case _ReadPublication(:final key, :final sha256):
      return _readPublication(db, key, sha256);
    case _ListPublications(:final protectedPaths):
      return List<StoredPublication>.unmodifiable(
        db
            .select('''$_publicationSelect ORDER BY p.accessed_at,
          p.server_key, p.book_id, p.byte_digest''')
            .map(_publication)
            .where((value) => !protectedPaths.contains(value.relativePath)),
      );
    case _DeleteGeneration(:final key, :final sha256):
      _deleteGeneration(db, key, sha256);
    case _ClearPublicationHead(:final key, :final sha256):
      _transaction(db, () => _clearPublicationHead(db, key, sha256));
    case _TouchGeneration(:final key, :final sha256, :final at):
      _transaction(
        db,
        () => db.execute(
          '''UPDATE cached_publications
        SET accessed_at = ? WHERE server_key = ? AND book_id = ?
        AND byte_digest = ?''',
          [at.microsecondsSinceEpoch, key.serverKey.value, key.bookId, sha256],
        ),
      );
    case _Close() || _ExitForTesting():
      throw const StorageException(StorageFailure.protocol);
  }
  return null;
}
