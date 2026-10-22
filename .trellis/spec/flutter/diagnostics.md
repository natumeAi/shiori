# Diagnostic capture and export contract

## 1. Scope / Trigger

Applies to `core/diagnostics`, `core/storage`, diagnostics-feature file
repositories and the explicit `main_probe.dart` entry point. This is a local
synthetic feasibility probe; the ordinary app entry point/routes stay usable.
The storage-free recorder is reusable by later reader work.
The probe root uses `retryNetworkErrors`, like the ordinary entry point, so
file/parse failures appear immediately instead of entering Riverpod retries.

## 2. Signatures

- `AppDirectories.applicationSupport()` / `.documents()` return
  `Future<Directory>`; inject this boundary in file-repository tests.
- `DirectoryAccess.resolve(lookup)` maps known directory/plugin lookup failures
  to a logged `ParseException` before repositories perform file I/O.
- `ProbeClock.utcNow()` and `monotonicUs` keep wall and elapsed domains separate.
- `FrameSource.start(void Function(List<FrameTiming>))` / `.stop()` own the
  engine subscription. `SchedulerFrameSource` lives in its own adapter file;
  `SystemProbeClock` likewise implements the separate `ProbeClock` interface.
- `DiagnosticRecorder.start(runId:, declarations:, metadata:)`,
  `.motion(frameNumber:, schedulerUs:, rawSchedulerUs:, progress:)`, `.stop(reason:)`,
  `.completed`, `.dispose()` form the capture lifecycle.
- `ProbeMarkerRepository.load()` / `.save(String)` use Application Support.
- `DiagnosticExportRepository.export(DiagnosticRecord)` returns the written
  Documents file path; `.loadLast()` reads the Application Support record;
  `.fileName(record)` provides the safe export name.
- `DiagnosticSummary.aggregate(frames, motionFrameNumbers)` runs after
  motion; `.clipboard(record, fileName)` returns at most 4000 UTF-8 bytes.
- `DiagnosticsScreen(frameNumberForTesting: reader)` provides a narrow test
  seam for the read-only platform frame data. Production omits it and reads
  `PlatformDispatcher.instance.frameData.frameNumber` in the post-frame phase.

## 3. Contracts

- Versioned freezed `DiagnosticRecord` uses `schemaVersion=1`,
  `scenarioId=synthetic_transform`, build/run identities, UTC start/stop,
  monotonic bounds, declarations, environment/viewport metadata, clock-domain
  descriptions, raw frames/motion, overflow/omissions, drain count, errors and
  aggregates. JSON boundaries use `Map<String, Object?>`.
- Each user declaration is `on`, `off` or `unknown`; model name is explicitly
  user-provided. Unknown automatic metadata stays unknown, never guessed.
- Default bounds: 4096 frame samples, 4096 motion samples, 15-second capture,
  1200-ms drain. Rings evict oldest entries and increment overflow counts.
- Stop transitions recording → draining → finished, retaining late timing
  batches during the bounded drain. Flutter has no public completeness flush;
  `incompleteTrailingBatch=true` remains explicit even when a batch arrives.
- `MotionSample.frameNumber` records the engine identity, not an inferred
  timestamp offset. The ticker captures adjusted/raw scheduler timestamps and
  progress, then a same-frame `addPostFrameCallback` reads
  `PlatformDispatcher.instance.frameData.frameNumber` and records the sample.
  Guard capture generation, mounted state and recorder phase so pending
  callbacks cannot publish into another capture or a disposed recorder.
- Raw subscription frames may precede/follow the motion window. Match
  nonnegative `FrameSample.frameNumber` with nonnegative motion frame numbers
  for UI/raster aggregation. A negative number is unavailable, never a match,
  and adds an explicit bounded error to the export. Cadence uses `vsyncUs`
  deltas only for consecutive engine frame numbers (`next = previous + 1`)
  present in both streams; an engine-number gap or missing motion sample
  breaks adjacency instead of fabricating a slower cadence.
- Raw scheduler timestamps describe vsync **target** time; timing `vsyncUs`
  describes vsync **start**. They can differ by one display period. Never
  correlate by timestamp equality or assume a fixed offset. Callback receipt,
  Stopwatch and UTC epochs are not equated. A frame-number match is engine
  identity evidence, not evidence of physical presentation.
- UI/raster distributions and consecutive correlated engine `vsyncStart`
  intervals are separate. Near 120 Hz, low-cost near 60 Hz and mixed expensive
  stages have distinct classifications. They never establish physical display
  presentation. `totalSpan` is pipeline latency, never an FPS reciprocal.
