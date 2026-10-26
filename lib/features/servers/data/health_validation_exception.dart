enum HealthIssue {
  wrongService,
  databaseUnconfigured,
  databaseFailed,
  malformed,
}

/// Safe health contract failure, never retaining a response body.
final class HealthValidationException implements Exception {
  const HealthValidationException(this.issue);

  final HealthIssue issue;
}
