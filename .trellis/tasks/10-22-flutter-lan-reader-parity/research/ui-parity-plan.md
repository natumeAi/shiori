# UI and interaction parity plan

Source audit: 2026-10-22. All `client/` and reference-spec anchors below refer
to `D:/Projects/lan-reader`. No screenshot or live-device parity result is
claimed yet.

## Baseline

Use the inspected lan-reader 3.3.0 working files as the initial behavior
reference. Record the deployed NAS version when it is connected; if it differs
materially, reconcile the reference deliberately rather than mixing releases.
Capture reference screenshots on the user's iPhone at recorded logical
viewport, safe areas, orientation, font scale, system appearance and reader
settings. Compare native content regions after accounting for Safari/PWA
chrome. Windows rendering is not the iPhone font baseline.

Native text reflow is accepted. The server connection screen and its accessible
entry point are necessary additions. Do not add another main navigation tab
or redesign the existing home/library/statistics information hierarchy.

## Traceable coverage matrix

| ID | Area and source | Required evidence |
| --- | --- | --- |
| UI01 | Main shell: `client/src/App.tsx`, `hooks/useMainView.ts:12`, `utils/mainViewPreference.ts` | Three entries, directional transitions, latest-target retargeting, blocked navigation while relevant overlays/operations are active, retained per-view scroll/selection state, correct reader return destination. Main-view exit/entry phases currently use 130 ms each. |
| UI02 | Reader session: `hooks/useReaderSession.ts:63`, `utils/activeReaderStorage.ts` | Reopen the active book across an app restart; explicit reader exit clears that resume intent; deleting the active book clears its reader state. |
| UI03 | Home: `components/home/`, `hooks/useReadingDashboard.ts`, reference `home-reading-contract.md` | Continue-reading card and expanded list, goals/dialog validation, seven days, lifetime totals, recommendation and yearly-completed sections; loading/empty/error/refresh states and return-from-reader refresh. |
| UI04 | Library browsing: `components/bookshelf/LibraryHome.tsx`, `utils/libraryView.ts`, reference `library-boundaries.md:46` | Responsive shelf, all-books/folder views, title/folder search (not author search), permitted sorts per mode, progress badges, folder covers/counts, empty/filter/error states. |
| UI05 | Folder/menu/selection: `components/folders/`, `hooks/useShelfItemMenu.ts`, `components/bookshelf/SelectionActionBar.tsx` | Opening/closing origin geometry, rename validation, action sheets, selection entry/exit, batch move/delete, partial failure presentation and menu availability. |
| UI06 | Dragging: `hooks/useLibraryDrag.ts`, `utils/dragMotion.ts`, reference `bookshelf-drag-boundaries.md` | Lift/reorder/group/import, dwell indicators, spring-open folder, move-out, scrolling, cancellation and delete confirmation. Preserve source timing and decision rules, not only the final server mutation. |
| UI07 | Upload/undo: `hooks/useUploadBooks.ts`, `hooks/useShelfUndo.ts`, reference `library-boundaries.md:100` | File picker, serial upload, placeholders, progress/retry/remove, committed-but-unpublished upload, eligible compensating undo only. Do not add undo to permanent deletion or invent a server undo endpoint. |
| UI08 | Statistics: `components/statistics/`, `hooks/useReadingStatistics.ts`, reference statistics contracts | Day/week/month/year/all, sticky dimension/period controls, complete bucket counts, comparison/unavailable states, ranking details, uncapped completed-book details, monthly calendar and period retention. |
| UI09 | Reader chrome: `components/reader/ReaderView.tsx`, `TocPanel.tsx`, `ReaderBottomBar.tsx` | Top/bottom controls, TOC/current chapter/scroll-to-active item, page/whole-book progress, center tap, panel blocking and safe-area behavior. |
| UI10 | Typography/themes: `hooks/useReaderSettings.ts:22`, `styles/reader.css` | Six font labels and actual iPhone fallback behavior, four themes, size/margins/line-height/spacing ranges/defaults, debounced persistence, anchor-preserving reflow. |
| UI11 | Turns: reference reader contracts and `reader/pageTurnEngine.ts` | Left/right tap zones, drag/flick/reverse/rebound, bounded rapid-input queue, chapter boundaries, reduced motion, cancellation and exactly-once accepted position. |
| UI12 | Images: `components/reader/ImageViewer.tsx`, `utils/imageViewerMotion.ts:1` | Image/SVG hit detection, full-screen fit, pinch/pan/dismiss, control blocking; transition currently 180 ms. |
| UI13 | Recovery: `hooks/useFoliateReader.ts`, reference `reader-boundaries.md:98` | Loading, unavailable/deleted book, retry, explicit chapter-start recovery, diagnostic export and saved-position preservation after failed restore. |
| UI14 | Appearance/accessibility/lifecycle | App follows system light/dark independently from reader theme; reduced motion; labeled actions; hit targets; enlarged-text overflow handling; background/resume and interrupted gesture cleanup. |

## Motion constants already verified

`client/src/utils/dragMotion.ts` currently defines:

- reorder displacement: 500 ms;
- drop settle: 260 ms, cubic-bezier(0.22, 1, 0.36, 1);
- landing settle: 320 ms;
- sort dwell: 150 ms; grouping/import intent dwell: 350 ms;
- spring-open dwell: 800 ms; touch activation: 350 ms;
- folder-exit dwell: 250 ms; vertical auto-scroll threshold: 0.12.

These are source defaults to port with their conditions. Do not substitute a
Flutter package's gesture defaults merely because it exposes a reorder API.
Reader motion constants are owned by `research/native-reader-contracts.md`.

## Native presentation rules

- Keep MaterialApp/router/localization infrastructure, but use explicit
  lan-reader tokens and custom composition for visual parity. The scaffold's
  `ColorScheme.fromSeed`/default Material appearance is not the product design.
- Store colors, typography, metrics and motion tokens centrally; derive
  reader typography from validated settings. Theme extensions can carry
  reader/app tokens without embedding literals throughout widgets.
- Preserve state across the three root destinations. A typed stateful shell
  and a dedicated transition host may be used; match the observed behavior,
  not a default page transition.
- Separate API state from pointer/ticker state. Dragging/reader animation must
  not rebuild the app shell or refetch API data per frame.
- Keep semantics and enlarged transparent hit regions where needed without
  changing the visible reference geometry. Native system file pickers,
  permission prompts, and share sheets are platform integrations, not custom
  redraw targets.

## Evidence production

For each row: store reference/native screenshots or interaction recordings,
the setup and data fixture, relevant automated tests, and unresolved diffs.
Golden tests cover deterministic Flutter layout; paired iPhone inspection
covers actual fonts, touch feel and platform behavior. Antialiasing noise is
not proof of a layout defect, but spacing, color, icon, copy, hierarchy and
interaction differences must be resolved or explicitly approved.

Use generated fixtures in source control and CI. Existing novel files are
local acceptance inputs; do not copy/upload them merely to build the app.
