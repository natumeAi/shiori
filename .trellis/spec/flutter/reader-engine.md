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

- `data/{epub,source,cfi,canonical}/` is pure Dart: no `dart:ui`, Flutter,
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
`UnsupportedLayoutException` with reasons. A mixed book is refused before
reading. Isolated RTL runs inside an LTR section are informational, not a refusal.
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
  above. The worker protocol prototype keeps archive/source work off root.
  Phase D still owns the bounded preloaded source/resource adapter for reader
  preparation, cache/lease accounting and near-limit worker memory evidence.
  Host archive measurements do not establish total worker RSS or iPhone limits;
  downloaded-publication integration and device validation remain required.
- S4: `FontRegistry` caps each font at 32 MiB but cannot unload engine fonts or
  bound their cross-book count. Add a session/restart policy. Font mappings and
  fallback availability require device evidence, not host Ahem results.
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
