# Phase D3: worker publication import

Date: 2026-10-27. Worktree: `D:/Projects/shiori-d3`, branch
`s3/d3-worker-import`, base `2603b18`. **D3 implemented and host-verified.**
This is independent D3 evidence; the shared Phase D evidence and task planning
artifacts are unchanged. No agent dispatch, staging, commit, push, branch
switch or access to another worktree was performed.

## Changes and ownership

- `lib/core/config/content_identity.dart`, `content_change.dart`: shared pure
  Dart values; no dependency on a reader feature, storage or a provider.
- `lib/features/reader/data/worker/`: prepared-result/layout models, metadata
  and first-source resource inventory, import errors and runtime import part;
  extended client/protocol/test hooks, preserving the original open APIs.
- `lib/features/reader/data/epub/epub_book.dart`: 11-line constructor extraction
  adding `EpubBook.fromArchive(archive, package, {tokens})`.
- Eight new files under `test/features/reader/data/worker/`, including generated
  ZIP support and the standalone VM reflection source stored as test data.
- `.trellis/spec/flutter/reader-engine.md`: executable identity/import/facts
  contracts, error matrix, assertions and the S4/D4 boundary.

**EPUB blocker and bounded fix:** the existing pure-Dart style resolver takes
`EpubBook`, whose only public constructor required the entire compressed file
as a Uint8List. That prevents styling file-backed worker content through the
existing resolver. The new constructor wraps the already validated archive
and parsed package without buffering compressed bytes or changing projection.
The worker remains the archive owner and closes it on failure/replacement/exit.
No EPUB archive/package/parser/loader algorithm or engine code was changed.

## Identity and import contract

`ContentIdentity(BookKey, sha256, {parserVersion, canonicalVersion})` normalizes
SHA-256 to lowercase and validates exactly 64 hexadecimal digits and positive
versions. Explicit current versions are `publicationParserVersion = 1` and
`publicationCanonicalVersion = 1`; the latter is tested against
`canonicalTextVersion`. Equality/hash include all four identity components.
Same numeric book ID on another server never aliases. `ContentChange` carries
nullable previous and required next identities, requires one BookKey, and has
no progress/activity behavior.

```dart
Future<PreparedPublication> prepare(
  String path,
  ContentIdentity identity, {
  PublicationTag? tag,
  PublicationCancellation? cancellation,
});
```

The caller owns digest verification and the immutable file. Preparation opens
with `EpubArchive.openFile`, validates container/package and the first original
linear itemref, loads its inert source, resolves its styles, builds its
canonical index and inventories source/CSS/SVG resource references. A missing
first linear itemref cannot be silently skipped. Fixed image/SVG source can
have canonical length zero and still prepare successfully.

`PreparedPublication` returns identity, frozen package/section snapshots,
ordered DC metadata, layout facts and first-section readiness. Readiness
contains index/href/CFI base, parser/fallback classification, canonical
version/length/signature and reference records. The first SourceDocument stays
in the worker for `loadSection`; the full canonical map is not transferred by
this summary. Other source/resource operations remain worker-owned.

The root verifies response identity along with the existing typed request ID,
tag and internal generation. An omitted tag derives from content identity;
product flows should supply their captured session tag and guard publication
with the session owner. Noncurrent identity versions fail before replacement.

Import failures are content-free `PublicationImportException` with
`invalidArchive`, `invalidPackage` or `invalidFirstSection`. No original cause,
path, parser object or source prose crosses in these exceptions. The failed
archive is closed and the same worker can prepare a valid book. Existing
open/load/read failures remain sanitized ParseException; lifecycle/cancel/
stale failures remain PublicationWorkerException. No new AppException subtype
was added outside its sealed library.

## Layout and resource facts

Each section records effective fixed/reflowable mode after package/itemref
overrides, original OPF slot, raw itemref properties and resolved rendition.
Package rendition retains layout/orientation/spread/viewport/sourceViewport;
the facts separately retain raw progression and first language tag.
The first styled section records viewport/source-viewport declarations,
inline or source SVG width/height/viewBox, computed root/body writing modes
and directions, raw dir declarations, visible writing modes and visible
non-root/body RTL element count. This count follows S2's informational block
count, not Unicode bidi segmentation. Every other section is explicitly
`notInspected` with null source/style facts, including later vertical/RTL
sections and skipped nonlinear sources. Detached summaries never mutate on
later source reads.

Reference records preserve source path, original URL, local path/media type
and presence. Discovery follows CSS imports/URLs and SVG dependencies,
terminates cycles and records missing/external/data/fragment references
without fetching remote resources. No resource bytes are retained in the
inventory or sent in the import summary. Individual `readResource` transfers
retain the existing declared/actual byte bound and read-only transferable view.

The existing loader's whole-spine resource graph is deliberately preserved
for reference token alias ordering. It does not style the other sections or
create a retained expanded-resource mirror. D3 runs no `detectBookLayout` or
`requireSupported`. UnsupportedLayoutReason, detection APIs and the S2 probe's
historical refusal remain unchanged. Renderer verdicts are S4's responsibility.

## Fixture and regression results

All new EPUBs are generated in-test using A3's raw ZIP helper. Mimetype is a
stored first entry; the image resource is a generated valid RGBA PNG. No
committed EPUB/vector or fixture manifest was added or modified.

