import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/library/data/publications/prepared_book.dart';
import 'package:shiori/features/reader/data/layout/reading_unit.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/pagination/layout_identity.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/prepared_reader_session.dart';
import 'package:shiori/features/reader/engine/surface/publication_fixed_composition.dart';
import 'package:shiori/features/reader/engine/surface/publication_fixed_sources.dart';

import '../../../library/data/publications/prepare_test_support.dart';
import 'surface_test_support.dart';

Map<String, Object> corpusResources() {
  final corpus = jsonDecode(
    File('test/fixtures/reader/fixed_layout/corpus.json').readAsStringSync(),
  ) as Map;
  return {
    for (final entry in (corpus['resources'] as Map).entries)
      (entry.key as String).substring(1): entry.value as String,
    'font.ttf': File(
      'tool/oracle/fixtures/styles/EPUB/fonts/Roboto-Regular.ttf',
    ).readAsBytesSync(),
  };
}

String corpusSource(String caseId) {
  final corpus = jsonDecode(
    File('test/fixtures/reader/fixed_layout/corpus.json').readAsStringSync(),
  ) as Map;
  final row = (corpus['cases'] as List).cast<Map>().singleWhere(
    (r) => r['id'] == caseId,
  );
  return row['source'] as String;
}

Uint8List _archiveZip(
  String packageSource,
  List<String> sections,
  Map<String, Object> resources,
) {
  final archive = Archive();
  void add(String path, Object content) {
    final bytes = content is Uint8List
        ? content
        : Uint8List.fromList(utf8.encode(content as String));
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  add(
    'META-INF/container.xml',
    '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
        '<rootfiles><rootfile full-path="EPUB/package.opf" '
        'media-type="application/oebps-package+xml"/></rootfiles></container>',
  );
  add('EPUB/package.opf', packageSource);
  for (var i = 0; i < sections.length; i++) {
    add('EPUB/p$i.xhtml', sections[i]);
    add('EPUB/s$i.xhtml', sections[i]);
  }
  for (final entry in resources.entries) {
    add(entry.key, entry.value);
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// Corpus mixed publication with its exact package/sequence.
Uint8List corpusPublication(String caseId) {
  final corpus = jsonDecode(
    File('test/fixtures/reader/fixed_layout/corpus.json').readAsStringSync(),
  ) as Map;
  final row = (corpus['cases'] as List).cast<Map>().singleWhere(
    (r) => r['id'] == caseId,
  );
  final publication = row['publication'] as Map;
  final source = row['source'] as String;
  final count = (publication['sequence'] as List).length;
  return _archiveZip(
    publication['packageSource'] as String,
    List.filled(count, source),
    corpusResources(),
  );
}

/// Synthetic all-fixed publication with explicit spine sides.
Uint8List fixedSidesPublication(List<String?> sides, {String? caseId}) {
  final source = corpusSource(caseId ?? 'mixed-navigation-positive');
  final spine = StringBuffer();
  for (var i = 0; i < sides.length; i++) {
    final side = sides[i] == null ? '' : ' page-spread-${sides[i]}';
    spine.write(
      '<itemref idref="p$i" linear="yes" '
      'properties="rendition:layout-pre-paginated$side"/>',
    );
  }
  final package =
      '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" '
      'unique-identifier="uid"><metadata '
      'xmlns:dc="http://purl.org/dc/elements/1.1/">'
      '<dc:identifier id="uid">synthetic-a4-fixed</dc:identifier>'
      '<dc:title>A4 synthetic</dc:title><dc:language>en</dc:language>'
      '<meta property="rendition:layout">pre-paginated</meta>'
      '<meta property="rendition:spread">auto</meta></metadata><manifest>'
      '${[for (var i = 0; i < sides.length; i++) '<item id="p$i" href="p$i.xhtml" media-type="application/xhtml+xml"/>'].join()}'
      '</manifest><spine page-progression-direction="ltr">$spine</spine>'
      '</package>';
  return _archiveZip(
    package,
    List.filled(sides.length, source),
    corpusResources(),
  );
}

final class PublicationFixedHarness {
  PublicationFixedHarness._(
    this.h,
    this.ready,
    this.sources,
    this.composition,
    this.pool,
    this.fonts,
    this.viewportWidth,
    this.viewportHeight,
  );
  final PrepareHarness h;
  final PreparedBook ready;
  final PublicationFixedSources sources;
  final PublicationFixedComposition composition;
  final PageSurfacePool pool;
  final FontRegistry fonts;
  final double viewportWidth, viewportHeight;
  final settings = const ReaderSettings();
  static const dpr = 1.0;

  LayoutIdentity fixedLayout(int section) => fixedSectionLayout(
    identity: ready.identity,
    section: section,
    viewportWidth: viewportWidth,
    viewportHeight: viewportHeight,
    devicePixelRatio: dpr,
    settings: settings,
  );

  static Future<PublicationFixedHarness> open(
    Uint8List bytes, {
    double width = 400,
    double height = 600,
  }) async {
    final h = await PrepareHarness.create();
    h.bytes = bytes;
    final ready = await h.service.prepare(h.key);
    final fonts = FontRegistry(processBudget: ProcessFontBudget());
    final pool = PageSurfacePool();
    LayoutIdentity layout(int section) => fixedSectionLayout(
      identity: ready.identity,
      section: section,
      viewportWidth: width,
      viewportHeight: height,
      devicePixelRatio: dpr,
      settings: const ReaderSettings(),
    );
    late PublicationFixedSources sources;
    sources = await PublicationFixedSources.open(
      preparedBook: ready,
      activation: h.session,
      layout: layout(0),
      isCurrent: () => h.f.guard.isCurrent(h.session),
      acquireLease: () => h.f.cache.acquireHead(h.session, h.key),
      queue: h.service.queue,
      worker: h.service.worker.get,
      pool: pool,
      fonts: fonts,
      layoutFor: layout,
      sectionBaseFor: (page) =>
          sources.book.sections[page.sectionIndex].spine.cfiBase,
    );
    final composition = await PublicationFixedComposition.prepare(
      pool: pool,
      book: sources.book,
      identity: ready.identity,
      facts: ready.layoutFacts,
      settings: const ReaderSettings(),
      viewportWidth: width,
      viewportHeight: height,
      devicePixelRatio: dpr,
      fixedLayout: layout,
      fonts: fonts,
    );
    final harness = PublicationFixedHarness._(
      h,
      ready,
      sources,
      composition,
      pool,
      fonts,
      width,
      height,
    );
    addTearDown(harness.close);
    return harness;
  }

  Future<PreparedReaderSession> openSession({ReadingUnit? unit}) async {
    final target = unit ?? composition.navigator.units.first;
    final session = (await PreparedReaderSession.openUnit(
      pool: pool,
      unit: target,
      navigator: composition.navigator,
      fixedSources: sources.unitSources,
      loadSection: composition.loadReflow,
      theme: surfaceTheme,
      activation: h.session,
      isActivationCurrent: h.f.guard.isCurrent,
      publication: sources.publication,
      cancelAndDrainMotion: () async {},
      disposeSourceAdapters: () async {
        composition.dispose();
        await sources.disposeBook();
      },
    ))!;
    addTearDown(() async {
      session.close();
      await session.closed;
    });
    return session;
  }

  Future<void> close() async {
    composition.dispose();
    await sources.close();
    pool.close();
    await pool.drained;
    ready.release();
  }
}
