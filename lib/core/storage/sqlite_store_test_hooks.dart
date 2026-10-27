/// Fixed fault points only: no SQL or callback can cross the worker boundary.
/// Production callers leave this absent.
final class SqliteStoreTestHooks {
  const SqliteStoreTestHooks({
    this.failMigration = false,
    this.failActivation = false,
    this.failPublicationCommitDigest,
  });

  final bool failMigration;
  final bool failActivation;

  /// Force an actual deferred-FK COMMIT failure for this digest, then rollback.
  final String? failPublicationCommitDigest;
}