| Cases | Result |
| --- | --- |
| Simple fixed single-image and complex positioned XHTML + SVG | Prepare; fixed mode, raw viewport/source viewport and SVG dimensions preserved |
| Reflowable then fixed, package-fixed overridden reflowable, package-reflowable overridden fixed first | Prepare with expected modes and unloaded sections not inspected |
| Valid fixed image first page and valid SVG first source | Prepare; zero canonical characters accepted; image reference and dimensions retained |
| Orientation/spread/page-spread left/right/center; legacy display options | Raw/default/override facts retained independently |
| RTL progression, Arabic/Hebrew publication language, vertical first section and RTL runs | Prepare without capability refusal; expected package/style facts |
| Nonlinear first source, later unstyled vertical/RTL sections | Actual first linear source styled; other sections explicitly not inspected |
| All 14 bundled oracle EPUBs, including unsupported-fixed/rtl/vertical | Prepare; first projected source and canonical signature equal direct existing loader results |
| Missing/malformed/wrong-root container or OPF; empty/unresolved/nonlinear-only spine | Typed invalidPackage; handle released and same worker reused |
| Missing/empty/unparseable/non-source first section and first-section CRC corruption | Typed invalidFirstSection; handle released and worker reused |
| Garbage/truncated ZIP and injected admission limits | Typed invalidArchive; no successful empty result |
| Nested discovery cancellation/reopen/close | Caller rejected immediately; physical slot retained until late reply discarded; next operation usable |
| Immutable response and work-isolate instrumentation | All work observed off root; one style/canonical pass; nested collections reject mutation |
| VM reflection audit | 122 final fields visited; only allowed detached values; lazy book/archive controls refused; response survives close/file deletion |

The reflection test materializes its VM-only source from `.dart.txt` into a
temporary script and invokes standalone `dart` with the package config.
Flutter's SDK does not expose dart:mirrors. This keeps the audit in the full
suite without analyzer suppressions or exclusions. No private book input is
required by any new test.

## Commands and final gates

All commands ran in this worktree using the existing Flutter/Dart toolchain.
Logs are ignored under `build/d3/`.

| Command/check | Final result |
| --- | --- |
| `flutter pub get --offline` | PASS; no online fallback needed, pubspec/lockfile unchanged |
| `dart run build_runner build` | PASS; 86 outputs emitted, generated content byte-identical to base |
| `dart format` on changed Dart files | PASS |
| `dart format --output=none --set-exit-if-changed lib test tool/reader tool/diag tool/ci` | PASS: 441 files, zero changes |
| `flutter analyze --no-pub` | PASS: no issues |
| `flutter test --no-pub test/features/reader/data/worker --reporter expanded` | PASS: 88 passed, zero skipped/failed; 51 new D3 tests plus 37 unchanged worker tests |
| `flutter test --no-pub --reporter expanded` | PASS: 1,859 passed, four existing optional skips, zero failed |
| `dart run tool/ci/check_reader_fixtures.dart` | PASS: manifests and EPUB privacy guard |
| `git diff --check`, scope/base-content review | PASS |

The four skips are the three local-book data/layout/support suites without
`build/oracle-local/`/the private EPUB folder, and native page-anchor export
without `SHIORI_NATIVE_CFI_OUT`. No assertion, expected vector, probe refusal
or existing test was edited to obtain these results. Existing oracle, CFI,
canonical, worker, probe and other product suites pass in the full run.

Early format/analyze attempts found a constructor punctuation error and
missing braces; these were fixed. The first standalone reflection program
ran successfully under Dart, but Flutter analysis correctly rejected its
dart:mirrors import. It now runs as VM test data through a real full-suite
test, with no diagnostic suppression. Final analysis and suite runs pass.
There were no failing test runs. The final complete suite was repeated after
improving generated fixtures to store mimetype and carry a valid generated PNG.

Pub get/build_runner regenerated native registrants and existing generated
Dart files with LF. All 59 affected generated files were verified equal to
base after newline normalization and restored to checkout CRLF. They have no
remaining diff; no generated content, dependencies, network/library/storage
implementation or other out-of-scope file was changed.

## Integration and remaining boundaries

- Download/cache publication supplies the streamed digest and immutable file,
  captures the session tag, handles PublicationImportException as recoverable,
  and guards its final generation/rename/DB publication. This operation does
  not perform those writes, emit ContentChange, or save reader progress.
- D4 receives first-section index/source through the worker plus identity,
  canonical summary and layout/resource facts. D4 owns its preloaded adapter,
  resource leases/cache accounting and reader source/resource seam. S4 owns
  fixed/mixed rendering and all renderer capability explanations.
- Cancellation is logical, matching the existing protocol: no synchronous
  parse/inflate preemption. The physical slot remains occupied until terminal
  completion, so canceled work cannot grow an unbounded worker queue.
- The oracle resource graph remains whole-spine for compatibility. Import
  does not inspect all section styles or run whole-book layout detection.
- This step adds no near-limit whole-worker RSS or iPhone measurement. The
  Phase A archive-only evidence remains valid within its documented limits;
  full worker/resource/device memory acceptance is separate integration work.

No D3 implementation issue remains. These retained boundaries are not claims
of completion for the parent S3/S4 acceptance criteria.

## D4 resource seam and budget

Date: 2026-10-27. Worktree `D:/Projects/shiori-d3`, branch
`s3/d3-worker-import`, base `c1054e3`. **D4 implemented: resource adapters,
engine routing, retained budget and host verification complete.** No existing test,
expectation, oracle fixture/vector, layout/painting algorithm or probe behavior
was changed. No sub-agent, staging, commit, push or branch switch was used.

### Scope review and decisions

The earlier partial-D4 scope blocker was resolved by the approved seam-only
extension. Final review covers all eight engine files (relative to
`lib/features/reader/engine/`):

