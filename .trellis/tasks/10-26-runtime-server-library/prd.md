# S3: Runtime server and library foundation

## Goal

Let the iPhone app connect to a user-entered lan-reader deployment, retain that
selection, display its library and prepare verified EPUB content for S4.
Server changes, interrupted work and cache recovery must not mix libraries or
damage durable reader state. This is the data foundation of
`flutter-lan-reader-parity`, not the complete parity release.

Status: **planning; ready for renewed review**, 2026-10-26. The user requested
S3 planning; the later parent fixed-layout expansion refines the import
handoff below. The same day's plan review added duplicate-name resolution,
import layout facts, a file-backed worker archive and an early hosted SQLite
gate (S3-R7, S3-AC7, S3-AC10). No implementation, task activation, NAS access
or deployment is authorized by this document.

## Background and Dependencies

- Parent requirements: R1/R7 directly; R5/R6/R8/R11 storage and import
  prerequisites. Parent AC1 is only partly delivered here: the complete
  reading experience still requires S4. This task does not close parent AC2
  or the 120 FPS AC4.
- S1 and S2 are completed/archived; current shiori HEAD is
  `f1220fa`, containing their merged changes. S1 provides the fixed bundle ID,
  free cloud build/install flow and private/export directory boundary.
- S2 assigns bounded EPUB inflation and worker parsing to S3 before downloaded
  books are opened. Its conditional S4 GO retains failed/unverified
  performance, resource and lifecycle gates; they are not waived here.
- The parent now includes simple, complex static and mixed fixed-layout
  publications in S4. S3 preserves their layout metadata and prepared source;
  the old S2 whole-book fixed-layout rejection must not block import. This
  changes source readiness, not S3's ownership of rendering or reading UI.
- The read-only reference is clean at
  `a4bda23fd3e82e285a22566d88576e67d3e8756b`, version 3.3.0.
  The live NAS version/proxy behavior has not been contacted.
- The current app has a compile-time endpoint and placeholder home
  (`lib/core/config/env.dart:1`, `lib/core/network/dio_provider.dart:11`,
  `lib/app/routes.dart:7`). S3 replaces that configuration path for the product.
- Exact API and source evidence is in `research/contracts.md`; storage,
  parser and platform findings are in `research/storage-and-import.md`.

Dependencies are explicit: S3 needs the S1 build/storage foundation and the
merged S2 source model for its import handoff. S4 depends on S3's server
identity, cache lease and worker contracts. S5/S6 consume S3's typed library
data and add their own endpoints/behavior. Parent/child position alone does
not establish these dependencies.

## Requirements

| ID | Requirement and observable behavior | Parent |
| --- | --- | --- |
| S3-R1 | Enter, validate, persist and change an HTTP(S) deployment root, including port and path prefix. No rebuild or private endpoint in the binary. A failed candidate connection leaves the previous selection intact. | R1 |
| S3-R2 | Identify local state by normalized deployment root, with a separate generation for each activation. Switching A -> B -> A, cancellation and late HTTP/worker callbacks cannot publish into the wrong session, including when book IDs overlap. | R1, R8 |
| S3-R3 | Verify health and a typed snapshot before first activation. Preserve exact JSON envelopes, nullability, field casing, safe IDs, timestamps and 304 semantics. Decode only the read endpoints needed by S3; future mutation/statistics endpoints remain owned by S4-S6. | R1, R7 |
| S3-R4 | Provide a minimal localized connection form, read-only library/folder listing, refresh/retry/server-change entry and book preparation state. Show loading/empty/error/stale states and cover fallbacks. Success means the file and first section can be prepared for S4, not that reading progress was saved. | R1, R2 |
| S3-R5 | Download original EPUBs into private removable cache with bounded streaming I/O, opaque HTTP validators and an actual byte digest. Revalidate on connected preparation; reuse 304 only with a valid matching local file. Explicit file refresh bypasses validators. | R1, R8 |
| S3-R6 | Publish a file generation and its metadata without exposing partial content. Failed transfer, parse, cancellation, disk write or metadata commit preserves the previous valid generation. Changed bytes invalidate derived source/layout data without deleting or silently rewriting saved position/activity. | R5, R6, R8 |
| S3-R7 | Close the S2 downloaded-book prerequisite: enforce actual inflation bounds before accumulation, resolve duplicate entry names to the last occurrence like the reference, read the downloaded file without a whole-archive memory buffer, parse in a cancellable worker and preserve source/CFI/canonical semantics plus package/per-section layout facts. No layout class rejects import: fixed-layout, mixed, RTL and vertical publications reach the S4 handoff with recorded facts, and S4 owns renderer verdicts and the parent AC10 explanation. Corrupt or structurally invalid content produces a recoverable explanation; no empty-success result, rendering-support claim or reading write. | R3, R8, R11 |
| S3-R8 | Establish versioned transactional private storage and bounded cache ownership. Cache eviction cannot touch future checkpoint/outbox namespaces; active leases survive replacement/eviction. Missing removable files recover through a download. Unknown/newer durable schemas are preserved, not reset. | R1, R5, R6, R8 |
| S3-R9 | Validate the product entry point on the existing free iPhone build/install route. Add local-network purpose text and test permission grant/denial/retry, actual HTTP transport and restart/update retention. Preserve bundle ID and build-number continuity. | R9 |
| S3-R10 | Keep the reference checkout and NAS read-only, private content out of public artifacts, and S2 evidence limits explicit. Update affected Flutter specs during implementation and supply concrete S4 handoff contracts. | R7, R9 |

