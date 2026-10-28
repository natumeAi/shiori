part of 'publication_worker.dart';

extension PublicationWorkerPreload on PublicationWorker {
  /// Discovers/styles just this section in the worker, reserves shared retained
  /// bytes, then transfers only missing local entries. No archive read on root.
  Future<PreloadedPublicationSection> preloadSection(
    int index, {
    ReaderSettings settings = const ReaderSettings(),
    ReaderResourceBudget? budget,
    PublicationCancellation? cancellation,
    void Function(ReaderResourceMiss)? onMiss,
    PublicationWorkerReservation? reservation,
  }) async {
    if (_blocked(reservation)) {
      throw const PublicationWorkerException(PublicationWorkerFailure.reserved);
    }
    final generation = _generation;
    final tag = _tag ?? const PublicationTag('');
    final plan = await _enqueue(
      PlanPublicationResources(++_nextId, tag, generation, index, settings),
      (reply) => switch (reply) {
        PublicationResourcesPlanned(:final plan) => plan,
        _ => throw PublicationWorker._protocol,
      },
      cancellation,
    );
    if (generation != _generation || isClosed) {
      throw const PublicationWorkerException(PublicationWorkerFailure.stale);
    }
    if (cancellation?.isCanceled ?? false) {
      throw const PublicationWorkerException(PublicationWorkerFailure.canceled);
    }
    final owner = budget ?? ReaderResourceBudget.shared;
    final session = _resourceSessions.putIfAbsent(owner, owner.createSession);
    final resourceReservation = session.reserve(plan.lengths);
    try {
      final source = await _enqueue(
        PreloadPublicationResources(
          ++_nextId,
          tag,
          generation,
          resourceReservation.missingLengths,
        ),
        (reply) {
          if (reply is! PublicationResourcesPreloaded ||
              reply.bytes.length != resourceReservation.missingLengths.length ||
              !reply.bytes.keys.every(
                resourceReservation.missingLengths.containsKey,
              )) {
            throw PublicationWorker._protocol;
          }
          return resourceReservation.commit(
            {
              for (final entry in reply.bytes.entries)
                entry.key: entry.value.materialize().asUint8List(),
            },
            absent: {
              for (final reference in plan.references)
                if (reference.path != null && !reference.present)
                  reference.path!,
            },
            onMiss: onMiss,
          );
        },
        cancellation,
      );
      // Covers retirement/cancellation in the completion microtask gap too.
      if (session.isRetired ||
          generation != _generation ||
          isClosed ||
          (cancellation?.isCanceled ?? false)) {
        source.dispose();
        throw PublicationWorkerException(
          cancellation?.isCanceled ?? false
              ? PublicationWorkerFailure.canceled
              : PublicationWorkerFailure.stale,
        );
      }
      return PreloadedPublicationSection(plan, source);
    } finally {
      resourceReservation.dispose();
    }
  }
}
