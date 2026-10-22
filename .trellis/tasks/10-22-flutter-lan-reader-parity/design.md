# Design: native Flutter client for lan-reader

Status: final planning proposal, awaiting the user's subsequent implementation
approval. Primary target: iPhone 14 Pro Max, built from a Windows workflow.
The requirements and acceptance ownership remain in `prd.md`.

## 1. Architecture

```mermaid
flowchart LR
  UI[Flutter screens and reader controls] --> State[Riverpod screen state]
  State --> Repo[Typed repositories]
  Repo --> HTTP[Dio and selected server session]
  HTTP --> NAS[Existing lan-reader APIs on NAS]
  Repo --> Store[Local configuration, checkpoints and outbox]
  NAS --> EPUB[EPUB bytes and HTTP validators]
  EPUB --> Parse[Dart package and source-document model]
  Parse --> Layout[Flutter layout and prepared pages]
  Layout --> Motion[Gesture and animation controller]
  Motion --> Accepted[Verified accepted content position]
  Accepted --> Store
  Store --> Delivery[Progress and activity delivery]
  Delivery --> HTTP
```

Retain Riverpod/codegen, Dio, Freezed/JSON serialization, typed go_router,
logging and ARB localization. All app/reader behavior and rendering are
implemented in Dart/Flutter. OS plugins for file selection, storage or sharing
may provide platform integration; no WebView/JavaScript EPUB engine supplies
the reader.

## 2. Module ownership and spec changes

```text
lib/app/                        router, persistent main shell, parity themes
lib/core/config/                selected server configuration/session
lib/core/network/               Dio, URI resolution, typed HTTP handling
lib/core/storage/               durable storage and file-cache infrastructure
lib/core/diagnostics/           bounded timing capture and export
lib/features/servers/           connection form and recovery UI
lib/features/library/data/      Book/Folder/Shelf models and repositories
lib/features/library/presentation/  shelf, folders, actions, drag coordination
lib/features/home/              dashboard repository/controller/presentation
lib/features/statistics/        statistics repository/controller/presentation
lib/features/reader/data/       publication/source model, CFI, activity records
lib/features/reader/engine/     native layout, page map, page preparation
lib/features/reader/presentation/  controls, gestures, motion, image viewer
lib/l10n/                       user-facing Chinese text and semantics
```

This extends the current feature-first structure with reader-private pure
engine code. Keep cross-feature imports through owning data modules; `core/`
does not import feature code. Server session primitives live in core so Dio
does not depend on a feature's presentation controller.

Implementation must update existing Flutter specs alongside the affected
changes: runtime endpoint config and durable cache/outbox replace the
scaffold's compile-time-only/no-persistence rule; the directory guide gains
the engine boundary; theme guidance gains explicit reference tokens rather
than seed-generated appearance; testing gains parity/device performance gates.
These changes follow the user's explicit requirements, not a separate product
redesign. Retain package/codegen pins unless compatibility work proves a need.

New dependency reasons: archive/XML/CSS utilities preserve EPUB structure;
image/SVG utilities preserve illustrations; local storage persists server
selection, accepted checkpoints and immutable activity; file/share integration
supports upload and diagnostics. Evaluate compatible maintained versions
before adding them, document the reason in the owning task, and update the
approved-dependency table. Do not adopt an entire viewer just for convenience.

## 3. Server connection and API boundary

- Add a first-launch connection form and an accessible server-change entry
  styled consistently with the reference. Keep the three existing main tabs.
- Normalize an HTTP(S) deployment root, including any path prefix. Reject
  missing host, embedded credentials, query and fragment. Persist locally,
  not in committed config or a binary build flag.
- Join `api/...` and backend-relative cover paths under that deployment root;
  preserve already encoded resource paths. Test root, prefix, port, trailing
  slash and percent-encoded path cases.
- A new server session cancels old requests and invalidates provider/page
  generations. Cache, book state and outbox keys include the normalized
  endpoint; pending data never follows a book ID to another server.
- Validate health body (`service`, `database == ok`) and read-only response
  shapes. Distinguish network failure, permission denial, HTML login pages,
  incompatible service and unavailable database. The currently deployed NAS
  version is not yet known.
