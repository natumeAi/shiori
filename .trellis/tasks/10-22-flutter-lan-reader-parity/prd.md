# Flutter parity with lan-reader

## Goal

Deliver an iOS-first, fully Dart/Flutter implementation of lan-reader for the
user's iPhone 14 Pro Max. Entering the NAS deployment address must provide the
same library, reading information, app UI and frontend interactions. The
reader targets stable 120 FPS page turning when the device/system permits
120 Hz; this device cannot demonstrate visible rates above its 120 Hz maximum.

This parent task owns first-release scope, requirement traceability and final
integration acceptance. The complete app is not finished when only a reader
prototype or installation experiment works.

## Background and Evidence

The following source anchors preserve the initial 2026-10-22 audit. S1-S3
have since delivered the installation, core and runtime-server/preparation
foundations; their current status and S4 handoff are in the delivery map.

| Confirmed reference fact | Evidence |
| --- | --- |
| shiori has Riverpod, Dio, typed routing, localization, errors and tests, with a placeholder home and compile-time API address. | `lib/core/config/env.dart:1`; `lib/core/network/dio_provider.dart:11`; `lib/features/home/presentation/home_screen.dart:6` |
| Existing backend routes cover library, books, folders, position, activity and statistics, including original EPUB downloads. | `D:/Projects/lan-reader/server/src/app.ts:84`; `D:/Projects/lan-reader/server/src/routes/books.ts:207` |
| The current reader uses Foliate/browser layout with separate navigation, preparation, motion and accepted-position owners. | `D:/Projects/lan-reader/client/src/reader/types.ts:5`; `D:/Projects/lan-reader/.trellis/spec/frontend/reader-boundaries.md:21` |
| Position uses CFI/chapter data; reading activity uses canonical intervals/signatures, not page counts. | `D:/Projects/lan-reader/shared/src/reading.ts:22`; `D:/Projects/lan-reader/shared/src/readingStats.ts:1` |
| Reading appearance is local to the browser today. | `D:/Projects/lan-reader/client/src/hooks/useReaderSettings.ts:224` |
| Reference task archival does not prove 120 Hz acceptance; physical-device evidence was outstanding. | `D:/Projects/lan-reader/.trellis/tasks/archive/2026-09/09-23-reader-high-refresh-slide/prd.md:50` |

The initial reference audit reported version 3.3.0. The deployed NAS version
and reference Git identity were not reverified in this S4 planning turn.
Technical research and source anchors
are indexed by the implementation/check context manifests.

## Accepted Decisions and Constraints

- Task creation/planning approved on 2026-10-22; implementation still requires
  approval of the latest final planning summary in a subsequent message.
- Available hardware: Windows computer and iPhone 14 Pro Max only. The plan
  must not assume a Mac or Android device. Other release platforms are later
  work; portable Flutter boundaries are retained.
- Use free personal sideloading with the explained seven-day signing refresh.
  Use available free hosted macOS build allowance. Paid Apple membership,
  subscriptions and billable overages are not authorized.
- Signing route changed by the user on 2026-10-22: on-device signing with
  全能签 and a certificate a third party supplied to the user; AltStore Classic
  remains the documented alternative. App data survives updates only while
  the same certificate team signs the same identifier, and a shared
  certificate can be revoked at any time. Later stages must not rely on data
  that exists only on the phone across a certificate change.
- Hosted iOS builds run on GitHub Actions standard macOS runners, which are
  free for the already-public `natumeAi/shiori` repository. Codemagic's
  personal free allowance is the fallback if that route is blocked or the
  repository becomes private (accepted after plan review, 2026-10-22).
- The app identifier is fixed as `io.github.natumeai.shiori` before the first
  device installation and kept for all probe and product builds, so local
  settings, checkpoints and pending activity survive updates.
- Native line breaks, words per page and page counts may differ. App UI,
  reader settings and interactions still match; resume is accepted by the
  same content location, not by equal page numbers.
- First release covers ordinary horizontal, left-to-right, reflowable
  novel/light-novel EPUBs with TOC, illustrations and normal text styling.
  On 2026-10-26, the user expanded S4 to include both single-image fixed
  pages and complex static fixed-layout EPUBs, including publications that
  mix fixed pages with reflowable sections. Vertical writing and RTL reading
  remain deferred; adding fixed layout does not change those boundaries.
