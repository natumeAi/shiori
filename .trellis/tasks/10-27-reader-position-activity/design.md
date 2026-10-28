# Design: one proof and durable delivery pipeline

Status: proposed, 2026-10-27. Exact wire fields, source anchors, time constants
and completion cases live in research/position-activity-contracts.md.
S4a supplies scenes/lifetimes; this child owns reading meaning and durable
records; S4c supplies user interaction and foreground state.

## Accepted observation and visibility

Pipeline: prepared candidate -> source/visible proof -> AcceptedObservation
-> durable checkpoint/position intent and eligible activity ledger ->
immutable outbox -> serialized delivery. Preview labels have no authority.

An observation carries activation, BookKey, ContentIdentity, reader/layout/
view generation, unit/composition, active real source, proven CFI and local
accepted revision. Reasons distinguish opened, navigation, layout-restored,
snapshot and stable visibility refresh. Zoom/pan refresh is not navigation
completion. Reuse existing turn proof; do not create a second save callback.

Compose source-to-unit and unit-to-viewport transforms, clips, masks,
opacity and occlusion. S4a exports candidate clusters/source ranges and
completeness; S4c supplies stable view/foreground/panel/viewer state. Persist
one proven active anchor; observe independently proven intervals from both
visible real spread pages. Blank slots contribute nothing.

After 300 ms eligible stable idle, map fully proven visible canonical
characters to disjoint half-open intervals. Preserve source UTF-16 versus
canonical code-point coordinates and exact v1 signature. SVG/MathML,
including foreignObject descendants under SVG, remain canonically excluded.
Reference sampling does not prove arbitrary occlusion: retain a separate
geometry oracle and expose differences; do not claim equal totals for cases
where the reference overcredits covered text. The user approved this narrow
exception on 2026-10-27: pair actual-visible native and reference results,
record the attributable interval/count difference and hand off the reference
fix without making it an S4 prerequisite. Do not rewrite existing history or
waive canonical/time/completion/deduplication compatibility. Unknown required visibility
keeps the gate open, never silently counts or satisfies required coverage.

Geometry granularity follows the S4a post-A0 contract. XHTML text uses
per-grapheme layout boxes from the same painted Paragraph. SVG text, including
foreignObject descendants, is geometry per shaping cluster and contributes no
canonical characters, so ligature component splitting never changes coverage.
The reference classifies visibility on WebKit's integer-snapped client
rectangles with a 1 px edge tolerance (`reference:client/src/reader/
visibleText.ts`). Native classifies unsnapped geometry with the same
tolerance. Under owner decision D6 (2026-10-28), a character may differ only
when its native box lies within 1 px of a clip edge and the reference rule on
unsnapped geometry reproduces the native verdict. Record each such difference
with its paired fixture; no other difference is exempt.

On stale/ineligible generation cancel sampling immediately. An unchanged
source anchor may be re-proved after reflow; failed restore never becomes a
page-one save. Explicit chapter-start recovery is a distinct accepted action.
Reproof does not itself create new pending delivery from an acknowledged
cache; new accepted reading intent does.

## Time and completion

Inject monotonic clock, wall clock and device-local calendar boundaries.
Use reference 15 s checkpoints, 120 s maximum span and 10 s drift rejection.
Split at actual local hour/midnight boundaries, including DST, and retain
original attribution on retry. Never hardcode the chat timezone.

Image viewer can retain eligible time while blocking text sampling; whole-
page gestures invalidate text samples until settled. Background, detached,
error/recovery and blocking panels exclude time per the reference contract.
Do not depend on an eventual app-termination callback for durability.

Completion is a distinct immutable event: proven nonfinal->final navigation,
or first healthy never-saved single-page open. Reopen at end, layout restore,
snapshot, canceled motion, recovery and view transforms do not invent it.
Pure-image/SVG-zero pages omit coverage sections but may send time and
eligible zero-duration completion; no fake zero-length section is sent.

## Durable storage proposal

Use the one existing SQLite worker/typed command protocol. At current v2,
add v3 transactionally; if another reviewed migration lands first, use the
next adjacent version without rewriting shipped schemas.

