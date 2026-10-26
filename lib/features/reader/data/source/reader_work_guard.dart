import 'dart:async';

enum ReaderWork {
  parsing,
  paragraphLayout,
  imageDecode,
  fontLoad,
  pagination,
  canonicalTraversal,
  storage,
  jsonSerialization,
  surfacePreparation,
}

/// Debug-only callback boundary, shared with isolate-safe source entry points.
/// Control tasks must be posted through the zone captured before admission.
abstract final class ReaderWorkGuard {
  static const _key = #shioriReaderMotionCallback;
  static bool get inCallback => Zone.current[_key] == true;

  static T callback<T>(T Function() action) {
    var debug = false;
    assert(() {
      debug = true;
      return true;
    }());
    return debug ? runZoned(action, zoneValues: {_key: true}) : action();
  }

  static void check(ReaderWork work) {
    assert(
      !inCallback,
      '${work.name} is forbidden in a reader pointer/ticker callback',
    );
  }
}