- Follow exact envelopes/camelCase/nullability in
  `research/backend-contract-audit.md`. A 304 has no JSON body. HTTP 200 on
  batch APIs does not mean every operation/section succeeded.
- Preserve raw server position timestamps for acknowledgment comparisons;
  SQLite UTC strings without a timezone must not be parsed as device-local
  time. Validate JavaScript-safe integer IDs and atomic nullable chapter pairs.
- Use the existing unauthenticated LAN API contract. Proxy-auth integrations
  are not invented as part of this migration; an auth response must be clear
  and recoverable rather than decoded as book data.

iPhone talks directly to the NAS. CI builds use generated fixtures and do not
need access to private NAS addresses or books. Add the appropriate local
network purpose description and test grant/deny/re-enable on the phone.
Verify the actual Dio and image transport before changing ATS settings; Dart
sockets and platform-owned networking have different policy boundaries.
Do not automatically add a global arbitrary-load exception or server CORS.

## 4. Local data and caching

Local settings hold the selected endpoint, local reader appearance, view
preferences and active-reader intent. A durable record store owns accepted
checkpoints, immutable activity JSON and delivery outcomes. All of this, and
every cache, lives in Application Support/Caches. The Documents directory is
user-visible through iOS File Sharing (enabled in S1 for diagnostic exports)
and holds only files the user is meant to take away. Prefer a small
transactional SQLite-backed implementation when selected; do not put a
critical outbox solely in best-effort preferences. Driver/package selection
is an implementation feasibility item, with existing tests kept platform-free.

EPUB files are downloaded atomically to app storage. Retain their opaque HTTP
ETag/Last-Modified and a digest of actual downloaded bytes. On connected open,
revalidate using existing file validators; a 304 is usable only with a valid
local file, otherwise fetch the full file. Clear manual refresh bypasses a
doubtful validator. Do not use book title, publication identifier, shelf
revision or `updatedAt` as a content digest.

Derived parsing/page caches include endpoint, imported book ID, byte digest,
parser/normalization version and layout generation. Layout keys include
viewport, direction, font metrics and reader settings; appearance keys include
colors/theme. Theme-only repaint should not unnecessarily repaginate.
Resource eviction must never delete pending activity or the last accepted
checkpoint. Enforce bounded image/page/archive allocations and release all
handles on session disposal.

No offline download-management product is added. An already loaded book can
continue through transient disconnection; local caching supports that behavior
and recovery. A whole-library offline guarantee is outside this release.

## 5. EPUB/source model and native pagination

First-release content: ordinary horizontal LTR reflowable novel/light-novel
EPUB 2/3, TOC, illustrations and normal text styling. Detect explicit fixed
layout, vertical writing and RTL before enabling reading; show an explanatory
return/retry path and preserve server progress. Do not label an unsupported
publication a successful empty book.

Preserve package/spine order, original XHTML/HTML node identity, namespaces and
UTF-16 text offsets. Keep three related representations:

1. **Source model:** exact navigable structure for CFI, including inert slots.
2. **Canonical index:** reference v1 filtered text coordinates and signatures.
3. **Layout model:** styled blocks/inlines and source-linked image anchors.

The first corpus must exercise paragraphs/headings/lists/quotes, inline
emphasis, indentation/alignment, whitespace, sizes/spacing, line breaks,
chapter fragments, Unicode/supplementary characters, and images/SVG. Evaluate
ruby/superscript/subscript and embedded-font cases as normal prose fixtures;
never discard their text to simplify pagination. Resolve packaged styles and
relative resources, then apply the same reader-setting override semantics.
The supported CSS mapping is documented and fixture-backed during the reader
milestone; it is not a claim of full browser CSS conformance. If an ordinary
novel fixture cannot be represented correctly, fix or escalate it rather than
silently narrowing the accepted scope.

