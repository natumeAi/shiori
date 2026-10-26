# Fixed-layout expansion for S4

Date: 2026-10-26. Status: user-approved scope expansion, planning only.
The user chose to include both single-image fixed pages and complex fixed
layout after their different implementation costs were explained. This
supersedes the fixed-layout exclusion in the original parent plan; vertical
writing and RTL reading remain deferred. Product code and the private sample
have not been modified.

## Confirmed local evidence

- The private regression EPUB passes ZIP CRC validation and the current
  source loader. Its 23 sections include six fixed pages; the actual S2
  detector returns only `fixedLayout` for those six and supports the other
  17. No title, pathname, digest, prose or image is included here.
- Each of the six fixed pages is an XHTML viewport containing a single SVG
  wrapper around one local JPEG, with a matching view box/image size. This
  proves the sample is a useful simple mixed-layout regression; it does not
  exercise general positioned XHTML or complex SVG.
- `lib/features/reader/engine/support/layout_flags.dart:36` recognizes
  itemref fixed layout. `unsupported_layout.dart:65` requires every section
  to be supported, and the probe invokes that gate in
  `lib/features/diagnostics/presentation/reader_probe/reader_probe_controller.dart:59`.
  These files match the device build revision `862d999010fa`.
- `lib/features/reader/engine/layout/svg_support.dart:125` and
  `block_builder.dart:532` provide the guarded single-raster wrapper path.
  `engine/pagination/anchor.dart:164` supports image-element source anchors.
- `lib/features/reader/engine/style/css_properties.dart` currently lacks
  general positioning/stacking/transform properties. The present SVG path
  surfaces partial features such as text, foreignObject and filters rather
  than proving complete rendering (`engine/layout/svg_support.dart`,
  `svg_picture.dart`; `.trellis/spec/flutter/reader-engine.md:161`).
- `lib/features/reader/engine/pagination/page_plan.dart:93` maps one section
  per page. Its line-oriented text coverage and the current single-section
  prepared surface do not already prove mixed-source spreads or clipping/
  occlusion-aware fixed-page coverage.
- The current pool uses bounded leases, pre-motion image decode and prepared
  paint (`engine/surface/page_surface_pool.dart:53`, `:100`). Reuse that
  lifecycle, but charge all page/spread resources; pre-existing caps are not
  evidence that the expanded corpus fits within them.

## Primary specification and reference evidence

Read on 2026-10-26:

