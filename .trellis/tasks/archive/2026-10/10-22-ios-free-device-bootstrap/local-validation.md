# Local validation

Windows preparation on 2026-10-22. No commit, push, remote branch, workflow
execution, sign-in, signing or device action was performed. Task status stays
`in_progress`; device acceptance remains pending.

## Initial state and preflight

Initial `git status --short` contained only the existing untracked parent and
child task directories. Product source was clean. All six Xcode identifiers
were the expected template values; `Env` contained only `apiBaseUrl`, and the
existing high-refresh plist key was already true.

Each preflight Flutter command had an explicit 180000-ms subprocess timeout:

| Command | Exit | Relevant tail |
| --- | --- | --- |
| `flutter --version` | 0 | Flutter 3.47.7 stable; framework abaf9c5237; engine deb287481e; Dart 3.13.5 |
| `flutter test test/core/errors/error_messages_test.dart` | 0 | `00:00 +8: All tests passed!` |
| `flutter analyze lib/main.dart` | 0 | `No issues found! (ran in 5.1s)` |

The first output-printing wrapper encountered Windows Python's GBK stdout
encoding after `flutter --version` returned. The wrapper was corrected to
UTF-8 and the full preflight above completed before any source edits.

## Dependency and public source verification

- `flutter pub add path_provider` resolved `2.1.6` and its expected transitive
  dependencies in the existing lockfile. The command then returned 1 at the
  Windows symlink/Developer Mode check. No OS settings were changed.
- The package requires Dart `^3.10.0` / Flutter `>=3.38.0`; resolved
  `path_provider_foundation 2.6.0` requires Dart `^3.10.3` / Flutter `>=3.38.4`.
  Its changelog establishes iOS 13 as the deployment floor, below Runner's
  existing 15.0 target. The resolved foundation implementation uses FFI/native
  assets, with no plugin podspec or Package.swift. The local plugin manifest
  reports `native_build:false` for it; the project already references
  FlutterGeneratedPluginSwiftPackage and has no Podfile. These are source and
  dependency inspection findings, not a tested macOS integration result.
- Current checkout/upload-artifact/flutter-action pins are the Node 24/composite
  versions supplied by Claude's authenticated outside-sandbox review using
  `gh api` and `git ls-remote`. The sandbox cannot re-verify GitHub over TLS;
  their supplied runtime/input checks are recorded in `device-runbook.md`.
  No sign-in or persistent Git config change was made.
- Official Flutter macOS release JSON confirmed stable 3.47.7 / Dart 3.13.5,
  arm64 archive and the expected full framework revision. Exact action tags
  and runner/Xcode documentation are recorded in `device-runbook.md`.
- Installed Flutter tool source `packages/flutter_tools/lib/src/macos/xcode.dart`
  defines required Xcode 15 and recommended Xcode 16; selected Xcode 26.3
  exceeds both. Native compilation compatibility still requires the hosted run.
- `bash -n tool/ci/build_ios_unsigned.sh` with explicit Git Bash
  `D:\DevTools\git\usr\bin\bash.exe` passed (exit 0). A first Python invocation
  of bare `bash` resolved WSL instead and failed to start with `E_ACCESSDENIED`;
  the explicit Git Bash path resolved that command-discovery issue.

## Final quality gate

All five commands passed after the engine-frame-number review fixes. Full relevant output
tails, durations and explicit timeout values are in `quality-gate-results.json`.

| Command | Exit | Relevant output tail |
| --- | --- | --- |
| `dart run build_runner build` | 0 | `Built with build_runner/aot in 3s; wrote 2 outputs.` (same contents; no file-hash changes) |
| `dart format --set-exit-if-changed lib test` | 0 | `Formatted 70 files (0 changed) in 0.11 seconds.` |
| `flutter analyze` | 0 | `No issues found! (ran in 4.3s)` |
| `flutter test` | 0 | `00:02 +90: All tests passed!` |
| `bash -n tool/ci/build_ios_unsigned.sh` (explicit Git Bash executable) | 0 | No output; syntax check succeeded. |

Before/after SHA-256 comparison of every file under `lib/` found no codegen
changes, including the two identical outputs rewritten during build-graph
refresh. Existing tracked tests and the ordinary app entry/routes are
unchanged; the full test run includes their existing smoke/regression coverage.
Codegen/full tests had 900000-ms limits; format/analyze/syntax had 180000-ms
limits. No command timed out in this final gate.

The Linux and Windows `flutter/generated_plugins.cmake` files intentionally
retain `jni` in `FLUTTER_FFI_PLUGIN_LIST`, generated from path_provider's Android
dependency. The review explicitly expanded scope to retain these required
generated outputs; they must not be restored after the gate.

