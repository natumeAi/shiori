# A0 review preparation

Date: 2026-10-27. Status: checklist only; no implementation review or quality
gate has run. This document was prepared from the approved task artifacts,
check.jsonl contexts and existing baseline contracts. It does not assess the
implementer's work in progress. Main owns spec/plan/task-state changes.

## Authority and completion boundary

- PRD A-R2/A-R4/A-R6/A-R7/A-R8 and A-AC2/A-AC5/A-AC6 govern the A0 seams.
- `implement.md` makes A0 an evidence gate before broad scene implementation:
  every required capability row needs an oracle case and a failure criterion;
  source/layer/font admission needs concrete provisional limits; diagnostic
  timelines must expose omissions and stalls.
- `research/rendering-plan.md` sections 3, 6 and 7 define the exact required
  profile and initial geometry gate. `design.md` separates A0 limit selection,
  A3 enforcement and A5 device validation.
- A0 is not the complete renderer, integration, or device gate. Reports must
  distinguish completed infrastructure, measured native feasibility, failing
  required constructs and work still needed. A descriptive matrix or a positive
  package API inspection is not measured feasibility.
- A required construct that cannot meet fidelity/resource requirements returns
  to main with the exact failure and options. It cannot be relabeled supported
  partial output, removed from the matrix, or deferred as proven.
- S4a remains open through A5. Host tests never establish iPhone performance,
  Swift runtime behavior, device font mapping, RSS, or physical presentation.

## Provenance and deterministic fixtures

- [ ] Record and verify the actual reference revision and dirty state for
  sources used by the new oracle. Keep the reference checkout read-only.
- [ ] Preserve the existing oracle distinction: lan-reader pin
  `a4bda23fd3e82e285a22566d88576e67d3e8756b`, Foliate pin
  `78914aef4466eb960965702401634c2cb348e9b1`, exact npm lockfile and browser
  engine/build versions. Existing `check-reference` validates four vendored
  files; that success alone does not validate additional fixed-layout helpers.
- [ ] New source snapshots have byte hashes and explicit provenance. Do not
  assign the Foliate MIT license to owner-authorized lan-reader source with no
  declared repository license.
- [ ] Record Flutter/Dart/framework/engine identity from the actual environment.
  Main reports the implementer verified the clean reference pin and Flutter
  3.47.7 / Dart 3.13.5, framework `abaf9c5…`, engine `deb2874…`; this checklist
  does not independently certify that verification.
- [ ] Pin authored viewport, device scale, font bytes/faces, local resource
  hashes, fixture identity and oracle extraction version. Wait for actual font
  and image readiness before collecting browser geometry.
- [ ] WebKit remains authoritative; Chromium is an explicit cross-check.
  Windows browser evidence is not iPhone Safari evidence.
- [ ] Generation is reproducible across repeated runs and timezones. Manifest
  bytes/hashes match the emitted synthetic EPUBs. No private inputs, timestamps,
  local absolute paths, random Blob identifiers or full Chromium vectors enter
  committed artifacts.
- [ ] Browser requests stay inside the existing loopback/blob/data boundary.
  Tests use no NAS or live server and do not modify reference sources.

## Required capability coverage must execute

For **each row** below, require generated source, a reachable painted/laid-out
case, positive/boundary/nested/unsupported-value variants, extracted reference
observations and an explicit failing assertion. Inspect source and extraction,
not just fixture names, comments, declared feature lists or expected booleans.
Where an A0 case is only a reference baseline for A1/A2, label native coverage
pending. High-risk native spikes need their own measured results.

