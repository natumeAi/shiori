import 'package:shiori/core/config/selection_storage_exception.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_key.dart';
import 'package:shiori/core/config/server_selection_store.dart';
import 'package:shiori/core/config/stored_server.dart';
import 'package:shiori/core/config/validated_snapshot.dart';
import 'package:shiori/core/storage/server_record.dart';
import 'package:shiori/core/storage/sqlite_store.dart';
import 'package:shiori/core/storage/storage_exception.dart';
import 'package:shiori/core/storage/stored_snapshot.dart';

/// Selection port over the scope-owned worker. Resolve lazily so open failures
/// cross the same typed boundary as command failures; the provider owns close.
final class SqliteServerSelectionStore implements ServerSelectionStore {
  SqliteServerSelectionStore(this._resolve);

  final Future<SqliteStore> Function() _resolve;

  Future<T> _run<T>(Future<T> Function(SqliteStore) command) async {
    try {
      return await command(await _resolve());
    } on StorageException catch (error) {
      throw SelectionStorageException(switch (error.failure) {
        StorageFailure.newerSchema => SelectionStorageIssue.newerSchema,
        StorageFailure.canonicalMismatch ||
        StorageFailure.invalidRecord => SelectionStorageIssue.invalidSelection,
        StorageFailure.open ||
        StorageFailure.migration ||
        StorageFailure.command ||
        StorageFailure.closed ||
        StorageFailure.workerExit ||
        StorageFailure.protocol => SelectionStorageIssue.unavailable,
      });
    }
  }

  @override
  Future<StoredServer?> readServer(ServerKey key) => _run((store) async {
    final record = await store.readServer(key);
    if (record == null) return null;
    return StoredServer(
      canonicalEndpoint: record.key.canonicalRoot,
      createdAt: record.createdAt,
      lastUsedAt: record.lastUsedAt,
    );
  });

  @override
  Future<ServerKey?> readActiveServer() =>
      _run((store) async => (await store.readActiveServer())?.key);

  @override
  Future<void> commitActivation({
    required ServerEndpoint endpoint,
    required ServerKey key,
    required ValidatedSnapshot snapshot,
  }) async {
    // Compare both digest and canonical root before dispatching any write.
    if (ServerKey(endpoint) != key) {
      throw const SelectionStorageException(
        SelectionStorageIssue.invalidSelection,
      );
    }
    final now = DateTime.now().toUtc();
    await _run(
      (store) => store.commitActivation(
        ServerRecord(key: key, createdAt: now, lastUsedAt: now),
        StoredSnapshot(
          payload: snapshot.payloadText,
          schemaVersion: snapshot.schemaVersion,
          etag: snapshot.etag,
          revision: snapshot.revision,
          fetchedAt: snapshot.fetchedAt,
        ),
      ),
    );
  }

  @override
  Future<ValidatedSnapshot?> readCurrentSnapshot(ServerKey key) =>
      _run((store) async {
        final snapshot = await store.readSnapshot(key);
        if (snapshot == null) return null;
        return ValidatedSnapshot(
          payloadText: snapshot.payload,
          schemaVersion: snapshot.schemaVersion,
          etag: snapshot.etag,
          revision: snapshot.revision,
          fetchedAt: snapshot.fetchedAt,
        );
      });

  @override
  Future<void> touchLastUsed(ServerKey key) =>
      _run((store) => store.touchLastUsed(key, DateTime.now().toUtc()));
}