Comparison with the 405-file baseline captured before this review found only
the 16 intended code/test/workflow/spec/report files changed. Protected
child-planning/parent files, existing ordinary app/tests and all other baseline
files are unchanged; both CMake files still contain their expected `jni` entry.
HEAD remains `88f7a49`, the child remains `in_progress`, and its parent remains
`planning`. Final whitespace/scope checks passed. The known untracked planning
directories predate implementation and were not rewritten.

## Review and design alignment

The Trellis implementation and independent check agents used the explicitly
requested `gpt-6.1-sol` with high reasoning. No unresolved review findings remain
within local steps 1–6. Source, generated output, tests, native edits, workflow,
script, localization, specs and the runbook were inspected.

The current review corrects the earlier timestamp-equality implementation:
scheduler timestamps are vsync targets, not the timing recorder's vsync starts.
The recorder now joins motion and timing data by valid engine frame numbers.
This corrects the sampling implementation while preserving the design's
engine/presentation evidence boundaries. The artifact additionally preserves newly
generated native files in `ios-untracked.zip`, because a tracked diff cannot
recover their contents. Additional compile-time version defines supply the
record's required provenance; metadata explicitly states that the build number
comes from the same CI input checked against CFBundleVersion, not a native
runtime read. The recorder conservatively marks trailing samples incomplete
because the engine API provides no public flush/completion guarantee.

## Resume verification and review corrections

- User enabled Windows Developer Mode before resuming. A fresh
  `flutter pub get --enforce-lockfile` now exits 0, keeps the lockfile hash
  unchanged and no longer reports the symlink privilege failure. Flutter
  regenerates Linux/Windows plugin CMake lists for transitive `jni`; those
  generated files are now explicitly authorized and retained after checks.
- The interrupted core test run exposed a test harness issue: a zero-duration
  drain timer needs `tester.pump(Duration.zero)`, not a bare `pump()`, before
  awaiting completion. Five calls were corrected and the core tests no longer
  hang. The stale test subprocesses were confirmed stopped before retrying.
- Independent review fixed cadence gaps (require adjacency in both sample
  streams), unsupported persisted record versions, directory/plugin failure
  normalization, public adapter file placement and probe-root retry policy.
  Local storage errors now use a diagnostics-specific localized message.

## Engine-frame-number review

- Verified the supplied facts in local Flutter 3.47.7:
  `animator.cc:114-118` passes `GetVsyncTargetTime()` and the recorder frame
  number; `ui/hooks.dart:400-403` runs the scheduler's begin-frame callback
  before updating frame data; `ui/window.dart:1142-1151` defines unavailable
  frame number `-1`. No source mismatch was found.
- Motion timestamps/progress are captured in the animation listener. A
  same-frame post-frame callback reads the updated engine frame number, with
  capture/disposal guards. Raw scheduler target timestamps remain metadata.
- UI/raster costs match nonnegative engine frame numbers. Cadence uses timing
  `vsyncUs` deltas for consecutive frame numbers present in both streams;
  missing/negative IDs cannot bridge a gap or match one another. Unavailable
  IDs surface as explicit export errors.
- Regression fixtures model scheduler target = vsync start + one period.
  The regression asserts five matched IDs/cost samples, four cadence intervals
  and a 5000-us UI maximum while excluding an unrelated 90000-us frame whose
  start accidentally equals a motion target. It proves the join cannot shift
  to a different frame with an equal timestamp. ID gaps, unavailable IDs,
  ring eviction/reset and same-frame post-frame sampling are also covered.
- Widget regression asserts the ID reader runs in `postFrameCallbacks` and
  returns the newly updated ID, not the previous ID visible during the ticker.
  Queued callbacks after lifecycle stop, capture restart and disposal cannot
  publish stale motion. The narrow reader seam only exists for the read-only
  test dispatcher; production reads actual platform frame data post-frame.
- Independent review found no additional substantive issue; targeted
  diagnostics tests and analysis passed before the complete 90-test gate above.
- Workflow pins: checkout `v7.0.1` / upload-artifact `v7.0.2` (Node 24),
  flutter-action `v2.23.0` (composite), with full supplied SHAs and unchanged
  build permissions/triggers/retention. No workflow was executed.

## Evidence boundaries

Only shell syntax is validated for the macOS build script on Windows. No
`flutter build ios`, `plutil`, `lipo`, native package validation, physical
timing, AltStore compatibility, USB retrieval or update/refresh retention
result is claimed. Follow `device-runbook.md` to collect those results.
