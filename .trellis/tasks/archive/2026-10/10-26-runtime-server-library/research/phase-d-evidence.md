# S3 Phase D evidence

## D1 bounded download

Implemented and host-verified on 2026-10-27, based on Phase C commit `2603b18`
on `ios-build/s3-runtime-server`. This slice stops at a transfer-verified staged
file or reverified not-modified result. No cache head, store command/schema,
worker, reader, snapshot or cover implementation changed.

### Transport streaming API

`SessionTransport.getFile<T>(bookId, maxBytes:, consume:, ifNoneMatch:,
ifModifiedSince:, cancelToken:)` retains the session-owned Dio, GET allowlist,
prefix resolver, redirect policy and sanitized transport error mapping.
ETag takes precedence over Last-Modified; both are opaque. No Range/If-Range
option exists. Conditional 304 bypasses body consumption; unsolicited 304 and
all non-200 statuses are typed failures.

For a file 200, BoundedResponseAdapter detaches the raw source through
StreamingFileBody and gives Dio an empty response stream. The source is consumed
only by the bounded file callback, with pause/resume propagated during disk
awaits. No whole-EPUB buffer is created by Dio, the adapter, digest code or sink.
The source has a 20-second receive timeout and one cancellation callback per
transfer. Rejected sources and headers arriving after cancellation are closed.

Before creating the .part, require one EPUB/generic-binary MIME and reject
HTML/JSON/text/missing/ambiguous types. Present Content-Length must be one
nonnegative decimal at or below the ceiling. Count actual chunks before writing,
with inclusive `EpubLimits.maxArchiveBytes` (256 MiB default). Reject actual
overflow, declared/actual mismatch and consumers that abandon the stream.
Small injected ceilings exercise the same production checks without allocating
a 256 MiB test buffer. Binary MIME admission is not EPUB package validation.

### Staging and policy

New library-owned `data/publications/` files provide the service, immutable
input/results, safe feature failures and shared staging owner/providers.
Exclusive secure random 128-bit names live only under
`<Caches>/shiori/v1/staging/<random>.part`. Sequential asynchronous file writes
feed crypto SHA-256 incrementally, then flush/close. Results carry actual length,
digest, path/ownership and exact nullable response ETag/Last-Modified.

LocalPublication belongs to the requested BookKey and describes an immutable
generation pinned by the caller. Before conditions and again on 304, check
existence, expected length and digest shape; stream-rehash generations up to
8 MiB. Larger generations rely on caller verification/pinning and current length.
ETag is preferred, otherwise Last-Modified. Explicit refresh is unconditional.
200 without validators clears both result validators to null.

Unusable/unsolicited 304 or unexpected 206/412/416 allows one unconditional
recovery total. Another such response fails; other HTTP/TLS/network failures do
not enter that recovery. Every failure/cancel removes only the attempt's file.
Disk failures are content-free DownloadException(storage), never network retry.

### Coordination and ownership

BookKey duplicates share one Future/result. Refresh cancels/supersedes older
work, with a per-book operation generation checked alongside the full session
guard. A per-call CancelToken cancels the shared attempt. Guard retirement and
provider disposal cancel pending HTTP; close/deletion complete before the shared
transfer gate opens for the next book/session. Tests cover old A completing close
after same-endpoint reactivation and cancellation before delayed headers.

PublicationStaging serializes EPUB transfers across sessions and reserves one
compressed staging file. Successful StagedDownload transfers ownership to its
caller and retains that reservation; discard deletes it, while D2 must call
releaseAfterMove only after moving/deleting it. Another retained-stage admission
fails stagingBusy rather than accumulating a second file. This is separate from
D2's retained-cache quota and immutable publication/metadata transaction.

Startup cleanupAbandoned is nonrecursive and removes only regular immediate
.part files inside that exact directory, excluding live owned paths. It retains
other extensions, nested directories/files and outside .part files; it never
uses Documents or durable storage. The startup caller is responsible for invoking
the helper before download admission; product startup wiring is a later slice.

