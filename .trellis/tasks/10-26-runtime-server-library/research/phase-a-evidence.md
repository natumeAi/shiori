# S3 Phase A evidence

## A1 dependencies and SQLite

Date: 2026-10-26. Scope: dependency resolution and test-only Windows
feasibility. **Verified** below means an inspected resolved source or an
executed host check; **Inference / unverified** identifies platform conclusions
that have not been exercised. This does not complete Phase A or its iOS gate.

### Resolved versions, licences and lockfile

**Verified:** initial branch `ios-build/s3-runtime-server`, HEAD `f94664c`.
The sole initial change was the existing task activation in `task.json`;
it was preserved. Toolchain: Flutter 3.47.7, Dart 3.13.5, framework
`abaf9c5237`, engine revision `deb287481e`.

Package source citations below are relative to
`%PUB_CACHE%/hosted/pub.dev/` (the pub cache).
Line numbers refer to the actual resolved files, not floating online docs.

| Package | Resolved version / constraint | Licence from cached LICENSE |
| --- | --- | --- |
| sqlite3 | 3.8.0 / direct `^3.8.0` | MIT: `sqlite3-3.8.0/LICENSE:1`, grant at `:5`, notice at `:12` |
| crypto | 3.0.7 / direct `^3.0.7` | BSD-3-Clause: `crypto-3.0.7/LICENSE:3`, three conditions at `:7`, `:9`, `:13` |
| native_toolchain_c | 0.19.3 / transitive | BSD-3-Clause: `native_toolchain_c-0.19.3/LICENSE:3`, `:7`, `:9`, `:13` |
| hooks | 2.2.0 / transitive | BSD-3-Clause: `hooks-2.2.0/LICENSE:3`, `:7`, `:9`, `:13` |
| record_use | 1.1.1 / transitive | BSD-3-Clause: `record_use-1.1.1/LICENSE:3`, `:7`, `:9`, `:13` |

**Verified:** the pub.dev versions listing checked this session reports 3.8.0
as the newest stable sqlite3 release; it resolves with the existing SDK and
pins. Its own SDK requirement is `>=3.10.0 <4.0.0`
(`sqlite3-3.8.0/pubspec.yaml:9`).

**Verified lockfile diff:** 21 added / 5 removed lines: add sqlite3 and
native_toolchain_c; promote crypto from transitive to direct without changing
its version/hash; update hooks 2.0.2 -> 2.2.0 and record_use 0.6.0 -> 1.1.1
with their hashes. These are required dependency-family changes:
`sqlite3-3.8.0/pubspec.yaml:33` requires hooks `^2.2.0`, `:35` requires
native_toolchain_c `>=0.17.5 <0.20.0`, and `hooks-2.2.0/pubspec.yaml:27`
requires record_use `^1.0.0`. All other locked package versions/hashes and SDK
bounds are unchanged. No SDK constraint, codegen constraint or other direct
pin was changed; no sqlite3_flutter_libs, ORM or additional direct driver.

### Native hook: inspected facts

**Verified source:** default installation bundles SQLite through hooks
(`sqlite3-3.8.0/README.md:8`); the supported prebuilt targets include device
iOS arm64, simulator arm64/x64 and Windows arm64/x64/x86 (`README.md:121`).
`doc/native.md:1` only identifies the native FFI libraries; hook configuration
and provenance are documented in `doc/hook.md`.

| Target / mode | Mechanism in the resolved source |
| --- | --- |
| iOS default | Download a prebuilt shared library, not an app-time SQLite source compilation or system-library lookup. Device asset is `libsqlite3.arm64.ios.dylib`; simulator is selected separately. |
| Windows default | Download a prebuilt DLL; this host selected `sqlite3.x64.windows.dll` and registered the downloaded file as bundled `sqlite3.dll`. |
| Explicit `source: source` | Compile user-supplied local C sources with `CBuilder.library`; optional includes, defines and linker/compiler flags are supported. |
| Explicit `source: system` | Emit an external system dynamic-loading asset without downloading or compiling a SQLite library. |

Source anchors (all under `sqlite3-3.8.0/`):

- `lib/src/hook/compile/description.dart:62`: missing `source` / `sqlite3`
  chooses GitHub precompiled assets; `:78` chooses system lookup;
  `:90` handles local source paths.
- `hook/build.dart:19`: download precompiled library; `:29` registers
  `DynamicLoadingBundled`; `:69` builds the optional C source mode;
  `:124` emits only a link mode for an external library.
- `lib/src/hook/assets.dart:52`: distinguish iPhoneOS / simulator;
  `:97` constructs release filenames; `:193` and `:199` enumerate ABIs.
- `lib/src/hook/asset_hashes.dart:9`: release tag `sqlite3-3.8.0`;
  `:29` pins the device iOS asset and `:60` pins Windows x64.
- `lib/src/hook/compile/description.dart:201`: stream and verify downloaded
  bytes with SHA-256; `:238` caches and rechecks existing files;
  `:310` uses an HTTP client respecting proxy environment configuration;
  `:343` defines the GitHub release download URL pattern.
- `doc/hook.md:13`: prebuilt shared libraries built from upstream in GitHub
  Actions, with hashes shipped in the package; `:217` documents immutable
  releases, attestations and shared hook-cache location (`:224`).

**Verified Windows execution:** the generated hook input selected `windows`
and `x64`, with empty user defines. The hook output status was `success` and
the asset link mode was `dynamic_loading_bundle`. The downloaded `sqlite3.dll`
SHA-256 was
`3a29878d0936510af0f563dfc7668c561c92f7ebe1d9fef95975f721dc01b590`,
matching `lib/src/hook/asset_hashes.dart:60`. These ignored runtime outputs
are under `.dart_tool/hooks_runner/sqlite3/8e04c28b44/{input,output}.json`
and `.dart_tool/hooks_runner/shared/sqlite3/build/download-3a29878d/`.
No DLL is added to source control.

### System-SQLite option and build requirements

**Verified configuration support:** `sqlite3-3.8.0/doc/hook.md:86` documents
`hooks.user_defines.sqlite3.source: system`; `:150` documents platform maps
for `source` (so iOS can use the system library while Windows keeps the
default). A candidate for the later iOS gate is:

```yaml
hooks:
  user_defines:
    sqlite3:
      source:
        ios: system
        default: sqlite3
```

This example is evidence only; it has **not** been applied to the app pubspec.
`lib/src/hook/compile/description.dart:43` implements per-OS selection;
`:82` defaults the system name to `sqlite3`; `:150` resolves a platform
library name and returns `DynamicLoadingSystem` (`:163`). The resolved
`code_assets-1.2.1/lib/src/code_assets/code_asset.dart:161`, `:175`, `:195`
and `:205` make that name `libsqlite3.dylib` on iOS. A `name` override can
also pass a library path as-is (`description.dart:154`, `doc/hook.md:135`).
This is runtime dynamic lookup, not an instruction to statically link SQLite.
`process` / `executable` are separate modes for already available symbols
(`description.dart:167`, `doc/hook.md:106`).

**Verified source / derived requirements:** default hooks need network access
to download an uncached release asset (and pub needs package access); a cached
hash-matching asset is reused. The default SQLite hook does not invoke a C
compiler or Xcode: only the explicit source mode reaches `CBuilder.library`
(`hook/build.dart:18`, `:69`, `:123`). System mode emits no downloaded file.
**Inference:** once Dart packages are resolved, system mode should need no
SQLite download or C compiler. Source mode requires a target C toolchain and
local source files; iOS source builds require Apple's toolchain/SDK, whose
resolver uses `xcrun` and iPhoneOS SDK lookup
(`native_toolchain_c-0.19.3/lib/src/native_toolchain/xcode.dart:17`, `:33`, `:48`).
Regardless of SQLite mode, building the iOS app still requires macOS/Xcode
(project `tool/ci/build_ios_unsigned.sh:2`, `:68`, `:86`); this was not run here.

**Inference / unverified:** the iOS-only system configuration is a candidate
with fewer packaged artifacts. Windows default-hook tests do not establish
iOS system-library discovery, exported symbols, compile options, signing or
installation. No iOS mode is selected by A1.

### Executed proof and commands

**Verified:** `test/core/storage/sqlite_feasibility_test.dart` contains four
tests, each using a fresh temporary directory and a file-backed database.
Every handle closes in `finally`; teardown recursively deletes its own temp
directory. It proves committed rows survive reopen, a real primary-key
failure rolls back earlier writes, v0 -> v1 migration is guarded by
`PRAGMA user_version` under a transaction write lock, and rerunning v1
preserves data. A failed migration after DDL, DML and a version write leaves
no new table and restores version 0 and unrelated sentinel data after reopen;
retry succeeds. A version-2 fixture is refused before writes, preserving
exact file bytes and the directory file set. Observed defaults, asserted on
initial open and reopen: `journal_mode=delete`, `synchronous=2` (FULL).
This proves handled SQL failure/reopen, not process-kill or power-loss recovery.