| Row | Minimum cases and independent observations |
| --- | --- |
| Metadata | Package/item overrides for layout, orientation, spread and side; raw/effective values and exact section/spine identity. |
| Dimensions | Valid/invalid/conflicting XHTML dimensions, SVG nonzero viewBox origin/aspect handling and absolute dimensions, verified raster wrapper; no guessed fallback size. |
| Cascade | Inline/linked/imported rules, inheritance/important, selectors and orientation/viewport predicates; unknown required declarations cannot yield completeness. |
| Boxes | Required display/position modes, auto/length/percentage insets, sizing/min/max, margin/padding and box-sizing; nested text and invalid/cyclic/nonfinite geometry. |
| Text | Same packaged SFNT face/weight/style; spacing, wrapping, whitespace, alignment, baseline/sub/super and decoration; exact original UTF-16 ranges and measured line/baseline geometry. |
| Paint | Background images with repeat/position/size, colors, borders/radii, opacity and visibility; hidden/transparent descendants affect geometry eligibility. |
| Stacking/transforms | Nested stacking contexts and all required 2D transforms/origins; actual paint order and inverse mapping; singular transforms cannot fabricate proof. |
| Clips/compositing | Rectangular/path clips, overflow modes, group opacity, alpha/luminance masks; clipping/masking changes visible output and retained source evidence. |
| SVG graphics | Shapes, paths, defs/symbol/use, gradients/patterns/markers, local images and nested viewports; reference cycles/depth/operations and paint order. |
| SVG text | text/tspan positions/deltas/rotation/anchor and packaged fonts; explicit textPath/textLength/lengthAdjust cases with glyph/source geometry. |
| foreignObject | Static XHTML with correct namespace, dimensions, transforms/clips and the same admitted box/text profile; SVG ancestry keeps canonical-v1 exclusion. |
| Filters | Gaussian blur, offset, color matrix, flood, composite, blend and merge, including filter units/regions and dependency order; visibly applied outputs, not unused defs. |
| Mixed navigation | Reflow/fixed/reflow, pairs/center/blanks, TOC fragments/nonlinear targets; exact source conservation and separate active-side identity. |

Specific false-positive traps to test:

- A filter primitive merely appearing in XML does not exercise it: its result
  must feed the displayed graph. A mask/clip/gradient must be referenced and
  visibly affect a nonempty target. A font declaration must actually shape text.
- Source text conservation must read projected nodes and UTF-16 endpoints;
  replaying a hand-written expected string or checking only element counts is
  not independent proof. SVG canonical exclusion must remain unchanged.
- Source/paint order must be independently distinguishable. A text overlay
  above all SVG shapes cannot pass a layered/occluded-text case.
- Missing small objects, line-wrap changes, missing resources and substituted
  fonts fail even when a whole-page pixel-difference percentage is small.
- Initial deterministic tolerance is <=0.5 authored CSS px for the specified
  boxes/transforms/clips/fixture-font baselines. Confirm same-font baselines;
  antialiasing differences do not excuse semantic or geometry failure.
- A recorded `ui.Picture`, dependency success, or enumerated partial marker
  cannot establish complete source-aware rendering. Required unknown
  mask/occlusion coverage keeps the gate open.

## Font and allocation policy evidence

- [ ] Propose finite source-graph bytes/count/depth, paragraph, vector operation
  and offscreen-layer area/bytes limits grounded in the host fixtures. State
  what each bound measures and what remains outside it.
- [ ] Preserve shared 128 MiB encoded reservation accounting and initial
  16 MiB picture / 48 MiB decoded-image budgets. Three presented units plus one
  reserve can contain eight source pages; count all constituents.
- [ ] Specify admission before decode/layer allocation and transient old/new
  overlap. Current oversize image leasing is not a hard peak bound.
- [ ] Font policy deduplicates bytes and face descriptors across books, reserves
  aggregate process bytes/count before registration, and retains accounting
  after book disposal. Include concurrent admission and failed-load behavior.
- [ ] Test real packaged-font loading/shaping and distinguish supported SFNT
  from separately probed WOFF/WOFF2. A magic-number check or Ahem host output is
  not format support/device-fidelity evidence.
- [ ] Typed process-font-exhausted preserves accepted state. Closing/retrying
  does not unload fonts; user-initiated restart may be needed. No automatic
  restart or silent required-font substitution.
- [ ] Clearly distinguish A0 policy/spike evidence from A3 enforcement tests
  and A5 device measurements. Unbounded classes cannot wait until A5.

## Diagnostic event and submission review

- [ ] Trace actual receipt, gesture recognition, recognized admission, queue
  entry/promotion, preparation start/end/hit/miss and first visual submission
  through production code. Pointer-down ownership is not drag recognition.
- [ ] Exercise held pointer before threshold, vertical/no-turn rejection, tap,
  warm/cold drag, queued held drag, reversal, release, rebound, cancellation and
  reduced-motion/static fallback without altering navigation acceptance.
- [ ] Warm latency uses the approved admission boundary and only eligible warm,
  unqueued inputs. Receipt-to-recognition and queue/preparation delays remain
  separately observable. Missing recognition/admission cannot default to zero
  or an earlier legacy event and fabricate a pass.
- [ ] Dirty drag updates, requested frames, intentional holds and preparation/
  barrier waits have explicit times and owner/epoch/generation identities.
  Demand that never receives a submission remains measurable through stop.
