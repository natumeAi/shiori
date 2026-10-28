# Research: verified position and reading activity

- Query: Define S4b's proof, visibility, durability and delivery contracts across reflowable, fixed and mixed books.
- Scope: internal; shiori and `D:/Projects/lan-reader` source read on disk. Reference checkout is read-only.
- Date: 2026-10-27
- Status: planning evidence and proposed design, not implemented or device-verified.

## Findings

### Files found and authority

Reference paths prefixed `reference:` below mean `D:/Projects/lan-reader/`.
The inspected source is available; this audit does not assert its current Git commit or the NAS deployment version.

| File | Contract / relevant anchor |
| --- | --- |
| `lib/core/config/content_identity.dart:11` | BookKey + actual SHA-256 + parser/canonical versions; never an HTTP validator. |
| `lib/features/library/data/publications/prepared_book.dart:9` | Detached source summary and shared preparation lease; reader must acquire its own lease. |
| `lib/features/library/data/publications/prepare_book_queue.dart:9` | Existing serialized worker-operation boundary. |
| `lib/features/library/data/publications/session_publication_worker.dart:13` | One lazy worker per server activation; retirement closes it. |
| `lib/features/reader/engine/motion/turn_session.dart:4` | Current TurnPosition has one section/page; S4a must extend composition identity. |
| `lib/features/reader/engine/motion/turn_controller_work.dart:121` | Target proof precedes one accepted publication; callbacks cannot undo it. |
| `lib/features/reader/engine/surface/prepared_page_position.dart:37` | Source/layout/page identity and visible anchor checks already exist for reflow. |
| `lib/features/reader/engine/pagination/anchor.dart:109` | CFI export/resolve/round-trip and foreground geometry, image fallback. |
| `lib/features/reader/data/canonical/canonical_text.dart:121` | Existing canonical v1; visibility does not change signature or offsets. |
| `lib/core/storage/sqlite_store.dart:31`, `sqlite_store_schema.dart:3` | Current schema v2 and adjacent transactional migrations. |
| `lib/core/network/session_transport.dart:46`, `server_route.dart:4` | Transport and route inventory currently permit S3 GETs only. |
| `lib/features/library/data/models/server_timestamp.dart:5` | Retains raw wire timestamp and UTC instant, including fractional SQLite timestamps. |
| `reference:shared/src/reading.ts:22` | Exact position DTO/update and atomic nullable chapter tuple. |
| `reference:server/src/routes/reading.ts:154`, `:179`, `:194` | Activity POST and position GET/PUT routes. |
| `reference:client/src/utils/chapterProgress.ts:15`, `:29` | TOC CFI boundaries and chapter index, including -1 before first chapter. |
| `reference:client/src/reader/activityTracker.ts:75`, `:177`, `:210`, `:264` | Eligible phases, accepted observations, time/text eligibility and stale-sample checks. |
| `reference:client/src/reader/visibleText.ts:132`, `:201`, `:235` | Actual clip/visibility sampler; zero-text sections omitted. |
| `reference:client/src/utils/readingActivity.ts:33`, `:68`, `:159`, `:234`, `:376` | Clock, local-hour splitting, coverage ledger and completion. |
| `reference:client/src/utils/activityDelivery.ts:7`, `:85`, `:179` | Immutable bytes, bounded single-flight retry and partial outcomes. |
| `reference:server/src/services/readingStats.ts:106`, `:158`, `:250` | Payload identity, first signature/length rule, per-event transaction/idempotency. |

### Dependency and ownership

S4b depends on S4a's admitted fixed/mixed renderer, per-source geometry, spread slots and bounded prepared-surface lifecycle, plus S3's verified file/worker/storage handoff. Planning may proceed now; geometry-dependent implementation/acceptance cannot bypass S4a's gate.

S4b owns the product reader session's accepted-position/event pipeline, source proof, activity semantics and durable delivery ports. S4c binds presentation, settings/TOC/image-viewer and fixed-view gesture signals to those ports. Do not create separate persistence owners for ordinary turns, TOC, slider, restore or zoom.

Proposed data flow: `Prepared source geometry -> candidate navigation/view -> proof -> AcceptedObservation -> local transaction -> position delivery / activity ledger -> immutable activity outbox -> delivery`. Display labels and previews have no persistence authority. Network, SQLite, canonical traversal and serialization remain outside frame callbacks.

