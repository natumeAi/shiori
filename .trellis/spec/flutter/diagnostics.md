# Diagnostic capture and export contract

S4a's implemented recognized-admission, demand/submission and native-loss
extension is specified in [Reader Admission Diagnostics](./reader-admission-diagnostics.md).
Its capability gates qualify the legacy timing reductions described below.

## SQLite self-check (S3 Phase A)

### 1. Scope / Trigger

The existing synthetic diagnostics screen exposes a probe-only SQLite check.
Diagnostics owns the direct `sqlite3` dependency usage; product/reader code
must not import it. This is a driver/packaging observation, not Phase B's
product database or migration owner.

### 2. Signatures

- `ProbeSqliteRepository(AppDirectories).run() -> Future<ProbeSqliteResult>`
  resolves Application Support, then uses `Isolate.run` with only its path
  and the root control port. All SQLite and scratch-file work runs off root.
- `ProbeSqliteResult.fromMetadata(Map<String, Object?>)` returns null for an
  absent extension and validates a present versioned result.

### 3. Contracts

`DiagnosticRecord.schemaVersion` remains 1. Its optional
`metadata.sqliteSelfCheck` is a JSON object with its own `schemaVersion: 1`:

- Required: UTC `checkedAt`, compile-time `buildId` / `buildNumber`,
  `packageVersion`, `packageVersionSource`, `ranOffRootIsolate`, `elapsedUs`
  (nonnegative), and `steps`.
- `steps` has exactly `open`, `commit`, `reopen`, `rollback`, `futureSchema`,
  `cleanup`: true means pass, false means fail, null means not reached.
- Runtime facts: nullable `libraryVersion`, `sourceId`, `journalMode`,
  `synchronous`; `compileOptions` is a sorted string list. Missing facts stay
  unavailable. `packageVersionSource=resolved_pubspec_lock_snapshot` marks
  the Dart package version snapshot, tested against the lockfile; it is not
  the native library version. Source ID/options do not prove bundle origin.
- Nullable `failure` contains only a bounded diagnostic code, never exception
  text, paths, SQL or stacks. Native-loader failures become failed evidence.

Each run creates a fresh `probe-sqlite-self-check/run-*` directory under
Application Support. It opens a fresh DB, commits DDL/data/user_version=1,
closes/reopens and reads it. A real duplicate-key failure rolls back earlier
DDL/data/version writes, checked before close and after reopen. A separate
version-2 DB is refused by a probe-only version guard before any write;
sentinel/version, exact file bytes and directory entries must stay unchanged.
Handles close in `finally`; scratch databases/sidecars are deleted in final
cleanup. The empty dedicated parent may remain. Documents holds exports only.

Capture/export and self-check are mutually disabled in the UI. Export merges
the latest result into the record; persisted results retain their original
build identity/time when reused. Running a check invalidates the displayed
export path; capture/stop or re-export is needed to persist the new result.
Old exports omit the extension and remain readable. Clipboard stays bounded
and retains the existing capture summary contract.

Hosted CI writes sorted `Runner.app/Frameworks` entries to `frameworks.txt`
and `provenance.json.packagedFrameworks` (with `packagedFrameworksFile`).
Each case-insensitive `*sqlite*.framework` uses its `CFBundleExecutable` for
the same arm64 slice verification as Flutter/App, including staged variants.
This adds no build mode or platform proof to Windows syntax validation.

### 4. Validation & Error Matrix

| Condition | Behavior |
| --- | --- |
| Unsupported/missing extension version, malformed shape | Saved-record load logs once and throws `ParseException` |
| Directory lookup / isolate spawn fails | Typed storage error; localized retry |
| SQL, native load, scratch I/O or invariant fails | Current step false; later steps null; cleanup attempted; failed result exportable |
| Cleanup fails | `cleanup=false`, bounded failure code; overall fail |
| Accidental root runner call | Refused before SQLite/disk access |

### 5. Good/Base/Bad Cases

Good: six true steps and runtime facts exported from the installed build.
Base: an old schema-1 record loads without SQLite evidence. Bad: treating a
Windows pass, source ID, or framework inventory as successful iPhone signing.

### 6. Tests Required

