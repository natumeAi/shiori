---
name: flutter-testing
description: Unit/widget tests, reader oracle and export parity, private-input switches and injected time/frame seams
paths:
  - test/**
  - integration_test/**
---

# Testing

> Required: unit tests for every repository and controller, widget tests for
> key screens. Mocks with `mocktail`. No real network in any test.

---

## What Must Be Tested

| Code | Test type | Minimum coverage |
|---|---|---|
| `*_repository.dart` | unit | each public method: success + each `AppException` it can raise |
| `*_controller.dart` | unit (`ProviderContainer.test`) | `build` success and error; each mutation method |
| Key screens (list, detail, forms) | widget | loading, data, empty, and error states; main interactions |
| `core/**` helpers (`guardDio`, `errorMessage`) | unit | every branch |
| Pure layout widgets | optional | |

Integration tests (`integration_test/`) and golden tests are not required yet.

---

## Layout

Tests mirror `lib/`: `lib/features/diagnostics/data/reader_export_repository.dart`
-> `test/features/diagnostics/data/reader_export_repository_test.dart`.

```text
test/
  helpers/
    mocks.dart              # shared mocktail mocks (MockDio, MockBookmarkRepository)
    pump_app.dart           # WidgetTester.pumpApp extension
    provider_exception.dart # providerException(error): a real Riverpod ProviderException
  fixtures/                 # JSON responses: bookmarks_list.json
  app/...                   # app smoke test (pumps ShioriApp)
  features/...              # mirrors lib/features
  core/...                  # mirrors lib/core
```

Test files import `lib/` code with `package:shiori/...` and helpers with a
relative path (`import '../../helpers/pump_app.dart';`); `test/` has no
`package:` URI, and `always_use_package_imports` only governs `lib/`.

`ProviderException`'s constructor is `@internal`. To test code that unwraps
it, use `providerException(error)` from `test/helpers/provider_exception.dart`,
which obtains one through the public `AsyncValue.requireValue` path.

---

## Repository Tests

Mock `Dio` and assert on returned models / thrown `AppException` types.

```dart
import '../../../helpers/mocks.dart'; // class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late BookmarkRepository repository;

  setUp(() {
    dio = MockDio();
    repository = BookmarkRepository(dio);
  });

  test('fetchBookmarks maps a connection error to NetworkException', () {
    when(() => dio.get<List<Object?>>(any(), queryParameters: any(named: 'queryParameters')))
        .thenThrow(DioException.connectionError(
          requestOptions: RequestOptions(path: '/bookmarks'),
          reason: 'offline',
        ));

    expect(repository.fetchBookmarks(), throwsA(isA<NetworkException>()));
  });
}
```

---

## Controller Tests

One fresh container per test; override the repository; keep a listener
alive on auto-dispose providers while awaiting.

```dart
test('build loads bookmarks', () async {
  final repository = MockBookmarkRepository();
  when(() => repository.fetchBookmarks()).thenAnswer((_) async => [bookmark]);

  final container = ProviderContainer.test(
    overrides: [bookmarkRepositoryProvider.overrideWith((ref) => repository)],
    retry: (_, _) => null,
  );
  container.listen(bookmarkListControllerProvider, (_, _) {});

  expect(await container.read(bookmarkListControllerProvider.future), [bookmark]);
});
```

- Always pass `retry: (_, _) => null` so a failing provider errors
  immediately instead of scheduling retry timers.
- Never share a container between tests.

---

## Widget Tests

Use the `pumpApp` helper so every screen gets a `ProviderScope`, the theme,
and localizations:

```dart
// test/helpers/pump_app.dart
import 'package:flutter_riverpod/misc.dart'; // Override is not in flutter_riverpod.dart

extension PumpApp on WidgetTester {
  Future<void> pumpApp(Widget widget, {List<Override> overrides = const []}) {
    return pumpWidget(
      ProviderScope(
        overrides: overrides,
        retry: (_, _) => null,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: widget,
        ),
      ),
    );
  }
}
```

- Find text through the generated strings, not literals:
  `final l10n = lookupAppLocalizations(const Locale('zh'));` then
  `find.text(l10n.bookmarksTitle)`.
- Override the controller's repository (not the controller itself) so the
  real controller logic runs.
- For the loading state, return a `Completer().future` that never completes;
  for data/error, `await tester.pumpAndSettle()`.
- To flush a `Timer(Duration.zero)` in a widget test, use
  `await tester.pump(Duration.zero)` before awaiting its completion. A bare
  `pump()` flushes microtasks without explicitly advancing the fake clock and
  can leave a recorder's zero-duration drain pending indefinitely.

---

## Commands

```bash
flutter test                                    # all
flutter test test/features/reader               # one feature
flutter test --name "maps a connection error"   # one test
```

---

## Reader Oracle and Interoperability

`test/fixtures/reader/oracle/` commits authoritative WebKit vectors, summary,
Unicode ranges and `cross-engine-differences.json`. The oracle runs pinned
Foliate and owner-authorized lan-reader logic in real WebKit and Chromium;
Chromium is a cross-check and its full vectors stay in ignored
`build/oracle-chromium/`. This is development tooling, not JavaScript in the app.
`tool/oracle/README.md`, `package.json` and `package-lock.json` define provenance,
versions and exact commands. Regenerate from `tool/oracle/`:

```powershell
npm ci
npx playwright install webkit chromium
npm run check-reference
npm run build-fixtures
npm run vectors
npm run verify-vectors
```

These are regeneration instructions, not a requirement to download tools or
rerun extraction during a documentation-only pass. `check-reference` uses the
pinned commit through read-only `git show`; `LAN_READER_DIR` overrides its
reference checkout location. The reference checkout must never be modified.

Fixture sources live under `tool/oracle/fixtures/`; the builder emits synthetic
EPUBs and a hashed manifest under `assets/reader_fixtures/`. Generation must be
reproducible across repeated clean runs/timezones. Preserve sorted JSON content,
compact vector formatting, stable resource aliases and scoped `.gitattributes`.
Do not commit full Chromium vectors, private vectors, timestamps, local paths
or random Blob IDs. Only normalize CRLF when comparing text generated source;
ZIP/provenance/hash comparisons that promise exact bytes stay byte-exact.

Assertions cover package/spine/TOC and real OPF CFI bases, parser selection,
inert projection/kinds/namespaces, canonical v1 length/signature/mappings,
CFI grammar/serialization/comparison and resolved nodes/UTF-16 offsets.
`source_edge_test.dart` under `test/features/reader/data/epub/` pins the known
HTML noscript difference and explicitly skips only its affected sampled nodes;
never broaden that exclusion to hide a mismatch.

Layout/anchor conservation uses `gateSettings` from
`test/features/reader/engine/layout/layout_test_support.dart`: defaults and the
two named non-default settings there. Keep all three in every-page round-trip
and conservation coverage rather than duplicating a drifting settings table.

Regenerate the committed Dart Unicode table from repository root with
`dart run tool/reader/generate_unicode_table.dart`. The canonical table test
regenerates in memory and compares with CRLF normalized. The browser exposes no
Unicode database version; test the complete pinned ranges/engine provenance.

Source-edge EPUB/vector maintenance is separate: run
`python tool/reader/source_edge/make_edge_epubs.py build`, then follow
`tool/reader/source_edge/README.md` to extract/trim WebKit vectors with
`vectors-local` and `make_edge_epubs.py trim <oracle-webkit.json> <name>`.
Back up the private directory's summary/Unicode/difference files before that
extraction overwrites them. The builder does not regenerate
`test/fixtures/reader/source_edge/manifest.json`; review/update its byte/hash
entries deliberately when changing those two allowed payloads. Do not expand
the two-file privacy exemption.

Native data-CFI interop (repository root; browser command from `tool/oracle/`):

```powershell
dart run tool/reader/native_cfi_interop.dart export build/interop
# In tool/oracle/:
npm run resolve -- ../../build/interop/cfi-list.json
# Back at repository root:
dart run tool/reader/native_cfi_interop.dart compare build/interop
```

This checks native exports against both engines, separately from `flutter test`.
`resolve` writes `build/oracle-local/resolve-results.json`; the compare tool reads
that output. Require identical native/browser section/node/offset results.

## Font and Fixed-Layout Vectors

`test/fixtures/reader/fonts/` holds committed Brotli/WOFF2 vectors for the
pure-Dart decoder; tests use only the Dart SDK and committed bytes, never a
compressor or native Brotli library. Maintenance commands (repository root):

```bash
dart run tool/fonts/brotli_dictionary.dart --check   # vendored dictionary + generated Dart file
flutter test test/features/reader/engine/layout       # Brotli, WOFF, WOFF2, admission, HarfBuzz parity
```

Regenerating vectors needs Python 3 and a Brotli CLI (`generate_brotli_vectors.py`,
`generate_dictionary_vectors.py`, `generate_woff2.py`; see the directory
`README.md`) and must reproduce byte-identical files. Fixed-layout assertions
sample alpha through `GeometryAlphaFootprint.alphaAt`, never absolute strides,
and compare native readback against independent controls; the harness reports
run with `flutter test test/tool/reader`. Contracts:
[Reader Font Conversion](./reader-font-conversion.md),
[Reader Fixed Layout](./reader-fixed-layout.md). Host passes (Windows HarfBuzz,
Ahem) are not device raster, font or timing evidence.

## Local-Only Reader Tests and Switches

| Switch / input | Behavior |
| --- | --- |
| `SHIORI_LOCAL_EPUB_DIR` | Existing extra private EPUB directory, alongside the tests' read-only default `D:/Projects/lan-reader/docs`; no filename list is committed |
| `build/oracle-local/` plus an existing private EPUB directory | Required for VM-only local data, layout and support tests; tests skip when either is absent |
| `npm run vectors-local -- <epub>...` (in `tool/oracle/`) | Reads books in place, stores digest-identified vectors under ignored `build/oracle-local/`; these files contain private text |
| `SHIORI_NATIVE_CFI_OUT` | Opts `test/features/reader/engine/pagination/native_cfi_export_test.dart` into writing synthetic page anchors; unset means skipped |
| `REGENERATE_READER_EXPORTS=1` | Explicitly rewrites committed synthetic analyzer exports through the parity test below; ordinary tests never rewrite fixtures |

Local-book suites are `data/epub/local_books_test.dart`,
`engine/pagination/local_books_layout_test.dart` and
`engine/support/local_books_support_test.dart` under `test/features/reader/`.
Output must use digests, indices, coordinates and counts, never prose, titles or
user filenames. A missing EPUB for an existing digest vector is a failure once
the data test runs, not permission to skip that comparison.

The optional page-anchor export test writes `native-cfis.json` and
`native-cfi-expected.json` to the chosen directory at all three gate settings.
Feed `native-cfis.json` to `npm run resolve -- <path>` from `tool/oracle/` and
compare returned endpoints with the expected file. Keep generated interop
outputs in ignored build directories; do not confuse this page-anchor path with
the data-CFI CLI's `cfi-list.json`/`compare` path.

## Synthetic Reader Exports and Independent Analyzer

`test/fixtures/reader/exports/` contains twelve deterministic synthetic records,
not device captures. Raw samples originate in
`test/helpers/reader_analyzer_exports.dart`, which constructs production records
and app aggregates without importing analyzer code. The ordinary parity test
compares committed JSON structurally with fresh app serialization, then checks
independent raw-sample recomputation. Regenerate only when intentionally changing
the app export contract (repository root, PowerShell):

```powershell
$env:REGENERATE_READER_EXPORTS = '1'
try {
  flutter test test/tool/diag/reader_export_parity_test.dart --reporter expanded
} finally {
  Remove-Item Env:REGENERATE_READER_EXPORTS
}
```

Preserve passing/budget-failing A1/A2/B cases, negative/missing frame IDs,
overflow, unknown schema, legacy unavailable resources, bounded 100-turn data,
duplicate acceptance and cap-breach fixtures. Negative measurement fixtures
must still have matching aggregates: parity alone cannot establish acceptance.
`test/tool/diag/` asserts epoch/ID correlation, both percentile conventions,
correctness/resource failures, unavailable evidence, CLI exits and privacy.
`test/tool/ci/check_reader_fixtures_test.dart` tests hashed manifests, exact
source-edge exemptions, tracked ignored EPUBs, byte/hash drift and extra files.
See [Diagnostics](./diagnostics.md) for raw fields and gate semantics.

## Injected Time, Frames and Host Evidence

- Inject `ProbeClock` / `FrameSource` for recorder tests and temporary
  `AppDirectories` for file tests. Use fake timing batches rather than a live
  platform subscription.
- Motion tests use `TestTurnClock` in
  `test/features/reader/engine/motion/motion_test_support.dart`, explicitly
  advancing milliseconds, posted control tasks and timers. Assert queue,
  cancellation, generations and accepted-turn preservation without sleeping.
- `ScenarioFrames.next()` is injected into `ReaderScenarioRunner`; tests supply
  deterministic frames and an injected pointer sink. Production uses actual
  scheduler frames, at most one move per actual frame with no catch-up. Nominal
  cadence does not manufacture a 120 Hz device schedule.
- Use `frameNumberForTesting` on `PreparedReader`/S1 `DiagnosticsScreen` to assert
  same-frame post-frame submission, owner/generation/epoch rejection and disposal.
  `PreparationControl` also accepts a yielder; cancellation checks occur between
  blocks/images, not within synchronous paragraph layout.
- Host Ahem layout timings, Windows browser vectors, widget animation tests and
  synthetic exports establish deterministic behavior only. Timings are indicative;
  iPhone budgets, fonts, OS lifecycle delivery, Swift hooks and presentation
  remain device/CI evidence. Never promote a host pass into NC7-NC9 acceptance.

---

## Forbidden

- Real HTTP calls (no live `Dio`, no hitting dev servers).
- `mockito` / `@GenerateMocks`. Use `mocktail`.
- `sleep` / fixed `Future.delayed` waits. Use `pump`, `pumpAndSettle`, or completers.
- Asserting on `error.toString()`. Assert on exception types or l10n text.