Commands used `D:/DevTools/flutter/bin/{flutter,dart}.bat` from the repo root:

| Command | Result |
| --- | --- |
| `git status --short`, `git log -1 --oneline`, `git branch --show-current` | PASS: expected initial state |
| `flutter --version` | PASS: 3.47.7 / Dart 3.13.5 |
| `flutter pub get` | PASS: compatible resolution, changes listed above |
| `dart format test/core/storage/sqlite_feasibility_test.dart` | PASS: formatted; final run 0 changes |
| `flutter analyze` | PASS: no issues (including final revision) |
| `flutter test test/core/storage/sqlite_feasibility_test.dart --reporter expanded` | PASS: 4 passed, 0 skipped/failed (including final revision) |
| `flutter test --reporter expanded` | PASS: final revision 989 passed, 1 skipped, 0 failed |
| `dart run build_runner build` | PASS: 34 generated outputs, no tracked generated-file diff |
| `dart format --output=none --set-exit-if-changed lib test` | PASS: 244 files, 0 changes |
| `git diff --check` | PASS |

The one skip is the existing opt-in native CFI export test because
`SHIORI_NATIVE_CFI_OUT` is not set; A1's four tests have no skips.

An ancillary PowerShell `Invoke-RestMethod` pub metadata lookup failed with a
TLS/receive error. The pub.dev versions listing was checked through web search;
actual `flutter pub get` and native-hook download both succeeded. No workaround,
TLS bypass or package/pin change was needed. Existing optional local-reader
tests ran through the unchanged full suite; no book payloads, names or raw
reader output are copied into this evidence.

### Hosted iOS gate still required before Phase B

**Unverified / required:** exercise the candidate iOS system mode first and
compare with default bundling as necessary. Through the existing hosted route,
prove compilation, inspect the IPA for actual native packaging/dependencies,
then use the selected S1 signing/install route on the iPhone. Under Application
Support, run open / commit / close / reopen and byte-preserving future-schema
refusal; record actual journal/synchronous settings and runtime SQLite
compatibility. Prove installation under the existing identity and retention
through the chosen signing/update route. The host pass cannot waive this gate;
driver failure returns S3 to planning. A1 adds no device self-check, CI changes,
product storage, UI or `lib/` code and performs no push, stage or commit.
The dependency-table spec update is left to the parent integration owner:
this assignment explicitly excludes `.trellis/spec/**` edits.

## A2 server response fixtures

Date: 2026-10-26. Scope: synthetic read-response bodies, HTTP metadata and
deployment URL vectors only. No product DTOs, live HTTP or real server data.

### Files added

Added 28 files under `test/fixtures/server/`: 25 JSON files, one HTML file,
`README.md` and `server_fixtures_test.dart`. The README's per-file table and
`manifest.json` enumerate all 26 response/vector/metadata payload files.

- Five health bodies: usable, unconfigured, DB-check failure, wrong service,
  and unknown additive field.
- Five valid snapshot bodies: typical, minimal invalid-case baseline, empty,
  explicit timestamp offset, and unknown fields at seven nesting levels.
  Typical includes root books, books inside a folder, an empty folder,
  ordered bookIds/previewBookIds/bookCount, recent ReadingPosition objects,
  null/zero/fractional progress and separate book:7/folder:7 shelf identities.
- Nine invalid snapshots: unsupported schema, missing required nullable
  author, unsafe/zero/fractional IDs, duplicate book ID, missing folder book,
  missing shelf record and wrong shelf enum. All are standalone bodies.
- Full `{book}` detail, exact missing-book 404, malformed-book-ID 400,
  sanitized 500 and invented HTML proxy/login page.
- Manifest: snapshot 200/304, file 200 with length/chunked/no validators,
  file 304, unexpected 206/412/416, and status/body associations for errors.
  A bodyless response uses `bodyKind: absent`, with no JSON/body-file stand-in.
- URL vectors: nine accepted roots and 17 rejected inputs. Every accepted
  root supplies five literal expected request URLs, including an encoded
  cover path/query. Cases cover prefix slash, explicit/default ports, IPv6,
  encoded path boundaries, whitespace/case and literal dot normalization.
  Every rejection declares zero traffic; no resolver is implemented here.

All content and metadata values are invented; endpoint examples use only
documentation-reserved hosts/addresses. File descriptors intentionally
contain no EPUB bytes; later download tests supply generated EPUB payloads.
The existing reader fixtures, A1 files, task planning files and specs were
preserved. This section is the only edit to the existing evidence file.

### Source citations and contract findings

Verified reference HEAD before editing and after checks:
`a4bda23fd3e82e285a22566d88576e67d3e8756b`; `git status --short` empty.
All following paths belong to the read-only `D:/Projects/lan-reader` checkout.
README keys map each individual fixture to these file:line anchors:

- Health: `server/src/app.ts:73`, `server/src/db/database.ts:93`,
  `server/src/http/requestInput.ts:33`.
- Snapshot: `shared/src/api.ts:113`, `shared/src/librarySnapshot.ts:19`,
  `shared/src/book.ts:60`, `shared/src/folder.ts:30`,
  `shared/src/shelf.ts:22`, `shared/src/reading.ts:22` and `:60`;
  `server/src/services/librarySnapshot.ts:37`, `:93`, `:107`, `:118`,
  `:132`, `:137`; `server/src/services/readingLibrary.ts:28` and `:49`.
- Detail/cover: `shared/src/book.ts:12`, `shared/src/api.ts:29`,
  `server/src/services/bookLibrary.ts:97` and `:121`,
  `server/src/routes/books.ts:130` and `:137`.
- Errors: `shared/src/api.ts:129`, `server/src/http/httpError.ts:28`
  and `:32`, `server/src/app.ts:105`,
  `server/src/http/requestInput.ts:71`.
- Raw timestamps: `server/src/db/migrations/001_initial_library_schema.sql:5`,
  `:23`, `:33`. Explicit-offset acceptance is the client's design section 4
  contract; it is not a claim about SQLite CURRENT_TIMESTAMP formatting.
- Invalid cases: `shared/src/librarySnapshot.ts:17`, `:48`, `:57`, `:66`,
  `shared/src/decode.ts:35` and `:42`, plus S3 design section 4's stricter
  nullable presence, safe-positive-ID and join invariants. These deliberately
  exceed the permissive reference decoder, as contracts.md already explains.
- Headers: `server/src/routes/library.ts:20`,
  `server/src/services/librarySnapshot.ts:33`,
  `server/src/routes/books.ts:207`, `server/src/app.ts:62` and `:65`.
  Inspected installed dependency evidence: `node_modules/send/index.js:514`,
  `:549`, `:564`, `:583`, `:757`; `node_modules/etag/index.js:126`.
  These dependencies are installed evidence, not tracked reference source.
- URLs: the same route anchors and cover encoder above; prefix-preserving
  joining, canonicalization and rejection vectors follow task design section 2.
  Cover query, chunked and no-validator cases are synthetic client/intermediary
  scenarios, not claims that the direct formatter/sendFile emits them.

Contradictions with `research/contracts.md`: **none**. Two clarifications to
the fixture request are documented in the README: checkDatabase returns `ok`
or throws, so DB failure is HTTP 500 `{error:"Internal Server Error"}` rather
than a fabricated `database:"error"` health body; Folder has no parent-folder
field, so nesting is represented as book membership, not a folder tree.
Detail 404 has no code field. Recent progress includes chapterCount/index.

### Verification

Commands used `D:/DevTools/flutter/bin/{dart,flutter}.bat` from repository root.

| Command | Result |
| --- | --- |
| Reference `git rev-parse HEAD` and `git status --short` | PASS: pinned and clean before/after |
| `dart format test/fixtures/server/server_fixtures_test.dart` | PASS: formatted one file |
| `dart format --output=none --set-exit-if-changed test/fixtures/server/server_fixtures_test.dart` | PASS: 0 changes |
| `flutter analyze` | PASS: no issues |
| `flutter test test/fixtures/server/server_fixtures_test.dart --reporter expanded` | PASS: 5 passed, 0 skipped/failed |
| `dart run build_runner build` | PASS: 0 generated outputs |
| `flutter test --reporter expanded` | PASS: 994 passed, 1 skipped, 0 failed |
| `git diff --check` | PASS |

The skip remains the existing opt-in native CFI export test with
`SHIORI_NATIVE_CFI_OUT` unset. New tests verify inventory/README parity and
JSON parsing, isolated named invalid invariants, ordered folder membership,
typed shelf keys, progress/raw timestamps, full detail distinctions,
bodyless 304/validator descriptors and the completeness of URL vectors.
They are fixture-integrity checks, not DTO, downloader or resolver tests.
No staging, commit, push, branch switch or reference mutation was performed.
No A2 open issue; later phases still own product implementation and live/device
compatibility evidence. A1's hosted iOS SQLite gate remains outside A2.

