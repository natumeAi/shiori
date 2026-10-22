# Initial reference audit

Inspected on 2026-10-22. This document records repository evidence and candidate
directions, not approved product trade-offs or implementation approval.

## Evidence boundary

- Target workspace: `D:/Projects/shiori`.
- Reference checkout: `D:/Projects/lan-reader`.
- Reference HEAD observed: `a4bda23fd3e82e285a22566d88576e67d3e8756b`
  (`chore(release): 升级至3.3并更新README`). Reference working-tree cleanliness
  was not established because the available Git status attempts failed under
  the environment restrictions. Findings below describe the files read.
- The NAS deployment itself has not been contacted. Its installed version and
  reverse-proxy configuration are not inferred from the local checkout.
- No source code, configuration, data, or Git state in lan-reader was changed.

## Existing shiori foundation

| Concern | Evidence | Planning implication |
| --- | --- | --- |
| App scaffold | `lib/features/home/presentation/home_screen.dart:6` | Feature implementation remains to be done. |
| Networking | `lib/core/config/env.dart:3`, `lib/core/network/dio_provider.dart:13` | Replace compile-time-only addressing with runtime server configuration. |
| Themes | `lib/app/theme.dart:4` | Current generated color schemes are not the lan-reader visual baseline. |
| Established stack | `.trellis/spec/flutter/index.md:18`, `pubspec.yaml` | Retain the existing Riverpod/Dio/typed-route/model conventions. |
| HTTP platform setup | Archived scaffold PRD notes; `android/app/src/main/AndroidManifest.xml` | Android Internet permission is present in debug/profile manifests, not the inspected main manifest. Release networking needs explicit verification and setup. |
| iOS refresh flag | `ios/Runner/Info.plist:5` | A generated high-refresh-related flag exists; that does not prove device support or performance. |

Platform directories are not evidence that all platforms are required. No
existing shiori task/spec establishes the user's intended target hardware.

## Initial parity inventory

Source: `D:/Projects/lan-reader/README.md:23` and corresponding components,
styles, hooks, and reader modules. Each row must later become traceable
screen/state/interaction checks, rather than a broad feature checkbox.

| Area | Current behavior to preserve |
| --- | --- |
| Navigation | Home/bookshelf/statistics tabs, transitions, per-session browsing state, reader return destination. |
| Home | Continue reading and expanded recent list, daily goal, seven-day activity, cumulative time/characters, recommendations, completed books for the year. |
| Library views | Responsive 3–5-column shelf, all-books/folders views, search, manual/recently-read/recently-added/title sorting, progress badges and folder counts. |
| Library operations | Multi-EPUB upload with placeholders/progress; reorder; hover-to-group/move; spring-loaded folder opening; delete zone; item menus; batch actions; five-second undo. |
| Statistics | Day/week/month/year/all ranges; local-date semantics; sticky controls; overview/comparison/trend/ranking/completed-book/calendar views and detail overlays. |
| Reader | Pagination, TOC, chapter page count and book progress, tap/drag/keyboard turns where applicable, image viewer with zoom, settings, diagnostics and recovery. |
| Appearance | Six font choices, four reader themes, font size, margins, line height and letter spacing; app dark mode follows the OS independently of the reader theme. |
| Accessibility/lifecycle | Reduced-motion behavior, overlays blocking reader input, suspend/resume, layout invalidation, reliable accepted-position persistence. |
| NAS integration | Book import/replacement/deletion remains server-owned; app must consume resulting changes correctly. |

No visual screenshot comparison has been performed yet. Source inspection is
not sufficient to claim visual parity.

## Existing API surface

Paths below are relative to the configured deployment root. Subpath handling
must be verified when designing URL resolution.

| Contract | Source anchor | Use |
| --- | --- | --- |
| `GET /api/health` | `server/src/app.ts:73` | Existing service/database probe; no explicit app/API version or capability fields. |
| `GET /api/library/snapshot` | `server/src/routes/library.ts:20` | Library snapshot with ETag/revision semantics. |
| Books/catalog/upload/order/delete | `server/src/routes/books.ts:109` | Existing book operations. |
| `GET /api/books/:id/file` | `server/src/routes/books.ts:207` | Original EPUB with `application/epub+zip` and `private, no-cache`; Express `sendFile`. |
| Shelf and folder operations | `server/src/routes/folders.ts:47` | Existing reordering and folder mutations. |
| `GET/PUT /api/reading/:bookId` | `server/src/routes/reading.ts:166` | CFI/progress/chapter data. |
| Recent, home stats, period statistics | `server/src/routes/reading.ts:81` | Existing home and statistics presentation data. |
| `PUT /api/reading/goals` | `server/src/routes/reading.ts:131` | Daily/annual reading goals. |
| `POST /api/reading/activity` | `server/src/routes/reading.ts:151` | Idempotent event batches with per-event outcomes. |

