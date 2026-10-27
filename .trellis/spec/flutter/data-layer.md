---
name: flutter-data-layer
description: freezed models, json_serializable config, Dio repositories, environment config
paths:
  - lib/features/*/data/**
  - lib/core/network/**
  - lib/core/config/**
  - build.yaml
  - config/**
---

# Data Layer

> Data comes from a remote HTTP API. `dio` does the transport, `freezed` +
> `json_serializable` define models, one repository per feature exposes typed methods.

---

## Models

One model per file in `features/<feature>/data/models/`. Always freezed,
always immutable.

```dart
// lib/features/bookmarks/data/models/bookmark.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bookmark.freezed.dart';
part 'bookmark.g.dart';

@freezed
abstract class Bookmark with _$Bookmark {
  const factory Bookmark({
    required String id,
    required String title,
    required Uri url,
    required DateTime createdAt,
    String? note,
  }) = _Bookmark;

  factory Bookmark.fromJson(Map<String, Object?> json) =>
      _$BookmarkFromJson(json);
}
```

- Data classes use `abstract class`; unions use `sealed class` with named
  factory constructors (freezed 3+ syntax).
- JSON maps are `Map<String, Object?>`, never `Map<String, dynamic>`.
- Use real types: `Uri`, `DateTime`, enums (with `@JsonValue` for wire names),
  not raw strings.
- `DateTime` values are kept in UTC; convert with `.toLocal()` only for display.
- The API model is the app model. Add a separate UI model only when the
  screen needs a shape the API does not provide.

`build.yaml` (project root) sets json_serializable options once for all models:

```yaml
targets:
  $default:
    builders:
      json_serializable:
        options:
          checked: true          # bad JSON -> CheckedFromJsonException
          explicit_to_json: true # nested models serialize correctly
```

S3 checked DTOs preserve the pinned contract's mixed wire names and envelopes;
never apply a global `field_rename`. SnapshotBook is distinct from full Book.
All declared wire fields, including nullable ones, use `@JsonKey(required: true)`
and a required constructor argument. `required T?` alone does not check JSON
key presence. Never supply a default for a missing nullable wire field.
Unknown additive keys are ignored, including inside nested records/unions.

Use `@ServerTimestampConverter()` on timestamp-bearing DTO constructors.
`ServerTimestamp` is a handwritten immutable converter value with `raw: String`
and `utc: DateTime`; it is not an HTTP DTO. SQLite `YYYY-MM-DD HH:mm:ss` with
optional `.` plus 1–9 fractional digits is UTC. The pinned
`server/src/routes/reading.ts:208` uses SQLite `%f` (three digits) for
SnapshotBook.readingUpdatedAt and recent[].progress.updatedAt, while book/folder
timestamps use second-only CURRENT_TIMESTAMP. Space or `T` forms carrying `Z`
or an explicit `+/-HH:mm` offset accept the same optional fractions. Offset-free
`T`, empty/over-nine-digit fractions, letters and out-of-range fields fail with
`LibraryDecodeException(LibraryInvariant.timestamp)`. Keep the first six
fractional digits, padding shorter fractions to microseconds; discard further
digits without rounding into another second. For example, `.999999999` becomes
999999 microseconds within that second. Compare `.utc` for chronological order,
retaining `.raw` for exact wire comparisons and unchanged serialization; never
use device-local parsing or serialize normalized UTC over the raw value.
Regression tests must cover 1–9 digits, raw/UTC/offset equivalence, second
boundaries and malformed inputs, plus mixed second-only/`.SSS` snapshots through
`LibrarySnapshotValidator` / `CachedLibrarySnapshot` validation and restore.

Numeric `fromJson` functions validate before converting to `int`: IDs are in
`1..9007199254740991`; versions, sizes and counts are nonnegative safe integers;
sort orders and chapter indices are signed safe integers. Progress is finite
in `[0,1]`, retaining null separately from zero. Converting a JSON number with
`toInt()` before validation would silently truncate fractional input.

---

## Repository

One repository per feature: a plain class taking `SessionTransport`, plus its
generated session-keyed keep-alive provider in the same file.

```dart
// Session-scoped dependency; DTO decoding remains feature-owned.
part 'book_repository.g.dart';

@Riverpod(keepAlive: true)
BookRepository bookRepository(Ref ref, ServerSession session) =>
    BookRepository(ref.watch(sessionTransportProvider(session)),
      ref.watch(sessionPublicationGuardProvider)); // also register dispose
```

Rules:

- Every public method wraps its body in `guardDio` (`core/network/guard_dio.dart`),
  so recoverable failures are `AppException` subtypes. Cancellation is a separate
  `RequestCancelled` control-flow exception, consumed by its lifecycle owner.
- Methods return models or `void`, never `Response`, `Map`, or `dynamic`.
- Product requests use
  `ServerEndpoint.api(['api', ...])` and the session transport; leading-slash
  origin-relative URLs discard deployment prefixes and are forbidden.
- Cover query strings are preserved by `ServerEndpoint.cover`, never rebuilt
  with string interpolation. B1b's JSON routes do not need query parameters.
- Provider state is the in-memory view; durable S3 configuration and snapshots
  use `SqliteStore` below. B1a/B1b own identities and transport. The hosted
  iPhone SQLite gate passed on 2026-10-26; B2's product store is host-tested.

## Typed snapshot and detail boundary

### Scope / Trigger

Before candidate activation, decode and validate the complete snapshot in
`features/library/data`; storage remains unaware of DTOs. The C2 cache and
cover contracts below extend this checked DTO/index boundary.

### Signatures

```dart
LibrarySnapshot decodeSnapshot(Object? body); // reads {snapshot: ...}
LibraryIndex LibraryIndex.fromSnapshot(LibrarySnapshot snapshot);
Future<BookDetailResult> BookRepository.fetchBook(BookKey key);
Future<ValidatedSnapshot> LibrarySnapshotValidator.validate(SessionTransport transport);
```

### Contracts

- DTO `fromJson` remains checked/generated. `decodeLibraryValue` unwraps checked
  exceptions into content-free `LibraryDecodeException(invariant)` without
  retaining JSON maps/causes. `schemaVersion != 1` is incompatible; missing or
  wrong-type schema fields are malformed. Index failure names are fixed enums.
- Index maps use separate book/folder namespaces; all maps/lists are immutable.
  Folder IDs and book IDs are independently unique. Membership must resolve,
  match each Book's folderId, and occur exactly once. Count equals list length;
  preview equals the first four ordered IDs (sortOrder, then ID).
- Shelf references resolve by sealed kind; each root Book and Folder appears
  once, contained Books never appear. Entity/ref sortOrder agrees; order follows
  sortOrder, kind (`book` before `folder`), then ID. Recent outer/inner book IDs
  agree and resolve; recent IDs are unique. Chapter count/index is either both
  null or a positive safe count and an index in `[-1,count)`.
- Detail takes a server-scoped BookKey, rejects foreign keys before traffic,
  checks response ID equality and reads `{book: ...}`. 404 returns
  `BookDetailResult.unavailable(key)`; malformed DTOs become sanitized
  `ParseException`, other HTTP/cancellation classifications propagate.
- `candidateSnapshotValidatorProvider` binds `LibrarySnapshotValidator` by
  default and remains overridable. Validation performs one unconditional GET,
  accepts only 200, validates DTOs/joins before producing a validated value,
  preserves the single opaque ETag value, and uses body version as revision.
  Present X-Library-Revision must be one unsigned decimal integer matching it.
  Fetched-at is UTC, injectable with `LibrarySnapshotValidator(now: ...)`.
- The validator persists `response.rawJsonText` unchanged after validation.
  Do not re-encode JSON: whitespace, escapes and numeric notation belong to the
  original representation. Exact payload, ETag and revision are persisted together.

### Validation & Error Matrix

| Input | Result |
| --- | --- |
| Null progress / numeric zero / fractional progress | Three distinct valid states |
| Missing nullable key / invalid type or number / invalid join | Named malformed `LibraryDecodeException` at decode/index boundary |
| Unknown integer schema version | Incompatible `LibraryDecodeException` |
| Candidate decode/index/header failure | `SnapshotValidationException(incompatible or malformed)`, no commit |
| Candidate unsolicited 304 / unauthorized / cancellation | Existing transport failure/control flow; no retry |
| Detail 404 | Typed unavailable result; no local deletion |

### Good / Base / Bad Cases

Base: empty snapshot revision zero is valid without an ETag. Good: book 7 and
folder 7 are distinct shelf records. Bad: a folder preview refers to a root Book
or missing member; reject rather than drop the reference.

### Tests Required

Every snapshot/detail fixture, named rejection invariants, missing vs null,
null/zero/fraction, nested additive keys, immutable ordered joins, timestamp
raw/UTC equivalence, header mismatch, detail 200/404, session identity rejection,
and real production validator plus fake HTTP and real temporary SQLite activation.
Assert exact payload string and UTF-8 byte equality with each valid fixture;
include non-ASCII text, escapes, fractional/exponent notation and final newlines.

### Wrong vs Correct

Wrong: `required double? readingProgress` alone accepts missing JSON keys.
Correct: add `@JsonKey(required: true, fromJson: nullableProgress)`.
Wrong: `DateTime.parse(sqliteText)` uses device-local time. Correct: the explicit
converter assigns UTC and keeps the wire string for serialization/comparisons.
Wrong: `jsonEncode(response.body)` to persist a snapshot. Correct: validate the
decoded body, then persist the original `response.rawJsonText` from that response.

---

## Snapshot cache, conditional refresh and covers

### Scope / Trigger

After activation, consume the complete library through a session-keyed
LibrarySnapshotRepository and LibrarySnapshotController. Covers require Flutter
decode/resource ownership and live under `library/presentation/covers`, outside
pure DTO/storage code. D2b adds removable cover persistence below; no product
screen is provided here.

### Signatures

```dart
Future<void> LibrarySnapshotRepository.load(); // restores and refreshes
Future<void> LibrarySnapshotRepository.refresh(); // coalesces pending work
LibrarySnapshotState get state;
Stream<LibrarySnapshotState> get changes;
CachedLibrarySnapshot? CachedLibrarySnapshot.restore(StoredSnapshot? stored);
CachedLibrarySnapshot.fromResponse(TransportResponse<Object?> response, DateTime at);
Future<StoredSnapshot?> LibrarySnapshotCache.read(ServerKey key);
Future<void> LibrarySnapshotCache.replace(ServerKey key, StoredSnapshot value,
    {required void Function() checkActive});
Future<BookDetailResult?> bookDetail(Ref ref, ServerSession session, BookKey key);
Future<CoverLoadResult> CoverLoader.load(String? serverCoverPath, {int? maxWidth});
SessionCoverImage(CoverLoader loader, String? serverCoverPath, {int? maxWidth});
void CoverLease.release();
```

Cache values, state, session scopes and leases are handwritten infrastructure
values, not wire DTOs. HTTP DTOs retain checked generated decoding.

### Contracts

- Restore uses the captured ServerKey. Decode payload/schema and validate the
  entire index again; stored schema and revision must match the payload. Missing,
  corrupt, incompatible or metadata-mismatched cache is unusable. Usable data is
  published immediately with `stale: true, refreshing: true` before HTTP finishes.
- Send only the exact stored opaque ETag for a usable same-server snapshot.
  Candidate validation and refresh 200 share CachedLibrarySnapshot validation:
  DTO, joins, single ETag, matching unsigned X-Library-Revision when present,
  exact raw text and UTC fetched-at. Never re-encode raw JSON or compare revisions
  across activations; a lower revision after reactivation is valid.
- 200 replaces payload, schema, ETag, revision and fetched-at together through
  SqliteStore.replaceSnapshot's transaction. The cache adapter checks session
  ownership after resolving the store and immediately before command dispatch.
  Publish fresh data only after that transaction succeeds and the guard passes.
- On 304 re-read/revalidate durable cache. Reuse only when the original request
  had an ETag and the reloaded payload/ETag still match that request's cache.
  Missing/corrupt/incompatible/changed cache, including loss during HTTP, causes
  exactly one unconditional recovery fetch. Another 304 is the content-free
  LibrarySnapshotProtocolException; do not recursively retry 304.
- A 200 without an ETag is valid, replaces any previous ETag with null, and
  cannot enable conditional reuse. Revision alone never enables it. A reused
  304 marks the data fresh without rewriting its original fetched-at.
- Failures accompany retained data as `LibrarySnapshotState.error`, with
  `stale: true` and `refreshing: false`; they never mutate server selection.
  Only HTTP NetworkException uses retryNetworkErrors (200/400/800 ms, three
  retries). Cache reads/writes, parse/schema/header/HTTP/TLS/protocol failures
  are not retried. Riverpod does not retry a successful state containing error.
- LibrarySessionScope captures the whole session, races unfinished operations
  with retirement, removes completed waiters, and checks before results/writes.
  Cancellation is silent. Snapshot stream publication checks the guard; disposal
  cancels immediately and closes the synchronous stream in a microtask, since
  a listener may dispose its owner during event delivery.
- BookRepository itself uses a required publication guard, checks before reads
  and after HTTP, and disposes its scope. The UI-facing bookDetail provider adds
  per-view cancellation; null is silent cancellation, distinct from typed 404.
- Covers accept only the snapshot's server cover field. Resolve with
  ServerEndpoint.cover; retain deployment prefix, encoded path and query. Never
  derive requests from storage coverPath, fileName, filesystem paths or
  Image.network. A missing/invalid cover becomes a typed placeholder.
- CoverLoader uses bounded SessionTransport.getBytes with an **8 MiB inclusive**
  individual ceiling and a **16 MiB encoded LRU**. Validate actual image decoding
  before admitting bytes; HTML/random bytes never enter either cache. The
  `_readEncoded` remains the bounded network source; D2b checks the shared disk
  sub-budget before that source. Disk writes follow successful image decoding.
- The decoded LRU has **128 MiB**, accounting RGBA pixels and reservations
  before decoding. Read dimensions with ImageDescriptor and, before
  instantiating the codec, downsample to `maxWidth` physical pixels (never
  upscale; proportional height) and to at most **16 MiB** of pixels per cover.
  Keep only the first frame and dispose the codec/descriptor/buffer. Active
  CoverLeases pin entries; evict oldest unpinned entries only. If
  pinned/reserved bytes prevent admission, return cacheBusy.
- BookCover passes `ceil(width * devicePixelRatio)` as `maxWidth` and picks
  `coverThumbnailUrl` (lan-reader's 384 px WebP) when that width is at most
  384, otherwise `coverThumbnail2xUrl` (768 px), then the other thumbnail, then
  `coverUrl`.
- Both memory cache keys include ServerSession (ServerKey + generation) and path;
  the decoded key also includes `maxWidth`, so one download can back several
  display sizes. SessionCoverImage's key includes `maxWidth` and it uses this
  loader's LRU directly, bypassing global ImageCache whose live images are
  outside its byte quota. Use the provider directly; the loader owns pixel
  sizing. The image stream clones a display handle, retains
  its lease until onDisposed (no listeners or keep-alive handles remain), and
  releases unused late results. TickerMode's handle still pins pixels.
- `onRetire` clears encoded/decoded maps, pending lookup state and owned image
  handles. Native decode completions dispose their resources without caching
  or publishing into a retired session. Provider disposal performs the same
  cleanup. Typed CoverImageException is for Image.errorBuilder's placeholder;
  cancelled sessions emit no image error, image or automatic retry.

### Validation & Error Matrix

| Evidence | Result |
| --- | --- |
| Usable cache, HTTP unfinished | Immediate stale data |
| Valid 200, transaction succeeds | Persist then fresh publication |
| Matching conditional 304, reloaded usable cache | Fresh reuse, no write |
| Unusable/lost/changed cache + 304 | One unconditional request |
| Recovery request also 304 | LibrarySnapshotProtocolException, stale data retained |
| No-validator 200 | Valid fresh data; next request is unconditional |
| Refresh/storage failure | Retained stale data + typed error; selection unchanged |
| Cover actual bytes >8 MiB | CoverFailure.oversized, upstream aborted |
| Non-image / unsafe cover path / missing cover | nonImage / invalidPath / missing placeholder |
| Cover pixels blocked by pinned entries | cacheBusy, no over-budget admission |
| Cover transport/TLS/status failure | network / unavailable placeholder |
| Session retired/disposed | Silent cancellation; reject late results |

### Good / Base / Bad Cases

Base: restore stale -> conditional 304 -> same data fresh. Good: a cache removed
during HTTP recovers with one unconditional 200; first A's late results cannot
affect B or later A, even when later A has a lower revision. Bad: recursively
fetch after every 304, send a revision as an ETag, or admit non-image bytes.

### Tests Required

Fixture-driven 200/304 cycles and all unusable-cache kinds, no-validator data,
cache loss/change during HTTP, exact validators/raw payload, stale on reopen and
network failure, bounded retry counts/delays, persistence failure and real SQLite
reopen/selection preservation. Test synchronous listener retirement/disposal,
late A -> B -> A success/error, and repository/provider detail cancellation.
Cover tests assert actual encoded boundaries/upstream abort, invalid images,
downsampled pixels/reservations, LRU ordering, pinning/cacheBusy, same-path
coalescing, session key/generation isolation, cleanup and Image.errorBuilder.
They also assert display-width decode per `maxWidth` over one download, the
per-cover pixel ceiling, BookCover's thumbnail choice, and that the default
budgets keep 30 concurrent 768 px covers loaded at list width.
`test/s3_get_only_inventory_test.dart` pins the five route templates, rejects
list/catalog/folders/reading/goals/statistics/writes, drives all network owners
through a recording adapter, and scans every lib Dart file for Dio write methods,
generic requests, non-GET options and independent Image.network calls. An owner
inventory makes a newly added transport caller require coverage.

### Wrong vs Correct

Wrong: reuse in-memory data after 304 without re-reading durable cache. Correct:
validate that cache again and allow at most one unconditional recovery.
Wrong: a `whenComplete` callback returns `_pending.remove(key)` when the value
is that same pending Future; it waits on itself. Correct: remove inside a void
block and test coalesced completion. Wrong: treat global ImageCache's keep-alive
quota as a bound on live covers. Correct: account pinned decoded leases too.
Wrong: decode covers at source width and size the LRU with 1×1 test images;
on a device, 768 px thumbnails pinned by visible rows fit only four at a time
and the rest stayed cacheBusy. Correct: decode at the displayed width and test
with real thumbnail dimensions.

## Removable cover disk cache (D2b)

### Scope / Trigger

`features/library/data/covers/cover_disk_store.dart` maps validated server cover
paths and session ownership onto `core/storage/cache_budget.dart`'s disk
sub-budget. Flutter decoding stays in presentation. Publication reconciliation
configures the shared admission queue and reconciles covers before returning.
The loader provider lazily resolves that cache; a storage-open failure falls
back to memory/network without failing the image.

### Signatures

```dart
CoverDiskStore.fromBudget(CacheBudget budget);
Future<Uint8List?> CoverDiskStore.read(LibrarySessionScope scope, String path);
Future<bool> CoverDiskStore.write(LibrarySessionScope scope, String path, Uint8List bytes);
Future<void> CoverDiskStore.invalidate(LibrarySessionScope scope, String path);
Future<void> CoverDiskStore.reconcile();
CacheDiskSubBudget? CacheBudget.subBudget(String name);
CacheDiskSubBudget CacheBudget.configureSubBudget(String name, {
  required AppDirectories directories, required int limit, required int individualLimit,
  required Future<CacheReservation?> Function(int) reserve,
  required Future<T> Function<T>(Future<T> Function()) serialize,
});
Future<void> CacheDiskSubBudget.reconcileInQueue(); // owner already holds queue
```

### Contracts

- Files live only under `<Caches>/shiori/v1/covers/<server SHA-256>/
  <SHA-256 of UTF-8 deployment-relative cover path including query>.cache`.
  ServerEndpoint.cover validates paths before hashing. No titles, filenames,
  supplied path components or origins authorize filesystem I/O. Temp files use
  exclusive random 128-bit `.part` names in the same generated server directory.
  Flush/close their encoded bytes, then rename atomically on that filesystem.
- Disk covers share a **16 MiB** encoded sub-budget across all servers, inside
  the shared **512 MiB** cap. Individual files are **8 MiB inclusive**. Existing
  memory encoded/decoded budgets remain 16 MiB each; decoded leases still pin.
  The byte counts are accounting bounds, not device/process-RSS measurements.
- Every cover read/write/eviction shares publication admission's serial queue.
  The cover callback measures publication bytes and uses budget.fits/reserve
  directly; it never calls publication `_reserve` or `reserveBytes`. Evict only
  the oldest cover files until the sub-budget/shared reservation fits. If it
  still cannot fit, skip persistence and return the successfully decoded image.
- Charge encoded bytes before creating/writing a temp, and retain the charge
  for the full persisted lifetime. Release only after deletion or confirmed
  absence. Failed cleanup retains its charge and counts toward the sub-budget
  until reconciliation removes it. Budget-owned sub-budget state survives
  publication service invalidation, rebinding its queue/admission callbacks.
- Loader order is decoded/encoded memory -> disk -> session transport GET.
  Read only regular, registered files whose length matches their charge and
  stays within both limits; also bound actual streamed bytes before accumulation.
  Invalid lengths/unregistered external files are removed. Decode disk bytes
  through the same native image path; nonImage deletes the file and performs
  one network fetch. Validate successful network decode before write-through.
  Disk failures are best effort and do not hide a successfully fetched image.
- Disk LRU follows writes/reads, retaining map order in-process and modification
  times across restart, with stable path ties. Memory hits need no disk access.
  Startup removes stray regular files/temps and invalid lengths only below this
  exact root and its generated server directories. Follow no directory/file
  links; never visit publication, staging, Documents or durable storage here.
  Enforce the cover sub-budget and register retained charges before publication
  admission. If shared capacity is insufficient, discard covers, preserving books.
- All results/writes check the captured full session. Retirement/disposal clears
  memory and cancels pending admissions/writes, preserving completed disk files
  in their server namespace. Own in-flight files are deleted and reservations
  released after outstanding filesystem I/O finishes. The controllable
  beforeRename test boundary races retirement, without leaving a temp/charge.
  Late callbacks cannot publish into a later activation of the same server.

### Validation & Error Matrix

| Condition | Result |
| --- | --- |
| Valid disk hit | Decode and lease; zero network requests |
| Missing/invalid-length/unregistered disk file | Miss; remove invalid bytes and fetch |
| Disk bytes cannot decode | Delete, one network fetch; persist only valid replacement |
| Cover/shared capacity unavailable | Skip persistence; decoded image succeeds |
| Disk write/rename/open failure | Best-effort memory/network; own temp cleanup |
| Session retired during write | Silent cancellation; clean own files/charge after I/O |
| Restart or provider replacement | Restore/preserve charges before admitting books |

### Good / Base / Bad Cases

Base: first network decode persists; a cold loader reuses disk without HTTP.
Good: A -> B -> A reuses A's disk namespace while rejecting late first-A work.
Bad: a cover write evicts an unleased publication, or releases its reservation
immediately after rename and admits more than the shared disk cap.

### Tests Required

Use temporary Caches and the real SQLite/publication owner. Assert cold disk hit
without HTTP, decode-corruption replacement, cross-server same-path separation,
sub-budget read-touch LRU, startup temp/length cleanup and sibling sentinels,
shared pressure preserving unleased publication bytes/heads, startup charges
blocking publication admission, provider invalidation retaining charges,
retirement at beforeRename removing the temp/reservation, successful images on
storage failure, memory priority, invalid network images never persisted, and
the existing GET-only network inventory. Existing pixel/lease/session tests pass.

### Wrong vs Correct

Wrong: call reserveBytes for covers, allowing publication eviction, or nest the
public reconcile method while already holding the shared admission queue.
Correct: configure the non-evicting callback and call reconcileInQueue from
publication startup; ordinary cover operations enter that same queue once.

## Bounded publication downloads and staging (D1)

### Scope / Trigger

Original EPUB transfers live in `features/library/data/publications/`. D1 ends
at transfer-verified private staging bytes or a reverified local generation.
It does not validate the EPUB package, publish a cache head, mutate SQLite or
claim reader readiness. The caller pins its existing immutable generation for
the attempt; D2 owns cache publication and retained-cache quota integration.

### Signatures

```dart
Future<TransportResponse<T?>> SessionTransport.getFile<T>(int bookId, {
  required int maxBytes,
  required Future<T> Function(Stream<Uint8List>) consume,
  String? ifNoneMatch, String? ifModifiedSince, CancelToken? cancelToken,
});
Future<DownloadResult> PublicationDownloadService.download(BookKey key, {
  LocalPublication? local, bool refresh = false, CancelToken? cancelToken,
  PublicationRecoveryAllowance? recoveryAllowance,
  Future<void> Function()? onUnusableLocal,
});
void PublicationRecoveryAllowance.recover(int status); // second call throws ServerException
Future<void> PublicationStaging.cleanupAbandoned();
Future<void> StagingFile.discard();
void StagingFile.releaseAfterMove();
publicationDownloadServiceProvider(ServerSession session); // keep-alive family
publicationStagingProvider; // shared keep-alive transfer gate / reservation
```

`LocalPublication` carries BookKey, immutable path, expected byteLength, lowercase
SHA-256 digest, nullable opaque etag/lastModified. `StagedDownload` carries BookKey,
owned StagingFile/path, actual byteLength/digest and nullable response validators.
`DownloadNotModified.local` is the reverified input generation. These are
handwritten infrastructure values, not HTTP DTOs.

### Contracts

- The session transport alone constructs Dio. `getFile` accepts only the safe
  file GET route, retaining deployment prefix, redirect policy and error mapping.
  It sends exact If-None-Match preferentially, otherwise If-Modified-Since. It
  never sends Range or If-Range. A 304 is admitted only if a condition was sent;
  its body is discarded. Other statuses remain typed HTTP failures.
- `StreamingFileBody` detaches a 200 source at the adapter boundary and gives Dio
  an empty response stream. Header checks precede the file callback; disk awaits
  propagate pause/resume to the original source. Do not expose the raw stream
  outside the request lifetime, use getBytes for EPUBs, or let Dio prebuffer it.
  An abandoned callback cannot return success without consuming the whole body.
- Require one Content-Type of application/epub+zip or application/octet-stream
  (parameters allowed); reject missing/ambiguous/HTML/JSON/text/other types before
  creating a file. Binary MIME is only a staging admission, never package proof.
  Present Content-Length must be one unsigned decimal within the limit. Count
  actual bytes before each write regardless of that header; reject mismatch at
  EOF, including truncated or understated bodies. The inclusive default limit is
  `const EpubLimits().maxArchiveBytes` (256 MiB), injectable downward in tests.
- The callback writes sequentially through an asynchronous RandomAccessFile,
  hashes each written chunk with crypto SHA-256, flushes and closes before
  returning. There is no whole-file buffer or second file read for download
  hashing. Staging uses exclusive creation of a secure random 128-bit `.part`
  name under `<Caches>/shiori/v1/staging/`; no supplied title/filename/path is used.
  Before creation, listing, open, discard or publication rename, probe every
  generated ancestor (`shiori`, `v1`, `staging`) with `followLinks: false`.
  Probe paths without a trailing separator (Windows otherwise follows links).
  Create missing ancestors one at a time; a link or non-directory is a typed
  DownloadException(storage). Also reject linked staging files before open/move/delete.
- Only a usable same-book local generation enables conditions. Check expected
  digest shape, existence and length before HTTP and again after 304. Rehash
  generations up to 8 MiB using a file stream both times; larger files rely on
  prior caller verification and its immutable-generation pin plus current length.
  Explicit refresh bypasses both validators. Missing validators on 200 are valid
  and return null, clearing any implication of previous validators.
- An unusable 304 or unexpected 206/412/416 permits exactly one unconditional
  recovery. This is one shared recovery allowance, including mixed statuses;
  D5 passes the same allowance to every D1 call and consumes it for failed full
  post-304 verification. A second anomaly fails with ServerException(status),
  mapped by preparation to PrepareBookException(server). No third file request.
  D1 awaits onUnusableLocal before recovering an invalid local generation; D5
  binds it to cache.markCorrupt, including small-file post-304 digest failures.
  No recursive or automatic network retries.
- Ordinary duplicates for a BookKey share the same Future/result. Refresh
  cancels/supersedes that book's older operation. Per-call cancellation cancels
  the shared attempt, including its coalesced consumers. Session retirement and
  provider disposal synchronously cancel pending operations. Check full session
  ownership and per-book operation generation before traffic, writes and results;
  await close and own-file deletion before releasing the transfer gate.
- Shared PublicationStaging serializes transfers across books/sessions and
  reserves at most one compressed staging file. Success transfers ownership to
  the caller and retains the reservation. D2 must move/delete it before calling
  releaseAfterMove, or call discard on abandonment. A retained staged result
  causes stagingBusy for another file; it is never evicted implicitly.
- Failures/cancellation delete only their own .part, preserving existing local
  generations. A failed deletion reports storage and retains its reservation.
  Call cleanupAbandoned at startup before admitting downloads: only immediate
  regular `.part` files in the exact staging directory are deleted, excluding
  live owned paths. Never recurse, follow links, scan Documents or touch other
  cache/durable files. Late headers after cancellation also close their source.

### Validation & Error Matrix

| Condition | Result |
| --- | --- |
| Full bounded 200, including no validators | StagedDownload; closed/flushed .part |
| Conditional 304 with still-usable generation | DownloadNotModified |
| Unsolicited/unusable 304, 206/412/416 | One unconditional recovery; then ServerException(status) |
| Other HTTP / TLS / transport receive error | Existing typed transport failure; no protocol recovery |
| MIME/length/actual overflow/incomplete consumption | ParseException; own .part removed |
| Disk create/write/flush/close/delete failure | DownloadException(storage) |
| Duplicate validator header values | DownloadException(invalidValidators) |
| Staging reservation already retained | DownloadException(stagingBusy) |
| Cancellation, supersession, retired session | RequestCancelled; no retry |
| Foreign BookKey/local generation | ArgumentError before traffic |

### Good / Base / Bad Cases

Base: chunked 200 hashes to the fixture digest without Content-Length. Good:
file disappears during conditional HTTP, so 304 causes one unconditional 200.
Bad: an HTML login 200, range fragment or truncated response becomes a complete
book; none may escape as a successful staged generation.

### Tests Required

Use real SessionTransport plus chunked fake adapters and temporary Caches.
Assert exact validators, GET/no Range, inclusive actual limits, lying lengths,
source backpressure/abort, SHA-256, flush/close and own-file cleanup. Exercise
304 loss/length/digest corruption, one recovery across status combinations,
no-validator 200, disk fault injection, duplicate coalescing, refresh ordering,
retirement before headers/during body/at close, reactivation, shared reservation
and nonrecursive startup cleanup. The GET inventory drives the actual download
provider and rejects every Dio construction outside session_transport.dart.

### Wrong vs Correct

Wrong: return Dio's already-subscribed response stream, trust Content-Length,
or hash `readAsBytes()` afterward. Correct: detach the raw source before Dio,
count before each disk write and hash those same chunks incrementally.
Wrong: cancel an unstarted StreamIterator to close a rejected source (it never
subscribes). Correct: explicitly subscribe-and-cancel the discarded source.

## Immutable publication cache (D2a)

### Scope / Trigger

`features/library/data/publications/publication_cache.dart` owns publication
files and their committed heads. Its generated keep-alive provider is shared
across server sessions. Await it before preparation: opening automatically
reconciles publications and calls D1's staging cleanup. Package/source validation
belongs to the worker/orchestrator; this cache accepts an already validated
StagedDownload and rehashes its closed bytes before publication.

### Signatures

```dart
Future<PublicationAttempt> beginPreparation(ServerSession session, BookKey key);
Future<StoredPublication> publish(PublicationAttempt attempt, StagedDownload staged,
    {required int parserVersion, required int canonicalVersion});
Future<PublicationLease?> acquireHead(ServerSession session, BookKey key);
Future<PublicationLease?> pinHead(BookKey key);
Future<void> markCorrupt(PublicationLease lease);
Future<CacheReservation> reserveBytes(int bytes);
Future<void> reconcile();
Stream<PublicationHeadChange> get headChanges;
void PublicationAttempt.close();
void PublicationLease.release();
void CacheReservation.release();

// Async commands on the existing SQLite owner/worker; no filesystem in worker.
Future<void> publishGeneration(StoredPublication value);
Future<StoredPublication?> readPublicationHead(BookKey key);
Future<StoredPublication?> readGeneration(BookKey key, String sha256);
Future<List<StoredPublication>> listPublicationCandidates(
    {Set<String> protectedPaths = const {}});
Future<void> deleteGeneration(BookKey key, String sha256);
Future<void> clearPublicationHead(BookKey key, String sha256);
Future<void> touchGeneration(BookKey key, String sha256, DateTime at);
```

### Contracts

- Files live at `<Caches>/shiori/v1/publications/<server SHA-256>/<safe book ID>/
  <byte SHA-256>.epub`, or `<byte SHA-256>.<32 lowercase hex generation>.epub`
  for a repair while the old path is leased. Components are generated from BookKey/digest; titles,
  filenames, URLs and stored arbitrary relative paths never authorize file I/O.
  The path version stays v1 when the separate SQLite schema becomes v2.
  Detached StoredPublication carries key, sha256, byteLength, parserVersion,
  canonicalVersion, UTC accessedAt and exact nullable etag/lastModified.
  Legacy invalid/zero-length/path-mismatched metadata can be listed for cleanup;
  publishGeneration rejects it. It never follows that row's supplied path.
- Begin preparation before detail/download/worker work. It captures the full
  session, allocates a monotonically increasing operation token and pins the
  previous usable head. Close the attempt in `finally` after success/failure.
  Supersession cancels publication authority but keeps its fallback pin until
  that attempt actually closes. Coalescing ordinary preparations belongs to the
  orchestrator; each new beginPreparation supersedes its book's previous token.
  Use `attempt.previousHead?.local` as D1's conditional-download input.
- Publish only owned staging files for the attempt's BookKey. Check the guard
  and operation token before rename and immediately before DB dispatch. Stream
  SHA-256 and verify actual length; never read the whole archive into memory.
  Reserve quota, then rename within Caches before issuing the SQLite command.
  A present same-digest destination must pass full length/digest verification;
  reuse it and discard staging without overwriting it, including on Windows.
  Full verification failure records the corrupt physical path in container
  state and removes its matching metadata/head under the serialized cache owner.
  New leases cannot acquire it. Never repair an open generation in place: while
  any pin/lease holds that path, publish the verified stage under its secure
  random 128-bit generation suffix and atomically upsert the same digest's row.
  Persist that strictly validated suffix in the existing relative_path column;
  no schema change or arbitrary stored path is accepted. If unleased, delete
  the corrupt destination before republishing. Physical repair preserves content
  identity and emits no preparation ContentChange when bytes/versions match.
- publishGeneration atomically upserts validated metadata and changes the head
  with bound SQL, preserving old generation rows. A failed COMMIT rolls both
  changes back. Consumers acquire through the serialized cache only after commit.
  A dispatched SQLite transaction finishes even if retirement/supersession races
  its reply; it writes only the captured server/book. A final guard/token check
  suppresses stale return/events without compensation writes. Emit
  PublicationHeadChange(key, previousDigest, newDigest) only on a new digest,
  including null -> first digest. Later integration maps this to ContentChange.
- Failure before rename discards only that attempt's stage, including queued
  calls rejected by disposal. After rename/before commit, leave the unreferenced
  destination for reconciliation; commit failure keeps the old head. A crash
  after commit leaves the new head verifiable. Never undo a successful commit
  because the caller was retired while awaiting its reply.
- Leases/pins are counted in memory by generated generation path. Acquire checks
  head file length/existence and touches its LRU time. Replacement keeps old
  bytes readable while any lease/pin remains. Release is idempotent; the last
  release makes a non-head generation eligible for later eviction. Closing an
  attempt releases its fallback pin; valid generations remain eligible for LRU.
  Private container state retains pins, reservations and the serial queue across
  cache provider invalidation. Direct open callers must maintain one owner.
  Detected-corrupt paths remain readable through existing leases until release;
  last release queues serialized cleanup. Failed deletion keeps the corruption
  record and its measured disk bytes; explicit reconcile reports storage and retries.
  A late report for an old path must not delete a repaired same-digest row.
- CacheBudget defaults to **512 MiB** across all server namespaces. Admission
  charges actual regular files under publications, including crash orphans,
  plus outstanding reservations. D1's one **256 MiB** staging allowance stays
  separate. Preflight enough reclaimable bytes, then evict unleased/unpinned
  rows in global accessedAt order (stable server/book/digest ties). A current
  head is evictable when unprotected; delete its matching head and generation
  row together, then delete its file. DB failure preserves the file; deletion
  failure leaves an orphan and a typed storage error. Same-digest reuse needs
  zero extra bytes. Never evict the attempt's fallback or destination being reused.
- D2b covers use a non-evicting shared reservation callback configured during
  reconciliation, not reserveBytes (which may evict publications). Hold their
  reservations until deletion; restore their charges before publication admission.
  The sub-budget and external reservations survive service invalidation within
  the container. See the cover disk contract below.
- Reconcile each record against validation/path metadata and file existence/
  length. Startup intentionally omits full digest hashing; same-length external
  corruption is detected by later digest verification, not promised at startup.
  Clear missing/mismatched heads and generation rows so preparation downloads
  again. Remove unreferenced regular files only below publications, excluding
  live protected paths. Never follow links or delete directory trees. A removed
  publications directory is an empty cache and is recreated on later publish.
  Call staging.cleanupAbandoned; it retains live staging ownership. Reconciliation
  runs staging cleanup through its own gate before entering the publication/
  acquisition queue. Never hold the cache queue while waiting for the staging
  gate: a download may await a corruption report on that same cache owner.
  Reconciliation is callable later; metadata/file reconciliation stays serialized.
- Low-level cache commands are for this owner, not direct product consumers:
  pass every protected path when requesting eviction candidates. All cache
  operations affect only cached_publications/book_cache_heads and cache files.
  Never mutate servers, app_state, snapshots, Documents, Application Support
  files or present/future checkpoint/activity tables to recover cache space.

### Validation & Error Matrix

| Condition | Result |
| --- | --- |
| Individual generation/reservation exceeds total limit | PublicationCacheException(tooLarge); recoverable |
| Leases, pins or reservations prevent admission | PublicationCacheException(cacheBusy); live bytes retained |
| Stage hash/length verification fails | PublicationCacheException(invalidGeneration) |
| Existing same-digest file fails full verification | Retire that path; publish verified stage separately if leased, otherwise delete then republish |
| Linked staging ancestor/root/file | DownloadException(storage); no outside file read/write/delete |
| Filesystem, SQLite, staging cleanup or closed-worker failure | PublicationCacheException(storage), content-free |
| Retired session, superseded/closed attempt, disposed service | RequestCancelled; no event/retry |
| Foreign staging owner/book/session or invalid version/digest input | ArgumentError; caller contract violation |
| Missing/length-mismatched/invalid referenced generation | Cache-only metadata removal; acquire returns null |
| Same-length corruption during startup | Retained by documented length-only startup check |

### Good / Base / Bad Cases

Base: validate stage -> reserve -> rename -> generation/head commit -> lease.
Good: leased A remains readable after B replaces its head; release later allows
LRU eviction. Rename-before-commit crash leaves a removable orphan and old head.
Good: unchanged server bytes repair a corrupt cache with the same identity while
an older lease keeps its corrupt physical file readable until release.
Bad: COMMIT failure must never point the head at an uncommitted generation or
delete the old fallback; a same-number book on another server is independent.

### Tests Required

Use temporary Caches plus the real SQLite worker. Assert publish ordering and
events, open-handle same-digest reuse, rename/precommit/actual deferred-FK COMMIT
faults, restart on both sides of commit, token/session retirement, queued disposal
cleanup and provider replacement with live leases/reservations. Cover cross-server
LRU/touch, fallback and explicit pins, multiple leases/last release, inclusive
quota, tooLarge/cacheBusy, orphan charging, cleanup retry, missing/length mismatch,
legacy invalid/path records and outside sentinel files. Compare exact rows in
servers/app_state/snapshots and a future-reader sentinel after cache operations.
Assert linked staging roots/intermediate ancestors are refused with outside .part
sentinels intact; same-length corruption repairs via prepare and reconcile/forced
refresh, with/without user leases, open old handles, cleanup retry, recovery-path
restart, and at most two file requests after small/large post-304 corruption.
Migration tests reconstruct v1, preserve head/durable/sentinel rows, roll back
the added column and version together, and retain future-schema refusal tests.

### Wrong vs Correct

Wrong: update the DB before rename, overwrite an existing digest path, or rebuild
the lease map when a service provider is invalidated. Correct: rename first,
commit the generation/head together, verify/reuse existing bytes and retain
protection in container state. Wrong: release a future cover's charge immediately
after writing; correct: keep it until those outside-subtree bytes are removed.
Wrong: length-only reconcile forgets a previously detected digest failure, or D5
starts a fresh recovery allowance after 304. Correct: retire the physical path
when detection occurs and share the allowance through the complete preparation.

## Dio and Config

### Scope / Trigger

Product requests use a user-selected runtime deployment root, replacing the
compile-time `API_BASE_URL` contract. The legacy `dio_provider.dart` and
`Env.apiBaseUrl` have been removed. There is no product endpoint define.
`Env.buildId`/`Env.buildNumber` remain compile-time build identity flags;
their behavior and the existing probe are unchanged. Public config files hold
placeholders only; no private endpoint belongs in the binary or repository.

### Signatures

```dart
ServerEndpointValidation ServerEndpoint.parse(String input);
String ServerEndpoint.canonicalRoot;
String ServerEndpoint.normalizedText;
Uri ServerEndpoint.api(List<String> segments); // includes the 'api' segment
Uri ServerEndpoint.cover(String serverPath);
ServerKey(ServerEndpoint endpoint); // value + canonicalRoot
BookKey(ServerKey serverKey, int bookId);
ServerSession({required ServerEndpoint endpoint, required int generation});
SessionTransport(ServerSession session, {HttpClientAdapter? adapter});
Future<TransportResponse<Object?>> getJson(List<String> segments, {
  String? ifNoneMatch, String? ifModifiedSince,
  Set<int> allowedTerminalStatuses = const {200},
});
Future<TransportResponse<Uint8List>> getBytes(String serverCoverPath, {
  required int maxBytes,
});
void SessionTransport.dispose();
sessionTransportProvider(ServerSession session); // generated family
Future<Directory> AppDirectories.caches();
```

### Contracts

- These handwritten immutable core values are not HTTP DTOs and need no
  Freezed/JSON/provider dependencies. Parsing is synchronous and has no I/O.
- Trim outer whitespace; require explicit HTTP(S) and a host. Lowercase
  scheme/host, drop default ports, normalize dot segments and end the root in
  one slash. Preserve path case and encoded separators; never decode/re-encode
  a whole path. `normalizedText` equals `canonicalRoot` without display decoding.
- `api(['api', 'books', '7'])` encodes each segment separately under the root.
  `cover('/covers/...?...')` retains the deployment prefix and encoded path/
  query. It accepts only leading-slash covers paths and never origin URLs.
- `ServerKey.value` is lowercase hex SHA-256 of UTF-8 `canonicalRoot`. Retain
  and compare the canonical string too. No DNS/redirect-based identity merge.
  `BookKey` combines that key with an integer in `1..9007199254740991`.
  Both have value equality/hash; equal numeric IDs on different roots differ.
- `caches()` uses `getApplicationCacheDirectory()`, through the existing
  injectable `AppDirectories` provider; it never falls back to Documents.
- Repositories share `sessionTransportProvider(session)` and never create Dio.
  `ServerSession` derives its key from the endpoint; equality/hash also includes
  its positive activation generation. A later A activation differs from old A.
- Each transport owns one private Dio (10 s connect/20 s receive) with automatic
  redirects disabled. Only GET health, snapshot, book detail/file and covers
  are exposed. `ServerRoute.api` validates this inventory before any traffic.
- JSON GET returns `TransportResponse` with status, copied immutable header
  lists/map, decoded body and `rawJsonText: String?`. Every successful JSON 200
  carries the exact UTF-8 decoded text before JSON parsing, preserving whitespace,
  escapes, number spelling and final newlines. This retains the same string used
  by jsonDecode after the existing bounded read; no second response, byte buffer
  or accumulation path is introduced. The optional field defaults to null for
  backwards-compatible construction; 304 and getBytes have null rawJsonText.
  Raw text is private content and must never be logged or displayed.
  DTOs remain feature-owned. Validators pass through exactly.
  Allowed terminal statuses are a per-call copy/subset of `{200,304}`;
  only snapshot/file may opt into 304, which bypasses body decoding. Default
  304 and all unexpected statuses fail. Cache recovery is caller-owned.
- JSON source limits are 64 KiB for health/file JSON and HTTP error envelopes,
  256 KiB for book detail, and 8 MiB for the complete library snapshot. Count
  actual emitted bytes before accumulation, regardless of Content-Length.
  `BoundedResponseAdapter` enforces the limit before Dio's eager subscription
  can buffer the source; `_read` also checks its own accumulation. A successful
  response overflow cancels upstream and throws content-free `ParseException`;
  an oversized HTTP failure retains `ServerException(status)` with no code.
  Validate JSON Content-Type at the adapter boundary before consuming the body;
  missing type still requires valid JSON. Status precedence and 304 are unchanged.
  These are wire-byte ceilings, not decoded-memory/RSS guarantees. Section 7's
  disk/worker budgets do not authorize unbounded JSON on the UI isolate.
- `getBytes` accepts only `endpoint.cover` resources and HTTP 200. It checks
  actual received chunk totals before accumulating, ignoring Content-Length
  as an authority; overflow cancels the remaining response and is a parse failure.
  Image/pixel validation is Phase C. EPUB streaming/digest/file sinks are Phase D;
  reuse the private `_openValidatedResponse` boundary rather than this bytes API.
- Each hop has a session-owned cancel token. `dispose` is idempotent, cancels
  every request/body and force-closes Dio. Checks before dispatch, during reads
  and before returning reject retired work. The keep-alive provider disposes
  its transport on invalidation/container disposal; the next activation owner
  must retire/invalidate old families and guard publication by key/generation.
- Manually follow 301/302/303/307/308 at most five times, retaining GET and
  conditional headers only after same-scheme/host/effective-port and deployment
  prefix validation. Detect repeated normalized targets including query, ignoring
  fragments. Reject userinfo (including empty `@` before URI normalization),
  malformed targets, encoded traversal/backslashes, cross-origin, prefix escape
  and HTTPS downgrade. Location must contain exactly one value. Redirects never
  change identity; failures ask for the
  final deployment root. Error classification/redaction: [Error Handling](./error-handling.md).

### Validation & Error Matrix

| Input / condition | Result |
| --- | --- |
| Valid deployment root | `ServerEndpointValidation.endpoint`, null `issue` |
| Bad scheme/host, userinfo (even empty), query/fragment (even empty), escapes, backslashes, port outside 1..65535 | Null endpoint + content-free `ServerEndpointIssue` |
| Bracketed IPv6 zone ID (`%25...`) | `ipv6ZoneIdentifier`; interface-local identities are not portable |
| URI parser failure | `invalidAddress`; original exception/input is not retained |
| Empty/dot API segment | Content-free `ArgumentError` |
| Absolute/foreign cover URL, traversal (including encoded `..` or separators), fragment, backslash, malformed encoding | Content-free `FormatException`, no source/offset |
| Zero/negative/unsafe integer book ID | Runtime `RangeError` |
| Missing application cache location | `path_provider` failure; callers use the existing local-I/O boundary |
| Nonpositive activation generation | Content-free `ArgumentError` |
| Unsupported S3 route/status opt-in or nonpositive byte limit | Content-free `ArgumentError`, no traffic |
| 304 without opt-in, including every cover/health/detail request | `ServerException(304)` |
| Cross-origin/prefix/downgrade, loop, malformed or sixth redirect | `RedirectException`, no disallowed request |
| Session disposed before headers, during receive or before return | `RequestCancelled`, no retry/error publication |

### Good / Base / Bad Cases

- Base: `https://example.test` -> `https://example.test/`.
- Good: ` HTTPS://EXAMPLE.TEST:443/a/../Reader ` ->
  `https://example.test/Reader/`; encoded `a%2Fb` stays one segment.
- Bad: `https://user@example.test`, `https://example.test/?`,
  `http://[2001:db8::7%25en0]` yield validation issues and cannot produce traffic.
- Good: snapshot `{200,304}` plus exact `If-None-Match` accepts a bodyless 304;
  the caller must prove a usable cached representation before reuse.
- Bad: health `{200,304}` is a caller contract error; covers exceeding their
  emitted-byte limit are canceled without returning partial success.

### Tests Required

`test/core/config/` executes every committed `url_resolution.json` root,
request and rejection, plus canonical round trips/idempotence, IPv6, encoded
prefixes, traversal, key aliases/isolation and book-ID boundaries.
`test/core/storage/app_directories_test.dart` verifies native cache method
wiring and provider overrides with fakes, without actual platform storage.
`test/core/network/` uses fake adapters asserting all 45 fixture request URIs,
GET-only inventory, timeout/redirect settings, exact validators, 304 opt-in,
five-hop/loop/origin/prefix/downgrade matrix, bounded receiving streams, every
Dio error type, whole-log redaction and session-family/disposal isolation.

### Wrong vs Correct

Wrong: `Uri.parse(root).resolve('/covers/a.webp')` loses `/Reader/`.
Correct: `endpoint.cover('/covers/a.webp')` retains `/Reader/covers/a.webp`.
Wrong: `BookKey` based only on `bookId`; correct: compare both server and ID.
Wrong: `Image.network` or a second Dio for covers. Correct: reuse the captured
session transport, enforce byte/pixel bounds and check identity before publishing.

## Private SQLite persistence

### Scope / Trigger

`core/storage/sqlite_store.dart` owns schema/migrations and the product database
at `<Application Support>/shiori/v1/state.db`. Documents is exports only;
Caches is removable bytes only. The diagnostic self-check stays independent.

### Signatures

```dart
Future<SqliteStore> SqliteStore.open(AppDirectories directories,
    {SqliteStoreTestHooks? testHooks});
Future<void> upsertServer(ServerRecord record);
Future<ServerRecord?> readServer(ServerKey key);
Future<ServerRecord?> readActiveServer();
Future<void> setActiveServer(ServerKey? key);
Future<void> commitActivation(ServerRecord record, StoredSnapshot snapshot);
Future<StoredSnapshot?> readSnapshot(ServerKey key);
Future<void> replaceSnapshot(ServerKey key, StoredSnapshot snapshot);
Future<void> touchLastUsed(ServerKey key, DateTime at);
Future<void> close();
sqliteStoreProvider; // generated keep-alive FutureProvider
```

### Contracts

- One long-lived worker owns the connection. Private typed operations/replies
  carry request IDs and detached values; no SQL, handles, statements or callbacks
  cross ports. Every command checks worker/root isolate identity. All reads and
  writes execute serially; write transactions use `BEGIN IMMEDIATE` and bound
  values. Opening, migrations and all SQLite calls run off the root isolate.
- `ServerRecord` carries `ServerKey`, `createdAt`, `lastUsedAt`. Upsert retains
  original creation time. Every namespace lookup compares its stored canonical
  endpoint to `ServerKey.canonicalRoot`; active restore also checks its digest.
- `StoredSnapshot` carries raw `payload`, positive `schemaVersion`, nullable
  opaque `etag`, nonnegative JS-safe `revision`, and `fetchedAt`. Feature DTO code
  validates wire semantics before writing and revalidates cached payloads when
  reading; storage does not interpret JSON. UTC timestamps persist as epoch
  microseconds. Revisions may decrease after server restore.
- Activation commits server metadata, snapshot/validator and active selection
  together. Failure preserves the previous rows. Snapshot replacement never
  changes selection. Nullable reads mean absent records, never swallowed errors.
- `core/storage/sqlite_server_selection_store.dart` implements the five-method
  `ServerSelectionStore` port in core/config without feature imports. The servers
  dependency provider binds it to the scope-owned SQLite provider by default;
  tests may override the port. Its lazy resolver keeps open and command failures
  inside the same typed boundary. It maps server canonical endpoint/timestamps
  and all snapshot fields verbatim (`payload` <-> `payloadText`, schema version,
  opaque nullable ETag, revision, fetched-at), without decoding or re-encoding.
  Commit compares endpoint/key (including canonical text) before dispatching one
  activation transaction. Local creation/last-use values use UTC now; the store
  retains original creation time on reactivation. Touch changes only last-use.
- Schema v1: `servers`, singleton `app_state`, one `library_snapshots` row per
  server, `cached_publications` keyed by server/book/digest, `book_cache_heads`
  keyed by server/book. Cache generation columns include relative path, actual
  bytes, ETag/Last-Modified, parser version, validation status and access time.
  Foreign keys restrict parent deletion and heads to validated generations;
  an access-time index supports cross-server LRU. Schema v2 adds a positive
  `canonical_version` with default 1 through an adjacent v1 -> v2 migration;
  shipped v1 DDL is unchanged. D2a adds cache commands below, without a
  `cache_operations` table.
- Ordered migrations must connect adjacent versions. Each DDL step, metadata
  update and `user_version` bump share one transaction. Verify foreign keys,
  DELETE journal and FULL synchronous settings on open. S4 adds checkpoint/outbox
  tables through explicit migrations owned here; never edit shipped v1 DDL.
- Check schema before persistent settings or writes to the original database.
  WAL mode and retained WAL/rollback journals are inspected using a private
  disposable copy (without copying shared memory); SQLite recovers that copy.
  Ordinary DELETE files use read-only inspection. Refusal preserves original
  database/sidecar bytes and never deletes, resets or renames them. Only the
  disposable inspection directory is cleaned up.
- Scope retains the provider owner between listeners. Invalidation/disposal
  rejects new calls, drains accepted commands, closes SQLite and awaits exit.
  A private scope-local gate waits for the retired worker to exit before a
  replacement opens. Disposal during initialization also closes the owner.
  Explicit callers must await `close()` before reopening the same path.
- Cache eviction may touch only cache-owned rows/files. Never delete
  a server, whole database or future durable reader state to recover cache.

### Validation & Error Matrix

All failures are content-free `StorageException` values with `failure`:

| Condition | Failure |
| --- | --- |
| Newer recovered `user_version` | `newerSchema`, observed `schemaVersion` |
| Directory/native open/corrupt or malformed current schema | `open` |
| Failed migration/check/version step | `migration`, transaction rolled back |
| Stored endpoint/digest mismatch | `canonicalMismatch` |
| Missing server required by write | `invalidRecord` |
| SQL constraint or transaction failure | `command` |
| New call after close/disposal | `closed` |
| Fatal worker error or unannounced exit | `workerExit`, all waiters completed |

These are local storage failures, never retryable `NetworkException`s.
The selection adapter maps `newerSchema` to
`SelectionStorageException(newerSchema)`, `canonicalMismatch`/`invalidRecord`
to `invalidSelection`, and every other storage failure (including open) to
`unavailable`. It retains no driver cause, SQL, path or observed schema version.
Localized recovery presentation remains Phase E.

### Good / Base / Bad Cases

- Base: fresh v0 migrates through v1 to v2 and reopens the committed selection.
- Good: failed B activation retains A plus B's previous snapshot; v0 sentinel
  tables survive migration. Uncommitted future versions in journals roll back.
- Bad: future committed schema returns `newerSchema` with identical original
  bytes; corrupt files return `open`. Neither path resets application state.

### Tests Required

Use real SQLite and temporary `AppDirectories`. Assert migration DDL/version
rollback, unrelated rows, DELETE/WAL/hot-journal refusal byte equality, recovery,
activation atomicity, canonical mismatch, opaque bound strings, cache FK/head
constraints, ordered concurrent commands, off-root checks, close/exit waiters,
provider retention/invalidation and disposal during lookup.
The adapter/activation integration tests verify exact field round trips,
canonical/key mismatch rejection, typed open/command failures, scope-owned
disposal and restart restore without HTTP through the default production binding.

### Wrong vs Correct

Wrong: set `journal_mode=DELETE` before checking a retained future WAL database,
or delete it on error. Correct: inspect recovered private copies, refuse future
schemas without altering originals, and expose typed retry/recovery state.

### Local diagnostic storage

The S1 probe explicitly authorizes local persistence through injectable
`core/storage` directories and diagnostics-feature repositories. These local
repositories handle file/parse errors at their own boundary; `guardDio` applies
to HTTP repositories, not local I/O.

- **Application Support:** marker and last completed/partial diagnostic record.
  Private settings, checkpoints, outbox and caches never belong in Documents.
- **Caches:** removable downloaded/derived data; absence must be recoverable.
  Publication downloads use the task-owned staging directory described above;
  durable cache publication/metadata are a separate step.
- **Documents:** intentional user exports only,
  `shiori-diag-<BUILD_ID>-<runId>.json`. iOS File Sharing exposes this directory
  because `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` are true.
- `Env.buildId` defaults to `local` and is shown in the probe and every export.
  CI injects it through `--dart-define=BUILD_ID=...`; see quality-guidelines.md.
- Resolve directories with `path_provider`; inject directories in repository
  tests so tests use no platform plugin or user directories. Marker retention
  is a feasibility check, not a transactional reading outbox guarantee.

---

## Connected prepare-book orchestration (D5)

### Scope / Trigger

`library/data/publications/PrepareBookService` composes detail, D1 download,
D3 worker import and D2 atomic publication. Its controller lives alongside it
as an orchestration adapter; screens/routes/l10n consume that API separately.
Reader data remains provider-free; session worker wiring is library-owned.

### Signatures

```dart
Future<PreparedBook> PrepareBookService.prepare(BookKey key, {bool refresh = false});
void PrepareBookService.cancel(BookKey key);
Stream<ContentChange> get PrepareBookService.contentChanges;
Stream<({BookKey key, int received, int? total})> get PrepareBookService.progress;
Future<PublicationWorker> SessionPublicationWorker.get();
Future<void> PublicationWorker.detach();
Future<PublicationLease> PublicationCache.publishLeased(
    PublicationAttempt attempt, StagedDownload staged, {
    required int parserVersion, required int canonicalVersion});
void PreparedBook.release();
```

### Contracts

- Capture the full session and book-operation generation. Coalesce normal
  duplicates, supersede on refresh. Hold the shared PrepareBookQueue through
  download, import, detach and cleanup, including across session retirement.
- BeginPreparation pins the old head before detail/network/import. Detail 404
  is typed unavailable. Check parser/canonical compatibility and stream-rehash
  the pinned file before conditional GET and after 304, including large files.
  Unusable 304 permits one unconditional recovery. Refresh bypasses validators.
- Build ContentIdentity from downloaded SHA-256 and current versions. Prepare
  staging in the worker before any head publication. Detach waits for the actual
  physical operation and releases its file handle before same-filesystem rename;
  it keeps the session isolate available. Reopen/prepare/detach retires resources.
- PublishLeased serializes commit and first new-head lease with eviction. Return
  PreparedBook only with matching identity, detached PreparedPublication summary,
  layoutFacts and lease. S4 reopens the immutable leased path for preload.
- Emit identity-bearing ContentChange after commit/acquisition, including first
  publication and interpretation-version changes; unchanged 304/200 emits none.
  Never mutate saved position/activity. The stream is transient, not an outbox.
- Cancellation/retirement completes callers silently and drains actual worker
  work before deleting staging. Release attempt pins and abandoned leases on
  every exit; retain the fallback pin through physical drain even after logical
  cancellation. Synchronous event listeners may retire/dispose owners: recheck
  after notification. A dispatched verified commit may finish without a UI
  result; do not compensate by deleting durable reader state or verified bytes.
- Session service owns outstanding PreparedBooks until release/retirement.
  Coalesced callers share one result/owner. Consumers needing independent
  lifetimes acquire their own cache lease and compare full identity.
- D1 getFile progress hook counts actual received bytes before bound enforcement,
  with nullable declared total; DownloadException(tooLarge) distinguishes limits
  from ParseException. Both reject before oversized bytes enter the writer.
  Keep core transport independent of feature error types.

### Validation & Error Matrix

| Condition | Result |
| --- | --- |
| Detail/file 404 | PrepareBookException(unavailable), no reader-state deletion |
| Network / TLS / unauthorized / redirect | Separate sanitized preparation failure |
| Compressed limit / pinned quota pressure | tooLarge / cacheBusy |
| Invalid archive/package/first section | invalidStructure; old head retained |
| Fixed/mixed/RTL/vertical | Prepared facts; capability belongs to S4 |
| Disk/store failure | storage; cleanup and old-head preservation before commit |
| Canceled/superseded/retired | RequestCancelled; never ready/error for new session |

### Good / Base / Bad Cases

Base: first 200 validates before publication. Good: changed bytes publish a new
identity while an older leased file stays readable. Bad: invalid replacement
must not become head or return an empty successful summary.

### Tests Required

Generated EPUB + real worker + real SQLite + fake adapter must cover 200/304,
actual request validators, identity/change events, unchanged forced refresh,
missing/corrupt head, bounded recovery, download/import cancellation, A -> B -> A,
lease/pin/staging release, cache busy/storage failure, fixed/RTL facts, GET-only
inventory, private-directory boundaries and S4 resource-preload consumption.

### Wrong vs Correct

Wrong: publish the download and validate later, or rename an open worker stage.
Correct: prepare -> detach/drain -> publishLeased -> emit identity event/ready.
Wrong: use summary readiness as a rendering/CFI-resume verdict. Correct: S4
reopens leased bytes, preloads resources and proves anchors against full identity.

## Not Decided Yet

- Authentication (token storage, refresh interceptor, router redirect):
  document here when the first auth task lands.
- Pagination contracts for later endpoints. S3 error envelopes/codes and exact
  DTO casing are defined by the contract audit, fixtures and transport above.
- Cleartext HTTP: runtime endpoints can use `http://`. Before the
  first real request, allow it per platform (Android `usesCleartextTraffic` for
  debug, iOS ATS exception, macOS `com.apple.security.network.client`
  entitlement) and record the chosen setup here.
