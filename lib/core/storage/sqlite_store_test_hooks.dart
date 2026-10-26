/// Fixed fault points only: no SQL or callback can cross the worker boundary.
/// Production callers leave this absent.
final class SqliteStoreTestHooks {
  const SqliteStoreTestHooks({
    this.failMigration = false,
    this.failActivation = false,
  });

  final bool failMigration;
  final bool failActivation;
}
