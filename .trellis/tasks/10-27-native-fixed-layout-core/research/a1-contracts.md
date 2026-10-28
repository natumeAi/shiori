# A1 shared contracts and parallel ownership

Date: 2026-10-28. Scope: the immutable shared subset before concurrent owners
start. A0 is closed per `a0-closure-report.md`, Closure verdict; SVG fidelity
remains required and open for A0b. These contracts do not establish A1/A2/A3
acceptance and no existing reader behavior is changed.

## Layer and representation

Paths below are relative to `lib/features/reader/` unless otherwise stated.
`data/layout/` holds detached source/composition/navigation values and ports;
`data/geometry/` holds detached geometry and dependency-free affine arithmetic.
Neither directory imports the engine, Flutter, providers or `dart:ui`; workers
and S4b can use the same values. Renderer verdicts live in
`engine/support/section_capability.dart` to reuse the existing engine-owned
`UnsupportedLayoutReason` without introducing a data-to-engine dependency.
That file itself needs no `dart:ui`. Future Paragraph/Path/Picture adapters and
leases belong under `engine/`, outside these detached values.

All values use final fields, runtime validation (not assertions), value equality
and matching hashes. Lists are defensive unmodifiable copies; ordered stacks
and ordered source fragments participate in equality. No codegen/dependency
addition or existing barrel edit is needed. Enums have normal Dart equality.

## Types, invariants and extension owners

| File | Types / invariants | Sole extension owner |
| --- | --- | --- |
| `data/layout/source_page_id.dart` | `SourcePageId`: full existing ContentIdentity, nonnegative filtered section and original spine indices, nonempty stable document id. Stable across recomposition. | A1-rest |
| `data/layout/authored_page_size.dart` | `AuthoredPageSize`: positive finite CSS-pixel width/height. Sealed `DimensionResolution`: `ResolvedDimensions` requires size, `DimensionSource` (viewportMeta/svgViewBox/svgSize/rasterIntrinsic) and reason; `MalformedDimensions`/`UnsupportedDimensions` have reasons and no size. | A1-rest |
| `data/geometry/affine_transform.dart` | `AffineTransform`: finite [a c e; b d f; 0 0 1], column vectors. `compose(inner)` applies inner first. Sealed `TransformInversion`: `InvertedTransform` or `NonInvertibleTransform` with singular/numericRange `InversionFailure`; no silent failure or epsilon-based singularity guess. | A1-rest |
| `data/layout/source_page_slot.dart` | Sealed `SourcePageSlot`: fieldless `BlankSourcePageSlot` has no section/CFI/source/coverage. `RealSourcePageSlot.fixed` requires authoredSize; `.reflow` has no authored size and is centered. Both retain page and sourceToUnit. Existing `PublicationLayoutMode` reused; `SpreadSide` is left/right/center. | A1-rest |
| `data/layout/reading_unit.dart` | `ReadingUnitId` scopes a nonempty composition key by ContentIdentity; `ReadingUnitKind` distinguishes reflowPage/fixedSingle/fixedSpread. `ReadingUnit` requires 1-2 ordered slots, real constituents with the same content, no repeated source, homogeneous mode, and activeSource matching a real slot. Singles have exactly one real slot. Spreads have exactly two slots, left then right; padding may occupy either slot. `realSourceCount` excludes blanks. | A1-rest |
| `data/layout/reading_unit_navigator.dart` | `ReadingUnitNavigator` is an interface only: async adjacent previous/next (`UnitDirection`), SourcePageId plus existing SourcePosition, and package-resolved TOC href including fragment. Sealed `UnitNavigationResult`: `LocatedReadingUnit`, `ReadingUnitBoundary` (start/end `UnitBoundary`), `UnavailableReadingUnit` with nonempty reason. Candidates never imply proof. | A1-rest |
| `engine/support/section_capability.dart` | Sealed `SectionCapability`: Complete/Malformed/Unsupported/Resource/RenderSectionCapability, nonnegative section and nonempty reason. Failures require ordered `OffendingConstruct` values (kind, nonempty identifier, optional nonnegative node). `CapabilityConstructKind` identifies constructs. Complete has none. Unsupported rejects fixedMetadata-only evidence and existing fixedLayout refusal reason; other existing UnsupportedLayoutReason values can be retained. | A2 |
| `data/geometry/cluster_geometry.dart` | `Utf16Range`: nonempty half-open source UTF-16 range, never canonical offsets. `GeometryPoint`: finite coordinates. `ClusterGeometry`: range, four ordered local quad corners, baseline start/end, finite clockwise-radian rotation, `ClusterGranularity` and `ClusterProvenance`. Paragraph provenance cannot assert shaping-cluster membership. | A2 |
| `data/geometry/source_fragment.dart` | `SourceElementAnchor`: nonnegative node and optional nonempty element id. `SourceFragmentKind`: xhtmlText/svgText/element; svgText includes SVG foreignObject descendants. `SourceFragment`: page/node, exact ordered cluster partition of textRange, matching granularity, optional same-node element anchor, sourceToUnit, nonempty outer-to-inner clip/mask ids, nonnegative paintOrdinal and finite opacity in [0,1]. Elements require an anchor and no text range/clusters. | A2 |
| `data/geometry/source_geometry.dart` | `SourceGeometry`: positive version, copied source-order fragments and required `GeometryCompleteness`. `CompleteGeometry` is an explicit producer attestation; `IncompleteGeometry` requires copied nonempty `GeometryIssue` values (`GeometryGapKind`, reason). Fixture-declared clusters cannot publish complete geometry. | A2 |