| File | Why touched |
| --- | --- |
| `pagination/section_preparer.dart` | Detached request metadata and resource input, font/presence/image call sites, lease transfer and failure/cancellation release. |
| `pagination/prepared_section.dart` | Resource ownership and lazy image reads; idempotent disposal and disposed-owner image guard. |
| `layout/font_registry.dart` | Resource size/byte access with legacy archive compatibility and unchanged 32 MiB preflight/fallback. |
| `layout/block_builder.dart` | Resource presence checks for images/SVG; legacy archive constructor compatibility. |
| `surface/page_surface_pool.dart` | Later encoded-image reads through the section's source. |
| `style/css_style_resolver.dart` | Archive text/presence access through the adapter. |
| `support/layout_flags.dart` | Display-option text through the adapter. |
| `support/unsupported_layout.dart` | OPF language text through the adapter. |

No layout, shaping, pagination, painting or capability algorithm changes were
found. The ownership guards prevent resource access after disposal and release
the new lease once; they are part of the seam lifetime contract. The only
diagnostic change passes the archive adapter and detached href/CFI metadata.
Compatibility entry points preserve existing archive callers and tests.

Style-sharing fix: the first detached freeze copied equal `ComputedStyle`
values per node, breaking the identity sharing used by `InlineAccumulator` to
merge runs. That split native shaping runs and changed geometry. The worker
snapshot now memoizes by original style identity, including root and character
data lookups, and freezes font-family lists. This fix is confined to the new
adapter; no engine shaping rule or expected geometry was changed. Exact
prepared-output parity and text-run comparisons cover the regression.

### Implemented seam values and worker preload

- `data/resources/reader_resource_source.dart`: synchronous encoded bytes,
  presence, declared size and disposal contract; content-free miss enum.
- `archive_reader_resource_source.dart`: exact archive delegation, no file
  ownership; all 14 bundled fixtures preserve every entry/size/presence/read
  and the callback work guard.
- `reader_resource_budget.dart` and its preloaded-adapter part: section leases,
  budget reservations, LRU, retirement, read-only owned buffers and typed errors.
- `preloaded_publication_section.dart`: detached source/style/section metadata,
  exact resource plan and adapter owner. Style lookups/font-family lists are
  frozen and retain no resolver, book or archive.
- Worker client/runtime/protocol parts: `preloadSection(index, {settings,
  budget, cancellation, onMiss})` discovers only that section's D3 references,
  resolves source/styles in the worker, reserves missing encoded bytes on root
  and transfers only cache misses as `TransferableTypedData`. Whole batches
  preflight before inflation; individual entry bounds and CRC checks remain.
- Resource misses return null and expose absent/notPreloaded/disposed/retired
  classifications. Diagnostics callbacks receive only the enum, never content,
  resource paths or URLs. The preloaded adapter has no archive fallback.

The default `ReaderResourceBudget.shared` accounts all product adapters across
workers, with retained plus reserved bytes bounded to 134,217,728. Tests inject
smaller budgets. Reservations pin cache hits; only unleased entries can be
evicted, in access order. Unsatisfiable admission is typed `budgetExceeded`
before transfer; overlapping in-flight keys yield typed `busy`. Cache hits
share one read-only buffer. Dispose releases a source and evicts last-lease
entries; explicit `releaseToCache()` retains only unleased LRU candidates.
Worker open/prepare/close/failure retires live/idle entries and reservations.
Caller cancellation releases reservations, drops late bytes and preserves the
existing physical queue-slot contract. Worker inflation remains indivisible.

### Host worker memory experiments

Command: `dart run tool/reader/publication_memory_probe.dart`; Windows,
Dart 3.13.5. The new sibling tool streams its generated archive to disk, hashes
incrementally outside the measured child, starts a fresh child process with a
real worker, prepares source/readiness and preloads one section. It never builds
the 200 MiB archive as a parent/root buffer. The payload has 200 stored 1 MiB
image entries with valid tiny PNG prefixes/padding; encoded access is measured,
not PNG decoding or page rendering. The first section references four entries.
The following table preserves the earlier partial-D4 run:

| Observation | Bytes |
| --- | ---: |
| Compressed/stored EPUB | 209,751,801 |
| Baseline process RSS after worker spawn | 408,162,304 |
| Baseline process maximum RSS | 408,215,552 |
| RSS after worker prepare | 326,082,560 |
| Prepare RSS minus baseline | -82,079,744 |
| Maximum RSS through prepare | 539,770,880 |
| RSS after preload | 334,647,296 |
| Preload RSS minus baseline | -73,515,008 |
| Maximum RSS through preload / process maximum | 539,770,880 |
| Four preloaded resources / retained encoded bytes | 4,194,304 |
| Retained plus reserved bytes after disposal/retirement | 0 |
| RSS after worker close | 317,014,016 |

Peak RSS rose 131,555,328 bytes over the baseline maximum. Negative sampled
deltas reflect VM/GC/Windows working-set variation, not negative allocation.
The original A3 second-review run measured -7,507,968 bytes at file-backed
open of a 209,733,802-byte archive, versus +202,850,304 for memory-open.
This D4 run is broader (loader graph hashing, parsing, styling, worker and
transfer); it does not prove the archive-only flat-residency claim for total
worker work. The 128 MiB retained limit is not a process-RSS ceiling and excludes
transient inflate/transfer copies, source/style graphs, decoded images and fonts.
All memory-probe temporary files and its directory were deleted in `finally`.
Host command logs/captures are ignored under `build/d4/`.