## A3 archive index and file-backed open

Date: 2026-10-26. **COMPLETE for A3: native bounded archive path verified on
Windows.** The earlier dependency gate is resolved by the orchestrator's
content-integrity decision below. The native path accepts valid level-1 streams
and returns only bounded, exact-length, CRC-verified entry bytes. Full tests and
analysis pass. No dependency/package-cache modification, padding or custom
decoder was needed. Worker integration and iPhone resource evidence remain
later work; this completes the archive substep only.

### fflate 0.8.2 reference behavior

Inspected and executed the installed `tool/oracle/node_modules/fflate` 0.8.2.
All source anchors below refer to `lib/node.cjs` inside that directory:

- Duplicate names: `unzipSync` traverses central headers at lines 2681-2683
  and assigns `files[fn]` at 2691/2693. The final physical entry wins.
  A generated duplicate containing `first`, then `last`, returned `last`.
- CRC: `zh` (1854-1857) does not return the central CRC field;
  `unzipSync` (2682-2696) performs no CRC comparison. A generated archive
  with CRC 123 and content `hello` still returned the five original bytes.
- Ordinary deflate truncation: `inflateSync` (1223-1224) passes `{i: 2}`
  into `inflt`. Its EOF checks throw error 0 at 269-270, 337-338,
  353-354 and 385-386. Generated three-byte and nine-byte prefixes of the
  ten-byte stream `cb48cdc9c957c8409000` throw `unexpected EOF`, code 0.
- Exceptions to strict rejection: `inflt` (233-234) returns the supplied
  buffer for empty compressed input. Since `unzipSync` supplies `new u8(su)`
  (2693), empty deflate with declared length 17 returned 17 zero bytes.
  Valid deflate producing five bytes with declared size 20 returned five;
  stored data of length two with declared size five returned two (2691).
  The output selection at 408 explains the short deflate result. These are
  observations, not acceptable corrupt-content behavior for S3-R7.

### Final design and intended divergences

The initial A3 implementation (superseded by the directory-metadata fix below)
indexes `ZipDirectory.fileHeaders`, with
an append-bounded header list checking every physical entry and its declared
size/total before expansion. It retains the final header per exact name;
symlink mode bits never trigger an open-time read. It validates directory
framing/counts/ranges and local signatures, rejects encryption and methods
other than stored/deflate, and checks emitted size and central CRC before
returning bytes. The app-owned sink checks capacity before every write.
The sum of declared sizes therefore bounds one expansion of all physical
entries; it does not limit repeated reads or caller-retained copies.

`openFile` checks length before opening `InputFileStream`; entry views share
the original file handle. Synchronous, idempotent `close()` releases it;
in-memory close is a no-op. ReaderWorkGuard checks remain at open/read/close.
Both success-close deletion on Windows and failed-open cleanup passed.

Reads use `ZipFile.decompress` -> `decodeLimited` -> `NativeChunkDecoder`
(platform zlib), targeting the app-owned bounded sink. Zero-length compressed
deflate is rejected even when its declared output is zero; a valid deflate
encoding of empty content remains readable. Exact emitted length and CRC-32
are checked after decoding and before any bytes are returned. Error messages
contain only fixed descriptions/error classes, never entry content or paths.

Rejecting CRC mismatch, short output and empty compressed input deliberately
differs from the permissive fflate cases above, as S3-R7 requires recoverable
failure. The archive paragraph of `reader-engine.md` now documents this path,
ownership and the accepted zero-output-tail divergence.

### Resolved dependency gate and rejected block path

Package root: `%PUB_CACHE%/hosted/pub.dev/archive-4.5.2`.

1. The original native candidate used `ZipFile.decompress` and the bounded
   sink, then exact length and CRC checks. All 31 initial archive tests passed.
   Adding every-proper-prefix coverage exposed acceptance of the nine-byte
   stream `cb48cdc9c957c84090`: it returned all 17 original bytes, so both
   length and CRC passed despite the missing final byte. fflate rejects it.
   NativeChunkDecoder creates `ZLibCodec(raw: raw)` at
   `lib/src/codecs/zlib/_native_chunk_decoder_io.dart:52` and closes it at
   56-62; its extra trailer checks apply only to gzip, not raw ZIP deflate.
2. Selecting the package's public `Inflate.lazy` / `inflateBlock` rejects
   that truncation. A targeted archive/oracle/unit run passed 79 tests before
   an additional valid-stream regression was added. The memory tool then
   failed during its small ZipEncoder-generated warm-up entry.
3. Independent package-only reproduction confirms the alternative is also
   unsuitable: `dart:io` ZLibEncoder(raw: true, level: 1) encodes 1024 zero
   bytes as `63601805a321301a0223350400`. Node zlib and fflate both decode it
   to 1024 bytes. `Inflate.lazy(InputMemoryStream(bytes), output:
   OutputMemoryStream())`, driven solely by `inflateBlock()`, throws
   `Invalid deflate data` at `lib/src/codecs/zlib/inflate.dart:55`.
   Its Huffman lookup requires `maxCodeLength` buffered bits and returns -1
   at EOF (210-219), then `_decodeHuffman` propagates failure (328-333).
   This is reproduced before EpubArchive's sink or EOF check participates.

**Orchestrator decision (Claude, recorded for the user on resumption):**
S3-R7's integrity contract is "never return content that differs from the stored
entry; bounded output; corrupt or incomplete content fails recoverably". The
native path's accepted nine-byte prefix lacks one final byte carrying no output;
its result is byte-identical to the original and passes exact length and CRC-32.
This satisfies that contract. Accept this narrow divergence from fflate, which
throws; do not pursue strict end-of-stream detection or a custom inflater.

The block path is **rejected** because it rejects ordinary valid level-1
deflate, before app verification participates. Its package-only reproduction
and source evidence above are retained as the reason for that rejection.
Product/tests contain no `Inflate.lazy` or `inflateBlock` calls; native
`ZipFile.decompress` is selected. No package/lockfile change was made here.

Both memory and file-backed tests check every proper prefix of a generated
deflate entry: reading either throws `ParseException` or returns bytes identical
to the original, with equal declared length and CRC. The explicitly named
`native accepts missing zero-output final byte with verified content` test
documents the accepted case and rejects the same prefix with incorrect length
or CRC. The valid level-1 regression passes; oversized output, short output,
CRC mismatch and empty compressed input still fail. Every other existing test
expectation and all oracle vectors/fixtures remain unchanged.

### Memory measurement

`tool/reader/archive_memory_probe.dart` streams stored-entry generation and
compares `openFile` with in-memory `open` in a fresh process per measurement.
Each process warms the native deflate/read/checksum path, records baseline RSS,
opens the archive and reads three 1 MiB entries (first, middle, last). Generation
reuses one 1 MiB block instead of retaining the large archive in the parent.
Host: Windows, Dart 3.13.5; RSS values below are **bytes**.

| Archive / API | Baseline RSS | Open RSS | Sample RSS (3 MiB read) | Process max RSS |
| --- | ---: | ---: | ---: | ---: |
| 20,973,362 bytes / `openFile` | 245,534,720 | 254,279,680 | 243,097,600 | 299,536,384 |
| 20,973,362 bytes / `open` | 244,871,168 | 279,674,880 | 264,454,144 | 299,548,672 |
| 209,733,802 bytes / `openFile` | 241,991,680 | 239,898,624 | 241,815,552 | 299,450,368 |
| 209,733,802 bytes / `open` | 242,913,280 | 448,262,144 | 451,616,768 | 451,624,960 |

Open deltas were +8,744,960 / -2,093,056 bytes for `openFile` and
+34,803,712 / +205,348,864 bytes for `open` (20 MiB / 200 MiB respectively).
Sample deltas were -2,437,120 / -176,128 bytes for `openFile` and
+19,582,976 / +208,703,488 bytes for `open`. Negative deltas reflect process
GC/working-set variation, not negative archive allocation. Process max includes
startup/JIT and warm-up before the baseline: observed file-backed high water
was 299,536,384 bytes (about 285.7 MiB) across these runs, versus 451,624,960
bytes (about 430.7 MiB) for the 200 MiB memory open. File-backed RSS did not
grow with the tenfold payload increase in this experiment. This is host
archive-only evidence, not a hard RSS ceiling, complete worker budget or iPhone
resource claim.

Both archive sizes completed. The probe's `finally` cleanup reported
`Temporary archives deleted.`; a subsequent temporary-directory check found
no `shiori-archive-rss-*` directory. The earlier block-path warm-up failure
produced no usable measurement and is superseded by these native results.

### Commands and results