### Inventory and regression coverage

The five-route GET inventory now drives the generated download-service provider
and actual EPUB staging path, replacing its old file-route JSON seam. Its eight
recorded requests remain GET. Static inventory scans all lib Dart files and
rejects every `Dio(` construction outside session_transport.dart, with detector
probes for aliased/new constructors. The new download transport owner is pinned.

57 new tests cover fixture 200/chunked/no-validator responses, multi-chunk hash
equality, inclusive limits, both lying-length directions, early declared overflow,
actual overflow/upstream cancellation, receive error and own-file-only deletion,
200 HTML/JSON/text rejection, write/flush/close faults, conditional/unsolicited
304, local missing/length/digest corruption before and during 304, bounded
206/412/416 recovery/failure, validator precedence, refresh, coalescing,
retirement/disposal/reactivation, pre-header cancellation, raw-source backpressure,
safe redirects, incomplete consumers, provider ownership, staging reservation
and startup cleanup scope.

Initial focused checks exposed source cleanup semantics: an unstarted
StreamIterator.cancel does not subscribe/cancel the actual source. Rejected and
late sources now explicitly subscribe-and-cancel; their bytes never reach the
file writer. The first full run found a Windows slash-direction comparison in
the new sentinel-file assertion; it now compares absolute URIs. Final gates pass.

### Verification

| Command | Final result |
| --- | --- |
| `dart run build_runner build` | PASS; generated providers checked/created |
| `dart format` on changed Dart files | PASS; 16 files, plus final test-format pass |
| `dart format --output=none --set-exit-if-changed lib test` | PASS; 424 files, zero changes |
| `flutter analyze` | PASS; no issues |
| `flutter test test/core/network test/features/library/data/publications test/s3_get_only_inventory_test.dart --reporter expanded` | PASS; 247 tests |
| `flutter test --reporter expanded` | PASS; 1868 passed, 1 existing optional skip |
| `dart run tool/ci/check_reader_fixtures.dart` | PASS |
| `git diff --check` | PASS |

The existing optional native CFI export skip remains due to unset
SHIORI_NATIVE_CFI_OUT. Command logs are ignored `build/phase-d1-*.log` files.
The preexisting implement.jsonl/check.jsonl edits were left intact. No task
planning/context, dependency, fixture, reference checkout or git-state mutation
was performed. No commit, staging, push or branch switch.

No remaining D1 implementation issue. D2 publication/quota/reconciliation and
D3 package/worker validation remain separate; no new device/LAN, near-limit
iPhone memory or reader-readiness acceptance is claimed by these host results.

## D2a publication cache

Implemented and host-verified on 2026-10-27 from `b8e7483` on
`ios-build/s3-runtime-server`. This slice owns immutable publication files,
cache metadata/heads, in-memory leases/pins, shared byte admission and recovery.
No reader, transport, cover, snapshot implementation, dependency, fixture,
task plan/context, other worktree or reference checkout was changed.

### Store commands and migration

Extended the existing typed owner/worker protocol with publishGeneration,
readPublicationHead, readGeneration, listPublicationCandidates, deleteGeneration,
clearPublicationHead and touchGeneration. Generation/head publication is one
BEGIN IMMEDIATE transaction. Deletion clears only a matching cache head and
generation in a transaction. Candidates span every server in accessedAt order
with deterministic server/book/digest ties, excluding owner-supplied protected
generated paths. Access updates never touch server last-used or snapshot rows.

Schema v2 adds `canonical_version INTEGER NOT NULL DEFAULT 1 CHECK (> 0)` to
cached_publications via an adjacent v1 -> v2 transaction; shipped v1 DDL is
unchanged. Schema metadata and user_version update atomically with the column.
Migration tests retain an actual generation/head, configuration, snapshot and
unrelated reader-state sentinel; an injected v1 migration failure rolls the
column/version back with byte-identical database contents. Existing future
DELETE/WAL/hot-journal schema refusal and recovery tests remain passing.