Use fake `AppDirectories` and fresh temp roots with actual SQLite: isolation,
transactions/refusal, version snapshot, cleanup/repeat runs, untouched marker
and no Documents access, failure evidence and export/old-record round-trip.
Widget tests cover running/disabled, saved/pass/fail, retry, export attachment,
disposal and 200% text scale. Run the full suite and Git Bash `bash -n`.

### 7. Wrong vs Correct

Wrong: `sqlite3.open` on root, scratch files in Documents, or silently promoting
host evidence into the hosted gate. Correct: probe repository + isolated
scratch run, explicit versioned facts, then authorized hosted build and actual
selected-route signing/install/run/export evidence before Phase B.

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
  intervals are separate. Stage distributions count `over8333Us`; interval
  distributions count `atLeast12500Us` (1.5 nominal periods, a missed vsync),
  because normal 120 Hz jitter sits just above 8333 µs and the first device
  run showed 1143 of 1794 intervals over 8333 µs with a P99 of 8457 µs.
  Near 120 Hz, low-cost near 60 Hz and mixed expensive
  stages have distinct classifications. They never establish physical display
  presentation. `totalSpan` is pipeline latency, never an FPS reciprocal.
- Application Support contains `probe-marker.txt` and `last-diagnostic.json`.
  Documents contains `shiori-diag-<BUILD_ID>-<runId>.json` exports only; safe
  components prevent traversal. Clipboard carries a bounded summary.
- Build identity uses `Env.buildId`; CI also injects `BUILD_NUMBER`. Flutter
  version and framework/engine revisions come from `FlutterVersion`
  (`package:flutter/services.dart`): the Flutter tool injects
  `FLUTTER_VERSION`, `FLUTTER_FRAMEWORK_REVISION` and
  `FLUTTER_ENGINE_REVISION` itself and rejects them in `--dart-define`.
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

## 8. Scenario: Reader Feasibility (S2)

### 8.1 Scope / Trigger

`lib/features/diagnostics/data/` composes the unchanged S1 recorder through
`ReaderProbeRecorder`. Probe UI/scenarios live in
`lib/features/diagnostics/presentation/reader_probe/`. The reader core owns its
injected sink interfaces and imports no diagnostics. The ordinary product entry
point never activates presentation sampling. Reader correctness and local
resource tests do not establish device performance or physical presentation.

### 8.2 Signatures

- `ReaderProbeRecorder.start({runId, bookSha256, fixtureId, scenarioId,
  repeatIndex, repeatCount, input, declarations, metadata, mode})`, `stop`,
  `completed`, `dispose`; implements `TurnTimingSink`, `TurnFrameSink`,
  `TurnTraceSink`, `TurnEvidenceSink` from reader `engine/motion/turn_session.dart`.
- `ReaderExportRepository.export(ReaderFeasibilityRecord) -> Future<String>`,
  static `decode(String)`, `fileName(record)`, `clipboard(record)`.
- `PresentationProbe.install() -> Future<PresentationReport>`,
  `start({runId, mode})`, `stop()`, `dispose()`; the method-channel adapter is
  `lib/features/diagnostics/data/method_channel_presentation_probe.dart`.
- Offline CLI: `dart run tool/diag/analyze_reader_export.dart [--strict] <export.json>...`.
  The analyzer deliberately imports no app code.

### 8.3 Contracts

#### Record, privacy and capture identity

`reader_feasibility_record.dart` defines the following top-level fields:

| Fields | Contract |
| --- | --- |
| `kind`, `schemaVersion` | `reader_feasibility`, integer `1`; model defaults are not persisted-schema validation |
| `bookSha256`, `fixtureId` | Lowercase 64-hex digest; bundled synthetic fixture ID or null for a user book |
| `scenarioId`, `repeatIndex`, `repeatCount`, `input` | R01-R11, one-based repeat, `manual_touch` or `synthetic_injected` |
| `engine` | Nested schema-v1 `DiagnosticRecord`: build/run identity, declarations, metadata, clocks, raw engine frames/motion, errors/overflow/omissions/aggregates |
| `readerEvents`, `layoutCosts`, `resources` | Bounded raw sample arrays, `Map<String, Object?>` entries |
| `presentation`, `aggregates`, `overflow`, `omissions` | Native report, app reader reduction, explicit loss counts and evidence omissions |

