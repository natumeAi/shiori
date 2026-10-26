/// Content-free failures suitable for retry/recovery presentation.
final class StorageException implements Exception {
  const StorageException(this.failure, {this.schemaVersion});

  final StorageFailure failure;
  final int? schemaVersion;

  @override
  String toString() => 'StorageException(${failure.name})';
}

enum StorageFailure {
  open,
  newerSchema,
  migration,
  command,
  canonicalMismatch,
  invalidRecord,
  closed,
  workerExit,
  protocol,
}
