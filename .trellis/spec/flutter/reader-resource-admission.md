# Provisional scene and process-font admission (S4a A0)

## 1. Scope / Trigger

`engine/layout/scene_resource_budget.dart` and `process_font_budget.dart` provide
tested standalone policy owners. Production FontRegistry, preparation and surface
integration remain A3 work. Do not describe these modules as an already enforced
product memory limit. Existing encoded/picture/image owners remain authoritative.

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
with fallback. Do not admit those formats from callback completion alone or
generalize that host result into an iPhone verdict.

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
A3 adds real allocation/owner integration tests; A5 measures device peaks/churn.

## 7. Wrong vs Correct

Wrong: treat a completed FontLoader Future as proof of correct font use or
reinitialize the budget when changing books. Correct: retain process-lifetime
admission and verify the actual shaped output separately. Policy admission and
native usability are distinct gates.
