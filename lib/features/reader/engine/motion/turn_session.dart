import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/reader_preparation_failure.dart';

/// A proven foreground page. Anchors on the same page need not be identical.
final class TurnPosition {
  const TurnPosition({
    required this.cfi,
    required this.layoutKey,
    required this.layoutGeneration,
    required this.sectionIndex,
    required this.pageIndex,
    required this.pageCount,
    required this.pageIdentity,
    required this.atStart,
    required this.atEnd,
  });
  final String cfi;
  final String layoutKey;
  final int layoutGeneration;
  final int sectionIndex;
  final int pageIndex;
  final int pageCount;
  final String pageIdentity;
  final bool atStart;
  final bool atEnd;

  bool samePage(TurnPosition other) =>
      layoutKey == other.layoutKey &&
      layoutGeneration == other.layoutGeneration &&
      sectionIndex == other.sectionIndex &&
      pageIndex == other.pageIndex &&
      pageCount == other.pageCount &&
      pageIdentity == other.pageIdentity;
  bool sameOrigin(TurnPosition other) => samePage(other) && cfi == other.cfi;
}

/// Holds an incoming surface through proof/rollback. Release is idempotent.
final class PreparedTurn {
  PreparedTurn({
    required this.origin,
    required this.target,
    required this.direction,
    required this.releaseCallback,
  });
  final TurnPosition origin;
  final TurnPosition target;
  final TurnDirection direction;
  final void Function() releaseCallback;
  bool _released = false;
  bool get released => _released;
  void release() {
    if (_released) return;
    _released = true;
    releaseCallback();
  }
}

enum TurnNavigationKind {
  verified,
  boundary,
  unavailable,
  mismatch,
  cancelled,
  failed,
}

final class TurnNavigation {
  const TurnNavigation(this.kind, {this.position, this.reason, this.failure});
  const TurnNavigation.verified(TurnPosition this.position)
    : kind = TurnNavigationKind.verified,
      reason = null,
      failure = null;
  final ReaderPreparationFailure? failure;
  final TurnNavigationKind kind;
  final TurnPosition? position;
  final String? reason;
}

/// Engine-owned seam; no providers, storage, diagnostics or frame scheduling.
enum TurnSessionState { ready, handoff, failed, closed, suspended, loading }

/// Optional session seam for synchronous generation invalidation. This must
/// only revoke publication, never dispose native resources in a callback.
/// The controller follows it with unbind in its ordinary control task.
abstract interface class TurnPreparationInvalidation {
  void invalidatePreparation();
}

abstract interface class TurnSession {
  TurnSessionState get state;

  /// Includes retiring owners and pending pagination/measurement work.
  Future<void> stopAndDrain();
  void optionalWorkAllowed(bool allowed);
  PreparedTurn? ready(TurnPosition origin, TurnDirection direction);
  Future<PreparedTurn?> prepare(TurnPosition origin, TurnDirection direction);
  void bind(TurnPosition origin, List<PreparedTurn> neighbors);
  void unbind();
  Future<TurnNavigation> navigate(
    TurnPosition origin,
    TurnDirection direction,
    PreparedTurn? preview,
  );

  /// Must use the existing anchor proof, including foreground visibility.
  Future<bool> prove(TurnPosition position, {PreparedTurn? preview});

  /// Marks the proven handoff; a cancelled speculative surface cannot promote.
  void accept(TurnPosition position);
  Future<bool> restore(TurnPosition origin);
}

enum TurnTimingEvent {
  inputReceived,
  pointerAdmitted,
  rejected,
  preparationStart,
  preparationHit,
  preparationMiss,
  settleEnd,
  proofPassed,
  proofFailed,
  generationInvalidated,
  admitted,
  queued,
  overflow,
  prepared,
  firstMotion,
  accepted,
  staticFallback,
  reducedMotion,
  cancelled,
  failed,
  queueClosed,
  inputCommitted,
  staleCallbackRejected,
  inputRecognized,
  recognizedAdmission,
  dragDirty,
  dragClean,
  holdStart,
  holdEnd,
  frameDemandStart,
  frameDemandEnd,
  preparationBarrierStart,
  preparationBarrierEnd,
  visualMutation,
  noMotionRequired,
}

abstract interface class TurnTimingSink {
  void record(
    TurnTimingEvent event,
    double time,
    int generation,
    int queueDepth,
  );
}

/// Same-frame engine submission identity; never implies physical presentation.
abstract interface class TurnFrameSink {
  int get frameEpoch;
  void submitted({
    required int frameNumber,
    required int schedulerUs,
    required int rawSchedulerUs,
    required int generation,
    required double offset,
    Object? input,
  });
}

/// Opaque input identity allows FIFO/drag correlation without exporting anchors.
abstract interface class TurnTraceSink {
  void recordTurn(
    TurnTimingEvent event,
    double time,
    int generation,
    int queueDepth,
    Object? input,
  );
}

/// Optional error observer; implementations must sanitize book-derived errors.
abstract interface class TurnFailureSink {
  void failure(Object error, StackTrace stack);
}

/// Optional correctness evidence, without copying anchors or book content.
abstract interface class TurnEvidenceSink {
  void recordEvidence(
    TurnTimingEvent event,
    double time,
    int generation,
    int activeGeneration,
    int queueDepth,
    Object? input, {
    TurnPosition? destination,
  });
}