- For fixed pages, the user chose initial fit-page display plus whole-page
  pinch zoom and panning on 2026-10-26. Complex-page text can therefore be
  enlarged without changing authored geometry. Image-viewer parity remains
  available separately; zoomed-page gestures must not cause accidental turns.
- `D:/Projects/lan-reader` is read-only for this work. Required changes there
  are described for the user to implement/deploy separately.
- On 2026-10-27, the user chose local priority for conflicting offline
  progress: a pending, verified local position may overwrite a newer
  server/web position. This applies to unsent accepted reading intent, not
  an old acknowledged cache record. Server/book/content identity and CFI
  revalidation remain mandatory; an invalid candidate never gains priority.
- On 2026-10-27, the user chose actual-visible native text coverage and an
  explicit parity exception for the reference's inter-element occlusion
  overcounting. Reproducible covered-text interval/count differences are
  recorded and handed off separately; the reference fix does not block S4.
  Canonical text/signatures, time, completion, idempotency and all other
  shared behavior retain exact compatibility. Existing NAS history is not
  rewritten to compensate for the reference defect.
- On 2026-10-28 the user approved a second narrow coverage exception (D6).
  The reference classifies visibility on WebKit's integer-snapped rectangles,
  while native uses unsnapped geometry. A character may differ only when its
  native box lies within 1 px of a clip edge, and the reference rule applied
  to unsnapped geometry must reproduce the native verdict. Each case is
  recorded with its paired fixture.
- On 2026-10-27 the user decided how fixed-layout fidelity is compared after A0
  (D1-D4 in `s4-plan.md`). Reproducible WebKit raster defects become narrow
  recorded exceptions with a reference-fix handoff. Cross-engine pixel edges
  follow a conservative edge rule. Curved SVG text stays required.

## Requirements

| ID | Requirement |
| --- | --- |
| R1 | Enter, validate, persist and change the deployment address in the app without rebuilding. Keep requests, cached books and pending writes isolated by server. |
| R2 | Reproduce home, bookshelf, statistics, reader, settings, overlays and their state transitions on the target iPhone. Preserve searching, sorting, folders, upload, actions, batch operations, eligible undo, appearance and navigation. UI01–UI14 in `research/ui-parity-plan.md` trace this scope. |
| R3 | All client/reader behavior and rendering use Dart/Flutter. No embedded lan-reader frontend, WebView or JavaScript EPUB engine supplies the experience. |
| R4 | Target stable 120 FPS turns on the available physical device under nominal high-refresh conditions. Validate correctness, frame costs/cadence, delays and evidence limits; an average FPS counter or cloud-build success is not acceptance. |
| R5 | Preserve verified reading position and web/app interoperability. Open, navigation, reflow, close/reopen, recovery and cancellation cannot overwrite a valid saved location with an unverified candidate. |
| R6 | Preserve reading-time, visible-character, completion, goals and statistics semantics. Retries do not duplicate events; only actual eligible foreground content contributes coverage. |
| R7 | Reuse current NAS contracts when sufficient. Provide an actionable, separately owned backend handoff with required/recommended/conditional classification, fields, compatibility and validation. |
| R8 | Preserve reader/app behavior across supported lifecycle, viewport, resource and network changes. No skipped/duplicated pages, stale callbacks or unbounded resource growth. |
| R9 | Deliver a free build/install/update/refresh/diagnostic workflow using Windows, hosted macOS and the iPhone; no local Mac, Android phone, paid membership or unapproved cloud charge is a prerequisite. |
| R10 | Permit native reflow while preserving content, order, visual settings, app UI and interactions. Different pagination does not authorize missing content or inaccurate cross-client resume. |
| R11 | Support reflowable novels, single-image fixed pages, complex static fixed-layout publications and mixed-layout EPUBs. Preserve authored fixed-page geometry and content order, with initial fit-page display and whole-page pinch zoom/pan. Detect remaining unsupported features and explain them recoverably without changing saved progress or silently dropping content. |

## Acceptance Criteria