The fixed failPublicationCommitDigest test hook introduces a deferred invalid
head FK after both intended writes. The real SQLite COMMIT fails, rolls back
the generation/head changes and leaves the worker usable for another command.
No arbitrary SQL or callbacks cross the worker boundary.

### Publication protocol

PublicationCache and its generated keep-alive provider are shared across
sessions. Files use `<Caches>/shiori/v1/publications/<serverKey>/<bookId>/
<sha256>.epub`; no title, filename, URL or arbitrary persisted path is resolved.
The cache rehashes the closed staged file incrementally. The orchestrator must
complete worker package/source validation before calling publish; synthetic
byte strings in these cache tests exercise publication, not EPUB validation.

beginPreparation captures the whole session and a monotonic operation token,
and pins its previous usable head before returning. Publish checks that token
and the guard before same-filesystem rename and immediately before store
dispatch. A present same-digest destination is stream-rehashed and reused while
staging is discarded; an open Windows destination is never overwritten.

Consumers acquire through the serialized cache after DB commit. A new digest
emits PublicationHeadChange(key, previousDigest, newDigest), including the first
head; identical digests emit no event. Metadata retains parserVersion and
canonicalVersion as integer fields; no ContentIdentity/ContentChange type is
defined here. A dispatched SQLite transaction is noncancelable; late retirement
suppresses results/events, with no compensation write after a successful commit.

Before rename, failure removes only the owned stage, including a queued publish
rejected by disposal. After rename/before commit, failure leaves an orphan and
the old head. After commit, a simulated crash retains the valid new head.
The staging reservation is released only after the file moves or is deleted.

### Leases, pins and shared budget

acquireHead returns PublicationLease(generation, local, release), checking
existence/length and touching LRU time. pinHead is an explicit pin API;
PublicationAttempt also retains its previousHead lease until close. Replacements
keep old generation bytes/records; the last lease/pin release makes them
evictable. Releases are idempotent and never synchronously delete bytes.

Private provider-container state retains the protection map, outstanding
reservations and serial queue across cache provider invalidation. Tests retain
an actual open generation lease plus a quota reservation across replacement,
then prove eviction is blocked until release. Mid-acquisition retirement cannot
touch access time or leak a pin. Mid-reservation disposal cannot evict bytes.

CacheBudget defaults to 512 MiB. Publication admission measures regular files
below publications (including unreferenced rename-crash orphans), plus held
reservations. It preflights enough reclaimable bytes, then evicts unleased and
unpinned generations in global LRU order. The current head can be evicted only
when unprotected. Generation/head row deletion precedes file deletion so DB
failure cannot leave a reference to a file just deleted by eviction.

An individual input above the cap returns tooLarge. Live content/reservations
preventing admission return cacheBusy. Filesystem/SQLite/cleanup failures map
to content-free storage failures. Same-digest reuse needs no additional quota.
D1's single up-to-256-MiB staging file is accounted separately.

reserveBytes exposes the next cover step's admission seam. Covers outside the
publications subtree must hold the reservation while those bytes exist and
release it after deletion; restoration must register existing cover bytes
before admitting publication bytes. No cover code changed in D2a.

### Reconciliation and durable-data isolation

Opening the cache automatically reconciles before returning; reconcile remains
callable later on the same queue. Check validation/path metadata and expected
file length/existence. Missing, invalid, zero-length, mismatched-length and
legacy arbitrary-path records lose only cache heads/rows so preparation fetches
again. Generated paths are the sole filesystem authority. Startup intentionally
does not hash every retained file; same-length external corruption is outside
this startup check and is detected by later digest verification.

Delete unreferenced regular files only inside publications, excluding live
protected paths. Do not follow directory/file links or remove directory trees.
OS removal of the publications directory becomes an empty cache and later
publication recreates it. Then call D1 cleanupAbandoned, retaining owned stages.

