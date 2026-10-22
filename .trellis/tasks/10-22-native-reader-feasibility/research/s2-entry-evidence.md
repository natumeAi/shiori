# S2 entry evidence

Inspected on 2026-10-22 while planning S2. These are source and prior-run
facts, not results of S2 work. Nothing here was built, installed or measured
for S2.

## S1 baseline carried into S2

From `../../archive/2026-10/10-22-ios-free-device-bootstrap/device-runbook.md`
(BC3/BC4 rows and feasibility matrix):

- Build route works: GitHub Actions `macos-15`, Xcode 26.3, Flutter 3.47.7
  (`abaf9c5237` / engine `deb287481e`), unsigned device IPA, ~70 s Xcode build.
- Signing route actually used: 全能签 with a third-party Apple Distribution ad
  hoc certificate (expires 2027-05-15). Same-certificate update (build 3 → 4)
  and same-build re-sign both retained Application Support state.
- Export retrieval actually used: Files app → On My iPhone → Shiori → Share to
  Windows. No USB route was used. The reverse direction (placing a file into
  the app's Documents folder through the Files app) is the planned way to get
  real EPUBs onto the phone in S2; it has not been tried yet.
- Synthetic transform capture (15 s, limiters declared off): UI P50/P95/P99/max
  353/406/1256/12715 µs; raster 799/916/1003/2927 µs; vsync intervals
  P50 8339 µs, 1795 of 1796 within 7–10 ms, one start-transition miss,
  classification `observed_near_120hz`. Viewport 430×932 @3x.
- Physical presentation: unverified. S1 explicitly hands this to S2.

These numbers are the cost floor of a trivial moving surface. A text page has
more raster work (glyphs, images) and the reader adds preparation work, so the
S1 margin does not predict S2 results.

## Presentation path in the pinned engine

The local SDK checkout at `D:/DevTools/flutter` is at framework revision
`abaf9c523780a608bd46686fd5e53740a07077f8`, the same pin CI uses, and contains
the engine sources under `engine/src/flutter`. Paths below are relative to
`engine/src/flutter/shell/platform/darwin/ios/`.

- `rendering_api_selection.mm:59` — for Metal, `FlutterView`'s layer class is
  `FlutterMetalLayer` when `[FlutterMetalLayer enabled]`, else `CAMetalLayer`.
- `framework/Source/FlutterMetalLayer.mm:459` — `enabled` defaults to `YES`;
  only an Info.plist `FLTUseFlutterMetalLayer = false` disables it. shiori's
  `ios/Runner/Info.plist` does not set the key, so the product path is
  `FlutterMetalLayer`.
- `FlutterMetalLayer.mm:118` — its `FlutterDrawable.presentedTime` returns `0`.
- `FlutterMetalLayer.mm:133` — `addPresentedHandler:` only logs a warning.
  Apple's `MTLDrawable` presentation callbacks therefore cannot be obtained on
  the default path, with or without swizzling `nextDrawable`.
- `FlutterMetalLayer.mm:425` — `presentTexture:` stamps `CACurrentMediaTime()`
  and calls `presentOnMainThread:` (`:398`), which sets `self.contents` to the
  IOSurface inside a `CATransaction`. Stale-size textures are dropped silently
  (`:399`).
- `FlutterMetalLayer.mm:187`, `:203`, `:217` — the layer runs its own main-thread
  `CADisplayLink` (the comment explains the UI-thread vsync waiter does not
  trigger Core Animation frames), sets a 60–120 Hz preferred range, raises it to
  forced max when two contents updates land in one display-link period, and
  pauses after three idle periods.

Consequences for the S2 spike (see `design.md` §9):

1. On the product path the best obtainable native signal is the time each new
   IOSurface is committed to the layer (`setContents:` on the main thread),
   aligned with display-link periods. That is compositor-submission cadence,
   one step closer to the display than engine `FrameTiming`, but still not
   scan-out.
2. Apple's `presentedTime` is only available on a diagnostic variant that sets
   `FLTUseFlutterMetalLayer = false`, which changes the presentation pipeline.
   The engine comment suggests that path may not sustain 120 Hz, so its result
   describes the alternate path, not the product.
3. Adding a diagnostic `CADisplayLink` with a 120 Hz preferred range can itself
   keep the display at 120 Hz and mask a pacing problem. The spike must compare
   runs with and without it.
4. Natively, `ProcessInfo.isLowPowerModeEnabled`, `ProcessInfo.thermalState`
   and `UIScreen.maximumFramesPerSecond` are readable. Accessibility → Limit
   Frame Rate still has no public API and stays a user declaration.

## Reference behavior to reproduce

`D:/Projects/lan-reader` is at `a4bda23fd3e82e285a22566d88576e67d3e8756b`
with a clean working tree (checked 2026-10-22). The repository
`natumeAi/lan-reader` is public and owned by the same account as shiori; it
has no LICENSE file. It stays read-only for this task.

- `client/package.json:19` pins `foliate-js` to the codeload tarball of commit
  `78914aef4466eb960965702401634c2cb348e9b1`; `client/package.json` also pins
  `fflate` `0.8.2`.
- `client/src/reader/foliateEngine.ts:461` opens books with
  `new EPUB({ loadText, loadBlob, getSize })` over `fflate.unzipSync` output.
  `loadText` uses `strFromU8`, i.e. every text resource is decoded as UTF-8
  regardless of any declared encoding. Native parsing must match that.
- `node_modules/foliate-js/epub.js:817` parses `application/xhtml+xml` with
  `DOMParser` and falls back to `text/html` when a `parsererror` appears.
  XML well-formedness and entity handling (for example `&nbsp;` with and
  without an XHTML DOCTYPE) therefore decide which parser applies.
- Sizes of the behavior to port: `utils/canonicalText.ts` 223 lines,
  `reader/contentSecurity.ts` 45, `utils/pageTurnGesture.ts` 164,
  `reader/pageTurnEngine.ts` 113, `reader/readerController.ts` 951,
  `reader/foliateEngine.ts` 497, `reader/visiblePageAnchor.ts` 25,
  `utils/contentImage.ts` 533, `hooks/useReaderSettings.ts` 550;
  `foliate-js/epubcfi.js` 349, `foliate-js/epub.js` 1083.
- `canonicalText.ts:18` imports only `READING_TEXT_NORMALIZATION_VERSION`
  from `@lan-reader/shared`; `contentSecurity.ts` has no imports. Both can be
  vendored into shiori's oracle tooling with provenance and a drift check.
- `canonicalText.ts:26` uses `/[\p{White_Space}\p{Cc}\p{Cf}\p{Cs}]/u`; the
  Unicode tables come from the JavaScript engine that ran the reader. Dart
  must use a generated, pinned table, compared against oracle output.
- Reference tests to port as state-machine evidence (all in `client/test/`):
  `readerTurnProof.test.ts`, `readerInputQueue.test.ts`,
  `readerMotionIsolation.test.ts`, `readerPageTurnEngine.test.ts`,
  `pageTurnEasing.test.ts`, `foliateTurnTargetProof.test.ts`,
  `readingActivityText.test.ts`, `contentImage.test.ts`.
- The reference's browser tests are hand-run HTML pages
  (`client/test/browser/*.html`); there is no Playwright setup to reuse.

## Local tooling

- Node `v24.19.0`, npm `11.17.0` are installed on the Windows machine.
- Flutter 3.47.7 / Dart 3.13.5 as in S1. A `windows/` desktop runner folder
  exists locally; desktop runs are indicative only and never device evidence.
- The four real sample EPUBs are in `D:/Projects/lan-reader/docs/` (names in
  parent `research/reader-fidelity.md`). They are copyrighted novels: never
  commit, push, upload to CI or include their text in exports.