Author dimensions are resolved only for fixed content. Reflow's null authoredSize
does not stand for unknown fixed size: its named constructor selects reflow mode,
and the unit constructor checks that mode. Reflow layout dimensions remain in
the existing pagination output. SVG viewBox origins/aspect transforms stay in
the transform; they are not inferred from width/height. A1-rest implements
dimension resolution from existing PublicationLayoutFacts/SectionLayoutFacts/
SvgSourceDimensions; this change adds no parser/resolver implementation.

Unit ids identify a composition within its existing LayoutIdentity scope;
the producer includes the reflow page/composition in the key. Selecting the
opposite real side keeps the spread id while changing activeSource. A3 will
carry LayoutIdentity plus activation/reader generations in the prepared envelope;
the unit id alone is not a stale-result token. SourcePageId's full content
identity already includes the existing server-scoped BookKey and versions.

Geometry is candidate evidence. XHTML uses graphemes from the painted Paragraph;
SVG, including foreignObject, uses shaped clusters. Fixture-declared membership
is provisional, distinct from Paragraph and shaped provenance. Fragment
sourceToUnit includes nested transforms plus page placement: do not multiply
the slot transform again. S4c composes unit-to-viewport above this matrix.
Paint ordinals are separate from source order. Clip/mask ids alone prove no
visibility: A2 must extend its geometry export with actual clip/mask/occluder
registries and mark missing/unknown evidence incomplete before integration.
S4b combines evidence with accepted source, settled view, foreground and dwell;
canonical v1 SVG/MathML exclusions and CFI proof are unchanged.

## Parallel file ownership

These are subsequent-phase assignments, not edits authorized by this delivery.
Tests belong to the owner of the corresponding production file. No concurrent
owner edits another owner's file; requests go to that owner for integration.

