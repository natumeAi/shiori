# A0 measurement review and owner decisions

Date: 2026-10-27. Main-session review of the delivered A0 evidence, made
read-only against committed fixtures and the ignored native report. No code,
test, oracle, reference or tolerance value changed. Inputs: corpus
`e2feb591...`, oracle `5cd38ddb...`, native harness `42ddd670...`
(`build/fixed-layout-native/report.json`). Re-derive the numbers below if any
input hash changes.

## Verdict

A0 remains **not passed** and A1 has not started. The reported text deltas
above 0.5 px mostly compare non-equivalent quantities; they do not show native
text painted in the wrong place. The real remaining work is narrower: one
measured geometric miss (curved `spacingAndGlyphs`), a public-API capability
gap for cluster-granular curved text, two undefined acceptance rules (pixel
edges, reference defects), corpus semantic gaps, font formats and capture
volume. The 0.5 authored CSS px value is unchanged.

## Findings

### F1. Ligature components dominate the SVG text deltas

Maximum per-character delta from the native report, split by the UTF-16
positions of the `fi` ligature (3, 4) versus all other characters:

| Case | All | `fi` components | Other characters |
| --- | ---: | ---: | ---: |
| svg-text-*-webkit-parent-length | 1.384887 | 1.384887 | 0.294022 |
| svg-text-path-none | 1.366096 | 1.366096 | 0.294022 |
| svg-text-path-spacing | 1.492119 | 1.492119 | 0.410503 |
| svg-text-path-spacingAndGlyphs | 3.572766 | 3.572766 | **0.861506** |

WebKit's SVG character API does not describe one consistent geometry for
ligature components. In `svg-text-path-none`, `f` ends 6.94 px along the path
from its start (the standalone `f` advance), while `i` starts 5.53 px along
(half of the 11.07 px ligature advance). WebKit's own `f` end and `i` start
therefore overlap by about 1.41 px. These are reporting conventions for parts
of one glyph, not painted positions. Whole-text alpha-support bounds match
exactly (`a0-native-spikes.md`). The 105.87 px `svg-text-*` variants that
apply the parent `textLength` are retained counterexamples; WebKit ignores
that attribute, so they are not the reference-compatible target.

Consequence: gate text at shaping-cluster granularity (a ligature or a
combining sequence is one cluster). Component metrics inside a cluster stay
diagnostic. The 0.86 px combining-sequence delta under `spacingAndGlyphs` is
outside the ligature and is a genuine failure to resolve in A0b.

### F2. foreignObject boxes compare against snapped reference rectangles

WebKit Range boxes for `Ab fi` start at x 36/49/60/65/70 with widths
14/12/6/6/6.28125; ` Z` gives 76/81 with 6/12.203125. Unsnapped canvas
prefix widths for the same font are 0/13.046875/24.267578125/29.21875/
36.162109375/40.29296875. Every interior edge equals floor(left)/ceil(right)
of the unsnapped advance, the run end is a 1/64 px layout unit, and the `fi`
ligature advance is split evenly between its two components. The native report
already records a same-definition advance delta of 0.0 px. The 1.048828 px
maximum is reference integer enclosure, not native placement.

This rule is observed across seven boxes in one fixture. Before any snapping
emulation is encoded, confirm it from WebKit primary source or additional
cases; until then compare unsnapped same-definition advances and keep snapped
boxes as diagnostics.

### F3. Two reproducible reference raster defects

- XHTML-hosted SVG in WebKit paints black alpha 38 at (0,0). Twenty isolated
  controls reproduce it with an empty SVG; HTML and Chromium stay transparent.
- In foreignObject, WebKit paints the relatively positioned `Z` above its
  sibling while its own DOM Range records top+3. The defect reproduces in
  isolated HTML and XHTML. Native follows CSS. This causes the 305 changed
  pixels in `foreign-object-positive`.

### F4. The pixel gate has no admissible rule

`rendering-plan.md` section 7 allowed antialiasing-only classification but
defined no criterion, so the harness correctly refused any classification.
Cross-engine vector edges never match strictly. `clip-mask-positive` has 6
changed pixels with 0 interior mismatches, and `filters-positive` has 1, which
is the F3 defect. Nine of the twelve measured boundary/nested native cases fail
`pixelGate` only because no reference PNG was captured.

### F5. Corpus semantic gaps

- `dimensions-unsupported` XHTML is byte-identical to `dimensions-positive`
  (source SHA `dc05c00c...`). Its OPF changes only spread `auto` to `both`,
  which is not a dimension construct.