Use native Flutter text/paragraph layout and paint APIs. Archive parsing,
resource indexing, hashing and other transferable pure Dart work can run in
worker isolates. `dart:ui` layout/painting cannot simply be moved to those
isolates. Prepare layout incrementally on the root isolate, using bounded
windows for very long paragraphs and preserving source/glyph boundaries.
Window boundaries must also preserve shaping and line context; test for
content loss/duplication/reordering and boundary shaping changes rather than
assuming arbitrary UTF-16 chunks are equivalent. Measure indivisible layout
costs in the feasibility milestone.

The page map records visible source ranges, canonical intervals, image
anchors and chapter page indices. Cached intervals are candidate mappings,
not reading observations: recheck accepted generation, actual foreground/clip
visibility, the reference idle delay, and panel/image-viewer eligibility before
crediting coverage. CFI resolution is independent of native
page numbers. Preserve actual OPF itemref paths, text-chunk rules and imported
UTF-16 offsets; do not substitute `/6/<spine arithmetic>` or flattened text.
Round-trip and visible-page proof are mandatory before publishing restore.
Exact details and edge vectors are in `research/native-reader-contracts.md`.

SVG wrappers around a single full-size raster image may use a verified
lossless image fast path while keeping the SVG source anchor. General static
SVG still needs correct native rendering; the generated vector fixture tests
that the optimization does not silently discard non-wrapper graphics.

## 6. Reader motion, lifecycle and acceptance

Use a reader-local controller, separate from API/Riverpod screen rebuilds.
Maintain bounded prepared previous/current/next surfaces and a bounded input
intent queue matching reference behavior. Page content is prepared before
motion; animation updates transforms on stable subtrees/paint content. Do not
parse EPUB, synchronously decode images, repaginate or write storage in ticker
callbacks. Flutter caching is opportunistic: a `RepaintBoundary` alone is not
proof that the incoming page is already cheap to rasterize.

Port source decision/timing rules for direction lock, tap/drag/flick/rebound,
rapid input, boundaries, reduced motion and panel/image-viewer blocking.
Commit exactly one accepted position only after the settled target is proven
against source/layout generation. Canceled, superseded, boundary and failed
turns never publish a candidate checkpoint or reading coverage.

Every async completion carries server/session/layout identity. Resize,
typography/font/image changes, backgrounding and disposal invalidate stale
work, drain motion and restore the last accepted source position. On a failed
saved-position restore, retain the record and offer retry or the reference's
explicit chapter-start recovery; do not overwrite it with page one.

## 7. Progress and statistics delivery

Position and activity are different streams. Serialize/coalesce position
writes per server/book. Keep a durable accepted checkpoint and acknowledge
only a matching submitted snapshot. Re-read after an uncertain write before
reconciling a pending position; do not blindly flush stale offline progress
over a newer server checkpoint. Backward reading is valid, so `max(progress)`
is not a merge rule. Existing API remains last-write-wins for concurrent
clients; a new universal concurrency guarantee requires backend cooperation.

Before any real coverage write, verify exact reference normalization: source
text-node order, excluded elements/namespaces, filtered Unicode code points,
FNV-1a UTF-8 digest, section length and source-to-visible interval mapping.
CFI offsets and canonical offsets are deliberately different coordinate
systems. Preserve chapter-count/index semantics from TOC boundaries.

Capture foreground reading with the reference checkpoint/idle/drift rules;
split duration at device-local hour boundaries, including midnight/DST.
Completion follows verified navigation semantics, not merely progress=1.
Persist a unique event and its exact JSON once before sending. Retry it
unchanged; handle per-record outcomes, duplicates, permanent rejection,
signature-mismatch coverage, and batch splitting. Keep delivery independent
from page motion. Refresh visible home/statistics after delivery; a library
snapshot 304 does not imply statistics are unchanged.

## 8. UI reproduction

`research/ui-parity-plan.md` owns UI01–UI14 coverage and source timings.
Use explicit colors, geometry, icon shapes, labels, sheets and transitions
from the reference. Golden tests and side-by-side iPhone checks complement
behavior tests. The user-approved reflow difference applies to book content,
not to arbitrary changes in app chrome, reading settings or interaction.