Tests preserve unrelated Caches files, synthetic Documents exports and
Application Support sentinels. Exact servers/app_state/library_snapshots and
future-reader sentinel rows are compared before/after publication, replacement,
lease access, eviction and missing-file reconciliation. Cache commands issue no
durable-table writes. No database/server-directory reset or reader-state deletion.

### Integration handoff

Await publicationCacheProvider.future at startup/before first preparation.
Create an attempt before detail/download/import, pass
`attempt.previousHead?.local` to D1, validate the returned stage in the worker,
then publish with the worker's parser/canonical versions. Always close the
attempt in finally. Acquire the committed head for subsequent file-backed use,
and release the lease only when its worker/consumer is finished with the file.
Any worker handles that would prevent rename must be closed before publication.

Normal preparation coalescing, worker identity mapping and product startup/UI
wiring remain with their owning slices. New beginPreparation calls supersede
the book's previous token; superseded attempts retain fallback protection until
their actual cleanup closes them. Leases are container-scoped, not durable locks.
Direct open callers must maintain a single cache owner for the shared directory.

### Verification

| Command | Final result |
| --- | --- |
| `dart run build_runner build` | PASS; generated cache/scope providers |
| `dart format` on storage/publication source and tests | PASS; 56 files |
| `dart format --output=none --set-exit-if-changed lib test` | PASS; 447 files, zero changes |
| `flutter analyze` | PASS; no issues |
| `flutter test test/core/storage test/features/library/data/publications --reporter expanded` | PASS; 151 tests |
| `flutter test --reporter expanded` | PASS; 1923 passed, 1 existing optional skip |
| `dart run tool/ci/check_reader_fixtures.dart` | PASS |
| `git diff --check` | PASS |

The existing optional native CFI export skip remains due to unset
SHIORI_NATIVE_CFI_OUT. Logs are ignored `build/phase-d2a-*.log` files. Initial
analysis found initializing-formal and braces lints, fixed before the final
clean run. No remaining D2a implementation issue. No commit, stage, push,
branch switch, worker-import/device/LAN or near-limit iPhone acceptance claim.

## D2b cover disk cache

Implemented directly on Windows, 2026-10-27, over D2a HEAD `c9e1b67` on
`ios-build/s3-runtime-server`. No sub-agents, Git-state mutations, dependencies,
fixtures, transport, schema, snapshots, reader code or other worktrees changed.

### Changed files and ownership

- `lib/core/storage/cache_budget.dart`: disk LRU sub-budget, generated-name I/O,
  atomic writes, length/stream bounds and lifetime reservation accounting. The
  budget retains sub-budget state across publication-provider replacement.
- `lib/features/library/data/covers/cover_disk_store.dart`: cover identity and
  session adapter; no Flutter image decoding in storage.
- `publication_cache_reconciliation.dart`: configure the cover sub-budget on
  the existing publication queue, supply non-evicting shared admission, and
  reconcile covers before returning. No publication_cache.dart edit was needed.
- `presentation/covers/cover_loader.dart` and generated `.g.dart`: lazy
  production disk wiring, memory -> disk -> session GET, decode validation,
  corrupt-file recovery and best-effort write-through.
- Tests add `data/covers/{cover_disk_store_test,cover_disk_integration_test,
  cover_disk_test_support}.dart` and
  `presentation/covers/cover_loader_disk_test.dart` (17 new test cases).
- `data-layer.md`: executable D2b signatures, layout, budget, cancellation,
  reconciliation, failure and test contracts; remove obsolete disk-seam wording.

### Disk layout and budget

Cover files live under `<Caches>/shiori/v1/covers/<ServerKey SHA-256>/
<SHA-256 of UTF-8 deployment-relative cover path including query>.cache`.
Only generated directory/file components authorize I/O. Validate the cover path
with ServerEndpoint.cover before hashing. Temp names are exclusive random
128-bit `.part` files in that same server directory; flush/close encoded bytes,
then rename atomically. Directory/file links are never followed.

