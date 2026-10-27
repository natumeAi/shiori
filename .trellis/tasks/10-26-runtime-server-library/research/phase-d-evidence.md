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
