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
