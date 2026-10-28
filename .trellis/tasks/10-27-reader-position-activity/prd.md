# S4b: verified reader position and activity

## Goal

Preserve interoperable location, eligible reading time, canonical coverage
and completion across admitted layouts, restart and network failure.
Durable local state survives retries, content replacement and server
switching. Status: planning, 2026-10-27.

## Background and Dependencies

Parent: `../10-22-flutter-lan-reader-parity`; owns parent R5/R6/R8 and source/
activity portions of AC5/AC6/AC8/AC11/AC12. Depends on S4a's accepted source
geometry, transforms, scene identity and session handoff, plus S3's namespace,
content identity and single SQLite v2 owner. S4a's early device gate precedes
geometry-dependent work (B0 geometry/visibility vectors, B1, B4, B5). Under owner
decision D5 (2026-10-28), B0 wire-DTO fixtures, B2 durability and B3 typed
delivery depend only on S3 and may run in parallel with S4a. Each still starts
only on the owner's explicit instruction and makes no live writes. S4c consumes
this work.

Evidence: `research/position-activity-contracts.md`. Current transport is
GET-only; the existing backend provides last-write-wins position and
deduplicated activity APIs, not CAS. Canonical v1 excludes SVG subtrees;
image pixels never become character coverage.

## Accepted Product Decision

On 2026-10-27 the user chose **local priority** when pending offline local
reading conflicts with changed server/web progress. A persisted accepted
local checkpoint may overwrite newer remote progress after server/book/
content and source-proof validation. No conflict-choice prompt is required.
An already acknowledged cache, preview or unresolvable CFI cannot create
pending write intent. No stronger simultaneous-writer guarantee is claimed.

Also on 2026-10-27, the user chose native actual-visible coverage over the
reference's known occlusion overcounting. Only demonstrated occluded-text
interval/count differences are an accepted cross-client exception, recorded
with a separate reference-fix handoff. Canonical v1, time, completion,
idempotency and other intervals/totals remain exact; existing history is not
rewritten and the reference fix is not an S4 dependency.

On 2026-10-28 (D6) the user added a second narrow exception. The reference
classifies visibility on WebKit's integer-snapped client rectangles with a 1 px
tolerance, while native uses unsnapped geometry. A character may differ between
the two only when its native box lies within 1 px of a clip edge, and applying
the reference rule to unsnapped geometry must reproduce the native result. Each
such difference is recorded with the paired fixture. Every other difference
remains a failure.

## Requirements

| ID | Requirement |
| --- | --- |
| B-R1 | One accepted-source owner consumes settled scene/view proofs; navigation, restore, reflow, zoom and lifecycle use one eligibility identity. Candidates, previews, cancellations and stale results never persist or count. |
| B-R2 | Resolve web/native CFI for text/images, spread sides and mixed boundaries. Failed restore/content changes preserve prior state; explicit chapter-start recovery is a separate accepted user action. |
| B-R3 | Derive canonical v1 intervals from actual eligible visible text through transforms, clipping and occlusion. Preserve exact normalization/signatures and SVG exclusions; previews, blanks, offscreen/covered text and background gaps do not count. |
| B-R4 | Match reference idle/checkpoint/drift, local-hour/date/DST splitting and completion triggers. Pure-image content may accrue time and eligible completion with zero text coverage; reaching the last page alone is insufficient. |
| B-R5 | Add adjacent migrations through the existing SQLite worker for accepted checkpoints, coalesced position intent, immutable activity/outcomes and suspension state. Preserve existing/future-schema bytes; eviction cannot touch reader state. |
| B-R6 | Extend typed routes for exact position/activity contracts. Serialize position writes per server/book, acknowledge only submitted snapshots, reconcile uncertain responses and apply local priority. No hidden mutation retry or cross-origin redirect. |
| B-R7 | Persist exact activity payload/identity before sending; retry unchanged, interpret every batch result, retain partial/permanent/signature-conflict outcomes and isolate endpoint/book/content. Never rewrite events onto replacement content. |
| B-R8 | Expose typed persistence/restore/delivery/refresh seams for S4c/S5. No real NAS write before source, canonical, visibility and durability fixture gates pass. |

## Acceptance Criteria

| ID | Requirements | Observable outcome |
| --- | --- | --- |
| B-AC1 | B-R1, B-R2 | Web->native->web vectors for all layouts prove visible source targets. Stale work, interrupted turns, failed restore and blanks preserve accepted checkpoints. |
| B-AC2 | B-R3 | Canonical/signatures and shared interval cases match exactly; zoom/clip/overlap tests credit only eligible text; SVG text has zero v1 characters. Reproduced reference occlusion overcounts have paired expected differences and a separate handoff under the approved exception. Edge characters that differ only through reference integer snapping are recorded under D6. Other missing/overcredited text remains failure. |
| B-AC3 | B-R4 | Fake-clock/time-zone cases cover idle, background, drift, midnight/DST, end/return/reflow and pure-image first-open/navigation completion; restored-end or duplicate observations cannot invent completion. |
| B-AC4 | B-R5 | v1->v2->v3, v2->v3, reopen, interrupted transaction and newer-schema cases preserve data. Death around enqueue/response/acknowledgment retains retryable identity; eviction affects only its namespace. |
| B-AC5 | B-R6 | Changed remote progress is intentionally replaced by latest pending proven local position, including backward movement. Older in-flight acknowledgment cannot clear newer intent; no pending intent means stale local cache cannot overwrite remote state. |
| B-AC6 | B-R7 | Duplicate delivery adds nothing; accepted/duplicate/partial/rejected/signature-conflict outcomes are durable and handled individually. Replacement, 404 and A->B->A switching neither leak delivery nor delete old records. |
| B-AC7 | B-R6-B-R8 | Fake adapter inventory proves methods/envelopes/null pairs/timestamps and bounded responses; GET compatibility remains. Fixture gates precede separately authorized disposable-data cross-client writes. |
| B-AC8 | B-R8 | A standalone contract harness proves restore, accepted-view observation, durable flush and delivery-driven refresh ports independent of snapshot 304. S4c/S5 consume these ports later; their implementation is not a prerequisite for this child. |

## Out of Scope

Renderer implementation, full product/settings UI, statistics dashboard,
backend edits/deployment, position CAS and appearance synchronization.
Local priority does not change canonical semantics or permit unverified saves.

## Technical Gates and Artifact Status

Exact payloads, timing constants, proof identity and migration shape are in
the research/design. No product decision remains open. Design, execution
plan and both manifests are required before start. Activation of the
D5-parallel phases waits for approval of this child's latest plan. All other
phases also wait for S4a's handoff.
