import 'dart:ui' as ui;

/// Pins decoded pixels against eviction until the image stream releases them.
final class CoverLease {
  CoverLease(this.image, this._release);

  final ui.Image image;
  final void Function() _release;
  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    _release();
  }
}
