# S3 D5 -> S4 preparation handoff

Date: 2026-10-27. Scope: host-verified connected preparation and source/resource
contracts. Readiness means package and first linear section validated. It does
not mean rendered pages, restored position or recorded activity. Sources below
are repository-relative; APIs are implemented, not proposed.

## Identities and session boundary

`lib/core/config/` owns these feature-independent values:

```dart
BookKey(ServerKey serverKey, int bookId); // 1..9007199254740991
ContentIdentity(BookKey bookKey, String sha256, {
  int parserVersion = publicationParserVersion,
  int canonicalVersion = publicationCanonicalVersion,
});
ContentChange({ContentIdentity? previous, required ContentIdentity next});
ServerSession({required ServerEndpoint endpoint, required int generation});
bool SessionPublicationGuard.isCurrent(ServerSession session);
bool SessionPublicationGuard.publish(ServerSession session, void Function() action);
void Function() SessionPublicationGuard.onRetire(
    ServerSession session, void Function() cancel);
```

`BookKey` equality includes the normalized deployment namespace. A numeric ID or
EPUB identifier alone cannot identify a book. `ContentIdentity` equality also
includes actual lowercase SHA-256 and both interpretation versions (currently
1/1). HTTP ETag/Last-Modified are opaque validators, never content identities.
`isCurrent` tests version compatibility. Every activation, including A -> B -> A,
has a fresh runtime generation. This generation is not a durable checkpoint key.
Same URL reused for another database cannot be perfectly detected; there is no
server-issued durable deployment UUID in the audited protocol.

## Preparation and UI APIs

Implemented under `lib/features/library/data/publications/`:

```dart
Future<PreparedBook> PrepareBookService.prepare(BookKey key, {bool refresh = false});
void PrepareBookService.cancel(BookKey key);
void PrepareBookService.dispose();
Stream<ContentChange> get PrepareBookService.contentChanges;
Stream<({BookKey key, int received, int? total})> get PrepareBookService.progress;

PreparedBook(PreparedPublication publication, PublicationLease lease,
    void Function() onRelease);
ContentIdentity get PreparedBook.identity;
PublicationLayoutFacts get PreparedBook.layoutFacts;
bool get PreparedBook.isReleased;
void PreparedBook.release();

PreparationState PreparationController.build(ServerSession session, BookKey key);
Future<void> PreparationController.prepare({bool refresh = false});
void PreparationController.cancel();
const PreparationState.idle();
const PreparationState.preparing({int? receivedBytes, int? totalBytes});
const PreparationState.ready(PreparedBook book);
const PreparationState.failed(PrepareBookException error);
```

Generated families: `prepareBookServiceProvider(session)` and
`sessionPublicationWorkerProvider(session)` are keep-alive; the auto-dispose
`preparationControllerProvider(session, key)` owns view state. No HTTP runs in
controller build: call its `prepare()` explicitly. `refresh: true` bypasses file
validators and supersedes pending work. Normal duplicate calls share the exact
Future/result/lease, not independently releasable owners. A later completed
prepare revalidates remotely, including a usable cached head.

The controller exposes the sealed `PreparationIdle`, `PreparationPreparing`,
`PreparationReady`, `PreparationFailed` values. Received bytes start unknown,
then count admitted file bytes; total stays null for chunked/unknown length.
Controller prepare consumes typed failures and cancellation; cancel returns
idle. Service callers catch `PrepareBookException.failure` or silent
`RequestCancelled`. Failure cases include unavailable (404), network, tooLarge,
cacheBusy, invalidStructure, unsupportedStructure, storage, unauthorized, tls,
server, redirect and workerUnavailable. No raw cause/path is retained. No layout
class maps to unsupportedStructure: renderer capability remains S4-owned.

The container-owned `PrepareBookQueue` holds the stage/import/detach/publish slot
across sessions. Cancellation settles callers promptly; the physical worker
operation still drains before detach/close and staging deletion. Its inflation
and synchronous parse cannot be preempted. A new operation cannot accumulate
another staging file behind a canceled import. Detail, download, worker results,
publication admission and UI/events check the captured session/operation.

## Publication summary and layout facts

