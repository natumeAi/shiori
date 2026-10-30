# Design: fixed/mixed native reading units

Status: proposed, 2026-10-27; revised the same day after the A0 measurement
review (`research/a0-measurement-review.md`, owner decisions D1-D4). PRD owns
scope; `research/rendering-plan.md` owns the exact required capability rows,
source anchors and the 0.5 authored CSS-pixel geometry tolerance; this design
owns which quantities that tolerance compares. All type/directory names below
are proposals, not existing APIs.

## Architecture and boundaries

Keep pure Dart source/CFI/canonical/worker layers and the existing reflow
preparer. Add a fixed-layout profile to the existing typed CSS cascade and an
`engine/fixed/` scene path. One source page retains its authored coordinate
system; final fit/zoom belongs above that scene, not in typography or source
mutation. Parsing, hashing and transferable scene inputs remain worker work;
root isolate prepares native paragraphs, images, pictures and compositing.

`SectionCapability` records complete/malformed/unsupported/resource/render
outcomes and offending constructs before a surface can publish. Fixed
metadata routes to a renderer; it never means unsupported by itself.
Required matrix rows cannot pass with a partial marker. Unknown declarations
that affect required content must propagate to capability completeness.

Use the exact raster-wrapper guard for simple pages. General SVG keeps ordered
vector, text, foreignObject and filter nodes; a subtree optimization must
preserve transforms, resource resolution, opacity, clips and source links.
Existing flutter_svg support does not itself prove source-aware text or
filter equivalence. A0 probed difficult textPath/filter/mask and font cases;
filters, masks and SFNT shaping were feasible for the tested inputs.

Public `dart:ui` cannot paint one shaped cluster at a time along a curve: it
exposes grapheme boxes, not glyph IDs, cluster membership or outlines. Owner
decision D1 routes this through a time-boxed A0b probe of HarfBuzz over Dart
FFI, which is also SkParagraph's shaping engine. The probe shapes a complete
run once, keeps the UTF-16-to-cluster map, and paints each cluster's glyph
outlines as Paths under its authored or path transform. Adoption requires a
pinned version, licence review, iOS static packaging, a Windows host test
build and lifetime/resource accounting. Straight positioned runs keep the
existing whole-Paragraph path. An engine bridge or CoreText adapter is not
approved and needs its own review. No other new package is selected without
a source/API/licence and pinned-build check.

## Geometry and navigation contract

`PreparedReadingUnit` adapts both reflow pages and fixed pages/spreads:

- Identity: server activation, full ContentIdentity, reader/layout generation,
  stable unit ID and active source page.
- Slots: each real slot owns section/spine/source-document identity, authored
  size and source-to-unit transform; a blank slot has none of those source
  semantics.
- Geometry: original node/UTF-16 clusters or image anchors, transforms,
  clip/mask stacks, effective opacity, paint order/occluders and an explicit
  completeness result. Source order and paint order remain separate.
- Ownership: all source/resource/surface leases plus measured resource
  accounting; a picture is paint storage, never the source map.

Resolve valid viewport/SVG dimensions and per-item defaults before
composition. Preserve SVG viewBox origin/aspect behavior. Invalid/missing
required dimensions produce recovery, not guessed page dimensions.
Reference LTR portrait/spread/center placement and nonlinear navigation are
the baseline. Never pair a reflow page with a fixed page; blank and opposite
slots cannot inherit active-side CFI. Same-spread active-side changes retain
real source identity and remain separately provable.

A reading-unit navigator replaces single-section arithmetic in adjacency,
TOC targets and boundary handling. The existing motion controller still owns
admission, queueing, cancellation and exactly-once settled acceptance.
Typography changes affect reflow; fixed content remains authored. A viewport
change may alter composition/fit and invalidates display proof, not source.

## Lease and worker ownership

Acquire an independent immutable-file cache lease before the preparation route
loses its owner. Confirm full acquired identity, reopen that path in the S3
worker queue, then preload. A file pin does not pin a worker adapter.

Introduce an explicit reader ownership/reservation token in the shared worker
queue. Another preparation cannot reopen/detach an adapter still used by the
reader. Define coordinated suspension/drain or defer conflicting work; never
silently commandeer the worker. All awaits carry activation/content/lifetime/
layout identities. Cancellation disposes abandoned preload/scene results.

