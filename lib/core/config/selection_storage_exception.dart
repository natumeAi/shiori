enum SelectionStorageIssue { unavailable, invalidSelection, newerSchema }

/// Adapter boundary: preserve the previous transaction and never reset storage.
/// Carries neither SQL nor private endpoint/payload/driver exception text.
final class SelectionStorageException implements Exception {
  const SelectionStorageException(this.issue);

  final SelectionStorageIssue issue;
}
