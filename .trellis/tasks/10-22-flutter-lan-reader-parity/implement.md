# Execution plan

Status: ready for final planning review; **do not run `task.py start` in the
planning turn**. The parent owns requirements/integration, not one enormous
implementation dispatch. All later deliverables need their own scoped PRD,
design/implementation plan where complex, context manifests and review gate.

## Ordered task map

| Stage | Deliverable / proposed child | Dependencies | Acceptance ownership |
| --- | --- | --- | --- |
| S1 | **Created:** `../10-22-ios-free-device-bootstrap` — fixed app identity, free GitHub Actions release build, Windows signing/update/refresh, diagnostic entry point and file-based metric export. | Parent plan approval; user-confirmed pushes to the public repository and user-operated Apple sign-in/device actions when needed. | AC9; establishes evidence availability for AC4. |
| S2 | **Created:** `../10-22-native-reader-feasibility` — oracle vectors, Dart source/CFI/canonical model, native layout and page proof, turn controller, reader probe and presentation-evidence spike. | S1 runs on the phone; generated interoperability fixtures available. | AC3, AC5, AC8, AC10 and early AC4. |
| S3 | Runtime server connection, typed API models, file/cache lifecycle and base library loading. | S1; exact API audit. Can be prepared beside S2 but cannot replace its gate. | AC1, client portion of AC7; data foundation for remaining stages. |
| S4 | Complete reader controls/settings/TOC/image viewer, accepted-position persistence and activity outbox. | S2 source/layout gate and S3 server/storage contracts. | AC3–AC6, AC8, UI09–UI14. |
| S5 | Main shell, home and statistics visual/behavioral parity. | S3 DTOs and S4 activity semantics; UI baseline recorded. | AC2/UI01–UI03, UI08, UI14. |
| S6 | Full bookshelf/folder/upload/menu/selection/drag/undo parity. | S3 library data, S5 shell/token foundations; exact mutation semantics. | AC2/UI04–UI07; partial failure and compensating undo checks. |
| S7 | End-to-end iPhone/NAS parity, cross-client resume, stability and performance acceptance; free update/refresh handoff. | S2–S6 gates passed. | All ACs; final parent integration review. |

Only S1 has a task directory now. S2–S7 are planned independently verifiable
children; create them just before their detailed planning/activation. Do not
silently reorder around failed reader or installation feasibility gates.
Later fixed-layout/vertical/RTL work is not part of these first-release stages.

## S1: build and measurement bootstrap

- [ ] Complete the child review gate and activate the child, leaving this
  parent as requirements/integration owner.
- [ ] Replace the `com.example.shiori` placeholder with the fixed identifier
  `io.github.natumeai.shiori` before any device installation.
- [ ] Produce a reviewed GitHub Actions workflow and host-neutral build script
  (pinned runner image/Xcode and Flutter 3.47.7/Dart 3.13.5, run-number
  `CFBundleVersion`, compile-time `BUILD_ID`, unsigned release device
  packaging, `ios/` diff artifact, no secrets), plus Windows
  personal-signing instructions with free-account limit checks. Codemagic is
  the documented fallback only. No paid usage.
- [ ] Add a separate diagnostic entry point with a synthetic moving surface,
  bounded FrameTiming/scheduling capture, vsync-interval distribution,
  declared refresh-limit settings, Documents file export retrieved over USB
  and a bounded clipboard summary.
- [ ] Prove build → local signing → independent phone launch → diagnostic
  export → same-identifier update/refresh with retained local test state.
- [ ] Record available/missing evidence honestly. No EPUB-FPS claim yet.

## S2: reader feasibility before broad UI construction

- [ ] Generate source/CFI/canonical fixtures from the pinned reference
  behavior in shiori-owned tooling; do not modify the reference project.
- [ ] Verify namespace/HTML repair, source offset, CFI grammar/ranges and
  normalization/hash vectors before any writes to real reading history.
- [ ] Prototype native paragraphs/blocks/images, page/source map, settings
  reflow and previous/current/next preparation.
- [ ] Port gesture constants, generation tokens, bounded FIFO and acceptance
  proof; exercise long unspaced paragraphs and chapter boundaries early.