Shutdown order: disable new work -> invalidate generations -> cancel/drain
motion/preparation -> dispose scenes and source/resource adapters -> detach
worker -> release final file pin. Releasing the route's shared PreparedBook
must not end the reader's independent lifetime.

## Resource admission

| Resource | Starting contract and required extension |
| --- | --- |
| Surfaces | Three presented reading units + one reserve. Charge every constituent; four spreads can retain eight real source pages. Live source leases cannot be evicted by the old four-section cache. |
| Encoded preloads | Preserve shared 128 MiB reservation/accounting; never reset budget per spread or book. |
| Pictures / decoded images | Preserve initial 16 / 48 MiB retained budgets; reserve before allocating and record transient decode peaks/oversize behavior separately. |
| Source graphs / paragraphs / vectors / layers | A0 proposes finite byte/count/operation/depth and layer-area caps using host fixtures; A3 enforces them, A5 validates them on device. Retained-surface counts are insufficient; A3 cannot finish with unbounded classes. |
| Fonts | Deduplicate by bytes/face; reserve aggregate process bytes/count before registration. Registrations persist after disposal. A0 defines provisional finite limits and a typed process-font-exhausted outcome; A3 enforces, A5 measures. Preserve accepted state and explain that closing the book/retry cannot unload engine fonts; user-initiated app restart may be needed. No silent font substitution or automatic restart. Direct WOFF/WOFF2 registration is not usable (A0: futures complete, shaping falls back), so convert to SFNT in Dart before admission: WOFF 1.0 via zlib per table, WOFF2 via Brotli plus glyf/loca reconstruction. Bound conversion bytes/time, charge converted bytes, and prove shaping use rather than future completion. A HarfBuzz face (D1) shares the same admitted bytes and face identity. Owner decision (2026-10-29): WOFF2 uses a pure-Dart decoder (RFC 7932 Brotli plus W3C WOFF2 table reconstruction), no native library; the only vendored input is the pinned Brotli static dictionary in `third_party/brotli/` (MIT, SHA-256 `20e42eb1...35c70`). |
| Zoom resources | Prepare bounded higher-resolution content outside motion; old and new allocations both count until swapped. S4c consumes the policy. |
| Display-resolution preparation (2026-10-29) | Measured on the private mixed sample: authored-size coverage grids (up to 102.8 MB vector bytes for a 1448x2048 image page against 16 MiB) and authored-size SVG layers (9.1 M px against 8.39 M) refuse simple full-page image wrappers. (1) Coverage evidence stays at the published one-CSS-pixel resolution but is stored losslessly: a paint whose coverage is a (transformed) rectangle with uniform alpha is recorded as an analytic uniform region; only non-uniform coverage keeps a grid, sized to the paint's own bounds. No downsampling of proof. (2) Image decode targets and offscreen layer allocations/reservations use the preparation scale = fit of the authored page or spread into the view x DPR, never above intrinsic size. Zoom above fit is a separate, bounded higher-resolution generation (S4c sets the bound). Corpus comparisons run at authored size (scale 1), so their verdicts are unaffected. Caps are unchanged. |
| Bounded evidence rasterization (2026-10-30) | A3-scale found that one-CSS-pixel evidence still needs an authored-size raster plus RGBA readback (private page 1: 9,106,344 px for those two buffers against the 8,388,608 cap), which display scaling cannot legitimately shrink. (1) Revised the same day after A3-scale measured that tiled or strip rasterization changes native rotated-edge AA by 1 (whole 106, strip 105): coverage evidence that needs native rasterization is rasterized ONCE as a whole authored-size image (exact native AA, one CSS pixel per sample; charged as one authored layer, typed refusal if that alone exceeds the cap), then read back through exact integer-aligned, unfiltered tile copies (bounded tile readback buffers) streamed into the lossless footprint (uniform detection and trimming across tiles). No other authored-size buffer coexists with it; the transient tile copy and its readback are charged and released before the next tile. (2) Opaque raster images: evidence alpha depends only on the destination geometry, so the display-decoded image drawn tile by tile gives exact evidence. Images with an alpha channel need authored-resolution alpha: a separate charged decode at min(intrinsic, authored) size, released after evidence; if that exceeds a cap the page refuses with a typed reason (no approximation). (3) Reservations equal real allocations: scaled display layers + one authored evidence raster + one tile copy and readback + retained evidence bytes. Caps unchanged. |
| Filter display scale (2026-10-30) | A3-scale-b measured that SVG filter DAG caches feed both display and authored evidence; scaling them changes proof pixels (synthetic scale 1 vs 0.25: 4,268 alpha samples differ). Decision for S4a: filter DAG caches and their display stay at authored scale (charged as today); every other display decode/layer uses the preparation scale. Known limitation: on a small authored page shown at DPR 3 a filtered region is rendered at 1x authored resolution and may look softer than surrounding content. Revisit with the S4c zoom generation (charged authored evidence caches plus scaled display caches). |
| Alpha-image evidence decode (2026-10-30) | Supersedes "a separate charged decode at min(intrinsic, authored) size" in "Bounded evidence rasterization" item (2). Final review A found the implementation decodes at intrinsic size. Decision: keep the intrinsic decode, because only a full decode proves per-pixel opacity and keeps exact alpha (a 1x1 hole hidden by the display decode must still reach evidence). Conditions: it is charged before allocation (including codec scratch), used only to prove opacity and produce authored evidence, and released as soon as evidence is produced, never retained for the scene lifetime alongside the display decode; opaque images release it immediately and the display decode serves display and evidence. If it exceeds a cap the page refuses typed. |

