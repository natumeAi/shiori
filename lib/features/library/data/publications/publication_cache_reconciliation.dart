part of 'publication_cache.dart';

extension _PublicationReconciliation on PublicationCache {
  Future<void> _deleteFile(File file) async {
    final delete = hooks?.delete;
    if (delete != null) {
      await delete(file);
    } else {
      await file.delete();
    }
  }

  Future<void> _reconcile() async {
    final referenced = <Uri>{};
    for (final value in await store.listPublicationCandidates()) {
      _checkOpen();
      // Startup checks length, not the digest: bounded I/O independent of total
      // book bytes. Reuse of an existing digest destination always rehashes it.
      final matches = await _files.matches(value);
      _checkOpen();
      if (matches) {
        referenced.add(_files.file(value).absolute.uri);
      } else {
        await store.deleteGeneration(value.key, value.sha256);
      }
    }
    final protected = _protected.keys
        .map(
          (path) => File.fromUri(_files.caches.uri.resolve(path)).absolute.uri,
        )
        .toSet();
    await for (final file in _files.all()) {
      _checkOpen();
      if (!referenced.contains(file.absolute.uri) &&
          !protected.contains(file.absolute.uri)) {
        await _deleteFile(file);
      }
    }
    _checkOpen();
    await staging.cleanupAbandoned();
    _checkOpen();
    // Covers share admission's queue but never use _reserve, which can evict
    // publication generations. Their retained file reservations survive sessions.
    final covers = budget.configureSubBudget(
      'covers',
      directories: staging.directories,
      limit: CacheBudget.coverLimit,
      individualLimit: CacheBudget.coverIndividualLimit,
      serialize: _serialize,
      reserve: (bytes) async {
        final used = await _files.usedBytes();
        _checkOpen();
        return budget.fits(bytes, used)
            ? budget.reserve(bytes, usedBytes: used)
            : null;
      },
    );
    await covers.reconcileInQueue();
  }
}