| Owner | Exclusive files / responsibility |
| --- | --- |
| A1-rest | `data/layout/**`, affine_transform.dart and their tests; new dimension resolver; `data/epub/epub_package.dart`, `data/worker/publication_layout_facts.dart`, `publication_import_facts.dart`; `engine/support/layout_flags.dart`, `unsupported_layout.dart`; new `engine/pagination/reading_unit_composer.dart`, `reading_unit_navigator.dart` implementations. Own metadata, dimensions, centered/blank/spread composition, nonlinear/TOC/mixed navigation. |
| A2 | New `engine/fixed/**`; `data/geometry/**` except affine_transform.dart; section_capability.dart; `engine/style/**`; `engine/layout/block_builder.dart`, `inline_accumulator.dart`, `paragraph_factory.dart`, `paragraph_map.dart`, `layout_model.dart`, `svg_support.dart`, `svg_picture.dart`, `image_sizing.dart`; `engine/pagination/section_preparer.dart`, `prepared_section.dart`, `page_plan.dart`, `anchor.dart`, `conservation.dart`. Own authored scene, CSS profile, geometry export and fidelity. |
| A3 | `engine/surface/**`, `engine/motion/**`; `engine/layout/scene_resource_budget.dart`, `process_font_budget.dart`, `font_registry.dart`, `font_mapping.dart`, `image_cache.dart`; `data/resources/**`; `data/worker/**` except the two A1-rest fact files above; `data/source/source_parser.dart`, `html_adapter.dart`, `content_protection.dart`, `xml_parser.dart`, `dom_serializer.dart`; new bounded WOFF/WOFF2 conversion/admission files. Own session/pool/leases, worker reservations, process-font integration, parser hardening and warm/prepare coalescing. |
| A0b | New HarfBuzz probe and companion files under repository `tool/reader/` only, plus its specifically assigned probe tests; no production ownership. The host probe remains separate from A2 adoption. |

## Shared seams: exactly one writer each

| Seam | Sole owner | Consumers / handoff |
| --- | --- | --- |
| `engine/surface/prepared_reader_session.dart` | A3 | A1 provides navigator, A2 provides scenes; A3 adapts existing TurnSession and proof flow. |
| `engine/surface/page_surface_pool.dart` | A3 | A2 supplies scene paint/geometry input; A3 owns leases and constituent accounting. |
| `engine/style/css_properties.dart` (and computed_style/cascade) | A2 | A1 sends metadata/size needs; A3 sends font-admission needs. |
| `engine/pagination/section_preparer.dart`, `prepared_section.dart` | A2 | A3 requests resource/font/lease hooks through A2; no competing preparer. |
| `engine/layout/font_registry.dart` | A3 | A2 consumes admitted bytes/face identities; A0b only probes them. |
| `data/worker/publication_worker_protocol.dart`, `publication_worker_runtime.dart`, queue/preload/resources/import | A3 | A1 supplies layout-fact changes through its owned fact files; A3 wires worker requests/replies. |
| `data/worker/publication_layout_facts.dart`, `publication_import_facts.dart` | A1-rest | A3 reads facts; A1 does not edit the worker runtime. |
| `engine/motion/turn_session.dart`, `engine/surface/prepared_page_position.dart` | A3 | Preserve existing TurnPosition/TurnSession and exactly-once acceptance; no parallel replacement. |
| Future prepared-unit/resource-accounting envelope under `engine/surface/` | A3 | Reuse ReadingUnit, SourceGeometry, existing LayoutIdentity and leases; define actual ownership/accounting API before consumer integration. |
| `engine/support/section_capability.dart` | A2 | A1 emits dimension/layout evidence; A3 emits resource/render failures; A2 integrates verdicts. |
| `data/geometry/affine_transform.dart` | A1-rest | A2/S4b request changes through A1-rest; no native Matrix replacement in data. |

PreparedReadingUnit and ResourceAccounting were design names, not existing
APIs. They are deliberately not implemented as empty successful wrappers here.
A3 owns the real resource-bearing envelope. Reuse SceneResourceBudget.reserveUnit
with ReadingUnit.realSourceCount: four units / eight real source pages, blanks
uncharged. This delivery neither allocates resources nor enforces product caps.
SectionLayoutSupport's current S2 detection remains unchanged; the new verdict
does not silently reinterpret or replace its legacy fixed-layout refusal.

## Integration order

1. Review this shared-contract document before assigning disjoint owners.
2. A1-rest implements facts/dimensions/composition/navigation. A3 implements
   resource/session logic in parallel. A0b runs its approved probe. A2 starts
   rows permitted by A0; curved/positioned SVG and foreignObject inline text
   wait for A0b's accepted result, with required failed rows remaining open.
