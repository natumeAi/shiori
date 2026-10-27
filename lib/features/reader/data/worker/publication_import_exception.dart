enum PublicationImportFailure {
  invalidArchive,
  invalidPackage,
  invalidFirstSection,
}

/// Recoverable content failure with no path, prose, parser object or cause.
final class PublicationImportException implements Exception {
  const PublicationImportException(this.failure);
  final PublicationImportFailure failure;

  @override
  String toString() => 'PublicationImportException(${failure.name})';
}
