# Design: native reader feasibility (S2)

Requirements and acceptance live in `prd.md`. Contracts inherited from the
parent are in `../10-22-flutter-lan-reader-parity/design.md` §5–§6 and
`research/native-reader-contracts.md`; this document refines them for S2 and
does not repeat their constant tables. Where this document and the reference
source disagree, the reference source at the pinned commits wins and the
disagreement is reported.

## 1. Scope and module map

S2 builds the reusable reader core (pure Dart data + Flutter engine) and a
diagnostic harness around it. S4 later wraps the same core in product UI,
persistence and activity tracking.

```text
lib/features/reader/data/epub/          container.xml, OPF, manifest, spine, nav/NCX
lib/features/reader/data/source/        source tree, parser selection, inert projection
lib/features/reader/data/cfi/           CFI AST, parser, serializer, compare, resolve
lib/features/reader/data/canonical/     normalization v1, Unicode table, FNV-1a64, maps
lib/features/reader/engine/style/       CSS subset, cascade, reader overrides
lib/features/reader/engine/layout/      blocks/inlines, paragraph building, images
lib/features/reader/engine/pagination/  page plans, page map, anchors, proofs
lib/features/reader/engine/motion/      gesture rules, turn engine, queue, controller
lib/features/reader/engine/surface/     prepared page surfaces and their lifetimes
lib/features/diagnostics/.../reader_probe/  probe screens, scenario runner, export
lib/core/diagnostics/                   shared recorder pieces (extended, not broken)
ios/Runner/                             diagnostic-only presentation probe (Swift)
tool/oracle/                            Node + Playwright oracle, fixture builder
tool/diag/                              offline export analyzer (Dart CLI)
assets/reader_fixtures/                 built synthetic fixture EPUBs only
test/fixtures/reader/                   committed oracle vectors and exports
```

Rules:

- `data/` and `engine/` contain no Riverpod providers and no widgets except
  in `engine/surface/`; they are plain Dart with injected clocks/resources so
  S4 can reuse them. `engine/` may import `dart:ui`; `data/` must not, so
  it can run in a worker isolate.
- `features/diagnostics` imports the reader core; the reader core never
  imports diagnostics. Timing hooks are an injected sink interface owned by the
  reader engine, implemented by the probe.
- `core/` keeps importing no feature code. Any recorder generalization stays
  backward compatible with S1's `DiagnosticRecord` schema v1 and its tests.
- The product entry point (`lib/main.dart`) and product routes do not change.

## 2. Oracle tooling and fixture corpus

### 2.1 Tool layout

`tool/oracle/` is a self-contained Node ESM project with a committed
`package-lock.json` and exact versions:

- `foliate-js` from the same codeload tarball URL as lan-reader
  (`78914aef…`), `fflate` `0.8.2`, a bundler (esbuild) and `playwright`.
- `reference/lan-reader-a4bda23/` holds vendored copies of
  `client/src/utils/canonicalText.ts`, `client/src/reader/contentSecurity.ts`
  and the one shared constant `canonicalText.ts` imports, each with a header
  naming source path and commit. `npm run check-reference` compares them with
  `git -C $LAN_READER_DIR show a4bda23:<path>` when the checkout is present
  (default `D:/Projects/lan-reader`) and fails on drift. Any other reference
  logic needed (for example `visiblePageAnchor.ts`) is vendored the same way.
- A page bundle replicates `foliateEngine.ts:461`: `unzipSync` → `EPUB`
  loader (`loadText` via `strFromU8`, `loadBlob`, `getSize`) → `book.init()`,
  then per section the same document load path, then the inert projection.
  The executor reads `foliateEngine.ts` around `:440–:497` and `:259–:400` to
  copy the exact order of operations rather than re-deriving it.
- Playwright drives WebKit (closest available engine to iOS Safari; primary)
  and Chromium (cross-check). Outputs record both browser versions. Browser
  binaries live in Playwright's cache, never in the repository.

Commands (all from `tool/oracle/`): `npm ci`, `npx playwright install webkit
chromium`, `npm run build-fixtures`, `npm run vectors`, `npm run resolve --
<cfi-list.json>`, `npm run vectors-local -- <epub...>`, `npm run
check-reference`.

### 2.2 Vector schema (versioned, `oracleSchemaVersion: 1`)