Disk covers have a 16 MiB encoded LRU sub-budget across servers, within the
shared 512 MiB cap, and an inclusive 8 MiB individual bound. Memory retains the
existing separate 16 MiB encoded and decoded accounting. Reads check registered
length and actual bounded streamed bytes; invalid/unregistered bytes are removed.
These are resource-accounting bounds, not device/process-RSS measurements.

The cover admission callback measures publication bytes and uses fits/reserve
directly on the same serial queue. It does not call publication reserveBytes or
_reserve and cannot evict a publication. Cover pressure evicts only oldest cover
files, using write/read order in memory and modification times after restart.
Insufficient shared capacity skips persistence, leaving the decoded image usable.

Reserve before temp creation and retain the charge while the file exists outside
the publications subtree. Release after deletion/confirmed absence, including
cancelled writes. A failed cleanup retains its reservation and counts toward the
sub-budget until reconciliation removes it. Budget-owned state and callback
rebinding preserve charges across publication provider invalidation.

### Loader and lifecycle

Use decoded/encoded memory first, then disk, then bounded GET through the captured
session transport. Disk bytes pass the same native decode path. A nonImage disk
failure deletes that file and performs one network fetch; only successful network
decoding enables write-through. Storage-open/write failures remain best effort.
During write-through an internal pixel pin prevents concurrent decode eviction
from invalidating the image awaiting persistence.

Results, mutations and admission check the complete session. Retirement/disposal
clears memory and cancels pending work without deleting completed server-scoped
disk files. An interrupted write removes only its own temp/new destination and
releases its charge once outstanding filesystem I/O and cleanup finish. The
beforeRename test gate races retirement, so its caller completes cancelled and
cleanup finishes even while the held gate has not resumed. Late completion does
not recreate a temp, publish pixels or affect a later activation.

### Reconciliation and assertions

Publication open reconciles covers before publication admission. Remove stray
regular files/temps and invalid lengths only in the covers root and generated
server directories; enforce the sub-budget and register retained reservations.
Under shared startup pressure, discard covers while preserving publication
bytes/heads. Repeated reconciliation does not double-charge files; OS-missing
files release their old charges. Sibling cache sentinels remain unchanged.

Tests prove disk reuse without HTTP after retirement and cold-loader creation,
non-decodable replacement, cross-server same-path isolation, sub-budget read-touch
LRU, no publication eviction under shared pressure, successful images without
persistence, retirement cleanup, startup cleanup/budget restoration, production
provider disk wiring and invalidation, memory priority, write-failure cleanup,
and rejection of non-image network bodies. Existing GET-only inventory passes.

### Commands run

| Command | Final result |
| --- | --- |
| `dart run build_runner build` | PASS; only loader generated hash changes semantically |
| `dart format` on changed Dart files | PASS |
| `dart format --output=none --set-exit-if-changed` on 9 changed/new Dart files | PASS; zero changes |
| `flutter analyze` | PASS; no issues |
| `flutter test --no-pub test/core/storage test/features/library test/s3_get_only_inventory_test.dart --reporter expanded` | PASS; 436 tests, no skips |
| `flutter test --reporter expanded` | PASS; 1940 passed, 1 existing optional skip |
| `dart run tool/ci/check_reader_fixtures.dart` | PASS; manifest/privacy guard, exit 0 |
| `git diff --check` | PASS |

The existing optional native CFI export skip remains due to unset
SHIORI_NATIVE_CFI_OUT. Logs are ignored `build/phase-d2b-*.log` files. Initial
focused checking caught nullable generic inference and a synchronous-throw test
assertion; both were corrected before the successful full gates above.

No remaining D2b implementation issue. Broader S3 product/device/LAN acceptance
and other phases remain with their owners; these host tests do not close them.