`ReaderProbeRecorder.start` rejects invalid digest/scenario/input/repeat identity.
R11 requires a user book (`fixtureId == null`), `manual_touch`, and one repeat.
Completion records `manualMinimumMet` from at least 50 retained acceptances for
R11; this marker alone does not establish correctness. Scripted R01-R10 use
frame-driven real gesture injection. R09 records controller/session lifecycle
simulation; it still needs actual OS background/foreground device evidence.

Reader event/cost/resource rings default to 16384 each. The reader screen
configures the nested engine recorder to 65536 samples and a ten-minute maximum,
retaining the S1 bounded drain. Do not apply the S1 synthetic 15-second/4096
defaults to reader runs. `overflow` keys are `events`, `layoutCosts`, `resources`,
`frames`, `motion`, `native`. `omissions` keys are `native`, `trailingTimingBatch`,
`manualMinimumMet`, `physicalPresentation`, `touchToPhoton`; trailing completeness
is never inferred from a timing batch arriving.

Export filename is `shiori-reader-<BUILD_ID>-<runId>.json`, built from
`record.engine.buildId/runId` with sanitized/truncated safe components, written
to Documents. Reader exports do not add a saved-record file to Application
Support. Clipboard uses the S1 4000-byte UTF-8 ceiling without splitting a code
point. User-placed EPUBs are intentional Documents inputs (`ProbeBookRepository`),
an S2 exception to S1's export-only Documents rule. Private book locators stay in
read closures; labels/metadata/serialization use digest identity.

Never export book text, titles, user filenames, assertion-bearing CFIs, raw
layout keys or private paths. `accepted.destination.pageIdentity` is SHA-256 of
the internal page identity; it is not the original string. Book I/O warnings and
platform-channel omissions exclude raw exception messages/details. This privacy
boundary also applies to task evidence and clipboard summaries.

Turn events contain `sequence`, `event`, `monotonicUs`, `turnClockMs`, `generation`,
`activeGeneration`, `captureEpoch`, `queueDepth`, `inputId`; acceptance adds
`destination` with `sectionIndex`, `pageIndex`, `layoutGeneration`, hashed
`pageIdentity`. `firstMotionSubmission` instead carries `sequence`, `event`,
`captureEpoch`, `monotonicUs`, `generation`, `frameNumber`, `inputId`.
Section preparation events carry `section`, `cacheHit`, sequence/time and
`sectionPreparationStart`/`sectionPreparationEnd`.

Input objects map to opaque integer IDs. New captures reset numbering; known old
objects retain their original capture epoch. Join by `(captureEpoch, inputId)`
within one export, never by generation or across exports. Epoch-less legacy
events remain separate from identified epochs. First-submission deduplication
also uses epoch plus ID. The surface post-frame callback checks owner, generation,
mounted state and `TurnFrameSink.frameEpoch` before publishing an engine ID.

#### Correctness and resources

`engine.metadata.readerCorrectnessVersion: 1` and integer `captureEpoch` declare
correctness capability. `inputCommitted` marks the navigation handoff after
settlement; rebound/boundary/no-turn inputs do not commit. Require exactly one
acceptance per explicit commit, none before a commit, zero proof failures and
zero stale acceptance publications. `staleCallbackRejected` is safe rejection,
reported separately. A foreign epoch, mismatched active generation, invalidated
input or rejected generation publishing acceptance fails. Missing required
fields/capability and event loss cannot establish a passing absence claim.

Layout samples: `monotonicUs`, `section`, `layoutUs`, `codeUnits`, `lines`,
`sectionPageCount`. Resource samples: `monotonicUs`, `liveSurfaces`, `pictureBytes`,
`imageBytes`, `rssBytes` (`ProcessInfo.currentRss` in Dart). The active pool/cache
declares `engine.metadata.resourceCaps`: `liveSurfaceCap`, `liveSurfaceReserve`,
`pictureCacheBytes`, `imageCacheBytes`; never copy guessed caps into an export.