Per fixture EPUB: provenance (fixture digest, tool versions, engine name and
version, reference commits); package (OPF path, spine items with `idref`,
`href`, `linear`, section index and Foliate CFI base; nav/NCX TOC entries
with resolved hrefs); per section:

- parser used (`xhtml` or `html-fallback`) and the parse error text class;
- depth-first projected node list after the inert projection: node kind
  (element/text/cdata/comment/pi), namespace URI, local name, `id`, parent
  index, child slot, text content for character data;
- canonical result: version, length, `fnv1a64:` signature, per text node
  canonical start and the canonical→UTF-16 start map;
- CFI samples: for chosen points (every text node start/end, interior
  offsets including both halves of surrogate pairs, whitespace-only nodes,
  element anchors for `img`, outer `svg`, nested `image`, headings), the
  Foliate CFI string, its parsed AST, and the resolution back to
  `(node index, offset)` for collapsed and range forms;
- comparison vectors: a shuffled list of CFIs and Foliate's sorted order;
- grammar vectors: escaped ids/assertions, indirection, ranges and malformed
  strings with Foliate's parse result or error.

Committed vectors are pretty-printed with sorted keys so diffs are reviewable
and reruns are byte-identical. Local book vectors go to
`build/oracle-local/` (gitignored) and include only structure, offsets,
lengths and digests; they may contain short text excerpts only in local files.

### 2.3 Synthetic fixture corpus

Fixture sources are hand-authored, non-copyrighted XHTML/OPF/CSS under
`tool/oracle/fixtures/<id>/`. `build-fixtures` produces deterministic EPUBs
(stored `mimetype` first, fixed timestamps, sorted entries) into
`assets/reader_fixtures/` plus `manifest.json` with SHA-256 per file. Generated
filler text is deterministic (numbered CJK/Latin sequences), not book prose.
Images are generated (small PNG/JPEG); any embedded font must carry an
OFL/Apache licence recorded next to it.

| Fixture | Exercises |
| --- | --- |
| `cfi-structure` | adjacent text separated by comments/CDATA, empty/whitespace nodes, nested inlines, escaped ids, entities and NBSP |
| `html-fallback` | malformed XHTML forcing the HTML parse; `&nbsp;` with and without an XHTML DOCTYPE |
| `inert-content` | script/style/noscript/template, iframe/object/embed with children, forms, SVG with script, `on*` attributes |
| `opf-variants` | spine not at `/6`, `linear="no"`, nav and NCX, non-default OPF location, odd hrefs (spaces, percent-encoding, `../`) |
| `unicode` | supplementary characters, emoji ZWJ, combining marks, Cf (U+200B, U+00AD, U+FEFF), U+3000, CR/LF and CR-only line ends |
| `styles` | the style matrix in §5.2, ruby, sup/sub, `!important`, class/type/descendant selectors, `:not(:last-child)`, embedded font |
| `images` | raster `img`, SVG wrapper around a full-size raster matching the sample shape, real vector SVG with shapes and text, image-only section, cover |
| `long-content` | a long chapter (≥ 30 pages at default settings), one CJK paragraph of ≥ 100,000 characters without spaces, one long unspaced Latin token |
| `chapters` | many short sections for boundary crossing; a one-page book |
| `unsupported-fixed` | `rendition:layout` `pre-paginated` |
| `unsupported-vertical` | `writing-mode: vertical-rl` and `page-progression-direction="rtl"` |
| `unsupported-rtl` | `dir="rtl"` content with `page-progression-direction="rtl"` |

The same EPUBs are bundled as Flutter assets for the device probe.

## 3. Source model and parsing (`data/epub`, `data/source`)

- Container: read `META-INF/container.xml`, the OPF, manifest, spine and TOC
  from a pure-Dart ZIP reader with entry-size and total-expansion limits.
  Decode every text resource as UTF-8 with replacement, as `strFromU8` does.
- Parser selection per section mirrors `epub.js:817`: parse by manifest media
  type; for XHTML, a well-formedness failure (matching the browser's
  `parsererror` decision on the oracle corpus) falls back to HTML parsing.
  Entity handling with and without the XHTML DOCTYPE is decided by the oracle
  vectors, not by parser defaults.
