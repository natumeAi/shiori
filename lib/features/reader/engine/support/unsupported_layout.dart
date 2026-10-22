/// Detection of layouts the S2 reader does not support. A detected book is
/// reported as unsupported with machine-readable reasons, never as an empty
/// successful read. Pure Dart.
library;

import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/style/style_resolver.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';

enum UnsupportedLayoutReason {
  /// OPF `rendition:layout` pre-paginated (package, itemref property or a
  /// display-options file).
  fixedLayout,

  /// Spine `page-progression-direction="rtl"`.
  rtlPageProgression,

  /// A vertical `writing-mode` on the root or on any rendered element.
  verticalWritingMode,

  /// `dir="rtl"` or computed `direction: rtl` on the document root or body.
  rtlDirection,

  /// The publication language is written right to left and the section
  /// declares no explicit direction (the reference then sets `dir=rtl`).
  rtlLanguage,
}

/// The verdict for one spine section.
final class SectionLayoutSupport {
  const SectionLayoutSupport({
    required this.sectionIndex,
    required this.reasons,
    this.rtlBlockCount = 0,
  });

  /// Index into `EpubBook.sections`.
  final int sectionIndex;
  final Set<UnsupportedLayoutReason> reasons;

  /// Non-root elements with `direction: rtl` (isolated right-to-left runs
  /// inside a left-to-right section). Informational: not a reason.
  final int rtlBlockCount;

  bool get supported => reasons.isEmpty;
}

/// The verdict for a whole book.
final class BookLayoutSupport {
  BookLayoutSupport({
    required Set<UnsupportedLayoutReason> bookReasons,
    required List<SectionLayoutSupport> sections,
  }) : bookReasons = Set.unmodifiable(bookReasons),
       sections = List.unmodifiable(sections);

  /// Package-level reasons; they also appear in every section.
  final Set<UnsupportedLayoutReason> bookReasons;
  final List<SectionLayoutSupport> sections;

  bool get supported =>
      bookReasons.isEmpty && sections.every((section) => section.supported);

  /// Every reason found anywhere in the book.
  Set<UnsupportedLayoutReason> get reasons => {
    ...bookReasons,
    for (final section in sections) ...section.reasons,
  };

  List<int> get unsupportedSectionIndices => [
    for (final section in sections)
      if (!section.supported) section.sectionIndex,
  ];

  /// Throws [UnsupportedLayoutException] unless the book is supported.
  void requireSupported() {
    if (!supported) throw UnsupportedLayoutException(this);
  }
}

/// A book (or section) whose layout the reader refuses to open.
final class UnsupportedLayoutException implements Exception {
  const UnsupportedLayoutException(this.support);

  final BookLayoutSupport support;

  @override
  String toString() =>
      'UnsupportedLayoutException(${support.reasons.map((r) => r.name).join(', ')})';
}

const _rtlLanguages = {
  'ar',
  'he',
  'fa',
  'ur',
  'yi',
  'ps',
  'sd',
  'ug',
  'dv',
  'ckb',
  'syr',
  'iw',
};

final _languageElement = RegExp(
  r'<(?:[\w.-]+:)?language\b[^>]*>([^<]*)<',
  caseSensitive: false,
);

String? _primaryLanguage(EpubBook book) {
  final opf = book.archive.text(book.package.opfPath);
  if (opf == null) return null;
  final match = _languageElement.firstMatch(opf);
  final tag = match?.group(1)?.trim().toLowerCase();
  if (tag == null || tag.isEmpty) return null;
  return tag.split(RegExp(r'[-_]')).first;
}

/// Package-level reasons (fixed layout, right-to-left page progression).
Set<UnsupportedLayoutReason> detectBookReasons(EpubBook book) => {
  if (packageLayout(book) == 'pre-paginated')
    UnsupportedLayoutReason.fixedLayout,
  if (book.package.direction?.trim().toLowerCase() == 'rtl')
    UnsupportedLayoutReason.rtlPageProgression,
};

/// Inspects section [sectionIndex]. Computed `writing-mode` and `direction`
/// come from [resolver] (the cascade with default reader settings).
SectionLayoutSupport detectSectionLayout(
  EpubBook book,
  int sectionIndex, {
  SourceDocument? document,
  StyleResolver resolver = const CssStyleResolver(),
  Set<UnsupportedLayoutReason>? bookReasons,
}) {
  final reasons = <UnsupportedLayoutReason>{
    ...(bookReasons ?? detectBookReasons(book)),
  };
  if (isFixedLayoutSection(book, sectionIndex)) {
    reasons.add(UnsupportedLayoutReason.fixedLayout);
  }
  final doc = document ?? book.loadSection(sectionIndex);
  final styled = resolver.resolve(
    book,
    sectionIndex,
    doc,
    const ReaderSettings(),
  );

  final root = doc.documentElementIndex;
  final body = doc.bodyIndex;
  final rootStyle = styled.styleOf(root);
  final bodyStyle = body == null ? null : styled.styleOf(body);
  final rootStyles = [?rootStyle, ?bodyStyle];
  final explicitDirection =
      _dirAttribute(doc, root) != null ||
      (body != null && _dirAttribute(doc, body) != null);

  if (rootStyles.any((s) => s.direction == StyleDirection.rtl) ||
      _dirAttribute(doc, root) == 'rtl' ||
      (body != null && _dirAttribute(doc, body) == 'rtl')) {
    reasons.add(UnsupportedLayoutReason.rtlDirection);
  } else if (!explicitDirection &&
      _rtlLanguages.contains(_primaryLanguage(book))) {
    reasons.add(UnsupportedLayoutReason.rtlLanguage);
  }

  var rtlBlocks = 0;
  // Elements inside a `display: none` subtree are not rendered.
  final hidden = List<bool>.filled(doc.nodes.length, false);
  for (final node in doc.nodes) {
    if (node.kind != SourceNodeKind.element) continue;
    final style = styled.styleOf(node.index);
    if (style == null) continue;
    final parent = node.parentIndex;
    hidden[node.index] =
        (parent != null && hidden[parent]) ||
        style.display == StyleDisplay.none;
    if (hidden[node.index]) continue;
    if (style.writingMode != StyleWritingMode.horizontalTb) {
      reasons.add(UnsupportedLayoutReason.verticalWritingMode);
    }
    if (style.direction == StyleDirection.rtl &&
        node.index != root &&
        node.index != body) {
      rtlBlocks++;
    }
  }
  return SectionLayoutSupport(
    sectionIndex: sectionIndex,
    reasons: reasons,
    rtlBlockCount: rtlBlocks,
  );
}

String? _dirAttribute(SourceDocument doc, int index) =>
    doc.nodes[index].attribute('dir')?.trim().toLowerCase();

/// Inspects every section of [book] (loads and styles each one).
BookLayoutSupport detectBookLayout(
  EpubBook book, {
  StyleResolver resolver = const CssStyleResolver(),
}) {
  final bookReasons = detectBookReasons(book);
  return BookLayoutSupport(
    bookReasons: bookReasons,
    sections: [
      for (var i = 0; i < book.sections.length; i++)
        detectSectionLayout(
          book,
          i,
          resolver: resolver,
          bookReasons: bookReasons,
        ),
    ],
  );
}
