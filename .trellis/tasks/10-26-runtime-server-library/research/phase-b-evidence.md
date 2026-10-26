# S3 Phase B evidence

## B1a endpoint and identities

Implemented and verified on Windows, 2026-10-26, against Phase A base
`c018794` on `ios-build/s3-runtime-server`. This slice adds no networking,
product persistence, SQLite usage or UI. The hosted iPhone storage gate and
later Phase B transport/activation work remain separate.

### API summary

| API | Contract |
| --- | --- |
| `ServerEndpoint.parse(String)` | Returns `ServerEndpointValidation`: endpoint on success, `ServerEndpointIssue` on failure; never retains the rejected text or URI exception |
| `canonicalRoot`, `normalizedText` | Canonical deployment root, including prefix and final slash; normalized display text is the same string |
| `api(List<String>)` | Returns a `Uri`; list includes `api`, e.g. `['api', 'books', '7']`; encodes every segment separately |
| `cover(String)` | Returns a `Uri`; accepts backend `/covers/...` paths with their encoded path/query under the configured deployment prefix |
| `ServerKey(ServerEndpoint)` | `value`: lowercase hex SHA-256 of UTF-8 canonical root; also carries `canonicalRoot` for comparison |
| `BookKey(ServerKey, int)` | Immutable server-scoped identity, runtime range `1..9007199254740991` |
| `AppDirectories.caches()` | Uses `path_provider.getApplicationCacheDirectory()` through the existing provider; fake supports the same interface |

### Decisions

- Endpoint/identity values live in pure Dart `core/config/`, usable from both
  library and reader without feature imports. The handwritten validation
  part shares the endpoint library, avoiding an import cycle and codegen.
- Validation checks explicit HTTP(S), authority/host, nonempty numeric port
  in `1..65535`, userinfo delimiters (including empty userinfo), query/fragment
  delimiters (including empty values), percent escapes and backslashes.
  `Uri` parsing/normalization supplies scheme/host case, default-port removal
  and dot normalization. Paths are never decoded/re-encoded wholesale;
  reserved encoded separators remain encoded and path case is significant.
- Reject IPv6 zone identifiers with `ipv6ZoneIdentifier`: interface-local
  zone names are not portable deployment identities. Bracketed IPv6 literals
  with no zone work with and without ports.
- API segments cannot be empty, `.` or `..`. Cover resolution requires the
  `/covers/` namespace and rejects absolute/foreign URLs, fragments,
  backslashes and malformed encoding. Parent segments, including encoded
  forms and those hidden inside encoded separators, are rejected before
  normalization. Decoding is used only for this validation, never rebuilding
  the path. Final resolution checks origin and the full deployment/covers
  prefix. Resource exceptions are content-free; cover errors have no source
  or offset.
- Equality/hash use canonical endpoint identity; `ServerKey` compares both
  digest and canonical string. Default-port/case/trailing-slash aliases merge;
  scheme, nondefault port, prefix, path case and distinct host remain separate.
  Book IDs alone never identify a cross-server record.
- `normalizedText` preserves the canonical encoding for display. No decoded
  display alias is introduced. `Env` and the legacy Dio provider are unchanged;
  the updated data spec requires runtime roots for new product requests and
  leaves build identity flags intact.
- Cache lookup has no Documents fallback and creates no app-owned files or
  metadata. Generated directory-provider output is unchanged after codegen.

### Fixture coverage and focused test counts

All inputs come directly from committed `test/fixtures/server/url_resolution.json`;
neither that file nor its README was modified.

- 9 accepted roots: root, prefix, trailing slash, explicit port, both default
  ports, IPv6, encoded prefix and scheme/host case with dot segments.
- All 45 exact request URL expectations: health, snapshot, book detail, book
  file and encoded cover path/query for each accepted root.
- All 17 rejected inputs: typed issue, absent endpoint and zero HTTP client
  creations under a network-forbidden `HttpOverrides` scope.
- Every accepted root also tests canonical round trip, normalized-text
  idempotence and equality/hash. Additional tests exercise IPv6 without port,
  zone rejection, encoded boundaries, per-segment encoding, traversal,
  malformed authorities/ports, identity aliases/range and cache wiring.