All Dart/Flutter commands used `D:/DevTools/flutter/bin/*.bat`.

| Final command / check | Result |
| --- | --- |
| `flutter test --no-pub test/features/reader/data/epub/epub_archive_test.dart --reporter expanded` | PASS: 37 passed, 0 failed |
| `flutter test --no-pub --reporter expanded` | PASS: 1031 passed, 1 skipped, 0 failed |
| `dart run tool/ci/check_reader_fixtures.dart` | PASS: manifests and EPUB privacy guard |
| `dart run tool/reader/archive_memory_probe.dart` | PASS: both sizes/APIs, three samples each; temp files deleted |
| `dart format` on the four A3 Dart files | PASS |
| `flutter analyze --no-pub` | PASS: no issues |

The skip remains the opt-in native CFI export test with `SHIORI_NATIVE_CFI_OUT`
unset. The full suite includes the unchanged pre-existing tests; all 14
pre-existing block-path failures now pass. No code generation was needed
because no generated declarations changed. Local validation logs are under
ignored `build/a3-native-{flutter-test,memory}.log`; they are not fixture or
public evidence payloads.

Historical feasibility results are retained for context: initial native archive
tests passed 31; the old strict-prefix expectation failed on 9/10 in both modes;
block-path archive/oracle/EPUB units passed 79 before the level-1 regression;
that regression failed twice; the block-path full suite had 1013 passed,
1 skipped and 16 failed (2 new, 14 existing). These failures explain the
rejected block path and are superseded by the final native run above.

No A3 open issue remains. A1's hosted iPhone SQLite gate and later worker/device
proof remain outside this substep. A1/A2 files and git index/branch state were
left alone. No staging, commit, push, reference-checkout mutation or sub-agent
dispatch occurred.

### A3 fix: directory metadata bounds

Date: 2026-10-26. **Verified on Windows; supersedes the initial A3 directory
admission mechanism above.** Independent review established that
`ZipDirectory.read` hydrates a central header and its referenced local header
before adding it to the bounded list. A 107,053-byte ZIP with 1,000 central
entries referencing one local header with a 60,000-byte extra therefore copied
about 60 MB of extras before application admission could help. The reviewer's
reported RSS increase was about 57 MB; at 20,000 entries the copied extras
would be about 1.2 GB. These original exploit figures are review evidence,
not a second execution of the vulnerable implementation during this fix.

**Decision:** `epub_zip_directory.dart` is a private part of `epub_archive.dart`.
Its app-owned reader validates all physical entries before creating any
`ZipFileHeader`/`ZipFile`. It reads fixed fields through range-checked shared
stream views, keeps only count-bounded offsets/ranges, and scans at most
65,557 tail bytes for a comment-framed EOCD ending at EOF. The package no
longer searches for EOCD: after the complete preflight, the app directly calls
`ZipFileHeader.read` at each validated central record. This prevents a second
parser from selecting a different directory. Package source audited under
`%PUB_CACHE%/hosted/pub.dev/archive-4.5.2/`: `lib/src/codecs/zip/zip_directory.dart`,
`zip_file_header.dart` and `zip_file.dart` in that same directory.

| Admission resource | Default / rule |
| --- | --- |
| Central-directory bytes | `EpubLimits.maxDirectoryBytes`: 16 MiB, checked before creating its stream view |
| Variable wire metadata | `maxMetadataBytes`: 8 MiB total; central/local names and extras, entry comments and archive comment; charged before reading variable fields |
| Physical entries / expanded bytes | Existing 20,000 / 64 MiB per entry / 1 GiB total; all overwritten entries count; both EOCD counts must match the physical walk |
| Local references | Unique offsets before the central directory; complete fixed/variable local headers and central-declared compressed data must fit inside the archive |
| Overlap | Sort complete local-header/data ranges and reject intersections, including optional signed/unsigned descriptors; no range may cross into the central directory |

At 20,000 entries, fixed central headers consume 920,000 bytes. The 8 MiB
variable budget allows about 419 bytes per physical entry across both names,
extras and comments, with normal short EPUB resource paths leaving room for
extras. The independent 16 MiB directory limit still applies if an injected
entry-count limit is raised. These are explicit engineering admission limits,
not total-process RSS limits; strings/objects and native decoder/JIT overhead
remain additional bounded or host-dependent costs.

ZIP64 is explicitly rejected using a fixed content-free `ParseException`
reason: `ZIP64 archives are not supported`. Detection covers EOCD counts/sizes/
offset sentinels, central/local size and central offset/disk sentinels, the
ZIP64 EOCD/locator and extra-field ID 1 in either header. Inspection of all 16
EPUB fixtures under `assets/reader_fixtures` and `test/fixtures` found no ZIP64
records/extras; no existing test or fixture needed changes. Duplicate names at
distinct offsets still resolve last-wins, including reverse central order.
Stored/deflate, inert symlinks, native bounded decoding, exact length/CRC,
ReaderWorkGuard, file ownership/cleanup and in-memory no-op close are unchanged.

**Tests:** 51 archive tests pass (37 existing plus 14 new cases across memory
and file-backed paths). Added assertions cover the exact 107,053-byte review
sample with zero expansion limits and its 20,000-reference variant; exact and
one-byte-over directory/metadata budgets; all variable metadata categories and
overwritten duplicates; nested local headers, overlapping data/descriptors and
directory crossing; out-of-archive/central offsets; unsigned descriptors;
reverse directory order; maximum archive comment/embedded EOCD signature;
truncated comment framing; and explicit ZIP64 rejection. Existing assertions,
oracle fixtures/vectors, worker and diagnostics code remain unchanged.

**RSS:** final standalone probe run on Windows, Dart 3.13.5; fresh child per
row after the existing small native-deflate warm-up. All values are bytes.
Ordinary rows read 3 MiB after open. Hostile rows use zero entry/total output
limits and are rejected at open, without any entry expansion.

| ZIP / API | Baseline RSS | Open or rejection RSS | Delta | After 3 MiB reads | Process max RSS |
| --- | ---: | ---: | ---: | ---: | ---: |
| 20,973,362 bytes / file | 243,486,720 | 252,891,136 | +9,404,416 | 240,545,792 | 299,986,944 |
| 20,973,362 bytes / memory | 246,087,680 | 261,001,216 | +14,913,536 | 262,864,896 | 300,216,320 |
| 209,733,802 bytes / file | 244,461,568 | 238,989,312 | -5,472,256 | 242,032,640 | 300,228,608 |
| 209,733,802 bytes / memory | 244,461,568 | 447,803,392 | +203,341,824 | 450,531,328 | 450,904,064 |
| 107,053 bytes, 1,000 aliases / file | 246,038,528 | 257,495,040 | +11,456,512 | rejected | 300,146,688 |
| 107,053 bytes, 1,000 aliases / memory | 246,149,120 | 255,844,352 | +9,695,232 | rejected | 300,179,456 |
| 1,000,053 bytes, 20,000 aliases / file | 247,656,448 | 258,646,016 | +10,989,568 | rejected | 300,163,072 |
| 1,000,053 bytes, 20,000 aliases / memory | 245,059,584 | 256,126,976 | +11,067,392 | rejected | 300,634,112 |

Each hostile child's max RSS was already reached during pre-baseline warm-up
and did not increase during rejection. Current-RSS deltas include JIT/GC and
working-set variation, not just Dart allocations; the 20-fold alias increase
does not multiply retained extras. File-backed open remains independent of
payload size in this experiment. These are host archive measurements, not an
iPhone or whole-worker memory claim. All generated temp archives were deleted.

| Command | Result |
| --- | --- |
| `dart format` on the five changed Dart files | PASS, final run 0 changes |
| `flutter analyze --no-pub` | PASS, no issues; first run found one missing-braces lint, corrected and rechecked |
| `flutter test --no-pub test/features/reader/data/epub/epub_archive_test.dart --reporter expanded` | PASS: 51 passed, 0 failed/skipped |
| `flutter test --no-pub --reporter expanded` | PASS: 1,094 passed, 1 existing opt-in native-CFI skip, 0 failed; includes unchanged oracle/worker/diagnostics tests |
| `dart run tool/ci/check_reader_fixtures.dart` | PASS: manifests and EPUB privacy guard |
| `dart run tool/reader/archive_memory_probe.dart` | PASS: ordinary 20/200 MiB and hostile 1,000/20,000 aliases, both APIs, temp cleanup |
| `git diff --check` | PASS |

Local ignored logs: `build/a3-directory-flutter-test.log` and
`build/a3-directory-memory-final.log`. No codegen declarations changed.
No fix-specific open issue remains. This change is confined to the seven
authorized files (including the new private helper); no dependency/cache,
git index/branch, worker, diagnostics, fixture or vector mutation, staging,
commit, push or sub-agent dispatch occurred.