Resource analysis reports first/last/max and ordinary-least-squares slope per
recorder second. Passing boundedness requires at least 100 accepted turns,
nonoverflowed events/resources, maxima within surface cap plus reserve and byte
caps, positive first RSS, and two distinct sample times. Both endpoint RSS growth
and slope projected over the capture must be within
`ReaderGates.maximumRssGrowthFraction` in `tool/diag/reader_export_data.dart`
(currently 5% of first RSS). Observed breaches fail even with partial evidence;
missing evidence stays unavailable. This implemented threshold is an observational
bound, not a numerical requirement from design §8 or proof of indefinite/per-cycle
stability. R10 supplies alternating-turn/jump coverage; telemetry does not certify
direction, cycle completion or warm-up by itself.

#### Native presentation probe and evidence levels

Channel: `io.github.natumeai.shiori/presentation_probe`, registered in
`ios/Runner/AppDelegate.swift`. Registration/construction allocates no sampling
buffers, inspects no views and installs no hooks. Explicit `install` allocates
the bounded buffer/shared callback and reads inventory; `start` lazily installs
the selected hook after checking the actual layer. Do not claim hooks activate
at registration or that `install` itself starts a capture.

| Mode | Requirement and raw samples | `evidence` |
| --- | --- | --- |
| `inventory` | Layer/flag, max FPS, power/thermal/OS metadata | `metadata` |
| `a1` | Default `FlutterMetalLayer`; `setContents:` timestamps | `layer_commit_cadence` |
| `a2` | A1 plus auxiliary `CADisplayLink` timestamp/targetTimestamp | `layer_commit_cadence_per_display_period` |
| `b` | Exact `CAMetalLayer` and explicit `FLTUseFlutterMetalLayer=false`; drawable ID and `presentedTime` | `system_drawable_presentation_non_product_path` |

Compare A1/A2 for observer perturbation: the auxiliary display link can affect
cadence. B describes only the alternate build path; it does not establish the
product path's behavior. Neither engine frame identity, layer submission nor
system drawable time establishes physical scan-out or touch-to-photon latency.
Native seconds remain in a separate clock domain; never infer a Dart epoch.
Reported display refresh-rate metadata is not measured effective cadence.

`PresentationReport` exports `available`, `evidence`, `omission`, `inventory`,
`samples`, `overflow`, `contentionDrops`, optional nonzero `unmatchedCallbacks`,
`clock`, `physicalPresentation`, `touchToPhoton`; the reader recorder adds `mode`.
Missing `unmatchedCallbacks` decodes as zero. `overflow` includes evictions plus
contention loss; `contentionDrops` is a subset, not another amount to add.
Unmatched callbacks are separate. Native rings have capacity 16384; callback
paths try-lock and count contention instead of blocking. `dispose` stops capture
and invalidates the auxiliary display link, retaining the bounded native buffer/
shared callback for permanent hooks and late callbacks. Do not promise swizzle
removal or buffer deallocation on dispose.

`presentation_payload.dart` validates/whitelists inventory keys: `layerClass`,
`FLTUseFlutterMetalLayer` (nullable bool), `maximumFramesPerSecond`, `lowPowerMode`,
`thermalState`, `iosVersion`, `ringCapacity`. Raw sample shapes are:

- `layer_commit`: `kind`, `timestamp` (A1/A2 only).
- `display_link`: `kind`, `timestamp`, `targetTimestamp` (A2 only).
- `drawable`: `kind`, `timestamp`, `presentedTime`, decimal-string `drawableId`
  within unsigned 64-bit range (B only).

Times must be finite/nonnegative, counters nonnegative, contention <= overflow,
and available streams nonempty (A2 requires both commit and display-link data).
Native B reports unavailable if no positive presented time arrives by stop.
Zero means no presentation observed by stop, potentially pending/lost callbacks.
The analyzer bins only recorded, positive, nonoverlapping A2 periods as
`[timestamp, targetTimestamp)`: zero, one or at least two commits, plus commits
outside recorded periods. Missing periods are not synthesized.

Swift compilation, runtime hook/ABI behavior and actual A1/A2/B data require
CI/device validation. Source inspection and Dart adapter tests do not prove them.
The S2 spike has one device iteration plus at most one fix iteration; unavailable
results stay explicitly unverified with the omission, not substituted evidence.

#### Independent analyzer