| Record | Key and role |
| --- | --- |
| reader_checkpoints | Server/book plus accepted revision, payload, full identity, proof status and retained remote baseline/raw timestamp. |
| pending_positions | Server/book coalesced latest accepted payload/revision/identity; pending, uncertain, held or permanent failure. |
| activity_outbox | Server/event ID, exact serialized payload, book/content identity, sequence and pending/rejected/held outcome. |
| coverage_suspensions | Server/book/section/normalization/signature mismatch state; independent from time and unrelated sections. |

Checkpoint plus pending position commits atomically. Ledger drain is retained
until enqueue succeeds. Storage failure sends nothing and exposes nondurable
state with bounded retained work; a later retry cannot duplicate drained
intervals. Durable event payloads/IDs never change. Outcome application
acknowledges only matching submitted IDs/bytes or position revisions.

Rows must not cascade from evictable cache generations. Cache removal,
404, content change and server switching retain checkpoint/events. Schema
metadata/user_version and DDL migrate atomically; unknown newer schemas
preserve database and sidecars. S4c intent/settings use existing generic
storage only if typed semantics fit, otherwise an adjacent later migration.

## Transport and position policy

Add narrow typed reading GET/PUT and activity POST operations to existing
SessionTransport/ServerRoute, preserving prefix joining, request bounds,
redaction and activation cancellation. No generic arbitrary write route,
hidden mutation retry or redirect replay is introduced.

Position GET/PUT use api/reading/{bookId}, exact progress/cfi/chapterHref/
chapterLabel/chapterCount/chapterIndex fields and {progress: ...} envelopes.
Retain raw server UTC timestamps. Serialize one write per server/book and
coalesce only later accepted local revisions, never max(progress).

The user explicitly selected local priority on 2026-10-27. When durable
pending local reading conflicts with changed remote progress, revalidate
content and CFI and send the latest accepted local payload even if it moves
backward. No conflict prompt/hold solely due to remote changes. With no
pending local intent, an old acknowledged checkpoint cannot overwrite the
server.

After uncertain delivery/restart, GET and reconcile: an exact matching remote
payload acknowledges only the submitted revision; otherwise re-prove and
send latest eligible pending local intent. A late response for N cannot clear
N+1 or update another active UI. Last-write-wins still permits concurrent
writers after preflight; no CAS guarantee is claimed.

## Activity delivery

POST api/reading/activity batches <=50 immutable events within 900000 encoded
bytes. IDs are unique random wire-safe values created once. Split sparse
coverage to preserve <=32 sections and <=256 intervals per section; never
fill hidden gaps to meet a bound. Preserve event local date/hour exactly.

Accepted/duplicate outcomes acknowledge only matching records. Signature
mismatch stores a section-signature suspension while acknowledging accepted
time/completion. Permanent INVALID_ACTIVITY/BOOK_NOT_FOUND/EVENT_ID_CONFLICT
retains a rejected record. Missing/invalid/5xx responses remain pending with
bounded backoff; multi-event 400 is attributed through singles and 413
halves the batch. Never assign a new ID to retry committed data.

Content identity is compared on every open, not only ephemeral change events.
New bytes/parser/canonical version invalidate proofs; unresolved old records
are preserved with original identities. Hold unresolved coverage rather than
rewriting it for new content. This is separate from remote position conflict.

## Integration, rollback and risks

S4a owns worker/session pin/drain; S4b subscribes before preparation, closes
eligible spans and invalidates callbacks before retirement. S4c binds all
navigation/settings/view paths to the same observation owner. Delivery
acknowledgments expose a refresh event for S5 independent of snapshot 304.

Fixture gates precede live writes. Use a minimal controlled harness for B5
so S4b does not wait on S4c's complete UI. Backend/real deployment changes
remain user-owned. Rollback cannot delete outbox/checkpoints or downgrade a
new schema by reset; older apps refuse unknown schema and preserve bytes.
Full offline retention is limited by device storage and existing signing/
reinstall constraints; no new cross-install backup promise is introduced.