### Single proof owner and S4a/S4c handoff

Define one immutable accepted observation carrying server activation, full ContentIdentity, reader generation, layout generation, composition identity, active source page/section, proven CFI, accepted revision and reason. Reasons retain `opened`, `navigation`, `layout-restored`, `snapshot`; a stable zoom/pan view change needs an explicit visibility-refresh reason that never counts as navigation completion.

S4a must expose, for each real source page in the foreground composition:

- Original section index/href/CFI base and source node/UTF-16 ranges, never a spread-wide fake section.
- Authored geometry, source-to-composition transform, clips, paint order/occluders, visibility/opacity and image-element hit geometry.
- The immutable layout/resource generation and source-order/nonlinear/blank-slot facts.
- Glyph/cluster ranges for XHTML text; SVG/MathML remain source-resolvable without inventing canonical text coordinates.

S4c supplies the settled composition-to-viewport transform and viewport/content clip plus blocking-panel/image-viewer/lifecycle state. S4b composes transforms and proves the original CFI start, including a range's start, against the same foreground generation. Bounding boxes alone cannot establish visibility under rotation, masks or occlusion. Unknown visibility contributes no coverage and produces a diagnosable unresolved gate for required fixtures.

CFI remains a source anchor. Reflowed page indices, percentages and spread labels cannot replace it. A blank slot cannot inherit the opposite page's CFI; active-side changes must select a real proven page. Persist one active anchor, while coverage may contain independently proven intervals for both visible real pages. An accepted CFI survives a failed reflow/restore/cancel; explicit chapter-start recovery is a new proven navigation, not an automatic overwrite.

On view change, invalidate delayed samples immediately; after a stable transform, re-prove the anchor and sample only the resulting visible geometry. Page-local transforms are keyed by content/composition/generation. Never serialize a transient transform as evidence that source content was seen. Keep source-position restoration independent of whether S4c retains transient zoom.

### Canonical coverage and zero-text behavior

Preserve canonical v1 exactly: source-order eligible Text nodes, filtered Unicode code points, UTF-16 mapping and FNV-1a signature. CSS-hidden text still belongs to canonical identity, but is not observed. SVG and MathML subtrees are excluded, including text rendered within SVG and its foreignObject descendants (`canonical_text.dart:126`; reference canonical oracle). Rendering new SVG text must not alter normalization.

After 300 ms of eligible stable idle, intersect each glyph/cluster's geometry with the accepted viewport, authored clips and occlusion model. Only complete proven visible canonical characters count. Retain disjoint half-open intervals; merge overlap/adjacency without filling hidden gaps. Emoji/combining/ligature fixtures must retain code-point counts and UTF-16 source positions. Recheck all identities before/after yields. Cached page intervals are candidates, never observations.

**Reference limitation:** `reference:client/src/reader/visibleText.ts` checks computed visibility/opacity and rectangular clipping, but does not subtract arbitrary overlapping elements or evaluate all transformed masks. Native actual-visible coverage therefore needs a separate conservative geometry oracle for overlaps/masks; the reference sampler alone is insufficient proof.

**Accepted narrow exception, 2026-10-27:** the user chose "native actual visibility, with known differences recorded". Reproducible reference occlusion-overcount differences in coverage intervals and resulting character totals are permitted only with paired reference/native evidence that identifies the occluder, expected visible characters and observed outcomes. Record a separately owned reference frontend fix handoff; that fix is not an S4 dependency. Canonical v1 text/coordinates, signatures, time, completion, deduplication and all other parity remain exact. This exception does not permit unexplained native undercounting, missing required text, broad masked-layout waivers or rewriting historical NAS statistics.

Pure image pages (and canonical-zero SVG pages) produce no section-coverage entry. The server requires `sectionLength >= 1` and nonempty intervals for an included section (`reference:shared/src/readingStats.ts:494`); sending a zero-length placeholder is invalid. They can still accrue foreground time and complete under the same rules as text pages:

- Verified navigation from non-final to final completes once per reader session, including explicit TOC/slider navigation.
- First healthy open of a never-saved one-page book completes once.
- Reopen at end, layout restore, snapshot, canceled turn, preview, zoom/pan and recovery do not create a completion.
- Completion is its own immutable `{durationMs: 0, sections: [], completion: {occurredAt, localDate}}` event with the full normal event identity/book/time fields; preserve its original local date/instant.