- **AC1 (R1):** A fresh installation accepts a reachable compatible server,
  displays its library and opens a book. Relaunch retains the address.
  Connection failure is recoverable; changing servers cannot mix their data
  or pending writes. Root and prefixed deployment URLs are covered.
- **AC2 (R2, R10):** UI01–UI14 have matched iPhone screen/interaction evidence
  and appropriate automated checks, including loading/empty/error states.
  Approved differences are native text reflow, necessary server setup UI,
  platform-owned file/permission/share dialogs and the selected whole-page
  fixed-layout fit/pinch/pan interaction specified in AC12.
- **AC3 (R3):** The shipping app and reader execute Dart/Flutter; no embedded
  browser reader supplies parsing-driven rendering, pagination or gestures.
- **AC4 (R4, R8):** Three-repeat physical-device scenario results include
  cold/warm, reverse/rapid turns, chapter boundaries, long paragraphs and
  images. The proposed engineering gate is >=99% of active-motion frames
  within each 8.333 ms UI/raster budget, no unexplained >=50 ms stall, and
  P95 warm admitted input to first motion submission <=two nominal intervals.
  Raw timings, omissions, queue/preparation/handoff/fallback data and
  presentation-evidence status are retained. These are engineering minimums,
  not proof of physical scan-out; missing required evidence is unverified,
  never a completed full performance target. Details and the early feasibility
  gate are in `research/performance-acceptance.md`.
- **AC5 (R5, R10):** Browser → Flutter → browser resume resolves the saved
  source anchor onto the foreground page despite different page numbers.
  Failed restore, canceled/interrupted turns and stale work preserve the last
  valid record; explicit chapter-start recovery remains available.
- **AC6 (R6):** Compatibility fixtures and cross-client scenarios agree on
  canonical text, signatures, intervals and server totals. Duplicate delivery
  adds nothing; preview pages and background gaps do not count. Date/hour/DST,
  partial outcomes, signature mismatch and completion cases are covered.
  The user-approved 2026-10-27 exception permits only demonstrated interval/
  character-total differences caused by the reference counting occluded text:
  native actual-visible coverage is authoritative for those fixtures, with
  both results and the separate reference-fix handoff recorded. The
  2026-10-28 D6 exception likewise permits only edge-character differences
  attributable to reference integer snapping. Other parity mismatches remain
  failures; neither exception changes canonical v1.
- **AC7 (R7):** `backend-handoff.md` is sufficient for separate backend work
  and accurately separates optional enhancements from existing functionality.
  No lan-reader files or deployment are modified by this task.
- **AC8 (R2, R8, R11):** The four existing local novel samples and generated
  Unicode/style/image/long-content fixtures pass content, lifecycle and
  repeated-navigation checks. Cache ownership remains bounded; reader scope
  is not silently reduced to obtain good timing results.
- **AC9 (R9):** A cloud-built release device app is locally signed, installed,
  independently launched, updated/refreshed with retained test state, and
  exports diagnostics through the selected Windows/iPhone flow. Validate this
  early, before relying on it for full product implementation.
- **AC10 (R11):** Vertical/RTL fixtures and remaining unsupported features are
  clearly identified with an explanation and recovery path. A fixed-layout
  declaration alone does not reject an otherwise supported publication.
  Unsupported content never becomes an empty or partly discarded successful
  read and does not overwrite saved position.
- **AC11 (R3-R6, R8, R10, R11):** Generated single-image, complex static
  fixed-layout and mixed-layout fixtures preserve authored page geometry,
  visible text/images, layering, clipping, fonts and reading order. Tests
  cover page dimensions, spread/orientation metadata, reflowable/fixed
  boundaries, TOC navigation, settings, lifecycle and web/native source-anchor
  restore. The local mixed-layout regression sample opens through all 23
  sections, including its six fixed image pages, without altering its source
  or omitting pages. Fixed-page text has correct canonical coverage; image
  pixels are not counted as text. The same AC4 performance thresholds and
  bounded-resource requirements apply to this corpus; S2's earlier success
  on other books does not establish these new results. Geometry and pixels
  are compared per S4a's per-channel contract. Only reproducible WebKit
  raster defects recorded as narrow exceptions are exempt.