| New test file | Passed |
| --- | ---: |
| `test/core/config/server_endpoint_test.dart` | 92 |
| `test/core/config/server_resource_test.dart` | 32 |
| `test/core/config/server_key_test.dart` | 6 |
| `test/core/config/book_key_test.dart` | 8 |
| `test/core/storage/app_directories_test.dart` | 3 |
| Total | 141 |

### Commands and results

| Command | Result |
| --- | --- |
| `dart format` on all 11 changed/new Dart files | PASS; 3 test files formatted |
| `flutter test test/core/config test/core/storage/app_directories_test.dart --reporter expanded` | PASS; 141 tests, no skips |
| `dart run build_runner build` | PASS; generated outputs unchanged in Git |
| `dart format --output=none --set-exit-if-changed lib test` | PASS; 283 files, 0 changes |
| `flutter analyze` | PASS; no issues |
| `flutter test --reporter expanded` | PASS; 1264 passed, 1 skipped; 17 seconds test-reporter elapsed |
| `git diff --check` | PASS |

The existing optional native CFI export test is skipped because
`SHIORI_NATIVE_CFI_OUT` is unset. The full-suite log is local ignored output
at `build/phase-b1a-flutter-test.log`; no raw private test data is copied here.
All results are host evidence only. No iPhone, live NAS, transport, persistence
or activation acceptance is implied. Existing task JSONL edits were preserved;
no staging, commit, push or branch change was performed.

## B1b session transport and errors

Implemented on Windows, 2026-10-26, on the existing uncommitted B1a slice.
No SQLite, DTO, UI, reader, diagnostic-behavior, fixture or dependency changes.
No live NAS traffic or iPhone transport acceptance is claimed.

### API summary

| API | Contract |
| --- | --- |
| `ServerSession(endpoint:, generation:)` | Immutable endpoint, derived `ServerKey`, positive activation generation; equality/hash include key and generation |
| `SessionTransport(session, adapter:)` | One private Dio per owner; optional fake adapter injection; 10 s connect/20 s receive, automatic redirects disabled |
| `getJson(segments, ifNoneMatch:, ifModifiedSince:, allowedTerminalStatuses:)` | GET via `endpoint.api`; copied allowed subset of `{200,304}`, default `{200}`; only snapshot/file may opt into 304 |
| `getBytes(serverCoverPath, maxBytes:)` | GET via `endpoint.cover`; HTTP 200 only; actual emitted-byte limit before accumulation, independent of Content-Length |
| `TransportResponse<T>` | Terminal status, copied immutable headers/map/lists, decoded JSON or bounded bytes; no Dio/request metadata |
| `dispose()` | Idempotently cancel every pending hop/body, close Dio forcibly, reject future calls and retired results |
| `sessionTransportProvider(session)` | Generated keep-alive family; equal session shares owner; invalidation/container disposal calls `dispose` |

The GET inventory is health, snapshot, book detail/file and covers only. IDs
are positive JS-safe integers. All initial URIs use B1a's resolver; redirects
are validated relative to the current URI. `If-None-Match`/`If-Modified-Since`
and response validators remain opaque. A permitted 304 skips decoding; cache
presence/validity and unconditional recovery remain the later caller's job.
The private `_openValidatedResponse` seam is reserved for Phase D's bounded
file sink/digest. Publication streaming is not implemented by this slice.

### Classification table

| Evidence | Type | Retry |
| --- | --- | --- |
| Dio cancel / disposed transport | Non-`AppException` `RequestCancelled`, no private cause | Never; owner consumes before error publication |
| Bad certificate / direct or Dio-wrapped `HandshakeException` | `TlsException` | Never; certificates remain enforced |
| Dio connect/send/receive/transform timeout / connectionError / other unknown | `NetworkException` | Existing 3 retries, 200/400/800 ms |
| Direct receiving socket / HTTP / timeout failure | `NetworkException` | Same bounded policy |
| 401/403, regardless of body | `UnauthorizedException` | Never |
| Other unapproved terminal HTTP status, default 304 included | `ServerException(status)` | Never |
| JSON error envelope, including HTTP 200 | `ServerException(status, null, code)` | Never |
| HTML/non-JSON/malformed JSON or UTF-8 / DTO boundary type error | `ParseException` | Never |
| Cover actual-byte overflow | `ParseException`, abort remaining body | Never |
| Invalid/outside/looping/sixth redirect | `RedirectException(issue)` with final-root recovery instruction | Never |