Phase D / Phase F S4-contract handoff item: [Concrete S4 APIs, lifetimes, migrations and retained gates](s4-handoff.md).

## D5 prepare-book orchestration

Implemented and host-verified on 2026-10-27 from `e1d652c`, branch
`ios-build/s3-runtime-server`. This session implemented directly, without
sub-agents, git index/branch changes, commits or pushes. Screens/routes/l10n,
iOS/CI/dependencies, fixtures/vectors, task planning/context files and other
checkouts were not edited. The two Flutter specs document the new contracts.

### Preparation sequence and ownership

PrepareBookService captures the active ServerSession and a per-book generation.
Normal duplicates share a Future/result; explicit refresh supersedes previous
work and bypasses validators. A container-owned PrepareBookQueue holds the single
staging/import slot through physical worker completion and cleanup across sessions.
BeginPreparation pins the prior head before detail/download/import. Detail 404
is typed unavailable. The current head supplies validators only after version
compatibility, length and full incremental SHA-256 verification. After 304 the
file is reverified again; local loss triggers bounded unconditional recovery.

Staged bytes become ContentIdentity, then pass real worker prepare before cache
publication. Worker detach drains canceled physical work and releases the staging
handle before rename. PublishLeased serializes validated publication and new-head
acquisition with eviction. PreparedBook returns identity, detached summary,
layout facts and a lease. S4 reopens its immutable leased path before preload.
Valid fixed/RTL/mixed/vertical facts remain independent of rendering capability.

Every async boundary and publication checks session/operation ownership.
Logical cancel settles callers silently; the fallback pin stays held until the
worker physically detaches, then cleanup releases attempt pins/abandoned leases
and removes only this attempt's staging. Ready owners are released on retirement.
A dispatched verified SQLite commit may still finish for its server namespace;
retired callbacks cannot expose ready/content events or write reader state.

### Controller and events

Generated preparationControllerProvider(session, BookKey) exposes idle,
preparing(receivedBytes?, totalBytes?), ready(PreparedBook), failed(typed error),
with explicit prepare/refresh/retry/cancel. Build starts no HTTP. Captured view
and operation lifetimes protect rebuild/dispose/synchronous-listener races.
Cancel returns idle; cancellation is never a provider error or automatic retry.

The service owns guarded synchronous ContentChange broadcasts; the generated
publicationContentChangesProvider(session) adapts them for S4. First publication
has null previous identity; replacement includes both full identities. Matching
304 and same-identity 200 emit none. This is transient notification, not an
outbox. S4 compares identities on open, re-proves CFI and retains unresolvable
checkpoints/events. No position/activity/goals or remote mutation API was added.

SessionPublicationWorker is lazy and session-scoped, declared in library wiring
so reader data stays provider-free. Retirement also closes a late spawn; failed
spawn can retry. Closed workers are replaceable on the next explicit attempt.

### Small D1-D4 integration hooks

| Existing boundary | Change and reason |
| --- | --- |
| D1 SessionTransport.getFile | Optional actual-byte/nullable-total progress hook, including over-limit evidence before rejecting headers/chunks; core keeps no feature imports. |
| D1 PublicationDownloadService / DownloadFailure | Forward guarded progress; typed tooLarge for declared/actual compressed overflow. Two existing limit tests now assert that stronger type; all safety assertions remain. |
| D2a PublicationCache | Add publishLeased so commit and first lease cannot race eviction; existing publish API remains. |
| D3 worker client/protocol/runtime | Add detach request/ack to release the archive while retaining its session isolate; canceled operations retain their physical slot until the late result drains. |

No D2b or D4 resource implementation was changed. D4 is exercised by reopening
the published leased file and preloading through ReaderResourceSource.

### Tests and final commands

