import 'dart:convert';
import 'dart:io';

import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/layout/authored_dimension_resolver.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_section.dart';
import 'package:shiori/features/reader/data/layout/section_source_facts.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';

import '../../contract_test_values.dart';
import '../worker/import_test_support.dart';

Map<String, Object?> jsonObject(Object? value) => value as Map<String, Object?>;
List<Map<String, Object?>> readCases(String name) =>
    (jsonObject(
              jsonDecode(
                File('test/fixtures/reader/fixed_layout/$name.json')
                    .readAsStringSync(),
              ),
            )['cases']
            as List)
        .map(jsonObject)
        .toList();

final class FixedCorpusInput {
  FixedCorpusInput(Map<String, Object?> fixture) {
    final publication = jsonObject(fixture['publication']);
    final sequence = (publication['sequence'] as List).map(jsonObject).toList();
    final entries = importEntries()..remove('EPUB/s0.xhtml');
    entries['EPUB/package.opf'] = publication['packageSource'] as String;
    for (var i = 0; i < sequence.length; i++) {
      entries['EPUB/p$i.xhtml'] = fixture['source'] as String;
    }
    book = EpubBook.open(importZip(entries));
    document = const SourceParser().parse(fixture['source'] as String);
    sourceFacts = extractSectionSourceFacts(document);
    sections = [
      for (var i = 0; i < book.sections.length; i++)
        ReadingUnitSection(
          page: SourcePageId(
            content: contractContent(),
            sectionIndex: i,
            spineIndex: book.sections[i].spine.sectionIndex,
            stableId: book.sections[i].spine.href!,
          ),
          href: book.sections[i].spine.href!,
          rendition: sectionRendition(book, i),
          linear: book.sections[i].spine.isLinear,
          layoutKey: 'fixture-${fixture['id']}-$i',
          dimensions: sectionRendition(book, i).isFixed == true
              ? resolveAuthoredDimensions(
                  source: sourceFacts,
                  packageRendition: book.package.rendition,
                )
              : null,
        ),
    ];
  }
  late final EpubBook book;
  late final SourceDocument document;
  late final SectionSourceFacts sourceFacts;
  late final List<ReadingUnitSection> sections;
}
