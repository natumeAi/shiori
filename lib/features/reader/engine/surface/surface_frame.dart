import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';

/// A stable set of prepared pages. Numeric motion never changes this object.
final class SurfaceFrame {
  const SurfaceFrame({required this.current, this.previous, this.next});
  final PreparedPageSurface current;
  final PreparedPageSurface? previous;
  final PreparedPageSurface? next;
}
