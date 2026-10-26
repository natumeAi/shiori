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

S3 field casing/envelopes follow the pinned contract audit and server fixtures.
Phase C adds checked DTOs; preserve actual mixed wire names instead of applying
a guessed global `field_rename` policy.

---

## Repository

One repository per feature: a plain class taking `SessionTransport`, plus its
generated session-keyed keep-alive provider in the same file.

```dart
// Illustrative Phase C book repository; DTO decoding remains feature-owned.
part 'book_repository.g.dart';

class BookRepository {
  BookRepository(this._transport);

  final SessionTransport _transport;

  Future<Book> fetchBook(int id) => guardDio(() async {
    final response = await _transport.getJson(
      ['api', 'books', id.toString()],
    );
    final envelope = response.body as Map<String, Object?>;
    return Book.fromJson(envelope['book'] as Map<String, Object?>);
  });
}

@Riverpod(keepAlive: true)
BookRepository bookRepository(Ref ref, ServerSession session) =>
    BookRepository(ref.watch(sessionTransportProvider(session)));
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

---

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
  lists/map and decoded body. DTOs remain feature-owned. Validators pass through
  exactly. Allowed terminal statuses are a per-call copy/subset of `{200,304}`;
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