27 new tests use generated EPUB bytes, real SQLite worker/store, real publication
worker, fake HTTP adapter and temporary Support/Caches directories. They cover
first 200/ready; conditional 304 without downloaded bytes; unchanged forced 200;
digest changes/events and readable older leases; malformed EPUB/old head;
detail 404/retry; missing/corrupt local heads; loss during 304 with one recovery;
cache busy/fallback pin; rename/storage and declared/chunked size errors;
network classification; fixed/RTL facts; worker-preload resource handoff;
duplicates/refresh; cancel during download/import; A -> B -> A; view disposal;
retirement cleanup; synchronous notification cancellation/retirement; foreign
BookKey rejection; concurrent/retired/failed worker spawn. A paused real 304 import
proves cancellation retains its fallback pin until detach, then permits eviction.
All successful outputs stay inside injected Caches/Application Support; Documents
resolution throws. Existing GET-only runtime/static inventory passes unchanged.

| Command | Final result |
| --- | --- |
| `dart run build_runner build` | PASS; four new generated provider files; existing generated contents unchanged. |
| `dart format` on changed/new Dart files | PASS; 26 files formatted. |
| `flutter analyze` | PASS; no issues. |
| Focused four D5 test files (`flutter test --no-pub ... --reporter expanded`) | PASS; 27 passed, zero skipped/failed. |
| Publication/network/worker/GET inventory regression run | PASS; 414 passed before five additional final lifecycle/spawn tests. |
| `flutter test --reporter expanded` | PASS; 2,082 passed, one existing optional skip, zero failed. |
| `dart run tool/ci/check_reader_fixtures.dart` | PASS; manifests and EPUB privacy guard, exit 0. |
| `git diff --check` and forbidden-path scope review | PASS. |

Logs are ignored `build/d5-*.log`. The full suite includes the available local
oracle/layout checks; no private input/output was added to tracked artifacts.
The single skip is native CFI export without SHIORI_NATIVE_CFI_OUT.
An initial analysis warning (unused import/braces) and two existing limit-test
type assertions were corrected. The first full run passed 2,081 tests; final
review tightened the cancellation pin lifetime and added its regression, then
reran build/format/analyze/full suite/fixture gates to the final totals above.

### Remaining boundaries

No known D5 implementation blocker remains. The handoff records exact public
types/APIs, release rules, v2 schema ownership and later S4 migrations, resource
budget semantics and all seven retained S2 conditional S4 items. S4 coordinates
session worker ownership with preparation, consumes resource owners once and
re-proves positions; product rendering/checkpoint/outbox work remains S4-owned.
Real iPhone product/LAN permission/HTTP-prefix/update/lifecycle evidence and
near-limit peak memory/no OS termination remain owed. These host gates do not
complete S3-AC10 or waive any S2 resource/performance/device condition.

## Phase D review fixes

Implemented directly on 2026-10-27 in `D:/Projects/shiori`, branch
`ios-build/s3-runtime-server`, from clean HEAD `d2163cf`. Read the independent
reviewer's `edge_probe_test.dart` and `corrupt_cache_probe_test.dart` under
`%TEMP%/shiori-phase-d-independent/` without editing them. Their staging,
same-length corruption and large-file post-304 cases now have project regression
coverage. No sub-agents, other checkout edits, staging, commits, pushes or branch
switches were performed.

### Fixes and contracts

1. Staging checks every generated ancestor (`shiori`, `v1`, `staging`) without
   following links before creation/listing and again before owned-file open,
   discard and publication rename. Missing ancestors are created one at a time;
   links/non-directories are content-free DownloadException(storage). Probe
   paths have no trailing separator: Windows otherwise followed directory links
   even with followLinks:false. Publication ancestor probes use the same safe
   form. Root/intermediate-link tests preserve outside .part sentinels; replacing
   the staging directory after file creation cannot redirect open/discard.
