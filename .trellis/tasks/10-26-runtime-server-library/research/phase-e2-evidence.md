# S3 Phase E2: iPhone build selection and local-network purpose

Date: 2026-10-27. Worktree: `D:/Projects/shiori-e2`, branch
`s3/e2-ci-app-mode`, baseline `c9e1b67`. Implements the CI/plist portion of
S3-R9 and enables the product-build route needed by S3-AC10; it does not
complete device acceptance. The worktree was clean before these edits.

## Changes

- `tool/ci/build_ios_unsigned.sh` accepts only `BUILD_MODE=probe|app`.
  Unset defaults to probe; explicitly empty and unknown values fail before
  Git, output creation, the exit trap, host detection or build commands.
  No free-form target is accepted. `--print-build-plan` prints the selections
  used by the build, without invoking build tools or creating output.
- Probe still selects `lib/main_probe.dart`, packages default and cametal
  variants, and retains existing output/IPA names. App selects `lib/main.dart`
  and packages one default variant; an existing `FLTUseFlutterMetalLayer`
  override in the built app causes app mode to fail before packaging.
- Both modes retain the fixed `io.github.natumeai.shiori` bundle ID,
  `BUILD_NUMBER`, `BUILD_ID`, pinned SDK checks, enforced lockfile, fixture
  guard, arm64 executable/framework/SQLite checks, framework inventory,
  checksums and native migration evidence. Provenance adds `mode` and
  `entryPoint`; the job summary identifies both as well.
- `.github/workflows/ios-unsigned.yml` adds a required dispatch choice
  `mode` (probe/app, default probe). Pushes always select probe. Its name,
  run-number source, action pins, Xcode/Flutter versions, permissions,
  triggers, cancellation setting and retention are unchanged.
  Concurrency is now `ios-unsigned-<ref>-<mode>`, separating app and probe
  runs on the same branch while retaining cancellation within a mode/ref.
- `tool/ci/check_ios_build_modes.sh` checks exact target/output/IPA selections,
  five invalid modes in normal and plan invocations, and target rejection.
- `.trellis/spec/flutter/quality-guidelines.md` records these executable
  contracts, local checks, native text policy and the S4 release asset item.
  The probe's diagnostic behavior is unchanged, so `diagnostics.md` needs
  no change.

| Mode | Target | Output | IPA files |
| --- | --- | --- | --- |
| probe | `lib/main_probe.dart` | `build/ios-probe/` | `shiori-probe-<BUILD_ID>.ipa`, `shiori-probe-<BUILD_ID>-cametal.ipa` |
| app | `lib/main.dart` | `build/ios-app/` | `shiori-app-<BUILD_ID>.ipa` |

Uploaded artifact: `shiori-<mode>-<full sha>-gha-<run number>`.
`BUILD_ID` remains `<12-character sha>-gha-<run number>`. The existing workflow
shares `github.run_number` between modes; there is no second counter.
The S1 runbook's provenance/checksum review and user-operated signing/install
flow still applies, using the app artifact/IPA names when mode is app.

## Plist and localization

`ios/Runner/Info.plist` adds only `NSLocalNetworkUsageDescription`:

> Shiori connects to your own lan-reader server on your local network to load your library and download books.

The native project has `developmentRegion = en`, known regions `en`/`Base`
and no `InfoPlist.strings` files; the plist uses
`CFBundleDevelopmentRegion=$(DEVELOPMENT_LANGUAGE)`. English therefore
matches the existing native setup. Flutter's ARB/gen-l10n path does not
translate system permission prompts. `InfoPlist.strings` translations and
Xcode resource registration are warranted before a localized product release;
introducing a native localization scheme is deferred from this narrow change.
No ATS exceptions, Bonjour/multicast keys or TLS changes were added.

## Local validation

All commands below ran locally on Windows with exit code 0. No hosted build
was attempted. Git Bash is `D:/DevTools/git/bin/bash.exe`.

```powershell
& 'D:/DevTools/git/bin/bash.exe' -n tool/ci/build_ios_unsigned.sh
& 'D:/DevTools/git/bin/bash.exe' -n tool/ci/check_ios_build_modes.sh
& 'D:/DevTools/git/bin/bash.exe' tool/ci/check_ios_build_modes.sh
```

Results:

```text
PASS: unset mode defaults to probe (two IPAs)
PASS: explicit probe target and package names
PASS: app target and single package name
PASS: five invalid modes rejected before build (normal and plan)
PASS: free-form target rejected
```

Workflow YAML was parsed offline with cached Dart `yaml 3.1.4`. An ignored
temporary `build/phase-e2-validation/package_config.json` points to cached
packages only; no dependency installation or lockfile change was needed.
The temporary checker parses both local `HEAD` and the edited workflow,
applies the expected mode-only changes to the former, and compares canonical
maps, covering pins, SDKs, permissions and the shared counter as well.

```powershell
& 'D:/DevTools/flutter/bin/cache/dart-sdk/bin/dart.exe' --packages=build/phase-e2-validation/package_config.json build/phase-e2-validation/check_workflow.dart
```

Result: YAML parse and exact semantic diff passed; choice/default, push
fallback, mode wiring, names, concurrency and unchanged settings confirmed.
This parses YAML and checks source expressions; GitHub's expression evaluation
and actual cancellation/upload behavior still require an authorized run.

Python checks ran via PowerShell here-strings piped to `python -`:

- `xml.etree.ElementTree.parse('ios/Runner/Info.plist')` and
  `plistlib.loads(Path(...).read_bytes())` passed. Comparing the typed plist
  with `git show HEAD:ios/Runner/Info.plist`, after removing the exact new
  purpose string, found no other semantic changes. Native English region and
  absence of `InfoPlist.strings` were confirmed by source inspection.
- Script comparison against `git show HEAD:tool/ci/build_ios_unsigned.sh`
  confirmed byte-identical identity/build-number checks and all bundle,
  framework, SQLite and Metal validation functions. Resolving the target,
  variant list and filename expressions back to their probe values made the
  Flutter command and full packaging loop byte-identical to the baseline.
- `git diff --check` passed. Final diff/status review confirmed only allowed
  files changed; nothing was staged, committed or pushed. No `lib/`, `test/`,
  dependency, signing or other workflow files were changed.

These focused shell/YAML/XML/source checks are the applicable local gate for
this CI/plist-only change. Dart code generation, analysis and Flutter tests
were not run; no Dart implementation changed. Windows checks do not prove
macOS/iOS execution. `plutil` is unavailable on this host.

## What only a hosted run and device acceptance can prove

- An authorized hosted run must compile both selected entry points with the
  pinned toolchain, validate actual iphoneos/arm64/SQLite bundles, package the
  expected IPA count and layer flags, and emit matching provenance/checksums.
  Review `ios-status.txt`, `ios-project.diff` and any `ios-untracked.zip`.
- Hosted runs must confirm dispatch/push mode resolution, separate concurrency
  groups, shared build-number progression and artifact upload identity.
- The user must sign/install the app IPA through the existing selected route
  and record launch, local-network grant/deny/re-enable/retry, real transport
  and library/cover access, book preparation including a near-limit synthetic
  archive, relaunch and same-identity update retention. Unavailable HTTP or
  prefix deployments remain explicitly unverified on device.

Open: S3-AC10 product/device evidence is still pending. Engineering app builds
still include shared synthetic reader fixtures; S4 must separate/remove them
before product release. Native prompt translation remains a release follow-up.
No workflow was run and GitHub was not contacted during this work.
