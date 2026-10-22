# Free iPhone build and diagnostics bootstrap

## Goal

Prove that this project can produce an independently running iPhone release
build, installed and refreshed from Windows without a paid Apple membership,
and return useful performance diagnostics before the native reader is built.

Parent: `../10-22-flutter-lan-reader-parity`. This child owns the first delivery
and measurement feasibility gate, not EPUB or full-app performance acceptance.

## Background

The user has Windows and an iPhone 14 Pro Max, selected free personal
sideloading with seven-day refresh, and approved planning only. The parent
requires all client/reader code in Dart/Flutter and a later 120 FPS target.
Current scaffold has no reader or diagnostic exporter. Local SDK metadata
reports Flutter 3.47.7 / Dart 3.13.5. `ios/Runner/Info.plist:5` already enables
`CADisableMinimumFrameDurationOnPhone`; this is not itself performance proof.

The source repository `natumeAi/shiori` is already public (checked
2026-10-22), so standard GitHub-hosted runners, macOS included, are free for
it without any visibility change. The iOS bundle identifier is still the
template placeholder `com.example.shiori`
(`ios/Runner.xcodeproj/project.pbxproj:386`). Evidence for both facts is in
`research/bootstrap-evidence.md`.

## Accepted Decisions

- **Build host:** GitHub Actions standard macOS runner on the existing public
  repository is the primary route. Codemagic's personal free macOS allowance
  is the documented fallback, used only if the GitHub route is blocked or the
  repository stops being public. No paid minutes on either service.
- **App identity:** `io.github.natumeai.shiori` replaces the placeholder
  before the first device installation and stays fixed for every later
  probe/product build, so the device data container survives updates.
- **Signing route (user change, 2026-10-22):** the user signs on the iPhone
  with 全能签 and a certificate supplied to them by a third party, instead of
  AltStore Classic, which stays documented as an alternative. Signing
  material never enters the repository, CI or agent tooling. Updates keep data
  only while the same certificate team signs the same identifier.
- **Diagnostic return path:** raw diagnostic exports are files in the app's
  Documents directory, retrieved on Windows over USB via the Apple Devices app
  or iTunes File Sharing. The clipboard carries only a short summary.

## Requirements

| ID | Requirement |
| --- | --- |
| B1 | Provide a reviewed, manually started GitHub Actions macOS build on the public repository using a pinned runner image/toolchain and the committed dependency lockfile, with no secrets. Keep the build/package logic in a host-neutral script so the Codemagic fallback can reuse it. Do not enable paid usage. |
| B2 | Produce an unsigned release iPhone device app and package it for user-side signing. Set the fixed app identifier before the first install. Document the chosen 全能签 + supplied-certificate route (certificate type, trust/Developer Mode needs, no injection, same-team updates, revocation risk) and keep AltStore Classic installation, refresh and free-account limits as the alternative. No user-owned Mac or TestFlight is required. |
| B3 | Add a separate diagnostic entry point containing a simple continuous native Flutter animation, start/stop capture and structured export. Keep diagnostic controls out of the production app flow. |
| B4 | Capture bounded release frame/scheduling samples and run metadata, with clock domains, overflow, unavailable fields and delayed batches explicit. Report the observed engine vsync-interval distribution and the user-declared refresh-limiting settings so a 60 Hz cap is visible. Engine timing/cadence must not be labeled physical presentation or EPUB performance. |
| B5 | Persist a non-sensitive probe marker to Application Support storage and verify that same-identifier update/refresh retains it. Write each complete or partial diagnostic export as a JSON file in the shared Documents directory; copy a bounded summary to the clipboard. |
| B6 | Supply reproducible user-operated installation/run steps, including a pre-capture refresh-limit checklist, and record actual device results separately from code/CI results. No device result may be invented when the phone is not connected to agent tooling. |
| B7 | Every build reports its identity: a monotonically increasing `CFBundleVersion` from the CI run number and a compile-time build ID containing the commit, shown in the probe UI and included in every export and artifact name. |

