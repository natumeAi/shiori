/// Thrown from a cooperative checkpoint after [PreparationControl.cancel].
final class PreparationCancelled implements Exception {
  const PreparationCancelled();
}

/// Cooperative scheduling for section preparation: callers `await
/// checkpoint()` between units of work (one paragraph, one image). The
/// control yields to the event loop when its time slice is used up and throws
/// [PreparationCancelled] once cancelled, so optional work stops as soon as
/// input needs the isolate.
final class PreparationControl {
  PreparationControl({
    this.slice = const Duration(milliseconds: 4),
    Future<void> Function()? yielder,
  }) : _yielder = yielder ?? (() => Future<void>.delayed(Duration.zero)) {
    _watch.start();
  }

  final Duration slice;
  final Future<void> Function() _yielder;
  final Stopwatch _watch = Stopwatch();
  bool _cancelled = false;
  int _yields = 0;

  bool get cancelled => _cancelled;

  /// Number of times preparation handed control back.
  int get yieldCount => _yields;

  void cancel() => _cancelled = true;

  Future<void> checkpoint() async {
    if (_cancelled) throw const PreparationCancelled();
    if (_watch.elapsed < slice) return;
    _yields++;
    await _yielder();
    _watch
      ..reset()
      ..start();
    if (_cancelled) throw const PreparationCancelled();
  }
}
