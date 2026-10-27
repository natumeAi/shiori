part of 'prepare_book_service.dart';

extension _PrepareBookFlow on PrepareBookService {
  Future<PreparedBook> _perform(
    BookKey key,
    _PreparationOperation operation,
    bool refresh,
  ) async {
    void check() => _check(key, operation);
    StagedDownload? staged;
    PublicationLease? lease;
    PublicationWorker? client;
    var detached = false;
    var handedOff = false;
    try {
      check();
      final publications = await cache();
      check();
      final attempt = await publications.beginPreparation(session, key);
      operation.attempt = attempt;
      check();
      final previous = attempt.previousHead?.generation;
      final detail = await Future.any([
        books.fetchBook(key),
        operation.cancelled.future.then<BookDetailResult>(
          (_) => throw const RequestCancelled(),
        ),
      ]);
      check();
      if (detail is BookUnavailable) {
        throw const PrepareBookException(PrepareBookFailure.unavailable);
      }
      // Compatibility and a complete streamed digest check precede conditions,
      // including for large files whose D1 fast check only checks length.
      final local = attempt.previousHead?.local;
      final verified =
          previous != null && await _verify(attempt.previousHead!, check);
      if (previous != null && !verified) {
        await publications.markCorrupt(attempt.previousHead!);
      }
      final usable = verified && _identity(previous).isCurrent;
      check();
      final recoveryAllowance = PublicationRecoveryAllowance();
      final download = await downloads.download(
        key,
        local: usable ? local : null,
        refresh: refresh,
        cancelToken: operation.http,
        recoveryAllowance: recoveryAllowance,
        onUnusableLocal: usable
            ? () => publications.markCorrupt(attempt.previousHead!)
            : null,
        onReceiveProgress: (received, total) {
          check();
          guard.publish(
            session,
            () => _progress.add((key: key, received: received, total: total)),
          );
          check(); // A synchronous listener may cancel/retire the owner.
        },
      );
      if (download is StagedDownload) staged = download;
      check();
      final ContentIdentity identity;
      final String path;
      switch (download) {
        case StagedDownload():
          staged = download;
          identity = ContentIdentity(key, download.digest);
          path = download.path;
        case DownloadNotModified():
          if (!await _verify(attempt.previousHead!, check)) {
            // Loss during the conditional round trip gets one full recovery.
            await publications.markCorrupt(attempt.previousHead!);
            check();
            recoveryAllowance.recover(304);
            final recovery = await downloads.download(
              key,
              refresh: true,
              cancelToken: operation.http,
              recoveryAllowance: recoveryAllowance,
            );
            if (recovery is StagedDownload) staged = recovery;
            check();
            if (recovery is! StagedDownload) {
              throw const PrepareBookException(
                PrepareBookFailure.invalidStructure,
              );
            }
            staged = recovery;
            identity = ContentIdentity(key, recovery.digest);
            path = recovery.path;
          } else {
            identity = _identity(previous!);
            path = local!.path;
          }
      }
      check();
      client = await worker.get();
      check();
      final summary = await client.prepare(
        path,
        identity,
        tag: PublicationTag('${session.generation}/${operation.generation}'),
        cancellation: operation.cancellation,
      );
      check();
      // Close the staged handle before rename (required on Windows). No parse
      // or worker open can fail after publication; S4 reopens the leased path.
      await client.detach();
      detached = true;
      check();
      if (staged != null) {
        lease = await publications.publishLeased(
          attempt,
          staged,
          parserVersion: identity.parserVersion,
          canonicalVersion: identity.canonicalVersion,
        );
      } else {
        lease = await publications.acquireHead(session, key);
      }
      check();
      if (lease == null || _identity(lease.generation) != identity) {
        throw const PrepareBookException(PrepareBookFailure.storage);
      }
      final priorIdentity = previous == null ? null : _identity(previous);
      if (priorIdentity != identity) {
        guard.publish(
          session,
          () => _changes.add(
            ContentChange(previous: priorIdentity, next: identity),
          ),
        );
        check();
      }
      late PreparedBook result;
      result = PreparedBook(summary, lease, () => _ready.remove(result));
      _ready.add(result);
      operation.result = result;
      handedOff = true;
      return result;
    } finally {
      try {
        if (client != null && !detached) {
          try {
            await client.detach();
          } on PublicationWorkerException {
            // Exited workers cannot retain a usable source. Preserve the typed
            // primary failure; normal cancellation waits for detach above.
            await worker.closed;
          }
        }
      } finally {
        if (!handedOff) lease?.release();
        operation.attempt?.close();
        await staged?.file.discard();
      }
    }
  }

  ContentIdentity _identity(StoredPublication generation) => ContentIdentity(
    generation.key,
    generation.sha256,
    parserVersion: generation.parserVersion,
    canonicalVersion: generation.canonicalVersion,
  );

  Future<bool> _verify(PublicationLease lease, void Function() check) async {
    try {
      check();
      final file = File(lease.local.path);
      if (await file.length() != lease.generation.byteLength) return false;
      final digest = await sha256
          .bind(
            file.openRead().map((bytes) {
              check();
              return bytes;
            }),
          )
          .single;
      check();
      return digest.toString() == lease.generation.sha256 &&
          await file.length() == lease.generation.byteLength;
    } on FileSystemException {
      check();
      return false;
    }
  }
}
