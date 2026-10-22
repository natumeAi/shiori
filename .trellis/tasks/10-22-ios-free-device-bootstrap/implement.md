# Implementation checklist: free iPhone bootstrap

Do not activate or implement in the final planning-review turn. Start only
after the user explicitly approves the latest parent/child summary.

## Ordered work

1. Load curated specs/research; inspect current SDK, iOS project and dependency
   setup. Verify the pinned setup action can install Flutter 3.47.7, the
   chosen macOS runner image/Xcode, and the `path_provider` version.
2. Replace `com.example.shiori` with `io.github.natumeai.shiori` (and the
   `RunnerTests` identifier) in the Xcode project. This must land before any
   build is installed on the phone.
3. Write `tool/ci/build_ios_unsigned.sh` (build with `--build-number` and
   `--dart-define=BUILD_ID`, bundle validation, `Payload/` packaging, `ios/`
   diff capture) and `.github/workflows/ios-unsigned.yml` (dispatch and
   `ios-build/**` push triggers, read-only permissions, SHA-pinned actions,
   short retention, no secrets). Check the script with `bash -n` without
   claiming an iOS build or package validation ran on Windows.
4. Add `Env.buildId`, the `core/storage` directory abstraction, the
   `core/diagnostics` recorder/record/summary, the `features/diagnostics`
   marker and export-file repositories, the declared-settings form, the
   Documents export and the separate probe entry point. Add
   `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` to
   `Info.plist`. Keep normal app behavior and its tests intact.
5. Add meaningful pure/widget tests and localization. Update relevant specs:
   `path_provider` in the approved-dependency table, `core/storage` and
   `core/diagnostics` in the directory guide, the Documents vs Application
   Support rule, `Env.buildId`, and the CI/build-identity convention.
6. Run local quality gates, inspect the complete diff, and write the exact
   GitHub build, AltStore signing, free-account limit check, refresh-limit
   checklist and USB export-retrieval instructions. Configuration must be
   reviewable before any push or sign-in action.
7. With the user's confirmation for that specific push, push to an
   `ios-build/s1-...` branch of the public repository and run the workflow.
   Record runner image, Xcode/Flutter/engine versions, build logs, artifact
   provenance and any `ios/` diff (review and commit it back if non-empty).
   No paid fallback; switch to the Codemagic fallback only if this route is
   blocked, and only after reviewing that configuration with the user.
8. Have the user check free-account slots, sign/install, launch from the home
   screen, confirm the displayed build ID, complete the refresh-limit
   declarations, run a capture and copy the export file to Windows over USB.
   Check actual device/OS, samples, cadence pattern and evidence labels.
9. Produce a second build (higher build number, unchanged app identity, again
   with push confirmation); validate update and signing refresh preserve the
   marker. Record each observed result.
10. Complete the feasibility report, self-check spec/quality compliance through
    Trellis check dispatch, and return evidence to the parent. Unobserved
    device criteria remain pending; do not call the child complete on CI
    success alone.

## Validation

```powershell
dart run build_runner build
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
bash -n tool/ci/build_ios_unsigned.sh
```

Run targeted recorder/storage/screen tests while changing those modules;
perform the final full gate once the child diff stabilizes. No real NAS calls
in this child.

Device run checklist, before every capture: Low Power Mode off; Settings →
Accessibility → Motion → Limit Frame Rate off; note charging state and
whether the phone is warm; record all four in the probe's declaration form.
A run with any limiter on is kept as separate evidence, not discarded.

Device checks: independent launch, displayed build ID, complete/partial
capture export file, USB retrieval on Windows, clipboard summary matching the
file, stable run/build identity, stop/resume/dispose, marker reload,
same-identity update with a higher build number and explicit refresh. A
synthetic animation's result is not EPUB acceptance or physical 120 FPS proof.

## Risk and rollback

- Missing account/device access pauses only the corresponding validation;
  finish all reviewable local preparation first.
- The repository is public: never push secrets, NAS addresses, real books or
  personal diagnostics; each push needs the user's confirmation. Committed
  feasibility reports summarize device results instead of copying raw exports.
- If unsigned release signing/launch fails, retain logs and validate package
  format/toolchain/entitlements before proposing another route. Do not require
  paid membership or a local Mac after the user chose free Windows delivery.
- If the GitHub runner/toolchain route fails or the repository becomes
  private, move the same script to the reviewed Codemagic fallback; do not buy
  minutes.
- Keep the fixed package identity. Do not delete app data to make update tests
  pass, and do not overwrite any existing user app with a conflicting identity.
  If the free App ID quota is exhausted, wait for it to recover instead of
  creating a variant identifier.
- Isolate probe code behind its entry point so it can be removed after its
  reusable diagnostics are integrated. Preserve useful metric export code.

## Ready gate

- PRD/design/implementation and real context manifests reviewed.
- Fresh explicit user approval after the final planning summary.
- Run `task.py start` for this child, not the parent or later planned children.
- Dispatch implementation/check agents with this exact active task path.