These outcomes are directly implemented by `reference:client/src/utils/readingActivity.ts:342` and `:376`; no image-pixel-to-character conversion or minimum-read-duration policy is needed.

### Foreground time and event creation

Port the clock/ledger behavior, not the browser event APIs. Inject monotonic time, wall time and a device-local calendar boundary adapter. Foreground time runs in idle/tracking/dragging/preparing/settling/committing once content is accepted and usable; it stops for background, detach/close, blocking panels, error/recovery and suspension. Image viewer keeps time but blocks text sampling. New whole-page gestures keep eligible time, invalidate text sampling until settled, and never synthesize navigation completion.

Checkpoint every 15 seconds and on lifecycle/close boundaries. Each checkpoint closes the span exactly once. Reject nonpositive spans, spans over 120 seconds, or monotonic/wall drift over 10 seconds. Split at observed local-hour/midnight boundaries with cumulative rounding; keep original local date/hour on retry. DST repeated hours share a label; skipped hours create no duration. The user's chat timezone must not be hardcoded into app event attribution.

Create opaque secure-random event IDs once (wire `[A-Za-z0-9_-]{8,64}`), serialize once, and durably store before send. Retain original event bytes across crashes/retry/content changes. Coverage ledger and pending event writes need a handoff that does not discard drained intervals when storage fails. Expose nondurable/error state and retain a bounded in-memory pending transaction for retry; do not report durable capture or send a record before its transaction succeeds.

### Proposed v2 -> v3 storage contract

Add an adjacent migration owned by existing `core/storage/sqlite_store*.dart`; do not alter shipped v1/v2 DDL or open a second connection. Proposed tables:

| Table | Key / retained values |
| --- | --- |
| `reader_checkpoints` | `(server_key, book_id)`: accepted revision, exact position payload, full ContentIdentity, local acceptance time, last server baseline payload/raw updatedAt, proof status. |
| `pending_positions` | `(server_key, book_id)`: latest accepted revision/payload/identity, baseline snapshot, pending/in-flight-uncertain/held/permanent-failure state. Coalesce only newer accepted revisions. |
| `activity_outbox` | `(server_key, event_id)`: exact payload text, book/content identity, durable sequence, creation time, pending/rejected/held status, sanitized reason. Event IDs remain globally random because the server keys IDs across books. |
| `coverage_suspensions` | `(server_key, book_id, section_index, normalization_version, signature)`: mismatch status; do not suspend unrelated text or time. |

Keep private state under Application Support. Rows reference server ownership with restrictive deletion, never evictable cache-generation rows. A cache purge/404/book replacement/server change cannot cascade away checkpoints/events. One accepted-position transaction writes checkpoint and pending position together. One outbox-result transaction records suspensions/rejections and removes only matching acknowledged IDs/payloads. Acknowledging revision N must leave N+1 pending. Migrate DDL, metadata and user_version atomically, with rollback and future-version refusal preserving original DB/sidecars.

S4c can add active-reader/appearance records through a later adjacent migration if needed. Coordinate schema numbers at implementation; v3 is the proposed next version based on the current v2 baseline.

### Exact HTTP surface and reconciliation

| Operation | Request / response | Rules |
| --- | --- | --- |
| GET `api/reading/{bookId}` | No body -> `{progress: ReadingPositionDto | null}` | Null means no stored position; it does not prove the book exists. Book existence remains S3 detail/file evidence. Failure must not become a page-one success. |
| PUT `api/reading/{bookId}` | `{progress, cfi, chapterHref, chapterLabel, chapterCount, chapterIndex}` -> `{progress: ReadingPositionDto}` | Finite progress in [0,1], strings/null, chapter pair both null or count>0/index in [-1,count-1]. Explicit backward movement is valid. 404 may carry `BOOK_NOT_FOUND`; 400 may carry `INVALID_CHAPTER_PROGRESS`. |
| POST `api/reading/activity` | `{"events":[<stored payloads joined verbatim>]}` -> `{results:[outcome...]}` | <=50 events, <=900000 encoded body bytes; validate result IDs/statuses and apply only the submitted snapshot. |