Unknown top-level `code` and nested `error.code` are preserved without logging
or displaying them. HTTP error-envelope inspection is limited to 64 KiB;
non-JSON/oversized bodies retain their HTTP status without body text/code.
JSON decode failures discard the original format exception/body source.
Missing Content-Type is accepted only for valid JSON; present empty/duplicate
or non-JSON types fail parsing. DTO/service/schema checks remain Phase C.

The old `guard_dio_test` expected cancellation and bad certificates to be
retryable network errors. Those assertions were changed specifically for the
defect recorded in `research/contracts.md` "Existing transport and boot";
other existing exception/cause expectations were retained.

### Redirect and logging rules

- Follow only 301/302/303/307/308, manually, at most five validated hops.
  Require same scheme/host/effective port and the full deployment directory
  prefix. Keep GET and exact conditional headers on each approved hop.
- Detect normalized target loops including query, ignoring fragments. Reject
  cross-origin/prefix escape/downgrade before making another request. Invalid
  escapes/backslashes/traversal and missing/empty/multiple Location values
  fail with typed, content-free recovery. Userinfo, including an empty `@`,
  is rejected before Dart URI normalization can erase it.
- Cancel each redirect body before following; all remaining bodies are closed
  on rejection, overflow or session disposal. Check active ownership before
  dispatch, while receiving and immediately before returning.
- Replace debug `LogInterceptor` with `RedactingInterceptor`. The only network
  record form is `GET api/books/{id} status=200 elapsedMs=12`, using a fixed enum
  template. Elapsed time measures dispatch through headers for each hop.
  Pre-header failures use `status=-`; fallback is `GET {route}`.
- `guardDio` shares safe metadata to avoid duplicate hop records. No raw URI,
  actual path/ID, endpoint, port, prefix, query, headers, body, opaque code,
  exception object or stack is attached. Cancellation emits no failure record.
  Tests inspect whole `LogRecord`s, including null `error`/`stackTrace` fields.

`Env.apiBaseUrl` and the old Dio provider/generated output are removed;
`Env.buildId`/`buildNumber` and entry points are unchanged. The next activation
coordinator must assign fresh generations, dispose/invalidate old families and
check captured key/generation immediately before publication. Cancellation must
be consumed there; Phase E owns localized TLS/final-root UI feedback.

### Tests and commands

| Focused test file | Passed |
| --- | ---: |
| `server_session_test.dart` | 2 |
| `guard_dio_test.dart` | 23 |
| `retry_policy_test.dart` (unchanged) | 5 |
| `redacted_logging_test.dart` | 4 |
| `session_lifecycle_test.dart` | 19 |
| `session_redirect_test.dart` | 30 |
| `session_transport_test.dart` | 81 |
| Total | 164 |

The new files add 136 tests; the guard changes add five net tests. Real Dio
adapter assertions execute all 45 committed URL expectations. Additional
coverage includes status/header fixtures, 304 opt-in, unknown codes, HTML/error
envelopes, all nine Dio error types, direct/wrapped TLS, receiving failures,
five/six-hop redirects, loops, cross-origin/prefix/downgrade, malformed headers,
overflow before stream completion, pending-header/body cancellation, late
adapter completion, provider A/B/A generations and complete log redaction.

| Command | Final result |
| --- | --- |
| `dart run build_runner build` | PASS; new family generated, obsolete Dio output removed |
| `dart format` on changed Dart files | PASS |
| `dart format --output=none --set-exit-if-changed lib test` | PASS; 297 files, no changes |
| `flutter analyze` | PASS; no issues |
| `flutter test --reporter expanded` | PASS; 1405 passed, 1 skipped |
| `flutter test test/core/network test/core/config/server_session_test.dart --reporter expanded` | PASS; 164 passed, no skips |
| `dart run tool/ci/check_reader_fixtures.dart` | PASS |
| `git diff --check` | PASS |

The existing optional native CFI export test remains skipped because
`SHIORI_NATIVE_CFI_OUT` is unset. Full-suite output is local ignored
`build/phase-b1b-flutter-test.log`. Existing B1a/spec/task-context edits were
preserved. No staging, commit, push or branch change was performed.

## B2 SQLite store