- [EPUB 3.3, layout and per-item overrides](https://www.w3.org/TR/epub-33/#layout):
  package layout is overridable per spine item; fixed content represents one
  authored page per item. Fixed-page styling cannot be treated as ordinary
  user-controlled text reflow.
- [EPUB 3.3, content dimensions](https://www.w3.org/TR/epub-33/#sec-fxl-content-dimensions):
  XHTML and SVG have defined dimension sources. Preserve these facts in the
  source metadata instead of inferring all pages from the first image.
- [EPUB Reading Systems 3.3, fixed layouts](https://www.w3.org/TR/epub-rs-33/#sec-fixed-layouts):
  layout, orientation, spread placement and viewport rendering are separate
  processing concerns. Supporting a single image does not establish all of
  them. This plan does not claim full reading-system conformance.

Read-only lan-reader evidence at its pinned `a4bda23` baseline:

- `D:/Projects/lan-reader/client/src/reader/foliateEngine.ts:208` sets a
  paginator column limit, but `node_modules/foliate-js/view.js:253` selects
  the fixed renderer by publication rendition. Do not infer fixed-page UX
  from a reflow paginator attribute.
- `node_modules/foliate-js/fixed-layout.js:6` resolves viewport dimensions;
  `:112` distinguishes portrait display and spread policy; `:201` builds
  centered/paired pages and retains active side. These are reference facts,
  not permission to copy arbitrary missing-viewport guesses.
- `client/test/foliateFixedLayoutCompatibility.test.ts:66` covers active-side
  changes, single/spread geometry, centered pages and nonlinear navigation.
  `client/test/foliateFixedLayoutVerification.test.ts` is the reference for
  scaled content-anchor proof. Port accepted LTR cases; RTL is not newly
  authorized by their presence in the reference.
- `client/src/reader/foliateEngine.ts:238` keeps source section identity per
  document in a spread. Opposite-side and blank documents cannot inherit the
  active side's source location.
- Existing image-viewer parity covers image pinch/pan/dismiss (UI12).
  The user also chose whole-page fit, pinch zoom and pan for complex fixed
  pages on 2026-10-26 (Q-FXL-1 resolved).

## Required capability and validation matrix

This matrix is the minimum expanded delivery surface, not a claim that every
CSS/SVG feature already works. During S4a planning, enumerate exact supported
properties/values and visual tolerances against generated fixtures. Required
content failures remain open work; unsupported reporting is not a waiver to
ship only the simple subset the user already chose to exceed.

| Area | Required outcome | Verification |
| --- | --- | --- |
| Package and section metadata | Correct package defaults, per-item fixed/reflowable overrides, dimensions, orientation, spread/side placement and source order. | Conflicting/default metadata, mixed spine, centered/paired pages, invalid/missing dimensions and recoverable errors. |
| Single-image fixed pages | Preserve complete raster/SVG-wrapper image, aspect ratio and source identity in authored page space. | Portrait/landscape image fixtures, independent image bounds, every fixed page in the private sample. |
| Complex static XHTML | Preserve authored text, packaged fonts, positioned/nested boxes, stacking, opacity, transforms, clipping, backgrounds/borders and images. | Deterministic text/font fixtures, overlapping positioned content, transformed/clipped content, expected source geometry and paired reference images. |
| Static SVG | Correct admitted shapes, paths, text and nested resources, transformations and required clipping/masking/filtering; no silently flattened or missing content. | Non-wrapper SVG cases that force the new rendering work; every required unsupported feature becomes a failing gate until implemented. Audit foreignObject/embedded XHTML during S4a capability planning. |
| Page/spread composition | Preserve each real source page, active side, centered and blank slots; no skipped page at a fixed/reflowable boundary. | Both turn directions, TOC targets, consecutive centered pages, nonlinear targets and viewport/orientation changes. |
| Source interoperability | Content-derived CFI round trips and visible-target proof after all page transforms. | Web/native/web restore for text/image pages, active-side changes and failed-restore preservation. |
| Activity | Canonical v1 remains unchanged; credit only eligible visible text, no image-to-character substitution. Verify zero-text completion against the reference. | Clipped/covered/offscreen content, blank slots, previews, image-only sections/books and lifecycle interruption. |
| Viewing and motion | Initial whole-page fit, pinch zoom and bounded pan; enlarged drag pans rather than turns. Preserve typography boundaries and image viewer; no parsing/decode/font work in motion. | Gesture conflict, return to fit, explicit navigation, image/page transitions, actual-visible source coverage, cancellation, reduced motion and reference UI comparisons. |
| Resources and device performance | Bounded retained/allocation ownership for all constituents; unchanged parent AC4 thresholds. | Complex pages and image-heavy spreads, repeated turns, cancellation/disposal, device timings/RSS and retained evidence qualifications. |

## S3 dependency and S4 delivery ownership

S3 owns a valid, bounded imported publication, immutable source/resource
access and versioned classification metadata. It must not call S2's whole-book
fixed-layout rejection as an import-eligibility rule. Preserve original
rendition and per-item metadata; classify malformed/unsupported features
separately and expose preparation as source readiness, not proven rendering.
Rendering does not move into S3.

S4a owns metadata-to-page rendering and geometry, S4b owns source/activity
integration, and S4c owns product reading/UI and device acceptance. Their
explicit dependencies are in the parent execution plan and must be repeated
in their child artifacts when created. No task is started by this note.

## Accepted interaction and remaining technical gates

Q-FXL-1 was resolved by the user on 2026-10-26: initial fit-page display plus
whole-page pinch zoom and bounded panning. Parent design 5.3 and AC12 define
the resulting gesture/source contract. Enlarged drags pan content, ordinary
turn gestures resume at fit, and a stable view requires source-visible proof
before position/coverage publication. Page-local transforms cannot leak
across source identities or lifecycle generations.

Technical work still needed before S4a implementation approval: the exact
static feature matrix, a native rendering approach for the currently absent
positioning/SVG capabilities, cross-client font/geometry tolerances, and a
bounded page/spread resource model. These are researched in the child plan;
they are not claimed solved by the existing image path. A failed feasibility
gate returns evidence for review without reducing the accepted complex scope,
changing the pure Dart/Flutter boundary or lowering the performance target.