- [ ] Post-frame submission is tied to an actual visual mutation in that
  frame, with current engine frame ID. Same-value ticks, stale owners and
  invalidated callbacks cannot count as movement; final/zero-offset mutations
  must have deliberate semantics rather than disappear accidentally.
- [ ] Captured input identity survives release/generation changes. Join by
  (captureEpoch, inputId), never inputId alone or generation alone. Preserve
  mounted/owner/generation/epoch guards and duplicate suppression.
- [ ] No parsing, layout, decoding, font registration, storage or serialization
  is introduced in pointer/ticker paths. Guard tests exercise real entry points.

## Independent analyzer and loss accounting

- [ ] Add deterministic timelines for admission delay, held idle time, dirty
  drag delay, preparation/barrier delay, demanded missing/late frame and an
  open demand at capture stop. Include negative/absent IDs and epoch changes.
- [ ] A hold only explains the interval actually recorded as held. It cannot
  excuse a pending dirty update, scheduled animation, overdue demand or long
  execution stage. Missing events/loss make absence claims unavailable.
- [ ] Analyzer computes from raw events independently of app reducers; raw
  fixtures originate in production record serialization. Update ordinary
  structural export parity and explicit negative measurement fixtures.
- [ ] Preserve engine versus reader percentile conventions, >=50 ms stall
  threshold, 8.333 ms separate UI/raster budgets and two nominal interval P95
  warm gate. Keep historical RSS failures and the existing 5% observational
  rule unless a prospective change is explicitly reviewed.
- [ ] Native long captures expose retained capacity, evictions, contention and
  unmatched callbacks. Overflow already includes contention: do not add it
  twice. Required device runs need zero loss, not just a larger buffer.
- [ ] Audit synchronization at start/stop/reset/snapshot, shared callback and
  late callback generation boundaries. Native callback loss must remain
  countable without unsafe races or blocking the hot path.
- [ ] OSAtomic retention/replacement has an explicit installed-SDK decision;
  host Dart tests cannot establish Swift compilation, ABI, swizzle or runtime
  thread-safety. Carry those checks to hosted CI/device evidence.
- [ ] Preserve product FlutterMetalLayer and A1/A2/B evidence distinctions.
  Native clocks never become Dart clocks by assumption. No layer/drawable
  sample claims physical scan-out or touch-to-photon proof.
- [ ] Legacy captures remain readable but cannot pass new capabilities they
  do not contain. Malformed current capability evidence is rejected or
  explicitly unavailable, never manufactured from aggregate defaults.
- [ ] Analyzer exit 0/aggregate parity does not mean measurement acceptance;
  read gate rows, omissions and loss counters explicitly.

## Baseline artifact gaps to reconcile at handoff

These are existing boundaries, not findings against the ongoing implementation:

1. `diagnostics.md` currently defines warm latency from input receipt, while the
   approved A0 plan requires recognized admission. Main must synchronize the
   spec with the reviewed implementation and retain truthful legacy semantics.
2. Existing analyzer stall classes cannot prove dirty demand or deliberate
   holds; `reader_engine_analysis.dart` explicitly leaves those gaps unresolved.
   Changing labels without capturing production events would not repair it.
3. `FontRegistry` has per-instance alias/path records despite process-lifetime
   native registrations. Its comments must not be mistaken for global digest/
   face admission. This known A3 enforcement gap needs the A0 concrete policy.
4. Current SVG support intentionally surfaces partial text/foreignObject/filter
   behavior. Existing reflow partial/fallback semantics cannot satisfy the
   stricter required fixed-layout completeness gate.
5. Broad testing guidance says golden/integration tests are not generally
   required yet; this task explicitly requires generated fixed-scene fidelity
   and conservation evidence. The task-specific requirement controls.

## Formal handoff verification (not run during preparation)

After main explicitly hands over completed A0 changes, review the actual diff
and execution paths, self-fix authorized issues, then run appropriate checks:

```powershell
dart run build_runner build
dart format --set-exit-if-changed lib test tool/reader tool/diag tool/ci
flutter analyze
flutter test
dart run tool/ci/check_reader_fixtures.dart
```

Include added directories in formatting/analysis. Run the relevant deterministic
oracle generation/provenance checks, analyzer/export parity and negative cases,
and existing build-mode/product-isolation checks if those paths change. No
private input is uploaded or committed. Inspect generated artifacts for parity
and missing coverage, not only process exit codes. Report lint/type-check/tests
as not run until actually executed, and list A0 pending evidence separately from
A5 device-unverified status.
