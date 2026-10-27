part of 'publication_cache.dart';

extension _PublicationReconciliation on PublicationCache {
  Future<void> _invalidate(StoredPublication value) async {
    _scope.corrupt[value.relativePath] = value;
    final stored = await store.readGeneration(value.key, value.sha256);
    if (stored?.relativePath == value.relativePath) {
      await store.deleteGeneration(value.key, value.sha256);
    }
    await _removeCorruptUnleased();
  }

  Future<void> _removeCorruptUnleased() async {
    for (final value in _scope.corrupt.values.toList()) {
      if (_protected.containsKey(value.relativePath)) continue;
      if (await _files._directories(
        value.relativePath.split('/')..removeLast(),
      )) {
        final file = _files.file(value);
        final type = await FileSystemEntity.type(file.path, followLinks: false);
        if (type != FileSystemEntityType.notFound) {
          if (type != FileSystemEntityType.file) {
            throw const PublicationCacheException(
              PublicationCacheFailure.storage,
            );
          }
          await _deleteFile(file);
        }
      }
      _scope.corrupt.remove(value.relativePath);
    }
  }

  Future<void> _deleteFile(File file) async {
    final delete = hooks?.delete;
    if (delete != null) {
      await delete(file);
    } else {
      await file.delete();
    }
  }

  Future<void> _reconcile() async {
    await _removeCorruptUnleased();
    final referenced = <Uri>{};
    for (final value in await store.listPublicationCandidates()) {
      _checkOpen();
      // Startup checks length, not the digest: bounded I/O independent of total
      // book bytes. Reuse of an existing digest destination always rehashes it.
      final matches =
          !_scope.corrupt.containsKey(value.relativePath) &&
          await _files.matches(value);
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
