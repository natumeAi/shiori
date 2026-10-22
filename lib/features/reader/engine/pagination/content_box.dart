import 'package:shiori/features/reader/engine/style/reader_settings.dart';

/// The page text area derived from the viewport and the reader settings.
///
/// Foliate's paginator (`paginator.js`, `#top` grid and `#beforeRender`)
/// reduces to two insets for a one-column paginated flow: the side inset is
/// the effective horizontal margin ([ReaderSettings.pageGap], the `gap`
/// attribute as a share of the width: outer padding `gap / 2` plus the
/// document's own `gap / 2` padding) and the top/bottom inset is the `margin`
/// attribute ([ReaderSettings.pageMargin]). Text and images therefore live in
/// a `(width - 2 * gap) x (height - 2 * margin)` box.
final class ContentBox {
  const ContentBox({
    required this.viewportWidth,
    required this.viewportHeight,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  factory ContentBox.fromViewport(
    double viewportWidth,
    double viewportHeight,
    ReaderSettings settings,
  ) {
    final gap = settings.pageGap(viewportWidth);
    final margin = settings.pageMargin;
    final width = viewportWidth - 2 * gap;
    final height = viewportHeight - 2 * margin;
    return ContentBox(
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      left: gap,
      top: margin,
      width: width < 1 ? 1 : width,
      height: height < 1 ? 1 : height,
    );
  }

  final double viewportWidth;
  final double viewportHeight;

  /// Content origin inside the viewport.
  final double left;
  final double top;
  final double width;
  final double height;
}
