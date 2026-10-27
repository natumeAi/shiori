# S3 Phase C evidence

## C1 DTOs, index and validator

Implemented directly on Windows, 2026-10-26, based on `9b7d16e`, branch
`ios-build/s3-runtime-server`. No sub-agents, live HTTP, staging, commits,
pushes or branch changes. This is host evidence, not device/LAN acceptance.
The initial exact-payload scope conflict described below was resolved by the
approved transport extension; see **Approved raw-text completion** for the final
C1 result. The earlier implementation record is retained as history.

### Source and model boundary

Read the task PRD, design section 4, implementation Phase C, contract audit,
Phase B/B3 evidence, Flutter data/error/directory/state/testing/quality rules and
shared thinking guides. Wire declarations and ordering were checked against the
read-only reference's `shared/src/{librarySnapshot,book,folder,shelf,reading}.ts`
and `server/src/services/librarySnapshot.ts`, pinned by fixture provenance to
`a4bda23fd3e82e285a22566d88576e67d3e8756b`. No fixture contradiction was found.

- Added checked Freezed/json_serializable LibrarySnapshot, SnapshotResponse,
  SnapshotBook, SnapshotFolder, sealed ShelfRef book/folder variants, RecentEntry,
  ReadingPosition, full Book and BookResponse. BookDetailResult is a Freezed
  available/unavailable union without a wire decoder.
- Every declared wire key is explicitly required, including nullable values;
  generated `$checkKeys` distinguishes missing from null. Unknown additive
  fields are ignored at envelope, snapshot, record, reference and progress levels.
- IDs are positive JS-safe integers; versions/sizes/counts are nonnegative safe
  integers; signed sort orders/indices remain safe. Validate before conversion,
  so fractional input cannot truncate. Signed bounds use direct comparisons:
  applying `abs()` to the minimum 64-bit integer can overflow.
- Progress accepts only finite `[0,1]` numbers; null, zero and fractional progress
  remain distinct. Unknown integer snapshot schema versions are incompatible;
  malformed types/missing schema are malformed.
- `ServerTimestamp` retains `raw` and UTC `utc`. SQLite timezone-free seconds
  mean UTC. Explicit ISO Z/offset forms normalize to the same instant; calendar
  overflow, invalid offsets and offset-free ISO are rejected. Converter output
  returns the original string, including fractional seconds and explicit offset.
  No device-local parsing is used. This converter value is handwritten immutable
  data; HTTP DTOs remain generated Freezed.

### Normalized immutable index

Books and folders use separate immutable maps. IDs are unique within each kind;
book ID 7 and folder ID 7 coexist correctly. Lists preserve source order.
Folder memberships resolve exactly once and agree with each Book's folderId;
all contained Books appear in their owner list. Count equals list length,
preview is the first four members, and member order is sortOrder then ID.
Shelf references resolve by kind, agree with entity sortOrder, contain each
root Book and Folder once, exclude folder-contained Books, and follow sortOrder,
kind then ID. Recent entries resolve, agree with nested bookId, and are unique;
chapter count/index is either both null or positive count with `-1 <= index < count`.
Failures carry only fixed `LibraryInvariant` names through sanitized
`LibraryDecodeException`; checked JSON maps, titles and other content are not
retained by that exception.

### Detail and production binding

`BookRepository.fetchBook(BookKey)` uses its captured session transport and a
generated session-keyed keep-alive provider. Foreign keys fail before traffic;
response identity must match the key. The full `{book}` DTO is separate from
SnapshotBook. HTTP 404 returns typed unavailable, without local deletion.
Malformed detail becomes content-free ParseException. HTTP/TLS/network failures
and RequestCancelled retain transport classifications.

The sole servers production change binds candidateSnapshotValidatorProvider to
LibrarySnapshotValidator, replacing the placeholder while keeping fake overrides.
It makes one unconditional prefixed snapshot GET, accepts only 200, validates
DTOs and joins, preserves the exact opaque ETag, and uses body version as revision.
Present X-Library-Revision must be a single matching unsigned integer value;
duplicate header values and mismatch are malformed. Fetched-at uses UTC with an
injectable clock. Incompatible/malformed failures map to the existing coordinator
SnapshotValidationException contract. No store or coordinator logic changed.

Three real-SQLite integration cases use the production validator binding and fake
HTTP adapters: typical success persists metadata, unsupported schema refuses
commit, and duplicate book IDs refuse commit. The existing placeholder-default
test was replaced; prior override-based activation/store tests remain intact.

### Exact payload scope conflict (initial; resolved below)

SessionTransport.getJson currently reads bounded bytes, decodes JSON, discards
the original text, and returns only TransportResponse.body plus status/headers.
TransportResponse has no raw-text field. Neither the library validator nor the
provider binding can recover whitespace, original escapes, numeric spelling or
final newline from the decoded body. A second HTTP client/request would violate
the candidate/session transport contract and would not prove the same response.