- `cascade-unsupported` places its unknown declaration inside
  `@supports (future:yes)`. The rule never applies, so it cannot prove
  rejection of a used declaration.
- `metadata-unsupported` correctly varies the OPF (unknown layout,
  orientation and spread values) and needs no change.

### F6. Public text API boundary

As recorded in `a0-text-geometry-options.md`, public `dart:ui` exposes
grapheme layout boxes but no glyph IDs, shaping-cluster membership or glyph
outlines. It cannot paint one shaped cluster at a time along a curve without
cropping or reshaping risk. Redefining the measurement (F1) does not remove
the need for a cluster-aware shaping source.

### F7. WOFF/WOFF2 fonts are not usable through direct registration

On the host engine both registration futures complete, but shaping equals the
absent-family control. EPUB 3 lists WOFF and WOFF2 among its core font media
types, so real books can depend on them. A bounded conversion route to SFNT is
needed before admission: WOFF 1.0 is zlib per table; WOFF2 needs Brotli and
glyf/loca transform reconstruction.

### F8. Capture volume cannot yet meet zero-loss long runs

The Dart reader ring holds 16384 events. A dirty-drag frame emits about six
events (dirty, demand start/end, clean, mutation, submission). At roughly 50
frames per turn, 100 turns produce about 30000 events, so the required >=100-
turn runs would overflow. A-AC5 and A5 require zero loss in required device
runs; sizing, segmented export or event compaction must land before A5.

### F9. Native diagnostic code is uncompiled

The `AppDelegate.swift` and bridging-header changes have not been compiled or
exercised on iOS. Discovering a build break at A5 would waste the device slot.

## Owner decisions (D1-D4 2026-10-27, D5-D6 2026-10-28)

| ID | Decision |
| --- | --- |
| D1 | A0b evaluates HarfBuzz through Dart FFI first, as a time-boxed probe. It keeps the shaping engine SkParagraph already uses and exposes glyph IDs, clusters and outlines. Licence, pinned version, iOS static packaging and the Windows host test build are checked before adoption. An engine bridge or CoreText adapter is not approved; either needs a new review. |
| D2 | Curved `textPath` with ligatures and `textLength`/`lengthAdjust` stays a required row. If A0b misses, the affected A2 rows stay open and return with evidence; no automatic narrowing. |
| D3 | Reproducible WebKit raster defects become narrow recorded exceptions, modeled on the approved occlusion parity exception. Each needs isolated reproducing controls, native renders per CSS and the reference's own DOM geometry, only the identified pixels/elements are exempt, and a separate reference-fix handoff is recorded. It does not block S4 and is not a general waiver. |
| D4 | Conservative edge rule for cross-engine pixels: zero interior mismatches; every changed pixel lies within one device pixel of a pixel that is partially transparent in either render; alpha-support bounds agree within one device pixel; the 8-connected alpha>0 component sets match (no missing or extra component); sample points match exactly. Anything else fails. |
| D5 | S4b B0 wire-DTO fixtures, B2 durability and B3 typed delivery depend only on S3. They may run in parallel with S4a on an explicit owner start, with disjoint files and no live writes. B0 geometry vectors, B1, B4 and B5 still wait for S4a's handoff. |
| D6 | The reference classifies visibility on WebKit's integer-snapped client rectangles with a 1 px tolerance (`visibleText.ts`); native uses unsnapped geometry. An edge character may differ only when its native box lies within 1 px of a clip edge and the reference rule on unsnapped geometry reproduces the native verdict. Each case is recorded with its paired fixture. This is the second and last narrow coverage exception. |

## Plan changes applied

- `design.md`: per-channel geometry contract, pixel/defect rules, HarfBuzz
  route boundary, font conversion and capture-volume ownership.
- `rendering-plan.md` section 7: tolerance bullets point to the channel
  contract; the threshold value is unchanged.
- `implement.md`: A0 closure items, new A0b, per-row gate split, A1/A3
  allowed before A0b only on the owner's explicit start instruction.
- `prd.md`, `execution-log.md`, `task.json`: decisions and gate status.
- S4b PRD/design/implement: D5 parallel track, D6 exception, XHTML
  per-grapheme versus SVG per-cluster geometry.
- S4c PRD/design/implement/research: revised S4a contract in C0, HarfBuzz
  inventory and licence notice in C4, device-Safari re-verification of D3,
  WOFF conversion failure handling and A4 capture sizing.
- Parent `s4-plan.md`, `prd.md` (AC6/AC11), `occlusion-parity-exception.md`
  and `s4-readiness.md`.

No phase has started under the revised plan.