- Source tree: immutable nodes with stable indices, kind, namespace, local
  name, attributes, parent/child links and UTF-16 text. Comments, PIs and
  CDATA are retained as their own kinds (CFI and canonical treat them
  differently).
- Inert projection: an explicit, separately testable transform matching the
  vendored `contentSecurity.ts`; it produces the tree CFI and canonical
  indexing operate on. The original tree stays available. No script runs and
  no remote resource is fetched.
- Archive parsing, source trees and canonical indexing are pure Dart and may
  run in a worker isolate (`Isolate.run`); results crossing isolates are plain
  transferable data.

## 4. CFI and canonical index (`data/cfi`, `data/canonical`)

CFI: a grammar-aware parser and serializer for the pinned `epubcfi.js`
behavior (steps, `!` indirection, `^` escapes, id assertions and retained
unsupported assertions, ranges with parent/start/end), structural comparison,
and resolution against the projected tree with even/odd slot rules, merged
Text/CDATA chunks, virtual edge slots and UTF-16 offsets. Section bases come
from actual OPF itemrefs (`epub.js:677`, `:688`), never `/6/<arithmetic>`.
Unsupported assertion kinds are preserved verbatim, not dropped. The exact
behavior table is parent `research/native-reader-contracts.md` §2.

Canonical v1: walk eligible Text nodes as `canonicalText.ts` does; filter with
a generated code-point range table for `White_Space`, `Cc`, `Cf`, `Cs`.
`tool/oracle` generates the table from the WebKit engine (and records the
Chromium table difference, if any) together with the engine's Unicode version;
the Dart table is generated source with a header naming that provenance.
FNV-1a64 over UTF-8 uses explicit 64-bit-safe arithmetic (two 32-bit limbs or
`BigInt` in tests) and is checked against `readingActivityText.test.ts` vectors
plus oracle signatures. Canonical and CFI coordinates stay separate types so
they cannot be mixed up.

## 5. Native layout and page map (`engine/style`, `engine/layout`, `engine/pagination`)

### 5.1 Pipeline

1. Style: parse packaged CSS (author sheets and `style` attributes) into a
   bounded selector/property subset; cascade with origin, specificity, source
   order and `!important`; inherit; then apply the reader overrides with the
   precedence of `useReaderSettings.ts:249` (skipping typography overrides
   exactly where the reference does).
2. Block/inline model: block boxes with margins/padding/indent/alignment;
   inline runs with style; `br` and whitespace handling recorded as explicit
   mapping entries; images as block or inline placeholders; list markers and
   ruby annotations as synthetic runs with no CFI/canonical slot.
3. Paragraph building on the root isolate with `ui.ParagraphBuilder`, keeping
   a paragraph-offset ↔ (source node, UTF-16 offset) map per run. First-line
   indentation placeholders are synthetic.
4. Line packing: lay out at the final content width once, read line metrics
   and boundaries, and pack whole lines, block gaps and image boxes into pages
   of the content height. Paragraphs are sliced by line ranges; slices are
   painted clipped and translated, never re-laid-out per page.
5. Page plan: immutable list of fragments (paragraph slice, image box,
   decoration) plus a page map entry: first/last source positions, candidate
   canonical intervals of complete clusters fully inside the page, image
   anchors, section and layout identity. Candidate intervals are geometry
   facts for S4, not reading observations.
6. Incremental preparation: current section first, then neighbors, yielding
   between paragraphs. Section page counts may stay unknown until laid out.

Layout identity covers fixture/book digest, section, parser/normalizer/style
versions, viewport and insets, DPR, font readiness, every typography setting
and layout generation. Theme-only changes repaint without repaginating.

### 5.2 Style matrix

Record an outcome per row in the report: supported, supported with a stated
difference, or surfaced-unsupported (shown as a visible marker plus a
diagnostic event; its text, if any, still flows).

| Area | Cases |
| --- | --- |
| Blocks | `p`, `div`, `h1`–`h6`, `blockquote`, `ul`/`ol`/`li`, `hr`, `section`, `figure` |
| Inline | `span`, `b`/`strong`, `i`/`em`, `a`, `br`, `small`, `sup`/`sub`, `ruby`/`rt`/`rp` |
| Box | margin, padding, text-indent (incl. `em`), text-align incl. justify, `display: none/block/inline` |
| Text | font-size (`px`, `em`, `rem`, `%`, keywords), font-weight, font-style, font-family incl. embedded `@font-face`, line-height, letter-spacing, color, background-color, `white-space` normal/pre/pre-wrap |
| Images | `img` with width/height/max-width, SVG wrapper fast path, vector SVG, image-only page, image taller than a page (contain to page) |

