# Research: S4a native fixed and mixed layout implementation

- Query: How can the existing native reader support authored fixed pages and mixed publications without losing source identity, fidelity or bounded ownership?
- Scope: internal source audit, installed primary dependency sources, and existing specification research; planning only.
- Date: 2026-10-27.
- Dependencies: completed S2 source/CFI/motion contracts and completed S3 immutable-publication/worker/resource handoff. S4b consumes the geometry contract below; S4c consumes prepared reading units and owns final product acceptance.

## Findings

### 1. Established code and reusable boundaries

Paths below are repository-relative unless absolute. Line anchors were inspected on this date.

| File | Current contract and implication |
| --- | --- |
| `lib/features/reader/data/worker/publication_layout_facts.dart:21` | Per-section mode, spine identity, effective rendition and optional inspected source/style facts already exist. Later uninspected sections are not proven horizontal/LTR. |
| `lib/features/reader/engine/style/css_properties.dart:76` | Current longhands cover prose; no general position, inset, stacking, transform, border or clip model exists. Unknown declarations become diagnostics rather than fatal capability verdicts. |
| `lib/features/reader/engine/style/css_stylesheet.dart:149` | Media matching admits unconditional screen/all rules, not general feature queries. Fixed-page style capability must inspect this boundary too. |
| `lib/features/reader/engine/pagination/section_preparer.dart:44` | `PrepareRequest.resources` consumes one preloaded section lease. Root-side fonts/paragraphs/layout are already separated from worker parsing. Preserve that ownership on a second preparation path. |
| `lib/features/reader/engine/layout/block_builder.dart:533` | Guarded full-raster SVG wrapper is reusable. General SVG is currently one image-like block with partial-feature markers. |
| `lib/features/reader/engine/layout/svg_support.dart:107` | Wrapper optimization requires one full-size untransformed/unclipped/unfiltered raster; keep this exact guard, never infer that every SVG is an image. |
| `lib/features/reader/engine/layout/svg_support.dart:162`; `svg_picture.dart:17` | Shiori's current SVG contract marks text, foreignObject, filters and non-data image resources partial. A successfully recorded picture does not prove source/fidelity support. |
| `lib/features/reader/engine/pagination/page_plan.dart:93` | `PageMapEntry` owns one section and whole-line source spans. It cannot describe two-source spreads, transformed glyphs, clipping or occlusion. |
| `lib/features/reader/engine/pagination/anchor.dart:181` | Existing proof validates CFI round trip and a text/image box inside a reflow content rectangle. Fixed scenes require transformed source geometry, not a page-index shortcut. |
| `lib/features/reader/engine/surface/page_surface_pool.dart:48` | Three presented units plus one reserve; default 16 MiB pictures and 48 MiB decoded images. Current surface embeds a `PreparedSection`; generalize the content contract while retaining leases. |
| `lib/features/reader/engine/surface/prepared_reader_session.dart:80` | Adjacency is section/page arithmetic. Introduce a reading-unit navigator for fixed spreads and nonlinear targets instead of hiding two sections behind one index. |
| `lib/features/reader/engine/surface/prepared_reader_session.dart:104`, `:142`, `:181` | `warm` coalesces only warm calls; ordinary prepare may duplicate the work. `optionalWorkAllowed` is a no-op. S4a must resolve both for a valid device checkpoint. |
| `lib/features/reader/engine/layout/font_registry.dart:29`, `:40`, `:68` | Loads SFNT fonts under content aliases, caps individual files at 32 MiB, and retains engine registrations for process lifetime. WOFF/WOFF2 and cumulative font limits are unproven. |
| `lib/features/reader/data/canonical/canonical_text.dart:114`, `:181` | Canonical v1 skips SVG subtrees. SVG text and XHTML inside foreignObject must not acquire new canonical characters merely because S4a renders them. |

S3's authoritative resource lifecycle is
`../archive/2026-10/10-26-runtime-server-library/research/s4-handoff.md:188`:
reopen the immutable leased path before preload; a reopen/detach retires old
adapters; the live reader and another prepare cannot independently commandeer
the session worker. Root preload buffers share the process-wide 128 MiB encoded
budget, including reservations. That limit excludes source graphs, decode,
paragraphs, font registrations and process RSS.

