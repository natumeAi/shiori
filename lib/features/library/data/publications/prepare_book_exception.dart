/// Safe recoverable reasons. No endpoint, parser cause, prose or file path.
final class PrepareBookException implements Exception {
  const PrepareBookException(this.failure);
  final PrepareBookFailure failure;
  @override
  String toString() => 'PrepareBookException(${failure.name})';
}

enum PrepareBookFailure {
  unavailable,
  network,
  tooLarge,
  cacheBusy,
  invalidStructure,
  unsupportedStructure,
  storage,
  unauthorized,
  tls,
  server,
  redirect,
  workerUnavailable,
}
