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

| Confirmed reference fact | Evidence |
| --- | --- |
| shiori has Riverpod, Dio, typed routing, localization, errors and tests, with a placeholder home and compile-time API address. | `lib/core/config/env.dart:1`; `lib/core/network/dio_provider.dart:11`; `lib/features/home/presentation/home_screen.dart:6` |
| Existing backend routes cover library, books, folders, position, activity and statistics, including original EPUB downloads. | `D:/Projects/lan-reader/server/src/app.ts:84`; `D:/Projects/lan-reader/server/src/routes/books.ts:207` |
| The current reader uses Foliate/browser layout with separate navigation, preparation, motion and accepted-position owners. | `D:/Projects/lan-reader/client/src/reader/types.ts:5`; `D:/Projects/lan-reader/.trellis/spec/frontend/reader-boundaries.md:21` |
| Position uses CFI/chapter data; reading activity uses canonical intervals/signatures, not page counts. | `D:/Projects/lan-reader/shared/src/reading.ts:22`; `D:/Projects/lan-reader/shared/src/readingStats.ts:1` |
| Reading appearance is local to the browser today. | `D:/Projects/lan-reader/client/src/hooks/useReaderSettings.ts:224` |
| Reference task archival does not prove 120 Hz acceptance; physical-device evidence was outstanding. | `D:/Projects/lan-reader/.trellis/tasks/archive/2026-09/09-23-reader-high-refresh-slide/prd.md:50` |

The local reference checkout reports version 3.3.0; the deployed NAS version
has not been contacted or verified. Technical research and source anchors
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
  Fixed-layout publications, vertical writing and RTL reading are deferred.
- `D:/Projects/lan-reader` is read-only for this work. Required changes there
  are described for the user to implement/deploy separately.

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
| R11 | Support the accepted first-release EPUB scope. Detect known unsupported layout classes and explain them recoverably without changing saved progress or silently dropping content. |

## Acceptance Criteria

- **AC1 (R1):** A fresh installation accepts a reachable compatible server,
  displays its library and opens a book. Relaunch retains the address.
  Connection failure is recoverable; changing servers cannot mix their data
  or pending writes. Root and prefixed deployment URLs are covered.
- **AC2 (R2, R10):** UI01–UI14 have matched iPhone screen/interaction evidence
  and appropriate automated checks, including loading/empty/error states.
  Approved differences are native text reflow, necessary server setup UI and
  platform-owned file/permission/share dialogs.
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
- **AC10 (R11):** Fixed-layout/vertical/RTL fixtures are clearly identified as
  outside the first release; unsupported content never becomes an empty or
  partly discarded successful read and does not overwrite saved position.

## Out of Scope

- Editing/deploying lan-reader, replacing its backend or database, or requiring
  a backend rewrite merely because the client changes.
- First-release fixed-layout, vertical and RTL reading; Android/iPad/desktop
  release acceptance; new reading formats or unrelated product redesign.
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

## Artifacts and Delivery Map

- `design.md`: architecture, source/layout/data contracts and compatibility.
- `implement.md`: S1–S7 ordering, validation and stop/rollback points.
- `backend-handoff.md`: separately implementable backend recommendations.
- `implement.jsonl` / `check.jsonl`: curated real spec/research context.
- First child: `../10-22-ios-free-device-bootstrap` (planning). Later children
  are mapped in `implement.md` and are planned just before their execution.

No product implementation or benchmark has been performed in this planning
phase. Final plan review is the next gate; no task is started by this document.