## A4 duplicate-name oracle fixture

Date: 2026-10-26. **COMPLETE for A4.** The generated synthetic EPUB contains
two distinct physical copies each of `EPUB/chapter.xhtml` and
`EPUB/package.opf`. Authoritative WebKit extraction, the Chromium cross-check
and Dart source/package/canonical/native-CFI comparisons select the last copy.

### Builder and fixture

`tool/oracle/src/build-fixtures.mjs` accepts optional `fixture.json` entries
`rawEntries: [{name, text}]`. Each UTF-8 copy precedes the normal entry with
that name; multiple earlier copies retain declaration order. Targets must
already exist and cannot be `mimetype`. The ordinary `zipSync(entries)` path
is unchanged for every pre-existing fixture. For duplicates only, the builder
assembles fflate's single-entry ZIP records, adjusting central-directory
offsets and the final directory count/size/offset. CRCs, compression options,
fixed local-calendar DOS timestamps and ordinary local headers still come
from fflate. This keeps `mimetype` first, stored, with its actual sizes in the
local header and no extra fields or streaming data descriptor.

Added `tool/oracle/fixtures/duplicate-entries/{fixture.json,README.md,
EPUB/chapter.xhtml}`, `assets/reader_fixtures/duplicate-entries.epub` and
`test/fixtures/reader/oracle/duplicate-entries.webkit.json`. The asset manifest,
oracle summary and cross-engine fixture inventory each gained only the new
record. Registered the ID in the Dart oracle test's two comparison groups and
the verifier's existing expected-fixture list; no reference or product code
changed in A4.

The 3,451-byte EPUB has eight physical entries and six unique names. Python's
ZIP reader verified both distinct copies, every CRC, all fixed timestamps and
the first stored `mimetype` local header. Chapter copies are 136 and 395 bytes;
OPF copies are 649 and 676 bytes. The stale chapter has one discarded paragraph;
the final chapter has a section, heading and two different paragraphs. The
stale OPF has `/6/2[ref-stale]`; the generated final OPF has
`/8/2[ref-chapter]`. The new vector contains one section, 115 CFI samples and
canonical length 92 with signature `fnv1a64:c4c16b4708a36029`.

Three ignored first-copy control archives were generated under `build/a4/`:
chapter-only, package-only and both. Running the existing Dart comparison
helpers against the committed vector produced source/package mismatches and
native-CFI failures for each control. The stale chapter instead has canonical
length 15 and signature `fnv1a64:ca957899b3e3e8df`; the stale package changes the
CFI base independently. These controls changed no `lib/` or committed payload.

**Intentional S2 behavior change:** before A3, archive 4.5.2's coalescing
`ZipDecoder` retained the first duplicate's content. A3's raw-directory index
now selects the last physical occurrence, matching reference fflate. This also
changes duplicate-name parsing through the shared S2 probe path. A4 records
that compatibility correction with authoritative vectors; it does not bless
changes to any pre-existing vector or change other S2 expectations.

### Byte-identity proof

Before editing, saved per-file SHA-256 baselines and output backups under
ignored `build/a4/`. After regeneration, all 13 pre-existing EPUB archives,
all 13 pre-existing WebKit vectors and `unicode-table.json` were byte-identical.
Removing only `duplicate-entries` from each regenerated manifest/summary/
cross-engine fixture list reproduced its entire previous JSON value.
`git diff --stat`/`--numstat` showed no pre-existing EPUB/vector/Unicode diff;
the three inventory diffs are additions only. SHA-256 checks also preserved
all other baseline files, including existing fixture sources, reference,
`lib/`, specs, pubspec, task artifacts and A1-A3 work. Existing evidence bytes
are preserved as the exact prefix before this appended section.

For reproducible compact evidence, hash the UTF-8 concatenation of sorted
`<repository-relative-path> <sha256>\n` lines for each original set:

- 13 EPUB archive ledger SHA-256:
  `6dd6a9db9914b539b08ecf4c3119d0610612003f7ed0df3c7d1f96717d850ba8`.
- 13 WebKit vector ledger SHA-256:
  `1785f7f54af5edd11aadb8c1102814fdc5f6ffa66c770fa78e4cb3b4ea79005c`.
- New EPUB SHA-256:
  `9b681950634971400b12cbf64e1036748a5948b8e816ae414e51c858c68a689b`.
- New WebKit vector SHA-256:
  `53b88a98aa6cb5bcc021c31539d8b57ac6992142b5ce23fc708cb5aa42ef1014`.

### Commands and results

Oracle commands ran from `tool/oracle/` with existing Node v24.19.0,
WebKit 27.2 and Chromium 156.0.8078.4. No dependency/browser install or network
download was run. Dart/Flutter used `D:/DevTools/flutter/bin/*.bat` at root.

| Command / check | Result |
| --- | --- |
| `npm run check-reference` | PASS: all four pinned source payloads |
| `npm run build-fixtures` | PASS: 14 synthetic EPUBs |
| `npm run vectors` | PASS: both engines; existing outputs unchanged |
| `npm run verify-vectors` | PASS: 14 EPUBs, 40 sections, 4,922 CFI samples per engine; no cross-engine differences |
| Repeated builder runs with `TZ=UTC`, `Pacific/Honolulu`, `Asia/Hong_Kong` | PASS: all 14 EPUBs and manifest byte-identical in each run |
| `dart format test/features/reader/data/epub/oracle_fixture_test.dart` | PASS: one file, zero changes |
| `flutter test --no-pub test/features/reader/data/epub/oracle_fixture_test.dart --reporter expanded` | PASS: 28 passed, zero skipped/failed; includes two new fixture cases |
| `dart run build/a4/first_wins_probe.dart` | PASS: all three first-copy negative controls rejected by existing comparisons |
| `dart run build_runner build` | PASS: two outputs written, no tracked generated-file change |
| `dart format --output=none --set-exit-if-changed lib test tool/reader tool/diag tool/ci` | PASS: 262 files, zero changes |
| `flutter analyze --no-pub` | PASS: no issues |
| `flutter test --no-pub --reporter expanded` | PASS: 1,033 passed, one skipped, zero failed |
| `dart run tool/ci/check_reader_fixtures.dart` | PASS: manifests and EPUB privacy guard |
| `git diff --check`, `git diff --stat`, baseline hashes | PASS |

The one skip remains the existing opt-in native CFI export test because
`SHIORI_NATIVE_CFI_OUT` is unset. The full-suite log and temporary synthetic
controls remain in ignored `build/a4/`; no private payload is included here.
No A4 open issue. A1's hosted iPhone SQLite gate and later worker/device proof
remain outside A4. No staging, commit, push, branch switch, git-state mutation,
reference-checkout mutation or sub-agent dispatch occurred.

## A5 worker protocol prototype

Date: 2026-10-26. **COMPLETE for the A5 host protocol prototype.** This does
not complete Phase A, its hosted iPhone SQLite gate, Phase D or device budgets.

### API and ownership rules

Added nine pure-Dart files under `lib/features/reader/data/worker/` and seven
files under the mirrored test directory (five test suites, shared gate support
and a standalone transfer probe). No engine, presentation, existing EPUB code,
dependency, fixture, spec or task planning artifact was changed in A5.

`PublicationWorker.spawn({limits, maxResourceBytes, testHooks})` spawns exactly
one long-lived publication isolate. Its root-side API is:

- `open(String path, PublicationTag tag, {cancellation})` returns an immutable
  `PublicationSnapshot` containing deeply frozen package/section metadata.
- `loadSection(int index, {cancellation})` returns the existing immutable
  `SourceDocument`, directly through the isolate port.
- `readResource(String path, {cancellation})` returns detached read-only
  `Uint8List?`. Null means absent; a present empty entry remains an empty list.
- `close()` is idempotent, completes outstanding caller futures as closed,
  waits for the running operation, closes the archive, and waits for actual
  isolate exit. `isClosed` also covers closing/fatal termination.

`PublicationTag.value` is an opaque caller-supplied session/content tag, not a
content digest or a lease. Every sealed typed request/response carries a
monotonic request ID, tag and internal open generation. Reopen immediately
completes older pending/running futures as stale and supersedes queued opens.
The generation distinguishes A -> B -> A even when the caller reuses tag A.
A matching ID with an incorrect tag/generation completes as stale. Unknown or
duplicate old IDs are dropped without consuming a newer request's execution
slot; the old future has already completed stale/canceled. The worker also
checks the request's tag/generation against its owned open publication.

The root serializes dispatch: at most one request is sent to the worker and
eight more are pending. Overflow returns `PublicationWorkerException` with
`queueFull` immediately. `PublicationCancellation` stays entirely on the root.
Pending cancellation removes the request without sending it. Running
cancellation completes its future immediately, retains the execution slot
until the terminal reply, and discards that reply, including parse failure.
Synchronous parsing is not preempted mid-call. Rapid cancellation therefore
cannot enqueue unlimited physical work behind the worker.

