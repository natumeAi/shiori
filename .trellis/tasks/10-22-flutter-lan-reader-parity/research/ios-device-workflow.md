# iPhone 14 Pro Max development and verification options

Researched on 2026-10-22. Free personal sideloading has been selected for
planning. No implementation, purchase, service connection, or distribution
action has been approved or performed.

## User-provided facts

- The user's only mobile device is an iPhone 14 Pro Max.
- The user has no Android device.
- They requested advice on the development path given this constraint.
- The user subsequently confirmed that only Windows is available. There is
  no available local/borrowed Mac to assume for this plan.
- The user selected the free-sideloading option after its seven-day refresh
  requirement was explained. Do not keep asking about paid membership or Mac
  availability. Use free build allowance first; no paid usage is authorized.

## Verified constraints

1. The iPhone 14 Pro Max has an adaptive ProMotion display with a maximum of
   120 Hz. The available device can validate a 120 FPS target, but not visible
   frame rates above 120 FPS.
   [Apple specifications](https://support.apple.com/en-us/111846).
2. iOS controls the effective refresh rate; applications cannot force an
   unconditional rate. Power, thermal, and user policies can reduce it.
   A proposal should separate high-refresh performance acceptance from
   correct behavior while the OS restricts refresh rate.
   [Apple ProMotion guidance](https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays).
3. Flutter iOS build/release tooling requires macOS and Xcode. Writing shared
   Dart/Flutter code and running appropriate non-iOS tests can remain on
   Windows, but that does not replace iOS compilation or physical-device
   acceptance.
   [Flutter iOS deployment](https://docs.flutter.dev/deployment/ios).
4. A free Apple Personal Team in Xcode supports installation and testing on
   personal devices. Its provisioning profiles expire after seven days,
   requiring rebuilding/reinstallation. App Store Connect/TestFlight uses
   the developer-program distribution workflow.
   [Apple account options](https://developer.apple.com/help/account/basics/about-your-developer-account).
5. A hosted macOS builder can create/sign the iOS build. Codemagic is one
   documented option, with a developer-program/App Store Connect signing
   integration and `app_store` distribution for TestFlight. Pricing and
   service selection are not decided here.
   [Codemagic signing](https://docs.codemagic.io/yaml-code-signing/signing-ios/),
   [Flutter workflow](https://docs.codemagic.io/yaml-quick-start/building-a-flutter-app/).
6. Paid signing is not required merely to compile an unsigned device build
   in hosted macOS. Codemagic documents a separate unsigned Flutter build
   stage. An unsigned artifact must still be signed before device use.
   [Unsigned build stage](https://docs.codemagic.io/yaml-quick-start/first-signed-build/).
7. AltStore Classic/AltServer provides a Windows installation and personal
   sideloading workflow. Free sideloaded apps expire after seven days unless
   refreshed, with a three-active-app limit. The local tool/driver setup,
   actual iOS version, Flutter release artifact, and entitlements must be
   validated together before calling the shiori installation path proven.
   [Windows setup](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows),
   [Refresh and limits](https://faq.altstore.io/altstore-classic/your-altstore).
8. Apple Developer Program membership is listed at USD 99 per membership
   year, or local currency where available. TestFlight is included, but an
   individual TestFlight build is testable for only up to 90 days. Membership
   does not make one TestFlight build permanently installable.
   [Membership](https://developer.apple.com/programs/whats-included/),
   [TestFlight lifetime](https://testflight.apple.com/).

## Recommendation and trade-offs

Prioritize the actual iPhone for the first full implementation and acceptance
cycle; do not require the user to obtain an Android phone merely to fit the
current development computer. Preserve portable Flutter boundaries while
leaving untested platform support unclaimed. Final release scope still belongs
in the reviewed planning summary.

The available computer setup is now resolved: Windows only. The following
workflow needs no user-owned Mac:

1. Edit Dart/Flutter on Windows; run static analysis, unit/widget tests, and
   appropriate desktop layout previews locally.
2. Use a hosted macOS/Xcode environment to compile an iPhone device build.
   Pin a compatible toolchain when the workflow is implemented. Do not use
   simulator artifacts as iPhone install packages.
3. Install a signed build on the user's iPhone by one of the routes below.
4. Exercise real gestures and NAS communication on the phone, export
   diagnostics, and iterate through another build when necessary.

| Installation route | Candidate workflow | Trade-off |
| --- | --- | --- |
| Free personal sideloading | Hosted macOS compiles an unsigned release device app; package the artifact for local signing; use a Windows sideloading tool with the user's Apple account to install/refresh it. | No paid Apple developer membership required for this proposed path, but recurring seven-day refresh and local tool setup are required. End-to-end compatibility is a first validation milestone, not an established result. |
| Developer Program + TestFlight | Hosted macOS builds and signs an App Store distribution artifact; upload to App Store Connect; the user installs/updates it via TestFlight. | Easier repeated distribution; annual membership and signing setup required. Each test build expires after 90 days and must be replaced. |

Free personal sideloading is the selected route. The paid row remains a
reference alternative only. Hosted compute allowance is a separate technical
selection; choose an available free allowance and avoid billable overages.
An exhausted allowance can delay the next build and must not silently trigger
a purchase or change the agreed delivery method.

GitHub documents free standard hosted runners, macOS included, for public
repositories and plan-dependent allowance for private repositories; do not
change source visibility merely to obtain free compute.
[GitHub billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions).
Plan review on 2026-10-22 found that `natumeAi/shiori` is already public
(`gh repo view` reports `PUBLIC`), so this needs no visibility change and no
third-party account. **Selected:** GitHub Actions is the primary build host;
evidence is in the S1 child's `research/bootstrap-evidence.md`.

As of this research, Codemagic documents 500 free macOS M2 minutes per month
for personal accounts; Team accounts do not receive that allowance. At an
estimated (not yet measured) 10–15 minutes per iOS build this would
constrain S2 iteration, so
Codemagic is the **fallback**: used only if the GitHub route is blocked or the
repository becomes private, reusing the same build script. Keep paid billing
disabled on both hosts.
[Codemagic allowance](https://docs.codemagic.io/billing/pricing/).

Free-account limits also shape the build plan: AltStore documents at most
10 App IDs per account, each held for a week, and about three active
sideloaded apps including AltStore itself.
[AltStore App IDs](https://faq.altstore.io/altstore-classic/app-ids).
The app identifier is therefore fixed (`io.github.natumeai.shiori`) before
the first install, and probe and product builds share it instead of using
separate identifiers.

The free route combines documented unsigned builds and documented Windows
sideloading; their suitability for this exact Flutter/iOS combination is an
engineering inference to test. Plan release/AOT builds for independent launch
and performance runs, not the debug-build example used in some CI tutorials.
No service has been connected, source uploaded, account enrolled, or signing
material requested or handled during this research.

For the performance requirement, obtain real iPhone feedback from the reader
prototype early, before replicating every surrounding screen. A successful
cloud build or desktop prototype does not establish 120 FPS.

## Proposed performance evidence

- Treat 8.33 ms as the 120 Hz frame interval, not a guarantee that the OS will
  always schedule 120 frames per second.
- Record the iOS version, actual refresh behavior, power/thermal conditions,
  viewport, sample book, settings, and scenario together with measurements.
  Low Power Mode and Accessibility → Motion → Limit Frame Rate can cap the
  display at 60 Hz and are not reported to the app, so each run records them
  as user declarations and reports the observed engine vsync-interval
  distribution rather than trusting a reported refresh rate.
- Return raw exports as files: the app's Documents directory is shared via
  `UIFileSharingEnabled`, and the Apple Devices app on Windows copies an
  app's files to the computer over USB.
  [Apple Devices file sharing](https://support.apple.com/en-us/120402).
- Measure continuous dragging and settling, rapid direction changes,
  chapter boundaries, long chapters, and images. Keep cold preparation and
  warm animation results separately identifiable.
- Flutter's `SchedulerBinding.addTimingsCallback` exposes engine frame timing
  in release as well as profile builds. It can support exported build/raster
  timings and latency diagnostics when live profiling is unavailable.
  [Flutter timing API](https://api.flutter.dev/flutter/scheduler/SchedulerBinding/addTimingsCallback.html).
- Engine timing alone is not proof that the display presented 120 distinct
  frames per second. Native/system presentation evidence and input-latency
  interpretation remain part of the acceptance protocol to design.
- With Windows only, plan instrumented release-device builds and exportable
  metrics from the beginning. Direct Mac-connected profile-mode investigation
  is a useful optional capability, not an available dependency. The exact
  evidence obtainable without a Mac must be validated before finalizing the
  numerical acceptance protocol. Desktop/browser/simulator FPS cannot be
  substituted for the user's iPhone result.
  [Flutter profiling](https://docs.flutter.dev/perf/ui-performance).

The generated `ios/Runner/Info.plist:5` already contains
`CADisableMinimumFrameDurationOnPhone = true`; adding it again is not a
performance fix. Runtime behavior still needs measurement.

## Remaining technical validation

- Verify that the pinned GitHub macOS runner image, Xcode and Flutter 3.47.7
  install satisfy the checked-in Flutter dependency constraints; keep the
  Codemagic fallback untested unless needed.
- Confirm a release device build installs, launches, updates, and refreshes
  through the chosen Windows tool on the user's actual iOS version.
- Check that refresh/update retains server settings, local reading state, and
  pending activity delivery; do not require reinstalling with data deletion.
- Validate diagnostic export and a defensible high-refresh measurement
  protocol before claiming the performance acceptance gate has passed.