The completed seam session reported this second run (the same synthetic input;
these are prior-session measurements, not a new run during finish verification):

| Observation | Bytes |
| --- | ---: |
| Compressed/stored EPUB | 209,751,801 |
| Baseline process RSS after worker spawn | 407,011,328 |
| RSS after worker prepare | 329,207,808 |
| RSS after preload | 337,805,312 |
| Process maximum RSS | 546,168,832 |
| Peak above baseline maximum | 139,042,816 |
| Four preloaded resources / retained encoded bytes | 4,194,304 |
| Retained plus reserved bytes after disposal/retirement | 0 |
| RSS after worker close | 325,111,808 |

Peak process RSS was about 521 MiB; retained encoded bytes were 4 MiB. This
does not include a page-layout/decode measurement or establish a 128 MiB RSS
ceiling. The same host/device limitations above apply to both runs.

S4 still needs product section/page/session integration, on-device near-limit peak memory
and no OS memory termination, repeated lifecycle/cancellation/resource cleanup,
fonts/decoding, renderer capability and performance evidence. Host RSS does not
close any iPhone resource or rendering acceptance gate.

### Earlier partial-D4 commands and verification

The existing package config was current; no pub get or dependency change was
needed. All commands ran in this worktree with the existing toolchain.

| Command | Final result |
| --- | --- |
| `dart run build_runner build` | PASS; 52 generated outputs content-identical to base, original checkout CRLF restored; no generated diff |
| `dart format` on changed Dart files | PASS |
| `dart format --output=none --set-exit-if-changed lib test tool/reader tool/diag tool/ci` | PASS: 454 files, zero changes |
| `flutter analyze --no-pub` | PASS: no issues |
| `flutter test --no-pub test/features/reader/data/worker test/features/reader/data/resources --reporter expanded` | PASS: 130 passed, zero failed/skipped (42 new D4 tests) |
| `flutter test --no-pub --reporter expanded` | PASS: 1,901 passed, four existing optional skips, zero failed |
| `dart run tool/ci/check_reader_fixtures.dart` | PASS: manifests/privacy |
| `dart run tool/reader/publication_memory_probe.dart` | PASS: one measurement, four resources, zero accounted bytes after retirement, memory temporary files deleted |

The four full-suite skips are the existing three local-book suites without
private inputs and native CFI export without `SHIORI_NATIVE_CFI_OUT`.
Coverage includes all bundled byte parity, detached source/styles at two
settings, exact per-section generated-image transfers/cache reuse, worker
off-root work events and guarded root adapter reads, budget preflight without
transfer, leases/LRU/global admissions/reservations, malformed transfer rollback,
normal retirement/reopen/close, pre-cancel and cancellation after actual
inflation, and budget retirement on unexpected worker exit.

Initial analysis found one missing brace and one unused import; both were
fixed. An added unexpected-exit regression initially passed its resource
assertions but failed Windows temp-file teardown: abrupt isolate kill does
not guarantee synchronous native-handle finalization. It now follows the
existing kill-test convention with a bundled synthetic input. Normal close/
reopen still tests deterministic temporary-file deletion. The failed attempt
left one synthetic test directory `%TEMP%/shiori-preload-3c924a3e`; direct and
narrow cleanup attempts were rejected by automatic approval policy. This is
separate from the memory tool, whose temporary files were removed successfully.

### Completed engine seam verification

The added engine seam coverage comprises 22 tests: 14 fixture parity tests,
one pre-seam baseline test, two font preflight/fallback tests and five ownership
tests. Across every section and three gate settings, all 120 cases / 2,733 pages
match exactly between archive and worker-preloaded preparation. The saved
pre-seam capture at `build/d4/pre-seam-pages.json` also matches archive-adapter
output; it is optional local host evidence, not a committed fixture or CI input.
Assertions cover page/source maps, line/paragraph geometry, images, unsupported
items, font chains and text-run/style values. Existing vectors are unchanged.

Actual preloaded byte/size/presence reads run inside `ReaderWorkGuard.callback`
via `GuardedResourceSource`; any archive inflation fallback would assert.
Layout/registration/decoding remain outside that resource-only guard. Later
`ensureImages` and `PageSurfacePool.prepare` reads use the same guarded seam.
The font test checks over-32-MiB rejection before any byte read, exact-cap
invalid-format fallback and absent-font fallback. Ownership tests check success,
double dispose, cancellation before and after blocks, callback failure and
worker retirement with a live prepared section, all returning accounting to zero.

### D4 finish verification (2026-10-27)

Reviewed the existing uncommitted implementation directly in this worktree;
no code fixes were required. Updated only this evidence and `reader-engine.md`
to resolve stale scope-blocker text, enumerate all eight engine files, document
the style-sharing fix and reconcile the completed seam's host memory run.

| Command | Result in this finish session |
| --- | --- |
| `dart run build_runner build` | PASS; final incremental run wrote zero outputs. |
| `dart format --set-exit-if-changed lib test tool/reader tool/diag tool/ci` | PASS; 460 files, zero changes. |
| `flutter analyze` | PASS; no issues. |
| `flutter test --reporter expanded` | PASS; 1,923 passed, four existing optional skips, zero failed; includes all 64 new D4 tests (42 data/worker and 22 engine seam tests). |
| `dart run tool/ci/check_reader_fixtures.dart` | PASS; fixture manifests and EPUB privacy guard. |
| `git diff --check` | PASS. |