### 2. Proposed architecture and implementation order

1. **Capability inventory and oracle first.** Generate small synthetic EPUBs
   forcing every row of the matrix below. Record pinned reference revision,
   renderer/viewport/fonts, expected source nodes and exact features used.
   Add a typed `SectionCapability` verdict before recording any success surface.
   Distinguish malformed content, unsupported features, resource admission and
   render failures; fixed metadata itself is never an error.
2. **Authored page path.** Add `engine/fixed/` pure data/geometry preparation and
   root `dart:ui` scene assembly. Preserve the existing reflow preparer. Resolve
   author styles with a fixed-layout profile: no reader typography, paragraph
   spacing, margins or recoloring that changes authored geometry. Reuse CSS
   parsing/cascade, but extend typed properties rather than create a second
   incompatible parser. Worker transfer carries immutable scene inputs, not UI
   objects; root prepares paragraphs, images, vectors and compositing layers.
3. **Source-aware scene.** Retain original node/UTF-16 identity on scene nodes.
   Lay out nested boxes, then record painting order/transforms/clip/mask state.
   Text paragraphs retain cluster mappings; images retain original resource
   and source-element anchors. Keep source geometry independent of pictures.
4. **SVG integration.** Reuse `flutter_svg` for admitted vector subtrees; custom
   text/foreignObject and filter groups join the same ordered scene. Do not
   paint all SVG text as an overlay above all shapes, or flatten a whole page
   and lose anchor geometry. Never assume an opaque package picture exposes
   source geometry. Validate package APIs before choosing a subtree split.
5. **Reading units and surfaces.** Adapt both reflow pages and fixed source
   pages/spreads to a common prepared-unit contract. A spread contains explicit
   source-page slots, including synthetic blanks, and an active source side.
   Generalize `PageSurfacePool`/`PreparedReaderSession`, not the motion constants.
   Coalesce prepare/warm by captured content/layout/unit/direction generation.
6. **Downloaded-book owner.** Acquire a reader-owned file lease before the
   preparation route releases its lease; serialize worker access with S3's
   queue/owner. Capture server/content/settings generation across every await.
   Dispose abandoned preloads, partial scenes and constituent leases exactly
   once; publish only after all constituents and geometry are ready.
7. **Early iPhone checkpoint.** Run the full required geometry corpus through
   a minimal reader/probe after host gates, before S4b delivery or broad S4c UI.
   Include the minimum admission, dirty-drag/intentional-hold, queue/preparation,
   fallback, source/scene ownership and native sample-loss instrumentation
   needed to interpret the run. This is an S4a feasibility gate; S4c repeats
   and closes the complete product/device gate. This ordering is acyclic.

### 3. Required initial static capability matrix

This is a proposed executable minimum for the approved complex-static scope,
not a claim of full CSS/SVG conformance and not permission to drop features
required by an accepted fixture. Each row needs positive, boundary, nested and
unsupported-value fixtures. Unsupported required cases keep the gate failing.

