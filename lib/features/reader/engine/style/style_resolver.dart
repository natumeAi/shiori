import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';

/// An `@font-face` rule from the section's author styles.
final class StyleFontFace {
  const StyleFontFace({
    required this.family,
    required this.archivePath,
    this.weight = 400,
    this.style = StyleFontStyle.normal,
  });

  final String family;

  /// Path of the font resource inside the EPUB archive.
  final String archivePath;
  final int weight;
  final StyleFontStyle style;
}

/// Styles of one projected section document.
abstract interface class StyledDocument {
  /// Style of the element at [nodeIndex]; character data uses its parent
  /// element's style. Null for nodes outside the styled tree (for example
  /// the head and its descendants).
  ComputedStyle? styleOf(int nodeIndex);

  /// The `body` element's style (the document element's when there is no
  /// body).
  ComputedStyle get rootStyle;

  List<StyleFontFace> get fontFaces;
}

/// Resolves author styles plus the reference reader overrides
/// (`useReaderSettings.ts:249` layout CSS and `:290` theme CSS) for one
/// section. Pure Dart; may run in a worker isolate.
abstract interface class StyleResolver {
  StyledDocument resolve(
    EpubBook book,
    int sectionIndex,
    SourceDocument document,
    ReaderSettings settings,
  );
}