Native file pickers and OS permission/share sheets remain native. Library
upload remains serialized and non-idempotent; never retry a known committed
upload merely because the following shelf refresh failed. Respect partial
batch failures and the reference's limited compensating undo eligibility.

## 9. Build and device feedback

Observed local SDK: Flutter **3.47.7**, Dart **3.13.5**, framework revision
`abaf9c523780a608bd46686fd5e53740a07077f8`; use this as the first cloud pin,
subject to actual availability/compatibility checks. Retain the lockfile.
The repository is already public, so GitHub Actions standard macOS runners are
the primary host at no cost and with no secrets: manual dispatch or a push to
an `ios-build/**` branch, read-only permissions, SHA-pinned actions, an
explicit runner image and Xcode. Build/validate/package logic lives in one
host-neutral script; Codemagic's personal free allowance reuses it only if
the GitHub route is blocked or the repository becomes private. No paid usage
on either host. Every push publishes to the public repository and needs the
user's confirmation. Because only macOS can migrate the Xcode project, CI
uploads any `ios/` diff it produces for review and commit-back.

Every build carries `CFBundleVersion` from the CI run number and a
compile-time `BUILD_ID` (commit, host, run) shown in diagnostics and artifact
names. The app identifier `io.github.natumeai.shiori` replaces the
`com.example.shiori` placeholder before the first install and never changes;
changing it would orphan the device data container and spend a free-account
App ID (ten per rolling seven days; about three active sideloaded apps
including AltStore).

Cloud creates an unsigned **release device** app and an IPA container for
local signing. AltStore Classic/AltServer on Windows is the initial signing
candidate. Validate installation, independent launch, same-identifier update,
seven-day refresh, state retention and diagnostic export on the actual iOS
version. Do not use simulator artifacts or treat a signed archive as proof
that it runs. Personal Apple sign-in stays in the local signing flow.

A separate diagnostic entry point in the same Flutter app package can host a
synthetic pager and export bounded timings without adding debug controls to
the final reference UI. It shares the product's identifier and data
container, so probe and product builds replace each other on the phone
rather than coexisting. Raw exports are JSON files in the shared Documents
directory, copied to Windows over USB through the Apple Devices app or
iTunes File Sharing; the clipboard carries only a bounded summary. No custom
reader has been implemented yet. The first child task proves this
delivery/measurement path; it does not prove EPUB FPS. A truthful
unverified-presentation row can satisfy S1's reporting obligation, but cannot
satisfy parent AC4.

## 10. Performance protocol and unresolved technical risk

Use `research/performance-acceptance.md` for the final proposed test contract.
The iPhone display tops out at 120 Hz, so greater visible FPS is not a valid
claim for this device. Record OS refresh policy/thermal/power state separately
from application misses. Low Power Mode and Accessibility → Motion → Limit
Frame Rate can cap the display at 60 Hz, and no pure-Dart signal reports
them, so each run records them as user declarations and every report includes
the observed engine vsync-interval distribution, which exposes a system cap
(uniform ~16.7 ms with low stage cost) distinctly from application misses.
The reported display refresh rate is metadata, not effective cadence. Target
8.33 ms stages during 120 Hz animation and report distributions, missed
budgets, input latency proxies and all stalls.

FrameTiming and scheduled-frame cadence support application performance
analysis, not proof of physical scan-out or touch-to-photon latency. The first
two milestones must establish what reliable evidence is obtainable in the
Windows/free-sideload setup. Missing measurements remain unverified. If the
native pipeline cannot satisfy the agreed target, return to planning with
evidence; do not substitute a WebView or lower scope/FPS silently.

## 11. Backend handoff and rollback

`backend-handoff.md` distinguishes usable existing contracts, recommended
version/content-identity reporting and conditional position CAS. No mandatory
backend source change is established for the first vertical slice. The user
owns all lan-reader modifications and deployment.

New app storage schemas are versioned. Test fixtures and diagnostics are
server-namespaced. Feature commits remain independently reviewable; preserve
accepted checkpoints/outbox during rollback. No rollback step modifies NAS
books or reading history. Scope changes, failed feasibility, or materially
changed contracts require an updated plan and a fresh final review.