| Area | Required property/value or construct coverage | Implementation/verification detail |
| --- | --- | --- |
| Metadata | package/per-item reflowable/pre-paginated; orientation auto/portrait/landscape; spread auto/none/landscape/both plus reference compatibility values; page-spread left/right/center | Preserve raw declarations and effective values; no global classification from the first section. |
| Dimensions | positive finite XHTML viewport width/height; SVG viewBox with nonzero origin and preserveAspectRatio; supported SVG absolute dimensions; raster intrinsic dimensions only for a verified raster source | Explicit precedence and invalid/missing/conflicting-dimension fixtures; never copy the reference's arbitrary 1000x2000 last-resort guess. |
| Cascade | existing selectors/cascade/inheritance/important; local linked/inline/imported CSS; screen/all and orientation/viewport-size feature predicates used by fixtures | Fixed authored viewport supplies layout query dimensions. Unknown selectors or required ignored declarations must affect capability completeness. |
| Box model | display block/inline/inline-block/none; position static/relative/absolute/fixed in authored page coordinates; top/right/bottom/left auto/length/percentage; width/height/min/max, margin/padding, box-sizing content-box/border-box | Resolve containing blocks and percentage dependencies; detect cycles and nonfinite geometry; preserve nested normal-flow text inside positioned boxes. |
| Text | horizontal LTR; family, SFNT face weight/style, size, line-height, letter/word spacing, text-align, indent, white-space, wrapping and decoration; baseline/sub/super | Original UTF-16 and cluster mapping; no arbitrary text chunking; fixture-authored fonts and line positions must remain stable. Probe WOFF/WOFF2 sources separately before admitting them. |
| Paint | color/background-color; local background-image with repeat/position/size; solid borders and radius; opacity 0..1; visibility visible/hidden | No line-only background approximation. Opacity/visibility/hidden descendants affect proof and coverage as well as pixels. |
| Stacking and transforms | z-index auto/integer; positioned and opacity/transform stacking contexts; 2D matrix/translate/scale/rotate/skew, transform-origin lengths/percentages | Preserve CSS paint ordering and inverse transforms; singular transforms fail source proof and cannot fabricate visibility. |
| Clip and compositing | overflow visible/hidden/clip; rectangular and path clips; group opacity; SVG alpha/luminance masks | Bounded offscreen layers; retain clip/mask evidence for source geometry; do not use untransformed bounding boxes for visibility. |
| SVG graphics | svg/g/defs/symbol/use; rect/circle/ellipse/line/polyline/polygon/path; fill/stroke rules, gradients, patterns, markers, local image resources, nested viewports | Retain source identity and reference resolution with cycle/depth/operation bounds; compare authored geometry and paint order. |
| SVG text | text/tspan x/y/dx/dy/rotate and text-anchor; packaged fonts; textPath/textLength/lengthAdjust as explicit high-risk fixtures | Package text rendering is not source-map proof. If required text positioning cannot be matched, keep the gate open rather than hide the text or accept a marker. |
| SVG foreignObject | static XHTML subtree using the same admitted box/text/style profile, with x/y/width/height, transforms and clips | Audit namespace and projected source identity; preserve SVG-ancestor canonical exclusion; no scripts/forms/embedded browser execution. |
| SVG filters | required generated cases: Gaussian blur, offset, color matrix, flood, composite, blend and merge, with filter units/regions | Existing dependency does not implement filters. Proposed bounded native layer/filter graph; color-space/edge/region equivalence is a feasibility spike, not assumed from similar API names. |
| Mixed navigation | reflow-to-fixed-to-reflow, centered/paired fixed pages, synthetic blanks, TOC fragments and explicit nonlinear targets | A reading unit never pairs a reflow page with a fixed page. Adjacent traversal and explicit TOC navigation preserve their separate reference rules. |

Values outside the tested profile (e.g. CSS 3D, arbitrary layout algorithms,
additional filter primitives) need capability diagnostics. If they are needed
for the approved complex corpus, add them to implementation or return evidence
for review; diagnostics alone do not convert a required failure into success.
Vertical/RTL and active scripted behavior remain outside the accepted release.

### 4. Dimensions and spread behavior

Reference source: `D:/Projects/lan-reader/node_modules/foliate-js/fixed-layout.js:6`,
`:112`, `:201`; compatibility tests in
`D:/Projects/lan-reader/client/test/foliateFixedLayoutCompatibility.test.ts:66`,
`:97`, `:119`, `:133`.

- Resolve dimension sources with explicit validity; SVG viewBox origin is a
  transform, not part of source width/height. Metadata dimensions and decoded
  image dimensions are separate values.
- Match the reference LTR portrait/spread active-side behavior and center-page
  placement, while preserving per-item overrides already required by the parent.
  Portrait can display only one side of a pair; landscape can display both.
- A blank slot has no section, CFI or canonical text. Each real side keeps its
  own source identity, and same-spread navigation can change active source
  without reconstructing the spread or borrowing its partner's location.
- Flush pairing at fixed/reflow boundaries. Preserve every source section,
  including consecutive centered pages and nonlinear targets. Determine
  adjacent linear traversal from the reference helper rather than assuming
  `sectionIndex + 1` is always correct.
- Fit uses the whole authored page/spread without cropping; S4c's view transform
  composes above authored transforms. Resize changes composition/view generation
  and triggers reproof; it does not rewrite source geometry or source identity.

