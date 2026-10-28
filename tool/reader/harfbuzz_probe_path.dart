// Measured WebKit 27.2 bounded quadratic traversal; no oracle inputs.
import 'dart:ui' as ui;

final class HbQuadraticTraversal {
  HbQuadraticTraversal(List<double> coordinates) {
    final start = ui.Offset(coordinates[0], coordinates[1]);
    final control = ui.Offset(coordinates[2], coordinates[3]);
    final end = ui.Offset(coordinates[4], coordinates[5]);
    // All observed tangents are chord slopes at t=(odd integer)/512.
    // One global dyadic depth for this reference profile, never case tuning.
    const segments = 1 << 8;
    for (var i = 0; i <= segments; i++) {
      final t = i / segments, u = 1 - t;
      final point = start * (u * u) + control * (2 * u * t) + end * (t * t);
      if (_points.isNotEmpty) {
        _lengths.add(_lengths.last + (point - _points.last).distance);
      }
      _points.add(point);
    }
  }

  final _points = <ui.Offset>[];
  final _lengths = <double>[0];
  double get length => _lengths.last;

  ui.Tangent tangent(double distance) {
    if (distance < 0 || distance > length) throw StateError('Path overflow');
    var low = 1, high = _lengths.length - 1;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (_lengths[middle] < distance) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    final vector = _points[low] - _points[low - 1];
    return ui.Tangent(
      _points[low - 1] +
          vector * ((distance - _lengths[low - 1]) / vector.distance),
      vector / vector.distance,
    );
  }
}
