/// Persisted deployment identity and local timestamps, with no I/O behavior.
final class StoredServer {
  const StoredServer({
    required this.canonicalEndpoint,
    required this.createdAt,
    required this.lastUsedAt,
  });

  final String canonicalEndpoint;
  final DateTime createdAt;
  final DateTime lastUsedAt;
}
