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
