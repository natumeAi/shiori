import 'dart:isolate';

import 'package:shiori/features/reader/data/worker/publication_worker_protocol.dart';

/// Explicit test-only gates. Ports and values only, never captured callbacks.
final class PublicationWorkerTestHooks {
  const PublicationWorkerTestHooks(this.events, {this.pauseRequests = false});
  final SendPort events;
  final bool pauseRequests;
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
}

final class PublicationWorkerWorkEvent {
  const PublicationWorkerWorkEvent(this.work, this.isolateControl);
  final PublicationWorkerWork work;
  final SendPort isolateControl;
}
