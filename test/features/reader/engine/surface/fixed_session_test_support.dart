import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/layout/authored_dimension_resolver.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_section.dart';
import 'package:shiori/features/reader/data/layout/section_source_facts.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';
import 'package:shiori/features/reader/data/resources/archive_reader_resource_source.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/pagination/anchor.dart';
import 'package:shiori/features/reader/engine/pagination/layout_identity.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';
import 'package:shiori/features/reader/engine/pagination/reading_unit_navigator.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';
import 'package:shiori/features/reader/engine/surface/fixed_unit_navigation.dart';

import '../../contract_test_values.dart';
import '../../data/worker/import_test_support.dart';
import '../style/style_test_support.dart' as style;

final class FixedSessionFixture {
  FixedSessionFixture({
    String caseId = 'mixed-navigation-positive',
    int? spreads,
    this.width = 800,
    this.height = 600,
  }) {
    final corpus = jsonDecode(
      File('test/fixtures/reader/fixed_layout/corpus.json').readAsStringSync(),
    ) as Map;
    final row = (corpus['cases'] as List).cast<Map>().singleWhere(
      (r) => r['id'] == caseId,
    );
    final source = row['source'] as String;
    final resources = <String, Object>{
      for (final entry in (corpus['resources'] as Map).entries)
        (entry.key as String).substring(1): entry.value as String,
      'font.ttf': File(
        'tool/oracle/fixtures/styles/EPUB/fonts/Roboto-Regular.ttf',
      ).readAsBytesSync(),
    };
    Uint8List bytes;
    if (spreads != null) {
      bytes = style.buildEpub(
        sections: {for (var i = 0; i < spreads * 2; i++) 'p$i.xhtml': source},
        rootFiles: resources,
        metadata: '<meta property="rendition:layout">pre-paginated</meta>',
        spineProperties: {
          for (var i = 0; i < spreads * 2; i++)
            'p$i.xhtml': 'page-spread-${i.isEven ? 'left' : 'right'}',
        },
      );
    } else {
      final publication = row['publication'] as Map;
      final entries = importEntries()..remove('EPUB/s0.xhtml');
      entries['EPUB/package.opf'] = publication['packageSource'] as String;
      for (var i = 0; i < (publication['sequence'] as List).length; i++) {
        entries['EPUB/p$i.xhtml'] = source;
      }
      final archive = Archive();
      for (final entry in <String, Object>{...entries, ...resources}.entries) {
        final data = entry.value is String
            ? utf8.encode(entry.value as String)
            : entry.value as Uint8List;
        archive.addFile(ArchiveFile(entry.key, data.length, data));
      }
      bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    }
    book = EpubBook.open(bytes);
    for (var i = 0; i < book.sections.length; i++) {
      documents[i] = book.loadSection(i);
      styles[i] = const CssStyleResolver().resolve(
        book,
        i,
        documents[i]!,
        const ReaderSettings(),
        authoredViewport: AuthoredPageSize(320, 240),
      );
    }
  }
  late final EpubBook book;
  final double width, height;
  final documents = <int, SourceDocument>{};
  final styles = <int, CssStyledDocument>{};
  final reflow = <int, PreparedSection>{};
  final acquired = <int, int>{},
      released = <int, int>{},
      resourceDisposals = <int, int>{};
  final images = <int, Map<String, FixedImageRequest>>{};
  final badFonts = <int>{};
  late ComposedReadingUnitNavigator navigator;
  LayoutIdentity layout(int section) => LayoutIdentity(
    contentId: contractContent().sha256,
    sectionIndex: section,
    viewportWidth: width,
    viewportHeight: height,
    devicePixelRatio: 1,
    settings: const ReaderSettings(),
    fontSignature: 'fixed',
  );
  SourcePageId page(int section) => contractPage(
    section: section,
    spine: book.sections[section].spine.sectionIndex,
    id: book.sections[section].item.href,
  );

  Future<void> prepareNavigation() async {
    for (var i = 0; i < book.sections.length; i++) {
      if (sectionRendition(book, i).isFixed != false) continue;
      reflow[i] =
          await SectionPreparer(
            fonts: FontRegistry(processBudget: ProcessFontBudget()),
          ).prepare(
            PrepareRequest(
              book: book,
              sectionIndex: i,
              document: documents[i]!,
              styled: styles[i]!,
              settings: const ReaderSettings(),
              contentId: contractContent().sha256,
              viewportWidth: width,
              viewportHeight: height,
              devicePixelRatio: 1,
            ),
          );
    }
    navigator = ComposedReadingUnitNavigator(
      sections: [
        for (var i = 0; i < book.sections.length; i++)
          ReadingUnitSection(
            page: page(i),
            href: book.sections[i].item.href,
            rendition: sectionRendition(book, i),
            linear: book.sections[i].spine.isLinear,
            layoutKey: reflow[i]?.identity.key ?? layout(i).key,
            reflowPageCount: reflow[i]?.pageCount ?? 1,
            dimensions: reflow.containsKey(i)
                ? null
                : resolveAuthoredDimensions(
                    source: extractSectionSourceFacts(documents[i]!),
                    packageRendition: book.package.rendition,
                  ),
          ),
      ],
      viewportWidth: width,
      viewportHeight: height,
      documents: {
        for (final entry in documents.entries) page(entry.key): entry.value,
      },
      locateReflow: (page, position) => reflow[page.sectionIndex] == null
          ? null
          : PageAnchors(reflow[page.sectionIndex]!).locate(position)?.pageIndex,
    );
  }

  FixedUnitSources sources({FontRegistry? fonts}) => FixedUnitSources(
    loadSource: (p) async {
      final i = p.sectionIndex;
      acquired.update(i, (n) => n + 1, ifAbsent: () => 1);
      return FixedSourceLease(
        page: p,
        document: documents[i]!,
        styles: styles[i]!,
        rendition: sectionRendition(book, i),
        retainedSourceBytes: documents[i]!.nodes.length * 256,
        images: images[i] ?? {},
        resources: _Resources(
          ArchiveReaderResourceSource(book.archive),
          badFonts.contains(i),
          () => resourceDisposals.update(i, (n) => n + 1, ifAbsent: () => 1),
        ),
        releaseSource: () =>
            released.update(i, (n) => n + 1, ifAbsent: () => 1),
      );
    },
    layoutFor: layout,
    sectionBaseFor: (p) => book.sections[p.sectionIndex].spine.cfiBase,
    fonts: fonts ?? FontRegistry(processBudget: ProcessFontBudget()),
  );

  void dispose() {
    for (final section in reflow.values) {
      section.dispose();
    }
    book.archive.close();
    expect(released, acquired);
    expect(resourceDisposals, acquired);
  }
}

final class _Resources implements ReaderResourceSource {
  _Resources(this.source, this.badFont, this.onDispose);
  final ReaderResourceSource source;
  final bool badFont;
  final void Function() onDispose;
  bool disposed = false;
  @override
  Uint8List? bytes(String path) =>
      badFont && path.endsWith('.ttf') ? Uint8List(12) : source.bytes(path);
  @override
  int size(String path) => source.size(path);
  @override
  bool contains(String path) => source.contains(path);
  @override
  void dispose() {
    if (disposed) return;
    disposed = true;
    onDispose();
    source.dispose();
  }
}
