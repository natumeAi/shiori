/// Phase C produces this value only after validating the entire snapshot.
/// Payload and validators are retained verbatim; revision is not a digest.
final class ValidatedSnapshot {
  const ValidatedSnapshot({
    required this.payloadText,
    required this.schemaVersion,
    required this.revision,
    required this.fetchedAt,
    this.etag,
  });

  final String payloadText;
  final int schemaVersion;
  final String? etag;
  final int revision;
  final DateTime fetchedAt;
}