- **AC12 (R2, R5, R6, R8, R11):** Fixed pages initially fit the reading area
  without cropping, support pinch zoom and bounded panning, and can return to
  fit-page display. A drag while enlarged pans content instead of turning
  pages; normal page gestures resume at fit. Image-viewer and explicit
  navigation remain coordinated. Accepted source position and actual-visible
  text coverage are proven after view changes, with no speculative writes
  during gestures. Viewport/lifecycle interruption and page changes cannot
  apply an obsolete transform to a different source page or lose content.

## Out of Scope

- Editing/deploying lan-reader, replacing its backend or database, or requiring
  a backend rewrite merely because the client changes.
- First-release vertical and RTL reading; Android/iPad/desktop release
  acceptance; new reading formats or unrelated product redesign.
- A WebView fallback, paid developer distribution or paid cloud usage.
- New app account systems/product cloud backends, synchronized reader
  appearance, a complete offline download manager, or stronger simultaneous-writer guarantees than
  the current backend without a separate reviewed requirement.
- Treating installation, a reduced prototype or software timing alone as full
  app/performance completion.

## Technical Notes and Deferred Feasibility

- Retain the scaffold stack; native source/CFI/canonical mappings and bounded
  Flutter layout must be proven before broad UI work. New parser/resource,
  storage and file/diagnostic dependencies are justified by R1/R3/R5/R6/R9/R11;
  the owning child records concrete package reasons and updates specs.
- Existing file ETags are size/mtime validators, not content hashes. Existing
  progress writes are last-write-wins. The handoff proposes additive content
  identity and conditional CAS without making them unproven prerequisites.
- Flutter layout cannot simply run in a worker isolate. Single-paragraph cost,
  font/SVG behavior, source parsing equivalence and memory use are early
  reader-feasibility checks, not already achieved results.
- The first device stage verifies obtainable metrics; the reader stage tests
  whether they can support the full acceptance wording. If physical
  presentation remains unverified or native performance fails, preserve the
  evidence and return for review rather than lower the target silently.
- Account connection, actual iOS version, signing setup, NAS endpoint and
  device-run evidence are operational inputs collected at their relevant
  stages; none is invented in this plan.
- Fixed-layout evidence and required capability coverage are recorded in
  `research/fixed-layout-expansion.md`. Source/CFI compatibility, authored
  geometry, actual-visible text coverage and device resource/performance
  acceptance apply to the expanded scope; the archived S2 gate is not proof
  of this new capability. Scripted/interactive content remains inert under
  the existing source-model contract.

## Artifacts and Delivery Map

- `design.md`: architecture, source/layout/data contracts and compatibility.
- `implement.md`: S1–S7 ordering, validation and stop/rollback points.
- `backend-handoff.md`: separately implementable backend recommendations.
- `implement.jsonl` / `check.jsonl`: curated real spec/research context.
- S1: `../archive/2026-10/10-22-ios-free-device-bootstrap` (completed).
- S2: `../archive/2026-10/10-22-native-reader-feasibility` (completed with
  conditional S4 GO; failed/unverified performance gates remain open).
- S3: `../archive/2026-10/10-26-runtime-server-library` (completed, 2026-10-27;
  owner-confirmed device acceptance): runtime server,
  typed reads, cache/worker foundation and minimal read-only verification UI.
- S4: `s4-plan.md` integrates the three planned children:
  `../10-27-native-fixed-layout-core` (S4a),
  `../10-27-reader-position-activity` (S4b), and
  `../10-27-product-reader-acceptance` (S4c). All remain planning.
- S5–S7 remain mapped in `implement.md` and are planned before execution.

Current planning status was refreshed on 2026-10-27. S1/S2/S3 are completed;
the parent is not complete. R11/AC10 were revised and AC11-AC12 added for
the user-approved fixed-layout expansion; other requirements remain in
force. S3's import handoff is accepted; its archived closeout report records
the owner-confirmed device result and retained S4 gates. Fixed-page
viewing and local-priority pending-progress delivery are decided. S4 child
PRDs, designs, execution plans, research and context manifests are prepared;
review of the latest summary is required before activating S4a. S4b/S4c
retain their explicit dependency gates and later review boundaries.
