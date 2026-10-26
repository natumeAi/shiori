/// Root-side cancellation only; never sent to the worker.
final class PublicationCancellation {
  bool _canceled = false;
  final Set<void Function()> _listeners = {};

  bool get isCanceled => _canceled;

  void cancel() {
    if (_canceled) return;
    _canceled = true;
    final listeners = _listeners.toList();
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }

  /// Returns an unsubscribe callback. Already canceled tokens fire immediately.
  void Function() listen(void Function() listener) {
    if (_canceled) {
      listener();
    } else {
      _listeners.add(listener);
    }
    return () => _listeners.remove(listener);
  }
}
