# S4c: product reader and device acceptance

## Goal

Open a prepared NAS book into a complete native reader with reference
controls, settings, TOC and image viewer, plus approved fixed-page fit/pinch/
pan; prove lifecycle, durable delivery and reader performance on iPhone.
Status: planning, 2026-10-27.

## Background and Dependencies

Parent: `../10-22-flutter-lan-reader-parity`; owns UI02's reader behavior,
UI09-UI14 and reader portions of AC2-AC6/AC8/AC10-AC12. Depends on accepted
S4a geometry/session/renderer and early device evidence, S4b semantic/
persistence gates, and S3 preparation/server contracts. S5 owns later
shell/home/statistics integration; S6 consumes the active-book deletion seam.

Current BookRoute ends at preparation. S2's seven conditions remain open
despite S3 acceptance. Exact UI/settings anchors and evidence ownership are
in `research/product-and-evidence-plan.md`. S4b's user-approved local-priority
policy applies; no server-progress conflict-choice UI is added.

S4a's post-A0 contract (2026-10-27/28,
`../10-27-native-fixed-layout-core/research/a0-measurement-review.md`) also
applies:
- per-channel geometry with SVG text per shaping cluster;
- the D4 pixel edge rule;
- narrow WebKit-defect (D3) and edge-snapping (D6) exceptions;
- WOFF/WOFF2-to-SFNT conversion;
- a HarfBuzz native library if A0b adopts it.

The dependency order on accepted S4a/S4b is unchanged.

## Requirements

| ID | Requirement |
| --- | --- |
| C-R1 | Add typed session-scoped reader routing/controller, acquire an independent publication lease, preserve return context, restore active intent on restart and clear it on explicit exit. Expose deletion/refresh seams for S5/S6. |
| C-R2 | Match chrome, center tap, nested TOC/current item, source/native-page progress, panels, safe areas and localized loading/error/recovery. Failed restore must preserve saved position. |
| C-R3 | Port six font choices, four themes, exact settings ranges/defaults and debounced local persistence. Reflow preserves the source anchor; fixed pages retain authored typography/geometry. App theme stays independent. |
| C-R4 | Deliver source-aware image hits and viewer fit/zoom/pan/dismiss. Fixed pages/spreads start fitted, support bounded whole-page pinch/pan and reset; enlarged drags pan without edge turns. Coordinate panels, explicit navigation and viewer blocking. |
| C-R5 | Reuse motion and proof owners; view changes publish visibility only after settling. Rotation/background/reopen/cancel/retirement cannot transfer transforms across pages or revive stale work. Resume from a revalidated accepted anchor. |
| C-R6 | Persist accepted checkpoints/activity during ordinary reading, not only exit. Integrate offline retry/local priority without network/storage/layout work in animation callbacks. |
| C-R7 | Close all seven S2 conditions on the product path, including fixture-free assets, font/resource bounds, parser/coalescing/synchronization and FlutterMetalLayer inventory. Preserve historical failed/unverified evidence. |
| C-R8 | Produce paired iPhone UI, cross-client and performance evidence for the full corpus through the free Windows/hosted-macOS/iPhone workflow. Software timing and physical presentation retain separate verdicts. |

## Acceptance Criteria

| ID | Requirements | Observable outcome |
| --- | --- | --- |
| C-AC1 | C-R1, C-R2 | Library->prepare->reader->origin and restart-active-book work. Explicit exit clears only intent. Unavailable/unsupported/failed restore retains checkpoint/events; switching servers cannot revive a retired route. |
| C-AC2 | C-R2, C-R3 | UI02/UI09-UI14 paired evidence covers controls, TOC, themes/settings, loading/errors, accessibility and reduced motion; exact settings and device font behavior are recorded, with only approved differences. |
| C-AC3 | C-R4, C-R5 | Fit/pinch/pan/reset, enlarged drag, transformed image taps, navigation and panel/viewer interruption have automated/device evidence. No accidental turn, obsolete transform, speculative save or offscreen credit. |
| C-AC4 | C-R5, C-R6 | Real OS background/return interrupts motion and cold preparation, then completes a proven turn. Rotation/reflow/network loss/restart preserve anchor/events; duplicate delivery and local-priority conflict cases pass. |
| C-AC5 | C-R7 | Packaged product has no synthetic EPUB fixtures; probe still works. Build/runtime layer is FlutterMetalLayer. Every S2 condition/subitem has owner, evidence and explicit pass/fail/unverified disposition. |
| C-AC6 | C-R8 | Three repeats per mandatory nominal-120-Hz scenario: >=99% frames within 8.333 ms UI/raster budgets separately, warm admitted submission P95 <=16.7 ms, no unexplained >=50 ms stall, >=100 alternating turns and bounded resource trend. Required native captures lose zero samples; correctness errors never pass. |
| C-AC7 | C-R4, C-R8 | Generated complex fixed/SVG/spread/zoom/mixed cases, all 23 private regression sections including six fixed pages, and remaining novels pass conservation/device checks under S4a's per-channel geometry and D4 pixel rule. A D3 exception applies on device only after the defect is reproduced on that device's Safari. Tracked evidence remains anonymous. |
| C-AC8 | C-R1, C-R6, C-R8 | Same-identifier update retains settings, intent, checkpoints and pending events. S5 receives verified return/delivery seams and an evidence ledger; S7 retains whole-app acceptance. |

## Out of Scope

Full shell/home/statistics/bookshelf/upload/drag/undo parity is S5/S6;
whole-app acceptance is S7. No paid service, backend rewrite, WebView,
vertical/RTL or scan-out claim based only on software timing is added.

## Technical Gates and Artifact Status

Zoom tuning/font limits are technical choices bounded by accepted behavior
and fidelity; no new gesture shortcuts are assumed. No product decision is
open. All planning artifacts and manifests, S4a/S4b gates and subsequent
review are required before activation.
