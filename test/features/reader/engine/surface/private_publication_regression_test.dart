@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/content_identity.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_key.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/storage/stored_publication.dart';
import 'package:shiori/features/library/data/publications/local_publication.dart';
import 'package:shiori/features/library/data/publications/prepare_book_queue.dart';
import 'package:shiori/features/library/data/publications/prepared_book.dart';
import 'package:shiori/features/library/data/publications/publication_lease.dart';
import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/epub/epub_package.dart';
import 'package:shiori/features/reader/data/layout/source_page_slot.dart';
import 'package:shiori/features/reader/data/layout/authored_dimension_resolver.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/layout/section_source_facts.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_section_preparer.dart';
import 'package:shiori/features/reader/engine/layout/font_format.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/pagination/reading_unit_composer.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/publication_fixed_composition.dart';
import 'package:shiori/features/reader/engine/surface/publication_fixed_sources.dart';

import '../../data/epub/sha256.dart';

/// Anonymous aggregate over the private local books. Never records a path,
/// name, title, text, CFI or image in the report.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final directories = [
    Platform.environment['SHIORI_LOCAL_EPUB_DIR'],
    'D:/Projects/lan-reader/docs',
  ].whereType<String>().where((path) => Directory(path).existsSync()).toList();
  final files = <File>[];
  for (final directory in directories) {
    for (final entity in Directory(directory).listSync()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.epub')) {
        files.add(entity);
      }
    }
  }
  for (final dpr in [1.0, 3.0]) {
    test(
      'private books: every section through import, rendition, composer, '
      'loader and fixed preparer at DPR $dpr',
      () async {
        expect(files, isNotEmpty);
        final report = await _run(files, dpr: dpr);
        final directory = Directory('build/a4-private-regression')
          ..createSync(recursive: true);
        File(
          '${directory.path}/report-dpr${dpr.toInt()}.json',
        ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
        // Counts only; this line never contains private content.
        // ignore: avoid_print
        print('A4 private regression counts: ${jsonEncode(report)}');
        expect(
          report['typedOutcomes'],
          isEmpty,
          reason: 'Anonymous typed failures',
        );
        expect(report['conservedSections'], report['sections']);
        expect(report['preparedFixedSections'], report['fixedSections']);
        expect(report['preparedFixedUnits'], report['fixedUnits']);
        // Evidence is authored: display scale must not change any page.
        expect(report['geometryDiffersFromDpr1'], 0);
      },
      skip: files.isEmpty ? 'private EPUB folders or books are absent' : null,
      timeout: const Timeout(Duration(minutes: 20)),
    );
  }
}

/// Authored evidence per page from the DPR 1 pass; the DPR 3 pass must match.
final _dpr1Geometry = <int, SourceGeometry>{};

