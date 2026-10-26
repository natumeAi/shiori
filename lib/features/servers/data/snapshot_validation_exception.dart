enum SnapshotValidationIssue { incompatible, malformed }

final class SnapshotValidationException implements Exception {
  const SnapshotValidationException(this.issue);

  final SnapshotValidationIssue issue;
}