### 5. Proposed typed geometry handoff to S4b/S4c

These are design names, not existing APIs. Final Dart types should be immutable
and avoid making reading activity depend on `ui.Picture` internals.

```text
PreparedReadingUnit {
  ContentIdentity content; LayoutIdentity layout; UnitId unit;
  List<SourcePageSlot> slots; SourcePageId activeSource;
  SourceGeometry geometry; ResourceAccounting accounting; SurfaceLease lease;
}
SourcePageSlot = BlankSlot | RealSlot(sectionIndex, spineIndex, sourcePageId,
  authoredSize, sourceToUnit, sourceDocumentIdentity)
SourceGeometry {
  GeometryVersion version; List<SourceFragment> fragments;
  List<ClipRegion> clips; List<MaskEvidence> masks;
  List<PaintOccluder> paintOrder; GeometryCompleteness completeness;
}
SourceFragment {
  SourcePageId page; int nodeIndex; Utf16Range? textRange;
  List<ClusterGeometry> clusters; SourceElementAnchor? element;
  Matrix sourceToUnit; ClipStack clips; MaskIds masks; int paintOrdinal;
  double effectiveOpacity; CanonicalMapping? canonical;
}
ResourceAccounting {
  sourceOwners; sourceGraphBytes; encodedLeasedBytes; decodedImageBytes;
  pictureBytes; paragraphCount; vectorBytes; offscreenLayerBytes;
  processFontAdmissions; outstandingReservations;
}
```

S4b combines this candidate geometry with an accepted unit, stable view transform,
actual foreground clip, active side, current generations and eligible dwell.
Clipping/masks/occlusion are evaluated after composing all transforms; source
order remains distinct from paint order. Fully covered/offscreen/transparent
text cannot count. Unknown coverage must be explicit and cannot produce a
successful required acceptance result. SVG canonical exclusion stays v1.
CFI proof resolves the original source and verifies the transformed target;
it never exports an invented CFI from display coordinates. Hit tests use the
same inverse-transform/clip/mask evidence. S4a must supply exact fixture geometry
and completeness results; S4b owns accepted position and observation semantics.

### 6. Resource and font feasibility gates

- Keep at most three displayed reading-unit surfaces plus one preparation
  reserve; charge **both** source pages and all children of every spread.
  Up to eight distinct fixed source pages may be needed for these four units;
  the old four-section owner cannot silently evict a live spread constituent.
  Add a source-graph/scene accounting budget as well as owner limits. Measure
  serialized and retained graph costs separately from process RSS.
- Preserve the shared 128 MiB encoded admission budget and current 16/48 MiB
  picture/image defaults as starting engineering limits. Test allocation before
  decode/filter-layer construction; the current oversize-image exception is
  not a hard peak bound. Decode dimensions follow displayed resolution and a
  bounded zoom policy, never an unlimited full-resolution page allocation.
- Register fonts once by content digest/face descriptors across books; reserve
  aggregate process-font count/bytes before registration, retaining real engine
  lifetime accounting after a book closes. A per-book registry reset cannot
  unload engine fonts. Select measured limits and recovery policy in the spike;
  never silently substitute a font for a required fixed fidelity case.
- Coalesce racing warm/prepare; suspend optional preload while motion is
  admitted. Cancellation/drain/retirement releases source, encoded, decoded,
  picture and temporary-layer owners without making stale results publishable.
- Verify near-limit reopen/rapid turns/spread churn/zoom preparation and repeated
  book changes on the iPhone. No host retained-byte figure establishes full
  iPhone RSS, peak allocation or a leak-free font lifetime.

### 7. Testable gates and tolerances

- Synthetic corpus has separate metadata, box, typography, stacking/transform,
  clipping/mask/filter, foreignObject, SVG-only spine, source/spread and mixed
  cases. Required features must render completely; zero missing/reordered source
  fragments, zero silently discarded resources and zero invented sections.