Future<Map<String, Object?>> _run(
  List<File> files, {
  required double dpr,
}) async {
  final pageResources = <Map<String, int>>[];
  final counts = <String, int>{
    'books': 0,
    'sections': 0,
    'conservedSections': 0,
    'fixedSections': 0,
    'preparedFixedSections': 0,
    'reflowUnits': 0,
    'fixedUnits': 0,
    'blankSlots': 0,
    'preparedFixedUnits': 0,
    'geometryMatchesDpr1': 0,
    'geometryDiffersFromDpr1': 0,
    'fixedPreparationFailures': 0,
    'compositionFailures': 0,
    'importFailures': 0,
  };
  final outcomes = <String, int>{};
  void outcome(String key) =>
      outcomes.update(key, (n) => n + 1, ifAbsent: () => 1);
  final unsupported = <String, int>{};
  var peakPictureBytes = 0,
      peakImageBytes = 0,
      peakSceneResources = 0,
      peakRetainedSources = 0;
  var retainedPictureBytes = 0,
      retainedImageBytes = 0,
      retainedSceneResources = 0,
      retainedSources = 0;

  final endpoint = ServerEndpoint.parse('https://private.invalid/').endpoint!;
  final bookKey = BookKey(ServerKey(endpoint), 1);
  final session = ServerSession(endpoint: endpoint, generation: 1);

  for (final file in files) {
    counts['books'] = counts['books']! + 1;
    EpubArchive? archive;
    PublicationWorker? importWorker;
    try {
      final bytes = file.readAsBytesSync();
      final identity = ContentIdentity(bookKey, sha256Hex(bytes));
      archive = EpubArchive.openFile(file.path);
      final book = EpubBook.fromArchive(archive, readEpubPackage(archive));
      counts['sections'] = counts['sections']! + book.sections.length;
      if (book.package.spine.length != book.sections.length) {
        outcome('conservation:unresolved-spine-source');
      }
      final first = book.sections.indexWhere((s) => s.spine.isLinear);
      if (first < 0) {
        counts['importFailures'] = counts['importFailures']! + 1;
        outcome('import:no-linear-section');
        continue;
      }
      importWorker = await PublicationWorker.spawn();
      final publication = await importWorker.prepare(file.path, identity);
      final facts = publication.layoutFacts;
      for (final fact in facts.sections) {
        for (final issue in fact.renditionResolution!.issues) {
          outcome('rendition:${issue.kind.name}');
        }
        if (fact.renditionResolution!.isFixed == true) {
          counts['fixedSections'] = counts['fixedSections']! + 1;
          final dimensions = resolveAuthoredDimensions(
            source: extractSectionSourceFacts(
              book.loadSection(fact.sectionIndex),
            ),
            packageRendition: fact.renditionResolution!.effective,
          );
          if (dimensions is UnsupportedDimensions) {
            outcome('dimensions:unsupported');
          }
          if (dimensions is MalformedDimensions) {
            outcome('dimensions:malformed');
          }
        }
      }
      final routeLease = _lease(identity, file);
      final prepared = PreparedBook(publication, routeLease, () {});
      final queue = PrepareBookQueue();
      final worker = importWorker;
      final pool = PageSurfacePool();
      final fonts = FontRegistry(processBudget: ProcessFontBudget());
      PublicationFixedSources? sources;
      PublicationFixedComposition? composition;
      try {
        sources = await PublicationFixedSources.open(
          preparedBook: prepared,
          activation: session,
          layout: fixedSectionLayout(
            identity: identity,
            section: 0,
            viewportWidth: 400,
            viewportHeight: 600,
            devicePixelRatio: dpr,
            settings: const ReaderSettings(),
          ),
          isCurrent: () => true,
          acquireLease: () async => _lease(identity, file),
          queue: queue,
          worker: () async => worker,
          pool: pool,
          fonts: fonts,
          layoutFor: (section) => fixedSectionLayout(
            identity: identity,
            section: section,
            viewportWidth: 400,
            viewportHeight: 600,
            devicePixelRatio: dpr,
            settings: const ReaderSettings(),
          ),
          sectionBaseFor: (page) =>
              sources!.book.sections[page.sectionIndex].spine.cfiBase,
        );
        final owner = sources;
        prepared.release();
        try {
          composition = await PublicationFixedComposition.prepare(
            pool: pool,
            book: owner.book,
            identity: identity,
            facts: facts,
            settings: const ReaderSettings(),
            viewportWidth: 400,
            viewportHeight: 600,
            devicePixelRatio: dpr,
            fixedLayout: (section) => fixedSectionLayout(
              identity: identity,
              section: section,
              viewportWidth: 400,
              viewportHeight: 600,
              devicePixelRatio: dpr,
              settings: const ReaderSettings(),
            ),
            fonts: fonts,
          );
        } on UnsupportedDirectionCompositionException catch (_) {
          counts['compositionFailures'] = counts['compositionFailures']! + 1;
          outcome('composition:unsupported-direction');
          continue;
        } on UnitCompositionException catch (_) {
          counts['compositionFailures'] = counts['compositionFailures']! + 1;
          outcome('composition:invalid-input');
          continue;
        }
        final navigator = composition.navigator;
        if (navigator.units.map((unit) => unit.id).toSet().length !=
            navigator.units.length) {
          outcome('conservation:duplicate-unit');
        }
        final occurrences = <int, int>{};
        for (final unit in navigator.units) {
          for (final slot in unit.slots.whereType<RealSourcePageSlot>()) {
            occurrences.update(
              slot.page.sectionIndex,
              (n) => n + 1,
              ifAbsent: () => 1,
            );
          }
        }
        final seen = <int>{};
        for (final section in navigator.sections) {
          final index = section.page.sectionIndex;
          if (index < 0 || index >= book.sections.length || !seen.add(index)) {
            outcome('conservation:duplicate-or-unknown-source');
            continue;
          }
          final source = book.sections[index];
          final expected = section.rendition.isFixed == true
              ? 1
              : section.reflowPageCount;
          if (section.page.spineIndex != source.spine.sectionIndex ||
              section.page.stableId != source.item.href ||
              occurrences[index] != expected ||
              expected < 1 ||
              !composition.documents.containsKey(section.page)) {
            outcome('conservation:source-mismatch');
          } else {
            counts['conservedSections'] = counts['conservedSections']! + 1;
          }
        }
        if (seen.length != book.sections.length ||
            occurrences.keys.any((index) => !seen.contains(index))) {
          outcome('conservation:missing-or-extra-source');
        }
        for (final unit in navigator.units) {
          if (unit.kind.name == 'reflowPage') {
            counts['reflowUnits'] = counts['reflowUnits']! + 1;
            continue;
          }
          counts['fixedUnits'] = counts['fixedUnits']! + 1;
          counts['blankSlots'] =
              counts['blankSlots']! +
              unit.slots.whereType<BlankSourcePageSlot>().length;
          try {
            pool.images.resetPeakBytes();
            final lease = await pool.prepareFixedUnit(
              unit,
              layout: fixedSectionLayout(
                identity: identity,
                section: unit.activeSource.sectionIndex,
                viewportWidth: 400,
                viewportHeight: 600,
                devicePixelRatio: dpr,
                settings: const ReaderSettings(),
              ),
              loadSource: owner.unitSources.loadSource,
              fonts: fonts,
            );
            if (lease != null) {
              for (final scene in lease.surface.fixedScenes) {
                final page = pageResources.length + 1;
                if (dpr == 1) {
                  _dpr1Geometry[page] = scene.geometry;
                } else {
                  final key = _dpr1Geometry[page] == scene.geometry
                      ? 'geometryMatchesDpr1'
                      : 'geometryDiffersFromDpr1';
                  counts[key] = counts[key]! + 1;
                }
                pageResources.add({
                  'page': pageResources.length + 1,
                  'requestedLayerPixels':
                      scene.plan.resources[SceneResource.layerPixels]!,
                  'peakImageBytes': pool.images.peakBytes,
                });
              }
              counts['preparedFixedUnits'] = counts['preparedFixedUnits']! + 1;
              counts['preparedFixedSections'] =
                  counts['preparedFixedSections']! +
                  unit.slots.whereType<RealSourcePageSlot>().length;
              lease.release();
            } else {
              outcome('fixed:no-prepared-unit');
            }
          } on FixedPreparationFailure catch (error) {
            counts['fixedPreparationFailures'] =
                counts['fixedPreparationFailures']! + 1;
            _capabilityOutcome(error.capability, outcome, unsupported);
          } on RequiredFontException catch (_) {
            outcome('font:required-font');
          } on SceneAdmissionException catch (error) {
            if (error.failure == SceneAdmissionFailure.processFontExhausted) {
              outcome('font:process-exhausted');
            } else {
              outcome('resource:scene-admission');
            }
          } on Object catch (error) {
            outcome('fixed:${error.runtimeType}');
          }
          peakPictureBytes = _max(peakPictureBytes, pool.pictureBytes);
          peakImageBytes = _max(peakImageBytes, pool.images.peakBytes);
          peakSceneResources = _max(
            peakSceneResources,
            pool.resourceBudget.used.values.fold<int>(0, (a, b) => a + b),
          );
          peakRetainedSources = _max(
            peakRetainedSources,
            owner.retainedSourceOwners,
          );
        }
      } on UnsupportedDirectionCompositionException catch (_) {
        counts['compositionFailures'] = counts['compositionFailures']! + 1;
        outcome('composition:unsupported-direction');
      } on Object catch (error) {
        counts['compositionFailures'] = counts['compositionFailures']! + 1;
        outcome('composition:${error.runtimeType}');
      } finally {
        prepared.release();
        composition?.dispose();
        await sources?.close();
        pool.close();
        await pool.drained;
        retainedPictureBytes = _max(retainedPictureBytes, pool.pictureBytes);
        retainedImageBytes = _max(retainedImageBytes, pool.images.totalBytes);
        retainedSceneResources = _max(
          retainedSceneResources,
          pool.resourceBudget.used.values.fold<int>(0, (a, b) => a + b),
        );
        retainedSources = _max(
          retainedSources,
          sources?.retainedSourceOwners ?? 0,
        );
      }
    } on Object catch (error) {
      counts['importFailures'] = counts['importFailures']! + 1;
      outcome('import:${error.runtimeType}');
    } finally {
      archive?.close();
      await importWorker?.close();
    }
  }

  final orderedOutcomes = Map.fromEntries(
    outcomes.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
  final orderedUnsupported = Map.fromEntries(
    unsupported.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
  return {
    ...counts,
    'typedOutcomes': orderedOutcomes,
    'unsupportedConstructKinds': orderedUnsupported,
    'resources': {
      'peakPictureBytes': peakPictureBytes,
      'peakImageBytes': peakImageBytes,
      'dpr': dpr,
      'pages': pageResources,
      'peakSceneResources': peakSceneResources,
      'peakRetainedSources': peakRetainedSources,
      'retainedPictureBytes': retainedPictureBytes,
      'retainedImageBytes': retainedImageBytes,
      'retainedSceneResources': retainedSceneResources,
      'retainedSources': retainedSources,
    },
  };
}

void _capabilityOutcome(
  SectionCapability capability,
  void Function(String) outcome,
  Map<String, int> unsupported,
) {
  switch (capability) {
    case UnsupportedSectionCapability():
      outcome('unsupported');
      for (final construct in capability.constructs) {
        unsupported.update(
          construct.kind.name,
          (n) => n + 1,
          ifAbsent: () => 1,
        );
      }
    case MalformedSectionCapability():
      outcome('malformed');
    case ResourceSectionCapability():
      outcome('resource:capability');
    case RenderSectionCapability():
      outcome('render:capability');
    case CompleteSectionCapability():
      outcome('complete:not-published');
  }
}

int _max(int a, int b) => a > b ? a : b;

PublicationLease _lease(ContentIdentity identity, File file) {
  final length = file.lengthSync();
  return PublicationLease(
    StoredPublication(
      key: identity.bookKey,
      sha256: identity.sha256,
      byteLength: length,
      parserVersion: identity.parserVersion,
      canonicalVersion: identity.canonicalVersion,
      accessedAt: DateTime.utc(2026, 10, 29),
    ),
    LocalPublication(
      key: identity.bookKey,
      path: file.path,
      byteLength: length,
      digest: identity.sha256,
    ),
    () {},
  );
}
