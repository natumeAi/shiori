/// Package-level layout facts shared by the style resolver and the
/// unsupported-layout detector. Pure Dart.
library;

import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/resources/archive_reader_resource_source.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';

const _displayOptionFiles = [
  'META-INF/com.apple.ibooks.display-options.xml',
  'META-INF/com.kobobooks.display-options.xml',
];

final _fixedLayoutOption = RegExp(
  r'''<option\b[^>]*\bname\s*=\s*["']fixed-layout["'][^>]*>\s*true\s*</option>''',
  caseSensitive: false,
);

/// The package layout as the reference computes it: `rendition:layout`, or
/// `pre-paginated` when a display-options file declares `fixed-layout`
/// (`epub.js:1030`, only when the package declares no layout).
String? packageLayout(EpubBook book) {
  final declared = book.package.rendition['layout']?.trim();
  if (declared != null && declared.isNotEmpty) return declared;
  for (final path in _displayOptionFiles) {
    final text = ArchiveReaderResourceSource(book.archive).text(path);
    if (text == null) continue;
    return _fixedLayoutOption.hasMatch(text) ? 'pre-paginated' : null;
  }
  return null;
}

/// True when section [sectionIndex] (index into `book.sections`) is fixed
/// layout: its itemref overrides the package value.
bool isFixedLayoutSection(EpubBook book, int sectionIndex) {
  final properties = book.sections[sectionIndex].spine.properties ?? const [];
  if (properties.contains('rendition:layout-reflowable')) return false;
  if (properties.contains('rendition:layout-pre-paginated')) return true;
  return packageLayout(book) == 'pre-paginated';
}