All anchors in this table are relative to `D:/Projects/lan-reader`.

## Reader compatibility risks

1. **Layout is a substantial rewrite.** `client/src/reader/types.ts:5` contains
   browser Document/HTMLElement contracts; `foliateEngine.ts` delegates to
   Foliate. Reusing those runtime objects would not satisfy the Flutter-native
   requirement. HTML/CSS support must be evaluated against actual EPUB cases.
2. **Reference scope includes more than plain horizontal text.**
   `client/src/reader/foliateEngine.ts:57` exposes RTL direction.
   `client/src/reader/foliateNavigation.ts:18` handles fixed-layout spreads;
   adjacent navigation skips non-linear spine entries. A reduced native
   content subset cannot be silently selected.
3. **Location must be content-based.** `shared/src/reading.ts:22` exposes CFI,
   progress and chapter fields. Native layout page indices are not portable
   across engines or settings. Validate CFI generation/resolution against the
   original XHTML structure and real cross-client fixtures.
4. **Statistics require byte/offset-compatible normalization.**
   `shared/src/readingStats.ts:32` fixes the accepted normalization version.
   `client/src/utils/canonicalText.ts:28` filters Unicode code points;
   `canonicalText.ts:63` implements FNV-1a 64 over UTF-8; `canonicalText.ts:174`
   indexes eligible body text. Dart UTF-16 string indexing alone is not a
   compatible character-count rule.
5. **Visible coverage is a separate computation.**
   `client/src/reader/visibleText.ts:1` counts verified visible content only,
   excluding preview/prewarm pages. Native layout must expose corresponding
   canonical intervals without counting an entire chapter or estimated
   percentage as visible text.
6. **Appearance is local today.**
   `client/src/hooks/useReaderSettings.ts:224` uses localStorage;
   `README.md:218` documents isolation by browser origin. Cross-client theme
   synchronization would be a new feature, not a missing current API.
7. **Performance remains a separate acceptance gate.**
   `.trellis/tasks/archive/2026-09/09-23-reader-high-refresh-slide/prd.md:50`
   leaves real 120 Hz device acceptance outstanding. Existing architecture
   and tests provide useful behavior cases, not a transferable FPS guarantee.

All relative anchors in this section refer to `D:/Projects/lan-reader`.

## Candidate backend handoff

These are initial recommendations, not proven mandatory changes:

- API version/capability reporting can make address validation and future
  compatibility errors explicit. Existing health and endpoint probes may
  suffice for the first compatible deployment.
- `shared/src/book.ts:12` does not expose a dedicated EPUB content digest or
  revision. Evaluate existing file HTTP validators before deciding whether
  an explicit content version is needed for reliable cache invalidation.
- Preserve existing CFI interoperability first. Only propose an additional
  locator format if the native compatibility investigation demonstrates the
  need; preserve old-client behavior in any extension.
- Reader-setting synchronization is conditional on a future explicit scope
  request. It is not required to reproduce current browser-local behavior.

No backend rewrite, NAS deployment, or direct backend edits are part of the
authorized work in this repository.

## Technical sources

- [Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance):
  validate supported high-refresh performance on physical devices in profile
  mode; debug/simulator measurements do not establish release performance.
- [Flutter performance practices](https://docs.flutter.dev/perf/best-practices):
  avoid repeated expensive build/layout work and unnecessary subtree rebuilds.
- [Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup):
  iOS build/device validation requires Xcode tooling and a Mac workflow.

The user later clarified that the only available mobile device is an iPhone
14 Pro Max and only Windows is available. The accepted planning route is
therefore iPhone-first with hosted macOS builds and free personal sideloading;
see `ios-device-workflow.md`. Existing generated platform folders do not
override that user-provided hardware constraint.