No CAS/If-Match support exists for positions. Server updates `updatedAt` using UTC SQLite fractional seconds and uses last-write-wins (`reference:server/src/routes/reading.ts:224`). Compare exact position tuples plus retained raw timestamp; do not infer ordering from native wall time or take `max(progress)`.

**Accepted user decision, 2026-10-27:** when a durable pending local progress intent conflicts with changed NAS/web progress, prefer local and allow it to overwrite the server. This does not authorize writes from an unproven candidate, another server/content identity, or a stale already-acknowledged checkpoint with no pending intent.

Reconciliation after timeout/restart/reconnect: GET before re-sending uncertain/stale positions. If remote equals submitted payload, acknowledge only that snapshot; otherwise re-prove the latest durable pending local CFI against current verified content and send that accepted local revision, even if remote changed since the baseline. Do not prompt for conflict or hold solely because the remote moved. Preserve the prior checkpoint on failed identity/CFI proof and offer existing retry/explicit recovery. Never replace an anchor with a percentage guess. Preflight cannot eliminate simultaneous-write races: the backend remains last-write-wins and no CAS guarantee is introduced.

The current web client blindly retries its coalesced local position queue (`reference:client/src/hooks/useReadingProgressPersistence.ts:48`); the native parent explicitly requires safer uncertain-write reconciliation. Do not copy the web queue verbatim or silently delete the durable checkpoint on 400/404.

Extend SessionTransport with narrowly typed mutation operations, fixed redacted route names, strict byte/body bounds and existing server activation cancellation. Do not reuse GET redirect/retry behavior for writes: reject mutation redirects instead of replaying potentially committed writes, and let the durable owner decide retries. Reader progress and activity repositories own DTO decoding; low-frequency delivery state exposes pending/error/last-accepted to S5 without importing presentation.

### Activity delivery outcomes

| Result | Durable action |
| --- | --- |
| `accepted`, duplicate false/true | Remove that exact queued event; never recapture/re-ID it. |
| Accepted with `SIGNATURE_MISMATCH` | Store suspension for the submitted section signature, acknowledge event; time/completion still count. Never rewrite its sections under the same ID. |
| `rejected`: `INVALID_ACTIVITY`, `BOOK_NOT_FOUND`, `EVENT_ID_CONFLICT` | Preserve exact event in rejected state, surface reason and stop retrying it. |
| Missing outcome, network/5xx, invalid response | Keep unanswered snapshot pending; retry same payload with bounded backoff (5 s to 5 min). |
| HTTP 400 envelope, multiple records | Retry singles to attribute the failure. A still-rejected singleton becomes retained permanent failure. |
| HTTP 413, multiple records | Halve batch; singleton oversized payload becomes retained permanent failure. |

Events commit individually on server; 500 may follow earlier committed events. Duplicate delivery must add no time/characters/completion. Activity wire bounds: <=32 distinct sections/event, <=256 intervals/section, indices <=100000, section length <=10000000; emit separate events to preserve sparse coverage without widening intervals. Duration limits are 86400000 ms without localHour and 3600000 ms with it. LocalHour absent and present are distinct immutable payloads.

### Content/session/worker invalidation

Acquire an independent cache lease before S3 route/controller releases PreparedBook; compare the acquired generation's full identity and restart if acquireHead returns another head. Open the leased immutable path with a captured PublicationTag, then preload. Use an explicit reader-session ownership token in the shared preparation queue so preparation cannot reopen/detach the same worker during a live reader's resource lifetime. A file lease protects bytes, not adapters.

On book/server replacement: stop accepting input, invalidate view/reader generations and sample timers, close time span, drain preparation/turn work, dispose prepared sections/resource adapters, detach worker, then release file lease. A late write response may reconcile only its captured server namespace and submitted revision; it must not update another active session's UI. A retired mutation can already have committed remotely, so retain uncertain delivery state.

Subscribe to identity-bearing `PrepareBookService.contentChanges`, but also compare stored/full current identity on every open because the stream is transient. Changed bytes/parser/canonical version invalidate derived proof and force CFI re-proof. Preserve unresolved checkpoints and immutable events with their old identities. Do not automatically relabel old coverage with the new signature. Known content mismatch holds unresolved coverage delivery for review; accepted historical time/events remain intact. A 304/size/mtime/snapshot revision cannot substitute for byte identity; server revision can decrease after restore.

