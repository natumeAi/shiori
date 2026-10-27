/// Idempotent lifetime charge, including future cover bytes outside publications.
final class CacheReservation {
  CacheReservation(this.bytes, this._release);
  final int bytes;
  final void Function() _release;
  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    _release();
  }
}
