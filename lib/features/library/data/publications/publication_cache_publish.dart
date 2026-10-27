part of 'publication_cache.dart';

extension _PublicationPublishing on PublicationCache {
  Future<StoredPublication> _publish(
    PublicationAttempt attempt,
    StagedDownload staged, {
    required int parserVersion,
    required int canonicalVersion,
  }) async {
    CacheReservation? reservation;
    var moved = false;
    if (!staging.owns(staged.file)) {
      throw ArgumentError('Staging file belongs to another owner');
    }
    try {
      void check() {
        if (!_attempts.contains(attempt)) throw const RequestCancelled();
        attempt.checkCurrent();
      }

      check();
      if (staged.key != attempt.key) {
        throw ArgumentError('Staging file belongs to another book');
      }
      final value = StoredPublication(
        key: staged.key,
        sha256: staged.digest,
        byteLength: staged.byteLength,
        parserVersion: parserVersion,
        canonicalVersion: canonicalVersion,
        accessedAt: now().toUtc(),
        etag: staged.etag,
        lastModified: staged.lastModified,
      );
      if (value.byteLength < 1) {
        throw const PublicationCacheException(
          PublicationCacheFailure.invalidGeneration,
        );
      }
      if (value.byteLength > budget.limit) {
        throw const PublicationCacheException(PublicationCacheFailure.tooLarge);
      }
      // Caller has completed worker package/source validation. Recheck bytes
      // before moving them, without ever accumulating a second archive buffer.
      if (!await _files.matchesFile(
        File(staged.path),
        value.byteLength,
        value.sha256,
        check,
      )) {
        throw const PublicationCacheException(
          PublicationCacheFailure.invalidGeneration,
        );
      }
      check();
      final previous = await store.readPublicationHead(value.key);
      final destination = await _files.destination(value);
      final exists =
          await FileSystemEntity.type(destination.path, followLinks: false) !=
          FileSystemEntityType.notFound;
      if (exists && !await _files.matches(value, digest: true, check: check)) {
        // Immutable paths are never repaired in place, especially if open on
        // Windows. Reconciliation removes invalid, unleased cache bytes later.
        throw const PublicationCacheException(
          PublicationCacheFailure.invalidGeneration,
        );
      }
      reservation = await _reserve(
        exists ? 0 : value.byteLength,
        check,
        protectedPaths: {value.relativePath},
      );
      check();
      if (exists) {
        await staged.file.discard();
      } else {
        // Both paths are below the same Caches filesystem. No copy fallback.
        check();
        final rename = hooks?.rename;
        if (rename == null) {
          await File(staged.path).rename(destination.path);
        } else {
          await rename(File(staged.path), destination.path);
        }
        moved = true;
        staged.file.releaseAfterMove();
        await hooks?.atBoundary?.call(PublicationCacheBoundary.afterRename);
      }
      check();
      await hooks?.atBoundary?.call(PublicationCacheBoundary.beforeCommit);
      check(); // No await between this check and command dispatch.
      await store.publishGeneration(value);
      await hooks?.atBoundary?.call(PublicationCacheBoundary.afterCommit);
      check();
      if (previous?.sha256 != value.sha256) {
        guard.publish(
          attempt.session,
          () => _changes.add(
            PublicationHeadChange(value.key, previous?.sha256, value.sha256),
          ),
        );
      }
      return value;
    } finally {
      reservation?.release();
      // After rename, leave an unreferenced file for reconciliation on failure.
      // Before rename, delete only this attempt's staging file.
      if (!moved) await staged.file.discard();
    }
  }

  Future<CacheReservation> _reserve(
    int bytes,
    void Function() check, {
    Set<String> protectedPaths = const {},
  }) async {
    if (bytes < 0) throw ArgumentError('Invalid reservation size');
    if (bytes > budget.limit) {
      throw const PublicationCacheException(PublicationCacheFailure.tooLarge);
    }
    var used = await _files.usedBytes();
    check();
    if (!budget.fits(bytes, used)) {
      final candidates = await store.listPublicationCandidates(
        protectedPaths: {..._protected.keys, ...protectedPaths},
      );
      final needed = used + budget.reservedBytes + bytes - budget.limit;
      final plan = <({StoredPublication value, int bytes})>[];
      var reclaimable = 0;
      for (final candidate in candidates) {
        // Check generated ancestors before any file access, including eviction.
        final exists = await _files.matches(candidate);
        final size = exists ? candidate.byteLength : 0;
        plan.add((value: candidate, bytes: size));
        reclaimable += size;
        if (reclaimable >= needed) break;
      }
      check();
      if (reclaimable < needed) {
        throw const PublicationCacheException(
          PublicationCacheFailure.cacheBusy,
        );
      }
      for (final item in plan) {
        check();
        final p = item.value;
        // DB first: failure preserves the referenced file; crash after deletion
        // of metadata leaves an orphan, safely collected by reconciliation.
        await store.deleteGeneration(p.key, p.sha256);
        check();
        final file = _files.file(p);
        if (await file.exists()) await _deleteFile(file);
        used -= item.bytes;
      }
    }
    check();
    return budget.reserve(bytes, usedBytes: used);
  }
}
