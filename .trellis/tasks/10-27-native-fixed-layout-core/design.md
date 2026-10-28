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
| Fonts | Deduplicate by bytes/face; reserve aggregate process bytes/count before registration. Registrations persist after disposal. A0 defines provisional finite limits and a typed process-font-exhausted outcome; A3 enforces, A5 measures. Preserve accepted state and explain that closing the book/retry cannot unload engine fonts; user-initiated app restart may be needed. No silent font substitution or automatic restart. Direct WOFF/WOFF2 registration is not usable (A0: futures complete, shaping falls back), so convert to SFNT in Dart before admission: WOFF 1.0 via zlib per table, WOFF2 via Brotli plus glyf/loca reconstruction. Bound conversion bytes/time, charge converted bytes, and prove shaping use rather than future completion. A HarfBuzz face (D1) shares the same admitted bytes and face identity. |
| Zoom resources | Prepare bounded higher-resolution content outside motion; old and new allocations both count until swapped. S4c consumes the policy. |

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
again on the device in A5. Every measured
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