`lib/features/reader/data/worker/prepared_publication.dart`:

```dart
const PreparedPublication({
  required ContentIdentity identity,
  required PublicationSnapshot snapshot,
  required PublicationMetadata metadata,
  required PublicationLayoutFacts layoutFacts,
  required FirstSectionReadiness firstSection,
});
```

All five are final fields. `snapshot.package` and `snapshot.sections` are detached
immutable package/section values, with real OPF-derived CFI bases. Metadata keeps
immutable `titles`, `creators`, `languages`, `identifiers` lists. First-section
readiness contains sectionIndex, href, nullable cfiBase, parserUsed,
parserErrorClass, canonicalVersion/Length/Signature and resource references
(sourcePath, url, nullable local path/mediaType, present). It contains no lazy
archive, loader, callback or file handle.

`PublicationLayoutFacts` retains nullable pageProgressionDirection and
primaryLanguage, immutable packageRendition and sections. Each section retains
filtered sectionIndex, original spineIndex, fixed/reflowable mode, raw itemref
properties, effective rendition overrides, optional source viewport/SVG facts
and optional writing-mode/direction/RTL style facts. Only the first prepared
linear section is inspected. Other sections are `SectionInspection.notInspected`,
with null source/style; null is never evidence of horizontal/LTR support.
Fixed, mixed, RTL and vertical content can prepare. S4 owns per-section renderer
verdicts and user explanation/action, including later-section failures without
losing accepted position. The S2 probe refusal is unchanged.

## File leases, attempts and publication

`PublicationLease` has final `StoredPublication generation` and
`LocalPublication local` fields and `void release()` (idempotent). It is a memory
pin on the immutable `local.path`, not a worker/source session. The historical
design shorthand `PublicationLease(identity, sourceSession, release)` is not
the implemented constructor; derive identity from generation, or use PreparedBook.

```dart
Future<PublicationAttempt> PublicationCache.beginPreparation(
    ServerSession session, BookKey key);
Future<PublicationLease?> PublicationCache.acquireHead(
    ServerSession session, BookKey key);
Future<PublicationLease> PublicationCache.publishLeased(
    PublicationAttempt attempt, StagedDownload staged, {
    required int parserVersion, required int canonicalVersion,
});
void PublicationAttempt.checkCurrent();
void PublicationAttempt.close();
```

The attempt pins the previous head before detail/network/import. The file is
stream-rehashed before conditions and again after 304, including large files;
missing/invalid conditional reuse gets one unconditional recovery. Staged bytes
pass worker prepare before rename. Detach releases the stage's native handle;
publish rehashes and renames on the Caches filesystem before the SQLite head
transaction. `publishLeased` shares serialization with eviction until the first
new-head lease is acquired. Parse/transfer/admission/commit failures cannot
publish an invalid/partial EPUB. A dispatched commit may finish after retirement;
its verified server-scoped generation remains durable, but no retired ready or
content event escapes. There is no unsafe rollback/deletion after dispatch.

`PreparedBook.release()` releases its lease and removes service ownership.
The controller releases its ready book on prepare, cancel, disposal and session
retirement. Direct service callers release on abandonment; the service also
releases every outstanding result on retirement/disposal. S4 must acquire its
own lease before the UI releases its ready book, verify its full identity still
matches, and release once all worker/source users of that file have stopped.
AcquireHead can return a newer head: compare identity and restart handoff if so.
Never release a shared/coalesced result as though it were a separate owner.
Replacing/evicting a head cannot remove an older leased generation. OS removal
or external corruption remains recoverable; a lease cannot prevent OS purge.
Corrupt existing immutable same-digest destinations are never overwritten while
leased; release users and reconcile/retry, or accept a valid different digest.

## Worker, preload and retained resources

The provider is declared in library publications to keep reader data independent
of Riverpod. `SessionPublicationWorker.get() -> Future<PublicationWorker>` lazily
returns one worker for that session; `dispose()` retires it and `closed` awaits
shutdown. Retirement during spawn closes the late worker before exposing it.
Provider retirement/disposal closes the isolate, including when a view remains.