`tool/diag/reader_export_analysis.dart` recomputes both app reader and nested
engine aggregates from raw samples, using a symmetric key/value comparison.
Never import app reducers into this tool or trust exported aggregate values.
S1 engine percentiles use `ceil((n-1)*p)`; reader distributions use
`ceil(n*p)-1`. Preserve both conventions. Stage budgets, warm-submission P95,
stall threshold, repeat/turn minima and RSS rule live in `ReaderGates`
(`tool/diag/reader_export_data.dart`).

Report UI and raster budgets separately; use nonnegative frame-number joins and
consecutive matched IDs for engine cadence. Legacy warm aggregates retain input
receipt to first motion submission, joined by epoch/ID. The current acceptance
gate requires versioned recognized-admission evidence as specified in Reader
Admission Diagnostics; a legacy receipt proxy cannot satisfy it. Report queue
wait, cold input/section preparation,
paragraph layout, static fallback/rate, motion-window stage/interval/submission
stalls, correctness, resource trends and native cadence separately. Unknown
schemas and malformed required data are rejected; incomplete streams, open
windows, broken adjacency, unavailable IDs and overflow qualify absence claims.
Definite observed failures still fail. Repeat summaries do not invent missing
repeats. Do not infer device acceptance from a matching synthetic export.

CLI exit codes: `64` usage, `65` invalid file/JSON/schema/input, `1` aggregate
mismatch with `--strict`, otherwise `0`. Failed measurement rows do not change
exit status when aggregates match. Always read gate rows, omissions and loss
counters in addition to the process result.

### 8.4 Validation & Error Matrix

| Condition | Behavior |
| --- | --- |
| Invalid capture identity / busy recorder | `ArgumentError` / `StateError` before starting a new capture |
| Unsupported top-level or nested engine schema | Repository `decode` throws `ParseException`; analyzer refuses with invalid-input status |
| Export I/O failure | Sanitized warning, typed `ParseException`; no success-looking export |
| Missing plugin / platform channel error | Mode-specific unavailable report with omission; omit native exception details |
| Malformed native report | Typed `ParseException`; capture completion errors rather than stranding the drain; scripted observer cancels the scenario |
| Missing correctness capability/fields/caps or insufficient samples | Gate unavailable with reason; never fill from counters/aggregate guesses |
| Safe stale rejection | Count separately; no correctness failure just for rejection |
| Duplicate/uncommitted/stale acceptance, proof failure, observed resource breach | Failed gate, including on partial evidence |
| Native stream absent or wrong layer/flag | Unavailable with reason; no stronger evidence label |
| Late post-frame/native completion after restart/dispose | Owner/generation/epoch guards suppress publication into another capture |

### 8.5 Good/Base/Bad Cases

- Good: raw samples independently reproduce app aggregates, every committed
  input has one hashed destination, and unavailable native evidence is explicit.
- Base: legacy v1 export still reduces available timing data, while missing
  correctness/capability fields leave those gates unavailable.
- Bad: exit 0 treated as device PASS, epoch-less/old input joined to a new input
  with the same number, contention counted twice, or B labeled product scan-out.

### 8.6 Tests Required

Keep S1 tests intact. Inject `ProbeClock`, `FrameSource`, presentation probe,
`TurnClock`, scenario frames and temporary directories. Test restart/dispose and
late callbacks, epoch/ID reuse and deduplication, schema rejection, bounded rings,
safe filenames/clipboard, sanitized I/O and native failures, stream validation,
native loss counters and A2 period boundaries. Maintain synthetic export parity
plus negative correctness/resource/overflow/missing-data fixtures under
`test/fixtures/reader/exports/`. Their regeneration path is in
[Testing](./testing.md). Widget tests cover post-frame submission identity,
scenario cancellation and typed stop failure, lifecycle cleanup and ordinary
product isolation (`test/app/product_presentation_isolation_test.dart`).

### 8.7 Wrong vs Correct

Wrong: join on `inputId` alone, use `proofPassed` as a commit, or report "120 Hz
physical presentation verified" from engine/layer/B intervals.

Correct: join `(captureEpoch, inputId)` within one export, replay explicit
`inputCommitted`/`accepted.destination` evidence, report each recorded evidence
level and keep physical presentation/touch-to-photon unverified.
