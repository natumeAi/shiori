import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/epub/epub_package.dart';
import 'package:shiori/features/reader/data/layout/section_source_facts.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';
import 'package:shiori/features/reader/data/source/xml_parser.dart';
import 'package:shiori/features/reader/data/worker/prepared_publication.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';

PublicationMetadata importMetadata(EpubArchive archive, String opfPath) {
  final root = parseXmlDocument(archive.text(opfPath)!).documentElement!;
  if (root.localName != 'package' ||
      (root.namespaceUri != null && root.namespaceUri != opfNamespace)) {
    throw const FormatException();
  }
  final metadata = root.childElements.where((e) => e.localName == 'metadata');
  List<String> values(String name) => [
    for (final parent in metadata)
      for (final node in parent.childElements)
        if (node.localName == name &&
            (node.namespaceUri == 'http://purl.org/dc/elements/1.1/' ||
                node.namespaceUri == null))
          node.textContent.trim(),
  ];
  return PublicationMetadata(
    titles: values('title'),
    creators: values('creator'),
    languages: values('language'),
    identifiers: values('identifier'),
  );
}

PublicationLayoutFacts importLayoutFacts(
  EpubBook book,
  PublicationMetadata metadata,
  int firstIndex,
  SourceDocument document,
) {
  final styled = const CssStyleResolver().resolve(
    book,
    firstIndex,
    document,
    const ReaderSettings(),
  );
  final root = document.documentElementIndex;
  final body = document.bodyIndex;
  final hidden = List<bool>.filled(document.nodes.length, false);
  final modes = <String>{};
  var rtlRuns = 0;
  for (final node in document.nodes) {
    if (node.kind != SourceNodeKind.element) continue;
    final style = styled.styleOf(node.index);
    if (style == null) continue;
    hidden[node.index] =
        (node.parentIndex != null && hidden[node.parentIndex!]) ||
        style.display == StyleDisplay.none;
    if (hidden[node.index]) continue;
    modes.add(_writingMode(style.writingMode));
    if (node.index != root &&
        node.index != body &&
        style.direction == StyleDirection.rtl) {
      rtlRuns++;
    }
  }
  final rootStyle = styled.styleOf(root);
  final bodyStyle = body == null ? null : styled.styleOf(body);
  final styleFacts = SectionStyleFacts(
    rootWritingMode: rootStyle == null
        ? null
        : _writingMode(rootStyle.writingMode),
    bodyWritingMode: bodyStyle == null
        ? null
        : _writingMode(bodyStyle.writingMode),
    writingModes: modes,
    rootDirection: rootStyle?.direction.name,
    bodyDirection: bodyStyle?.direction.name,
    declaredRootDirection: document.attribute(root, 'dir'),
    declaredBodyDirection: body == null
        ? null
        : document.attribute(body, 'dir'),
    rtlRunCount: rtlRuns,
  );
  final source = importSectionSourceFacts(document);
  return PublicationLayoutFacts(
    pageProgressionDirection: book.package.direction,
    primaryLanguage: metadata.languages.firstOrNull,
    packageRendition: book.package.rendition,
    sections: [
      for (var i = 0; i < book.sections.length; i++)
        SectionLayoutFacts(
          sectionIndex: i,
          spineIndex: book.sections[i].spine.sectionIndex,
          mode: isFixedLayoutSection(book, i)
              ? PublicationLayoutMode.fixed
              : PublicationLayoutMode.reflowable,
          itemrefProperties: book.sections[i].spine.properties ?? const [],
          rendition: _rendition(book, i),
          renditionResolution: sectionRendition(book, i),
          source: i == firstIndex ? source : null,
          style: i == firstIndex ? styleFacts : null,
        ),
    ],
  );
}

String _writingMode(StyleWritingMode mode) => switch (mode) {
  StyleWritingMode.horizontalTb => 'horizontal-tb',
  StyleWritingMode.verticalRl => 'vertical-rl',
  StyleWritingMode.verticalLr => 'vertical-lr',
};

Map<String, String?> _rendition(EpubBook book, int index) {
  return sectionRendition(book, index).effective;
}

/// Detached dimensions for later sections as well as the initial import.
SectionSourceFacts importSectionSourceFacts(SourceDocument document) {
  return extractSectionSourceFacts(document);
}
