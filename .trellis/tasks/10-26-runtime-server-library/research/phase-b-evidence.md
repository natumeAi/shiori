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