### Ordered implementation and acceptance evidence

1. Freeze S4a geometry/transform/source-page contract and extend generated fixtures for text/image anchors, spread sides, mixed transitions, masks/clips, supplementary/combining text and canonical-zero SVG. Gate: exact CFI/canonical vectors, never actual NAS writes.
2. Build accepted-observation/session and coverage/clock/completion model using fake delivery and clocks. Gate: canceled/stale/preview/layout/zoom observations never overcredit or overwrite; pure-image cases above pass.
3. Add v3 migration and typed store commands. Gate: real SQLite temp-directory migration/crash/rollback/reopen tests; v1/v2 rows preserved, future schema untouched, cache eviction cannot remove reader rows.
4. Add typed routes and repositories plus serialized position and app-owned activity delivery. Gate: fake-transport request inventory permits only approved reads and the two new write routes, body redaction, prefixes, retirement, partial/duplicate/uncertain outcomes.
5. Wire S3 leases/worker to S4a prepared session and accepted pipeline. Gate: content replacement, revalidation, route departure, server switch and concurrent-preparation lifecycle with no stale proof/leak/cross-server write.
6. After semantic gates, run dedicated disposable cross-client data on the user's device/NAS: web -> native -> web CFI, backward reading, unchanged totals on duplicate retry, time exclusion, completion and signature mismatch. S4c owns full UI/device performance and paired evidence; S4b host passes cannot stand in for these results.

Port/reference fixture families: `readingActivityText`, `readingActivityGeometry`, `readingActivitySession`, `readingActivityDelivery`, `readingProgressPersistence`, `chapterProgress`, `foliateFixedLayoutCompatibility`, `foliateFixedLayoutVerification` under `reference:client/test/`. Reuse shiori canonical/CFI oracle tests and turn proof/cancellation tests; extend, do not replace their corpus. All public fixtures are synthetic; personal books/NAS addresses/CFIs/payloads remain private.

## Related specs and external references

Read `.trellis/spec/flutter/{reader-engine,data-layer,state-management,index}.md`, parent PRD/design/implementation and research/native-reader-contracts plus backend-contract-audit, and archived S3 research/s4-handoff. They establish the native/source, namespace, ownership and migration boundaries. No external dependency/API selection is needed for this internal contract audit; no package capability or live NAS version is inferred.

## Caveats / Not Found

- Current native code has no product checkpoint/activity owner or write transport; S2 diagnostic anchors are reusable proof components, not persistence completion.
- The accepted reference occlusion-overcount exception is limited to reproducible interval/character-total differences with paired evidence and a separate reference frontend fix handoff. The fix does not block S4; all other parity and canonical v1 remain unchanged, with no historical NAS rewrite.
- Local-first pending-progress reconciliation follows the explicit user decision above. Missing/invalid source proof still blocks delivery; remote change alone does not. Existing backend last-write-wins remains the concurrency limit.
- Durable history cannot be guaranteed across reinstall/signing-identity changes without a separately specified transfer route; keep existing signing/data-retention constraints.
- No product files, reference checkout, live NAS/history or tests/builds were changed or executed by this research.

## Planning consistency review (2026-10-27)

Reviewed all three S4 child PRDs/designs/execution plans after their first draft. Local-first pending position policy is consistent with the user's decision; zero-text completion, immutable activity and source/file ownership are substantially covered. All three reported planning findings are now resolved by the main owner:

1. **Resolved:** B-AC8 uses a standalone contract harness for restore/observe/flush/refresh ports. Actual S4c/S5 integration belongs to those later consumers, removing the circular completion gate.
2. **Resolved:** C lifecycle design separates panel/viewer eligibility, background suspension and final retirement, with retained/reacquired ownership explicit. Full dispose/detach/release follows A's shutdown order for retirement rather than every time-ineligible panel state.
3. **Resolved by explicit user decision:** parent AC6 and child plans record the narrow reference occlusion-overcount exception above. `reference:client/src/reader/visibleText.ts:61`, `:133`, `:210` remains the source evidence; paired outcomes and separate reference frontend remediation are required, but remediation is not an S4 dependency. Canonical v1 and all unaffected parity stay exact.

These are planning findings, not implementation test results. Main artifacts remain owned by the coordinating session; this review did not edit them.