```dart
Future<PreparedPublication> PublicationWorker.prepare(
  String path, ContentIdentity identity, {
  PublicationTag? tag, PublicationCancellation? cancellation,
});
Future<PublicationSnapshot> PublicationWorker.open(
  String path, PublicationTag tag, {PublicationCancellation? cancellation});
Future<SourceDocument> PublicationWorker.loadSection(
  int index, {PublicationCancellation? cancellation});
Future<Uint8List?> PublicationWorker.readResource(
  String path, {PublicationCancellation? cancellation});
Future<PreloadedPublicationSection> PublicationWorker.preloadSection(int index, {
  ReaderSettings settings = const ReaderSettings(),
  ReaderResourceBudget? budget, PublicationCancellation? cancellation,
  void Function(ReaderResourceMiss)? onMiss,
});
Future<void> PublicationWorker.detach();
Future<void> PublicationWorker.close();
```

D5 returns a detached summary, with the worker detached from staging. S4 opens
or prepares `ready.lease.local.path` with its captured identity/session tag before
load/preload. Reopen/prepare/detach/close invalidate prior resource adapters;
do not concurrently use the session worker for another book and a live reader.
S4 must coordinate this ownership with preparation (the shared queue can
serialize an open/preload sequence) and capture settings/content/session before
accepting a section. A file lease preserves bytes, not old worker adapters.

`PreloadedPublicationSection.plan` contains detached document, styled lookup,
sectionIndex/href/cfiBase, references and exact lengths. Its `.resources` is a
`PreloadedReaderResourceSource implements ReaderResourceSource`:

```dart
Uint8List? ReaderResourceSource.bytes(String path);
bool ReaderResourceSource.contains(String path);
int ReaderResourceSource.size(String path);
void ReaderResourceSource.dispose();
void PreloadedPublicationSection.dispose();
void PreloadedReaderResourceSource.releaseToCache();
```

Pass plan values and resources to `PrepareRequest.resources` / SectionPreparer.
Section preparation consumes this resource owner once: success transfers it to
PreparedSection, and failure/cancel disposes it. Dispose an abandoned preload.
The adapter never falls back to archive/network/disk/inflate. Missing bytes are
null, with absent/notPreloaded/disposed/retired diagnostics; only enum values may
be logged. Main-isolate font registration, native paragraphs, image decode and
painting remain outside motion callbacks and outside the worker.

`ReaderResourceBudget.shared` is the D4 process-shared product default:
134,217,728 bytes (128 MiB) for retained encoded bytes **plus reservations**.
Preload reserves complete missing sizes before transfer, pins hits, sends only
misses, shares read-only buffers and evicts only unleased LRU entries. Dispose
drops last-owner entries; releaseToCache retains unleased LRU candidates. Worker
reopen/detach/close/exit retires reservations and even live adapters. Budget
failures are `ReaderResourceException` with budgetExceeded/busy/retired/
invalidTransfer; never trim a section to fit. The cap excludes source/style
graphs, transient inflate/transfer copies, decoded pixels, fonts and process RSS.
D4 host peaks were about 521 MiB with only 4 MiB retained encoded resources;
these results cannot establish an iPhone memory ceiling.

Other retained bounds: 256 MiB compressed/staged file, 20,000 physical entries,
64 MiB per expanded entry, 1 GiB aggregate expansion, bounded ZIP directory and
metadata, worker pending queue 8, one staged EPUB, 512 MiB retained EPUB/cover
disk cache across servers, cover encoded disk sub-budget 16 MiB. Staging is
additional to retained disk quota. Source/CFI/canonical vectors stay authoritative.

## Schema and migration ownership

`lib/core/storage/sqlite_store*.dart` owns the one background SQLite connection,
typed command protocol and explicit adjacent migrations. Current schema is v2:
v1 contains servers, app_state, library_snapshots, cached_publications and
book_cache_heads; v2 adds canonical_version. D5 adds no schema/table.

S4 adds checkpoint/outbox tables through explicit **later** migrations, including
transactional schema metadata/user_version updates and preservation tests.
Never edit shipped v1/v2 definitions, reset on future schema, introduce a second
connection owner or pass SQL/handles across isolate ports. Unknown/newer schemas
are refused with original database/sidecar bytes retained.

