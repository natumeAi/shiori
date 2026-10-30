# A2 SVG feature hooks

Internal contract for filters, clip-path/mask, foreignObject and SVG text. The
shared module owns admission order, reservations, painting and release. Each
feature owns one part file.

## Files

| Feature | Owns | May change |
| --- | --- | --- |
| Filters | `svg_feature_filters.dart` | this file; its tests/harness assigned by the main owner |
| Clip/mask | `svg_feature_clip_mask.dart` | this file; its tests/harness assigned by the main owner |
| foreignObject | `svg_feature_foreign_object.dart` | this file; its tests/harness assigned by the main owner |
| SVG text | `svg_feature_text.dart` | this file; its tests/harness assigned by the main owner |

`svg_feature_hooks.dart` is the contract and registry. The shared
`svg_graphics_plan.dart`, `svg_graphics_tree.dart` and
`svg_graphics_prepare.dart` call the hooks and must not grow feature-specific
branches. `svg_graphics.dart` holds only part lines plus `SvgFeatureHost`.

## Contract

`SvgFeature` exposes:

- `key`; `tags`, `definitionTags`, `attributes`, `presentationProperties`.
- `presentationRefusal(property, value)` returning a typed identifier, and
  `presentationIgnored(property, value)` for no-op values.
- `opaqueChildren` for feature-owned whole subtrees.
- `admit(SvgFeatureAdmission)` once per owning source node, before resource
  charges. Use `charge`/`chargeLayers` to add to `plan.resources` before
  allocation, `resolveReference`/`addReference` for references, and `refuse` for
  the section's typed refusal.
- `Future<void> prepare(SvgFeaturePreparation)` after the base ledger
  reservation and tree construction, before any paint. Use shaping/layout here,
  `reserve` for exact additional leases, `setPicture`/`addPicture` for native
  pictures, and `onDispose` for feature-owned non-picture resources. Every node
  instance the feature owns must call `markCovered(node)` or
  `markIncomplete(node, kind, reason)` in `prepare` or `geometry`.
- `geometry(SvgFeatureGeometryContext)` after paint ordinals exist and before
  scene assembly. Add `SourceFragment`/`GeometryPaint`/`GeometryClip`/
  `GeometryOpacityGroup`, use `addClipTo`/`addMaskTo` to attach evidence to the
  module's existing node fragments/paint, or call
  `geometry.incomplete(kind, reason)`. The same `markCovered`/`markIncomplete`
  methods are available here.
- `paint(SvgFeaturePaint)` wraps one node's default paint. The default paints
  the leaf and then children; module opacity wrapping stays inside it. Features
  are applied outermost-first in `SvgFeatureRegistry.defaults` order. Use
  `canvas.saveLayer`/clip/mask around `paintDefault()` for filter regions,
  clipping, masking or group opacity. `paintDefault()` must be called exactly
  once per wrapper; skip/repeat is a typed `svg-feature-paint-default` refusal.
  Alternatively, `captureDefault() -> ui.Picture` records the next wrapper and
  default into a picture in root coordinates, consuming the single default
  call. Repeated capture calls return that same picture without rerunning the
  source; replay it with `canvas.drawPicture(...)` any number of times. Capture
  itself draws nothing on the wrapper's canvas. Mixing capture and direct
  `paintDefault()` refuses. The picture is borrowed: never dispose it yourself.
  Scene ownership releases it exactly once on success, failure or cancellation,
  and includes its bytes in the existing recorded-picture limit. Capture needs
  the scene lifecycle; excluded pattern/marker builders cannot capture.

Per-node state is `SvgFeaturePreparation.state`/`SvgFeatureGeometryContext.state`
keyed by the feature instance; never store plan state on the shared const
feature object.

## Call order

1. `SvgGraphicsPlan.inspect`: tag ownership, tag admission, attribute ownership,
   attribute/presentation admission, then shared source/reference charges.
   Feature-owned content inside `pattern`/`marker` is refused explicitly
   (`svg-feature-in-pattern`/`svg-feature-in-marker`); those builders do not run
   the feature lifecycle yet.
