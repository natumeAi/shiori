# Bootstrap evidence

Inspected on 2026-10-22. This records local metadata and official documentation,
not a successful cloud build, phone installation or performance run.

## Local toolchain

The installed Flutter SDK's `bin/cache/flutter.version.json` reports:

- Flutter 3.47.7, stable;
- Dart 3.13.5;
- framework revision `abaf9c523780a608bd46686fd5e53740a07077f8`;
- engine revision `deb287481e3ce9468f3434937ced4240a70539ca`.

`pubspec.yaml` requires Dart `^3.13.5`. The cloud pin must satisfy that exact
floor; a generic older Flutter 3.47 image is not automatically compatible.
Actual hosted Xcode and native dependency resolution still need validation.
The repository has no `ios/Podfile`; Flutter decides on the first macOS build
whether Swift Package Manager or CocoaPods integrates plugins, and that build
may modify the Xcode project.

## Repository and build host

`gh repo view natumeAi/shiori` on 2026-10-22 returned `"visibility":
"PUBLIC"`, default branch `master`. No visibility change is involved in
choosing a GitHub-hosted runner.

- GitHub documents Actions usage as free for standard GitHub-hosted runners
  in public repositories; the free plan allows up to five concurrent macOS
  jobs. Private repositories consume plan minutes instead, at a higher macOS
  rate, which is why a later switch to private moves builds to the Codemagic
  fallback. [Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions),
  [usage limits](https://docs.github.com/en/actions/reference/usage-limits-billing-and-administration),
  [2026 pricing changelog](https://github.blog/changelog/2025-12-16-coming-soon-simpler-pricing-and-a-better-experience-for-github-actions/).
- `workflow_dispatch` runs are tied to the workflow file on the default
  branch, and community reports disagree on how branch selection behaves.
  [docs issue](https://github.com/github/docs/issues/35318). The design adds an
  `ios-build/**` push trigger so the first build does not depend on that
  behavior or on merging to `master`.
- Public-repository artifacts can be downloaded by signed-in GitHub users;
  the S1 artifact is an unsigned probe app with no secrets or NAS data.

## App identity and free-account limits

`ios/Runner.xcodeproj/project.pbxproj:386` (and the other Runner build
configurations) set `PRODUCT_BUNDLE_IDENTIFIER = com.example.shiori`, the
`flutter create` placeholder; `RunnerTests` uses `com.example.shiori.RunnerTests`.
The plan fixes `io.github.natumeai.shiori` before the first installation.

AltStore documents that a free account can register at most 10 App IDs, each
held for one week, and reports the free-account cap on active sideloaded apps
at three. Older third-party guides cite two active apps, so the actual limit
is checked on the user's account at install time.
[AltStore App IDs](https://faq.altstore.io/altstore-classic/app-ids),
[AltStore error codes](https://faq.altstore.io/altstore-world/error-codes).
Apple developer forum reports describe the same 10-per-7-days App ID quota.
[Apple forums](https://developer.apple.com/forums/thread/705834).

## Diagnostic export retrieval

Apple's support article for the Apple Devices app on Windows has a section
"Copy files from an iOS or iPadOS app to your computer": connect by USB,
open File Sharing, select the app's files and save them to a folder. It
requires the app to support File Sharing.
[Apple Devices file sharing](https://support.apple.com/en-us/120402),
[Windows → device transfers](https://support.apple.com/guide/devices-windows/mchl4bd77d3a/).
`UIFileSharingEnabled` is the Info.plist key that exposes the app's Documents
directory for file sharing; `LSSupportsOpeningDocumentsInPlace` is set with it
so the folder also appears in the Files app. The Apple developer page did not
render its body when fetched, so this key behavior is from Apple's
long-standing documented behavior and is confirmed on the device in S1.
[UIFileSharingEnabled](https://developer.apple.com/documentation/bundleresources/information-property-list/uifilesharingenabled).
AltServer's own setup already uses Apple's Windows device software; which of
Apple Devices or iTunes File Sharing coexists with it is recorded during S1.

## Refresh-limiting settings

Settings → Accessibility → Motion → Limit Frame Rate caps a ProMotion
display at 60 fps, and developer references report that Low Power Mode does
the same. No public API detects Limit Frame Rate. These come from third-party
guides and developer references, not an Apple support page found in this
search, so the probe asks the user to declare both settings and shows the
observed vsync-interval pattern instead of trusting any reported rate.
[iDownloadBlog](https://www.idownloadblog.com/2023/10/02/how-to-turn-off-promotion-iphone-ipad/),
[display-performance reference](https://playbooks.com/skills/charleswiltgen/axiom/axiom-display-performance).
Parent `research/ios-device-workflow.md` cites Apple's ProMotion guidance
that the system may limit the effective rate.

## Candidate app-support storage dependency

The Flutter team's [path_provider](https://pub.dev/packages/path_provider)
page currently lists 2.1.6 and supports Application Support and Documents
directories on iOS and Windows. It provides a suitable directory abstraction
for the probe marker, the last completed record and the shared export files;
it does not itself provide durable transactional outbox semantics.

The publisher recommends mocking `PathProviderPlatform` in tests rather than
assuming a shared platform-channel implementation. Alternatively inject the
resolved directory/storage abstraction into the probe repositories so most
tests do not invoke a plugin at all. No package has been added or compatibility
test run in this planning phase.

## Required related evidence

- Parent `research/ios-device-workflow.md`: selected free signing workflow,
  build host selection and user-owned device steps.
- Parent `research/performance-acceptance.md`: distinct engine, cadence and
  presentation evidence; no synthetic-probe EPUB claim.
- `ios/Runner/Info.plist:5`: the high-refresh opt-in already exists. It is not
  an optimization to add it again, and it does not prove effective 120 Hz.

The child is ready for plan review, not already activated or executed.
