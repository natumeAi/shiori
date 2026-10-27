import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/epub/epub_package.dart';
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
  final source = _sourceFacts(document);
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
  final result = Map<String, String?>.of(book.package.rendition);
  result['layout'] = isFixedLayoutSection(book, index)
      ? 'pre-paginated'
      : 'reflowable';
  for (final token in book.sections[index].spine.properties ?? <String>[]) {
    for (final name in ['orientation', 'spread', 'page-spread']) {
      final prefix = 'rendition:$name-';
      if (token.startsWith(prefix)) {
        result[name == 'page-spread' ? 'pageSpread' : name] = token.substring(
          prefix.length,
        );
      }
    }
    if (token.startsWith('page-spread-')) {
      result['pageSpread'] = token.substring('page-spread-'.length);
    }
  }
  return result;
}

SectionSourceFacts _sourceFacts(SourceDocument document) {
  final viewports = <String>[];
  final sourceViewports = <String>[];
  final svg = <SvgSourceDimensions>[];
  for (final node in document.nodes) {
    if (node.kind != SourceNodeKind.element) continue;
    if (node.localName == 'meta') {
      final name = node.attribute('name') ?? node.attribute('property');
      final value = node.attribute('content');
      if (value != null) {
        if (name == 'viewport' || name == 'rendition:viewport') {
          viewports.add(value);
        }
        if (name == 'source-viewport' || name == 'rendition:source-viewport') {
          sourceViewports.add(value);
        }
      }
    }
    if (node.localName == 'svg' &&
        node.namespaceUri == 'http://www.w3.org/2000/svg') {
      svg.add(
        SvgSourceDimensions(
          nodeIndex: node.index,
          width: node.attribute('width'),
          height: node.attribute('height'),
          viewBox: node.attribute('viewBox'),
        ),
      );
    }
  }
  return SectionSourceFacts(
    viewports: viewports,
    sourceViewports: sourceViewports,
    svgDimensions: svg,
  );
}