The optional skips remain the three private/local-book suites and the native
CFI export without its output environment variable. The full suite exercised
the saved pre-seam capture present locally (120 cases / 2,733 pages). Finish
logs are ignored at `build/d4/finish-{build,format,analyze,test,fixtures}.log`.
The memory probe was not rerun; both measurements above are prior-session
evidence, with the completed seam run also recorded in `reader-engine.md`.

Build generation/dependency resolution rewrote 52 generated Dart files and
seven native registrants with LF. All 59 were verified byte-equal to HEAD
after newline normalization and restored to their checkout CRLF; no generated
content or out-of-scope diff remains. No dependency, fixture/vector, network,
library, storage, planning artifact or other-checkout changes were made.
The developer identity helper reported uninitialized in this worktree; the
named existing task is `in_progress`, and no Trellis metadata was changed.

D4 is ready for integration on `s3/d3-worker-import`, uncommitted and unstaged.
S4 must consume each section resource lease once (or dispose an abandoned
preload), capture settings/content/session identity, close retired workers and
prove product lifecycle/cancellation, decoding/fonts, near-limit memory and
performance on iPhone. No D4 implementation blocker remains. The old synthetic
temp-directory cleanup limitation above is historical and was not retried;
this session does not claim device acceptance or completion of the S3 parent.

## Phase F worker memory scaling

2026-10-27, Windows host, Dart 3.13.5, checkout base `c488778` on
`ios-build/s3-runtime-server`. **Round 1 was confounded by larger preloaded
resources. Round 2 holds those bytes fixed and detects no archive-size-driven
prepare/preload RSS increase beyond observed run-to-run variation.** The host
envelope below is specific to this fixed-metadata, fixed-resource experiment;
it does not close S3's iPhone/device gate or prove a universal worker heap bound.
No implementation under `lib/` or `test/` was changed to influence the result.

### Round 1: scaled resource payloads (confounded)

The following method, observations and decision are retained as the first
measurement round. Its decision to leave the design row unchanged applied at
that time; Round 2 below supplies the isolated comparison and current decision.

#### Method

Command: `dart run tool/reader/publication_memory_probe.dart`. This remains a
manual host tool outside `flutter test`. The parent streams two generated EPUBs
to temporary files and hashes each incrementally before measurement. Both have
the same single-section source, OPF/manifest, 200 stored image entries and four
image references in the first section. Only each image's padded encoded payload
changes: 104,857 versus 1,048,576 bytes, producing archives of 21,008,001 bytes
(about 20 MiB) and 209,751,801 bytes (about 200 MiB). The tiny valid PNG prefix is
preserved; this is encoded-resource access, not image decoding or rendering.
The stored ZIP method deliberately makes archive size track payload size.

For each of three repetitions, the parent runs the small then large input in
separate fresh `dart run ... --measure <path> <sha256>` child processes: six
measured processes, each spawning a real `PublicationWorker`. The parent does
not construct a whole-archive buffer. The child takes its RSS baseline after
worker spawn, calls file-backed `prepare`, then `preloadSection` for the first
section with a fresh `ReaderResourceBudget`, checks all four resource lengths,
disposes the preload and awaits worker close. It records `ProcessInfo.currentRss`
at baseline/prepare/preload/close and `ProcessInfo.maxRss` at each stage.
There is no warm-up, forced GC, VM-heap isolation or subtraction of JIT costs.

`prepareDelta` and `preloadDelta` subtract current baseline RSS from each sample.
`peakDelta` subtracts current baseline RSS from the process high-water mark
through preload; `peakGrowth` instead subtracts the pre-existing baseline
high-water mark. Neither isolates worker-only allocations. All include the root
VM, compiler, worker, parsing/styles and transfer overhead. Negative endpoint
deltas reflect VM/GC/Windows working-set variation, not negative allocation.
The parent validates four preloaded entries, expected sampled/retained bytes,
zero reserved bytes and zero accounting after disposal/close, and prints median,
minimum and maximum by size. All temporary EPUBs and their directory were
successfully deleted by `finally`. Raw command output is ignored at
`build/phase-f-worker-memory.log`.

#### Per-run observations

Exact bytes; size labels refer to total archive size above. Resource accounting
is retained encoded bytes while the preload is live. Reserved bytes during
preload and retained plus reserved bytes after disposal/close are **zero in all
six runs**.

| Size | Run | Baseline RSS | After prepare | After preload | After close | Retained encoded bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| ~20 MiB | 1 | 421,916,672 | 322,240,512 | 322,867,200 | 322,940,928 | 419,428 |
| ~20 MiB | 2 | 408,702,976 | 319,778,816 | 320,364,544 | 320,438,272 | 419,428 |
| ~20 MiB | 3 | 420,102,144 | 325,480,448 | 326,017,024 | 326,090,752 | 419,428 |
| ~200 MiB | 1 | 411,672,576 | 329,670,656 | 338,247,680 | 325,513,216 | 4,194,304 |
| ~200 MiB | 2 | 414,806,016 | 330,825,728 | 339,447,808 | 327,524,352 | 4,194,304 |
| ~200 MiB | 3 | 406,921,216 | 329,207,808 | 337,780,736 | 324,902,912 | 4,194,304 |

