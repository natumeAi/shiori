# S4 implementation plan

Date: 2026-10-27; revised 2026-10-28. Status: reviewed plan approved for
implementation; S4a is in progress. A0 was delivered on 2026-10-27, but its gate has not
passed. After the A0 measurement review
(`../10-27-native-fixed-layout-core/research/a0-measurement-review.md`) the
owner decided D1-D6 and all S4 plans were revised; no phase has started under
the revision. S1/S2/S3 are archived. S3 acceptance covers preparation, not
full reader performance. The parent remains the requirements/integration
owner; S4b/S4c retain their dependency gates.

## Outcome and accepted scope

Deliver a pure Dart/Flutter product reader for horizontal LTR reflowable,
single-image fixed, complex static fixed and mixed EPUBs. Preserve authored
fixed geometry, content/source identity, source-based resume and accurate
time/coverage/completion. Add reference reader controls/settings/TOC/image
viewer, approved whole-page fit/pinch/pan and the unchanged 120 Hz target.

New decision on 2026-10-27: pending verified local progress wins a conflict
with server/web progress and may overwrite it. This does not authorize an
unproven candidate, wrong content/server identity or old acknowledged cache
to create a write. No server-progress conflict-choice prompt is planned.

Second decision on 2026-10-27: native counts actual-visible text. Reproduced
reference occlusion overcounts are a narrow interval/character-total parity
exception, recorded with a separate reference fix handoff that does not block
S4. Canonical v1, time, completion and idempotency remain unchanged; existing
NAS history is not rewritten.

Post-A0 decisions (D1-D4 on 2026-10-27, D5-D6 on 2026-10-28):

- D1: prove cluster-granular curved/positioned SVG text through a time-boxed
  HarfBuzz FFI probe (A0b).
- D2: curved textPath with ligatures and length adjustment stays required.
- D3: reproducible WebKit raster defects become narrow recorded exceptions.
- D4: cross-engine pixel edges follow a conservative edge rule.
- D5: S4b's B2/B3 and wire-DTO fixtures may run in parallel with S4a.
- D6: edge characters that differ only through reference integer snapping
  become a second narrow coverage exception.
- D7 (2026-10-28): D4's component check counts only pixels with alpha >= 32,
  so faint antialiasing bridges between rasterizers do not decide it.
- D8 (2026-10-28): for text, the component check is replaced by "each glyph
  cluster painted exactly once" plus 0.5 px positions. Text edge pixels are
  compared again on the iPhone in A5.

The 0.5 authored CSS px tolerance, the 120 Hz target and every required row
are unchanged.

## Deliverables and explicit ordering

| Child | Execution phases | Independent deliverable / next-stage gate |
| --- | --- | --- |
| [S4a: native fixed/mixed core](../10-27-native-fixed-layout-core/implement.md) | A0 oracle/complex-feature/font/measurement spikes (closure items open); A0b HarfBuzz text-geometry probe; A1 metadata/reading units; A2 authored scene; A3 resources/session; A4 host/probe integration and capture sizing; A5 early iPhone gate. | Complete required static capability corpus, source geometry, bounded session ownership and measured early feasibility. Depends on completed S2/S3. A1/A3 need only A0 closure; A2 curved/positioned SVG text waits for A0b. Required failure stops dependent activation for review. |
| [S4b: position/activity](../10-27-reader-position-activity/implement.md) | B0 exact source/wire oracles; B1 proof/visibility/time/completion; B2 SQLite durability; B3 typed delivery; B4 session integration; B5 controlled cross-client evidence. | Verified checkpoints and immutable activity delivery, local-priority reconciliation and reusable typed ports. B0 wire-DTO fixtures, B2 and B3 depend only on S3 and may run in parallel with S4a (D5). B0 geometry vectors, B1, B4 and B5 depend on S4a's geometry/session/early device gate. No live writes before semantic/durability gates. |
| [S4c: product reader](../10-27-product-reader-acceptance/implement.md) | C0 integration baseline; C1 route/active intent; C2 controls/settings; C3 image/view/lifecycle; C4 release hardening; C5 final iPhone gate. | UI02 reader behavior + UI09-UI14, whole-page interaction, final seven-condition ledger and S5 handoff. Depends on accepted S4a/S4b. S7 still owns whole-app acceptance. |

Planning/fixtures can be researched in parallel. Implementation runs in the
order above, except for the D5 track, which may overlap S4a. Every phase start
needs an explicit owner instruction. Exception: on 2026-10-28 the owner told S4a
to proceed from A0 closure through A4 automatically; A5 and S4b/S4c starts still
need the owner. Parent-child links are not dependency
enforcement. Dependencies
are repeated in every child PRD/execution plan. Each child has PRD, design,
implementation plan, persisted research and real implement/check manifests.

## Architecture decisions

- Keep the existing source/CFI/canonical and reflow/motion core. Add an authored
  coordinate scene path and common reading units for fixed pages/spreads.
  Reuse the guarded single-image optimization only when lossless.
- Exact required XHTML/SVG properties, values, masks/filters/foreignObject,
  metadata and tolerances are in S4a research. Native primitives are a
  feasibility starting point, not proof of complete browser equivalence.