Only the worker calls `EpubArchive.openFile`, `readEpubPackage`,
`EpubSectionLoader.project`, archive resource reads and archive close. It
owns the file handle, loader and resource-discovery graph. Neither an
`EpubBook`, `EpubArchive`, loader nor another lazy object crosses the port.
All relevant worker entry points check their isolate control port against the
root's port, including in release mode. Tests combine actual work events with
`ReaderWorkGuard.callback` around root API calls and assert every open/package
parse/section parse/resource read/close event belongs to the same non-root
isolate. The standalone probe also executes with ordinary `dart run`.

Resources cross the wire as `TransferableTypedData`, with a default individual
64 MiB bound, configurable down to zero and never above `EpubLimits.maxEntryBytes`.
Declared size is checked before inflation; archive enforcement bounds actual
emitted bytes, followed by an actual-length check before transfer. Root-side
materialization validates length and produces an unmodifiable byte view. The
wire test verifies the transferable can be materialized only once.
`fromList` preparation and expanded bytes can coexist temporarily; an
individual transfer bound is not a process RSS or retained-cache guarantee.

Bad archive/package/section/resource input yields a sanitized `ParseException`
and leaves the worker usable. Lifecycle/queue/protocol failures use the local
`PublicationWorkerException.failure` enum because core `AppException` is sealed
outside this library. Uncaught worker errors and unexpected exits have actual
isolate listeners, complete every waiter with `workerError` / `unexpectedExit`,
and close the client. Tests inject a real isolate kill and an uncaught worker
error. Windows temp-file tests verify successful close, failed-open cleanup
and re-open release their archive handles before deletion.

### SourceDocument transfer and cost

No sendability problem occurred, and no serialization layer was added. All
14 generated fixture first sections match direct `EpubBook` results for
projected nodes, attributes/children, parser metadata, package/CFI facts and
canonical length/signature. Received source lists and nested metadata reject
mutation; detached source/resource values outlive archive closure.

`source_transfer_probe.dart` first obtains each source through the publication
worker, then measures direct typed object graph sends through a separate echo
isolate: five warm-ups, twenty measured samples. No ZIP work or source parsing
runs on the root. Windows, Dart 3.13.5; microseconds below are host observations.

| Synthetic first section | Nodes / attributes | Text UTF-16 units | Projection JSON UTF-8 bytes | Send us min / median / max | Round trip us min / median / max |
| --- | ---: | ---: | ---: | --- | --- |
| one-page | 8 / 4 | 14 | 1,042 | 1 / 1 / 4 | 7 / 9 / 35 |
| long-content | 1,087 / 363 | 152,294 | 583,897 | 119 / 169 / 286 | 270 / 390 / 1,445 |

The JSON byte count is only a size proxy (projection JSON omits full attribute
and child-list detail), not the wire representation or heap size. Send timing
measures the synchronous `SendPort.send` call; round trip includes both graph
sends and scheduling, excludes parsing, and is not the full publication load
latency. Source snapshots use ordinary object graph messaging rather than
transferable byte ownership. These small synthetic results do not establish
near-limit source copy cost, worker peak RSS or iPhone memory/performance.

### Left for Phase D

Leases and generation pinning; actual server/book/content identity and digest;
cache publication/reconciliation/eviction and retained-resource accounting;
bounded source/resource seam and preloaded adapter for `section_preparer.dart`
and `prepared_section.dart`; canonical indexing in the worker; richer layout,
language, viewport/style/resource facts with explicit not-inspected states;
near-limit source/worker memory and device evidence. The existing loader's
resource graph discovery is preserved for source parity, not replaced with a
new cache policy. No product reader or rendering-capability claim is added.

### Commands and results

All Dart/Flutter commands used `D:/DevTools/flutter/bin/*.bat` from repo root.

| Final command / check | Result |
| --- | --- |
| `dart format lib/features/reader/data/worker test/features/reader/data/worker` | PASS: 16 files, final run zero changes |
| `flutter test --no-pub test/features/reader/data/worker --reporter expanded` | PASS: 37 passed, zero skipped/failed |
| `dart run test/features/reader/data/worker/source_transfer_probe.dart` | PASS: both synthetic source sizes, twenty samples each |
| `dart run build_runner build` | PASS: zero outputs written |
| `dart format --output=none --set-exit-if-changed lib test tool/reader tool/diag tool/ci` | PASS: 278 files, zero changes |
| `flutter analyze --no-pub` | PASS: no issues |
| `flutter test --no-pub --reporter expanded` | PASS: 1,070 passed, one skipped, zero failed |
| `dart run tool/ci/check_reader_fixtures.dart` | PASS: manifests and EPUB privacy guard |
| `git diff --check`, scope/hash review | PASS |

The one skip remains the existing opt-in native CFI export test with
`SHIORI_NATIVE_CFI_OUT` unset. Full-suite output is in ignored
`build/a5-flutter-test.log`. Earlier focused-test failures were test setup
corrections (the one-page section is `EPUB/only.xhtml`; repeat materialization
throws `ArgumentError`); all final expectations pass without EPUB-layer edits.
The pre-A5 evidence remains an exact 34,665-byte prefix. Hash comparison
verified 769 intact baseline records for other existing tracked/nonignored
files as byte-identical; git status/diff also confirms the permitted scope.
No staging, commit, push, branch switch, reference-checkout mutation or
sub-agent dispatch occurred. No A5 protocol issue remains; the explicit Phase D
and device work above remains deferred.

## A6 probe SQLite self-check

Date: 2026-10-26. **COMPLETE for the local A6 implementation and Windows
checks.** The hosted build, native packaging/signing and iPhone SQLite gate
remain unverified and required before Phase B. No source push was performed.

### Self-check and ownership

Added `ProbeSqliteRepository`, `ProbeSqliteResult` and the isolated runner
under `lib/features/diagnostics/data/`, plus a localized panel on the existing
synthetic diagnostics screen. The repository resolves injectable
`AppDirectories.applicationSupport()`, then passes only its path and the root
control port to `Isolate.run`. The runner refuses an accidental root call
before SQLite or disk access. No product database owner or reader import of
diagnostics was introduced.

Each run uses a unique `probe-sqlite-self-check/run-*` Application Support
subdirectory and fresh databases. It records six pass/fail/not-reached steps:

1. Open a fresh file-backed database and read actual runtime settings.
2. Commit table/data/user_version=1 in a transaction.
3. Close, reopen and verify the committed row/version.
4. Trigger an actual duplicate-key SQL failure after DDL, an earlier insert
   and a version write. Verify rollback of all three both before close and
   after reopening.
5. Seed a separate version-2 database, refuse it through a probe-only version
   guard before any write, then check the sentinel/version, exact file bytes
   and directory entry set are unchanged. This is driver feasibility, not
   the deferred product migration implementation.
6. Close every handle and delete the run directory/databases/sidecars in
   cleanup. The empty dedicated parent may remain; Documents is never used.

Results include UTC time, originating compile-time build identity, Dart
package version, runtime SQLite version/source ID/sorted compile options,
journal mode, synchronous setting, elapsed microseconds and sanitized failure
codes. `sqlite3` provides no public Dart-package version getter; the 3.8.0
snapshot is explicitly labelled `resolved_pubspec_lock_snapshot` and a test
checks it against the actual lockfile. Native-loader/SQL/filesystem failures
inside the worker remain failed, exportable evidence. Directory lookup/spawn
failures use the probe's typed/localized storage-error path.

### Export, UI and specification

The existing outer `DiagnosticRecord.schemaVersion=1` is unchanged. Optional
`metadata.sqliteSelfCheck` has its own `schemaVersion=1`; old records without
it load unchanged. A present invalid/unsupported extension fails saved-record
loading as `ParseException`. The exported result round-trips through Documents
and the existing private `last-diagnostic.json`.

The screen displays the latest result, individual steps and runtime facts,
restores a previously exported result with its original build/time, disables
overlapping capture/export/check work, and supports rerun after failure. A new
result clears the displayed export path: the user must capture/stop or
re-export an existing record to save it. The bounded clipboard summary is
unchanged. `.trellis/spec/flutter/diagnostics.md` documents the field, API,
storage/isolate boundaries, validation matrix and tests.

### CI packaging provenance

`tool/ci/build_ios_unsigned.sh` now writes sorted immediate
`Runner.app/Frameworks` entries to `$OUTPUT_DIR/frameworks.txt`, also recorded
as `provenance.json.packagedFrameworks` and `packagedFrameworksFile`. Inventory
is written before bundle validation so a validation failure retains it.
For case-insensitive `*sqlite*.framework` matches, `validate_bundle` reads the
framework's `CFBundleExecutable`, checks it exists and verifies arm64 using
`lipo`, including both staged variants. Existing Flutter/App checks remain.
Build target, default/cametal behavior, build counters, identity checks,
workflow and native source are unchanged. No Phase E app build mode was added.