The store is `<Application Support>/shiori/v1/state.db`. EPUB and covers are
removable files below Caches; Documents remains intentional exports. Cache
eviction/reconciliation may delete only cache-owned generation/head rows and
generated cache/staging/cover files. It cannot delete server/configuration,
snapshot, checkpoint, outbox, whole-database or unrelated rows/files. S4 must
keep this namespace ownership testable in its migrations and eviction tests.

## Content-change semantics and reader-state preservation

`publicationContentChangesProvider(session)` exposes the service stream as a
Riverpod StreamProvider. Subscribe before preparing; events are synchronous
broadcast, scoped to one activation, and are not a durable/replayed log. First
publication emits `{previous: null, next: identity}`; replacement emits full
old/new identities after validated publication and new-head lease acquisition.
Parser/canonical interpretation changes also invalidate derived data. Matching
304 and same-identity 200 refresh emit no change. Cancellation, retired callbacks
and rejected imports emit none. D2a's lower-level `PublicationHeadChange` remains
a digest-only cache notification; S4 consumes the identity-bearing D5 boundary.

S4 must compare its stored identity on every open, even without an event (cold
start, missed stream, missing cache head). Treat revision decreases as possible
server restore, not a monotonic global clock. A content change invalidates old
derived source/layout/proof, and **S4 must re-prove each CFI against the new
content** before using it. Keep unresolvable checkpoints and activity/outbox
events with their original identities; do not delete, silently remap or rewrite
them. HTTP 404 marks unavailable without deleting saved reader state. S3 emits
no position/activity/goals/mutation writes and grants no outbox delivery policy.

## Retained S2 conditional S4 items

The user's 2026-10-23 conditional GO is in
`.trellis/tasks/archive/2026-10/10-22-native-reader-feasibility/feasibility-report.md`,
NC9 (archived evidence remains authoritative).
S4 planning must retain owners and evidence for all seven conditions:

1. Recognized tap/drag/direct admission instrumentation and on-device warm
   admitted-input -> first-motion submission P95 <=16.7 ms before release.
   Keep cold preparation and queue wait separate.
2. Dirty-drag submissions, hold/barrier and frame-demand capture; no unexplained
   >=50 ms device stall, retaining and classifying every candidate.
3. Explain/fix reflow/cold-start RSS growth, review the existing 5% endpoint/
   projected-OLS rule without relabeling failures, >=100 alternating turns,
   retained cap checks, and zero native sample loss in long R06 captures.
4. Real OS background/foreground recovery including a completed proven accepted
   turn after return; motion/cold-preparation interruption evidence stays explicit.
5. Per-section mixed-layout handling and clear explanation/action. The later
   parent fixed-layout expansion includes simple, complex static and mixed fixed
   pages; vertical/RTL capability remains S4-owned. Import success is insufficient.
6. Existing hardening: S3 bounded inflation/file-backed worker prerequisite is
   implemented and host-tested; retain device proof, fixture-free product assets,
   bounded FontRegistry/session policy, known HTML template/noscript gaps,
   reviewed OSAtomic synchronization/CI/device behavior, and warm/prepare
   coalescing under the retained 3+1 surface cap and lifecycle checks.
7. Product stays on FlutterMetalLayer. Alternate CAMetalLayer results remain
   non-product evidence and cannot establish physical presentation/touch-to-photon.

## Evidence still owed on iPhone

S3 product entry build/install under the existing identity/free signing route;
real LAN grant, deny, re-enable and retry; real root/prefixed HTTP(S)/proxy access
where available; covers and complete preparation; transient failure and session
switch; relaunch and same-identity update retention. Reconfirm SQLite packaging,
Support storage/migrations and future-schema refusal in the product build (the
early SQLite probe gate is separate prior evidence).

Near-limit synthetic preparation + section preload + decode/layout needs measured
peak memory and no OS memory termination. Repeated cancel/retire/reopen and actual
background/foreground cleanup, resource/font bounds and all seven S2 device
conditions remain open. Host fake HTTP/SQLite/worker tests and Windows memory
probes do not close these gates. Keep private device/NAS/books/captures ignored
under `local-evidence/s3/`; publish only redacted counts and synthetic descriptions.
