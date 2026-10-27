enum PublicationWorkerFailure {
  closed,
  queueFull,
  canceled,
  stale,
  notOpen,
  resourceTooLarge,
  unexpectedExit,
  workerError,
  protocol,
  incompatibleIdentity,
}

/// Lifecycle/protocol failures are distinct from malformed EPUB ParseException.
/// Kept local because AppException is sealed outside this library.
final class PublicationWorkerException implements Exception {
  const PublicationWorkerException(this.failure);

  final PublicationWorkerFailure failure;
}