| Size | Run | Prepare delta | Preload delta | Baseline max RSS | Peak RSS | Peak delta | Peak growth |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| ~20 MiB | 1 | -99,676,160 | -99,049,472 | 421,941,248 | 539,230,208 | 117,313,536 | 117,288,960 |
| ~20 MiB | 2 | -88,924,160 | -88,338,432 | 408,776,704 | 543,219,712 | 134,516,736 | 134,443,008 |
| ~20 MiB | 3 | -94,621,696 | -94,085,120 | 420,151,296 | 551,268,352 | 131,166,208 | 131,117,056 |
| ~200 MiB | 1 | -82,001,920 | -73,424,896 | 411,697,152 | 546,746,368 | 135,073,792 | 135,049,216 |
| ~200 MiB | 2 | -83,980,288 | -75,358,208 | 414,871,552 | 548,208,640 | 133,402,624 | 133,337,088 |
| ~200 MiB | 3 | -77,713,408 | -69,140,480 | 406,970,368 | 547,504,128 | 140,582,912 | 140,533,760 |

In every run, the maximum recorded after prepare, after preload and after close
is the same value shown as Peak RSS. No later high-water increase was observed.

#### Medians and ranges

MiB (1,048,576 bytes), rounded to three decimals; each size has three runs.
Ranges are observed minimum to maximum, not confidence intervals.

| Metric | ~20 MiB median | ~20 MiB range | ~200 MiB median | ~200 MiB range |
| --- | ---: | ---: | ---: | ---: |
| Baseline RSS | 400.641 | 389.770 to 402.371 | 392.602 | 388.070 to 395.590 |
| After prepare RSS | 307.312 | 304.965 to 310.402 | 314.398 | 313.957 to 315.500 |
| Prepare delta | -90.238 | -95.059 to -84.805 | -78.203 | -80.090 to -74.113 |
| After preload RSS | 307.910 | 305.523 to 310.914 | 322.578 | 322.133 to 323.723 |
| Preload delta | -89.727 | -94.461 to -84.246 | -70.023 | -71.867 to -65.938 |
| Peak RSS | 518.055 | 514.250 to 525.730 | 522.141 | 521.418 to 522.812 |
| Peak delta | 125.090 | 111.879 to 128.285 | 128.816 | 127.223 to 134.070 |
| Peak growth | 125.043 | 111.855 to 128.215 | 128.793 | 127.160 to 134.023 |
| After close RSS | 307.980 | 305.594 to 310.984 | 310.434 | 309.852 to 312.352 |
| Retained encoded bytes | 0.400 | 0.400 to 0.400 | 4.000 | 4.000 to 4.000 |
| Reserved / accounted after close | 0 | 0 to 0 | 0 | 0 to 0 |

#### Envelope and conclusion

The observed conservative peak increase through prepare+preload is
117,313,536 to 134,516,736 bytes for ~20 MiB and 133,402,624 to 140,582,912 bytes
for ~200 MiB. The absolute process peak never exceeds 551,268,352 bytes
(525.730 MiB). Peak-delta medians differ by only 3.727 MiB and their ranges
overlap; the absolute peak ranges overlap too. This alone is insufficient to
claim all integrated worker residency is independent of archive size.

The larger input consistently has higher prepare/preload endpoint RSS, with
non-overlapping observed ranges both in absolute RSS and baseline-subtracted
deltas. Median preload RSS rises 14.668 MiB; median preload delta rises
19.703 MiB, exceeding either size's observed within-size delta range width
(10.215 and 5.930 MiB). Prepare deltas also have disjoint ranges. Accordingly,
the measured samples do **not** support "does not grow with compressed size
beyond noise" for integrated prepare+preload. The known retained payload itself
increases from 419,428 to 4,194,304 bytes because the four referenced images grow;
transient copies, VM/JIT/GC and working-set variation remain confounders. These
six measurements cannot identify how much of the increase is attributable to
each cause, nor establish linear or whole-archive retention.

Per the Phase F stop condition, no flat-residency ceiling with margin is adopted
and the design's "Compressed archive in worker" budget row is unchanged. The
major evidence finding remains open for investigation; the claim was not
weakened or tuned to make this result pass. The 128 MiB encoded-resource budget
is still not an RSS budget. This host/JIT experiment is not an iPhone limit or
acceptance proof, does not cover arbitrary archive metadata/source complexity,
and does not cover decoded images, fonts, page layout/rendering, long-running
lifecycle or OS memory termination. AC10/device evidence stays separate.

#### Verification and spec corrections

The three stale passages now describe the library at `/` with active-session
routes, the actual `BookRepository` family using session transport/publication
guards, and implemented localized connection feedback (TLS/final root/network).
The neighboring stale claim that activation/UI are later slices was corrected
in the same error-handling passage. No product contract changed.

| Command | Result |
| --- | --- |
| `dart format tool/reader/publication_memory_probe.dart tool/reader/publication_memory_fixture.dart` | PASS; two files formatted, one changed. |
| `dart run tool/reader/publication_memory_probe.dart` (captured with PowerShell `Tee-Object`) | PASS as a measurement tool: six processes, three runs per size, resource checks passed, temporary files deleted. Scaling acceptance did not pass. |
| `flutter analyze` | PASS; no issues. |

No full `flutter test` run: changes are confined to manual tools and the allowed
documentation; `lib/` and `test/` are unchanged. No code generation, dependency,
fixture, staging, commit, push, branch switch or other-checkout mutation occurred.
The final format check (`dart format --output=none --set-exit-if-changed` on the
two changed tools) and `git diff --check` passed. A read-only comparison of the
captured JSON against all 12 per-run evidence table rows passed, including
identical stage peaks and zero accounting checks.

### Round 2: fixed first-section resources, unread archive growth

2026-10-27, same Windows host and Dart 3.13.5; six fresh measured processes,
strictly alternating small/large three times. All samples are included, with
no warm-up, forced GC, exclusions or retries. The baseline, prepare, preload,
peak and close stages and their definitions are unchanged from Round 1.
Only the fixture isolation and parent-side validation/accounting checks changed.

