part of 'harfbuzz.dart';

final class HarfBuzzStartOffset {
  const HarfBuzzStartOffset.absolute(this.value) : percentage = false;
  const HarfBuzzStartOffset.percent(this.value) : percentage = true;
  final double value;
  final bool percentage;
  double _resolve(double length) {
    if (!value.isFinite) throw ArgumentError('Invalid startOffset');
    return percentage ? value * length / 100 : value;
  }
}

/// Round-3 bounded quadratic reference profile. Exactly 256 dyadic chords;
/// no PathMetric, oracle coordinates, per-case constants or analytic tangent.
/// Other path kinds need an independently established traversal contract.
final class HarfBuzzQuadraticPath {
  factory HarfBuzzQuadraticPath({
    required ui.Offset start,
    required ui.Offset control,
    required ui.Offset end,
    required HarfBuzzResources resources,
  }) {
    _control();
    if ([start, control, end].any((p) => !p.dx.isFinite || !p.dy.isFinite)) {
      throw ArgumentError('Invalid quadratic coordinates');
    }
    final charge = resources._reserve('quadratic-traversal', {
      SceneResource.vectorBytes: 257 * 3 * 8,
      SceneResource.vectorOperations: 256,
    });
    try {
      final points = <ui.Offset>[];
      final lengths = <double>[0];
      for (var i = 0; i <= 256; i++) {
        final t = i / 256, u = 1 - t;
        final p = start * (u * u) + control * (2 * u * t) + end * (t * t);
        if (points.isNotEmpty) {
          final segment = (p - points.last).distance;
          if (!segment.isFinite || segment == 0) {
            throw const HarfBuzzException(HarfBuzzFailure.pathOverflow);
          }
          lengths.add(lengths.last + segment);
        }
        points.add(p);
      }
      return HarfBuzzQuadraticPath._(points, lengths, charge);
    } catch (_) {
      charge.release();
      rethrow;
    }
  }
  HarfBuzzQuadraticPath._(this._points, this._lengths, this._charge);
  final List<ui.Offset> _points;
  final List<double> _lengths;
  final _HbCharge _charge;
  bool _disposed = false;
  double get length {
    if (_disposed) throw const HarfBuzzException(HarfBuzzFailure.disposed);
    return _lengths.last;
  }

  ui.Tangent _tangent(double distance) {
    if (!distance.isFinite || distance < 0 || distance > length) {
      throw const HarfBuzzException(HarfBuzzFailure.pathOverflow);
    }
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

  void dispose() {
    _control();
    if (_disposed) return;
    _disposed = true;
    _points.clear();
    _lengths.clear();
    _charge.release();
  }
}