- The 0.5 px gate compares same-definition quantities per channel, as defined
  in the S4a design. SVG text geometry is per shaping cluster. Public
  `dart:ui` cannot place clusters along curves, so A0b probes HarfBuzz via
  FFI. If adopted, S4c ships it pinned with its licence notice. WOFF/WOFF2 are
  converted to SFNT before font admission.
- Source geometry is independent from paint caches: original node/UTF-16
  ranges, source-page identities, transforms, clips and occlusion evidence.
  One accepted-source owner drives position and eligible activity.
- S4a owns independent file/worker/session leases, preloading and resource
  admission. Account for both spread pages, transient decode/layers and
  process-lifetime fonts; surface counts alone do not bound RSS.
- S4b adds adjacent SQLite migrations and narrowly typed reading writes.
  Local priority applies only to durable pending proven reading intent.
  Immutable activity retries and per-event outcomes remain separate from
  coalesced last-write-wins position writes.
- Canonical v1 remains unchanged: SVG descendants do not gain characters.
  Pure-image content may have reading time and reference-eligible completion
  without fabricated text. Overlap/mask visibility has its own source oracle.
- S4c composes the owners, preserves exact reference settings and keeps
  fixed typography authored. Enlarged drag pans; fit restores ordinary page
  turning. Gesture previews never save progress or count as text/completion.

## All seven S2 conditions remain owned

| Condition | Early implementation / evidence | Final closure |
| --- | --- | --- |
| 1. Recognized admission / warm latency | A0 instrumentation; A5 actual admitted-input to first-submission evidence, separate queue/cold waits. | C5 warm P95 <=16.7 ms before release. |
| 2. Dirty-drag / demand / stalls | A0 actual submission, hold/barrier/demand capture and analyzer cases; A5 candidates retained. | C5 no unexplained >=50 ms stall. |
| 3. RSS growth / native sample loss | A0 provisional limits and loss accounting (its 16384-event Dart ring still overflows within 100 turns); A3 enforcement; A4 capture sizing with a zero-loss synthetic >=100-turn run; A5 peak/trend and >=100-turn evidence, reviewed RSS rule with historical failures preserved. | C5 integrated product trend/caps and zero sample loss in required long native runs. |
| 4. Real OS recovery | A5 probe lifecycle; B1/B4 eligibility/durable correctness; C3 product integration. | C5 motion/cold-preparation interruption, real return and completed proven turn. |
| 5. Mixed layouts | A1-A4 per-section rendering/geometry; B source/coverage; C UI/recovery. | All 23 private sections/six fixed pages and generated complex corpus; no image-only scope reduction. |
| 6. Existing hardening | S3 bounded import complete; A owns preload peak, process-font admission, parser gaps, warm/prepare coalescing and synchronization review. | C4 fixture-free packaged app; C5 integrated evidence for every retained subitem. |
| 7. Product layer | A0 preserves FlutterMetalLayer; alternate CAMetal path stays diagnostic only. | C4/C5 build/runtime inventory; no non-product trace used as physical presentation proof. |

## Acceptance and evidence

1. Exact content/source/order/CFI/canonical conservation plus the per-channel
   fixed geometry contract, D4 pixel rule and explicit font tolerances; no
   missing authored elements, false acceptance, stale callback publication or
   successful partial rendering. Only recorded D3 reference defects are exempt.
2. Web->native->web resume, local-priority offline conflict, backward reading,
   crash-safe checkpoints/outbox, duplicate/partial delivery, date/hour/DST,
   signature mismatch and pure-image completion fixtures.
3. Paired iPhone UI02/UI09-UI14 evidence, fit/pinch/pan/viewer arbitration,
   real background/return, content change and same-identifier update retention.
4. At least three repeats per required nominal-120-Hz scenario: >=99% UI
   and raster stages separately within 8.333 ms, warm admitted submission
   P95 <=16.7 ms, no unexplained >=50 ms stall, >=100 alternating turns and
   bounded resources. Correctness, engine costs, cadence and physical
   presentation have independent verdicts; missing evidence stays unverified.

Host gates use codegen, formatting, analysis, meaningful unit/widget/SQLite/
oracle/analyzer checks and build/privacy inventories. Device gates reuse
the existing free Windows + hosted macOS + iPhone workflow and fixed app ID.
Private books/NAS details/raw captures stay ignored; tracked reports contain
synthetic references and anonymous results. No build/push/NAS call occurs
in planning.

## Risks, deferred work and review boundary

Highest risks are native SVG text/filter/mask equivalence, process-lifetime
font growth, transformed/occluded source proof, aggregate spread/decoder
memory and obtaining honest device evidence. A0 probed these before broad
implementation. Filters, masks and SFNT shaping were feasible for the tested
inputs; cluster-granular curved text remains the main open risk (A0b). A5
checks the real device before full product UI. Missing required features
trigger review, never automatic narrowing or a WebView.

Full shell/home/statistics and library/upload/drag/undo remain S5/S6; final
whole-app acceptance is S7. Vertical/RTL, active scripts, CAS/backend changes,
paid distribution and a comprehensive offline manager are not added.

No blocking product decision remains; D1-D6 are recorded above. The owner
approved starting this previously presented plan on 2026-10-27 and S4a was
activated. Implementation
uses gpt-6.1-sol high; independent checking uses gpt-6-astra high. S4b/S4c
require their dependencies and latest child-plan review; changed contracts
require refreshed artifacts. Activation does not establish native fidelity
or performance passes; phase evidence is recorded in the child task.