2. `SvgGraphicsPreparation.prepare` (after base reservation and `_tree`):
   the base plan debits the local ledger even when the caller already reserved it
   globally, feature `prepare` in registry order, `prepareNode`
   ordinals/geometry/paint records, feature `geometry` in registry order, then
   completion validation (missing completion becomes `IncompleteGeometry`),
   feature `paint` wrappers with exactly-once `paintDefault` validation, then
   scene ownership transfer.
3. `SvgGraphicsScene.dispose`: picture, pictures, leases, feature owners. Exactly
   once on success; failure and cancellation release pictures, leases and owners
   before returning/throwing.

## Host

`SvgFeatureHost` has two host-only services:

- `foreignObject`: `SvgForeignObjectLayoutService.available` and
  `layout(SvgForeignObjectRequest)` returning an owned picture, bounds,
  fragments and clips for the same admitted XHTML box/text/style profile.
- `text`: `SvgTextFontService.available` and `acquire(SvgTextFontRequest)`
  returning a `SvgTextFontLease` with admitted face bytes, byte count and
  `release()`. The host owns physical registration drain; the module only calls
  `release()` once through scene disposal.

`SvgFeatureHost.unavailable()` is the production default until A3 supplies a
real host. `FixedSectionPreparer.svgFeatureHost` is the injection point;
`fixed_preparation_plan.dart`/`fixed_scene_svg.dart` pass it through.

## Later owners

- Filters: build the bounded primitive graph (blur, offset, color matrix, flood,
  composite, blend, merge), filter units/regions, layers and geometry evidence;
  keep `svg-<feTag>`/`svg-filter` refusals until each case is supported.
- Clip/mask: resolve `clipPath`/`mask` units and content, add clip/mask registry
  evidence and paint wrappers; keep `svg-clipPath`/`svg-mask`/
  `svg-attribute-*`/`svg-css-*` refusals until supported.
- foreignObject: use the host layout service, keep `opaqueChildren`, audit the
  host's fragments/source identity and canonical v1 exclusion; keep
  `svg-foreignObject` until supported.
- Text: acquire the font lease in `prepare`, shape/place through HarfBuzz,
  publish text fragments/paint evidence with module paint ordinals, and keep
  `svg-text`/`svg-tspan`/`svg-textPath` until supported. `textPath`,
  `textLength` and `lengthAdjust` remain explicit high-risk cases.

No owner may change shared admission order, reservation ownership, paint order,
or silence a refusal without a typed capability change. Fixtures, oracle,
generators, gates, specs and pubspec stay untouched.

## Contract change 2026-10-29

Feature owners must call `markCovered(node)` for every owned node instance once
its picture/evidence is complete, or `markIncomplete(node, kind, reason)` when
it is not. A missing call now yields `IncompleteGeometry`; it is no longer
implicitly complete. `paintDefault()` must be called exactly once per paint
wrapper, otherwise preparation returns the typed `svg-feature-paint-default`
refusal. Feature-owned content inside `pattern` or `marker` is not yet routed
through the feature lifecycle and is refused with
`svg-feature-in-pattern`/`svg-feature-in-marker`.

### Source capture and layer ownership (A2-filters-2, 2026-10-29)

`captureDefault()` is the additive, once-only alternative described above;
existing feature wrappers can continue using `paintDefault()` unchanged. Inner
wrappers/children run once into the capture, even when a filter reads
SourceGraphic or SourceAlpha repeatedly. Cancellation is checked after painting
before scene transfer; unfinished capture/output recorders are released on
failure.

`chargeLayers` contributes to the base `reservation()`. Do not reserve those
same layers again in `prepare`; `reserve` is for additional, unplanned resources.
The admission audit follows references and charges repeated source instances,
so filter uses already share one budget with the base lease. `preReserved`
still debits only the local capacity not already occupied by the fixed scene,
but a layer request larger than the entire local limit refuses before tree or
picture allocation. The caller retains ownership of its pre-existing lease;
scene disposal only releases leases acquired by that scene.