#### Fixture isolation and validation

Both archives now have **209 entries**, including 200 stored PNG entries.
The single linear spine section `EPUB/s0.xhtml`, the OPF/container, every other
non-variable entry and `image-0.png` through `image-3.png` are byte-identical.
Each of those four preloaded images is **104,857 bytes**, so sampled/retained
encoded bytes are **419,428 in both sizes**, with the same four resource paths.
The supplementary XHTML, also identical between sizes, references the remaining
196 stored images. Their payloads alone grow from 104,857 to 1,067,835 bytes per
entry. Total archive sizes are **21,013,310 bytes (20.039854 MiB)** and
**209,756,998 bytes (200.039862 MiB)**. ZIP framing/header offsets, size fields
and CRC values necessarily change with the variable payload sizes; entry count,
name lengths and central-directory byte length stay fixed.

The supplementary section is manifest-listed **outside the spine** and is not
referenced by the first section. This is necessary because
`EpubSectionLoader._discover` in
`lib/features/reader/data/epub/epub_loader.dart` visits every spine item,
including non-linear items, and loads their referenced resources for token
alias ordering. Merely moving larger images into a later spine section would
still read/digest them during prepare. Here that traversal only reaches the
unchanged first section and its four unchanged images. The unused image payloads
are not requested/expanded/digested by prepare or preload. ZIP open still reads
their headers and bounded EOF/search/read-buffer bytes; this is not a claim of
zero physical I/O touching any byte within their stored ranges.

Before spawning measured children, the parent opens both files with file-backed
`EpubArchive.openFile`, compares the complete ordered entry-name lists, then
compares **all 13 non-variable entry payloads byte for byte** and prints their
SHA-256 values. It closes both audit handles. Examples:

| Shared entry | SHA-256 (same in both fixtures) |
| --- | --- |
| First linear source `EPUB/s0.xhtml` | `c9eba5a20d396d53d2e86bcc046173805120b73e32307601668cbc5d99744377` |
| Each of `EPUB/image-0.png` through `image-3.png` | `b020dcbcf1ecce3a9d79d9ac4695986a7cffce378a7df312cbce69d2c0a7b9d6` |
| `EPUB/supplement.xhtml` | `496c7869cd2f0c1e8476dae29d67ad8403647542cca1048f5082bf26f36e5423` |

Each child uses the same real integrated worker path as before. The parent
additionally requires exactly `EPUB/image-0.png` through `image-3.png`,
419,428 sampled/retained bytes, zero reserved bytes and zero accounting after
preload disposal plus worker close. All six runs passed. Fixture generation,
whole-file streamed SHA-256 and byte-equality auditing occur in the parent,
outside measured child processes; there is no whole-archive child buffer.
OS file caches are not flushed. This is whole-process host/JIT RSS, including
root VM/compiler and worker, not an isolate heap allocation measurement.

#### Per-run observations: ~20 MiB

Exact bytes. Peaks are process high-water marks; prepare, preload and final
process max RSS were identical within each of all six runs.

| Run | Baseline RSS | After prepare | After preload | After close | Retained encoded bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 396,963,840 | 323,174,400 | 323,772,416 | 323,846,144 | 419,428 |
| 2 | 398,352,384 | 320,102,400 | 320,712,704 | 320,786,432 | 419,428 |
| 3 | 401,035,264 | 319,381,504 | 319,827,968 | 319,905,792 | 419,428 |

| Run | Prepare delta | Preload delta | Baseline max RSS | Peak RSS | Peak delta | Peak growth |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | -73,789,440 | -73,191,424 | 397,008,896 | 549,224,448 | 152,260,608 | 152,215,552 |
| 2 | -78,249,984 | -77,639,680 | 398,458,880 | 545,882,112 | 147,529,728 | 147,423,232 |
| 3 | -81,653,760 | -81,207,296 | 401,092,608 | 551,993,344 | 150,958,080 | 150,900,736 |

#### Per-run observations: ~200 MiB

Exact bytes; same stage and accounting definitions as above.

| Run | Baseline RSS | After prepare | After preload | After close | Retained encoded bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 405,180,416 | 324,165,632 | 324,747,264 | 324,820,992 | 419,428 |
| 2 | 407,609,344 | 324,685,824 | 324,702,208 | 324,775,936 | 419,428 |
| 3 | 417,124,352 | 321,216,512 | 321,732,608 | 321,810,432 | 419,428 |

| Run | Prepare delta | Preload delta | Baseline max RSS | Peak RSS | Peak delta | Peak growth |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | -81,014,784 | -80,433,152 | 405,225,472 | 550,465,536 | 145,285,120 | 145,240,064 |
| 2 | -82,923,520 | -82,907,136 | 407,629,824 | 557,752,320 | 150,142,976 | 150,122,496 |
| 3 | -95,907,840 | -95,391,744 | 417,230,848 | 557,821,952 | 140,697,600 | 140,591,104 |

In both sizes and all runs: 200 stored image entries; four preloaded paths;
sampled bytes = retained bytes = 419,428; reserved bytes = 0; accounted bytes
after disposal/close = 0. Both temporary EPUBs and their directory were deleted
successfully by the parent's `finally`.

#### Medians and ranges

MiB (1,048,576 bytes), rounded to three decimals. Three runs per size;
ranges are observed minimum to maximum, not confidence intervals.