3. A1-rest publishes navigator and composition vectors; A2 publishes typed
   scenes, actual clip/mask/occluder evidence and completeness; A3 publishes
   the actual prepared-unit/lease/accounting seam. Each owner changes only its
   files, including requested seam changes from other owners.
4. A3 integrates navigator/scenes into session/pool using existing motion and
   proof, full identities/generations and per-real-source reservations. A2
   integrates any requested preparation hooks in its own files.
5. A4 integrates and runs the phase-defined host gates after A1-A3 delivery;
   then A5 obtains actual device evidence. S4b consumes geometry with its own
   accepted-observation/visibility proof; none of these contract tests activates
   S4b or claims fidelity/resource/device acceptance.

## Validation record

Only the 16 new Dart files are formatted/analyzed; only the five new test files
run. Their 24 tests cover blanks, counts, mixing, identity, list immutability,
singular/numeric inversion, dimensions, navigation values, geometry partitions,
granularity/provenance, paint evidence, completeness and capability variants.
SDK commands use the direct dart.exe and flutter_tools.snapshot; no .bat,
codegen, full suite, commit or tool/fixture/native changes. Final exit statuses
are recorded in the handoff reply.

## A2 seam for A3

Published by A2 slice 2b, 2026-10-28. Entry point:
`engine/fixed/fixed_section_preparer.dart`. The reflow SectionPreparer and
PreparedSection constructors are unchanged. This is a real retained scene seam;
it does not attest that every required fidelity row or the whole task passes.

Lifecycle and ownership:

1. Acquire an independent `FixedSourceLease` containing the exact SourcePageId,
   immutable document, fixed CssStyledDocument, resolved SectionRendition,
   ReaderResourceSource, retainedSourceBytes, and nonthrowing releaseSource.
   The callback retains/releases A3's file/worker/source pins. An image request
   supplies inspected output width/height and an acquire(capturedToken) callback.
   That callback must physically drain decode before returning/throwing; a late
   returned FixedImageLease is disposed by A2 on cancellation. No I/O is added.
2. `FixedSectionPreparer.plan(source)` borrows these handles; it performs no font
   registration, Paragraph/Path/Picture/image allocation or encoded-resource read.
   `FixedPreparationPlan` exposes A1's DimensionResolution, typed input capability,
   per-class SceneResource requests, source/reference/layer depths, pictureBytes
   and decodedImageBytes. A complete input capability is not a prepared result.
   Bad metadata/dimensions remain typed; no size is guessed. Unsupported SVG
   attributes/children and unimplemented baseline shifts cannot publish complete.
3. A3 reserves the entire unit once with SceneResourceBudget.reserveUnit and its
   existing picture/image owners BEFORE prepare, summing real constituents and
   preserving old/new overlap. Pass each constituent a `FixedSceneAdmission` with
   that exact plan, a live sufficiently charged sceneLease, reserved picture and
   decoded bytes, reconcilePictureBytes(actual), and releaseReservations().
   This callback releases A3's constituent reference; the last reference releases
   the aggregate lease. A2 never releases a shared unit lease independently.
   Failed ticket construction leaves ownership with A3; release it there.
4. `prepare(plan, admission, cancellation: capturedToken)` consumes both source
   and ticket once. It returns FixedPreparationOperation: result, cancel(),
   drained. Cancellation rejects result promptly. Await drained before recycling
   the owner: pending decode/coverage/native font work and partial destruction
   must finish. Reservations and source handles stay charged during that time.
   The local builder budget is a prepaid suballocation ledger, not another unit
   or shared process reservation. Failed capabilities, incomplete geometry and
   picture reconciliation refusal destroy partial work and never publish a scene.
5. A successful PreparedFixedScene retains plan/source, scene.picture, native
   Paragraphs, SourceGeometry with explicit completeness, image/resource leases
   and the same admission owner. dispose() is idempotent; it destroys paint and
   images before releasing source and aggregate reservation references. A3 still
   guards full activation/layout/reader generations immediately before publish.
   Plan/prepare/composition/disposal guard against motion callback execution.

