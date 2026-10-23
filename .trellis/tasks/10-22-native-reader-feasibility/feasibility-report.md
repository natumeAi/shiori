# S2 native reader feasibility report (Phases A-E)

Status of each acceptance row is independent. Nothing here is device evidence:
all numbers come from the Windows development machine (`flutter test`, host
engine, Ahem test font) and from Windows WebKit/Chromium via Playwright.
Local Phases A-E are complete through commit `bf12416` (2026-10-23).
**GO / NO-GO for S4 remains explicitly undecided until the device run and
review of NC7-NC9.** No local pass implies iPhone cadence or presentation.
The user-operated next step is [the device runbook](device-runbook.md), after
the confirmed push. Phase F part 2 owns Trellis spec updates separately.

## Rows

| Row | Status | Evidence |
| --- | --- | --- |
| NC1 oracle | PASS locally (Phase A) | Two clean UTC/Asia/Hong_Kong generations: final 32 generated/attribute files byte-identical, zero source-filter mismatches. WebKit 27.2 / Chromium 156.0.8078.4; 13 fixtures, 39 sections, 4,807 sampled CFI points per engine; four local sample books, 60 sections, 168,677 samples, zero cross-engine differences. Vendored reference matches `a4bda23`. [Final reproducibility](evidence/oracle-final-reproducibility.json), [reference check](evidence/oracle-check-reference-final.json), [source-byte correction](local-validation.md#phase-a-post-staging-source-byte-correction), [final vector slimming](local-validation.md#post-phase-b-review-oracle-vector-slimming). Earlier 45-file results predate slimming. |
| NC2 source, CFI, canonical | PASS locally (B, re-run in C) | 256 reader-data tests; zero mismatches on synthetic and local-book vectors, including 168,677 local CFI samples. Native-exported vector CFIs resolve identically 4,807/4,807 per browser; Phase C adds 2,413 page anchors x 2 engines = 4,826/4,826. `xml` 7.0.1 re-verified. [Phase B results/test counts/gaps](local-validation.md#phase-b-evidence--2026-10-22), [Phase C](local-validation.md#phase-c--layout-page-map-anchors-detection). |
| NC3 conservation and matrix | PASS locally (Phase C) | Ten supported fixtures and the four local sample books pass all three gate settings; zero text loss/duplication/order/geometry failures. Tables and documented differences below. Three unsupported fixtures are refused recoverably, never opened empty. [Phase C evidence](local-validation.md#phase-c--layout-page-map-anchors-detection). |
| NC4 anchors | PASS locally (Phase C, D integration) | Every supported fixture page round-trips at three settings; four local sample books pass conservation/anchors; 2,980 visible oracle CFIs land; 2,413 native anchors resolve identically in both engines. Reflow/injected failure preserve the accepted anchor; Phase D adds turn-target proofs. [Phase C](local-validation.md#phase-c--layout-page-map-anchors-detection), [Phase D proof inventory](local-validation.md#ported-reference-inventory), details below. |
| NC5 motion state machine | PASS locally (Phase D) | Reference ports and native equivalents cover thresholds, easing, axis lock, rebound, late neighbor, 1+8 FIFO/overflow, rebase, cancellation/generation, proof-before-acceptance, reduced motion and lifetime/callback-work bounds. Implementation contributed 146 tests; review added lifecycle-resume regression. Whole suite 785 passed, 1 skipped after review. [Built/completed and port inventory](local-validation.md#phase-d--motion-controller-and-surfaces), [deferrals](local-validation.md#deferred-cases-and-native-substitutions), [review](local-validation.md#phase-d-review-and-independent-re-run). |
| NC6 harness and quality gate | PASS locally (Phase E) | Probe R01-R11, bounded/private v1 exports, independent analyzer parity over 12 synthetic exports, negative correctness/resource fixtures and fixture/privacy guard pass. Post-review format: 253 files, 0 changed; analyze: no issues; whole suite: 969 passed, 1 skipped, all exits 0. Existing product/S1 tests pass. [Phase E implementation/gate](local-validation.md#phase-e--probe-harness-analyzer-native-spike-ci), [independent review/final gate](local-validation.md#phase-e-independent-trellis-check-review--2026-10-23). Swift/IPA execution remains unverified, not a claimed local result. |
| NC7 device scenarios | pending device run | Populate from default-IPA R01-R10 three limiter-off repeats each, R11 one >=50-accepted-turn manual run per local book, plus actual OS lifecycle supplement. Record independent UI/raster budgets, warm-submission P95, unexplained stalls, correctness, R10 >=100-turn resource trends, cold/queue/fallback data, omissions and provenance. See runbook sections 4-7. |
| NC8 presentation evidence | pending device run | Per-mode availability/omissions, inventory, A1 commits, A2 period bins and observer perturbation, B system drawable times on the CAMetal variant; loss counters and one-plus-one iteration time box. No native result or touch-to-photon claim yet. See runbook section 6. |
| NC9 GO / NO-GO | pending device run | Review every row independently after NC7/NC8 evidence arrives; state the S4 decision and specific gaps. **S4 GO / NO-GO is undecided**, not conditionally granted by the local passes. |

## Local validation checkpoints

These are historical sequential gates, not additional device runs. Codegen,
format, analysis and tests passed at each completed phase; the linked log
retains the exact command scope and timeout. Later reviews supersede test
counts without rewriting earlier JSON.

| Checkpoint | Whole-suite result | Evidence |
| --- | --- | --- |
| Baseline / Phase A | 91 passed | [Baseline](evidence/quality-gate-0.json), [corrected A](evidence/quality-gate-A-source-lf.json) |
| Phase B | 347 passed; 256 reader-data tests | [Phase B](local-validation.md#phase-b-evidence--2026-10-22) |
| Phase C | 638 passed, 1 skipped | [Phase C gate](local-validation.md#phase-c-gate-sequential) |
| Phase D implementation -> review | 784 -> 785 passed, 1 skipped | [D JSON](evidence/quality-gate-D.json), [review](local-validation.md#phase-d-review-and-independent-re-run) |
| Phase E parts 1 / 2 / 3a / 3b | 823 / 869 / 918 / 962 passed, each 1 skipped | [Verification chain](local-validation.md#phase-e-execution-and-verification-chain), [3b JSON](evidence/quality-gate-E.json) |
| Phase E independent review | 969 passed, 1 skipped; zero failures | [Final gate](local-validation.md#phase-e-independent-trellis-check-review--2026-10-23) |

## NC3: conservation

Viewport 430x932 logical (content box 334x812 at the defaults), C1 `CssStyleResolver`.
Settings: D = defaults; L = font size 26 + line height 2.0; M = font size 14 +
letter spacing 0.12 em + horizontal margin 48. Every cell passed: page text in
order equals the eligible source text, paragraph maps reproduce text from source,
lines placed once in order, each image/SVG placed once or listed, nothing crosses
the content rectangle. Pages are summed over a fixture's sections.

| Fixture | Sections | D pages | L pages | M pages | Source characters |
| --- | ---: | ---: | ---: | ---: | ---: |
| cfi-structure | 1 | 1 | 1 | 1 | 70 |
| html-fallback | 5 | 5 | 5 | 5 | 29 |
| inert-content | 1 | 1 | 1 | 1 | 19 (SVG placed, math surfaced) |
| opf-variants | 4 | 4 | 4 | 4 | 45 |
| unicode | 1 | 1 | 1 | 1 | 57 |
| styles | 1 | 2 | 4 | 2 | 191 |
| images | 3 | 4 | 5 | 4 | 35 (6 images/SVG) |
| long-content | 3 | 546 | 1530 | 504 | 264,923 |
| chapters | 16 | 16 | 48 | 16 | 5,550 |
| one-page | 1 | 1 | 1 | 1 | 6 |

Four local books at all three settings D/L/M (digests only, no text; D pages shown): `6e4ed2a78ea6` 3
sections / 20 pages / 5,278 characters / 2 images; `aac482b2d33f` 3 / 36 / 9,622
/ 1; `a595d98d4400` 33 / 347 / 86,475 / 0; `9bfc26bc676d` 21 / 443 / 128,385 / 14
(SVG wrappers). All passed with zero unsupported items. A negative test shows the
check fails when expected text is withheld.

### Style matrix outcomes (resolver and layout merged)

| Area | Outcome |
| --- | --- |
| `p`, `div`, `h1`-`h6`, `blockquote`, `section`, `figure`, `hr` | Supported (UA margins, author margin/padding, backgrounds behind text lines, hairline rule). |
| `ul`/`ol`/`li` | Supported with difference: marker is generated text inside the item (not hanging). `list-style-type` (none, disc, circle, square, decimal, lower/upper alpha and roman; UA disc/circle/square nesting, decimal for `ol`), `ol start` and `li value` honored; markers are synthetic (no CFI or canonical slot). |
| `span`, `b`/`strong`, `i`/`em`, `a`, `br`, `small` | Supported. |
| `sup`/`sub` | Supported with difference: smaller size, no baseline shift. |
| `ruby`/`rt`/`rp` | Supported with difference: annotation text is author source text with its coordinates, set inline at half size; generated parentheses (synthetic) only when no `rp` exists. |
| margin, padding, text-indent (incl. `em`), text-align incl. justify, `display` | Supported. Negative margins are ignored. |
| font-size units and keywords, weight, style, family, line-height, letter-spacing, colors | Supported. Reader overrides follow `useReaderSettings.ts`. |
| `@font-face` (linked sheet and inline `<style>`) | Supported: real archive paths, loaded with `loadFontFromList`; both fixture faces load. Non-sfnt (WOFF) fonts and missing files are recorded, not fatal. |
| `white-space` normal / pre / pre-wrap / pre-line / nowrap | Supported for space and newline handling; `pre` and `nowrap` still wrap at the content width (difference `nowrap-wraps`). |
| `img` (width/height/max-width, taller than page) | Supported; contained to content width and page height; undecodable, missing and remote images become listed markers. |
| SVG wrapper around a full-size raster (guard `contentImage.ts:403`) | Supported; nine guard-refusal cases fall to vector; outer `svg` is the anchor. |
| Vector SVG | Supported through `flutter_svg` for shapes/paths (pixel-tested); `text`, `foreignObject`, filters and external images are not painted: listed as `svg-partial` with a corner badge. |
| Tables | Surfaced-unsupported with text flow: flattened to blocks, marker plus `table` entry. |
| `math`, `video`, `audio`, `canvas`, `object`, `embed`, `iframe` | Surfaced-unsupported: marker plus list entry. |
| Borders, `text-transform`, `::before`/`::after` content | Not rendered (see gaps). |

### Unsupported-layout detection (C1, `engine/support`)

| Cue | Result |
| --- | --- |
| `rendition:layout` pre-paginated (package, itemref property, display-options file) | fixed layout, refused |
| spine `page-progression-direction="rtl"` | refused |
| vertical `writing-mode` on root or any rendered element (vendor aliases included, undisplayed ones ignored) | refused, section named |
| `dir="rtl"` / computed `direction: rtl` on root or body; RTL publication language without explicit direction | refused |
| isolated RTL run inside an LTR section | supported, counted informationally |
| fixtures `unsupported-fixed`, `unsupported-vertical`, `unsupported-rtl` | refused with their reasons; the ten supported fixtures and the four books are supported |

`requireSupported()` throws `UnsupportedLayoutException`; the accepted in-memory
anchor is not touched by detection.

## NC4: anchors

- Round trip: for every page of every supported fixture at all three settings the
  exported anchor (reference midpoint policy, image-element fallback) proves and
  resolves back to the same page with its glyph or image box inside the content
  rectangle (2,580 anchors for `long-content` alone; four books: 20 + 36 + 347 +
  443 anchors, every page).
- Oracle landing: 2,980 WebKit vector CFIs whose resolved start is laid out all
  prove, and the page's source spans contain the node/offset; 1,693 samples are in
  the head or hidden text and are not rendered.
- Interop loop: 2,413 native page-anchor CFIs fed to `npm run resolve`; WebKit and
  Chromium resolve to the native node/offset 4,826/4,826.
- Reflow: the accepted anchor remains provable and visible after font size 22,
  size 22 with line height 2.0, size 14 with line height 1.3 and letter spacing
  0.08, and margins 36/24; `reflow` never rewrites the accepted CFI.
- Injected proof failure: `accept`, `acceptPage` and `reflow` keep the previous
  CFI. No page-one, nearest-paragraph or percentage fallback exists.
- Coverage limitation: `notVisible` and `roundTrip` rejections have no natural
  trigger with whole-line packing; only the injected path exercises rejection.
  Phase D now supplies local turn-target proof tests (inventory below); device
  visibility and physical behavior remain pending.

## Fonts

Reader font options map to iOS families (`font_mapping.dart`): system stack to the
platform default; PingFang SC/TC/HK as is; Microsoft YaHei, Heiti SC and Noto Sans
CJK to PingFang SC; SimSun and Noto Serif CJK to Songti SC; KaiTi to Kaiti SC;
`serif` to Times New Roman. The chain is recorded per section
(`PreparedSection.fontChains`); Flutter cannot report which family actually
rendered. The four local books reference fonts missing from their archives
(diagnosed as `stylesheetNotFound:@font-face`, 57 occurrences in three books; the fourth only has 42 ignored `border-radius` declarations) and so use the
mapped families.

## Host timing (indicative, host-only)

The 100,000-code-unit CJK paragraph: 5,556 lines, 199 pages at the defaults;
`Paragraph.layout` median about 5.5-10.6 ms over repeated runs (cold first call
30-60 ms); whole-section preparation (layout, line table, paging) about 25-52 ms.
Font was Flutter's test font Ahem (every glyph a square), so shaping cost is far
below a real CJK font. These numbers say nothing about iPhone cost; the device run
owns that.

## Phase D: motion controller and prepared surfaces

The local core uses reader-local numeric motion and repaint-only Flow
transforms over retained page pictures. Tests cover the frozen admission ruler,
axis lock, thresholds, flick/reversal/rebound, tap zones/easing/settlement,
late neighbor admission, 1+8 FIFO with explicit overflow, accepted-origin
rebase, lifecycle cancellation/resume, stale-generation rejection and exactly
one proven destination per committed input. Reduced motion and static fallback
are explicit outcomes; no real position/history persistence was added.

Prepared surfaces have three presented owners plus one reserve, counting
pending owners; picture and decoded-image caps are 16 MiB and 48 MiB. Lease
and decode tests check disposal, close and late callbacks. A debug work guard
rejects parsing, shaping, decoding, font loading, pagination, canonical
traversal, archive reads and JSON projection in pointer/ticker zones; its 38
tests cover real entry calls and all nine work categories. This is local
correctness/isolation evidence, not a measurement of phone callback cost.

The [port inventory](local-validation.md#ported-reference-inventory) records
all eight reference test families and their native equivalents. Browser
pointer-capture hooks, fixed-layout frame proof, mutable DOM cache invalidation
and product image hit-testing/viewer cases are explicitly deferred or replaced
by native preparation/lifetime tests with reasons in
[deferred cases](local-validation.md#deferred-cases-and-native-substitutions).
They are not silently counted as implemented product features.

The implementation gate in [evidence/quality-gate-D.json](evidence/quality-gate-D.json)
is preserved at 784 passed / 1 skipped. Independent review fixed the real
background/foreground resume bug and added a widget regression; the final
coordinator gate was **785 passed / 1 skipped**, format 196 files / 0 changed,
analyze no issues. The warm/prepare race remains a bounded S4 hardening item
below. [Phase D review](local-validation.md#phase-d-review-and-independent-re-run).

## Phase E: harness, analyzer, guard and packaging

- **Probe and recorder:** the isolated `lib/main_probe.dart` app retains S1
  capture and adds `阅读器可行性探针`, bundled fixtures, top-level Documents
  EPUB inventory by SHA-256, settings/reflow/jumps, scripted R01-R10 and manual
  R11. Scripted moves inject at most one move per actual frame, without catch-up.
  R09 explicitly simulates the controller/session lifecycle; R11 has no scripted
  substitute and requires >=50 accepted turns in one capture per book.
- **Export:** `kind: reader_feasibility`, schema version 1, with nested engine
  timings, reader events, layout costs, resource snapshots and native report.
  `shiori-reader-<BUILD_ID>-<runId>.json` is written to Documents; the bounded
  clipboard summary identifies it. Book/page identities are digests, not text,
  titles, assertion CFIs or user filenames. Correctness joins include capture
  epoch plus input ID, and carry explicit commits, active generation, proof and
  hashed destination. Event loss/missing fields cannot prove a passing absence.
- **Analyzer parity:** twelve app-produced synthetic exports have independently
  recomputed reader/engine aggregates; the unknown-schema fixture is deliberately
  rejected. Double acceptance and cap breach fail their measurement gates with
  aggregate parity intact. The bounded 100-turn fixture passes correctness and
  resource rows; the legacy 100-turn record remains unavailable for missing
  capability/caps. Privacy tests also check fixture prose, filenames and CFIs.
  `--strict` checks aggregate mismatches, not measurement-gate exit status.
- **Native spike:** diagnostic-only install/start/stop/dispose and inventory,
  A1 layer-commit cadence, A2 auxiliary-display-link periods, and B drawable
  callbacks have local Dart/channel tests and pinned-engine source review.
  Hooks are lazy; registration alone neither installs them nor allocates the
  sampling buffer. A1/A2 require exact FlutterMetalLayer; B requires exact
  CAMetalLayer plus explicit false flag. None was compiled or run on iOS here.
- **Fixture/privacy guard:** the real repository and 17 guard tests pass. Git's
  tracked plus nonignored-untracked inventory is checked before building,
  including tracked ignored files. Only the asset manifest and the two exact
  hashed Phase B source-edge EPUBs are allowed; new files, drift, invalid
  manifests, traversal/duplicates or symlink payloads fail closed. It does not
  exempt the source-edge directory wholesale.
- **Packaging:** shell syntax passes. The script retains the lockfile/pin and
  arm64/bundle checks, builds `lib/main_probe.dart` once, and packages unchanged
  default and false-flag CAMetal copies. Both are revalidated, ZIP-tested and
  entered in `sha256.txt` and provenance with actual/effective Metal-layer flag.
  The existing workflow upload covers both IPAs. This is verified source/syntax,
  not a successful hosted/macOS build.

[Phase E implementation, fields, scenarios and gate](local-validation.md#phase-e--probe-harness-analyzer-native-spike-ci)
contains the measured details. The preserved
[evidence/quality-gate-E.json](evidence/quality-gate-E.json) has seven successful
commands and **962 passed / 1 skipped** before review. The independent review
fixed cross-epoch input joins, unhandled native-stop completion errors, explicit
block bridging and unmatched-callback accounting. Its post-fix gate is **969
passed / 1 skipped**, 253 formatted files / 0 changed, analyze no issues, shell
syntax and fixture guard passing; export fixtures remain unchanged.
[Review and final gate](local-validation.md#phase-e-independent-trellis-check-review--2026-10-23),
[execution chain and retained decisions](local-validation.md#phase-e-execution-and-verification-chain).
Existing ordinary-app and S1 tests remain green; no product route/entry behavior
change or product persistence is claimed.

### Local-only switches and evidence boundaries

The sole final-suite skip is `native_cfi_export_test.dart` without
`SHIORI_NATIVE_CFI_OUT`; setting it enables local native-CFI file generation
for the oracle interop loop. The optional four-book tests depend on private
`build/oracle-local/` vectors and the local source directory; they ran in the
recorded local gates. Neither those vectors nor private books enter CI.
`REGENERATE_READER_EXPORTS=1` deliberately regenerates synthetic analyzer
fixtures; ordinary tests check them without rewriting. This documentation
session does not regenerate either corpus.

The [31-file evidence index](evidence/README.md) preserves each raw JSON and
its SHA-256 relocation manifest. Historical pre-review gates are not edited
to look like later runs; later counts are linked to their validation sections.

## Unverified until CI / device

- Swift compilation, channel/hook integration, block/IMP ABI and ARC ownership,
  callback identity across captures, and actual hook overhead with the pinned
  engine. Local method-channel tests do not execute Swift.
- Hosted macOS `plutil`/`lipo`, single-build/two-IPA execution, both complete
  IPAs, checksums/provenance/artifact creation, signing, launch, update and
  re-sign retention for S2. S1 proved its marker retention only.
- The Files import direction for the four local sample books and all S2 raw
  device exports: real R01-R11, limiter-off repeat coverage, manual >=50-turn
  book captures, actual OS lifecycle, CJK shaping/raster/font behavior and
  >=100 alternating-turn resource/RSS behavior.
- Native A1/A2 cadence, auxiliary-display-link perturbation and B drawable
  callbacks on the nondefault path. Product physical presentation and
  touch-to-photon remain unverified. NC7-NC9 and the S4 decision remain pending.

## Carry-forward to later stages

The four Phase A/B review items below are copied from `implement.md`:

- **S3:** `lib/features/reader/data/epub/epub_archive.dart` checks ZIP sizes
  declared in headers; `archive` inflates a whole entry before the length
  check, so a hostile EPUB can briefly allocate past the limit. Add bounded or
  streamed inflation and parse in a worker isolate before opening downloaded
  books.
- **S4:** `assets/reader_fixtures/` is registered in the shared `pubspec.yaml`,
  so product builds also carry ~1.2 MB of synthetic fixtures. Move them behind
  the diagnostic entry point (or out of product assets) before a product build.
- **S4:** `FontRegistry` (`engine/layout/font_registry.dart`) never unloads
  fonts (the engine cannot); each font is capped at 32 MB but the count is
  unbounded across books. Bound it per reading session or restart policy.
- **S4:** known HTML-mode parser gaps (head-level `<template>`, `<noscript>`
  content that closes an open `<p>`, attribute URLs in script-enabled
  `<noscript>` raw text) are listed in `local-validation.md`; add fixtures if
  the NAS library contains such books.

Additional retained review items:

- **S4, low severity (Phase D):** `PreparedReaderSession.warm()` coalesces warm
  calls per direction, but a concurrent controller `prepare()` for the same
  target can briefly hold another lease. The 3+1 cap bounds it; over-cap work
  becomes a static-fallback prepare failure, not a leak. Coalesce warm/prepare
  work during S4 hardening. [Review](local-validation.md#phase-d-review-and-independent-re-run).
- **Native diagnostic follow-up (Phase E, kept by decision):** deprecated
  `OSAtomic*` calls remain; replacing synchronization without a Swift compiler
  was judged riskier. Verify compiler warnings/runtime behavior in CI/device
  before choosing a replacement. This local review did not compile Swift.
- **Device judgement (Phase E, kept by decision):** the 5% RSS rule bounds both
  endpoint growth and projected OLS growth over the captured duration relative
  to positive first RSS. It is observational, not specified numerically by NC7
  and not proof of no per-cycle/indefinite growth. Judge against device data,
  including R10's cold start/warm-up and actual alternating-cycle coverage;
  retain observed failures and do not silently change the gate.

## Known differences and gaps

- `sup`/`sub`: no baseline shift.
- Borders (and `border-radius`) and `text-transform` are not rendered.
- `::before` / `::after` generated content is not rendered.
- Tables are flattened to blocks with a visible marker.
- `white-space: pre`/`nowrap` wrap at the content width.
- List markers are inline generated text, not hanging.
- Block backgrounds are painted behind text lines only (no padding/margin boxes).
- Inline images split their paragraph into text, image block, text.
- SVG `text`, `foreignObject`, filters and external images are not painted.
- Songti SC, Kaiti SC and Heiti SC availability on iOS is unverified; the family
  mapping and fallback chain need the device run.
- `Paragraph.getLineBoundary` costs time linear in the paragraph per call (about
  2 ms at 100,000 units on the host); the line table uses `getLineNumberAt` with
  galloping and bisection instead. Whether device cost behaves the same is unknown.
- CJK newline segment-break rules are not applied (newlines collapse to spaces).
- No locale is set on paragraphs (Han glyph variants follow the system).
- Windows WebKit is not the iPhone's Safari; iPhone parsing behaviour is unverified.
- `xml` is held at 7.0.1 because every `flutter_svg` release requires `xml <=7.0.1`.
