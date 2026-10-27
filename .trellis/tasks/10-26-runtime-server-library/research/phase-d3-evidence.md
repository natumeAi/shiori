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
