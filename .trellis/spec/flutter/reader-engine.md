---
name: flutter-reader-engine
description: EPUB source, CFI, canonical v1, native layout, proven anchors and bounded page motion
paths:
  - lib/features/reader/**
  - test/features/reader/**
  - tool/reader/**
---

# Native Reader Core

## 1. Scope / Trigger

S2 establishes a reusable reflowable reader core, not product persistence or
reading activity. Apply this contract when S3-S6 load books, restore positions,
extend layout or connect product UI. Paths below are relative to
`lib/features/reader/` unless a repository-root path is given.

- `data/{epub,source,cfi,canonical,worker}/` is pure Dart: no `dart:ui`, Flutter,
  providers or widgets. Its snapshots can be built in a worker isolate.
- `engine/{style,layout,pagination,support,motion,surface}/` may use `dart:ui`.
  No providers; widgets belong only in `engine/surface/`. Hand-written core
  models and typed proof/navigation results are intentional exceptions to the
  HTTP-model/provider conventions in [Data Layer](./data-layer.md).
- Diagnostics imports the reader core; the reader never imports diagnostics.
  `engine/motion/turn_session.dart` owns injected timing/frame/trace/failure/
  evidence sinks. `TurnClock` supplies milliseconds and ordinary-task scheduling;
  do not bind the controller to a recorder or a global clock.
- Prepared resources have explicit owners. Keep parsing, preparation and
  disposal outside pointer/ticker callbacks. Product checkpoints, outbox,
  visibility sampling and activity writes remain later-stage work.

## 2. Signatures

| Boundary | Implemented API / source |
| --- | --- |
| Container/book | `EpubArchive.open(Uint8List, {EpubLimits limits})`; `EpubBook.open(Uint8List, {limits, tokens})`, `loadSection(int) -> SourceDocument` (`data/epub/`) |
| Verified publication import | `PublicationWorker.prepare(String path, ContentIdentity identity, {PublicationTag? tag, PublicationCancellation? cancellation}) -> Future<PreparedPublication>` (`data/worker/`); file-backed `EpubBook.fromArchive(archive, package, {tokens})` stays inside worker |
| Shared content identities | `ContentIdentity(BookKey, String sha256, {parserVersion, canonicalVersion})`; `ContentChange({ContentIdentity? previous, required ContentIdentity next})` in `lib/core/config/` |
| Parser | `SourceParser.parseTree(String, String) -> ParsedSection`; `parse(String, {mediaType, transform, protect}) -> SourceDocument` (`data/source/source_parser.dart`) |
| CFI | `Cfi.parse`, `serialize`, `collapse`, `compare`, `sort`, `export`, `resolve`, `resolveLocal`, `resolvePackageNode` (`data/cfi/cfi.dart`) |
| Canonical | `CanonicalIndex.build(SourceDocument)`; `CanonicalEntry.canonicalToUtf16` (`data/canonical/canonical_text.dart`) |
| Style/layout | `CssStyleResolver.resolve(book, sectionIndex, document, settings)`; `SectionPreparer.prepare(PrepareRequest, {control, onPageReady}) -> Future<PreparedSection>` |
| Conservation | `checkConservation(PreparedSection, StyledDocument) -> ConservationReport` (`engine/pagination/conservation.dart`) |
| Anchors | `PageAnchors.exportVisible(int) -> VisibleAnchor?`, `prove(String, {expectedIdentity}) -> AnchorProof`, `locate(SourcePosition)`; `AnchorKeeper.accept`, `acceptPage`, `reflow` (`engine/pagination/anchor.dart`) |
| Turns | `ReaderTurnController.turnPage(TurnDirection) -> Future<TurnResult>`, `pointerDown/Move/Up/Cancel`, `tick`, `cancel`, `settingsChanged`, `layoutChanged`, `suspend`, `resume`, `close` |
| Surfaces | `PageSurfacePool.prepare(section, pageIndex, theme) -> Future<PageSurfaceLease?>`; `PreparedReaderSession` implements `TurnSession`; `PreparedReader` owns local repaint/ticker integration |

## 3. Contracts

### EPUB loading and inert source projection

`epub_archive.dart` validates ZIP framing with an app-owned bounded reader before
hydrating any package `ZipFileHeader`, then indexes exact names (last duplicate
wins at distinct local offsets). `EpubLimits.maxDirectoryBytes` defaults to
16 MiB for the central directory; `maxMetadataBytes` defaults to 8 MiB for the
sum of central/local names and extras, entry comments, the archive comment and
the ZIP64 EOCD extensible sector.
Both are injectable and independent of expanded-content limits. At the default
20,000 physical entries, fixed central headers cost 920,000 bytes and the
variable budget permits about 419 bytes per entry across both headers; the
16 MiB cap also bounds directories when callers raise the entry count.
EOCD search reads at most 65,557 tail bytes and requires the declared comment
to end at EOF. Physical counts must match both EOCD counts. Every local offset
must be unique, inside the archive and before the central directory. Local
headers, compressed data and any data descriptors must form disjoint ranges
that cannot cross the central directory. Local variable lengths are charged
before reading extras. Aliases, overlaps, invalid ranges and budget violations
fail as content-free `ParseException` before package hydration; do not rely on
`ZipDirectory.read` followed by admission checks. ZIP64 is supported within the
same bounds: resolve the locator/EOCD record and extra-field ID 1 before
admission, reading extra values in APPNOTE order only for corresponding
32-bit/16-bit sentinels. ID 1 without any required values is valid. Reject
missing/truncated fields, inconsistent counts or legacy/ZIP64 end values,
out-of-archive offsets, signed-integer overflow and multi-disk archives. The
ZIP64 record must fit before its locator; central data cannot overlap it.
Retain admitted sizes/offsets for hydration: decode central metadata without
local I/O, apply the validated values, then restrict `ZipFile.read` to the
admitted local range, including signed/unsigned 32-bit or ZIP64 descriptors.
`EpubLimits` counts every physical entry and its declared size before hydration
and expansion, including overwritten duplicates. Opening never decompresses
entries or reads symlink targets; link mode bits leave ordinary entry bytes.
Only stored/deflate entries are supported; encryption and other methods fail.
Lazy native reads use `ZipFile.decompress` -> `decodeLimited` ->
`NativeChunkDecoder` (platform zlib), with an app-owned sink checking emitted
bytes before accumulation. Returned length must equal the declared size and
CRC-32 must match; corruption fails as content-free `ParseException`. These
bounds cover one expansion of all physical entries, not repeated reads or
caller-retained copies. Native decoding may accept a missing zero-output final
byte when exact length and CRC still pass, unlike fflate's EOF rejection; the
generated prefix regression also requires byte-identical output. Do not use the
package's block inflater, which rejects valid level-1 deflate. `openFile(String,
{EpubLimits limits})` retains a shared file handle until synchronous, idempotent
`close()`; `open(Uint8List)` remains available and its close is a no-op. This
closes the S3 bounded-inflation carry-forward below; the worker protocol
prototype exists, and its reader-preparation integration remains Phase D work
(see the carry-forward list). Text is always UTF-8 with replacement, ignoring declared encodings;
the decoder removes one leading BOM. `epub_package.dart` reads the
container/OPF, manifest, ordered itemrefs including `linear="no"`, and nav/NCX.
`EpubBook.sections` drops itemrefs without manifest items. Preserve the original
itemref `sectionIndex`; do not confuse it with the filtered sections-list index.
CFI bases come from actual OPF element slots/IDs, never `/6` arithmetic.

Parser selection in `source_parser.dart`:

- `text/html` uses the HTML tree builder directly.
- XHTML first uses the project strict XML parser (`xml_parser.dart`); malformed
  XML selects HTML with `xml_parsererror`. A root with no namespace also selects
  HTML with `missing_namespace`. XML failure for non-XHTML media types throws
  `ParseException` rather than taking the XHTML fallback.
- `xml` supplies the XHTML/HTML4 entity table, not the XML parser. Doctype/entity
  behavior must match the committed browser vectors, not parser defaults.
- Order is initial parse -> loader resource rewrite -> serialize ->
  `protectBookDocument` -> serialize -> final reparse -> frozen `SourceDocument`.
  The final HTML reparse uses scripting-enabled parsing, without executing code.
  `epub_loader.dart` preserves archive attribute URLs and uses length-neutral
  resource tokens in stylesheet text; the default token length is oracle-origin
  specific. Head-text offsets are not portable across arbitrary Blob URL lengths.

`content_protection.dart` removes processing instructions, replaces active
elements in place with inert namespace-appropriate elements, keeps IDs and form
children, removes event/script URL/srcdoc attributes and prepends CSP metadata.
Do not simply delete all blocked nodes: that changes CFI slots. Frozen nodes
retain kind, namespace, attributes, parent/children and stable indices; Text and
CDATA remain distinct. Doctypes and HTML template-fragment children are excluded
from the frozen node list. CFI and canonical indexing use this final projection.
The core executes no scripts and fetches no remote resources.

### Verified worker import and layout facts (S3 D3)

Use `prepare` for the verified-download handoff. The caller supplies an
immutable, closed/flushed file and its actual streamed SHA-256; the worker does
not rehash it or prove remote freshness. `core/config/content_identity.dart`
and `content_change.dart` are feature-independent pure Dart values shared by
cache/library and reader code. Identity equality includes server-scoped
`BookKey`, lowercase 64-hex SHA-256, parser version and canonical version.
Versions must be positive. `publicationParserVersion = 1` and
`publicationCanonicalVersion = 1` are explicit compatibility constants; the
latter must equal `canonicalTextVersion`. An incompatible identity fails before
replacing the current publication. `ContentChange` permits an absent previous
identity, requires the same BookKey when present, and never mutates progress.

The worker opens with `EpubArchive.openFile`, validates container/package and
the first original linear itemref, and projects/styles only that section for
layout inspection. An unresolved first linear itemref or absent linear source
fails; do not silently select a later readable section. Section-list indices
are filtered indices; `spineIndex` retains the original OPF slot and CFI bases
come from OPF structure. XHTML-to-HTML fallback remains oracle-compatible.
Canonical indexing runs in the worker on the final inert projection. A valid
image/SVG-only page can have canonical length zero and still be ready.

`PreparedPublication` contains only detached immutable values:

- `identity`, deeply frozen `snapshot.package` and `snapshot.sections`;
- DC `metadata` (ordered titles, creators, languages, identifiers);
- `layoutFacts` with raw package rendition, raw progression, first publication
  language, and ordered per-section facts;
- `firstSection` with index/href/CFI base, parser/fallback classification,
  canonical version/length/signature and a resource-reference inventory.

Each `SectionLayoutFacts` records effective fixed/reflowable mode, original
itemref properties and rendition after layout/orientation/spread/page-spread
overrides. Legacy display options still supply layout defaults. Raw package
rendition remains separate, including viewport/sourceViewport declarations.
The inspected section's `source` retains viewport/source-viewport meta content
and SVG node indices with raw width/height/viewBox. Its `style` records computed
root/body writing mode/direction, explicit root/body dir declarations, visible
writing modes and `rtlRunCount` (visible non-root/body elements with computed
RTL, matching S2's informational block count; not bidi text segmentation).
Other sections have null source/style and `inspection = notInspected`, never
invented horizontal/LTR facts. Later source reads do not mutate this snapshot.

The first-source inventory follows local CSS imports/URLs and SVG dependencies,
terminates cycles, preserves missing/external/data/fragment references, and
never fetches them remotely. Each reference records sourcePath, original URL,
nullable local path, declared media type and local presence. No decoded image,
font, rasterization or rendering acceptance is implied. The existing loader's
whole-spine resource graph remains for oracle token alias ordering; this is
not a whole-book style/layout inspection. It retains digests/ordinals, not an
expanded resource mirror. The prepared first SourceDocument stays in the worker
for `loadSection`; only canonical summary facts cross in the import response.

`prepare` uses the existing typed ID/tag/internal-generation queue (one running,
eight pending). Product callers supply their captured session tag and still
guard cache publication with the session owner. An omitted tag derives from
the content identity; it is not a session lease. Reopen/prepare invalidate old
results even for identical tags/content. Running cancellation completes the
caller immediately and holds the physical slot until the discarded terminal
reply; synchronous parse/inflate is not preempted. Discovery yields between
dependencies. Close drains the running work, closes the handle and awaits exit.
Returned identity must match the requested identity. No archive/book/loader,
closure, Flutter object or lazy read crosses the port.

Fixed, mixed, RTL-progression, RTL-language and vertical facts never fail import.
`prepare` does not call `detectBookLayout` or `requireSupported`; S4 owns renderer
verdicts. D4 adds the source/resource seam, preloaded values, section leases and
resource-cache accounting below; both archive and detached preparation are tested.
File-backed import is not a total worker RSS or iPhone memory proof.

### Preloaded resources and retained budget (S3 D4)

#### 1. Scope / Trigger

Downloaded publications need synchronous, already-preloaded resource access
without root-isolate archive inflation. The complete seam-routed engine list
is below; paths are relative to `lib/features/reader/engine/`.

| File | Seam-only change |
| --- | --- |
| `pagination/section_preparer.dart` | Accept detached href/CFI/source/styles and resources; route fonts, presence and intrinsic-image reads; transfer/release the resource lease on success/failure. |
| `pagination/prepared_section.dart` | Own the resource source, use it for later image reads and release it once on disposal; ignore image requests after disposal. |
| `layout/font_registry.dart` | Adapt the legacy archive entry point and route unchanged size/byte checks through `loadResources`. |
| `layout/block_builder.dart` | Adapt the legacy archive argument and route image/SVG presence checks through the source. |
| `surface/page_surface_pool.dart` | Read encoded images from the prepared section's resource source. |
| `style/css_style_resolver.dart` | Route archive text/presence reads through the archive adapter. |
| `support/layout_flags.dart` | Route display-option text reads through the archive adapter. |
| `support/unsupported_layout.dart` | Route OPF language text reads through the archive adapter. |

The added disposal guards enforce lease lifetime. Layout, shaping, pagination,
painting, capability decisions and probe output keep their existing behavior.

#### 2. Signatures

`data/resources/reader_resource_source.dart` defines `ReaderResourceSource`:
synchronous `bytes(path)`, `contains(path)`, `size(path)` and idempotent
`dispose()`. `ArchiveReaderResourceSource` delegates all reads, presence and
declared sizes to the existing archive and does not close its caller's archive.
It preserves the probe's in-memory resource behavior and work guard. The
`ReaderResourceText.text` extension uses the archive's exact UTF-8 replacement/
BOM behavior, with the same storage work guard. All engine encoded-byte,
declared-size, presence and text reads go through this interface.

Use `PrepareRequest.resources(resources, sectionHref, sectionBase, ...)` with
the worker plan's source/styles and captured settings/content ID. It needs no
root `EpubBook`, archive or lazy callback. The existing `PrepareRequest(book:
...)`, `LayoutBlockBuilder(archive: ...)` and `FontRegistry.load(archive, ...)`
remain compatibility paths that immediately adapt archive access; existing
tests need no edits. The probe explicitly passes `ArchiveReaderResourceSource`.
`FontRegistry.loadResources` keeps the 32 MiB declared-size check before bytes,
the same format/load failures, aliasing and missing-font fallback. Image/SVG
presence, intrinsic sizing, lazy decoded-image leasing and page surfaces all
read through the section resource owner, with unchanged layout/painting.

#### 3. Contracts

`PublicationWorker.preloadSection(index, {settings, budget, cancellation,
onMiss}) -> Future<PreloadedPublicationSection>` uses two serialized, tagged,
generation-checked requests. First the worker loads the projected source,
discovers that section's CSS/SVG/local references using the D3 inventory and
resolves its styles at the supplied settings. The detached plan contains source,
frozen style lookups, href/CFI base, references and local declared lengths.
Freezing must preserve the original computed-style identity graph with an
identity-keyed memo: `InlineAccumulator` merges adjacent runs using `identical`.
Equal style values copied separately split runs and can alter native shaping/
rounding. Preserve sharing across element/character-data/root style lookups;
do not weaken geometry assertions to conceal this contract.
External/data/fragment references are never fetched. No book/archive/loader or
lazy resource callback crosses the boundary. The root reserves the missing
encoded bytes before requesting their transfer; existing cache hits are pinned
and are not retransmitted. The worker preflights the batch, enforces the
individual worker entry bound (64 MiB by default), inflates/verifies entries
and sends `TransferableTypedData`. A batch cannot exceed 128 MiB. Root-side
commit validates exact lengths/backing-buffer sizes and retains read-only views.

`ReaderResourceBudget.shared` is the product default across all adapters and
workers: `retainedBytes + reservedBytes <= 128 MiB`. Smaller injectable budgets
are for isolated tests; product composition must share one owner. Entry keys
include an opaque publication-generation session and exact path, never just a
book ID or path. Admission pins cache hits, charges missing bytes and evicts
only unleased entries, oldest last-access first. If pins/reservations prevent
admission, `ReaderResourceException(budgetExceeded)` occurs before transfer;
overlapping in-flight keys return `busy`, without duplicate retention.

Each preloaded adapter leases its entries. `dispose()` drops its references and
immediately evicts any entry whose last lease is released; `releaseToCache()`
instead leaves unleased LRU candidates for an explicit warm-cache handoff.
Disposed adapters cannot read again. Reopen/prepare/close/worker failure retire
the previous generation's reservations, live adapters and idle bytes. Session
retirement is immediate on the root; normal worker close still drains physical
work and waits for archive closure/exit. Cancellation discards late replies and
rolls back reservations, but does not preempt synchronous inflation.

`PreloadedReaderResourceSource` serves only its leased entries. Missing reads
return null; `miss(path)` distinguishes absent, not-preloaded, disposed and
retired entries. Optional diagnostics receive only the `ReaderResourceMiss`
enum, never paths, URLs or resource content. No fallback archive read is allowed.
Callers must dispose an abandoned preload. Outside a forbidden motion callback,
`SectionPreparer.prepare` consumes its resource lease: success transfers it to
`PreparedSection`, and any failure/cancellation disposes it, including before
block creation. `PreparedSection.dispose()` releases decoded images, blocks
and encoded resources once. Callers must not share one adapter across multiple
preparations or dispose a consumed preload early; ask the worker for another
lease. Independent section adapters share underlying retained entries safely.
Bind server-session retirement to worker close; close revokes root resource
leases immediately, then asynchronously drains/joins the worker.

#### 4. Validation & Error Matrix

| Condition | Result |
| --- | --- |
| Pinned/reserved bytes prevent admission | `ReaderResourceException(budgetExceeded)` before transfer. |
| A missing key is already reserved | `ReaderResourceException(busy)`; no duplicate retention. |
| Wrong transfer keys, lengths or backing-buffer sizes | Reject as protocol/`invalidTransfer`; release reservation. |
| Publication generation changes or worker closes/fails | Revoke leases/reservations; reject stale work. |
| Resource absent or not preloaded; adapter disposed/retired | Null read and content-free miss classification; no I/O fallback. |
| Preparation cancellation/failure | Release encoded lease; preserve existing block cleanup. |
| Font declared size exceeds 32 MiB | Reject before reading bytes; preserve missing-font fallback. |

#### 5. Good/Base/Bad Cases

Good: independent section leases share cached bytes, and disposing the last
owner returns accounting to zero. Base: bundled probe/archive callers retain
the same prepared output. Bad: sharing a consumed adapter between preparations
or counting the encoded limit as a process-memory ceiling.

#### 6. Tests Required

Host parity covers 14 bundled fixtures, every section and all three gate
settings: 120 cases / 2,733 pages. Archive-adapter output exactly matches the
pre-seam host capture, and detached worker preparation matches archive output
for page/source maps, lines/geometry, text runs, images, unsupported items and
font chains. New tests wrap actual preloaded resource calls in
`ReaderWorkGuard.callback`; an archive inflation fallback would assert. Layout,
font loading and decoding still run normally outside that resource-only zone.
Image `ensureImages` and `PageSurfacePool.prepare` exercise later encoded reads
through the same guarded source. All existing tests/vectors remain unchanged.

#### 7. Wrong vs Correct

Wrong: freeze each node's equal style into a separate object, or recover a
preloaded miss by reading the archive on root. Correct: memoize frozen styles
by source identity and serve only leased preloaded bytes; report the miss.

#### Host evidence and S4 device gate

Host experiment, Windows/Dart 3.13.5, 2026-10-27:
`dart run tool/reader/publication_memory_probe.dart` generated a 209,751,801-byte
EPUB containing 200 stored 1 MiB image entries and preloaded four referenced
entries (4,194,304 bytes). The final D4 run's process RSS (both isolates) was
407,011,328 bytes before prepare, 329,207,808 after prepare, 337,805,312 after
preload and 325,111,808 after close; maximum RSS was 546,168,832. Accounting
returned to zero. The prior partial-D4 run is retained in task evidence.
The negative sampled deltas reflect VM/GC/working-set variation; the peak rose
139,042,816 bytes above the baseline maximum. These are source import/preload
observations, not section layout/image decode measurements. Compared with A3's
200 MiB archive-only file-open delta of -7,507,968 bytes (memory-open:
+202,850,304), this broader worker experiment includes loader graph hashing,
source/style work and transfer overhead and cannot establish an equivalent
flat-RSS guarantee. Temporary memory-probe files were deleted.

The budget bounds retained encoded buffers, not transient inflate/transfer
copies, source/style graphs, decoded rasters, registered fonts or process RSS.
S4 must bind these APIs into the product reader/session owner and prove device
cancellation/lifecycle cleanup, near-limit peak memory and absence of OS memory
termination on iPhone, plus the existing font/performance/rendering gates.
Abrupt isolate kill cannot promise synchronous native file-handle finalization;
use normal `close()` for
deterministic file release.

### CFI and canonical coordinates

`data/cfi/` targets pinned Foliate behavior, not stricter generic conformance:
paths, `!` indirection, escapes, assertions, ranges, element anchors, merged
Text/CDATA chunks, even/odd and virtual edge slots all follow oracle vectors.
Unknown assertion parameters are dropped; only `;s=` survives. `resolve` skips
the package indirection; `resolveLocal` does not. `resolvePackageNode` lets the
caller locate the actual OPF itemref. Reversed DOM range endpoints collapse to
the end; outside-root boundaries may use node index `-1`. Chunk boundaries may
resolve to a preceding text node's end. Keep raw imported strings separately if
needed; compare structurally with `Cfi.compare`, not string identity.

`SourcePosition.offset` is UTF-16 for character data and a child index for
element positions. Surrogate-half offsets are valid compatibility inputs; never
substitute Unicode scalar or grapheme counts for CFI offsets.

Canonical normalization is `canonicalTextVersion = 1`:

- Walk Text nodes under body (document element if no body), excluding
  script/style/noscript/template and SVG/MathML subtrees. CDATA does not count.
  CSS visibility does not change canonical coordinates.
- Filter code points in `White_Space`, `Cc`, `Cf`, `Cs`; unpaired surrogates
  therefore do not count. Use `unicode_exclusion_table.g.dart`, generated by
  `tool/reader/generate_unicode_table.dart` from the `webkit` entry of
  `test/fixtures/reader/oracle/unicode-table.json`. Do not use Dart's runtime
  Unicode classification. The browser Unicode database version is unavailable;
  engine version plus complete ranges pin the behavior.
- `length` counts retained code points. Entries contain section-canonical
  `start`, `length`, original `utf16Length` and each retained point's UTF-16 start
  in `canonicalToUtf16`. This is not a CFI offset table; preserve both domains.
- Signature is `fnv1a64:<16 lowercase hex>` over canonical code points encoded
  as UTF-8, in order. `fnv1a64.dart` uses four 16-bit limbs, avoiding reliance on
  native 64-bit overflow. Do not hash UTF-16 code units or rendered text.

### Native layout, page plans and conservation

`engine/style/` parses packaged/inline CSS, resolves the supported cascade and
inheritance, then applies reader overrides. `LayoutBlockBuilder` builds block/
inline runs and explicit `ParagraphMap` entries for exact, collapsed, removed,
synthetic and line-break content. List markers/indentation/generated ruby
parentheses are synthetic; author `rt`/`rp` text keeps source coordinates.

`SectionPreparer` loads fonts, builds each `ui.Paragraph` once at final width,
sizes raster/SVG blocks, and passes blocks to `SectionPaginator`. Pack complete
lines with widow/orphan handling; paint clipped translated slices without
relayout per page. `PreparationControl` yields/cancels between work units;
one synchronous paragraph layout remains indivisible. `onPageReady` can observe
finished pages, while `prepare` returns only after the whole section is ready.

`page_plan.dart` defines immutable page fragments and `PageMapEntry`: section/
page indices, `layoutKey`, ordered source `spans`, `imageNodes`, `first`/`last`.
`identity` combines layout key and page index. `canonicalIntervals(index)` maps
these spans to half-open canonical intervals. They are candidate geometry facts,
not foreground visibility observations or permission to record reading activity.

`LayoutIdentity.key` (`engine/pagination/layout_identity.dart`) includes layout
engine/style version, content ID, section, viewport, DPR, typography settings,
loaded-font signature and generation. Theme and reduced motion are absent.
Insets are represented by reader margins, not a separate safe-area field.
Parser/normalizer versions are not separate key fields; unlike design §5.1,
current code does not encode them. Invalidate/bump versions if these inputs change.

`checkConservation` independently walks eligible styled source and verifies
non-whitespace UTF-16 units in order, paragraph-map integrity and source coverage,
every line exactly once, each eligible image/atomic item placed once or listed
unsupported, and line/image geometry inside the content rectangle. It is not
literal whitespace-preserving concatenation. Failures contain indices/counts,
never source prose.

`engine/support/unsupported_layout.dart` inspects package/itemref/display-options
fixed layout, RTL page progression, root/body direction, RTL publication language
without explicit direction, and rendered vertical writing (including vendor
aliases). `detectBookLayout` checks every section; `requireSupported()` throws
`UnsupportedLayoutException` with reasons. The S2 probe refuses a mixed book
before reading; product import uses the separate facts contract above. Isolated
RTL runs inside an LTR section are informational, not a refusal.
Detection must not replace an accepted anchor or succeed with an empty reader.

Raster images are contained to the content box. The guarded SVG raster-wrapper
path keeps the outer `svg` anchor; other vectors use `flutter_svg` preparation.
`svg_support.dart`/`svg_picture.dart` surface partial/unrenderable SVG. Current
differences include inline images becoming blocks, inline ruby, sup/sub without
baseline shift, inline list markers, wrapping `pre`/`nowrap`, flattened tables,
line-only block backgrounds, and unpainted SVG text/foreignObject/filters/external
images. Borders, text-transform and pseudo-element generated content are absent.
These are implemented scope limits, not a promise of full CSS/browser fidelity.

### Anchor export, proof and reflow

`PageAnchors.exportVisible` selects a non-whitespace Text position nearest the
visible text midpoint using UTF-16 lengths; image-only pages use a proven image
element. Export returns null if it cannot prove the page. `prove` checks expected
layout identity, CFI resolution, structural resolve/export equality and geometry
of the resolved start inside the foreground page. Visibility uses the complete
owning glyph cluster without rewriting an imported surrogate-half offset.

`AnchorKeeper` changes `acceptedCfi` only after proof. `reflow(newSection)` proves
the existing CFI on the new layout and never rewrites it. Failure keeps the old
accepted CFI: no page-one, nearest-paragraph or percentage fallback. Turn proof
also checks preview origin and layout generation, then destination layout,
section, page index/count/identity and session anchor/visibility proof through
`TurnAcceptance.verify` (`engine/motion/turn_acceptance.dart`). Valid distinct
anchors on the same page need not have identical strings.

### Motion and prepared-surface ownership

The authoritative thresholds, tap zones, velocity window, easing, settle/flick
durations, rebound and late-neighbor catch-up values live in
`engine/motion/page_turn_gesture.dart` (`PageTurnRules` and pure functions) and
`engine/motion/page_turn_engine.dart` (`PageTurnEngine`). Read those files when
porting/changing motion; do not duplicate their numeric table in another layer.
Gesture coordinates are logical pixels; `GestureInput.time`/`TurnClock.now` are
milliseconds. Admission freezes a ruler; queued held pointers rebase against the
latest accepted origin when promoted.

- `ReaderTurnController` owns the current intent plus `TurnIntentQueue.capacity`
  (eight waiting intents, FIFO). Overflow resolves only the new intent as
  `queueFull` with `queue-full`; do not silently drop or reorder waiting inputs.
- Preparation and navigation run in ordinary control tasks using the zone
  captured before admission. Drain prior work before binding a motion pair;
  retain newest pointer samples/reversals while preparation is pending. A late
  neighbor catches up via `DragCatchUp` using `PageTurnRules`. No uncovered
  incoming page is painted as if prepared.
- Settings/layout/background/close cancel speculative work, terminate waiting
  intents and invalidate generation tokens. Pair-generation checks also reject
  stale preparation. Late prepared results release leases; cancelled navigation
  restores the latest accepted origin before fresh admission. Resume re-proves
  the accepted position; failed restore leaves the controller failed.
- Navigation acceptance follows proof and publishes one destination. Once
  `TurnIntent.accepted` is true, `resolve` returns committed even if a later
  callback fails/cancels. Waiting inputs may fail; the accepted turn is not
  rolled back by a post-acceptance callback failure.
- Reduced motion skips animation while retaining navigation/proof/acceptance.
  Missing/failed/timed-out preview may attempt a verified static turn; count it
  as `staticFallback`, separately from reduced motion. Static mode never bypasses
  anchor proof or resource admission. Preparation timeout is configurable on
  `ReaderTurnController`; it is separate from gesture settlement constants.
- `PreparedReader` uses local `ValueNotifier<double>` and repaint-only `Flow`
  transforms with stable picture children and repaint isolation. No provider
  rebuild, parse, layout, decode, font load, pagination, canonical traversal,
  storage or JSON serialization occurs on a pointer/ticker path.

`PageSurfacePool` (`engine/surface/page_surface_pool.dart`) permits three
presented surfaces plus one preparation/handoff reserve. Pending owners count
against the same four-owner cap, including cancellation/close. Defaults are
16 MiB picture bytes and 48 MiB decoded images; configured values are the source
for diagnostic caps. There is no idle picture cache. Leases are reference-counted,
release is idempotent and the last release disposes the picture/image leases.
Pool close prevents pending work from publishing; existing leases remain valid
until released. Picture accounting uses `ui.Picture.approximateBytesUsed`, not
total process RSS. `ReaderImageCache` can grant one oversize image lease; the pool
then refuses an over-budget surface. Do not describe the cache alone as a hard
peak-allocation bound. Session close is idempotent; closed bind/unbind/restore
must not mutate disposed frame notifiers.

`ReaderWorkGuard` (`data/source/reader_work_guard.dart`) marks callback zones
only in debug/assert builds. Guard entry points before mutation; this includes
final surface release. Posting a future inside the guarded zone is insufficient:
use the controller's captured control zone. The guard is an assertion aid, not a
release-mode scheduler or an isolation guarantee for unguarded future APIs.

### Carry-forward and code/design boundaries

- S3 Phase A: archive reads now use the bounded raw-directory index, native
  emitted-byte limits, exact length/CRC-32 checks and file-backed open described
  above. D3's worker import keeps archive/source/style/canonical work off root
  and returns detached readiness/layout facts without a capability verdict.
  D4's bounded preloaded resource seam, section ownership, cache/lease accounting,
  prepared-output parity and near-limit host worker measurements are implemented
  above. Full product/session wiring and device integration remain S4 work.
  Host archive measurements do not establish total worker RSS or iPhone limits;
  downloaded-publication integration and device validation remain required.
- S4: production `FontRegistry` still caps each font at 32 MiB without a shared
  cross-book count. A0 added standalone scene/process-font policy owners in
  [Reader Resource Admission](./reader-resource-admission.md); A3 must integrate
  them before claiming product enforcement. Font mappings and fallback
  availability require device evidence, not host Ahem results.
- S4: known HTML-mode gaps are head-level template isolation, noscript closing
  an open paragraph, and attribute URL rewriting in script-enabled noscript raw
  text. Expand edge fixtures if encountered; pure-SVG spine interop is unproven.
- Design §3 describes retaining the original tree. The public
  `EpubBook.loadSection` returns only the final projected snapshot;
  `ProjectedSection` retains raw text, not an exposed original parsed tree.
  Design §3 also omits the implemented missing-namespace XHTML fallback.
- Design §4 proposed two 32-bit limbs/BigInt and a browser Unicode version;
  implementation uses four 16-bit limbs and an explicitly null Unicode version.
- Design §5.1's broader identity and incremental preparation are limited as
  described above. `PreparedReaderSession.optionalWorkAllowed` is currently a
  no-op; optional-work policy belongs to its caller. The probe section owner is
  bounded to four cached sections. Coalesce racing warm/prepare calls in S4:
  warm calls coalesce per direction, but concurrent prepare can hold a second
  lease; the common owner cap still applies.

## 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| Invalid/empty/oversize ZIP, corrupt entry, missing package/readable section | Typed `ParseException` from the EPUB boundary; no successful empty book |
| `prepare`: invalid/truncated/over-limit ZIP | Content-free `PublicationImportException(invalidArchive)`; failed handle released, worker reusable |
| `prepare`: invalid/missing container or OPF, empty spine, no resolvable first linear itemref | `PublicationImportException(invalidPackage)`; no ready result |
| `prepare`: missing/empty/unparseable/invalid-root first source or corrupt discovered resource | `PublicationImportException(invalidFirstSection)`; worker reusable |
| `prepare`: noncurrent parser/canonical version | `PublicationWorkerException(incompatibleIdentity)` before replacing current publication |
| `prepare`: fixed/mixed/RTL/vertical | Successful facts and first-source readiness; no renderer-support claim |
| Malformed XHTML / namespace-less XHTML | HTML fallback with recorded error class; non-XHTML XML failure throws |
| Unsupported publication layout | `UnsupportedLayoutException` with reasons; accepted anchor unchanged |
| CFI grammar/resolution failure | `CfiException` with reference error class; anchor proof maps it to `unresolved`/`roundTrip` |
| Failed anchor proof | `AnchorFailure`: `unresolved`, `roundTrip`, `notLaidOut`, `notVisible`, `identityMismatch`, `injected`; preserve accepted CFI |
| Cooperative cancellation | `PreparationCancelled`; dispose built blocks and suppress stale publication |
| Missing image/font or partial SVG | Listed failure/unsupported marker or font fallback; never silently claim complete rendering |
| FIFO full / controller blocked | `TurnResultKind.queueFull` / `blocked`; no speculative acceptance |
| Preview/proof mismatch | Failed turn and recovery; if restore fails, failed controller; no fabricated destination |
| Surface owner/byte budget exhausted or pool closed | `prepare` returns null and releases partial work; no over-cap publication |
| Forbidden work in callback | Debug assertion before work/mutation; schedule via the ordinary control zone |

## 5. Good/Base/Bad Cases

- Good: prepare a section, export/prove a visible CFI, then accept exactly once;
  reflow proves the same CFI against the new identity.
- Base: an unready neighbor yields a counted static turn only if navigation and
  proof succeed; an unsupported layout yields recoverable reasons.
- Import base: ordinary reflowable source prepares; fixed first pages also
  prepare with dimensions/resource facts and may have zero canonical characters.
- Import good: mixed sections keep per-item overrides and unstyled sections
  remain `notInspected`. Import bad: treating those sections as horizontal/LTR
  or calling the probe's whole-book refusal as a download acceptance gate.
- Bad: persist a page index as source position, count canonical intervals as read,
  overwrite an anchor after failed proof, or decode from a ticker.

## 6. Tests Required

See [Testing](./testing.md) for regeneration and private-input switches. Maintain
oracle equality for package/projection/CFI/canonical; native-to-browser CFI loops;
conservation at all three gate settings; every-page anchor proofs and reflow
failure preservation; unsupported-layout refusal and SVG/image markers. Keep
motion tests for thresholds/easing, late neighbors, 1+8 FIFO/overflow/rebase,
cancellation/stale callbacks, one acceptance per commit, callback failure after
acceptance, reduced motion and static fallback. Surface/widget tests must assert
actual painted movement with stable build counts, owner/byte caps, pending decode
through close, final release/disposal, and suspend/resume. Guard tests call real
entry points inside and outside callback zones, asserting no mutation on refusal.

D3 import tests generate simple/complex fixed, both mixed override directions,
valid fixed/SVG first pages, progression/language/vertical and corrupt EPUBs
in-test. Assert raw/resolved rendition, source dimensions, exactly one styled
section, not-inspected later sections, first linear/CFI slots, canonical/source
parity for all bundled oracle fixtures, typed recoverable errors and handle
release, nested-discovery cancel/reopen/close and worker reuse. The VM graph
audit in `test/features/reader/data/worker/` reflects every instance field,
including private fields, requires final fields and a value-type allowlist,
rejects lazy book/archive controls and proves snapshots outlive file deletion.
Its VM-only source is test data because Flutter's SDK has no `dart:mirrors`;
the Flutter test runs it with the package config using the standalone `dart`.

## 7. Wrong vs Correct

```dart
// Wrong: replace a failed restore with an unrelated accepted position.
if (!keeper.reflow(newSection).ok) keeper.acceptPage(newSection, 0);

// Correct: return the proof to the caller; acceptedCfi stays unchanged.
final proof = keeper.reflow(newSection);
return proof;
```

Wrong: `ReaderWorkGuard.callback(() => preparer.prepare(request))` or treating
`page.map.canonicalIntervals(index)` as reading activity.

Correct: prepare in an ordinary control task, animate retained surfaces only,
and leave visibility/activity acceptance to the later product contract.

Wrong: `detectBookLayout(book).requireSupported()` during product import, or
returning `EpubBook` to let root-side code inflate later. Correct:
`await worker.prepare(verifiedPath, identity, tag: capturedSessionTag)` and
consume immutable metadata/facts; obtain sources/resources through the worker
and leave renderer verdicts to S4.
