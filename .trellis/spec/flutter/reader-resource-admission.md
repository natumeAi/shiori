# Provisional scene and process-font admission (S4a A0)

## 1. Scope / Trigger

`engine/layout/scene_resource_budget.dart` and `process_font_budget.dart` provide
tested standalone policy owners. Production `FontRegistry` already admits every
face through `ProcessFontBudget.shared` and converts WOFF/WOFF2 to SFNT first
(see [Font Conversion](./reader-font-conversion.md)). Fixed-layout preparation
already reserves through `SceneResourceBudget`: `PageSurfacePool.prepareFixedUnit`
sums each `FixedPreparationPlan.resources`, reserves the unit with
`resourceBudget.reserveUnit` (plus the picture and decoded-image owners) before any
native allocation, and `FixedSceneAdmission` refuses a plan the lease does not
fully cover ([Fixed Layout](./reader-fixed-layout.md)). The plans' terms are safe
upper bounds. Successful fixed preparation reconciles retained evidence with the
shared ledger after evidence production; reflow preparation remains pending.
Do not describe these modules as a measured product memory
limit: the caps are provisional and device peaks are A5. Existing
encoded/picture/image owners remain authoritative.

## 2. Signatures

- `SceneResourceBudget.reserve(request, {sourceDepth, referenceDepth,
  layerDepth}) -> SceneResourceLease` validates the whole request atomically.
- `reserveUnit({sourcePages, resources, sourceDepth, referenceDepth,
  layerDepth})` admits one unit with one or two real constituents.
- `reserveLayer(width, height, {buffers, depth})` charges physical RGBA8 pixels
  and bytes before allocation; multiplication overflow is checked first.
- `SceneResourceLease.release()` is idempotent.
- `ProcessFontBudget.shared.load(bytes, {face, register, cancellation})`
  returns the content-derived engine alias and coalesces native registration.

## 3. Contracts

Scene reservations include pending and retained work, including old/new
replacement overlap. A failed multi-class request changes no counter. Blank
slots have no source identity/charge. One unit policy must correspond to the
existing three-presented-plus-one-reserve surface ownership, not add four more.

Fixed evidence reconciliation holds `FixedPreparationPlan.retainedEvidenceBytes`
inside the unit's `vectorBytes` reservation through allocation, cancellation and
failure. Before publication, `RetainedEvidence.measure` counts each live footprint
identity and mask coverage from merged geometry, retained SVG geometry and the
original foreignObject host geometry (still owned by the host disposal callback).
It also charges one 128-byte placement wrapper per paint footprint and mask
application. Shared sample payload is conservatively charged per footprint object.
`FixedSceneAdmission.reconcileEvidence` releases only positive excess over those
owners via `SceneResourceLease.shrink`; it is single-shot. Disposal releases the
remaining charge exactly once. Repeated unit placement refuses before allocation.

Fixed publication image admission collects CSS background URLs, SVG `image`
`href`/`xlink:href`, and XHTML `img src` through the same dimension inspection
and pool request path, deduplicated by source URL and provenance. Element URLs
resolve strictly against their section document before admission; an archive-key
or CSS-reference spelling match never supplies an unavailable document-relative
resource. CSS URLs retain their declaring stylesheet's resolved archive paths.
When a resolved CSS path equals an element's raw URL, the CSS request uses a
separate internal key through decoding, painting and evidence admission, so both
resources remain independent. Empty, fragment-only, external, data and unavailable sources are not
admitted; a required image without an admitted request refuses preparation,
never publishes missing paint. Image selection uses `src` only; `srcset` and
`picture` selection remain unsupported.

Raster opacity inspection uses an intrinsic decode, as decided in design row
"Alpha-image evidence decode (2026-10-30)". The image cache admits intrinsic codec
scratch plus output before codec allocation, in addition to live decodes and
outstanding unit credits. An opaque intrinsic-only decode is released immediately
after inspection; an alpha intrinsic-only decode is used for authored evidence
then released before picture/evidence reconciliation. Only the display lease
survives publication (or the shared intrinsic/display decode when targets match).
An excessive peak refuses typed; no fine alpha may disappear through downsampling.