- [ ] Run the release prototype on the iPhone and export the proposed
  performance report. Investigate presentation evidence within available
  tooling. Keep unverified evidence explicit; stop for review if required
  performance/compatibility cannot be demonstrated without changing scope.
- [ ] Document supported ordinary styles/resources and unsupported layout
  detection. Test the four real local samples and generated SVG/Unicode cases.

## S3–S6 implementation checkpoints

- [ ] Before each affected module is written, load its existing Flutter specs
  and the relevant research manifest entries; update scaffold conventions
  where the approved design intentionally changes them.
- [ ] API layer: exact envelopes, nullability, 304/file responses, base-prefix
  URI resolution, error mapping, aborted/stale requests and server isolation.
- [ ] Storage: versioned persistent settings/checkpoints/outbox, atomic file
  publication, validator/digest keys, eviction and content-change invalidation.
- [ ] Reader: accepted-source proof drives saves and coverage; no speculative
  save, no stats from prewarm, no layout/network/storage work per motion tick.
- [ ] Statistics: immutable retries, partial outcomes, signature mismatch,
  local-date/hour/DST and completion behavior agree with reference fixtures.
- [ ] UI: populate UI01–UI14 paired evidence; preserve animation/dwell rules,
  view state, gestures, mutations, upload publication and undo eligibility.
- [ ] Treat any new backend requirement as a separate handoff to the user.
  Native work may use contract fixtures until the user's deployment is ready.

## Validation commands and evidence

Run appropriate targeted tests during a child, followed by the repository's
required gate after its final changes:

```powershell
dart run build_runner build
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

Include `integration_test`/tool directories in formatting and analysis once
they exist. Add behavior/fixture/golden coverage for new substantial modules;
avoid tests that only restate constants. Unit/widget tests use injected mocks
and clocks, never the user's live NAS. Manual live validation uses dedicated
disposable test data, and never exercises deletion against personal books.

The reviewed host-neutral build script, started by the GitHub Actions
workflow (or the Codemagic fallback), runs the iOS release build for the
selected entry point using `--no-codesign`, a run-number build number and a
compile-time `BUILD_ID`, validates the device artifact and packages it for
local signing. `flutter build ipa` with store credentials is not the chosen
free route. Exact SDK/tool availability is tested in S1, not assumed from a
YAML file's existence.

S7 must include: cold/warm launch; endpoint change; network denial/recovery;
web→native→web source-anchor resume; failed restore preservation; duplicated
activity delivery; background time exclusion; upload commit/refresh failure;
stale reorder/partial delete; content replacement; reduced motion; and the
performance scenarios in `research/performance-acceptance.md`.

## Risk, rollback and stop points

- Product files are untouched during this planning turn. No NAS version,
  signing identity, external service account or iPhone run is inferred.
- SDK/toolchain, signing and metrics feasibility are first-stage gates.
  If any fails, retain diagnostics and revise the plan; do not buy service,
  require a Mac, or report the parent complete.
- CFI/normalization correctness gates precede real activity/position writes.
  A wrong first coverage signature can poison future compatibility for that
  section on the existing server.
- Preserve pending events/checkpoints through storage upgrades, server
  switching and rollback. Do not downgrade by deleting the user's state.
- Real sample books remain local acceptance inputs; generated fixtures are
  the repeatable CI corpus. The repository and its CI artifacts are public:
  every push needs the user's confirmation and never carries secrets, NAS
  addresses, real books or raw personal diagnostics.
- The app identifier `io.github.natumeai.shiori` is fixed from S1 onward.
  Changing it orphans settings, checkpoints and pending activity on the
  phone, so any later change needs its own reviewed migration plan.
- Broad UI work follows the reader feasibility result, avoiding a polished
  surrounding app whose core reader cannot meet the goal.

## Pre-activation checklist

- [ ] User has explicitly approved the latest final summary in a subsequent
  message, including the evidence limits and first child scope.
- [ ] Parent and S1 PRD/design/implementation files are complete and read.
- [ ] Parent/S1 `implement.jsonl` and `check.jsonl` each contain real existing
  spec/research entries; seed-only entries are removed.
- [ ] S1 is the implementation target. Do not activate the parent merely
  because it has children; do not activate later children prematurely.