## Acceptance Criteria

| ID | Requirements | Evidence required |
| --- | --- | --- |
| S3-AC1 | R1, R3 | Fresh setup succeeds against generated root/prefix deployments; relaunch restores the committed endpoint. URL cases include trailing slash, explicit/default port, encoded path and IPv6 host. Credentials, malformed URL, query/fragment and non-HTTP(S) inputs are rejected without traffic. |
| S3-AC2 | R1, R3, R4 | Timeout/offline, HTML proxy/login body, 401/403, TLS failure, wrong service, unavailable database and unsupported snapshot schema have distinct recoverable states where evidence permits. Candidate failure/cancel leaves the previous server active; no guessed login flow or certificate bypass. |
| S3-AC3 | R2, R6 | Delayed health/snapshot/cover/file/worker responses in A -> B -> A tests cannot overwrite B or the later A activation. Requests and publication both enforce session identity/generation; cancellation does not trigger retry or an error for the new screen. |
| S3-AC4 | R3, R4 | Snapshot 200/304, null vs zero progress, empty library, folders/recent/shelf references, unknown additive fields, invalid required fields and UTC/raw timestamp preservation are fixture-tested. A 304 with missing/corrupt/incompatible cache causes one unconditional retry; repeated unusable 304 fails recoverably. |
| S3-AC5 | R5, R6 | EPUB 200 and valid 304 are usable; missing/corrupt local file, manual refresh, changed digest, unexpected 206/412/416, chunked transfer and no-validator responses are covered. Range fragments and error/login bodies never become complete cached books. |
| S3-AC6 | R6, R8 | Fault injection at temp write, validation, rename and DB commit, plus process restart/orphan cleanup, leaves either the previous verified generation or the new verified generation reachable. Cache purge never removes durable configuration or future reader-state records. |
| S3-AC7 | R7 | Generated hostile/corrupt/oversized/truncated archives fail within enforced entry/total/count limits. Generated duplicate-name archives resolve to the last occurrence like the reference, with every physical entry counted toward limits. Worker responsiveness/cancel/exit/late-result tests pass, and existing generated source/CFI/canonical vectors remain equivalent. Simple/complex fixed and mixed fixtures retain package/itemref layout, viewport/source and resource facts through import and handoff without the S2 blanket refusal. RTL-progression, RTL-language and vertical fixtures also prepare with their facts recorded; sections the worker did not style are marked not inspected, never horizontal/LTR. Corrupt documents remain recoverable failures. A generated near-limit archive opens file-backed, and host-measured worker resident memory stays within the documented budget without growing with compressed size. Source parsing or decompression must not occur in root-isolate resource reads or motion callbacks. |
| S3-AC8 | R5, R8 | Cache budget tests cover cross-server LRU, active lease pinning, disk-full, cleanup failure, OS-missing files and closed workers. Same numeric Book ID or publication identifier cannot merge server/book identities. Supported ordinary books are not silently truncated to satisfy a limit. |
| S3-AC9 | R4, R7 | Widget tests cover setup, switch failure, list/folder navigation, refresh, cover fallback, preparation/cancel/error/success. The successful state describes book readiness without implying a rendered reader or a saved position. |
| S3-AC10 | R8, R9 | Before Phase B relies on SQLite, an early hosted build through the existing route proves the chosen SQLite integration on the iPhone: packaging, the selected signing/install route, and open/commit/reopen/future-schema refusal under Application Support. A build of `lib/main.dart` installs under `io.github.natumeai.shiori`; iPhone grant/deny/re-enable/retry, real root-or-prefixed NAS access, book preparation including a near-limit synthetic archive without memory termination, relaunch and same-identity update retention are recorded. Unavailable prefix/HTTP cases remain explicitly unverified on device even if host fixtures pass. |
| S3-AC11 | R3, R10 | Automated network inventory permits only S3 GETs, including covers. No upload/delete/reorder/position/activity/goals writes. No lan-reader edits or personal NAS/book data in tracked artifacts. S4 receives documented identity, worker, lease, migration and content-change contracts. |