The six reader font option IDs map to recorded iPhone fallbacks; the report
states which family actually rendered. Matching a slider value is not
typographic parity.

### 5.3 Images and SVG

Decode images off the motion path (`ui.instantiateImageCodec` or
`ImmutableBuffer`-based decoding during preparation) with byte-bounded
caches. The SVG wrapper fast path applies only under the reference guard
(`contentImage.ts:403`: single full-size `image`, no transform/crop/mask/
filter/multiple graphics) and keeps the outer `svg` identity as the anchor.
Other static SVG goes through the evaluated Flutter SVG renderer; if a
construct cannot be rendered, surface it, never strip it. SVG text stays
excluded from canonical statistics.

### 5.4 Long paragraphs

A paragraph layout call is synchronous. Measure the ≥100,000-character
fixture on device first. Only if it threatens preparation budgets, prototype
windowing at verified boundaries and prove with tests that windowed output has
no lost/duplicated/reordered code units and no shaping change at the seams
(compare glyph runs around each seam against an unwindowed reference layout).
Report the indivisible cost either way.

### 5.5 Unsupported layout detection

Before enabling reading, inspect OPF metadata (`rendition:layout`,
`rendition:spread` and the like), spine `page-progression-direction`,
document/root `dir`, and computed `writing-mode`/`direction`. A detected
fixture opens a recoverable explanation and leaves the in-memory accepted
anchor untouched. Mixed content (one vertical section) is reported per
section and blocks reading in S2.

### 5.6 Conservation check

A test-time and probe-time check walks every page of a laid-out section and
asserts: page text in order equals the eligible source text after the
documented whitespace mapping; each image/SVG appears exactly once or is in
the surfaced-unsupported list; no line box or image crosses the content rect.
It runs for each fixture and local book at default and at least two
non-default settings (for example font size 26 + line height 2.0, and font
size 14 + letter spacing 0.12 em + margin 48).

## 6. Position anchors and proof

- Export: the reference policy (`visiblePageAnchor.ts`, `foliateEngine.ts:350`)
  — the first non-whitespace character nearest the visible text midpoint,
  falling back to a verified image element on image-only pages — serialized as
  a CFI with UTF-16 offsets.
- Resolve: CFI → projected node/offset → paragraph offset → line → page. If
  the offset falls inside a cluster, use the owning complete cluster for
  visibility, but keep the imported offset unchanged.
- Proof before acceptance: structural round trip (`resolve → export` of the
  same point compares equal), section and layout identity match, and the
  anchor's glyph or image box lies within the foreground page content rect.
  A turn target additionally matches origin, layout generation, section and
  target page identity.
- Reflow: settings or viewport change invalidates layout, keeps the accepted
  CFI, lays out again and accepts only after the proof succeeds; failure keeps
  the old accepted CFI and reports the failure. No page-one, nearest-paragraph
  or percentage fallback replaces it.
- Interop loop: native-exported CFIs for every page of every fixture are
  written to a list and fed to `npm run resolve`; Foliate must resolve each to
  the same node/offset.

## 7. Motion controller (`engine/motion`, `engine/surface`)

- Port `pageTurnGesture.ts` and `pageTurnEngine.ts` as pure functions with the
  constants in parent `research/native-reader-contracts.md` §4, and the
  admission/queue/proof/acceptance semantics of `readerController.ts`
  (current intent + at most eight FIFO waiting intents, explicit overflow,
  rebase on the latest accepted origin, cancellation on settings/layout/
  background/close, stale-callback rejection by generation token, accepted
  turns stay accepted if a later callback fails).
- Surfaces: previous/current/next prepared page surfaces, each owning a
  recorded `ui.Picture` (or equivalent retained layer) created during
  preparation. Motion only updates a numeric offset held by a reader-local
  `ValueNotifier`/`AnimationController`; the moving subtree is stable and
  repaint-isolated. No Riverpod rebuild per tick.