### Local commands and results

All Flutter/Dart commands used `D:/DevTools/flutter/bin/*.bat` at repo root.

| Final command / check | Result |
| --- | --- |
| `flutter gen-l10n` | PASS; generated localization updated |
| `dart run build_runner build` | PASS; final regeneration leaves generated contents stable |
| `dart format` on changed Dart sources/tests | PASS |
| `dart format --output=none --set-exit-if-changed lib test tool/reader tool/diag tool/ci` | PASS: 286 files, zero changes |
| `flutter analyze --no-pub` | PASS: no issues |
| Focused repository + diagnostics-screen tests | PASS: 21 passed, zero failed (7 new data tests + 14 screen tests, including 3 new screen cases) |
| `flutter test --no-pub --reporter expanded` | PASS: 1,080 passed, one skipped, zero failed |
| `dart run tool/ci/check_reader_fixtures.dart` | PASS: manifests and EPUB privacy guard |
| Git Bash `bash -n tool/ci/build_ios_unsigned.sh` | PASS: exit 0; no macOS build/commands executed |
| `dart run build/a6/sqlite_probe.dart` (ignored host observation) | PASS: six steps true, off-root true; temp root deleted |
| `git diff --check`, baseline/scope review | PASS; earlier A1-A5 contents preserved |

The standalone Windows observation used package 3.8.0 and native SQLite
3.54.1, source ID
`2026-10-16 14:45:20 555e07ef33f69a0957d24d8e555b702464a131d6f1607f4c3c1e4551e8e6ca76`,
`journal_mode=delete`, `synchronous=2`; elapsed 60,493 us for that one run.
Compile options were recorded (including `COMPILER=msvc-1951`, `MUTEX_W32`,
`THREADSAFE=1`). This is host evidence, not iPhone compatibility or a latency
budget. Full-suite output and host observation remain ignored under `build/a6/`.
The sole full-suite skip remains the optional native-CFI export test with
`SHIORI_NATIVE_CFI_OUT` unset. Initial widget-test failures exposed assumptions
about list scroll/cache positions after adding a long panel; test navigation
now supports revisiting controls and locating the loading indicator directly.
The original behavior assertions remain in place and pass.

### Hosted gate still required

1. Obtain the user's explicit chat authorization for a push to `ios-build/**`.
   The integration owner reviews/integrates the existing working tree, then
   pushes through the existing workflow. A6 does not stage, commit or push.
2. Download the hosted unsigned default probe IPA plus `provenance.json`,
   `frameworks.txt`, `sha256.txt` and native status/diff/untracked artifacts.
   Check commit/build identity, counter, SHA-256, iphoneos/arm64 validation and
   the actual SQLite framework/native asset in the IPA. Inspect its native
   dependencies on macOS as needed; Windows `bash -n` establishes only syntax.
3. A1's system-SQLite configuration remains an untested candidate. This scope
   leaves pubspec unchanged, so the default hook still bundles SQLite. The
   integration owner must exercise the system candidate and compare bundling
   as necessary to settle the design's fewer-packaged-artifacts choice; do not
   infer a selection or a system-link pass from this implementation.
4. The user signs/installs through the selected S1 route: 全能签 with the
   existing selected certificate/profile and identity, following the archived
   S1 `device-runbook.md`. Verify launch, same-identity update/re-sign and the
   retained non-sensitive marker without uninstalling the app.
5. Open the synthetic diagnostics screen on the iPhone and run **运行 SQLite
   自检**. Require all six steps to pass. Check the self-check's build identity,
   runtime library/source/options, journal/synchronous settings and elapsed
   time. A storage-driver failure stops S3 for a plan revision.
6. Start/stop a synthetic capture (or re-export an existing record), then
   retrieve its JSON via Files → On My iPhone → Shiori → Share to Windows.
   Confirm `metadata.sqliteSelfCheck.schemaVersion=1`, all steps, cleanup,
   original self-check identity and the matching hosted provenance. Retain
   personal/device exports under ignored `local-evidence/`, with only a safe
   evidence summary appended here. Only that actual hosted/device result can
   satisfy the Phase A iOS gate.

No local A6 issue remains. No staging, commit, push, branch switch, git-state
mutation, reference-checkout mutation or sub-agent dispatch occurred.

### Review minor fixes

Date: 2026-10-26. The four independent-review minor findings are fixed and
verified locally. This does not satisfy the hosted/iPhone gate above.

1. **Raw SQLite result validation:** `ProbeSqliteResult.fromJson` validates
   before generated defaults or numeric conversions. Required fields have
   their raw types, the timestamp identifies UTC, the six step keys have
   boolean/null values, elapsed microseconds are a nonnegative integer, and
   optional runtime fields retain their declared types (including integer
   `synchronous`). Both direct decoding and `fromMetadata` use this boundary.
   `probe_sqlite_result_test.dart` covers every missing required field
   (including provenance), fractional/negative durations (including `-0.5`),
   malformed raw types, zero duration and a valid JSON/metadata round trip.
   The saved-record repository test also rejects missing provenance and
   fractional negative elapsed time as typed `ParseException`.
2. **Path-free repository failures:** directory and isolate-spawn failures
   log only fixed classifications and propagate a sanitized
   `ParseException(FormatException(...))` cause. Original exceptions and
   stacks are omitted. The repository regression injects a private path in
   both a filesystem exception and its stack, captures root `LogRecord`s,
   and checks the message, error, stack, thrown string and sanitized cause.
3. **Portable research citations:** `storage-and-import.md` now cites
   `%PUB_CACHE%/hosted/pub.dev/archive-4.5.2`. The A1/A3 citations in this
   file were already normalized at entry and remain package-relative or
   rooted at `%PUB_CACHE%/hosted/pub.dev/`. A whole-working-tree search
   includes hidden, ignored, tracked and untracked text; it excludes
   `.git`, `build`, `.dart_tool`, `dist` and `node_modules` directories.
   Case-insensitive matching covers forward, backslash and JSON-escaped
   separators. Neither scoped research file retains a user-profile path.
   Every remaining hit is outside the allowed edit scope and was preserved:
   - `.flutter-plugins-dependencies:1`: 9 occurrences in generated local
     plugin metadata.
   - `.trellis/tasks/archive/2026-10/10-22-native-reader-feasibility/evidence/oracle-browser-install.json:7`:
     5 occurrences in the archived browser-install stdout.
4. **Current dependency/archive specs:** `quality-guidelines.md` now lists
   direct `sqlite3 3.8.0` (MIT) and `crypto 3.0.7` (BSD-3-Clause), checked
   against pubspec/lockfile and cached licences. Its archive row documents
   the raw-directory index, metadata bounds, last-wins duplicates, exact
   length/CRC-32, bounded native decode and file-backed open.
   Only the superseded carry-forward bullet in `reader-engine.md` was
   reconciled; Phase D adapter/cache/lease and near-limit worker/device
   limits remain explicit. Source/diff review and the full unchanged reader,
   archive, worker and oracle tests verify consistency.

All commands used `D:/DevTools/flutter/bin/*.bat` at repository root:

| Final command / check | Result |
| --- | --- |
| `dart run build_runner build` | PASS; generated files finish byte-identical to the entry baseline |
| `dart format` on the two changed sources and two tests | PASS; final check: 4 files, zero changes |
| Focused SQLite result/repository tests, `flutter test --no-pub ... --reporter expanded` | PASS: 12 passed, zero skipped/failed |
| `flutter analyze --no-pub` | PASS: no issues |
| `flutter test --no-pub --reporter expanded` | PASS: 1,099 passed, 1 existing skip, zero failed |
| `dart run tool/ci/check_reader_fixtures.dart` | PASS: manifests and EPUB privacy guard |
| Working-tree profile-path search | PASS: scoped files clean; all 14 remaining occurrences in the two out-of-scope files above |
| `git diff --check` and baseline hash/scope review | PASS |

An initial focused run failed to compile after a block-bodied `fromJson`
disabled Freezed JSON generation. Restoring the required arrow factory and
placing raw validation in its argument fixed this; regeneration and every
final check above passed. The one suite skip remains the existing native CFI
export test with `SHIORI_NATIVE_CFI_OUT` unset. Logs and the path-hit ledger
are ignored under `build/review-minors/`.

Baseline comparison preserves all existing files outside this bounded scope,
including generated files, `epub_archive.dart`, its tests, worker code,
pubspecs, planning/context artifacts and the earlier archive-spec paragraph.
No staging, commit, push, branch switch, git-state mutation, reference-checkout
mutation or sub-agent dispatch occurred. No review-minor implementation issue
remains; out-of-scope path hits and the pre-existing hosted/device gates remain
as reported above.