Policy pressure cancels optional prewarm first, never destroys current proof
or drops authored content. If an accepted fixture exceeds a cap, retain the
failure and review architecture/budget; do not mark partial output successful.

## Fidelity and proof handoff

A0 pins reference revision/dirty state, viewport/fonts/resources and fixture
manifest. Require exact source/content/order/CFI and paint-layer conservation.
Changed line wrapping or missing small objects cannot be hidden by a global
pixel-difference percentage.

The <=0.5 authored CSS px gate compares only quantities with the same
definition on both sides:

| Channel | Gated comparison | Diagnostic only |
| --- | --- | --- |
| CSS boxes, transforms, clips | Resolved box/transform/clip geometry | - |
| Text runs | Baseline origin and unsnapped advances (oracle `prefixWidths`) | WebKit DOM Range boxes, which snap interior edges to integer px (F2) |
| Positioned or path text | Start of every shaping cluster; run total advance against WebKit `computedTextLength`; rotation of single-component clusters | Component metrics inside one cluster (including the "end" of a ligature's last component and per-component rotations), which WebKit reports by convention (F1, A0b round 2) |
| Painted coverage | Whole-run alpha-support bounds | Per-component slice boxes |

Definition B for positioned/path text was adopted on 2026-10-28 from A0b round-2
evidence. In every case the start of the cluster after `fi` matched WebKit within
0.05 px, while WebKit reported overlapping component ends and two rotations for
one glyph. D4 pixels remain the paint gate, and 0.5 px is unchanged.

A snapping emulation of DOM Range boxes may replace the unsnapped comparison
only after WebKit primary-source or multi-case confirmation. Rotation is gated
in px through the displacement it induces at the cluster's far edge
(|delta angle| x cluster advance); the raw angle delta stays diagnostic. Until A0b
supplies shaped cluster membership, the A0 harness uses a fixture-declared
cluster map and labels the verdict provisional.

Pixels use the conservative edge rule (D4): zero interior mismatches; each
changed pixel within one device pixel of a pixel that is partially transparent
in either render; alpha-support bounds (alpha > 0) within one device pixel;
identical 8-connected component sets; exact sample points. Under owner decision
D7 (2026-10-28), components are computed on pixels with alpha >= 32. A0b round 3
showed that faint antialiasing pixels (alpha 4-25) join or split adjacent glyph
pieces differently between rasterizers while geometry agreed within 0.0005 px.
All other D4 sub-rules keep alpha > 0, and the interior rule still catches
missing faint areas larger than 3x3.

Owner decision D8 (2026-10-28) supersedes D7 for text. The A2 segment-4
before/after run showed glyph-component topology flipping with the alpha
threshold and with rasterizer hinting; iOS (CoreText vs Impeller) differs
again. Text glyph pixels (native glyph coverage and reference text geometry,
each expanded by 1 px) are therefore excluded from the component sub-rule.
Glyph presence is gated by cluster conservation instead: every shaped cluster
or grapheme is painted exactly once with an exact source mapping, together
with the definition-B geometry channels at 0.5 px. Interior, edge-band,
support-bound and sample rules still apply to text pixels. Non-text paint
keeps the component rule at the D7 threshold. Text raster parity is judged
again on the device in A5.

Owner decision D9 (2026-10-29) relaxes only the sample sub-rule for gradients.
Flutter dithers every gradient and its UI API has no dithering control, so
native gradient pixels differ from WebKit's exact rounding by +/-1 in single
channels (svg-graphics-boundary: 665 of 1369 pixels of one gradient rect). A
sample is gradient-painted when the native topmost paint covering the pixel
centre is a gradient paint server and the reference's computed fill or stroke
of the same source element is a gradient `url(...)`; such samples pass at a
maximum channel delta of 1. Classification comes from source and paint
records, never from pixel values. Solid samples stay exact, and the interior,
edge-band, support-bound and component sub-rules are unchanged for gradient
pixels. Each sample records its classification and delta. Gradient raster
parity is judged again on the device in A5.

Owner decision D10 (2026-10-29) defines a changed pixel for every D4 sub-rule
except samples: its maximum straight-RGBA channel delta is at least 2. Since
A0 the harness had silently used "greater than 2". Measured over all scene,
A0 and SVG renders, the only sub-threshold differences are exactly 1:
stacking-boundary's `opacity:.7` square (alpha 178 native vs 179 WebKit,
100 pixels) and gradient dithering; no case has a delta-2 pixel. The reports
keep the count of delta-1 pixels per case as a diagnostic. Every measured
variant needs its own reference PNG; a missing reference is unverified, not
passed.