The current validator uses `jsonEncode(response.body)`: this retains validated
JSON structure and unknown additive fields, but **does not retain exact HTTP
payload text**. Validator and SQLite tests currently assert structural payload
equality, not exact text equality. Exact ETag/revision checks do pass.

A scope decision was requested asynchronously: allow a minimal transport seam,
or accept reconstructed JSON. No answer had arrived when this evidence was
written. Proposed minimal completion, pending authorization because transport
changes are explicitly excluded by this assignment:

1. Add optional `rawJsonText: String?` to TransportResponse.
2. In the existing bounded JSON read/decode path, retain UTF-8 text from the same
   bytes and attach it to the successful result; 304 has no raw text. Preserve
   all route/status/size/cancellation behavior.
3. Have the validator persist that text, then change validator and real-SQLite
   assertions to exact string equality, including whitespace/escapes/newlines.
4. Re-run codegen/format/analyze/full tests. No second request, transport redesign,
   store/coordinator logic or dependency change is needed.

### Validation (initial pass)

All five valid and nine invalid snapshot fixtures are tested at decode/index
and validator boundaries. Each invalid fixture asserts its named invariant.
Additional tests cover every required key, numeric boundaries, nested timestamps,
immutable joins/ownership/order/count/previews, chapter tuples, all detail
fixtures, foreign/mismatched BookKey, HTTP/network/TLS/cancellation and unsolicited
304. Unsupported schema and malformed joins never commit selection.

| Command | Final result |
| --- | --- |
| `dart run build_runner build` | PASS; new DTO/provider outputs and binding regenerated |
| `dart format` on changed Dart files | PASS |
| `dart format --output=none --set-exit-if-changed` on all 45 changed/new Dart files | PASS; zero changes |
| `flutter test test/features/library --reporter expanded` | PASS; 194 tests, no skips |
| Focused library plus SQLite activation test file, before additional key/boundary cases | PASS; 124 tests, no skips |
| `flutter analyze` | PASS; no issues |
| `flutter test --reporter expanded` | PASS; 1743 passed, 1 skipped |
| `dart run tool/ci/check_reader_fixtures.dart` | PASS |
| `git diff --check` | PASS |

The existing native CFI export test is skipped because SHIORI_NATIVE_CFI_OUT is
unset. Existing local-book tests ran without printing private content. Logs are
ignored `build/phase-c-{codegen,format,format-check,focused,analyze,flutter-test}.log`.
Initial code generation exposed the Freezed union's arrow-factory requirement
for JSON generation and a prefixed converter reference lost in generated code;
both were corrected. Initial analysis found one constructor-style info; fixed.
All final command results above are passing; exact raw-text coverage remains
explicitly absent rather than waived by these passes.

### Scope and remaining work (initial pass)

Only library implementation/tests, the servers validator provider and its generated
output, one servers SQLite activation test file, data-layer.md and this evidence
were edited. Transport, store, coordinator, reader/diagnostics, dependencies,
fixtures, task plan/context manifests and reference checkout were preserved.
No UI was added. Later Phase C refresh/cache-304 and covers remain outside C1.
The task was not archived or marked complete, and no journal/git-state write ran.

### Approved raw-text completion

Resumed on 2026-10-26 with explicit authorization for minimal backwards-compatible
changes to `transport_response.dart`, `session_transport.dart` and a transport test.
The earlier open-scope and re-encoding notes above describe the initial pass only;
the re-encoding implementation has now been removed.

- TransportResponse adds optional `rawJsonText`, defaulting to null for existing
  construction. Successful JSON 200 responses expose the exact UTF-8 decoded
  string passed to jsonDecode. The private decoder returns that string and the
  decoded object together; no second request, byte buffer, UTF-8 decode or stream
  accumulation was added. Existing per-route/source bounds remain unchanged.
- 304 and byte responses retain null rawJsonText. HTTP errors, invalid JSON/UTF-8,
  MIME rejection, redirects, cancellation, limits and logging preserve their
  existing behavior. Raw text is private content and is never logged or displayed.
- LibrarySnapshotValidator persists that same raw string after DTO/index/header
  validation. It no longer calls jsonEncode. Exact ETag/revision/fetched-at and
  production provider/override behavior are unchanged.
- New transport tests cover all four JSON routes with Unicode including a
  multi-byte character split across chunks, original `\\u96ea` escaping,
  `1.00` and `1.0e-7` spellings, leading spaces and CRLF. Assertions compare exact
  text/UTF-8 bytes, decoded values, and demonstrate that re-encoding changes the
  numeric spellings. A separate test checks null text for 304 and cover bytes.
  Existing transport tests and assertions were preserved.