Composition: scene.picture and geometry are authored-page local. During A3's
unit preparation, draw the picture under the slot sourceToUnit matrix once and
call prepared.geometryForUnit(theSameMatrix, registryPrefix: uniqueSourceKey,
paintOrdinalOffset: unitPaintBase). The returned fragments, regions and clip/
opacity registries are already placed and namespaced; never apply the slot again
in S4b/S4c. GeometryAlphaFootprint now carries a grid-to-unit transform; placement
shares its immutable alpha buffer without resampling/copying. Visibility must
inverse-map through this matrix as well as respect its one-CSS-pixel resolution.
Noninvertible placement is refused. SVG viewBox origin and meet/slice/none are
resolved in the authored scene through FixedSvgViewport using A1's dimensions.
The current production SVG primitive route supports validated viewports/rects;
general SVG text/filter/mask/foreignObject adoption still awaits its own seam.

Conservative policy and limits: initial pictureBytes is a 2 MiB per-source
recording ceiling (the existing 16 MiB picture owner divided by eight real source
owners), not an inferred native byte cost per command. Actual approximateBytesUsed
must fit and reconcile before publish. All eight real constituents can reserve
this ceiling together; a source exceeding it returns resource refusal and needs
policy review, without successful partial content or raising the 16 MiB owner.
It does not claim an opaque native recording allocator/RSS peak bound. The plan
includes source/text/node counts, paragraph upper bounds, geometry/alpha payload,
vector operation/reference bounds, and simultaneous layer/coverage buffers.
Decoded output bytes come from inspected image requests; A3's acquire callback
must additionally reserve intrinsic/transient decode allocations before decode.

Exact font requests to A3 (no edits to font_mapping.dart/font_registry.dart):

- Fixed preparation calls FontRegistry.loadResources(resources,
  plan.source.styles.fontFaces, scope: source.page.content.sha256,
  requiredFonts: true, cancellation: capturedToken). RequiredFontException,
  ProcessFontLoadCanceled and resource admission failures propagate; no partial
  success/fallback scene is published. StyleFontFace supplies family,
  archivePath, integer weight and StyleFontStyle.normal/italic in source order.
  Unsupported weight ranges/angles/values now emit CSS diagnostics.
- Implement `ResolvedFontFamilies Function(ParagraphFontRequest) selectFace` in
  A3's mapping/registry and inject it into FixedSectionPreparer. Request fields:
  immutable ordered `List<String> families`, `int weight`, `StyleFontStyle style`.
  ParagraphFonts sends the computed base and every painted run descriptors and
  keys its cache by all three. Select among the admitted StyleFontFace descriptors
  and retain per-face aliases; FontLoadRecord/registry keys must distinguish
  weight/style even for the same CSS family and archivePath. Never take the final
  family alias. Until supplied, multiple faces of one fixed family return typed
  descriptor-selection-required, with zero font loads.
- Supply `Future<void> Function() drainFonts`, a physical barrier for all started
  or coalesced registrations consumed by this preparer. Existing canceled registry
  waiter futures cannot provide this barrier. A2 keeps source/reservations until
  it completes, even when result already reports cancellation. Process-lifetime
  registrations retain A3's process charges after scene destruction.

Host verdicts for this slice: metadata capability/identity passes, with no paint
gate. Dimensions geometry is 0 px; malformed/unsupported variants are typed,
nested D4 passes, positive D4 fails at the isolated reference (0,0) alpha-38 pixel.
The RD-1 registry does not include dimensions, so no exemption was added. Text
positive/nested fail (11.8212890625 px maximum, D4 fails); sub/super baseline
shifting remains explicitly unsupported and incomplete, not successful partial
content. text-boundary retains painted/source-mapped fallback and A5-only
geometry/pixels. The unchanged 0.5 px/D4 gates and required rows remain open.
