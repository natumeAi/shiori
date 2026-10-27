part of 'sqlite_store.dart';

final class _Bootstrap {
  const _Bootstrap(this.path, this.replies, this.root, this.hooks);
  final String path;
  final SendPort replies;
  final SendPort root;
  final SqliteStoreTestHooks? hooks;
}

final class _Ready {
  const _Ready(this.requests);
  final SendPort requests;
}

final class _OpenFailed {
  const _OpenFailed(this.error);
  final StorageException error;
}

final class _Request<T> {
  const _Request(this.id, this.operation);
  final int id;
  final _Operation<T> operation;
}

final class _Reply {
  const _Reply(this.id, this.value, [this.error]);
  final int id;
  final Object? value;
  final StorageException? error;
}

sealed class _Operation<T> {
  const _Operation();
}

final class _UpsertServer extends _Operation<void> {
  const _UpsertServer(this.record);
  final ServerRecord record;
}

final class _ReadServer extends _Operation<ServerRecord?> {
  const _ReadServer(this.key);
  final ServerKey key;
}

final class _ReadActive extends _Operation<ServerRecord?> {
  const _ReadActive();
}

final class _SetActive extends _Operation<void> {
  const _SetActive(this.key);
  final ServerKey? key;
}

final class _Activate extends _Operation<void> {
  const _Activate(this.record, this.snapshot);
  final ServerRecord record;
  final StoredSnapshot snapshot;
}

final class _ReadSnapshot extends _Operation<StoredSnapshot?> {
  const _ReadSnapshot(this.key);
  final ServerKey key;
}

final class _ReplaceSnapshot extends _Operation<void> {
  const _ReplaceSnapshot(this.key, this.snapshot);
  final ServerKey key;
  final StoredSnapshot snapshot;
}

final class _Touch extends _Operation<void> {
  const _Touch(this.key, this.at);
  final ServerKey key;
  final DateTime at;
}

final class _Close extends _Operation<void> {
  const _Close();
}

final class _PublishGeneration extends _Operation<void> {
  const _PublishGeneration(this.value);
  final StoredPublication value;
}

final class _ReadPublication extends _Operation<StoredPublication?> {
  const _ReadPublication(this.key, this.sha256);
  final BookKey key;
  final String? sha256;
}

final class _ListPublications extends _Operation<List<StoredPublication>> {
  const _ListPublications(this.protectedPaths);
  final Set<String> protectedPaths;
}

final class _DeleteGeneration extends _Operation<void> {
  const _DeleteGeneration(this.key, this.sha256);
  final BookKey key;
  final String sha256;
}

final class _ClearPublicationHead extends _Operation<void> {
  const _ClearPublicationHead(this.key, this.sha256);
  final BookKey key;
  final String sha256;
}

final class _TouchGeneration extends _Operation<void> {
  const _TouchGeneration(this.key, this.sha256, this.at);
  final BookKey key;
  final String sha256;
  final DateTime at;
}

final class _WorkerIdentity extends _Operation<bool> {
  const _WorkerIdentity();
}

final class _ExitForTesting extends _Operation<void> {
  const _ExitForTesting();
}
