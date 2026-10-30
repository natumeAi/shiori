---
name: flutter-reader-fixed-layout
description: Fixed-layout SVG presentation, replaced-element sizing, authored evidence raster, paint roles, filtered/clipped/masked evidence, display-scale preparation, alpha footprints and D9 gates
paths:
  - lib/features/reader/engine/fixed/**
  - lib/features/reader/engine/layout/image_cache.dart
  - lib/features/reader/engine/surface/fixed_unit_surface.dart
  - lib/features/reader/data/geometry/**
  - test/features/reader/engine/fixed/**
  - test/features/reader/engine/surface/fixed_image_reservation_test.dart
  - test/features/reader/data/geometry/**
  - tool/reader/fixed_layout_*.dart
---

# Fixed-Layout SVG and Coverage Evidence (S4a A2/A3)

## 1. Scope / Trigger

Apply this contract when changing SVG presentation cascade, SVG text style
sheets, inline SVG sizing, the authored evidence raster, paint roles, filter /
clip / mask evidence, display-scale preparation, the D9 sample harness helper,
`GeometryAlphaFootprint` or any consumer of paint alpha. It states only the
finished, stable contracts. Plans reserve safe upper bounds before allocation;
`FixedSceneAdmission.reconcileEvidence` shrinks the shared unit evidence charge
to every live footprint owner plus one unit-placement wrapper set after evidence
production. Host passes establish no device raster parity (A5). Paths are
relative to `lib/features/reader/` unless a repository-root path is given.

- Geometry published by a prepared scene must be exact or explicitly
  incomplete. An incomplete scene is refused, never partially accepted.
- `data/geometry/` is pure Dart (no `dart:ui`); native rasterization stays in
  `engine/fixed/`.

## 2. Signatures

| Boundary | API / source |
| --- | --- |
| SVG cascade | `SvgPresentation.resolve(SourceDocument, Iterable<String> sheets, {viewportWidth, viewportHeight, SvgFeatureRegistry? features}) -> SvgPresentation` with `values`, `problems`, `handedOffDiagnostics`; `SvgPresentation.parseStylesheet(String, {List<Message>? errors}) -> StyleSheet` (`engine/fixed/svg/svg_presentation.dart`) |
| Feature no-effect hook | `SvgFeature.presentationIgnored(String property, String value) -> bool`, `presentationRefusal(property, value) -> String?` (`svg/svg_feature_hooks.dart`; implemented by `SvgFilterFeature`, `SvgClipMaskFeature`) |
| SVG text styles | `FixedSvgTextFontService.presentation` (late, resolved from the section document and its linked/imported sheets) (`engine/fixed/fixed_svg_text_fonts.dart`) |
| Inline SVG size | `FixedSvgViewport.resolveInline(SvgSourceDimensions, {style, containingWidth, containingHeight, cssWidth, cssHeight}) -> FixedSvgViewport` (`engine/fixed/fixed_svg_viewport.dart`); min/max clamp is `FixedUsedBoxSize.constrain` (`fixed_scene_sizing.dart`) |
| Clip/mask bounds | `SvgClipMaskFeature._localBounds(plan, node)` over the expanded instance tree (`svg/svg_feature_clip_mask.dart`) |
| Alpha footprint | `GeometryAlphaFootprint(...)` explicit grid; `.uniform({width, height, pixelSize, origin, alpha, transform, masks})`; `fromRgba`, `fromSamples`, `fromTiles({width, height, origin, visitTiles, reserve})`; `storageOverhead = 128`, `storageBytes`, `uniformAlpha`, `alpha`, `alphaAt(GeometryPoint) -> int?`, `placed(AffineTransform, {maskId})`, `withMasks` (`data/geometry/paint_geometry.dart`) |
| Placement | `FixedSectionPreparer.geometryForUnit(sourceToUnit, {registryPrefix, paintOrdinalOffset})` -> `placeSourceGeometry` (`engine/fixed/fixed_section_preparer.dart`, `data/geometry/place_source_geometry.dart`) |
| D9 samples | `classifySvgSamples({document, elements, clips, fragments, paints, referenceComputedPaint, samples, actual}) -> List<SpikeSampleRecord>` (`tool/reader/fixed_layout_svg_samples.dart`) |
| Evidence raster | `AuthoredEvidenceRaster.rasterize(picture, {width, height, budget, reserve, checkCancellation})`, `readImage`, `isOpaque`, `visitTiles`, `tilePixels`, `scratchPixels`, `tileSide = 512` (`svg/svg_graphics_geometry.dart`, shared with XHTML in `fixed_scene_coverage.dart` `_FixedCoverage._resolveCoverage`) |
| Evidence extent | `SvgGraphicsPlan.inspect({..., evidenceSize, evidenceOrigin, preparationScale})`, `evidencePixels`, `reservation({hostOpacity, placement})` (`svg/svg_graphics_plan.dart`) |
| Paint role | `GeometryPaintRole { combined, fill, stroke }`, `GeometryPaint.role` (default `combined`) (`data/geometry/paint_geometry.dart`) |
| Post-paint evidence | `SvgFeature.captureOutput(SvgFeatureNode) -> bool`, `Future<void> postPaint(SvgFeaturePostPaintContext)` (default no-ops); `SvgFeaturePostPaintContext.outputFor(node)`, `.rasterBudget`, `.checkCancellation` (`svg/svg_feature_hooks.dart`) |
| Filter evidence | `SvgFilterFeature.geometry(SvgFeatureGeometryContext)`, `.captureOutput`, `.postPaint` (`svg/svg_feature_filters.dart`) |
| Clip/mask evidence | `SvgClipMaskFeature.geometry`, `.postPaint`; helpers `_clipFootprint`, `_maskCoverage`, using preparation/post-paint `evidenceExtent` (`svg/svg_feature_clip_mask.dart`, `svg/svg_feature_hooks.dart`) |
| Preparation scale | `FixedPreparationScale(value)`, `.authored()`, `.fit({authoredWidth, authoredHeight, viewWidth, viewHeight, devicePixelRatio})`, `pixels(authored)`, `imageTarget(w, h)` (`engine/fixed/fixed_preparation_scale.dart`) |
| Plan with scale | `FixedSectionPreparer.plan(source, {scale})` -> `FixedPreparationPlan.inspect(source, {svgFeatureHost, scale})` with `scale`, `imageTarget(path)`, `decodedImageBytes`, `authoredImagePaths` (`fixed_preparation_plan.dart`) |
| Scale derivation | `PageSurfacePool.prepareFixedUnit(unit, {layout, loadSource, fonts, preparationScale?, cancellation})` (`engine/surface/fixed_unit_surface.dart`) |
| Image decode | `FixedImageRequest.acquire` / `acquireTarget(cancellation, w, h)` -> `FixedImageLease.dispose()` (`fixed_source_lease.dart`); `ReaderImageCache.lease(key, bytes, {targetWidth, targetHeight, reservation})`, `ImageLease.release({discard})`, `ImageAdmissionException` (`engine/layout/image_cache.dart`) |

## 3. Contracts

### SVG presentation cascade

CSS participates for SVG elements through one parser entry point,
`parseStylesheet`, used by both `SvgPresentation.resolve` and the SVG text sheet
collector. It protects standard `filter:` declarations from csslib's legacy IE
filter parser (which swallows `none !important`) by aliasing the property
identifier outside comments/strings and restoring it before the cascade and
diagnostics; source offsets are preserved.

Winner order per node and property: `!important`, then selector specificity,
then source order; inline `style` outranks every selector. A declaration whose
feature owner reports `presentationIgnored` (`filter` with `none`/`initial`/`unset`; `clip-path` and `mask` with
`none`/`normal`/`auto`/`initial`/`unset`) is **not discarded**: it enters
the cascade with the literal value `none`. The winning reset therefore overrides
earlier rules and presentation attributes; a weaker reset never disables a
winning effect. Values the owner refuses are recorded in `problems` and skipped.

### SVG text stylesheets

`FixedSvgTextFontService` builds the SVG text cascade from the section document:

- Authored media evaluation uses `CssSheetBuilder.matchesMediaAttribute` with
  the authored dimensions (`resolveAuthoredDimensions`); unresolved dimensions
  refuse `svg-text-css-viewport`.
- `<style>` is eligible when `type` is empty/`text/css` and its media matches.
  `<link>` is eligible for `rel` containing `stylesheet`, not `alternate`, not
  external, with matching media. Ineligible sheets are skipped and not read.
- A link href resolves with `resolveUrl(href, page.stableId)`; an `@import`
  resolves against the declaring sheet's path; the fragment is stripped. Import
  media queries are evaluated the same way. External URLs are skipped.
- Depth over 4, a cycle, or a missing local resource refuses with
  `svg-text-css-depth`, `svg-text-css-cycle`, `svg-text-css-resource`
  (`SvgFeatureRefusal`).
- The loader rewrites inline `@import` URLs to length-neutral resource tokens.
  Authored style text is recovered **lazily**: the raw section resource is read
  only when an eligible inline `<style>` actually contains an `@import`, matched
  by style ordinal (a count mismatch falls back to the projected text, like
  `CssStyleResolver`). Ordinary rules and `@font-face` reuse the already loaded
  projected document, so an unsupported-SVG refusal happens with zero resource
  reads. This is not a promise that all linked/imported CSS is read-free.
- Projected source nodes, UTF-16 offsets, canonical v1 and CFI are unchanged.

### SVG text coverage and geometry gate

- Each source span's native text coverage uses
  `SvgFeaturePreparation.evidenceExtent` and `rasterBudget`, with cancellation
  checks, through the shared `_coverage` helper. The extent includes the
  enclosing authored bounds and effective prepare-time placement/origin; the
  local SVG viewport size cannot substitute for it. Retained per-source grids
  (including footprint overhead) are admitted inside the prepaid text envelope
  before rasterization; serial raster scratch uses the shared SVG subdivision.
- `measureSvgTextSourceGeometry` retains all local Definition-B channels and
  additionally transforms cluster baseline starts/vectors by `sourceToUnit`.
  Screen-space starts, total advance and single-component rotation displacement
  must also pass the unchanged 0.5 CSS px gate. Expected screen placement is
  independent of native mappings: recorded oracle element screen boxes anchor
  the local character extent union for the pinned translation-only corpus;
  path probes explicitly use their recorded 8px capture-host margin. The recorded
  WebKit box snapping contributes about 0.01522px to the screen check. Missing
  screen evidence fails; an implicit identity mapping cannot pass that case.
- Regressions compare every placed text alpha sample in an offset XHTML box,
  exercise equal-area plan/prepare extents with different origins, and reject
  translated, scaled and rotated published mappings while conserving all 12
  cluster comparisons. Required nested/probe controls still pass. Local checks
  remain active so screen-box snapping cannot hide a local geometry violation.

### Replaced-element (inline SVG) sizing and positioning

In-flow inline SVG and admitted XHTML `img` use atomic paragraph placeholders, retaining
their source element geometry and independent image/SVG paint. Nested spans do
not consume their descendants as text. Absolute/fixed descendants, including those
nested in spans, bypass placeholder allocation and placement and use their
containing block. When an absolute descendant's nearest positioned ancestor is
a non-atomic inline element, the first/last inline fragment containing-block
rectangle is not retained; preparation refuses explicitly with
`inline-positioned-containing-block`, including multiline and nested spans,
rather than substituting a block ancestor. Viewport-fixed descendants and
descendants with a nearer positioned block/inline-block retain their own
containing-block path. Shifted-paragraph admission includes relative inline-blocks
and other relative inline atomic elements. Unsupported replaced elements and missing
image resources refuse explicitly. Before publication, source conservation checks
every rendered replaced root against its prepared box/scene and every noncollapsed
XHTML text node against paragraph mappings; hidden subtrees and CSS-collapsed
indentation are excluded. A placeholder-only paragraph has no text paint.

Inline color backgrounds publish source-linked decoration evidence for each line
fragment, behind text and replaced children, using the owner's placement, opacity
groups and content clips. Inline borders, background images, nonzero padding,
margins or radii, and decorated spans containing replaced placeholders currently
refuse explicitly (`inline-box-decoration` / `inline-replaced-decoration`).

`resolveInline` follows CSS replaced-element sizing. A `viewBox` supplies only an
intrinsic ratio. With no intrinsic size the default object box is 300x150.
Constraint resolution is axis-dependent:

| Authored axes | Rule |
| --- | --- |
| One definite, one auto, ratio known | Constrain the definite axis with min/max first, then recompute the auto axis from the ratio, then constrain it too (`width:100%;height:auto;max-width:100px` on a 4:3 `viewBox` in a 320px block -> 100x75) |
| Both auto, ratio known | Pick the common scale satisfying both axes (CSS 2.2 10.4); if limits conflict honor each limit and let the ratio break |
| Both definite or no ratio | Each axis constrained independently |

`FixedUsedBoxSize.constrain` gives min precedence over max and applies
`box-sizing`. Nonpositive, non-finite or unsupported-unit lengths return
malformed/unsupported dimensions, never a guessed size.

The frozen SVG used viewport is a size, not its XHTML placement. Before SVG
preparation, `_layoutSvg` resolves the replaced box using the XHTML scene's
shared `_positioningBlock` and `_positionedOrigin` helpers. Absolute positioning
uses the enclosing positioned box (the initial authored page when there is no
positioned ancestor), fixed positioning uses the authored page,
and relative positioning offsets the normal-flow/paragraph placeholder box.
Left/right percentages use containing-block width; top/bottom percentages use
its height. Left/top take precedence over right/bottom; trailing insets subtract
the used box size and trailing margin. Nested positioned ancestors, their final
layout shifts and ancestor transforms contribute exactly once. Ancestor layout
shifts skip viewport-fixed subtrees, preserving their authored-page coordinates.

`box.transform.compose(box.svgContentTransform)` is passed to
`SvgGraphicsPlan.prepare(placement:)` after placeholder/ancestor placement is
final. That same placement determines feature `evidenceExtent` (including its
origin), paint alpha and fragment `sourceToUnit`; the local SVG viewport must
not replace it. CSS positioning diagnostics, including unsupported units, stay
with the XHTML box rather than disappearing into SVG presentation handoff.
Unsupported positioning such as sticky or calc insets refuses typed, never a
complete scene at a guessed flow position. Regressions compare authored native
pixels and published alpha over the whole page, transformed source corners and
element CFI round-trips; the inline relative case also compares an independent
unpositioned paragraph control to preserve fractional native baselines.

### Clip/mask `objectBoundingBox` bounds

Bounds for `clipPathUnits`/`maskUnits`/`maskContentUnits="objectBoundingBox"`
come from the **expanded instance tree** (`node._instance`), not source children:
shape and image leaves use the same geometry as painting (`_shape(instance)`),
each mapped through the inverse of the owner's transform into owner space. This
keeps `use` x/y, nested `use`, referenced-target transforms and `symbol` viewport
overrides. No leaf yields an empty rectangle. Layer sizing is unaffected.

Leaf extents are taken from the geometry **transformed into owner space** before
the extrema are computed, never by transforming an already axis-aligned box:
circle/ellipse extents are analytic, a rounded rectangle is its transformed inset
rectangle plus the ellipse support extents, and path cubics are transformed and
then solved with `_pathBounds` (native `Path.getBounds` includes off-curve
control points). A radius-20 circle rotated 45 degrees therefore has diameter 40,
not 56.57.

### Alpha footprint (`GeometryAlphaFootprint`)

A footprint is native alpha at an explicit authored grid (`pixelSize` defaults to
one CSS pixel) with a grid-to-unit `transform`; it is actual post-clip paint,
never an enclosing-box approximation. Masks stay separate compositing evidence.

Two forms exist:

- **Explicit grid**: `width * height` bytes, immutable view.
- **Uniform**: one alpha (0..255) over the same rectangle. `alpha` is a
  read-only virtual `List<int>` of length `width * height` (writes throw
  `UnsupportedError`); no grid is allocated. Logical accounting is
  `storageBytes = storageOverhead (128) + (uniform ? 0 : grid length)`.

`fromSamples`/`fromRgba` classify borrowed samples before allocating anything,
call `reserve(128 + (uniform ? 0 : w*h))` before any retained grid exists, and
trim **only zero-alpha margins** (origin shifts by whole `pixelSize` steps; an
all-zero input keeps its rectangle; `trim: false` disables trimming). Nonuniform
grids keep every original sample, antialiasing included. Downsampling and
enclosing-box substitution are forbidden. A footprint may be uniform only when
every retained sample is provably equal.

`fromTiles` is the streaming form for rasters too large to read back whole (see
"Authored evidence raster"). The producer lends ordered, non-overlapping RGBA
tiles through `visitTiles`; the stream must be row-major with equal tile height
within a band, cover the grid exactly once and carry `w*h*4` bytes per tile
(`ArgumentError` for an incomplete, overlapping, unordered or out-of-range
stream). Pass 1 finds the nonzero bounds and detects uniformity without storing a
grid; the result is uniform when every sample is zero, or when all nonzero samples
are equal and fill their bounding rectangle. It then calls
`reserve(128 + (uniform ? 0 : w*h))` for the **trimmed** payload before any
retained allocation. Only a nonuniform result allocates the trimmed grid once and
replays the tiles into it in pass 2 (no extra alpha copy); a uniform result
allocates none and never runs pass 2. Trimming, equality and placement are
identical to the other forms.

Placement is identical for both forms: `placed(placement)` composes
`placement.compose(transform)`, shares the immutable samples and re-places masks;
`geometryForUnit` therefore never copies or resamples alpha. `withMasks` shares
samples. Equality/hash compare dimensions, `pixelSize`, `origin`, `transform`,
sample values and masks, so a uniform footprint equals an explicit grid of the
same values. `alphaAt(point)` inverse-maps a unit-space point to the grid:
`null` when the placement is singular (must never prove visibility), `0`
outside the rectangle, otherwise the sample.

**Consumer rule:** every alpha consumer must treat both forms identically. Read
through `alpha[y * width + x]` or `alphaAt`; do not assume a backing
`Uint8List` (`buffer`, `asTypedList`, `is Uint8List`), do not use `alpha.length`
as byte cost (use `storageBytes`), and do not special-case `uniformAlpha` except
for optimization that is sample-equivalent. Iteration cost is the sample count,
not the retained bytes. Complete `SourceGeometry` requires an `alphaFootprint`
on text, image and decoration paints and `exactCoverage` on all paints.

### Authored evidence raster

Alpha evidence is the native alpha of the actual drawing at the published
one-CSS-pixel resolution. `AuthoredEvidenceRaster` is the only path that
produces it from a recorded `ui.Picture` (SVG leaves, roles, clips, masks, filter
output) and the XHTML scene builder (`_FixedCoverage._resolveCoverage`, raster
`ceil(width) x ceil(height)` of the authored page, same helper). Contract:

- **One whole raster.** `rasterize` renders the picture once at the full authored
  size (`width x height`, root coordinates, placed origin; exact native AA), then
  reads it back through **exact integer-aligned, unfiltered tile copies**
  (`tileSide = 512`; `drawImageRect` with `FilterQuality.none`, no AA, `BlendMode.src`,
  then `toImage` and `toByteData(rawRgba)`), streamed into
  `GeometryAlphaFootprint.fromTiles`. There is no whole-image RGBA readback and no
  second authored-size buffer.
- **Tiled or strip rasterization is forbidden.** Re-rendering the picture per
  tile or strip changed native rotated-edge AA by 1 (alpha 106 whole versus 105
  per strip), so only the copy of the already rasterized image is allowed.
- **Peak.** `scratchPixels(w, h) = w*h + tilePixels(w, h)` with
  `tilePixels = 2 * min(w, 512) * min(h, 512)` (one tile image plus its RGBA
  readback). `rasterize` reserves the whole raster with `budget.reserveLayer`
  (checked multiplication first), admits the full tile-pair peak before the first
  native allocation, then reserves and releases each tile pair serially. A refusal
  (`SceneAdmissionException`) therefore happens before any native image exists.
- **Release.** Tile image, tile picture and tile lease are released in a `finally`
  per tile; the authored image is disposed and its lease released after both
  `fromTiles` passes. Cancellation (`checkCancellation`, `ReaderWorkGuard`) and
  late failures release every image and lease exactly once. The caller owns the
  input picture.
- **Retained payload.** `reserve` receives the trimmed payload from `fromTiles`
  before the grid is allocated. XHTML charges it as `vectorBytes` and keeps the
  lease until scene disposal; SVG prepays it in `SvgGraphicsPlan.reservation`
  (one worst-case footprint per published role / mask / clip copy, then `reserve`
  is a no-op).
- **Opacity.** `isOpaque` proves opacity from every decoded alpha sample of a
  borrowed image (tile-wise, charged like a tile pair); never infer it from a file
  type.
- **Uniform shortcuts** are allowed only when provable without a raster:
  `uniformPixelRectangle` (axis-aligned or 90-degree transforms, integer-aligned
  edges, no radii, intersected with every clip rectangle), used for undecorated
  XHTML backgrounds (no border/image) and for an unstroked, non-rounded,
  non-`url()` SVG `rect` (one native 1x1 sample supplies the alpha). Everything
  else rasterizes.

SVG evidence uses one **root-coordinate extent**, independent of the replaced
viewport: `SvgGraphicsPlan._evidenceBounds()` is the enclosing
`evidenceSize`/`evidenceOrigin` when `FixedPreparationPlan` supplies it for an
inline SVG (always, in production), otherwise the outward-rounded bounds of the
viewport transformed by the effective placement, root transform and `x`/`y`,
unioned with the root canvas. Fractional host offsets stay in the native matrix;
a raster whose origin is shifted is mapped back with `footprint.placed(translate)`
(samples shared, never resampled). An extent larger than the `layerPixels` cap
refuses `layerPixels` before any multiplication or allocation. Evidence
reservation follows design item (3): scaled display layers + one authored evidence
raster (`scratchPixels` of the extent, taken as the maximum over serial evidence
users, not their sum) + retained evidence bytes; caps are unchanged.

### Paint roles (fill / stroke)

`GeometryPaintRole { combined, fill, stroke }` labels which SVG paint operation a
`GeometryPaint` covers; the default `combined` is the legacy/composited form and
takes part in `==`/`hashCode`.

- SVG shapes publish one record per visible role (`fill != none` -> `fill`,
  `stroke != none` -> `stroke`; neither -> `combined`) with the element's
  `paintOrdinal` and source fragment. Images, text, foreignObject and feature
  output publish `combined`. Published paints sort by ordinal, then role index
  (`combined`, `fill`, `stroke`), so stroke sits above fill. Marker descendants
  keep their own later ordinals.
- A mixed shape's footprints come from replaying the same `_compile` pipeline once
  per role with the other paint disabled, so gradients, patterns, dashes, caps,
  joins and offsets are the actual native drawing; each replay goes through
  `AuthoredEvidenceRaster`. A single-role shape reuses its normal picture. Never
  estimate stroke support from the centreline, bounds or colour.
- Only the normal paint order (fill, stroke, markers) is published; any other
  `paint-order` value is refused (`UnsupportedSectionCapability`).
- The role must survive every copy: `placeSourceGeometry`, `_copyPaint` and
  `addClipTo`'s annotation (clip/mask), and the SVG paint merge in
  `fixed_scene_geometry.dart`. A constructor that rebuilds a `GeometryPaint`
  without `role:` is a defect.

### Filtered-output evidence

Source footprints never prove filtered visibility, so the filter owner replaces
them with footprints of the **actual filter output**.

1. `SvgFilterFeature.geometry` removes every paint record of the filtered instance
   subtree (recording their ordinals), keeps the source fragments (identity,
   anchors, transforms, text ranges) and validates the root-space cache region
   (over 4096 px a side or over `2 * ceil(w) * ceil(h)` px: `SvgFeatureRefusal`
   `svg-filter-region`).
2. `captureOutput` opts the outermost filtered instance in. `_paintTree` records it
   exactly once in root coordinates, including its feature wrappers and its own
   element opacity, and draws that same scene-owned picture into its parent;
   siblings are never part of the capture. Nested filter intermediates are marked
   covered and publish identity only.
   Input capture excludes the inherited `SvgFeatureNode.clips` by ID through
   `captureDefault(excludeViewportClipIds: ...)`, retaining descendant viewport
   clips and element-local clip-path/mask wrappers. The final filter paint applies
   the deferred SVG/host viewport clips exactly once to all output, including
   flood/blur/offset. Nested filters inherit the exclusions, add their own during
   input capture, and replay only clips not deferred to an outer filter's output.
   This wrapper is inside the isolated capture, so display and postPaint evidence
   share the same once-clipped alpha. Identity-filter fractional viewport edges
   must equal the unfiltered control pixel for pixel, including antialiasing; a
   nested hidden 30x30 SVG must retain zero exterior alpha. Explicit visible
   overflow keeps negative filter output available.
3. After painting, every feature's `postPaint` is **awaited** (cancellation checked
   around each), before `featureCoverage.require`, geometry assembly and
   publication, so a suspended hook cannot publish a scene. The filter postpass
   removes source paints again (later text/foreignObject producers cannot restore
   input evidence) and collapses mask ids consumed inside the subtree on source
   fragments (their effect is already in the output alpha).
4. For each captured instance the helper replays ancestor opacity layers in native
   nesting order over the capture and rasterizes the outward-rounded transformed
   filter region through `AuthoredEvidenceRaster` at `pixelSize = 1` (output
   beyond the source bounds is included), then places the grid at the region
   origin. The published `GeometryPaint` is `kind: image`, role `combined`,
   `effectiveOpacity: 1`, no clip/group ids: opacity and consumed masks are baked
   into the samples and must not be applied again. Transparent output compresses
   to uniform alpha 0 (proves no visible paint); partial/flood subregions
   compress only when every retained sample is equal.
5. `markIncomplete(node, GeometryGapKind.paint, ...)` is reserved for a missing
   source graph, missing source bounds (not `display: none`), a missing output
   capture, and an **uncaptured ancestor clip or mask** (not folded into the
   isolated capture, so no output proof is invented). `filter: none`/no filter is
   `markCovered`. Unsupported constructs stay `UnsupportedSectionCapability` /
   `svg-filter`.

Filter admission: with `P = ceil(viewport width) * ceil(viewport height)`, each
filter prepays `2P * (primitiveCount + 5)` raster pixels (cached sources, one image
per primitive and scratch) and `128 + 2P` retained vector bytes. The shared
evidence slot is `max(base evidence, 2P + 2 * min(2P, 512 * 512))`: all retained
DAG caches may coexist with one evidence raster and one tile pair, never two
evidence rasters. Every cache image holds a live lease in the same prepaid raster
subdivision (`SvgFeaturePostPaintContext.rasterBudget`). Dart handles close after
`postPaint`; the scene pictures keep the native references and their leases until
disposal. Filter DAG caches and their display stay at authored scale (see
"Display-scale preparation"). An incomplete scene is refused with
`FixedPreparationFailure(RenderSectionCapability(... 'incomplete-geometry'))` and
publishes no picture or fragments. Never replace missing evidence with an invented
region solid, the input footprints or a relaxed admission.

### Clip and mask evidence

- **Clips are replayed, not point-sampled.** A binary point-in-path footprint
  published 255 where the native clipped alpha is 191, so it was removed. `geometry`
  only attaches registered clips and masks; the awaited `postPaint` replaces each
  clipped paint's footprint by replaying the compiled native leaf under its ordered
  ancestor and own `clipPath`s (per role for a mixed shape, with
  `prep.images.forEvidence` for admitted images) through `AuthoredEvidenceRaster`.
  No analytic clip shortcut exists; an integer rectangle becomes uniform only after
  every native sample was inspected. A pattern image that is not among the admitted
  images refuses `missing-admitted-svg-image`; alpha grids are never clipped or
  multiplied as a substitute. A per-source feature paint that cannot be replayed
  from its combined picture is marked clip-incomplete.
- **Placed extent.** Clipped replays and mask coverage use the same root-coordinate
  extent as unclipped evidence (`SvgFeaturePreparation.evidenceExtent` and
  `SvgFeaturePostPaintContext.evidenceExtent`, populated where preparation computes
  `_evidenceBounds(placement)`):
  they translate by `-extent.origin`, rasterize the extent through one whole raster
  and return `footprint.placed(translate(origin))`. The extent is required and
  admitted for that preparation, including a direct `prepare(placement:)` override.
  Never infer extent equality from pixel counts: placements at +100 and -100 can
  have equal area and different origins. Both clip and mask evidence must retain
  the effective negative-origin samples and release every admitted owner.
- **Masks.** `_maskCoverage` rasterizes the mask content once (alpha, or luminance
  through a `saveLayer` colour filter) over that extent and streams it through
  `fromTiles`; mask preparation is serial and precedes leaf evidence. It uses a
  shared preparation `rasterBudget` (no second debit of the outer ledger).
  Peak: `W*H + 2*min(W,512)*min(H,512)` RGBA pixels. Mask content that is
  an `image`, text, `foreignObject` or `filter` refuses `svg-mask-content`.

### Display-scale preparation

`FixedPreparationScale` is the frozen device pixels per authored CSS pixel.
`fit` returns `min(viewWidth / authoredWidth, viewHeight / authoredHeight) * devicePixelRatio`
(every input finite and positive, else `ArgumentError`); `pixels(authored) =
max(1, ceil(authored * value))`; `imageTarget(w, h)` clamps each axis to the
intrinsic size, so a decode is never larger than intrinsic. `authored()` is scale 1.

**Flow.** `PageSurfacePool.prepareFixedUnit` derives one scale per unit from the
frozen `LayoutIdentity` (viewport, DPR) and the unit's authored page or spread
extent (`_fixedUnitExtent`, shared with composition); an explicit
`preparationScale` overrides it. It is passed through `FixedSectionPreparer.plan`
to `FixedPreparationPlan.scale`, which derives the image targets
(`imageTarget(path)`), `decodedImageBytes`, XHTML opacity layers
(`displayPixels * layers`) and, through `SvgGraphicsPlan.preparationScale`, the
SVG opacity/host-opacity buffers and feature layers. The **same plan is the
reservation and the allocation input** (`FixedImageRequest.acquireTarget`, the
cache credit `ImageReservation`). The corpus and every harness driver pass
`FixedPreparationScale.authored()` explicitly, so their verdicts are unchanged.

| Site | Scale |
| --- | --- |
| Raster image decode target and `decodedImageBytes` | Display (clamped to intrinsic) |
| XHTML opacity layers; SVG opacity / host-opacity buffers | Display (`displayPixels`) |
| Clip, mask, pattern and dash layers (`_chargeLayers`) | Display (charge scaled by `displayPixels / authoredPixels`) |
| All evidence (`AuthoredEvidenceRaster`, placed extents, clipped roles, filtered output), footprints, CFI/source data | Authored |
| Filter DAG caches and scratch (`_filterRasterPixels`), and every image reachable under a filter (`authoredImagePaths`, followed through references, including CSS background images of those nodes) | Authored (decoded at intrinsic size) |

Pictures are recorded in authored coordinates; the scale changes only decode
targets and the planned size of deferred `saveLayer` allocations. Layout uses the
inspected intrinsic dimensions (`FixedImageRequest.width/height`), not the decoded
`ui.Image` size. `SourceGeometry` and CFIs are identical at any scale. Known
limitation: because filter caches stay authored, a filtered region on a small
authored page shown at DPR above 1 renders at 1x authored resolution and may look
softer than its surroundings (revisit with the S4c zoom generation).

**Alpha-image evidence path.** Every raster is first decoded at intrinsic size
(`acquire`; its size must equal the inspected size or the scene refuses
`resourceExhausted`) and its opacity is proved from the decoded samples with
`isOpaque`. When the display target equals intrinsic, that one decode serves both.
Otherwise: **opaque** -> the intrinsic decode is released and the display decode
(`acquireTarget`) serves display and evidence, since evidence alpha then depends
only on geometry; **alpha** -> the intrinsic decode stays leased as the evidence
raster (`SvgGraphicsImages.evidenceRasters`, `forEvidence`) only while authored
evidence is produced, then is disposed before picture/evidence reconciliation;
the display decode is the retained lease. Both are
charged in `decodedImageBytes` (display + intrinsic whenever the target is smaller).
Cache capacity refusal before codec allocation throws `ImageAdmissionException`
(`ReaderPreparationFailureKind.imageAdmission`); an undecodable raster fails
`FixedPreparationFailure(RenderSectionCapability ... 'image-decode')`. Regression:
a one-pixel alpha hole that the 1x1 display decode hides must remain in the
evidence. Design row "Alpha-image evidence decode (2026-10-30)" supersedes the
older `min(intrinsic, authored)` decision: only the intrinsic decode proves full
opacity and preserves fine alpha. `ReaderImageCache` charges intrinsic codec
scratch plus output before codec allocation; scratch is additional to unit output
credit. Over-capacity evidence refuses typed. No intrinsic-only lease survives
alongside the display decode for the scene lifetime.

**`ImageLease.release({discard})` is single-shot per lease**: a second call is a
no-op. `discard` is sticky on the entry and removes it only when its **final** lease
returns, in either release order; a plain release by another holder never evicts a
discarded entry early and a discarding release never disposes an image another
lease still holds. A cache hit whose `ImageReservation` credit is rejected throws
before the live entry is touched. `FixedImageLease.dispose()` is likewise
single-shot and releases with `discard: true`.

### Retained evidence reconciliation

`FixedPreparationPlan.retainedEvidenceBytes` identifies the evidence share of
the prepaid `vectorBytes` upper bound. The shared lease holds that full bound
through allocation and failure/cancellation. After evidence images are released,
`RetainedEvidence.measure` counts footprint identities and mask coverage across
the merged scene, SVG scenes, and `FixedScene.retainedHostGeometries`: the original
foreignObject host geometry remains live through its dispose callback even after
export creates placed footprints. Shared sample buffers are conservatively counted
per footprint object. One unit placement prepays a 128-byte wrapper per paint
footprint and mask application. A uniform foreignObject therefore needs at least
384 bytes (original + exported + unit-placement owners).

Reconciliation releases only positive excess over this measured charge and runs
once as the last fallible step before publication. Disposal returns the remaining
lease once. `geometryForUnit` rejects a repeated call before placement allocates
any wrappers, including when that repeated call supplies invalid arguments.
Inline fragments and XHTML images are included in the planning evidence envelope.
Reflow reconciliation and device RSS/peaks remain separate work.

### D9 sample classification (harness)

`classifySvgSamples` marks a D4 sample `gradient` (tolerance of one straight-RGBA
channel step, `d9GradientSampleMaximumDelta`) only from source and published
paint evidence, never from pixel values. `paints` must be every published
`GeometryPaint` of the sampled scene; callers pass `scene.geometry.paint`
(`fixed_layout_svg_harness.dart` twice, `fixed_layout_svg_text_harness.dart`,
`fixed_layout_svg_foreign_object_harness.dart`). Paints are visited topmost
first: descending `paintOrdinal`, then stroke above fill above combined. For each
pixel centre the helper reads the paint's clip evidence, `alphaFootprint.alphaAt`
and mask coverage:

- zero effective alpha or a clipped/masked-out centre reveals the next paint, so
  the **topmost paint with nonzero alpha** owns the sample;
- unknown clip, null footprint/`alphaAt`, singular placement or unknown mask
  coverage -> exact (`solid`);
- the topmost covering paint must map to exactly one SVG graphics element and
  not be text, foreignObject (no unique SVG role) or an `image`; otherwise exact;
- a **filter** on that element, its instance chain or any source ancestor (raw
  `filter` attribute or the oracle's computed `filter`, either one) -> exact: the
  output alpha proves coverage, not that the filter preserved the input's paint
  server. Source attributes fail closed even when computed filter evidence is
  absent;
- otherwise the paint's published `role` selects the only paint server that may
  exempt the sample: `fill` or `stroke` as published; a `combined` record resolves
  a role only when exactly one of fill/stroke is visible, and is otherwise (both
  visible, or unknown visibility/width) ambiguous -> exact. No
  centreline or colour inference selects a role, so dash gaps, caps and joins
  cannot be misattributed;
- `gradient` also requires the native paint of that role and the oracle's computed
  paint for the same source element to both be gradient paint servers.

Missing `paints` therefore classifies exactly (strict); the exemption is never
broadened to compensate for missing evidence.

**SVG graphics gate.** The production graphics row passes only when the report
`pass`, `fixedPass`, every case `pass`, the fixed path's `pass` and `parityPass`,
and, for each required case, module geometry, module pixels, fixed geometry,
`fixedPass`/`pixelPass` and fixed pixels all pass. Parity (module and fixed paths
agree) is necessary but never sufficient: identical failure is not fidelity.
`_expectGraphicsGate` in `test/tool/reader/fixed_layout_svg_test.dart` falsifies
each channel independently.

## 4. Validation & Error Matrix

| Condition | Outcome |
| --- | --- |
| `filter/clip-path/mask: none` wins the cascade | Value `none` selected; earlier effect disabled |
| Weaker `none` reset | Stronger effect declaration still wins |
| Ineligible/alternate/external stylesheet | Skipped, not read |
| Eligible local stylesheet missing / cycle / depth > 4 | `SvgFeatureRefusal` (`svg-text-css-resource` / `-cycle` / `-depth`) |
| Unsupported SVG with an inline style lacking `@import` | Refusal before any raw section read |
| Constrained auto axis | Recomputed from ratio; never left at the unconstrained value |
| `use`/`symbol` target under `objectBoundingBox` | Bounds from instance leaves, not an empty box |
| Alpha reserve rejected | Throws before any retained grid or native readback is kept |
| Singular footprint placement | `alphaAt == null`; consumer must fail closed |
| Evidence raster, tile pair or extent exceeds the layer cap | `SceneAdmissionException` before any native image exists; ledgers stay at zero |
| Cancellation / late failure during evidence | Every created image disposed and lease released exactly once; no partial scene |
| Tile stream incomplete, overlapping, unordered or out of range | `ArgumentError` from `fromTiles` |
| Mixed fill+stroke shape | Two `GeometryPaint`s (`fill`, `stroke`) with separate native footprints; `paint-order` other than normal -> `UnsupportedSectionCapability` |
| Clipped paint | Native per-role clipped replay; never a point-in-path footprint |
| Clip/mask prepare placement differs from inspection | Use the admitted preparation `evidenceExtent`, including origin; exhausted raster admission refuses before allocation |
| Pattern image not among the admitted images (clip replay) | `missing-admitted-svg-image` refusal |
| Filtered element, output captured | Source paints removed; one `image`/`combined` paint from the filter output; covered |
| Filtered element with missing graph, bounds, capture or an uncaptured ancestor clip/mask | `markIncomplete`; scene refused (`incomplete-geometry`) |
| Filter region over 4096 px a side or 2x the viewport area | `SvgFeatureRefusal` `svg-filter-region` |
| Raster decode capacity refused | `ImageAdmissionException` (`imageAdmission`), before codec allocation |
| Raster cannot decode | `FixedPreparationFailure` (`RenderSectionCapability`, `image-decode`) |
| Alpha raster with a smaller display target | Intrinsic evidence and codec scratch admitted before allocation; evidence lease released immediately after evidence production, before reconciliation |
| Second `ImageLease.release` / `FixedImageLease.dispose` | No-op |
| D9 evidence missing, ambiguous or under a filter | Sample classified solid and must match exactly |
| Graphics row with any failed channel but passing parity | Gate fails |

## 5. Good/Base/Bad Cases

Good: a 1476x849 opaque image page retains one 128-byte uniform footprint whose
placed `alphaAt` equals a native control at every pixel. Base: a rotated
antialiased rect retains a trimmed one-pixel-sample grid with the exact native
alpha. Bad: collapsing an antialiased grid to a uniform box, indexing a
hard-coded row stride, letting a filter's input footprint prove visibility, or
classifying gradient samples without `paints`. Good: a fractionally clipped rect
retains the native 191 edge sample; a mixed fill+stroke rect publishes two
role-labelled footprints; a filtered flood publishes its output alpha at the
filter region; an opaque image decoded at display size serves display and
evidence, while an alpha image releases its intrinsic-only decode immediately
after authored evidence. Bad: rasterizing evidence per tile or strip, a whole-image RGBA readback
next to the authored raster, rasterizing placed evidence at origin zero, scaling
filter caches or any evidence, one `combined` footprint standing in for both
roles, or a reconstructed `GeometryPaint` without `role:`.

## 6. Tests Required

Keep under `test/features/reader/`: `engine/fixed/svg/svg_presentation_reset_test`
(reset winners/controls, IE-filter alias), `engine/fixed/fixed_svg_text_stylesheet_test`
(linked/quoted/`url()` imports, nested directories, fragments, media, lazy
recovery read spy), `engine/fixed/fixed_svg_viewport_test` and
`fixed_inline_svg_sizing_test` (min/max vectors, both-auto, conflicting limits),
`engine/fixed/svg/svg_feature_clip_mask_test` (direct/nested `use`, symbol,
ancestor transforms, `alphaAt` samples, zero budget after disposal),
`data/geometry/uniform_coverage_test` and `engine/fixed/uniform_coverage_test`
(0/1/32/128/254/255, equality/hash, immutability, translated/rotated/scaled/
skewed placement, mask ids, opacity groups, trimming, reserve-before-allocation,
native pixel equality against independent controls),
`engine/fixed/svg/svg_feature_filters_test` and `svg_feature_hooks_test` (output
footprints equal an independent final-picture readback at every authored pixel
including transparent margins and AA, opacity, nested/repeated graphs, own and
ancestor clip/mask, awaited hook ordering and late source-paint removal,
preallocation refusal, shared peaks, exactly-once cleanup),
`data/geometry/tiled_coverage_test` and `engine/fixed/authored_evidence_raster_test`
(`fromTiles` values/uniform/trim/refusal, rotated-edge tile seams byte-equal to a
whole readback, refusal before native allocation, cancellation),
`engine/fixed/svg/svg_graphics_paint_roles_test` (full-grid per-role controls for
caps/joins/dashes/patterns, prepaid payload, role preservation through clip/mask
and merge, `paint-order` refusal), `svg_graphics_evidence_placement_test` and
`svg_clipped_evidence_placement_test` (integer, fractional and skewed hosts,
reservation equals the native raster, one-pixel-short refusal, created ==
disposed), `svg_feature_clip_mask_test` clipped/bounds cases (fractional,
rotated and cubic clips against an independent native control; rotated-circle
bounds), `engine/fixed/fixed_preparation_scale_test` (geometry/CFI equal at scale
1, .25 and 1.5; plan deltas; alpha hole preserved), and
`engine/surface/fixed_image_reservation_test` (credit, single-shot release,
discard ordering). Under `test/tool/reader/`: `fixed_layout_svg_samples_test`
(real preparer output: text/foreignObject over a gradient, role/dash-gap cases,
filtered output exact, absent or singular footprints fail closed),
`fixed_layout_svg_test` (gate falsification per channel),
`fixed_layout_svg_filters_test`, `fixed_layout_svg_clipmask_test` and the other
harness tests. Reports compare footprints to native pixels through `alphaAt`,
never absolute strides. Run `flutter test <paths>` with `-j 1` when several runs
share the Flutter compiler cache (concurrent runs hit `PathExistsException`).
Host passes do not establish device raster parity (A5).

## 7. Wrong vs Correct

```dart
// Wrong: assumes a row-major byte array of the authored size.
final v = footprint.alpha[y * 100 + x];
final bytes = footprint.alpha.length; // not the retained cost

// Correct: sample by unit-space point; account with storageBytes.
final v = footprint.alphaAt(GeometryPoint(x + .5, y + .5)); // null => unknown
final cost = footprint.storageBytes;
```

Wrong: report a filtered element's input paint as its visible coverage, take
`objectBoundingBox` bounds from a `use` element's source children, or answer a
clipped paint by sampling `Path.contains`. Correct: publish the filter's actual
output alpha (or an explicit gap), walk the expanded instance tree, and replay the
native clipped drawing through `AuthoredEvidenceRaster` over the placed extent.

```dart
// Wrong: per-tile re-rendering changes native AA; a whole readback doubles the peak.
for (final tile in tiles) { await picture.toImage(tile.w, tile.h); }
final all = await whole.toByteData(format: ui.ImageByteFormat.rawStraightRgba);

// Correct: one whole authored raster, exact tile copies streamed into fromTiles.
final footprint = await AuthoredEvidenceRaster.rasterize(
  picture, width: w, height: h, budget: ledger, reserve: reservePayload);
```
