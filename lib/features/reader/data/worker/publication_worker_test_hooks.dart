import 'dart:isolate';

import 'package:shiori/features/reader/data/worker/publication_worker_protocol.dart';

/// Explicit test-only gates. Ports and values only, never captured callbacks.
final class PublicationWorkerTestHooks {
  const PublicationWorkerTestHooks(
    this.events, {
    this.pauseRequests = false,
    this.pauseDiscovery = false,
    this.pausePreload = false,
  });
  final SendPort events;
  final bool pauseRequests;
  final bool pauseDiscovery;
  final bool pausePreload;
}

enum PublicationWorkerTestAction { resume, crash }

final class PublicationWorkerRequestEvent {
  const PublicationWorkerRequestEvent(
    this.request,
    this.resume,
    this.replies,
    this.isolateControl,
  );
  final PublicationRequest request;
  final SendPort? resume;
  final SendPort replies;
  final SendPort isolateControl;
}

enum PublicationWorkerWork {
  archiveOpen,
  packageParse,
  sectionParse,
  resourceRead,
  archiveClose,
  resourceDiscovery,
  sectionStyle,
  canonicalIndex,
}

/// A gate inside the first-source resource inventory, after source parsing.
final class PublicationWorkerDiscoveryEvent {
  const PublicationWorkerDiscoveryEvent(this.resume);
  final SendPort resume;
}

/// Gate after an actual resource inflation/transfer, before the batch reply.
final class PublicationWorkerPreloadEvent {
  const PublicationWorkerPreloadEvent(this.resume);
  final SendPort resume;
}

final class PublicationWorkerWorkEvent {
  const PublicationWorkerWorkEvent(this.work, this.isolateControl);
  final PublicationWorkerWork work;
  final SendPort isolateControl;
}
