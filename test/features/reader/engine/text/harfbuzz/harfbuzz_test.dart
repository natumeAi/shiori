import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/text/harfbuzz/harfbuzz.dart';

import '../../../../../../tool/reader/fixed_layout_spike_defects.dart';
import 'module_fixture.dart';
import 'module_measurements.dart';

TypeMatcher<HarfBuzzException> failure(HarfBuzzFailure value) =>
    isA<HarfBuzzException>().having((e) => e.failure, 'failure', value);

void expectDrained(HarfBuzzResources resources) {
  expect(resources.live.values, everyElement(0));
  expect(resources.created, resources.destroyed);
  expect(resources.budget.used.values, everyElement(0));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final missing = HarfBuzzLibrarySource.windowsHashes.keys
      .where(
        (name) =>
            !File('${HarfBuzzLibrarySource.windowsDirectory}/$name')
                .existsSync(),
      )
      .toList();
  final skip = !Platform.isWindows
      ? 'HarfBuzz 14.6.0 Windows host DLL tests; this platform has no host binary.'
      : missing.isNotEmpty
      ? 'Pinned host DLL chain absent: ${missing.join(', ')} in '
            '${HarfBuzzLibrarySource.windowsDirectory}; no download attempted.'
      : null;
  final corpus = readFixtureJson('corpus'), oracle = readFixtureJson('oracle');
  final cases = requiredCases(corpus, oracle);
  final processFonts = ProcessFontBudget(); // Isolated test owner only.
  late HarfBuzzAdmittedFont admitted;
  late HarfBuzzBindings bindings;
  late SpikeReferenceDefects defects;
  setUpAll(() async {
    if (skip != null) return;
    final font = corpus['font'] as Map;
    final bytes = File(font['path'] as String).readAsBytesSync();
    expect(sha256.convert(bytes).toString(), font['sha256']);
    bindings = HarfBuzzBindings();
    admitted = await HarfBuzzAdmittedFont.load(
      bytes,
      faceDescriptor: '400/normal',
      processFonts: processFonts,
      register: (b, alias) => ui.loadFontFromList(b, fontFamily: alias),
    );
    defects = SpikeReferenceDefects(oracle);
    await defects.load();
    expect(cases, hasLength(6));
  });

  for (final (fixture, reference) in cases) {
    test('${fixture['id']}: B geometry and measured D4', () async {
      final resources = HarfBuzzResources(SceneResourceBudget());
      final font = HarfBuzzFont.open(
        admitted,
        bindings: bindings,
        resources: resources,
      );
      final runs = <(HarfBuzzRun, HarfBuzzPlacedRun)>[];
      try {
        runs.addAll(
          prepareFixture(fixture['source'] as String, font, resources),
        );
        final maximum = definitionB(runs, reference);
        expect(maximum, lessThanOrEqualTo(.5));
        final pixels = await rasterD4(runs, fixture, reference, defects);
        expect(pixels['status'], isNot('unverified'));
        // Geometry-test success never converts a measured raster failure to a
        // successful svg-text fidelity gate. Keep the unchanged D4 result visible.
        // ignore: avoid_print
        print(
          '${fixture['id']}: B max=$maximum px; D4=${pixels['pass']}; '
          'detail=${pixels['d4']}',
        );
      } finally {
        for (final (run, placed) in runs.reversed) {
          placed.dispose();
          placed.dispose();
          run.dispose();
          run.dispose();
        }
        font.dispose();
        font.dispose();
        expectDrained(resources);
        expect(processFonts.registeredFaces, 1);
        expect(processFonts.pendingFaces, 0);
        expect(processFonts.uncertainFaces, 0);
        expect(processFonts.registeredBytes, admitted.bytes.length);
      }
    }, skip: skip ?? false);
  }

  test('resource refusal precedes malloc or outline Path creation', () {
    final denied = HarfBuzzResources(
      SceneResourceBudget(
        limits: {
          ...SceneResourceBudget.provisionalLimits,
          SceneResource.sourceBytes: 1,
        },
      ),
    );
    expect(
      () => HarfBuzzFont.open(admitted, bindings: bindings, resources: denied),
      throwsA(isA<SceneAdmissionException>()),
    );
    expect(denied.created, isEmpty);
    expectDrained(denied);
    final resources = HarfBuzzResources(
      SceneResourceBudget(
        limits: {
          ...SceneResourceBudget.provisionalLimits,
          SceneResource.vectorBytes: 1,
        },
      ),
    );
    final font = HarfBuzzFont.open(
      admitted,
      bindings: bindings,
      resources: resources,
    );
    try {
      expect(
        () => font.shapeRun('fi'),
        throwsA(isA<SceneAdmissionException>()),
      );
      expect(resources.created['outline'], isNull);
      expect(resources.created['buffer'], 2);
      expect(resources.destroyed['buffer'], 2);
    } finally {
      font.dispose();
      expectDrained(resources);
    }
  }, skip: skip ?? false);

  test('motion guards run before native or placement mutation', () {
    final resources = HarfBuzzResources(SceneResourceBudget());
    final font = HarfBuzzFont.open(
      admitted,
      bindings: bindings,
      resources: resources,
    );
    final run = font.shapeRun('fi');
    final before = resources.created;
    try {
      expect(
        () => ReaderWorkGuard.callback(() => HarfBuzzBindings()),
        throwsAssertionError,
      );
      expect(
        () => ReaderWorkGuard.callback(() => font.shapeRun('fi')),
        throwsAssertionError,
      );
      expect(
        () => ReaderWorkGuard.callback(() => run.place()),
        throwsAssertionError,
      );
      expect(
        () => ReaderWorkGuard.callback(() => font.dispose()),
        throwsAssertionError,
      );
      expect(resources.created, before);
    } finally {
      run.dispose();
      font.dispose();
      expectDrained(resources);
    }
  }, skip: skip ?? false);

  test('prepared placement survives font close and never reshapes', () {
    final resources = HarfBuzzResources(SceneResourceBudget());
    final font = HarfBuzzFont.open(
      admitted,
      bindings: bindings,
      resources: resources,
    );
    final run = font.shapeRun('fi e\u0301');
    HarfBuzzPlacedRun? placed;
    try {
      font.dispose();
      final buffers = resources.created['buffer'];
      placed = run.place(sourceOffset: 30);
      expect(placed.fragments.first.geometry.range.start, 30);
      expect(placed.fragments.last.geometry.range.end, 30 + run.text.length);
      expect(
        placed.fragments.last.geometry.range.end -
            placed.fragments.last.geometry.range.start,
        2,
      );
      final again = run.place(
        x: 50,
        textLength: 80,
        lengthAdjust: HarfBuzzLengthAdjust.spacingAndGlyphs,
      );
      try {
        expect(again.advance, closeTo(80, 1e-10));
      } finally {
        again.dispose();
      }
      expect(resources.created['buffer'], buffers);
      final token = PublicationCancellation()..cancel();
      expect(
        () => run.place(cancellation: token),
        throwsA(failure(HarfBuzzFailure.canceled)),
      );
      final path = HarfBuzzQuadraticPath(
        start: const ui.Offset(0, 0),
        control: const ui.Offset(50, 10),
        end: const ui.Offset(100, 0),
        resources: resources,
      );
      try {
        expect(
          () => run.place(
            path: path,
            startOffset: const HarfBuzzStartOffset.absolute(1000),
          ),
          throwsA(failure(HarfBuzzFailure.pathOverflow)),
        );
      } finally {
        path.dispose();
        path.dispose();
      }
    } finally {
      placed?.dispose();
      run.dispose();
      font.dispose();
      expectDrained(resources);
    }
  }, skip: skip ?? false);

  test('explicit features preserve whole-run advance semantics', () {
    final resources = HarfBuzzResources(SceneResourceBudget());
    final font = HarfBuzzFont.open(
      admitted,
      bindings: bindings,
      resources: resources,
    );
    final run = font.shapeRun('Ab fi', features: [HarfBuzzFeature('liga', 0)]);
    try {
      final ref = ((cases.first.$2['svgTexts'] as List).first as Map);
      expect(run.advance, (ref['ligatureControl'] as Map)['disabledLength']);
      expect(run.layoutClusters.length, 5);
    } finally {
      run.dispose();
      font.dispose();
      expectDrained(resources);
    }
  }, skip: skip ?? false);

  test(
    'font admission cancellation drains registration and keeps process charge',
    () async {
      final owner = ProcessFontBudget();
      final finish = Completer<void>(), drained = Completer<void>();
      final token = PublicationCancellation();
      final pending = HarfBuzzAdmittedFont.load(
        admitted.bytes,
        faceDescriptor: '400/normal',
        processFonts: owner,
        cancellation: token,
        register: (bytes, alias) async {
          await finish.future;
          await ui.loadFontFromList(bytes, fontFamily: alias);
          drained.complete();
        },
      );
      final rejected = expectLater(
        pending,
        throwsA(isA<ProcessFontLoadCanceled>()),
      );
      token.cancel();
      await rejected;
      expect(owner.pendingFaces, 1);
      expect(owner.bytes, admitted.bytes.length);
      finish.complete();
      await drained.future;
      await Future<void>.value();
      expect(owner.pendingFaces, 0);
      expect(owner.registeredFaces, 1);
      expect(owner.registeredBytes, admitted.bytes.length);
    },
    skip: skip ?? false,
  );

  test(
    'overlapping fonts keep the accepted font charged on replacement refusal',
    () {
      final resources = HarfBuzzResources(
        SceneResourceBudget(
          limits: {
            ...SceneResourceBudget.provisionalLimits,
            SceneResource.sourceBytes: 200000,
          },
        ),
      );
      final font = HarfBuzzFont.open(
        admitted,
        bindings: bindings,
        resources: resources,
      );
      final before = resources.budget.used;
      try {
        expect(
          () => HarfBuzzFont.open(
            admitted,
            bindings: bindings,
            resources: resources,
          ),
          throwsA(isA<SceneAdmissionException>()),
        );
        expect(resources.budget.used, before);
        final run = font.shapeRun('fi');
        run.dispose();
      } finally {
        font.dispose();
        expectDrained(resources);
      }
    },
    skip: skip ?? false,
  );

  test(
    'host binary pins match the probe manifest without importing probe code',
    () {
      final manifest = jsonDecode(
        File('tool/reader/harfbuzz_probe_manifest.json').readAsStringSync(),
      ) as Map;
      expect(HarfBuzzLibrarySource.windowsHashes, {
        ...Map<String, String>.from(manifest['dependenciesInLoadOrder'] as Map),
        manifest['library'] as String: manifest['librarySHA256'] as String,
      });
    },
  );

  test('missing prefixed process symbol is typed and eager', () {
    expect(
      () => HarfBuzzBindings(
        source: HarfBuzzLibrarySource.library(
          DynamicLibrary.process(),
          prefix: 'shiori_missing_test_',
        ),
      ),
      throwsA(
        failure(HarfBuzzFailure.missingSymbol).having(
          (e) => e.symbol,
          'symbol',
          'shiori_missing_test_hb_version_string',
        ),
      ),
    );
    expect(
      () => HarfBuzzLibrarySource.process(prefix: ''),
      throwsArgumentError,
    );
  });
  test('unavailable host chain is typed', () {
    expect(
      () => HarfBuzzBindings(
        source: HarfBuzzLibrarySource.windowsHost(
          directory: 'build/third_party/absent-harfbuzz-module-test',
        ),
      ),
      throwsA(failure(HarfBuzzFailure.libraryUnavailable)),
    );
  });

  test('canceled request starts no buffer or outline work', () {
    final resources = HarfBuzzResources(SceneResourceBudget());
    final font = HarfBuzzFont.open(
      admitted,
      bindings: bindings,
      resources: resources,
    );
    final before = resources.created;
    try {
      final token = PublicationCancellation()..cancel();
      expect(
        () => font.shapeRun('fi e\u0301', cancellation: token),
        throwsA(failure(HarfBuzzFailure.canceled)),
      );
      expect(resources.created, before);
    } finally {
      font.dispose();
      expectDrained(resources);
    }
  }, skip: skip ?? false);

  test('failed/missing glyph shaping drains partial owners', () {
    final resources = HarfBuzzResources(SceneResourceBudget());
    final font = HarfBuzzFont.open(
      admitted,
      bindings: bindings,
      resources: resources,
    );
    final before = resources.live;
    try {
      expect(
        () => font.shapeRun('\u{10ffff}'),
        throwsA(failure(HarfBuzzFailure.missingGlyph)),
      );
      expect(
        Map.fromEntries(resources.live.entries.where((e) => e.value != 0)),
        Map.fromEntries(before.entries.where((e) => e.value != 0)),
      );
      expect(
        () => font.shapeRun('abc', direction: HarfBuzzDirection.rtl),
        throwsA(failure(HarfBuzzFailure.unsupportedRun)),
      );
      expect(
        () => font.shapeRun('abc', maxGlyphs: 1),
        throwsA(failure(HarfBuzzFailure.invalidShaping)),
      );
    } finally {
      font.dispose();
      expectDrained(resources);
    }
    expect(
      () => font.shapeRun('abc'),
      throwsA(failure(HarfBuzzFailure.disposed)),
    );
  }, skip: skip ?? false);
}
