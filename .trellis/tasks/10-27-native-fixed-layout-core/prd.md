# S4a: native fixed and mixed layout core

## Goal

Render the accepted horizontal LTR reflowable, single-image fixed, complex
static fixed and mixed EPUB corpus through one native prepared-page lifecycle,
preserving authored fixed-page geometry and source identity. This is S4's
rendering and early device-feasibility deliverable, not the complete product
reader. Status: in progress, activated with user approval on 2026-10-27.
A0 was delivered on 2026-10-27, but its gate has not passed. The plan was revised after
the A0 measurement review; A1 has not started.

## Background and Dependencies

Parent: `../10-22-flutter-lan-reader-parity`. Owns portions of parent R3-R5,
R8/R10/R11 and AC3-AC5/AC8/AC10-AC12. Depends on completed S2 source/CFI,
motion and surfaces, and completed S3 content identity, independent file
lease, worker and resource handoff. S3 acceptance does not prove rendering
or full-reader RSS. Source anchors and the required capability matrix are
in `research/rendering-plan.md`.

S4b depends on this child's source geometry and lifetime handoff. S4c depends
on its renderer and early device report. S4a's minimal probe provides the
early gate without depending on either later child. The reference checkout
is read-only; private samples and captures never enter public artifacts.

## Requirements

| ID | Requirement |
| --- | --- |
| A-R1 | Resolve package/itemref layout, authored dimensions, orientation and spread/side metadata per section. Distinguish malformed metadata, unsupported vertical/RTL and resource failures; no blanket fixed-layout refusal. |
| A-R2 | Deliver the required complex XHTML/SVG matrix, including positioned text, packaged fonts, layers, transforms, clips, masks, required filters and audited foreignObject. Single-image success cannot replace this gate. No browser reader or flattening that loses source geometry. |
| A-R3 | Compose real pages, active side and blank slots; switch fixed/reflowable paths without dropping, duplicating or inventing sections. Preserve the reflowable corpus and canonical v1. |
| A-R4 | Export source-linked text/image geometry with UTF-16 ranges, transforms, clips and paint/occlusion information for proof, hit tests and S4b visibility. Rendering SVG must not alter canonical exclusions. |
| A-R5 | Own an independent publication lease, coordinate worker reopen/preload, bound retained/transient resources, coalesce preparation and reject stale results. No decode/layout/font/I/O in motion callbacks. Account for both spread pages and process-lifetime fonts. |
| A-R6 | Repair recognized-admission/dirty-drag/hold/demand capture and loss-accounted native sampling before measuring. Preserve the product FlutterMetalLayer path and investigate historical RSS failures without relabeling them. |
| A-R7 | Close A-owned hardening: template/noscript cases, warm/prepare coalescing, font admission and native synchronization review. Retain S3 import bounds and all seven S2 conditions with explicit final owners. |
| A-R8 | Produce deterministic fidelity/conservation fixtures and an early iPhone report through actual preparation/motion. Failed required fidelity/resource/performance work returns for review; it never silently reduces scope or the 120 Hz target. |

## Acceptance Criteria