Characters that the authored font does not cover (for example emoji) use
platform fallback fonts. On the Windows host, WebKit (Segoe UI Emoji) and
`flutter test` (no system fonts) use different fallback fonts, so a host
geometry or pixel comparison of those glyphs is not same-font. Keep such
characters in a dedicated fallback case, not inside row fixtures. On the
host, require only that the fallback glyph is painted and source-mapped, never
dropped. Its geometry and pixels are gated in A5, where Safari and Flutter use
the same iOS fallback font. Cluster maps must come from measured ligature
evidence, never a hand-written guess.

A reproducible WebKit raster defect becomes a narrow recorded exception (D3),
modeled on the parent occlusion parity exception: isolated reproducing
controls, native output per CSS and the reference's own DOM geometry, an
exemption limited to the named pixels/elements, and a separate reference-fix
handoff. The XHTML-SVG (0,0) pixel and the foreignObject relative-span paint
are the first two candidates. Exceptions never cover native-only deviations.

S4b receives candidate source geometry and completeness, then combines it
with settled viewport, active side, foreground eligibility and dwell. Unknown
mask/occlusion visibility must fail the required fixture gate rather than
overcredit or silently satisfy acceptance. SVG descendants retain canonical
v1 exclusion. S4c inverse-transforms hits and supplies whole-page view state.

## Instrumentation and device boundary

A0 adds actual recognized admission, submission mutation, dirty drag, hold/
barrier and frame-demand timestamps, with fake-timeline analyzer vectors.
Use loss-accounted native sampling and review OSAtomic replacement/use against
the installed SDK; preserve FlutterMetalLayer for product/A-path evidence.
The alternate CAMetalLayer experiment never supplies product acceptance.

The 16384-event Dart ring overflows well before 100 dirty-drag turns (about
six events per frame). A3/A4 owns capture volume before A5: size the rings
from measured per-turn volume, export in bounded segments, or compact
per-frame events without dropping the fields the analyzer needs. A larger
native ring cannot hide Dart loss. The A0 Swift/C changes are compiled on
hosted macOS CI at the next owner-approved push, not first at A5.

A5 is an early feasibility gate through real surfaces, not UI parity. Keep
three repeats, unchanged stage/latency/stall thresholds, >=100 alternating
turns, font/source/decode peaks and real background/return. Explain historical
RSS failures and record any reviewed rule prospectively; do not relabel old
results. Physical scan-out stays separately qualified. S4c repeats final
product scenarios and owns closure of all seven conditions.

## Compatibility and rollback

Keep source/CFI/canonical vectors and reflow behavior intact. No database
migration or NAS write belongs to this child. Independent phase commits can
be reverted without deleting user state; fixture/diagnostic modes must not
replace the product reader. A failed required scene/font/filter/device gate
stops dependent activation and returns measured options for review.