- Forbidden inside pointer/ticker callbacks: parsing, paragraph layout, image
  decode start, font load, pagination, canonical traversal, storage, JSON
  serialization. A debug-mode assertion guard enforces this for engine entry
  points.
- Late neighbor: if the incoming surface is not ready at admission, follow
  the finger and run the 80 ms catch-up once ready; if preparation fails, a
  verified static turn is allowed and counted as a static fallback.
- Reduced motion skips animation and still proves and accepts.
- Resource bounds: at most three live surfaces plus a declared small reserve;
  byte-bounded picture/image caches; everything disposed when its lease ends.

## 8. Reader probe, scenarios, export and analyzer

### 8.1 Probe app

`main_probe.dart` gains a probe home with two entries: the existing synthetic
capture (unchanged) and reader feasibility. Reader feasibility lists bundled
fixtures and `*.epub` files the user placed in Documents (Files app → On My
iPhone → Shiori). Opening runs the §5.5 detection, prepares the book, and
shows the paged reader with minimal probe controls: the reference reader
settings (font option, size, line height, letter spacing, margin, theme,
reduced motion), jump to section, scenario selection with repeat count,
capture start/stop, export and copy summary. Strings are localized (zh ARB)
per the widget guidelines. Diagnostic controls stay out of the product app.

### 8.2 Scenarios

Scripted scenarios inject pointer events through `GestureBinding` on a
frame-driven schedule (move events once per frame at 120 Hz cadence, realistic
velocities), so they exercise the real gesture path. Each run records
`input: synthetic_injected`; manual runs record `input: manual_touch`.

| ID | Scenario (≥ 3 repeats each) | Fixture |
| --- | --- | --- |
| R01 | 40 tap-next then 40 tap-previous | `long-content` long chapter |
| R02 | slow drag + settle, flick, reverse-before-release, rebound at first and last page | `chapters` |
| R03 | held finger with a cold neighbor (late-neighbor catch-up) | `long-content` |
| R04 | rapid queued turns including queue overflow, then a programmatic section jump | `chapters` |
| R05 | cold and warm chapter crossings in both directions | `chapters` |
| R06 | turns through the ≥ 100,000-character paragraph | `long-content` |
| R07 | mixed text/images, image-only page, SVG wrapper, vector SVG | `images` |
| R08 | font size and line height change mid-book, anchor restore, then turns | `styles` |
| R09 | background/foreground during motion and during preparation | `chapters` |
| R10 | ≥ 100 alternating turns plus a repeated jump loop with cache/memory snapshots | `long-content` |
| R11 | manual reading of each local real book (one run of ≥ 50 turns per book; a realism check, not part of the three-repeat rule) | user-placed books |

### 8.3 Capture and export

The reader recorder reuses S1's frame-number correlation (`diagnostics.md`
§3) and adds bounded rings for reader events: input received / admitted /
queued / rejected, preparation start/end with cache hit or miss, first motion
submission (frame number), settle end, proof result, acceptance, static
fallback, generation invalidation; layout-cost samples (paragraph layout µs,
code units, lines, section page count); cache/memory snapshots (live surfaces,
picture/image cache bytes, `ProcessInfo.currentRss`); and native presentation
samples (§9). Export is a new versioned record kind `reader_feasibility`
(`schemaVersion: 1`), written to Documents as
`shiori-reader-<BUILD_ID>-<runId>.json`, with the S1 clipboard summary
pattern. Book identity is a SHA-256 digest plus fixture id; no titles, text,
CFIs with assertions or file names of user books appear in exports.

### 8.4 Offline analyzer

`tool/diag/analyze_reader_export.dart` (pure Dart CLI) recomputes every
aggregate from raw samples — stage distributions with `over8333Us`, interval
distributions with `atLeast12500Us`, stalls ≥ 50 ms in motion windows, input
→ first-motion-submission latency for warm admitted inputs, queue wait, cold
preparation, static-fallback rate, correctness counters, resource trend, and
native cadence/presentation tables — and prints a markdown table per scenario
and repeat against the gate. It refuses exports with unknown schema versions
and reports omissions instead of filling them. Tests use committed synthetic
exports.

## 9. Presentation-evidence spike (diagnostic only)