Dependency justification: `path_provider` resolves the Application Support
directory (probe marker, last completed record) and the Documents directory
(user-retrievable export files). This is non-critical probe state, not the
future reading outbox. Clipboard summary uses Flutter services. Confirm
package/toolchain compatibility and add the approved-dependency/spec entry
before using it.

## Acceptance Criteria

- **BC1 (B1, B2, B7):** The GitHub Actions build succeeds with the recorded
  runner image, Xcode and Flutter/engine versions; the artifact is a release
  `iPhoneOS`/device app with required frameworks, correctly packaged under
  `Payload/`, named with its build ID. It is not a simulator build or an
  empty/success-looking archive. The workflow uses no secrets and no NAS
  address, and also uploads any CI-generated `ios/` project diff for review.
- **BC2 (B2, B6, B7):** The user installs the locally signed build, with the
  fixed identifier, on their iPhone, launches it from the home screen without a
  debugger, and reports the build ID shown in the app and the actual iOS
  version. Cloud success alone does not satisfy this.
- **BC3 (B3, B4, B5):** A capture run writes a nonempty, bounded export file
  with timing samples, scheduling/events, vsync-interval distribution,
  declared refresh-limit settings and metadata; the user retrieves it on
  Windows (over USB, or through the Files app share sheet when no USB route
  exists) and the clipboard summary matches it. Missing clock
  correlation or final batches are reported explicitly; no physical-FPS claim
  is produced.
- **BC4 (B5, B6, B7):** Create a marker, update to a second build with a higher
  build number and the same signing identity/app identifier, and re-sign the
  same build with the same certificate (the 全能签 equivalent of a refresh;
  AltStore's refresh if that route is used). The marker survives; reopening
  works. Record the certificate expiry and the re-sign outcome without
  claiming an unobserved expiration, revocation or cross-team test.
- **BC5 (B1–B7):** Generated code, formatting, analysis and relevant tests pass;
  the ordinary scaffold app still launches through its existing entry point.
- **BC6 (B4, B6):** A short feasibility report distinguishes installed-device,
  update/refresh, exported-engine-data, observed-cadence and
  presentation-evidence results. Unknown/failed states block the corresponding
  acceptance instead of being hidden in an aggregate pass.

BC1–BC6 feed parent AC9 and the early evidence portion of parent AC4.

## Out of Scope

- EPUB parsing/layout, CFI, activity writes, NAS access, complete UI replication
  or claiming 120 FPS reader acceptance.
- Purchasing/enrolling in paid services, connecting accounts before the build
  configuration is reviewable, publishing the app, or changing repository
  visibility to obtain free compute. If the user makes the repository private
  later, switch to the Codemagic fallback rather than paid GitHub minutes.
- Implementing the Codemagic configuration while the GitHub route works.
- Native platform channels for thermal/low-power/display-link state; manual
  declaration covers S1, and a native diagnostic channel is a later option.
- Adding an iOS engine patch, replacing the Flutter renderer, requiring a Mac,
  or presenting a phone screen recording as physical 120 FPS proof.
- Changing the Android `applicationId`; no Android release is planned.

## Technical Notes and Operational Inputs

Windows signing-tool setup, Apple sign-in and physical phone actions are
operational inputs needed after local build configuration is reviewable. No
credentials are requested in the planning conversation, and the GitHub
workflow needs none. The user controls sign-in/device trust actions.

The repository is public, so every push publishes its content and every CI
artifact is downloadable by signed-in GitHub users. Each push requires the
user's confirmation in chat, goes to a dedicated build branch, never to
`master` without approval, and contains only reviewable code, generated probe
content and unsigned artifacts.

Unsigned build plus Windows signing is documented but not yet demonstrated
for this exact project and current iOS version. The point of this child is to
resolve that uncertainty early. A blocked GitHub route moves to the Codemagic
fallback; exhaustion of that free allowance delays builds. There is no
automatic paid fallback.

## Status

Planning artifacts are prepared for review alongside the parent and were
revised on 2026-10-22 after plan review (build host, app identity, export
path, refresh-limit evidence). This child has not been started and no code,
cloud build, installation or measurement has been performed.