### Second review fixes

Date: 2026-10-26. **Verified on Windows.** This subsection supersedes the
blanket ZIP64 rejection described in "A3 fix: directory metadata bounds" and
completes the directory-plugin redaction missed by "Review minor fixes".
The former rejection was an uncommitted Phase A regression, not an approved
content-support change. No test present at `f94664c` was edited.

**ZIP64 decision and implementation:** keep the bounded preflight and support
ZIP64 within the same archive/count/entry/total/directory/metadata limits.
The locator must point to a complete EOCD64 record ending at the locator;
single-disk identifiers, both counts and nonsentinel classic EOCD values must
agree. Resolved central data must fit before the EOCD64 record. Extra-field
ID 1 reads expanded size, compressed size, local offset and disk in that
order, consuming only fields whose corresponding classic values are
sentinels. Local extras likewise resolve only required size fields. An ID-1
extra with no required field is valid; missing/truncated required fields,
truncated ID-1 payloads and duplicate ID-1 records fail. Unknown extras retain
the previous bounded tolerance. Unsigned values that cannot fit a native
signed integer are rejected before arithmetic can wrap. EOCD64 extensible
bytes are charged against the existing variable metadata budget.

Every resolved central entry is admitted before package hydration, including
overwritten duplicates. Unique local offsets, disjoint complete local/data/
descriptor ranges, compression/encryption restrictions and all budgets still
apply. Signed and unsigned descriptors use their full 32-bit or ZIP64 width,
matching the package's local-ID-1 rule. Hydration calls `ZipFileHeader.read`
without local I/O, installs the admitted sizes/offset/disk, then calls
`ZipFile.read` with a view restricted to that admitted local range. Package
metadata decoding cannot substitute an unchecked size or offset for I/O or
lazy decompression. Bounded output, exact length and CRC checks remain in use.
All malformed ZIP64 failures are content-free `ParseException`s.

Source inspection used `%PUB_CACHE%/hosted/pub.dev/archive-4.5.2/`:
`lib/src/codecs/zip/zip_directory.dart` (`_readZip64Data`),
`zip_file_header.dart` and `zip_file.dart` in that codec directory. The
conditional extra-field ordering follows APPNOTE 4.5.3 as documented in the
resolved header implementation. Also inspected fflate 0.8.2's `zh`, `z64e`
and `unzipSync` in `tool/oracle/node_modules/fflate/lib/node.cjs`; its ZIP64
shortcut assumes a fuller central extra layout, so selective central fields
are independently tested against the APPNOTE field-presence rules.

**ZIP64 tests:** 65 archive tests pass across memory and file-backed APIs.
The review reproduction is generated from the unchanged `one-page.epub`
fixture in-test: 2,230 bytes, six entries, ordinary first `mimetype`, ZIP64
local records for the remaining entries. Every name, size and returned entry
byte matches the original. Tests cover all 16 central sentinel combinations,
central-only ZIP64 with and without ZIP64 end records, individual local size
sentinels, empty ID-1 extras without sentinels, both descriptor signatures,
classic/ZIP64 end consistency, missing locator/target/required fields,
truncated extras/records, high-word and overflow values, multi-disk refusal,
and content-free causes. ZIP64 versions of 1,000/20,000 aliases, nested local
headers, overlapping payloads/descriptors, directory crossing, overwritten
entry/total/count limits and exact/one-byte-over directory/metadata budgets
fail at open. Earlier malformed-input assertions are preserved or strengthened;
only the uncommitted blanket-rejection expectations were replaced.

**Directory errors:** `DirectoryAccess` logs fixed classifications with no
original exception, message, details or stack. Plugin failures still surface
as `ParseException`, now with a fixed `FormatException` cause. Filesystem
lookup failures retain `FileSystemException` for existing repository mappings,
with a fixed message, empty path and no OS error. The SQLite repository keeps
its existing sanitized filesystem cause and mapping; its two log records
(directory classification and repository classification) contain no original
error/stack. Nine new direct tests cover success plus synchronous/asynchronous
filesystem, platform, missing-plugin and missing-directory failures. SQLite
repository regressions cover both filesystem and platform failures with
synthetic private paths in exception fields and injected stacks. Tests inspect
every `LogRecord` field, thrown strings and causes. The unchanged tests for
all other directory callers pass in the full suite. `error-handling.md` has
no directory-lookup logging rule to revise and was left unchanged.

Commands ran from the package root using the existing Dart/Flutter toolchain:

| Command / check | Result |
| --- | --- |
| `dart format` on the seven changed Dart files | PASS |
| `dart format --output=none --set-exit-if-changed lib test tool/reader tool/diag tool/ci` | PASS: 289 files, zero changes |
| `dart run build_runner build` | PASS; no tracked generated-code diff |
| Focused archive / directory / SQLite repository tests, `flutter test --no-pub ... --reporter expanded` | PASS: 83 passed (65 + 9 + 9), zero failed/skipped |
| `flutter analyze --no-pub` | PASS: no issues |
| `flutter test --no-pub --reporter expanded` | PASS: 1,123 passed, one existing opt-in native-CFI skip, zero failed |
| `dart run tool/ci/check_reader_fixtures.dart` | PASS: manifests and EPUB privacy guard |
| `dart run tool/reader/archive_memory_probe.dart` | PASS: both ordinary sizes/APIs, both hostile alias counts/APIs, temporary archives deleted |
| `git diff --check` | PASS |

The initial analysis reported one unnecessary cascade in the test builder;
it was corrected before the final clean analysis and full suite. No failing
test run preceded the final pass. Logs are ignored under
`build/second-review-*.log`; the suite's one skip remains the native CFI export
test with `SHIORI_NATIVE_CFI_OUT` unset.

The standalone memory probe measured file-open RSS deltas of +8,290,304 bytes
for 20,973,362 archive bytes and -7,507,968 for 209,733,802 archive bytes.
Memory-open deltas were +13,905,920 and +202,850,304 bytes respectively.
All four hostile runs rejected at open; their process maxima stayed equal
to the warm-up maxima (about 300 MB), with rejection RSS deltas of about
11.3-13.3 MB. Negative deltas reflect host GC/working-set variation. These
are host archive observations, not an iPhone or whole-worker RSS guarantee;
ZIP64 hostile encodings are covered by the unit regressions above.

The reader-engine archive paragraph now documents bounded ZIP64 support and
validated-value hydration. No oracle fixture/vector, worker, dependency,
package cache, task plan/context, reference checkout or git index/branch was
changed. No staging, commit, push, branch switch or sub-agent dispatch occurred.
No fix-specific issue remains; hosted/iPhone and later-phase gates retain
their previously recorded status.

## Hosted iOS SQLite gate (Phase A exit)

Date: 2026-10-26. **PASSED.** Recorded by the orchestrator from the hosted
build provenance and one user-operated iPhone export; the raw export and CI
provenance are kept privately in ignored `local-evidence/s3/`.

- Push of `ios-build/s3-runtime-server` (commits `f94664c`, `c018794`) was
  explicitly authorized by the user. GitHub Actions run `40281924284`
  ("Unsigned iPhone probe") succeeded; build `c018794f5aab-gha-10`, build
  number 10, Flutter 3.47.7, Xcode 26.3, iPhoneOS SDK 26.2, build exit 0,
  empty generated iOS project diff.
- Packaged frameworks (`frameworks.txt`): `App`, `Flutter`, `objective_c`,
  `sqlite3`. The default `sqlite3` 3.8.0 hook bundled its own library; the
  iOS `source: system` option was not needed and remains unverified.
- IPA SHA-256: default
  `6e844e5cdc8141822c544da7ab63a175e246781581b27e7fa073681f80b4e2b8`,
  cametal `b28c61de2c0c1f24da025823541a1f80fd82cf746a305735f9e081f44c8e6a8d`.
  The export does not record which variant was installed; both contain the
  same Dart code and frameworks.
- The user signed/installed through the selected S1 on-device signing route
  and ran the probe SQLite self-check on an iPhone (iOS 27.0.1, release mode,
  120 Hz display metadata). Export `buildId` `c018794f5aab-gha-10` matches the
  hosted build.
- Self-check result: all six steps passed (`open`, `commit`, `reopen`,
  `rollback`, `futureSchema`, `cleanup`), `ranOffRootIsolate: true`,
  package 3.8.0, SQLite library 3.54.1, `journal_mode=delete`,
  `synchronous=2` (FULL), elapsed 27,776 us, no failure.

Decision: keep the default bundled SQLite (device-verified) for S3. Phase B
may now build on SQLite. This gate proves packaging, signing/install and basic
transactions under Application Support only; it does not prove the product
storage owner, migrations under real data or update retention, which remain
S3-AC6/AC8/AC10 work.