Implemented in Swift inside `ios/Runner` (prefer existing compiled files such
as `AppDelegate.swift`, or add a file with a correct `project.pbxproj` entry
that the CI build verifies). A method channel
`io.github.natumeai.shiori/presentation_probe` is registered for the engine,
but nothing happens until the diagnostic Dart code calls `install`. The
product entry point never calls it.

| Mode | Build | What it records | Evidence level |
| --- | --- | --- | --- |
| Inventory | both | FlutterView layer class name, `FLTUseFlutterMetalLayer` value, `UIScreen.maximumFramesPerSecond`, `ProcessInfo.isLowPowerModeEnabled`, `thermalState`, iOS version | metadata |
| A1 | default | main-thread timestamp of every `setContents:` on the `FlutterMetalLayer` instance (hook added on that class only, calling through to the original) | layer-commit cadence |
| A2 | default | A1 plus an auxiliary `CADisplayLink` (`timestamp`, `targetTimestamp`), to bin commits per display period: 0 = repeated frame, 1 = new frame, ≥ 2 = overwritten frame | layer-commit cadence per display period |
| B | `-cametal` variant (`FLTUseFlutterMetalLayer = false`) | for every drawable from `-[CAMetalLayer nextDrawable]`, `addPresentedHandler` → `presentedTime` (0 = not presented) and drawable ID | system-reported drawable presentation, non-product path |

Rules: rings are preallocated and bounded; hooks never block or allocate per
frame beyond the ring write; Dart pulls samples after capture. A1 and A2 runs
are compared to show whether the auxiliary display link changes engine cadence
(it may keep the display at 120 Hz on its own). Mode B results describe the
CAMetalLayer path only; switching the product to it would be a separate,
reviewed decision. All engine-private details are taken from the pinned
sources listed in `research/s2-entry-evidence.md` and must be re-checked
against them; if a hook point differs, stop the spike and record why.

Time box: one device iteration with both variants, plus at most one fix
iteration. Without usable data after that, record "unverified" with the
observed failure.

## 10. CI packaging and privacy guards

- `tool/ci/build_ios_unsigned.sh` keeps one Flutter build of
  `lib/main_probe.dart`, then packages two IPAs from the same validated
  `Runner.app`: `shiori-probe-<BUILD_ID>.ipa` (unchanged plist) and
  `shiori-probe-<BUILD_ID>-cametal.ipa` (a copy with
  `FLTUseFlutterMetalLayer` set to false via `plutil`, re-validated). Both are
  unsigned; checksums and the variant appear in provenance. The workflow file
  changes only if the upload path or names need it.
- Before building, the script fails if any `*.epub` exists outside
  `assets/reader_fixtures/`, or if a file there is missing from, or differs
  from, `manifest.json`.
- `.gitignore` gains `tool/oracle/node_modules/`, `build/oracle-local/` and a
  local evidence folder (for example `local-evidence/`) for device exports.
- The public-repository rules from S1 hold: pushes only after the user
  confirms in chat, to `ios-build/**`, with no secrets, NAS addresses, real
  books or raw personal diagnostics.

## 11. Gates, risks and rollback

| Gate | Blocks | Stop condition |
| --- | --- | --- |
| A — oracle | everything | non-reproducible vectors, unexplained cross-engine difference, vendored drift |
| B — source/CFI/canonical | layout work | any vector mismatch on synthetic fixtures or local books |
| C — layout/page map | motion integration | conservation failure, silent drop, anchor proof failure, unsupported fixture opening as success |
| D — motion | probe | ported state-machine test failure |
| E — harness | push | local quality gate, analyzer or privacy guard failure |
| Device | S4 | NC7 gate miss without a fix that fits this architecture, or correctness failures |

Main risks: the HTML-fallback and entity behavior of Dart parsers may differ
from WebKit (mitigation: vectors decide; a targeted repair layer is allowed);
Flutter cannot render ruby natively (surface as supported-with-difference and
keep text); single-paragraph layout cost on device; raster cost of dense CJK
pages at 3x; FlutterMetalLayer pacing interactions; Playwright WebKit on
Windows is not iOS Safari (record versions; real-browser checks on the phone
are a later option).

Rollback: S2 adds new modules, assets, tooling and a diagnostic-only native
probe; it changes no product behavior and no stored product data. Reverting
the S2 commits restores S1. The S1 marker and exports are not touched.
Scope or architecture changes found necessary go back to the user for review.
