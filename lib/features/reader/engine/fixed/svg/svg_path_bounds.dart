part of 'svg_graphics.dart';

/// dart:ui Path.getBounds includes Bezier control points. SVG getBBox uses
/// extrema of the painted curve, so solve its derivative in each coordinate.
ui.Rect _pathBounds(String data) {
  var point = ui.Offset.zero, start = ui.Offset.zero;
  ui.Rect? bounds;
  void include(ui.Offset p) {
    final r = ui.Rect.fromLTRB(p.dx, p.dy, p.dx, p.dy);
    bounds = bounds == null ? r : bounds!.expandToInclude(r);
  }

  for (final command in vc.parseSvgPathData(data).commands) {
    switch (command) {
      case vc.MoveToCommand():
        point = start = ui.Offset(command.x, command.y);
        include(point);
      case vc.LineToCommand():
        point = ui.Offset(command.x, command.y);
        include(point);
      case vc.CloseCommand():
        point = start;
        include(point);
      case vc.CubicToCommand():
        final p0 = point,
            p1 = ui.Offset(command.x1, command.y1),
            p2 = ui.Offset(command.x2, command.y2),
            p3 = ui.Offset(command.x3, command.y3);
        final times = <double>{0, 1};
        void roots(double q0, double q1, double q2, double q3) {
          final a = -q0 + 3 * q1 - 3 * q2 + q3,
              b = 2 * (q0 - 2 * q1 + q2),
              c = q1 - q0;
          if (a == 0) {
            if (b != 0) times.add(-c / b);
            return;
          }
          final discriminant = b * b - 4 * a * c;
          if (discriminant < 0) return;
          final root = math.sqrt(discriminant);
          times.add((-b - root) / (2 * a));
          times.add((-b + root) / (2 * a));
        }
        roots(p0.dx, p1.dx, p2.dx, p3.dx);
        roots(p0.dy, p1.dy, p2.dy, p3.dy);
        for (final t in times.where((t) => t >= 0 && t <= 1)) {
          final s = 1 - t;
          include(
            p0 * (s * s * s) +
                p1 * (3 * s * s * t) +
                p2 * (3 * s * t * t) +
                p3 * (t * t * t),
          );
        }
        point = p3;
    }
  }
  return bounds ?? ui.Rect.zero;
}
