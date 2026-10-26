import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/diagnostics/probe_declarations.dart';
import 'package:shiori/features/diagnostics/data/book_digest.dart';
import 'package:shiori/features/diagnostics/data/reader_export_repository.dart';
import 'package:shiori/features/diagnostics/data/reader_preparation_repository.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/reader_probe_controller.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/reader_turn_controller.dart';
import 'package:shiori/features/reader/engine/pagination/page_painter.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/prepared_reader_session.dart';

import '../../../helpers/probe_storage_fixtures.dart';
import '../../../helpers/reader_probe_fixtures.dart';
import '../../reader/engine/motion/motion_test_support.dart';
import '../../reader/engine/surface/surface_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'resource metadata round trips actual nondefault pool/cache caps',
    () async {
      final h = await SurfaceHarness.open();
      addTearDown(h.close);
      final pool = PageSurfacePool(
        maxPictureBytes: 1234567,
        maxImageBytes: 2345678,
      );
      final session = (await PreparedReaderSession.open(
        pool: pool,
        section: h.section,
        pageIndex: 0,
        sectionCount: 1,
        loadSection: (_) async => h.section,
        theme: surfaceTheme,
      ))!;
      final rec = readerRecorder(capacity: 100);
      addTearDown(rec.dispose);
      final probe = ReaderProbeController(rec)..session = session;
      addTearDown(probe.dispose);
      await rec.start(
        runId: 'caps',
        bookSha256: readerDigest,
        fixtureId: 'chapters',
        scenarioId: 'R10',
        repeatIndex: 1,
        repeatCount: 3,
        input: 'synthetic_injected',
        declarations: const ProbeDeclarations(),
        metadata: {'resourceCaps': probe.resourceCaps},
      );
      probe.snapshot();
      final record = (await rec.stop())!;
      final decoded = ReaderExportRepository.decode(
        jsonEncode(record.toJson()),
      );
      expect(decoded.engine.metadata['resourceCaps'], {
        'liveSurfaceCap': 3,
        'liveSurfaceReserve': 1,
        'pictureCacheBytes': 1234567,
        'imageCacheBytes': 2345678,
      });
      expect(decoded.resources.single['liveSurfaces'], pool.liveSurfaces);
      expect(decoded.resources.single['pictureBytes'], pool.pictureBytes);
      expect(decoded.resources.single['imageBytes'], pool.images.totalBytes);
    },
  );
  test('versioned JSON round trip and safe Documents filename', () async {
    final root = await Directory.systemTemp.createTemp('reader-export-');
    addTearDown(() => root.delete(recursive: true));
    final record = await sampleReaderRecord();
    final unsafe = record.copyWith(
      engine: record.engine.copyWith(
        buildId: '../build/界',
        runId: r'../../runpath',
      ),
    );
    final repo = ReaderExportRepository(TestDirectories(root));
    final path = await repo.export(unsafe);
    expect(
      File(path).parent.uri,
      (await TestDirectories(root).documents()).uri,
    );
    expect(
      ReaderExportRepository.fileName(unsafe),
      matches(r'^shiori-reader-[a-zA-Z0-9._-]+.json$'),
    );
    expect(
      ReaderExportRepository.decode(await File(path).readAsString()),
      unsafe,
    );
    expect(unsafe.schemaVersion, 1);
    expect(unsafe.kind, 'reader_feasibility');
  });
  test(
    'missing, future, noninteger schemas and malformed JSON are rejected',
    () async {
      final record = await sampleReaderRecord();
      for (final version in [null, 2, 1.0, '1']) {
        final map = record.toJson()..['schemaVersion'] = version;
        expect(
          () => ReaderExportRepository.decode(jsonEncode(map)),
          throwsA(isA<ParseException>()),
        );
      }
      final map = record.toJson()..['engine'] = {'schemaVersion': 2};
      expect(
        () => ReaderExportRepository.decode(jsonEncode(map)),
        throwsA(isA<ParseException>()),
      );
      for (final value in ['[]', '{', '{}']) {
        expect(
          () => ReaderExportRepository.decode(value),
          throwsA(isA<ParseException>()),
        );
      }
    },
  );
  test(
    'clipboard is valid UTF-8 and bounded under oversized declarations',
    () async {
      final record = await sampleReaderRecord();
      final huge = record.copyWith(
        engine: record.engine.copyWith(
          runId: List.filled(9000, '界🙂').join(),
          declarations: record.engine.declarations.copyWith(
            deviceModel: List.filled(9000, '界').join(),
          ),
        ),
      );
      final summary = ReaderExportRepository.clipboard(huge);
      expect(utf8.encode(summary).length, lessThanOrEqualTo(4000));
      expect(utf8.decode(utf8.encode(summary)), summary);
      expect(summary, contains('unverified'));
    },
  );
  test('I/O errors are typed and never return a success path', () async {
    final root = await Directory.systemTemp.createTemp('reader-export-error-');
    addTearDown(() => root.delete(recursive: true));
    await File('${root.path}/documents').writeAsString('occupied');
    await expectLater(
      ReaderExportRepository(TestDirectories(root))
          .export(await sampleReaderRecord()),
      throwsA(isA<ParseException>()),
    );
  });
  test('real fixture preparation and proven turn export no title, prose, filename or CFI', () async {
    final bytes = File('assets/reader_fixtures/chapters.epub')
        .readAsBytesSync();
    expect(sha256Hex(bytes), readerDigest);
    final book = EpubBook.open(bytes);
    final rec = readerRecorder(capacity: 1024);
    addTearDown(rec.dispose);
    await startReader(rec);
    final owner = ReaderPreparationRepository(
      book: book,
      digest: readerDigest,
      settings: const ReaderSettings(),
      width: 430,
      height: 932,
      dpr: 3,
      generation: 1,
      recorder: rec,
    );
    final section = (await owner.load(0))!;
    final session = (await PreparedReaderSession.open(
      pool: PageSurfacePool(),
      section: section,
      pageIndex: 0,
      sectionCount: book.sections.length,
      loadSection: owner.load,
      theme: const PagePaintTheme(background: 0xffffffff),
    ))!;
    final clock = TestTurnClock();
    final controller = ReaderTurnController(
      session: session,
      initial: session.position,
      clock: clock,
      width: 430,
      timing: rec,
    );
    // Complete real preparation before advancing the injected motion clock.
    await session.warm(TurnDirection.next);
    final turn = controller.turnPage(TurnDirection.next);
    await clock.flush();
    controller.tick();
    clock.now = 500;
    controller.tick();
    await clock.flush();
    await turn;
    final record = (await rec.stop())!;
    controller.close();
    await clock.flush();
    session.close();
    await owner.close();
    expect(record.layoutCosts, isNotEmpty);
    expect(record.readerEvents.any((e) => e['event'] == 'accepted'), true);
    final json = jsonEncode(record.toJson());
    expect(json, isNot(contains('chapters.epub')));
    expect(json, isNot(contains('epubcfi(')));
    final opf = book.archive.text(book.package.opfPath)!;
    final title = RegExp(r'<dc:title[^>]*>([^<]+)</dc:title>')
        .firstMatch(opf)!
        .group(1)!;
    expect(json, isNot(contains(title)));
    for (var i = 0; i < book.sections.length; i++) {
      for (final node in book.loadSection(i).nodes) {
        final text = node.text?.trim();
        if (node.kind == SourceNodeKind.text &&
            text != null &&
            text.length >= 12) {
          expect(json, isNot(contains(text.substring(0, 12))));
        }
      }
    }
  });
}