## Inherited Boundaries and Proposed S3 Decisions

- One active endpoint; changing it retains isolated state for previously used
  endpoints. No multi-server dashboard, discovery or endpoint migration/merge.
  Different scheme/port/prefix values remain different server identities.
- This follows the existing unauthenticated LAN contract. Reverse-proxy login,
  self-signed certificate acceptance and credential storage are out of scope.
- Use a read-only snapshot/list and preparation UI for independent S3
  validation. Full shell/home/statistics and bookshelf visual/interaction
  parity stay in S5/S6; full reading, CFI resume and activity delivery in S4.
- Import records layout facts and never rejects a layout class. Deferred
  vertical/RTL content is explained by S4 when it opens a section (parent
  AC10), so capability verdicts have one owner. S3 inspects styles only for
  sections it actually prepares; it does not scan the whole book at import.
- Cached metadata may be shown as stale after network failure. Continue using
  a verified publication already leased during transient failure. A new
  disconnected cold-open/offline-library promise is not added.
- Proposed storage: SQLite with a single background owner, plus
  `path_provider` directories; `sqlite3` is justified by transactional state
  and portable Windows tests. Promote existing transitive `crypto` to a direct
  dependency for streamed SHA-256. Resolve and check actual compatible versions
  and licences in implementation; no dependencies are installed in planning.
- All private configuration/durable state lives in Application Support;
  removable book/cover bytes in Caches. Documents remains intentional exports.
- The S3 device build is an engineering milestone. Shared synthetic probe
  assets remain tracked as the existing S4 pre-release cleanup item; S3 does
  not claim a production-ready asset bundle or complete app.

## Out of Scope

- Reader controls, theme/settings parity, accepted-position persistence,
  reading activity/outbox production/delivery, statistics/goal semantics.
- Rendering fixed/reflowable pages or selecting fixed-page zoom/gesture UX;
  those belong to S4 and do not block this import-only handoff.
- Upload, delete, reorder, grouping, drag, search/sort parity, batch actions,
  undo and a full three-tab product shell.
- Offline download management, background transfers, resume-range downloads,
  server/account discovery, automatic identity merging or backend migrations.
- Paid services, new app identity, new platform release targets, WebView/JS
  reader fallback, or resolving S2's full performance/presentation conditions.

## Risks and Deferred Evidence

- The deployed NAS/proxy may differ from audited source. Live incompatibility
  becomes an explicit handoff; never silently change backend behavior.
- Size/mtime ETags can miss same-size/same-mtime replacement. Client digests
  detect bytes actually downloaded; explicit refresh is the current recovery.
  Strong server content identity remains an optional parent handoff item.
- SQLite native packaging/signing is proven on the iPhone in Phase A, before
  storage work depends on it; a failure returns S3 to planning for the
  storage driver. Bounded file-backed archive I/O, transferable
  source/resource objects and iOS permission behavior also need
  implementation/device proof. Their gates precede downloaded-book
  activation; no unbounded UI-thread fallback.
- Fixing duplicate-name resolution changes merged S2 archive behavior,
  including the probe, for archives with repeated entry names. Existing
  vectors contain no duplicates and must remain unchanged.
- S2's seven conditional S4 items remain owned by S4, except the already
  assigned S3 import dependency. No extra S2 instrumentation is requested.
- Technical limits and UX additions here are a reviewable proposal. No
  unresolved product question blocks review; approval of this latest plan
  must precede `task.py start` and implementation.

## Artifacts

`design.md`: contracts and lifecycle; `implement.md`: ordered work/validation;
`research/contracts.md` and `research/storage-and-import.md`: evidence;
`research/planning-readiness.md`: planning checks;
`implement.jsonl` / `check.jsonl`: curated sub-agent context.