Implemented and verified on Windows, 2026-10-26, including the B3 code present
at `dc7504f`. Product database location:
`<Application Support>/shiori/v1/state.db`. Documents and Caches are never used
for the database. No UI, networking, reader/diagnostic, dependency, fixture or
task-plan changes are part of this slice.

### Store API and lifecycle

- `SqliteStore.open(AppDirectories, testHooks:)` starts one long-lived isolate.
  `sqliteStoreProvider` is generated and keep-alive, scoped to its container.
  Provider invalidation waits for the old worker to drain/exit before opening
  its successor; disposal racing directory lookup creates no database.
- Public typed futures: `upsertServer`, `readServer`, `readActiveServer`,
  `setActiveServer`, `commitActivation`, `readSnapshot`, `replaceSnapshot`,
  `touchLastUsed`, `close`. Detached `ServerRecord` and `StoredSnapshot` values
  carry canonical identity, local timestamps and opaque payload/validator data.
- Private typed operations/replies carry request IDs. No SQL, native handle,
  statement or callback crosses a port. Worker bootstrap and every command
  compare isolate control ports to reject root execution. One synchronous
  worker event runs to completion before the next; writes use transactions
  and bound values. Snapshot JSON semantics remain feature validation's job.
- `close()` rejects new calls, completes accepted commands in order, closes
  the connection and awaits actual exit. Fatal onError/onExit completes every
  outstanding waiter with content-free `StorageException(workerExit)`.
  Fixed migration/activation fault points and worker exit probes exercise the
  real protocol; no arbitrary SQL or injected callback is transferred.
- Canonical endpoint comparison protects every server namespace command;
  active restore also recomputes its key digest. Upsert retains creation time;
  timestamps store UTC epoch microseconds. Snapshot revision decrease is valid.

### Schema v1 DDL summary

| Table | Key and columns / constraints |
| --- | --- |
| `servers` | `server_key` PK, unique canonical endpoint, created/last-used timestamps |
| `app_state` | singleton `id=1`, nullable active-server FK, schema version |
| `library_snapshots` | server PK/FK, raw payload, positive schema version, opaque nullable ETag, JS-safe nonnegative revision, fetched-at |
| `cached_publications` | server/book/digest PK, relative path, actual bytes, ETag/Last-Modified, parser version, validation status, access timestamp |
| `book_cache_heads` | server/book PK; composite FK to a validated cached generation |

Book IDs are positive JS-safe integers; digests are 64 lowercase hex characters.
Foreign keys restrict deletion of referenced parents/current generations. An
access-time index supports future cross-server LRU; active-server lookup is
indexed. There is no `cache_operations` table or cache deletion command. Phase D
adds cache commands; S4 adds checkpoint/outbox tables through explicit migrations
under this owner. Cache cleanup must never remove server/durable state.

### Migration, refusal and recovery

- The checked ordered list currently contains v0 -> v1. Each step's DDL,
  app metadata and `PRAGMA user_version` bump share one `BEGIN IMMEDIATE`
  transaction. Injected failure after the version bump and a real DDL collision
  both roll back completely; unrelated sentinel rows survive successful retry.
- Existing schemas are inspected before writes/settings changes to the original.
  Ordinary DELETE files use read-only inspection. WAL mode or retained WAL/hot
  rollback journals use a disposable private copy of the DB plus WAL/journal;
  shared memory is not copied. SQLite recovers only that copy for the version
  check, so uncommitted header changes cannot determine the schema verdict.
- A newer recovered schema returns `newerSchema` plus its observed version.
  Original DB/sidecar bytes and directory inventory are unchanged. Only newly
  created inspection copies are removed; originals are never renamed, reset
  or deleted. Supported retained journals recover before migration.
- Accepted opens enable/verify foreign keys, DELETE journal and FULL synchronous
  (`2`), then run migrations and validate required current-schema columns,
  singleton metadata and foreign keys. Unrecoverable open errors preserve the
  retained file and return a redacted typed `open` failure for retry/recovery.
- Activation atomically persists endpoint/last-use, snapshot/ETag/revision and
  active selection. Mid-transaction failure retains the old selection, previous
  snapshots and timestamps; a failed new-server activation creates no server.

### Tests and commands

All new tests use temporary directories and real resolved SQLite on Windows.