| Metric | ~20 MiB median | ~20 MiB range | ~200 MiB median | ~200 MiB range |
| --- | ---: | ---: | ---: | ---: |
| Baseline RSS | 379.898 | 378.574 to 382.457 | 388.727 | 386.410 to 397.801 |
| Baseline max RSS | 380.000 | 378.617 to 382.512 | 388.746 | 386.453 to 397.902 |
| After prepare RSS | 305.273 | 304.586 to 308.203 | 309.148 | 306.336 to 309.645 |
| Prepare delta | -74.625 | -77.871 to -70.371 | -79.082 | -91.465 to -77.262 |
| Prepare max RSS | 523.781 | 520.594 to 526.422 | 531.914 | 524.965 to 531.980 |
| After preload RSS | 305.855 | 305.012 to 308.773 | 309.660 | 306.828 to 309.703 |
| Preload delta | -74.043 | -77.445 to -69.801 | -79.066 | -90.973 to -76.707 |
| Preload / final max RSS | 523.781 | 520.594 to 526.422 | 531.914 | 524.965 to 531.980 |
| Peak delta | 143.965 | 140.695 to 145.207 | 138.555 | 134.180 to 143.188 |
| Peak growth | 143.910 | 140.594 to 145.164 | 138.512 | 134.078 to 143.168 |
| After close RSS | 305.926 | 305.086 to 308.844 | 309.730 | 306.902 to 309.773 |
| Sampled encoded bytes | 0.400 | 0.400 to 0.400 | 0.400 | 0.400 to 0.400 |
| Retained encoded bytes | 0.400 | 0.400 to 0.400 | 0.400 | 0.400 to 0.400 |
| Reserved bytes | 0.000 | 0.000 to 0.000 | 0.000 | 0.000 to 0.000 |
| Accounted after close | 0.000 | 0.000 to 0.000 | 0.000 | 0.000 to 0.000 |

#### Conclusion and host envelope

The earlier **+19.703 MiB** preload-delta median difference cannot be attributed
to archive size alone: that round also enlarged the preloaded payload tenfold
(419,428 to 4,194,304 bytes), with worker/transfer/root copies in the integrated
path. Round 2 removes that confound, keeping retained payload exactly equal.

In Round 2 the large-minus-small median differences are **-4.457 MiB for
prepare delta**, **-5.023 MiB for preload delta**, and **-5.410 MiB for peak
delta**. Prepare-delta ranges overlap and have widths 7.500/14.203 MiB;
preload-delta ranges overlap and have widths 7.645/14.266 MiB. Peak-delta
ranges also overlap (widths 4.512/9.008 MiB). The prepare and preload median
shifts are smaller than either size's within-size delta width, with no increase
for the larger archive. There is **no detected archive-size-driven growth
beyond run-to-run noise in this isolated comparison**.

Absolute endpoint RSS medians are still 3.875 MiB (prepare) and 3.805 MiB
(preload) higher for the large archive, with overlapping ranges. Its baseline
RSS median was already 8.828 MiB higher before archive open. Absolute peak
medians differ by 8.133 MiB with overlapping ranges; the baseline-subtracted
peak instead decreases. These differences and negative endpoint deltas show
why the result must remain a host/process envelope rather than a claim of
identical allocations, a fitted scaling law or an isolate-only memory ceiling.
The six samples cannot rule out smaller size effects or explain VM/GC/working-set
changes precisely.

For this **fixed 209-entry metadata and fixed 419,428-byte preload** workload,
the pooled six-run conservative peak delta has median **141.941 MiB** and
observed range **134.180 to 145.207 MiB**. Add an explicit **32 MiB engineering
margin above the observed maximum**, then round upward: **178 MiB above the
post-spawn baseline** is the adopted host planning envelope. The pooled
absolute process peak has median **525.693 MiB**, range **520.594 to
531.980 MiB**; the same 32 MiB margin gives a rounded **564 MiB whole-process
host envelope**. The margin is planning headroom, not measured extra usage,
a statistical confidence bound or an iPhone limit. These pooled medians use
the average of the two middle samples (per-size medians use the middle of three).

Only the design's **Compressed archive in worker** budget row is updated to
record those host envelopes and link here. No other design budget is changed.
The compressed archive is file-backed; this experiment supports no detected
growth when only unread stored payload size increases, not flat RSS with
increasing entry count, metadata, source complexity or resources actually read.
All-spine resource discovery can read later sections' image bytes; that separate
workload is intentionally outside this isolation result. The 128 MiB encoded
resource budget is not an RSS budget. Image/font decode, layout/rendering,
long-running lifecycle, iPhone near-limit preparation and memory termination
remain separate unverified device evidence; S3-AC10 is still open.

#### Round 2 verification

| Command | Result |
| --- | --- |
| `dart format tool/reader/publication_memory_probe.dart tool/reader/publication_memory_fixture.dart` | PASS; both files formatted. |
| `dart run tool/reader/publication_memory_probe.dart` | PASS; byte-equality audit, six alternating fresh processes, three runs per size, fixed resource accounting, temporary-file cleanup. |
| `flutter analyze` | PASS; no issues. |
| `dart format --output=none --set-exit-if-changed tool/reader/publication_memory_probe.dart tool/reader/publication_memory_fixture.dart` | PASS; no formatting changes. |
| `git diff --check` | PASS. |

Round 2 raw values were captured in the command/tool transcript, without adding
another evidence artifact. The exact tables above are generated from those
JSON records and include every run; per-size summaries were checked against
the records. No full `flutter test` or code generation was run for this
manual-tool-only change. No `lib/`, `test/`, dependency or fixture assets
changed; the three existing spec corrections are preserved. No staging,
commit, push or branch switch occurred.
