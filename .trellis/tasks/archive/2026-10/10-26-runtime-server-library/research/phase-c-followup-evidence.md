# Phase C follow-up regression evidence

Date: 2026-10-27. Worktree: `D:/Projects/shiori-cs`, branch
`s3/c-followup-tests`, starting HEAD `2603b18`. Implemented directly without
sub-agents, staging, commits, pushes, branch switches or other worktree access.

## Changed files

- `lib/features/library/data/library_snapshot_repository.dart`: recover from
  typed cache-read errors through the existing unconditional-fetch path.
- `lib/features/library/presentation/covers/cover_loader.dart` and
  `cover_loader_decode.dart`: optional frame-decode injection, defaulting to
  the existing native codec operation, for deterministic concurrency tests.
- `test/features/library/data/library_snapshot_repository_test.dart`: eight
  additional snapshot cases using the existing injected MemorySnapshotCache
  and fake HTTP adapter.
- `test/features/library/presentation/covers/cover_loader_concurrency_test.dart`:
  three new concurrency/lifecycle cases.
- `test/features/library/presentation/covers/cover_test_support.dart`: a gate
  that holds a real decoded native frame before returning it to the loader,
  plus bounded asynchronous cleanup draining.
- This evidence file.

No semantic generated-file changes remain. Dependency restoration and codegen
rewrote generated files with LF; their contents were verified against HEAD and
their expected Windows line endings restored. No dependency, fixture, spec,
task planning/context manifest, network, storage or reader implementation diff
was introduced.

## Tests and decisions

### Same opaque ETag, changed body

Design section 4 makes ETags opaque conditional validators, not payload
identity checks for successful 200 responses. A validated 200 always replaces
and publishes its body; a usable matching 304 reuses the stored body.

The new test keeps the weak opaque ETag and revision unchanged while changing
a book title. It checks the normalized published title, exact new raw text
(including leading whitespace and CRLF), new fetched-at, and persistence before
fresh publication. A following conditional 304 must reuse that exact stored
value without another write or fetched-at change. A separate added case changes
the durable payload under an unchanged ETag while a conditional request runs:
the 304 cannot reuse it and causes one unconditional fetch.

### Typed cache-read failures

Six cases inject `StorageException(StorageFailure.command)` on initial load
or on the second durable read after a conditional 304. Each position covers
successful 200 recovery, network failure, and repeated bodyless 304.

- An unreadable initial cache never supplies a validator or stale display data.
- An unreadable revalidation cache cannot satisfy a 304. Only the previously
  validated display snapshot may remain stale on failure.
- Recovery uses no If-None-Match header, never retries storage reads, and makes
  at most one recovery fetch after a 304. Another 304 is a typed
  LibrarySnapshotProtocolException without a further request.
- Terminal network failure remains a typed NetworkException. Its existing
  three retries are bounded by 200/400/800 ms; all four attempts remain
  unconditional. Thus a logical recovery fetch may have network retries,
  but there is no recursive 304 or storage retry loop.
- Failures leave the store and selection unchanged; a successful recovery
  persists once before publishing fresh data.

### Covers under concurrency and retirement

One test holds two different-path native frame completions concurrently while
an existing image is leased. It checks exact 4/8-byte reservations, the shared
12-byte decoded bound, encoded admission under a two-image byte bound,
cacheBusy placeholders, reverse completion order, pinned-image survival, and
oldest-unpinned eviction. Image disposal and the exact HTTP request sequence
prove both decoded ordering and encoded reuse/eviction rather than checking
counters alone. Rejected admissions release no other operation's reservation.

Two more cases run retirement and explicit loader disposal for 30 cycles each.
Each cycle holds an existing lease and a real native frame, keeps an image
stream listener attached, and coalesces a second pending load for that path.
The pending caller completes cancelled before the native operation returns;
owned caches/images clear and repeated lease release is safe. A later session
loads the same path before the old frame is released. The late old frame is
disposed, produces no stream image/error, and cannot modify the successor.
Every retired loader ends with zero encoded, decoded and reserved bytes.
Reservations remain accounted while native work is held and release in its
finally cleanup after completion; tests do not claim synchronous cancellation
of native work or device/process-RSS measurements.

## Defect found and fixed

Before the fix, all six cache-read-error cases failed: initial read errors
prevented any HTTP request, and 304 re-read errors prevented recovery. The
repository's outer catch treated those errors as terminal too early.

The minimal fix catches only StorageException in the shared read helper and
returns unusable cache. Existing initial-fetch and bounded 304-recovery logic
then apply. Cancellation and unexpected errors retain their existing handling;
write failures retain their typed terminal behavior. No ETag or cover lifecycle
defect was exposed. The cover implementation change is solely the explicitly
requested controllable decode seam.

## Commands and results

| Command | Result |
| --- | --- |
| `flutter pub get --offline` (first command) | PASS; no fallback needed |
| Snapshot regression run before the fix | Expected FAIL: 25 passed, 6 failed |
| Initial two-file focused run after the fix | PASS: 34 tests; before the additional changed-cache-payload case |
| `dart run build_runner build` | PASS; no semantic generated diff |
| `dart format` on all six changed/new Dart files | PASS |
| `dart format --output=none --set-exit-if-changed lib test` | PASS: 412 files, zero changes |
| `flutter analyze` | Initial run: one constructor-style info, corrected |
| `flutter analyze --no-pub` | Final PASS: no issues |
| `flutter test --no-pub test/features/library --reporter expanded` | Final PASS: 264 tests, zero skips |
| `flutter test --reporter expanded` | PASS: 1819 passed, 4 existing optional skips |
| `flutter test --no-pub --reporter expanded` | Final PASS after constructor-style fix: 1819 passed, 4 existing optional skips |
| `dart run tool/ci/check_reader_fixtures.dart` | PASS; manifests/privacy guard, exit 0 |
| `git diff --check` | PASS |

Eleven new test cases cover all three reviewer suggestions. The four skips are
three optional local-book vector/layout/support tests because local input or
`build/oracle-local/` is absent, and the native CFI export because
SHIORI_NATIVE_CFI_OUT is unset. No library test is skipped. The fixture command
prints build-hook progress on stderr under PowerShell but exits successfully.
Command logs are ignored `build/phase-c-followup-*.log` files.

## Open issues

None within this follow-up scope. Existing broader S3 device/LAN and later-phase
acceptance gates remain outside these host regression tests.
