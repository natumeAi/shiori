# Design: free iPhone delivery and diagnostic probe

Status: proposal awaiting final plan approval, revised after plan review on
2026-10-22. Follow the parent requirements and `research/ios-device-workflow.md`
under the parent task.

## Build path

Windows source/tests → user-confirmed push to a build branch of the public
repository → GitHub Actions standard macOS runner → unsigned release device
`.app` → IPA container artifact → local Windows signing → iPhone home-screen
launch.

Primary host: GitHub Actions on `natumeAi/shiori`, which is already public, so
standard hosted runners cost nothing and need no third-party account. Pin an
explicit macOS runner image label (not `macos-latest`), select Xcode
explicitly, install Flutter 3.47.7 stable through a pinned setup action, and
fail the job if `flutter --version` does not report framework revision
`abaf9c523780a608bd46686fd5e53740a07077f8`. Record macOS/Xcode/Flutter/engine
versions in the job summary and artifact metadata. No build requires NAS
access, actual novel files or any secret. Use only generated probe content.

Workflow shape (`.github/workflows/ios-unsigned.yml`):

- Triggers: `workflow_dispatch`, plus `push` to `ios-build/**` branches so a
  build can start before the workflow file exists on the default branch.
  No `pull_request`/`pull_request_target`, no schedule, no `master` push
  trigger.
- `permissions: contents: read`; third-party actions pinned to commit SHAs;
  one concurrency group per ref; short artifact retention (for example
  14 days).
- The job calls `tool/ci/build_ios_unsigned.sh`, which owns build, bundle
  validation and packaging, so the Codemagic fallback reuses the same logic
  instead of duplicating it.

Codemagic fallback: only if the GitHub route is blocked (toolchain/runner
unavailable, policy change) or the repository becomes private. Then add a
manually started `codemagic.yaml` on the personal free macOS allowance that
calls the same script; keep paid billing disabled. Do not add it while the
primary route works.

Let Flutter drive the project's supported native dependency mechanism (Swift
Package Manager or CocoaPods, whichever this Flutter version selects) rather
than blindly running copied CocoaPods commands. Because only macOS can
migrate the Xcode project, the script captures `git status --porcelain ios/`
and `git diff -- ios/` after the build and uploads them as an artifact. A
non-empty diff is reviewed and committed back from Windows so later builds
start from a reproducible project instead of re-migrating silently.

Proposed device command inside the script:

```sh
flutter build ios --release --no-codesign \
  --target lib/main_probe.dart \
  --build-number "$BUILD_NUMBER" \
  --dart-define=BUILD_ID="$BUILD_ID"
```

`BUILD_NUMBER` is the CI run number, so `CFBundleVersion` increases with every
build and the BC4 update is a real version increase. `BUILD_ID` is
`<short commit>-<host>-<run number>`; `lib/core/config/env.dart` exposes it as
`Env.buildId` with a `local` default, beside the existing compile-time
`API_BASE_URL`. The probe UI, every export and the artifact file name show it.

Validate the produced bundle before packaging: `DTPlatformName` is
`iphoneos`, the executable is `arm64`, `Frameworks/Flutter.framework` and
`Frameworks/App.framework` exist, `CFBundleIdentifier` is the fixed value
below and `CFBundleVersion` equals `BUILD_NUMBER`. Then put the complete app
under `Payload/` in `shiori-probe-<BUILD_ID>.ipa`. Artifact metadata includes
commit, runner/SDK/engine versions and build ID, never credentials.

## App identity

Replace the template `com.example.shiori` with `io.github.natumeai.shiori` (and
`io.github.natumeai.shiori.RunnerTests` for the test target) in
`ios/Runner.xcodeproj/project.pbxproj` before the first device installation.
Every later probe and product build keeps this identifier; changing it later
creates a different app with an empty data container and spends another
free-account App ID. The Android `applicationId` stays unchanged.

The probe and the product app are two build targets of the same app: they
share one identifier, one data container and one home-screen slot. Installing
one replaces the other while keeping app data. This is intentional: it keeps
within the free account's limits (three active sideloaded apps including
AltStore itself, ten App IDs per rolling seven days) and lets BC4 test data
retention across the exact identity later product builds use.

The local signing flow initially uses AltStore Classic/AltServer on Windows.
Document current tool/driver and Developer Mode requirements from official
instructions when executing, plus a pre-install check that the account has a
free active-app slot and App ID quota. Record the identifier AltStore actually
installs (it may rewrite the bundle identifier for the signing team) and keep
using the same tool and Apple ID, since another tool or account can produce a
different installed identity. The user completes Apple sign-in and phone trust
prompts. Each source push publishes to the public repository and requires the
user's confirmation in chat.

## Probe ownership