- Every valid snapshot fixture now asserts exact payload text and UTF-8 bytes
  against its on-disk body. An extra validator case retains non-ASCII/escaped
  additive fields, fractional revision notation and exponent notation. The real
  SQLite activation success test compares persisted text and UTF-8 bytes exactly
  with the fixture file, replacing its former structural comparison.
- Updated data-layer.md's C1 and B1b transport contracts for the raw text field,
  bounded decoding path, private-data handling and exact persistence assertions.

No dependency, fixture, store/coordinator logic, reader/diagnostics, task planning,
reference-checkout or git-state writes were introduced. Scope remains C1; later
Phase C refresh/cache-304 and cover work is still separate.

Final verification after the approved completion:

| Command | Result |
| --- | --- |
| `dart run build_runner build` | PASS; existing generated outputs checked/regenerated |
| `dart format` on six directly changed Dart files | PASS |
| `dart format --output=none --set-exit-if-changed` on 46 C1/transport Dart files | PASS; zero changes |
| `flutter test test/core/network test/features/library test/features/servers/presentation/sqlite_server_activation_test.dart --reporter expanded` | PASS; 390 tests, no skips |
| `flutter analyze` | PASS; no issues |
| `flutter test --reporter expanded` | PASS; 1749 passed, 1 existing skip |
| `git diff --check` | PASS |

The single skip remains the optional native CFI export with SHIORI_NATIVE_CFI_OUT
unset. All existing transport tests, including per-route byte-boundary and source
cancellation tests, pass unchanged alongside the new raw-text tests. Ignored logs:
`build/phase-c-raw-{codegen,format-check,focused,analyze,flutter-test}.log`.

**C1 is complete, including exact raw payload retention. No C1 issue remains.**
This does not complete the broader S3 task or its later Phase C/device gates.

## C2 snapshot cache, covers and inventory

Implemented directly on Windows, 2026-10-27, on top of the existing uncommitted
C1 tree and committed Phase B (`9b7d16e`). No sub-agents, live HTTP/NAS requests,
dependency/fixture changes, staging, commits, pushes or branch switches. The C1
transport raw-text changes and prior activation wiring/tests remain intact;
C2 required no additional transport behavior change or store/coordinator change.

### Changed files and boundaries

- Library data adds `cached_library_snapshot.dart`, `library_session_scope.dart`,
  `library_snapshot_cache.dart`, `library_snapshot_repository.dart`,
  `library_snapshot_state.dart` and `library_snapshot_protocol_exception.dart`.
  Cache/repository providers have generated `.g.dart` files. The candidate
  validator reuses the shared response validation; its public behavior remains.
- `book_repository.dart` now requires a session publication guard, owns a
  disposable scope, and adds the generated `bookDetailProvider(session, key)`.
  Existing C1 BookRepository tests now provide a selected guard and retain all
  their prior success/error assertions.
- Presentation adds `library_snapshot_controller.dart` plus generated provider,
  and `covers/{cover_loader,cover_loader_decode,cover_failure,cover_lease,
  cover_load_result,cover_image_exception,session_cover_image}.dart` plus the
  loader's generated provider. These use Flutter resources outside pure data.
- Tests add snapshot repository/lifecycle/cache support, controller and real
  SQLite reopen coverage, cover loader/image-provider/support files, and
  `test/s3_get_only_inventory_test.dart`.
- Updated `data-layer.md` and `state-management.md` with executable cache,
  validator, resource-budget, provider/retirement and cancellation contracts.
  No product screen, reader/diagnostics behavior, task plan/context manifest,
  reference checkout or durable-store implementation was edited.

### Snapshot cache and 304 policy

Read current snapshot by the captured ServerKey. Restore only when JSON decoding,
supported schema, the complete immutable index, and stored schema/revision all
agree. Publish valid cache stale/refreshing before waiting for HTTP. Refresh
requests coalesce; a view can render the retained snapshot with a typed error.

Send the stored opaque ETag exactly only for usable cache. Candidate and refresh
200 validation share CachedLibrarySnapshot: checked DTOs/index/header validation,
exact raw payload, body revision/schema, optional single ETag, matching optional
X-Library-Revision and UTC fetched-at. Persist the entire StoredSnapshot through
one existing replaceSnapshot transaction before fresh publication. The adapter
checks session ownership after awaiting the store and immediately before dispatch.
Failure preserves cached data and the selected server.

A 304 re-reads and revalidates durable cache and checks its payload/ETag still
match the conditional request. Missing, corrupt, incompatible, metadata-mismatched
or changed cache (including loss/change while HTTP ran) causes exactly one
unconditional recovery fetch. A second 304 becomes LibrarySnapshotProtocolException
without another request. Without ETag, a 200 remains valid, clears an older ETag,
and never authorizes conditional reuse. A successful 304 marks fresh without
rewriting the original fetched-at. Revisions are never compared across activations.

