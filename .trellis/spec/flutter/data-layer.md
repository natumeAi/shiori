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
and `utc: DateTime`; it is not an HTTP DTO. SQLite `YYYY-MM-DD HH:mm:ss` is UTC.
ISO forms must carry `Z` or an explicit `+/-HH:mm` offset. Reject invalid calendar
components and offset-free ISO strings. Serialization returns `raw` unchanged;
never use device-local parsing or serialize normalized UTC over the raw value.

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
pure DTO/storage code. No product screen or disk cover cache is provided here.

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
Future<CoverLoadResult> CoverLoader.load(String? serverCoverPath);
SessionCoverImage(CoverLoader loader, String? serverCoverPath);
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
  `_readEncoded` source seam is reserved for Phase D's shared disk quota; C2
  does not read/write disk cover files or claim a persistent cache budget.
- The decoded LRU has **16 MiB**, accounting RGBA pixels and reservations before
  decoding. Read dimensions with ImageDescriptor, downsample larger images to
  fit before instantiating the codec, keep only the first frame, and dispose the
  codec/descriptor/buffer. Active CoverLeases pin entries; evict oldest unpinned
  entries only. If pinned/reserved bytes prevent admission, return cacheBusy.
- Both cache keys include ServerSession (ServerKey + generation) and cover path.
  SessionCoverImage uses this loader's LRU directly, bypassing global ImageCache
  whose live images are outside its byte quota. Use the provider directly;
  loader owns pixel sizing. The image stream clones a display handle, retains
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
  an access-time index supports future cross-server LRU. No cache commands or
  `cache_operations` table are added in B2.
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
- Future cache eviction may touch only cache-owned rows/files. Never delete
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

- Base: fresh v0 creates v1 and reopens the committed selection.
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
  B1a supplies only the directory accessor, with no cache files or metadata.
- **Documents:** intentional user exports only,
  `shiori-diag-<BUILD_ID>-<runId>.json`. iOS File Sharing exposes this directory
  because `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` are true.
- `Env.buildId` defaults to `local` and is shown in the probe and every export.
  CI injects it through `--dart-define=BUILD_ID=...`; see quality-guidelines.md.
- Resolve directories with `path_provider`; inject directories in repository
  tests so tests use no platform plugin or user directories. Marker retention
  is a feasibility check, not a transactional reading outbox guarantee.

---

## Not Decided Yet

- Authentication (token storage, refresh interceptor, router redirect):
  document here when the first auth task lands.
- Pagination contracts for later endpoints. S3 error envelopes/codes and exact
  DTO casing are defined by the contract audit, fixtures and transport above.
- Cleartext HTTP: runtime endpoints can use `http://`. Before the
  first real request, allow it per platform (Android `usesCleartextTraffic` for
  debug, iOS ATS exception, macOS `com.apple.security.network.client`
  entitlement) and record the chosen setup here.