Initial aggregate bounds are 4 units / 8 real pages, 32 MiB source payload /
100,000 source nodes, 8,192 paragraphs / 4,194,304 shaping UTF-16 units,
16 MiB vector payload / 100,000 operations, 4,096 references / gradient stops,
and 8,388,608 RGBA8 temporary pixels / 32 MiB. Source/reference/layer depths are
64/32/8. These are provisional logical limits, not measured iPhone-safe RSS.
Use the enum-keyed `used`/`peaks` snapshots for accounting; snapshots are immutable.

The existing process-shared encoded owner keeps its 128 MiB reservation budget;
picture/image defaults remain 16/48 MiB. Do not reset or duplicate those budgets.
Source payload accounting includes owned source/style/geometry strings and
buffers; raw XHTML bytes alone are insufficient. Actual native shaping, filter
scratch, GPU storage and VM overhead still need separate measurement.

Process font admission defaults to 64 MiB input bytes and 32 faces, shared across
books/registries/activations. Deduplicate by SHA-256 plus a caller-normalized face
descriptor, not archive path or CSS alias. Caller-supplied bytes stay immutable
until registration completes. Admission reserves before calling `register`,
including reentrant/concurrent requests. It distinguishes pending, registered
and uncertain counts and retains lifetime peaks.

Cancellation abandons a waiter, not already-started engine registration. A late
success remains permanently charged; there is no unload/reset/close API. Only
`ProcessFontRegistrationRejected` certifies no native retention and releases a
failed reservation. Generic registration errors retain an uncertain charge and
cached failed attempt. A caller cannot close/retry to bypass the process cap.

Successful registration callbacks do not prove usable font-format support.
Validate actual shaping against a known-font result and absent-family control.
A0's Windows SFNT probe succeeds; direct WOFF/WOFF2 callbacks finish but shape
with fallback, so WOFF and WOFF2 never reach `register` directly: they are
converted in Dart ([Font Conversion](./reader-font-conversion.md)) and this
owner digests, deduplicates and charges the **converted SFNT bytes**. Do not
admit any format from callback completion alone or generalize the host result
into an iPhone verdict.

## 4. Validation & Error Matrix

| Condition | Outcome |
| --- | --- |
| Invalid/negative request or dimensions | `ArgumentError`, no charge |
| Aggregate resource cap exceeded | `SceneAdmissionException(resourceExhausted)`, no partial reservation |
| Depth exceeded | `SceneAdmissionException(complexityExceeded)` with depth |
| Process font cap exceeded | `SceneAdmissionException(processFontExhausted)` before registration |
| Cancellation before admission | `ProcessFontLoadCanceled`, no native work |
| Cancellation after admission | Waiter canceled; shared registration stays charged |
| Certified no-retention rejection | Release pending charge; later explicit retry can register |
| Other native failure | Keep uncertain charge and failed attempt |
| Repeated scene release | No second decrement |

Required content never becomes successful partial output after admission fails.
A3 must propagate process exhaustion instead of hiding it in missing-font
fallback, preserve accepted reader state and explain that an explicit app
restart may be needed. Closing the book cannot unload registered fonts; do not
restart automatically or silently substitute a required font.

## 5. Good/Base/Bad Cases

Good: reserve the whole temporary graph, charge old and new scenes until actual
disposal, and share a digest/face load across consumers. Base: A0 policy tests
prove finite accounting without claiming product integration. Bad: per-book font
budgets, releasing canceled native work before it drains, or counting eight raw
source files as proof that eight complete scenes fit memory.

## 6. Tests Required

Keep `scene_resource_budget_test.dart` and `process_font_budget_test.dart`.
Assert inclusive limits for all classes, atomic failure, nesting, 4-unit/8-page
ownership, old/new overlap, overflow refusal, exact-once release, immutable
snapshots, source-projection fixture admission, concurrent font dedup, uncertain
versus certified failure, cancellation, and no font work in motion callbacks.
Fixed preparation has real allocation/owner integration tests
(`fixed_section_preparer_test`, `engine/surface/fixed_image_reservation_test`, the
SVG feature tests asserting a zero ledger after disposal); reflow integration and
A5 device peaks/churn remain.

## 7. Wrong vs Correct

Wrong: treat a completed FontLoader Future as proof of correct font use or
reinitialize the budget when changing books. Correct: retain process-lifetime
admission and verify the actual shaped output separately. Policy admission and
native usability are distinct gates.
