part of 'sqlite_store.dart';

StoredPublication _publication(Row row) {
  final canonical = row['canonical_endpoint'] as String;
  final endpoint = ServerEndpoint.parse(canonical).endpoint;
  if (endpoint == null || endpoint.canonicalRoot != canonical) {
    throw const StorageException(StorageFailure.canonicalMismatch);
  }
  final server = ServerKey(endpoint);
  if (server.value != row['server_key']) {
    throw const StorageException(StorageFailure.canonicalMismatch);
  }
  final key = BookKey(server, row['book_id'] as int);
  final digest = row['byte_digest'] as String;
  return StoredPublication(
    key: key,
    sha256: digest,
    byteLength: row['actual_bytes'] as int,
    parserVersion: row['parser_version'] as int,
    canonicalVersion: row['canonical_version'] as int,
    accessedAt: _date(row['accessed_at'] as int),
    etag: row['etag'] as String?,
    lastModified: row['last_modified'] as String?,
    isValidated: row['validation_status'] == 'validated',
    hasExpectedPath:
        row['relative_path'] == StoredPublication.pathFor(key, digest),
  );
}

const _publicationSelect = '''SELECT p.*, s.canonical_endpoint
  FROM cached_publications p JOIN servers s USING (server_key)''';

StoredPublication? _readPublication(Database db, BookKey key, String? digest) {
  if (_readServer(db, key.serverKey) == null) return null;
  final rows = digest == null
      ? db.select(
          '''$_publicationSelect JOIN book_cache_heads h
          USING (server_key, book_id, byte_digest, validation_status)
          WHERE p.server_key = ? AND p.book_id = ?''',
          [key.serverKey.value, key.bookId],
        )
      : db.select(
          '''$_publicationSelect WHERE p.server_key = ?
          AND p.book_id = ? AND p.byte_digest = ?''',
          [key.serverKey.value, key.bookId, digest],
        );
  return rows.isEmpty ? null : _publication(rows.single);
}

void _publishGeneration(
  Database db,
  StoredPublication p,
  SqliteStoreTestHooks? hooks,
) {
  _transaction(db, () {
    if (p.byteLength < 1 || !p.isValidated || !p.hasExpectedPath) {
      throw const StorageException(StorageFailure.invalidRecord);
    }
    _requireServer(db, p.key.serverKey);
    // Same bytes may be validated by a newer parser. Never replace a row via
    // SQLite REPLACE: an existing head references it with ON DELETE RESTRICT.
    db.execute(
      '''INSERT INTO cached_publications
      (server_key, book_id, byte_digest, relative_path, actual_bytes, etag,
       last_modified, parser_version, canonical_version, validation_status,
       accessed_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'validated', ?)
      ON CONFLICT(server_key, book_id, byte_digest) DO UPDATE SET
        relative_path = excluded.relative_path, actual_bytes = excluded.actual_bytes,
        etag = excluded.etag, last_modified = excluded.last_modified,
        parser_version = excluded.parser_version,
        canonical_version = excluded.canonical_version,
        validation_status = 'validated', accessed_at = excluded.accessed_at''',
      [
        p.key.serverKey.value,
        p.key.bookId,
        p.sha256,
        p.relativePath,
        p.byteLength,
        p.etag,
        p.lastModified,
        p.parserVersion,
        p.canonicalVersion,
        p.accessedAt.microsecondsSinceEpoch,
      ],
    );
    db.execute(
      '''INSERT INTO book_cache_heads (server_key, book_id, byte_digest)
      VALUES (?, ?, ?) ON CONFLICT(server_key, book_id) DO UPDATE SET
      byte_digest = excluded.byte_digest''',
      [p.key.serverKey.value, p.key.bookId, p.sha256],
    );
    if (hooks?.failPublicationCommitDigest == p.sha256) {
      // Actual COMMIT rejects this deferred FK; _transaction rolls everything
      // back, including the generation insert and previous head replacement.
      db.execute('PRAGMA defer_foreign_keys = ON');
      db.execute(
        '''UPDATE book_cache_heads SET byte_digest = ?
        WHERE server_key = ? AND book_id = ?''',
        ['injected-missing-generation', p.key.serverKey.value, p.key.bookId],
      );
    }
  });
}

void _clearPublicationHead(Database db, BookKey key, String digest) {
  db.execute(
    '''DELETE FROM book_cache_heads
    WHERE server_key = ? AND book_id = ? AND byte_digest = ?''',
    [key.serverKey.value, key.bookId, digest],
  );
}

void _deleteGeneration(Database db, BookKey key, String digest) {
  _transaction(db, () {
    _clearPublicationHead(db, key, digest);
    db.execute(
      '''DELETE FROM cached_publications
      WHERE server_key = ? AND book_id = ? AND byte_digest = ?''',
      [key.serverKey.value, key.bookId, digest],
    );
  });
}
