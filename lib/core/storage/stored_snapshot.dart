/// Opaque validated wire JSON. The library DTO boundary owns validation before
/// writes and revalidation after reads; storage does not import feature models.
final class StoredSnapshot {
  const StoredSnapshot({
    required this.payload,
    required this.schemaVersion,
    required this.revision,
    required this.fetchedAt,
    this.etag,
  });

  final String payload;
  final int schemaVersion;
  final String? etag;
  final int revision;
  final DateTime fetchedAt;
}