Only HTTP NetworkException uses the existing three delays (200/400/800 ms).
Storage, validation/schema/header, TLS, HTTP and protocol errors are not retried.
Session retirement/disposal races unfinished work and retry waits, rejects late
success/errors and completes callers silently. Every state/cache admission checks
the full session; tests accept a lower revision on later A after A -> B -> A.
BookRepository and the UI-facing detail provider both guard results; null from
the detail provider is silent cancellation, distinct from typed unavailable 404.

### Cover loading

CoverLoader resolves only server cover paths with ServerEndpoint.cover and uses
the captured session transport's bounded getBytes. Prefix/encoding/query survive.
Missing/invalid paths, HTTP/network/TLS failures, non-images and actual encoded
overflow return fixed typed placeholder reasons. Actual byte limit is 8 MiB
inclusive; a chunked oversized source is aborted before draining the whole stream.

Validated encoded bytes use a 16 MiB LRU. Decoded RGBA pixels and in-flight pixel
reservations share a separate 16 MiB bound. Inspect dimensions, downsample before
codec decode, retain the first frame only, and dispose all codecs/descriptors/
buffers. Evict only unpinned decoded entries; pinned/reserved pressure returns
cacheBusy rather than admitting excess pixels. Tests inject smaller budgets to
prove ordering, encoded reuse after pixel eviction, pinning and reservation bounds.
The byte figures are resource accounting, not a measured device/process-RSS claim.

Keys include ServerSession (server key + generation) and cover path. The custom
ImageProvider uses this cache directly and does not add global ImageCache
retention. Its stream holds a lease until ImageStreamCompleter.onDisposed,
including TickerMode keep-alive handles with no listeners. Image.errorBuilder
renders typed failures as a placeholder; retirement emits no image/error.
onRetire and provider disposal clear owned cache maps/image handles and pending
lookup state; native late decode completions dispose their resources and cannot
repopulate the cache. `_readEncoded` is the Phase D source seam; no disk cover
files, second HTTP client or persistent-cache quota implementation was added.

### GET-only inventory

The automated inventory pins exactly health, snapshot, book detail, book file
and covers. It drives HealthRepository, LibrarySnapshotValidator, snapshot and
book repositories, guarded detail provider, cover loader and ImageProvider
through a recording fake adapter. Phase D has no file repository yet: the test
exercises the existing file-route transport seam with synthetic JSON and does
not claim EPUB transfer/validation acceptance. All eight recorded requests are
GET and map to the five templates. List/catalog/folders/reading/goals/statistics
and write-like routes are rejected and never observed.

A static pass reads every lib Dart file, rejects Dio write/generic request calls
and non-GET method options, and rejects Image.network. Positive detector probes
cover aliased Dio imports, method setters, dynamic options and write calls. An
exact transport-caller inventory makes newly added network owners require test
coverage; pure offline archive getBytes methods are excluded by transport import.

### Regression findings and verification

Focused implementation initially found nullability/style issues and two real
async lifecycle defects, now corrected with regression coverage: a cleanup
callback returning the pending Future made it wait for itself, and synchronous
stream closure from a listener threw during dispatch. Cleanup now returns void;
disposal cancels immediately and closes the stream in a microtask. Review also
ensured that keep-alive stream handles retain pixel leases until actual disposal.
No transport bug or scope exception was necessary.

| Command | Final result |
| --- | --- |
| `dart run build_runner build` | PASS; library providers regenerated/checked |
| `dart format lib/features/library test/features/library test/s3_get_only_inventory_test.dart` | PASS; 68 files |
| `dart format --output=none --set-exit-if-changed lib test` | PASS; 411 files, zero changes |
| `flutter test test/features/library test/s3_get_only_inventory_test.dart --reporter expanded` | PASS; 257 tests, no skips |
| `flutter analyze` | PASS; no issues |
| `flutter test --reporter expanded` | PASS; 1811 tests, 1 existing skip |
| `dart run tool/ci/check_reader_fixtures.dart` | PASS; manifests/privacy guard, exit 0 |
| `git diff --check` | PASS |

The existing optional native CFI export remains skipped because
SHIORI_NATIVE_CFI_OUT is unset. Ignored command records are
`build/phase-c2-{codegen,format,format-check,focused,analyze,flutter-test,fixtures}.log`.
PowerShell captured Dart's successful build-hook progress on stderr in the fixture
log; the command printed PASS and exited 0. Final checks above all pass after
the corrections; earlier failed focused runs remain in ignored local logs.

C2 has no remaining implementation issue. Cover disk persistence and real EPUB
transfer/cache are Phase D; product screens are Phase E. Device/LAN acceptance
remains the existing later gate; these host tests do not close it. The broader
S3 task stays active and no task/journal/git-state mutation was performed.