| ID | Requirements | Observable outcome |
| --- | --- | --- |
| A-AC1 | A-R1, A-R3 | Default/override, dimensions, centered/paired/blank-slot and mixed-boundary vectors retain exact source identity across reverse turns, TOC targets and viewport changes. Invalid dimensions yield a recoverable reason, not guessed geometry. |
| A-AC2 | A-R2, A-R4 | Every required matrix row has generated source and pinned reference/native evidence. Text/images/order, source ranges and clips are conserved under the per-channel 0.5 authored CSS px geometry contract (text gated per shaping cluster) and explicit font tolerances; no required feature becomes successful partial output. Only reproducible reference defects may be exempted, each as a narrow recorded exception. |
| A-AC3 | A-R3, A-R4 | Text/image anchors and spread-side mappings round-trip through CFI; transforms invert correctly; blanks have no source/coverage. Existing source/CFI/canonical vectors stay green. This proves geometry, not product writes. |
| A-AC4 | A-R5, A-R7 | Concurrent preparation, cancellation, A->B->A server switches, replacement and disposal release owners exactly once. Retained 3+1 surface, picture/image and preload limits hold; peak/font accounting includes allocations outside those caps. |
| A-AC5 | A-R6 | Analyzer vectors distinguish receipt/recognition/admission/queue/preparation/submission, dirty updates, holds and overdue frames. Long captures report loss; required native device runs lose zero samples. Product layer remains FlutterMetalLayer. |
| A-AC6 | A-R7 | Supported parser regressions, bounded process-font policy and native synchronization decision have host/CI/device evidence as applicable. Required corpus failures remain open rather than being waived as unsupported. |
| A-AC7 | A-R1-A-R8 | Early release-device matrix covers complex text/SVG, images/spreads, mixed boundaries, reflow, cold/warm/rapid turns and interruption: three repeats per measured scenario, >=100 alternating turns, unchanged parent thresholds and explicit RSS/presentation limitations. Failures block dependent activation pending review. |
| A-AC8 | A-R3, A-R8 | All 23 private regression sections including six fixed image pages are conserved; remaining novels and generated long/Unicode/style cases pass. Only anonymous results are tracked. |

## Out of Scope

Durable position/activity writes, complete controls, image-viewer/product
zoom UI, shell/library/statistics parity and release acceptance belong to
S4b/S4c/S5/S6/S7. Vertical/RTL, active scripts and full browser CSS conformance
remain outside the parent release. No required static matrix row is excluded.

## Technical Gates and Artifact Status

The scene renderer, geometry contract, font admission and SVG compositing
are proposed engineering contracts to prove in A0-A3. Design, execution plan
and both context manifests are validated before activation. The previously
presented plan was approved on 2026-10-27; A0 must establish evidence before
broad renderer implementation.

The owner made these decisions after the A0 review on 2026-10-27. Evidence is in
`research/a0-measurement-review.md`:

- D1: cluster-granular curved/positioned SVG text is proved first through a
  time-boxed HarfBuzz FFI probe (A0b). Other routes need a new review.
- D2: curved textPath with ligatures and textLength/lengthAdjust stays a
  required row. A failed probe keeps those rows open; no automatic narrowing.
- D3: reproducible WebKit raster defects become narrow recorded exceptions,
  modeled on the parent occlusion parity exception, with a reference-fix
  handoff. They never cover native-only deviations.
- D4: cross-engine pixel edges pass only under the conservative edge rule in
  `design.md`; anything else fails.
- D7 (2026-10-28): D4's component sub-rule counts only pixels with alpha >= 32.
  Faint antialiasing bridges no longer decide component counts; every other
  D4 sub-rule is unchanged.
- D8 (2026-10-28): text glyph pixels are excluded from the component
  sub-rule. Glyph presence is gated by cluster conservation (each cluster
  painted exactly once, exact source mapping) plus 0.5 px geometry. Non-text
  keeps D7. Text raster parity is judged again on the device in A5.
- D9 (2026-10-29): a D4 sample point on gradient-painted pixels may differ by
  at most 1/255 per channel, because Flutter always dithers gradients and
  exposes no control. A sample counts as gradient-painted only when the
  native topmost paint and the reference's computed paint of the same source
  element both use a gradient paint server. Solid samples and every other D4
  sub-rule stay exact. Gradient raster parity is judged again on the device
  in A5.
- D10 (2026-10-29): for D4's interior, edge-band, support and component
  counting, a pixel is changed when its maximum channel delta is at least 2;
  an exact 1/255 difference (8-bit rounding, e.g. opacity 0.7 giving alpha
  178 vs 179, or gradient dithering) is not a change. This tightens the
  undocumented delta-2 threshold used since A0. Sample points follow D9.

The 0.5 authored CSS px tolerance and the 120 Hz target are unchanged. No other
product decision is open.
