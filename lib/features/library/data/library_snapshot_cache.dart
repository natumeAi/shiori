import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/config/server_key.dart';
import 'package:shiori/core/storage/sqlite_store.dart';
import 'package:shiori/core/storage/stored_snapshot.dart';

part 'library_snapshot_cache.g.dart';

/// DTO validation belongs to the repository; each replace is one transaction.
abstract interface class LibrarySnapshotCache {
  Future<StoredSnapshot?> read(ServerKey key);
  Future<void> replace(
    ServerKey key,
    StoredSnapshot snapshot, {
    required void Function() checkActive,
  });
}

final class _SqliteSnapshotCache implements LibrarySnapshotCache {
  const _SqliteSnapshotCache(this.store);
  final Future<SqliteStore> Function() store;

  @override
  Future<StoredSnapshot?> read(ServerKey key) async =>
      (await store()).readSnapshot(key);

  @override
  Future<void> replace(
    ServerKey key,
    StoredSnapshot snapshot, {
    required void Function() checkActive,
  }) async {
    final owner = await store();
    checkActive(); // No await between session admission and command dispatch.
    await owner.replaceSnapshot(key, snapshot);
  }
}

@Riverpod(keepAlive: true)
LibrarySnapshotCache librarySnapshotCache(Ref ref) =>
    _SqliteSnapshotCache(() => ref.read(sqliteStoreProvider.future));