| New test file | Passed |
| --- | ---: |
| `sqlite_store_schema_test.dart` | 11 |
| `sqlite_store_commands_test.dart` | 9 |
| `sqlite_store_lifecycle_test.dart` | 5 |
| `sqlite_store_recovery_test.dart` | 2 |
| B2 total | 27 |

Coverage includes fresh/reopen, migration/sentinel/rollback, DELETE/WAL refusal,
newer version committed only in retained WAL, both directions of hot rollback
journal version recovery, corruption, malformed current schema, cache-head/FK
constraints, atomic activation, canonical mismatch across all namespace calls,
opaque bound strings, missing records, UTC timestamps, 200 ordered concurrent
read/write commands, close draining, fatal error/exit waiters and provider lifecycle.

| Command | Final result |
| --- | --- |
| `dart run build_runner build` | PASS; storage providers generated |
| `dart format lib/core/storage test/core/storage` | PASS; 21 files |
| `dart format --output=none --set-exit-if-changed lib test` | PASS; 336 files, zero changes |
| `flutter analyze` | PASS; no issues |
| `flutter test` for the four new B2 test files, expanded reporter | PASS; 27 passed, no skips |
| `flutter test --reporter expanded` | PASS; 1502 passed, 1 skipped, B3 included |
| `dart run tool/ci/check_reader_fixtures.dart` | PASS |
| `git diff --check` | PASS |

Full-suite output is ignored `build/phase-b2-flutter-test.log`. The existing
optional native CFI export remains skipped with `SHIORI_NATIVE_CFI_OUT` unset.
These are host results; the earlier hosted SQLite integration gate is separate
and does not prove this product owner's iPhone update retention. B3's
`ServerSelectionStore` adapter remains the explicitly assigned next step;
B3 files were not changed. No staging, commit, push or branch switch was performed.

## B3 activation coordinator

Implemented in `dc7504f`; detailed API, state-machine, lifecycle and 70-test
evidence remains in [phase-b3-evidence.md](./phase-b3-evidence.md).
`ServerSelectionStore` is a five-method core/config port over plain stored-server
and validated-snapshot values. Health precedes candidate snapshot validation;
endpoint/snapshot/selection commit and session publication form one serialized,
noncancelable section. Candidate failure preserves the previous session and work.
Restore verifies canonical endpoint/key and creates runtime ownership without
HTTP. Session generations are container-local, never persisted/global revisions.
`SessionPublicationGuard.publish` checks captured key/generation immediately
before synchronous writes; register session-owned cleanup with `onRetire` and
unregister completed work. Retirement revokes publication before cleanup and
transport invalidation. B4 below supplies SQLite composition; Phase C still
supplies the unconditional snapshot validator. The B3 evidence file is retained.

## B4 store wiring

Implemented and verified directly on Windows, 2026-10-26, on `dc7504f` plus the
existing uncommitted B2 store. No B2 internals or B3 coordinator behavior changed.
These are host SQLite/composition results; iPhone product retention, live NAS,
Phase C DTO validation and Phase E UI acceptance remain separate.

### Adapter mapping and binding

- `core/storage/sqlite_server_selection_store.dart` implements the existing
  five-method `ServerSelectionStore` without importing features. `ServerRecord`
  maps canonical root, creation time and last-use time to `StoredServer`;
  active-record reads return its verified key. Missing reads remain nullable.
- `ValidatedSnapshot.payloadText` maps directly to `StoredSnapshot.payload` and
  back; schema version, opaque nullable ETag, revision and fetched-at are copied
  exactly. No JSON decode/re-encode, trimming, ETag normalization or revision
  ordering is added. Microsecond UTC timestamps survive the worker round trip.
- Commit checks endpoint/key equality (digest and canonical string) before
  resolving the worker, then dispatches one B2 activation transaction. Creation
  and last-use use UTC now; B2 retains existing creation time. Touch updates only
  last-use. B2's canonical-string checks remain in every namespace operation.
- `StorageFailure.newerSchema` -> `SelectionStorageIssue.newerSchema`;
  `canonicalMismatch`/`invalidRecord` -> `invalidSelection`; open, migration,
  command, closed, worker-exit and protocol -> `unavailable`. Only the typed
  issue crosses the selection boundary: no path, SQL, payload or driver cause.
- The generated keep-alive `serverSelectionStoreProvider` now returns this
  adapter. Its lazy resolver reads `sqliteStoreProvider.future` during port
  calls so initialization failures also receive typed mapping. B2's keep-alive
  provider owns draining/closing the worker on container disposal. Tests retain
  their fake-port overrides; product composition needs no store override.