- Proposed deterministic geometry threshold: <=0.5 authored CSS px for boxes,
  transforms, clips and fixture-font baseline positions; exact text/CFI/source
  ranges and paint order. Confirm the threshold using pinned same-font baselines
  before broad implementation. Whole-page native reflow tolerance does not
  excuse authored fixed-page line-wrap or geometry changes.
  A0 amendment (2026-10-27): same-font baselines and unsnapped advances met
  this threshold. The value is unchanged; `../design.md` "Fidelity and proof
  handoff" now defines the compared quantity per channel. Text is gated per
  shaping cluster; snapped DOM Range boxes and ligature component metrics are
  diagnostics. Evidence: `a0-measurement-review.md`.
- Compare paired renders in normalized authored coordinates. Antialiasing-only
  edge differences are classified only by the D4 edge rule in `../design.md`,
  and reproducible reference defects only by D3 recorded exceptions; clipping,
  hidden text, changed line breaks, missing layers and font substitution
  remain failures. Do not accept a broad image-difference percentage that
  hides missing small objects.
- Exercise all 23 private mixed-book sections, including six fixed image pages;
  publish only anonymous counts/results, not book names, text, paths or images.
- End-S4a iPhone runs preserve parent AC4: three repetitions, >=99% active-motion
  UI/raster frames within 8.333 ms each, no unexplained >=50 ms stall, P95 warm
  admitted-input-to-first-motion submission <=two nominal intervals. Record
  resource and sample-loss evidence, hold classification and actual cadence.
  Physical presentation remains separately qualified. S4a success is not S4c
  product acceptance or a waiver of the seven retained S2 conditions.
- A failed spike returns exact unsupported constructs, geometry diffs, resource
  peaks and options to the parent. It must not auto-reduce complex fixed layout
  to image pages, introduce a WebView, or weaken the performance threshold.

## External references and related specs

- Existing reviewed specification research: parent `research/fixed-layout-expansion.md` cites EPUB 3.3 layout/content dimensions and EPUB Reading Systems 3.3 fixed layout. This audit preserves those contracts; it does not claim full reading-system conformance.
- Installed primary source `C:/Users/H3C/AppData/Local/Pub/Cache/hosted/pub.dev/vector_graphics_compiler-1.3.2/README.md` lists basic graphics/text/references/gradients and explicitly excludes filters/some text attributes. Text availability does not prove Shiori source mapping or fixed-layout fidelity.
- Installed Flutter SDK primary sources `D:/DevTools/flutter/bin/cache/pkg/sky_engine/lib/ui/painting.dart:7003`, `:7056`, `:7117` expose layers/transforms/path clips; `:4335` exposes image filters. `ui/text.dart:3074`, `:3114` expose range/glyph geometry and `:3791` font registration. These primitives support the proposed spike, not proven SVG/CSS equivalence.
- Relevant project specs: `.trellis/spec/flutter/reader-engine.md`, `state-management.md`, `data-layer.md`, `diagnostics.md`, `testing.md`, `quality-guidelines.md`.

## Caveats / Not Found

- No product code, tests, benchmark or device run was performed during this research. Renderer feasibility and numeric aggregate font/source/layer limits remain measured implementation gates.
- Primary web requests were attempted but returned no usable content in this researcher run; dependency/API claims above are restricted to the installed primary sources and existing reviewed standards research.
- Exact full CSS/SVG support is not currently implemented. The matrix is a proposed minimum with explicit failure gates; no existing product intent requires a new user scope decision before planning this work.
- Font format conversion, difficult SVG text attributes, filter color-space parity and partially transparent mask/occlusion proof are the highest-risk native spikes. Their failure requires review; neither a partial marker nor unverified coverage closes acceptance.

## Final artifact review (2026-10-27)

- Reviewed S4a PRD/design/implementation plus S4b/S4c design and S4c execution. The required capability profile, typed geometry, worker reservation, spread constituent accounting and early-device dependency agree; no silent scope reduction or measured-feasibility claim found.
- Resolved and verified at S4a `design.md:84`: A0 establishes provisional finite limits from host fixtures, A3 enforces them, and A5 validates them on device. This now agrees with `implement.md:18`; unbounded classes cannot wait until A5.
- Resolved and verified at S4a `design.md:85` and S4c `design.md:101`: typed process-font-exhausted preserves accepted state, explicitly rejects close/retry-as-unload, and explains a possible user-initiated app restart without automatic restart or silent required-font substitution. S4c consumes this actionable recovery state. No outstanding finding remains from this review.