```text
lib/main_probe.dart                           bootstrap only
lib/app/probe_app.dart                        diagnostic app shell
lib/core/config/env.dart                      + Env.buildId (compile-time)
lib/core/diagnostics/                         recorder, samples, record model, serialization, summary
lib/core/storage/                             app directory abstraction over path_provider
lib/features/diagnostics/data/                probe marker + export file repositories
lib/features/diagnostics/presentation/        synthetic motion/capture UI, declarations
tool/ci/build_ios_unsigned.sh                 host-neutral build/validate/package
.github/workflows/ios-unsigned.yml            primary CI entry
test/core/diagnostics/                        pure fixture/clock tests
test/features/diagnostics/                    repositories, controls and export states
```

`core/storage/` only resolves directories (Application Support, Documents)
behind an injectable interface; it knows nothing about markers or exports.
The marker and export file formats are diagnostics-feature data and live in
`features/diagnostics/data/`. `core/diagnostics/` stays storage-free so the
S2 reader can reuse the recorder. This keeps the `core/` → `features/` import
boundary intact.

Keep `lib/main.dart` and the normal app route flow usable. The probe is an
explicit build target, not a new product tab. Use existing localization/theme
infrastructure and locally owned ticker state. Resource and recorder disposal
must stop callbacks and free retained samples.

The synthetic animation moves a retained Flutter subtree/painted surface
continuously for a bounded capture. It does not use EPUB content, parsing,
network, page-count work or reading-position persistence. Reports identify
the scenario as `synthetic_transform`, never `epub_reader`.

## Diagnostic record

Use a versioned record containing:

- schema/run/scenario/build IDs, `CFBundleVersion` and pinned SDK/engine
  metadata;
- actual OS string, logical/physical viewport and DPR; declared device model
  is labeled as user-provided if no supported automatic API supplies it;
- reported display refresh rate, labeled as reported metadata and never used
  as effective cadence;
- user-declared pre-capture settings: Low Power Mode, Settings → Accessibility
  → Motion → Limit Frame Rate, charging state and whether the phone felt warm,
  each `on`/`off`/`unknown`. iOS gives the app no reliable pure-Dart signal for
  these, and both settings can cap the display at 60 Hz;
- start/stop state, clock domains and correlation status;
- engine FrameTiming samples, scheduler timestamps and inexpensive probe
  motion events in bounded rings;
- sample omissions/overflow, incomplete trailing batch state and errors;
- aggregate UI/raster distributions and the distribution of consecutive
  `vsyncStart` intervals during active motion, computed after capture, with
  raw samples retained for later analysis where complete.

The vsync-interval distribution is the observed engine cadence. Mostly
~16.7 ms intervals with low UI/raster cost indicate a system 60 Hz cap, not an
application miss; mixed ~8.3/16.7 ms intervals alongside over-budget frames
indicate application misses. The export states which pattern it saw and does
not call either physical presentation.

Do not use a batched timing callback's arrival time as frame presentation.
Do not infer FPS from `totalSpan`, assume wall/monotonic epochs match, or
serialize large JSON inside animation callbacks. Stop/drain/export is a
separate state transition. If final samples cannot be proven complete, the
export says so and remains useful partial evidence.

## Export and storage

- **Application Support** (not user-visible): the editable probe marker and
  the last completed record, used for BC4 retention and in-app review.
- **Documents** (user-visible): one `shiori-diag-<BUILD_ID>-<runId>.json` per
  finished or partial capture. Add `UIFileSharingEnabled` and
  `LSSupportsOpeningDocumentsInPlace` to `ios/Runner/Info.plist` so the files
  appear in the Files app under On My iPhone and in the Apple Devices app or
  iTunes File Sharing on Windows, where the user saves them over USB. The
  keys also apply to the product app, so Documents is reserved for files the
  user is meant to take away; settings, checkpoints, outbox and caches never
  go there.
- **Clipboard:** a bounded plain-text summary (at most about 4 KB) with build
  ID, run ID, OS, sample counts, UI/raster P50/P95/P99, the vsync-interval
  pattern, completeness flags and the export file name. It is a quick check,
  not the raw evidence.

`path_provider` is justified in the child PRD; verify its version before
addition. The marker proves update/refresh retention, not durable
reading-event semantics.

## Validation and boundaries

Inject clocks, sample sources and the directory abstraction in tests. Test
bounded capture, overflow, late reports, stop/dispose, stable serialization,
unavailable fields, vsync-interval classification (120 Hz, 60 Hz cap, mixed
misses), declared-setting serialization, export file naming/writing, summary
size bound, marker reload and copy/export UI. Validate the CI script with
`bash -n` on Windows; its bundle checks use macOS tools (`plutil`, `lipo`) and
are first exercised on the runner, so a Windows syntax check is not an iOS
build or a validated package. Device execution remains required for
actual timing availability, signing, file retrieval and retention; mocks
cannot satisfy BC2–4.

The result is a feasibility matrix with independent outcomes. Passing the
engine-data row does not pass actual presentation or the later reader target.
An explicitly unverified presentation row is a valid S1 reporting outcome;
it does not pass the parent performance acceptance criterion.
If the setup cannot supply required evidence, retain the report and bring
the limitation back to the parent rather than hide it or assume paid tools.