- The Phase C provider default returns a validator whose `validate` throws
  `SnapshotValidationException(incompatible)`, producing typed incompatible
  feedback and no commit. Throwing from the provider factory instead was found
  to wrap the exception in Riverpod's `ProviderException`; the default-method
  failure avoids changing B3's classifier or controller.

### Integration tests and validation

Real SQLite and temporary directories exercise the default store binding;
only HTTP adapters and Phase C validation are substituted. One failure test
injects a real worker with B2's fixed mid-transaction activation fault hook.

| New test file | Passed |
| --- | ---: |
| `test/core/storage/sqlite_server_selection_store_test.dart` | 13 |
| `test/features/servers/presentation/sqlite_server_activation_test.dart` | 7 |
| B4 total | 20 |

The seven coordinator tests prove exact activation persistence, provider retention
and disposal, a new container restoring the same server without any candidate
or active HTTP request, transaction rollback preserving A plus B's existing
snapshot/last-use and A's pending work/transport, A -> B -> A retaining exactly
two server/snapshot rows and original creation time, byte-identical future-schema
refusal, byte-identical corrupt-open refusal, and the typed unconfigured validator.
A new container starts a fresh generation clock; cross-container monotonicity is
not asserted. Adapter tests cover all nine storage classifications, nullable
reads, stored/touched timestamps, pre-dispatch key mismatch, and all five methods
against a real closed worker and a noncanonical retained server row.

| Command | Result |
| --- | --- |
| `dart run build_runner build` | PASS; dependency-provider binding/default output regenerated; final run wrote zero outputs |
| `dart format` on changed handwritten Dart files | PASS |
| `dart format --output=none --set-exit-if-changed` on six B4 Dart files including generated output | PASS; zero changes |
| `dart format --output=none --set-exit-if-changed lib test` | PASS; 340 files, zero changes |
| `flutter test` for the two new B4 test files, expanded reporter | PASS; 20 passed, no skips |
| `flutter analyze` | PASS; no issues |
| `flutter test --reporter expanded` | PASS; 1522 passed, 1 skipped |
| `git diff --check` | PASS |

The existing native CFI export is skipped because `SHIORI_NATIVE_CFI_OUT` is
unset. Full-suite output is ignored `build/phase-b4-flutter-test.log`. An initial
focused test compile needed the Riverpod extension import; the default-validator
regression then caught the provider-construction wrapping described above. Both
were corrected before the final passing runs. Other regenerated B3 model/controller
outputs were verified byte-identical to HEAD. Only data-layer/state-management
wiring notes were added to specs; existing B2 edits and the B3 evidence file were
preserved. No dependency, fixture, reader/diagnostic, task-plan, reference-checkout,
staging, commit, push or branch changes. No B4 implementation issue remains.

## Phase B review fixes

Implemented on Windows, 2026-10-26, directly in the existing dirty worktree.
Read the reviewer's temporary `review_boundary_test.dart` without modifying it;
ported its synchronous `committing` invalidation/immediate-restore case into
project regression tests. Existing B2/B4 edits were preserved.

### Activation consistency

- Added a generated keep-alive, container-scoped
  `serverActivationSerializerProvider`, independent of controller rebuilds.
  Register its barrier before notifying `committing`, re-check candidate
  ownership after the synchronous notification, then dispatch the store call.
  Every completion/failure/cancellation releases the barrier in `finally`.
- Restoration awaits this barrier before reading SQLite. A retired dispatched
  commit restores B on success or A after rollback; a retired candidate before
  dispatch never writes B. No compensation transaction or port API was added.
- Admission awaits the build's actual restoration future and shared barrier.
  A reentrant Riverpod `.future` read inside a state notification can expose
  retained data while the replacement build is still loading; it must not let
  a queued candidate bypass restoration. Regression assertions wait for the
  replacement session generation, then verify its publication guard too.
- Six new real-SQLite tests cover synchronous rebuild during `validating` and
  `committing`, each with/without a queued C, plus dispatched B commit success
  and failure during rebuild. The latter gate the production adapter's worker
  resolver after port dispatch; release runs the real transaction, including
  the existing worker's fixed activation rollback fault. Every settled case
  asserts durable selection equals published session key and current guard;
  prior rows/snapshots survive, and pre-dispatch B has no persisted row/snapshot.
