# Execution: S4b

Status: planning, 2026-10-27; revised 2026-10-28 for owner decisions D5/D6
and the S4a post-A0 contract (`../10-27-native-fixed-layout-core/research/
a0-measurement-review.md`). Explicit dependencies: S3 storage/network/content
contracts for every phase. S4a's accepted geometry/session/early-device
handoff is also required for the geometry-dependent phases marked below. No
real write or implementation starts without the owner's explicit instruction.

D5 track (parallel with S4a): B0 wire-DTO fixtures, B2 and B3. They use fake
transports and temporary SQLite files only. They must not touch S4a-owned
reader engine/surface/diagnostic files.

Geometry track (after S4a handoff): B0 geometry/visibility vectors, B1, B4, B5.

## Phase order and gates

| Phase | Work / ownership | Gate |
| --- | --- | --- |
| B0: contracts and oracles | D5 track: exact wire DTO fixtures. Geometry track: freeze S4a's immutable geometry/view/identity contract, then extend CFI/canonical/visibility vectors. XHTML text visibility uses per-grapheme layout boxes from the painted Paragraph. SVG text, including foreignObject, is per shaping cluster and canonical-zero. | Source/UTF-16/canonical/blank/SVG-zero behavior and all required overlap/mask cases have expected results. D6 edge cases put a character within 1 px of a fractional clip edge and record any snapping-only difference. No live requests. |
| B1: proof and activity model | Single accepted observation owner, transformed source proof, eligible visible intervals, fake-clock foreground ledger, completion and chapter mapping. | Stale/canceled/preview/layout/zoom cases cannot save or overcredit; pure-image and DST vectors pass. |
| B2: durability | Adjacent v3 schema, typed worker commands, atomic checkpoint+pending position and immutable outbox/results/suspensions. | Real SQLite temp-file migration/restart/interruption/future-version and storage-failure tests preserve data and retry identity. |
| B3: typed delivery | Reading GET/PUT, activity POST, exact DTOs, per-book single flight, local-priority/uncertain reconciliation, bounded batching/partial outcomes. | Fake transport proves writes only after proof and durable enqueue; duplicates/timeout/413/400/5xx/signature conflict/late ack are correct. |
| B4: session integration | Connect S4a reader lease/worker/session, S3 content changes and S4b proof/store/delivery. | Replacement, old content, 404, route departure, A->B->A and concurrent prep cause no stale publication or cross-server leak. Full host review passes. |
| B5: interoperability evidence | Controlled minimal harness on dedicated disposable books; web->native->web, backward/local-priority conflict, retries and totals. | B-AC1-B-AC8 and explicit evidence ledger. S4c consumes the ports; this is not complete UI/performance acceptance. |

## Required context

Manifests inject bounded general specs and research. Before B0/B1 load the
authoritative reader-engine.md and relevant parent native-reader-contracts.md.
Before B2/B3 load data-layer.md and error-handling.md; before B4 load state-
management.md and archived S3 research/s4-handoff.md. All Flutter specs are
under .trellis/spec/flutter/. Large-file omission from injection is not a
waiver to skip them.

## Validation and test inventory

- CFI text/image/range-start, spread-side, TOC/chapter -1, mixed boundaries,
  transformed/covered/clipped/transparent text and exact canonical signatures.
- Paired occlusion fixtures document the approved reference-overcount
  exception and separate fix handoff. D6 fixtures document edge characters
  that differ only through reference integer snapping: the native box lies
  within 1 px of a clip edge, and the reference rule on unsnapped geometry
  reproduces native. All other cross-client differences remain failures. No
  reference deployment prerequisite or history rewrite.
- Time/idle/drift, DST/midnight, background/pan/viewer eligibility and pure-
  image completion; injected clocks, no device-local assumption in unit tests.
- Database v1->v2->v3/v2->v3, reopen, future-schema preservation, transaction
  abort and death between enqueue/send/response/acknowledgment.
- Offline local-priority vs changed web progress, backward reading, older
  in-flight response with newer pending intent, already-acked cache no-op.
- Activity exact bytes across duplicates/partial success/malformed outcomes,
  signature suspension and batch splitting; cache purge cannot delete events.
- Prefix URLs, route/method inventory, redacted errors, rejected redirects,
  retired-session uncertain writes and A->B->A isolation.

After final code changes:

```powershell
dart run build_runner build
dart format --set-exit-if-changed lib test tool/reader tool/diag tool/ci
flutter analyze
flutter test
```

Extend format/analysis to new tool/integration directories; rerun the existing
source/canonical/oracle suites relevant to changed contracts. Ordinary tests
never contact the NAS. After B4 semantic gates, obtain required operational
authorization for disposable-data device/NAS validation; never use personal
reading history as an experimentation surface.

## Dispatch and rollback

One scoped trellis-implement owner per phase, then trellis-check; main session
owns plan/spec updates and reviewed commits. Native injection plus required
child-side reads; no recursive implement/check dispatch. Final check covers
all B phases and affected core/library/reader layers.

Risky seams: source proof/visibility, SQLite typed protocol and migrations,
GET-only transport generalization, exact immutable bytes, acknowledgment
revision logic. Preserve old rows and raw outcomes when reverting code.
Do not reset/downgrade the database or rewrite mismatched events.

## Activation / handoff checklist

- [ ] Subsequent user approval after the latest plan summary (covers the D5
      track; the geometry track also needs the next item).
- [ ] S4a handoff accepted; any changed geometry contract reflected here.
      Already reflected: cluster-granular SVG text and the D6 edge exception.
- [ ] Valid real context manifests and all required specs loadable.
- [ ] B4 tests pass before any live position/activity operation.
- [ ] Publish DTO/storage versions, proof/visibility ports, rejected/suspended
      outcome handling and disposable cross-client evidence for S4c/S5.