- Application Support contains `probe-marker.txt` and `last-diagnostic.json`.
  Documents contains `shiori-diag-<BUILD_ID>-<runId>.json` exports only; safe
  components prevent traversal. Clipboard carries a bounded summary.
- Build identity uses `Env.buildId`; CI also injects `BUILD_NUMBER`,
  `FLUTTER_VERSION`, `FLUTTER_FRAMEWORK_REVISION`, `FLUTTER_ENGINE_REVISION`.
  Artifact provenance and the app's compile-time metadata must match.

## 4. Validation & Error Matrix

| Condition | Behavior |
| --- | --- |
| Invalid capture bounds | `ArgumentError` before subscribing |
| Start while recording/draining/disposed | `StateError` |
| Repeated stop | Same completion, no second drain |
| Ring full | Evict oldest, increment corresponding overflow |
| No engine data/motion/correlation | Explicit unavailable error/metadata and partial record |
| Negative engine or motion frame number | Exclude from matching/cadence; report `engine_frame_number_unavailable` / `motion_frame_number_unavailable` once per run, even if its raw sample is later evicted |
| No valid engine/motion ID matches | Report `engine_motion_frame_number_correlation_unavailable`; correlation status stays unavailable |
| Late timing after finish/dispose | Ignore; subscription removed |
| Dispose during capture/drain | Cancel timers, unsubscribe, release samples, resolve pending completion safely |
| Missing marker / saved record | Empty marker / null record (first-run state) |
| File I/O or malformed persisted data | Repository logs once, throws typed `ParseException`; diagnostics UI uses its local-storage message and retry |
| Persisted schema version missing, non-integer or unsupported | Reject as `ParseException`; generated model defaults do not establish persisted compatibility |
| Directory/plugin unavailable | `DirectoryAccess` logs once and maps known path-provider/platform exceptions to `ParseException` |
| Export error | Show localized failure; allow review/retry, never success-looking output |

## 5. Good/Base/Bad Cases

- Good: declared limiter-off capture has frame-number-correlated engine data,
  exports raw samples, reports engine cadence and incomplete trailing state.
- Base: local build without CI defines shows `local` identity and unavailable
  SDK/build-number fields. Empty timing input yields useful partial evidence.
- Bad: using callback arrival as presentation, hiding overflows, placing a
  marker in shared Documents, or equating a synthetic run with reader acceptance.

## 6. Tests Required

Inject clocks, timing sources and temporary directories. Assert ring bounds,
overflow counts, stop/drain/dispose, late reports, repeated captures,
serialization round-trip and unknown declarations. Fixture tests distinguish
120-Hz, 60-Hz-cap and mixed-over-budget intervals. Set fixture raw scheduler
target timestamps to vsync start plus a period with matching frame numbers;
assert exact matched counts/costs when same-frame timestamps differ. Accidental
equality with another frame's start must not shift the association.
Test frame-number gaps, missing motion samples and unavailable negative IDs;
none may fabricate cadence. Widget tests assert the frame-number reader runs
post-frame, sees the current rather than previous ID, and queued callbacks
are safe after stop/dispose/restart. Check UTF-8 summary size, safe filenames, marker
reload, saved-record round-trip and repository I/O/parse failures. Widget tests
exercise declarations, capture controls, export/copy and failure states with
localization, plus lifecycle cleanup and ordinary app smoke coverage.

## 7. Wrong vs Correct

Wrong: match `frame.vsyncUs == motion.rawSchedulerUs`, read engine frame data
inside the ticker, or compute `fps = 1000000 / frame.totalSpan.inMicroseconds`.

Correct: record same-frame post-frame engine IDs, join timing/motion on valid
IDs, retain stage durations as costs, and derive engine intervals from
consecutive matched frame numbers. Report scope/omissions and mark physical
presentation unverified.

### SDK evidence for the correlation boundary

Verified in local Flutter 3.47.7: `engine/src/flutter/shell/common/animator.cc`
passes `GetVsyncTargetTime()` and the recorder frame number to
`OnAnimatorBeginFrame`. `bin/cache/pkg/sky_engine/lib/ui/hooks.dart` calls
`_beginFrame(microseconds)` before `_updateFrameData(frameNumber)`; the ticker
therefore sees the previous ID. Same-frame post-frame callbacks see the updated
ID. `ui/window.dart` defines `FrameData.frameNumber` with unavailable default
`-1`. These source facts explain the test contract; device results stay pending.