- The initial regression run failed on the reproduced selection split and
  premature restoration. Final six cases pass. B2 store internals are unchanged.

### Bounded JSON and header hygiene

| Response | Actual wire-byte ceiling | Reason |
| --- | ---: | --- |
| Health / file-route JSON | 64 KiB | Small status/error envelopes; health fixtures are 81-134 bytes |
| Book detail | 256 KiB | Detail includes descriptions; committed detail is 906 bytes |
| Complete library snapshot | 8 MiB | Includes all books/folders/joins; typical/additive fixtures are 4275/4570 bytes, leaving substantial multi-thousand-record headroom |
| Non-success HTTP error envelope, on every route | 64 KiB | Preserve existing bounded error inspection and HTTP status precedence |

These are explicit engineering ceilings consistent with design section 7's
bounded-input rule. Its 512 MiB removable disk and 128 MiB expanded-worker
budgets are separate from JSON received/decoded on the UI isolate. The 8 MiB
ceiling bounds wire bytes, not decoded object memory or process RSS; it is not
a supported-library-size guarantee, and limits are never raised silently.
Publication bytes remain a later streaming sink, not `getJson` or cover bytes.

- `BoundedResponseAdapter` counts actual source chunks before Dio's eager
  response subscription can buffer them. An additional `_read` guard checks
  accumulation. Chunking, absent Content-Length and misleading length cannot
  authorize overflow; oversized chunks are rejected before they are retained.
- The sixteen MiB reproduction initially exposed that a `_read`-only fix still
  allowed Dio to drain the entire source. The adapter regression now proves
  rejection and upstream termination before all sixteen MiB are emitted.
- Content-Type is checked from response headers before source consumption;
  incompatible/empty/duplicate types do not require a body read. Missing type
  still requires valid JSON. Unneeded redirect/304/401/403 bodies are canceled.
- HTTP 200 overflow is content-free `ParseException`, never retried. HTTP
  failure overflow retains `ServerException(status)` without an envelope code.
  Cancellation remains control flow; TLS/status/304/logging contracts remain.
- Nineteen new transport tests cover unfinished chunked overflow on all four
  JSON routes at HTTP 200 and 500, source/response/token cancellation, exact
  per-route byte boundaries, normal health/snapshot/detail/error fixtures,
  incompatible MIME before even a first body chunk (200/500), and the review's
  sixteen MiB additive-health reproduction. Existing network tests also pass.

### Address examples and specifications

- Replaced both scoped IPv6 test literals and the data-layer example with
  `2001:db8::7` plus zone suffixes. The same `ipv6ZoneIdentifier` assertions
  remain; fixture inputs are unchanged.
- Directory spec now lists session transport/bounded adapter and build-only
  Env flags; removed the deleted Dio provider entry. Quality spec describes
  product SQLite and the already-passed hosted iPhone storage gate accurately.
- Data/state specs now document byte limits, pre-Dio source enforcement,
  cross-rebuild commit/restore ordering and required regression assertions.

### Verification

| Command | Final result |
| --- | --- |
| `dart run build_runner build` | PASS; serializer provider and controller hash regenerated |
| `dart format` on eight changed handwritten Dart files | PASS |
| `dart format --output=none --set-exit-if-changed lib test` | PASS; 343 files, zero changes |
| `flutter test test/core/network test/features/servers/presentation/sqlite_activation_rebuild_test.dart --reporter expanded` | PASS; 187 tests |
| `flutter analyze` | PASS; no issues (initial single brace-style info corrected) |
| `flutter test --reporter expanded` | PASS; 1547 passed, 1 skipped; 25 new regression tests |
| `dart run tool/ci/check_reader_fixtures.dart` | PASS |
| `git diff --check` | PASS |

The existing optional native CFI export test remains skipped because
`SHIORI_NATIVE_CFI_OUT` is unset. Ignored logs are
`build/phase-b-review-{red,focused,codegen,analyze,flutter-test}.log`.
No B2 internals, reader/diagnostics implementation, dependencies, fixtures,
task planning/context manifests or reference checkout were changed. No staging,
commit, push or branch switch. These results are host regression evidence;
no new live-server/device acceptance claim or review-fix issue remains.