2. Full verification retires the detected corrupt physical path under the cache
   queue, removes only matching cache metadata/head and prevents new leases.
   Existing leases keep that path readable until release. Verified unchanged
   bytes can publish at `<sha256>.<random 128-bit generation>.epub` while the old
   path is pinned; an unleased corrupt destination is removed before republishing
   at its digest path. The generated suffix round-trips through the existing v2
   relative_path column, with strict path/name validation and no schema migration.
   Last lease release queues deletion on the current cache owner, including
   provider replacement. Failed cleanup remains recorded/charged; explicit
   reconciliation reports storage and retries. Late reports for the old path
   cannot delete a repaired same-digest row. Content identity stays unchanged.
3. One PublicationRecoveryAllowance spans D1 and D5 for an entire preparation,
   including full verification after 304. Small-file D1 failures notify the cache
   before recovery; large-file D5 failures do likewise. A second protocol anomaly
   becomes PrepareBookException(server) after two file requests, rather than
   starting a third request. Successful 304 -> full 200 recovery remains valid.
   Reconciliation waits for staging cleanup before entering the cache queue,
   avoiding a staging/cache lock inversion with D1's corruption notification.
4. The optional pre-seam baseline reports a skip when
   `build/d4/pre-seam-pages.json` is absent. `D4_REQUIRE_BASELINE=1` makes missing
   evidence fail explicitly; capture mode remains available. Comparison cannot
   silently pass if a previously present baseline disappears before reading it.

`data-layer.md` and `s4-handoff.md` now describe actual retirement/recovery,
generated paths, lease cleanup, staging checks and the shared recovery allowance.
Startup intentionally retains its length-only check: unknown same-length
corruption is detected on full verification, while already detected corruption
is never admitted for reuse. No reader state is removed or rewritten.

### Regression coverage and commands

20 new tests cover linked staging roots/intermediates and post-create swaps;
normal preparation and reconcile/forced-refresh repair with/without user leases;
old handles held across recovery; small and large post-304 corruption; mixed
second statuses 206/304/412/416; recovery-path restart/reuse; unleased digest-path
repair; failed cleanup retry; concurrent reconciliation; and release after cache
provider replacement. The former corrupt-destination rejection test now requires
successful repair while preserving its old-file/no-overwrite assertions, then
checks deletion after release. No existing safety assertion was weakened.

| Command/check | Final result |
| --- | --- |
| `dart run build_runner build` | PASS; generated outputs have no remaining diff |
| `dart format` on changed Dart files | PASS |
| `dart format --output=none --set-exit-if-changed lib test tool/reader tool/diag tool/ci` | PASS; 522 files, zero changes |
| `flutter analyze` | PASS; no issues |
| `flutter test --no-pub test/features/library/data/publications test/core/storage test/features/reader/engine/pagination/resource_baseline_test.dart --reporter expanded` | PASS; 198 passed, one explicit optional baseline skip |
| `D4_REQUIRE_BASELINE=1 flutter test --no-pub test/features/reader/engine/pagination/resource_baseline_test.dart --reporter expanded` | Expected failure verified; one test fails with the missing-evidence reason |
| `flutter test --reporter expanded` | PASS; 2,101 passed, two optional skips, zero failed |
| `dart run tool/ci/check_reader_fixtures.dart` | PASS; fixture manifests/privacy guard |
| `git diff --check` and changed-path review | PASS; only authorized publication/cache primitives, related tests and three documentation files |

The two skips are native CFI export without SHIORI_NATIVE_CFI_OUT and the absent
pre-seam baseline. Logs are ignored `build/phase-d-review-*.log` files. Initial
focused failures exposed the Windows trailing-separator/link behavior, mixed
separator staging ownership comparisons and reuse of a retired missing path;
these were fixed before the final passing runs. Initial analyzer findings
(redundant null assertion, unnecessary import and missing braces) were fixed.
No UI/routes/l10n, transport implementation, pubspec/dependencies, fixtures,
task prd/design/implement/jsonl, or reviewer's temporary files changed.

All four review items are resolved. Existing device/LAN/performance evidence
boundaries above remain unchanged; these host regressions do not close AC10.
