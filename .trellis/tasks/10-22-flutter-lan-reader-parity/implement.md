# Execution plan

Status as of 2026-10-27: S1/S2/S3 completed and archived; S3 device acceptance
is owner-confirmed in its closeout report. S4 scope
includes single-image, complex static fixed-layout and mixed publications
with user-approved fit-page display plus whole-page pinch zoom/pan.
**Do not run `task.py start` in the planning turn**.
The parent owns requirements/integration, not one enormous implementation
dispatch. All later deliverables need their own scoped PRD,
design/implementation plan where complex, context manifests and review gate.

## Ordered task map

| Stage | Deliverable / proposed child | Dependencies | Acceptance ownership |
| --- | --- | --- | --- |
| S1 | **Completed/archived:** `../archive/2026-10/10-22-ios-free-device-bootstrap` — fixed app identity, free GitHub Actions release build, Windows signing/update/refresh, diagnostic entry point and file-based metric export. | Parent plan approval; user-confirmed pushes to the public repository and user-operated Apple sign-in/device actions when needed. | AC9; establishes evidence availability for AC4. |
| S2 | **Completed/archived (conditional S4 GO):** `../archive/2026-10/10-22-native-reader-feasibility` — oracle vectors, Dart source/CFI/canonical model, native layout and page proof, turn controller, reader probe and presentation-evidence spike. | S1 runs on the phone; generated interoperability fixtures available. | AC3, AC5, AC8, AC10 and early AC4. |
| S3 | **Completed/archived:** `../archive/2026-10/10-26-runtime-server-library` — runtime server connection, typed read APIs, durable configuration, bounded EPUB/cache/worker lifecycle and minimal read-only library/preparation UI. | S1 build/storage foundation; merged S2 source model and its S3 bounded-import carry-forward; exact API audit. Does not waive S2 conditional performance gates. | AC1, client portion of AC7; data foundation for remaining stages. |
| S4 | Native fixed-layout/mixed-book core, source/position/activity adaptation, then complete reader controls/settings/TOC/image viewer, whole-page zoom/pan and durable delivery. Proposed independently verifiable children S4a-S4c below. | S2 source/motion contracts and retained conditions; S3 server/storage/source-resource handoff. S2's old fixed-layout refusal is not acceptance for the expanded scope. | AC3–AC6, AC8, AC10–AC12, UI09–UI14. |
| S5 | Main shell, home and statistics visual/behavioral parity. | S3 DTOs and S4 activity semantics; UI baseline recorded. | AC2/UI01–UI03, UI08, UI14. |
| S6 | Full bookshelf/folder/upload/menu/selection/drag/undo parity. | S3 library data, S5 shell/token foundations; exact mutation semantics. | AC2/UI04–UI07; partial failure and compensating undo checks. |
| S7 | End-to-end iPhone/NAS parity, cross-client resume, stability and performance acceptance; free update/refresh handoff. | S2–S6 gates passed. | All ACs; final parent integration review. |

S1, S2 and S3 are completed and archived. S3 acceptance and evidence limits
are recorded in its `research/s3-closeout.md`. S4–S7 remain proposed children;
create them just before their detailed planning/activation. Do not
silently reorder around failed reader or installation feasibility gates.
Vertical/RTL reading remains deferred. Simple and complex static fixed layout
are part of the first release by the user's 2026-10-26 scope decision.

## S4 expansion: proposed child boundaries and dependencies

The following are deliverable boundaries, not created or activated tasks.
Create each child when its detailed planning begins, retain the parent scope,
and write these dependencies into that child's PRD and implementation plan.
No child may treat its narrower milestone as completion of all of S4.

| Child | Deliverable and independent gate | Explicit dependencies |
| --- | --- | --- |
| S4a: fixed-layout core | Per-section metadata/capability routing, authored page coordinates, single-image and complex static XHTML/SVG rendering, fixed/reflowable switching and source-page/spread composition. Generated fidelity/conservation corpus, private sample all-page check and preparer/resource evidence. | Merged S2 source/CFI and motion interfaces; S3 bounded worker/source-resource and lease contracts. Planning/fixture design may proceed earlier, but downloaded-book integration requires the S3 handoff. |
| S4b: reader source and activity integration | Fixed-page/spread CFI visibility and web/native round trips, active-side selection, text/clip coverage, pure-image completion semantics, lifecycle/restore and durable checkpoint/outbox behavior across all layout modes. | S4a geometry/source maps and S3 identity/storage contracts. No real progress/activity writes before semantic gates. |
| S4c: product reader and acceptance | Controls/settings/TOC/images, fit-page plus whole-page pinch/pan, persisted sessions and all remaining S2 carry-forward work; paired iPhone UI, mixed/complex fixed-layout performance and full reader acceptance. | S4a and S4b gates, S3 product entry point and review of the child's full plan. S5 statistics consumes its verified activity handoff. |

Required ordering within S4:

- [x] Q-FXL-1 resolved by the user on 2026-10-26: fit-page display plus
  whole-page pinch/pan. Parent design 5.3 and AC12 record gesture arbitration,
  source visibility and interruption/restore requirements for child planning.
- [ ] Establish the fixed-page capability matrix and deterministic fixtures
  from `research/fixed-layout-expansion.md`, including complex positioned
  text, fonts, stacking/clipping/transforms, static SVG and mixed boundaries.
- [ ] Verify the native coordinate renderer and source geometry with pinned
  reference/browser baselines. Existing single-image support is not proof of
  complex-layout fidelity. Document tolerances and remaining technical gaps.
- [ ] Extend source-page/spread ownership, preserving each section and blank
  slot separately; wire into the existing prepared-surface/motion lifecycle.
- [ ] Prove source anchors, actual-visible canonical coverage, image-only
  completion and web/native restoration before enabling delivery.
- [ ] Verify all 23 sections of the private regression sample, including its
  six fixed image pages; store only anonymous counts in tracked evidence.
- [ ] Test fixed-page transitions, complex pages, image-heavy spreads,
  reflowable boundaries, interruptions, resource retention and the selected
  viewing interaction on iPhone under the unchanged performance gate.
- [ ] Test enlarged-state drag versus page-turn arbitration, pinch/pan
  cancellation, reset-to-fit, explicit navigation and image-viewer blocking;
  credit only stable proven visible text and retain page-local transforms.
- [ ] Keep all required fixed-layout features in scope if feasibility fails;
  return the evidence and options for a scope/architecture decision instead
  of automatically shipping the single-image subset.

## S1: historical plan — completed build and measurement bootstrap

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

## S2: historical plan — archived with conditional S4 GO

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
- [ ] Fixed layout: S3 retains classification/source metadata without a blanket
  fixed-layout rejection; S4a-S4c own rendering, source/activity correctness
  and product/device acceptance respectively.
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
performance scenarios in `research/performance-acceptance.md`. Extend those
scenarios to mixed/fixed pages, complex static content and spread boundaries;
S2's original reflowable corpus cannot stand in for AC11.

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

## Next activation boundary (S4)

S3 closed on 2026-10-27 following owner confirmation that device tests all
passed. Read its archived `research/s3-closeout.md` and `research/s4-handoff.md`
when planning S4. Retain all seven S2 conditions: S3 closes its bounded import
and product preparation acceptance, not reader rendering/performance/release.
S4a-S4c still require scoped planning and review before activation.
