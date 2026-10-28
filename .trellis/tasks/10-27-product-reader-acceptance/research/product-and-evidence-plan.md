# Research: product reader integration and S4 evidence

- Query: How should S4c integrate the product reader and close the retained S2 conditions without delaying measurement until all UI is built?
- Scope: internal source and archived evidence; read-only reference checkout.
- Date: 2026-10-27.
- Status: proposed execution design, not implementation or measured acceptance.

## Findings

### Existing boundaries and files

| Source | Observed responsibility / implication |
| --- | --- |
| `lib/app/routes.dart:14`, `:34`, `:63` | Product routes are library/folder/book preparation views, keyed by captured server session. `BookRoute` does not open a reader. Add a typed reader destination and preserve the return context. |
| `lib/features/library/presentation/widgets/book_preparation.dart:24` | Explicit prepare/retry/refresh UI ends at source readiness. It has no reading controls or write side effects. |
| `lib/features/library/data/publications/prepared_book.dart:6` | Preparation owns a shared result and lease; the reader needs an independent cache lease before preparation loses its visible owner. |
| `.trellis/spec/flutter/state-management.md:394` | Route departure releases preparation's file pin, retaining only immutable metadata. Reopening must verify the actual current bytes and identity. |
| `lib/features/reader/engine/motion/reader_turn_controller.dart:31`, `:199`, `:207`, `:234` | Reusable numeric motion, cancellation generations, settings/layout invalidation, suspend/resume and acceptance owner exist. Product state should wrap these seams rather than replace them. |
| `lib/features/reader/engine/surface/prepared_reader_session.dart:104`, `:142`, `:176` | Preparation and warming can race; optional-work suppression is currently a no-op. S4a must supply a real session/resource owner and coalescing. |
| `lib/features/reader/engine/surface/prepared_reader.dart:49`, `:63` | The existing tick/offset observation path can clear dirty state before `needsTick` is consulted. Instrument submissions at the actual mutation/submission boundary. |
| `lib/features/reader/engine/surface/page_surface_pool.dart:53` | Existing picture/image budgets are 16/48 MiB with three presented owners and one reserve. These are retained-owner bounds, not a full peak-RSS guarantee. |
| `lib/features/reader/engine/layout/font_registry.dart:40`, `:44`, `:85` | Engine fonts cannot be unloaded; the only current size bound is 32 MiB per encoded font. Cross-book registration needs process-level admission/accounting, not merely disposal of a Dart registry. |
| `ios/Runner/AppDelegate.swift:45`, `:85`, `:91`, `:227` | Native sample capacity is 16,384; deprecated OSAtomic counters and explicit layer inventory remain. Registration alone must remain inert. |
| `pubspec.yaml:81`; `tool/ci/build_ios_unsigned.sh`; `.github/workflows/ios-unsigned.yml:7` | Shared synthetic EPUB assets currently enter both modes. Existing `app`/`probe` modes share identifier/build-number provenance; only probe has the alternate CAMetal artifact. |

No `lib/features/reader/presentation/` product module exists at this baseline.
Related specs: `routing.md`, `state-management.md` (preparation owner),
`reader-engine.md` (surface/motion and carry-forward), `diagnostics.md`,
`quality-guidelines.md`, `widget-guidelines.md`, and `testing.md` under
`.trellis/spec/flutter/`.

### Product owner and lifecycle proposal

S4a supplies `ReaderPublicationSession` (name proposed): it owns the independent
immutable-file lease, worker reopen/preload coordination, section/source caches,
fonts, prepared surfaces and shutdown/drain ordering. S4b supplies the accepted
source/checkpoint/activity owner. S4c composes those owners in a session-scoped
reader controller and typed route; neither the page widget nor a second UI
controller may independently publish positions.

Use `(ServerSession generation, BookKey, ContentIdentity, reader lifetime,
layout generation)` in asynchronous eligibility. A numeric book ID or server
key alone cannot protect an A -> B -> A switch. Subscribe to content changes
before prepare, compare identity on every open, and preserve S4b's unresolvable
saved state when content changes. Never borrow a route's shared `PreparedBook`
as a reader lifetime owner. Coordinate reopen/preload with the session worker
queue so a library prepare cannot displace the active reader handle unnoticed.

The route stores durable active-reader intent separately from an accepted
checkpoint. Persist intent on explicit open; restore only after server/session
restoration. Explicit reader exit clears intent and returns to the origin
view; deleting the active book clears intent through the later S6 integration
seam. Temporary network/restore failure should remain recoverable and must not
erase accepted location/activity. S4c owns UI02's reader portion; S5 owns the
eventual shell's return/refresh integration. See reference
`D:/Projects/lan-reader/client/src/hooks/useReaderSession.ts:63`, `:111`,
`:134`, `:150`, `:164`, `:179`, and
`client/src/utils/activeReaderStorage.ts:27`.

User decision supplied during planning on 2026-10-27: pending verified offline
local position wins when NAS/web position changed ("prioritize local; allow
overwriting the server"). S4c adds no server-position conflict-choice dialog.
Apply this only to unsent accepted local intent, never an already acknowledged
or stale cached position. Content identity and source proof remain mandatory;
invalid CFI uses the ordinary retry / explicit chapter-start recovery UI.

Lifecycle must disable input/coverage immediately when ineligible, cancel
motion/pinch/pan and pending generation work, then persist already accepted
state without relying on a last callback at process termination. On foreground,
revalidate viewport/resources and re-prove the existing accepted anchor before
input and coverage resume. A real post-return accepted turn is required. Close,
server retirement and replacement await worker/source drain before the last
file lease is released. Keep the user's current transform only when it still
belongs to the same page, content identity and compatible viewport generation.

### UI09-UI14 and UI02 contract inventory

All reference paths in this subsection are under `D:/Projects/lan-reader/`.
Files were read directly; the current reference Git revision was not verified.
The parent records `a4bda23` as its historical fixed-layout baseline. Capture
the effective reference version and reconcile drift before producing goldens.

| Area | Concrete implementation / validation contract |
| --- | --- |
| UI02 / entry | Resume active book once after startup, explicit exit clears intent, correct previous route, unavailable book recovery, session-switch stack reset. Do not couple startup to the later S5 shell. |
| UI09 / chrome, TOC | Reader top/bottom controls, center tap, nested TOC/current chapter/centering, source-derived whole-book progress and native page progress, safe areas, mutually exclusive panels. Reference `client/src/components/reader/ReaderView.tsx:91`, `:125`, `:574`; `TocPanel.tsx:23`. |
| UI10 / appearance | Six font labels and device fallback behavior; four theme palettes; settings sanitization, 500 ms debounce and teardown flush. Reflow typography preserves the accepted anchor; fixed content omits reflow typography and margins. Reference `client/src/hooks/useReaderSettings.ts:19`, `:45`, `:78`, `:313`, `:388`. |
| UI11 / turns | Reuse S2 page-turn rules and FIFO/generation logic. Include fast reverse, rebound, held neighbor, boundaries and reduced motion, with exactly one accepted result. Reference/native constants already live in `lib/features/reader/engine/motion/page_turn_gesture.dart:4`. |
| UI12 / images | Source-aware raster/SVG hit tests after all page transforms; fit, zoom, pan, close/backdrop, cancellation and viewer blocking. Reference `client/src/components/reader/ImageViewer.tsx:36`, `:236`, `:334`, `:412`; `client/src/utils/imageViewerMotion.ts:1`. |
| UI12 / fixed-page extension | Initially fit the complete page/spread without cropping; pinch/pan affects authored coordinates only. Enlarged drags pan and never trigger edge turns; return-to-fit restores ordinary turns. Reachable reset, explicit TOC/page navigation and image-viewer arbitration. Source visibility is handed to S4b only after the view settles. |
| UI13 / recovery | Loading, unavailable/deleted, retry, explicit chapter-start fallback, export. Failed restore leaves prior position intact. Reference `client/src/components/reader/ReaderView.tsx:549`. Unsupported vertical/RTL or other required-feature failures are explanatory outcomes, never partly rendered success. |
| UI14 / lifecycle and accessibility | App theme independent of reader theme; reduced motion; localized labels, safe hit regions, enlarged-text controls and real OS lifecycle. Fixed-page transform and source identity cannot drift during rotation or interruption. |

Source settings values (`client/src/hooks/useReaderSettings.ts:19-44`):
font 18 default, 14..40 step 2; extra horizontal and vertical margins 0 default,
0..48 step 6, atop reference bases 48 and 60; line height 1.6 default,
1.3..2.0 step 0.1; letter spacing 0 default, 0..0.12 em step 0.02.
Fonts are default/PingFang/Microsoft YaHei/sans/serif/Kai; names do not prove
those fonts exist on iPhone. Themes are light/warm/green/dark; port source
tokens rather than approximate Material seed colors. Panels close over 260 ms
(`ReaderView.tsx:39`); image-viewer transitions use 180 ms. Viewer zoom is
1..5 with 2.5 double-tap target and 0.25 pan resistance
(`client/src/utils/imageViewerTransform.ts:3`). These are image-viewer facts;
whole-page zoom shares the selected fit/pinch/pan behavior, but any new shortcuts
must not be assumed required by the accepted extension.

### Seven retained S2 conditions: owners and gates

Authoritative source: archived S2 `feasibility-report.md:240-314`, repeated in
archived S3 `research/s4-handoff.md:304`. S3 closeout on 2026-10-27 is owner-
reported acceptance of preparation only; it supplies no new full-reader RSS,
timing, physical-presentation or lifecycle result.

| Condition | Implementation owner / early gate | S4c final evidence |
| --- | --- | --- |
| 1. Recognized admission / latency | S4a phase A0: add input identity and recognized tap/drag/direct admission before its renderer device gate; distinguish receipt, queue wait, preparation, admission and submission. | Warm admitted input -> first motion submission P95 <=16.7 ms on device before release. Keep this labeled a submission proxy. |
| 2. Dirty drag / stall classification | S4a A0: fix actual dirty submission recording, hold/barrier and frame-demand timeline; add analyzer tests with genuine idle, held and overdue frames. | Retain all >=50 ms candidates, classify deliberate hold/idle versus missed demanded frame, and leave no unexplained >=50 ms application stall. |
| 3. RSS / ring loss | S4a A0 delivered loss accounting; its 16384-event Dart ring still loses events within 100 turns. S4a A3/A4 profiles reflow/cold-start growth and sizes capture (ring size, segmented export or compaction) for long R06 before A5. Reviewed RSS rule is recorded, not retroactive relabeling. | >=100 alternating turns plus repeated reflow/cold navigation, bounded retained ownership/trend, zero native sample loss in long R06; preserve old 5% endpoint/projected-OLS failures as historical failures. |
| 4. Actual OS lifecycle | S4a probe gate demonstrates its session can recover; S4b tests no ineligible activity and durable state; S4c owns actual product lifecycle wiring. | Capture motion and cold-preparation interruption, foreground recovery and a completed proven accepted turn after return; identify any remaining unverified subcase explicitly. |
| 5. Mixed layout | S4a capabilities/geometry and per-section routing; S4b source semantics; S4c explanations/navigation. | All 23 private regression sections including six fixed pages plus generated complex fixtures; vertical/RTL remains deferred. Later expanded fixed-layout scope supersedes S2's older refusal allowance. |
| 6. Existing hardening | S3 bounded inflation/file-backed worker prerequisite complete. S4a owns preload/decode peak, font admission/session policy, HTML template/noscript cases, warm/prepare coalescing and native synchronization review. | S4c owns fixture-free product bundle proof, integrated resource/device regressions and preservation of every subitem; font fallback cannot silently invalidate required fixed fidelity. |
| 7. Product layer | Preserve current `app` build's default FlutterMetalLayer through S4a instrumentation and S4c packaging. | Build/runtime layer inventory and A-path product evidence; CAMetal B evidence stays non-product and never closes physical scan-out/touch-to-photon. |

This ordering is intentionally acyclic: S4a implements measurement prerequisites
and runs its own early probe gate; it does not wait for S4c UI. S4c consumes that
validated instrumentation and closes conditions using the final product path.
S4b's own semantic gate is required before product delivery of progress/activity.

### Proposed S4c execution phases

1. **C0 integration contracts:** consume approved S4a/S4b handoffs; lock UI
   baseline/tokens; identify active-reader/settings storage owner; confirm
   reader lifetime, error and evidence adapters. Verify early S4a device report
   and unclosed conditions before planning final scenarios.
2. **C1 product session:** typed reader route, S3-to-reader lease acquisition,
   loading/retry/cancel and source restore, persisted active intent, reader exit
   and return refresh seam. Test session switch, detached preparation and stale
   completion without NAS writes until S4b's semantic gates pass.
3. **C2 controls and appearance:** chrome, TOC and nested active-entry centering,
   native/page source progress, settings/font/theme tokens, anchor-preserving
   reflow and fixed-style boundaries; panel blocking and reduced motion.
4. **C3 view transforms and lifecycle:** image viewer plus page fit/pinch/pan,
   explicit reset/navigation, transformed source hit tests/coverage observation,
   gesture cancellation, orientation, background/return, inaccessible-resource
   recovery and export. No network/storage/layout/font work per motion tick.
5. **C4 release hardening:** isolate synthetic fixture assets per build mode and
   inspect the packaged app's asset manifest; preserve probe fixtures. Verify
   supported parser cases, process font bound/recovery, memory accounting,
   synchronization decision and warm/prepare deduplication already owned by A.
6. **C5 final device gate / handoff:** paired iPhone UI evidence, cross-client
   source resume, durable delivery and failure cases, full nominal/reduced-
   motion/refresh-limited matrix and same-identity update retention. Publish a
   redacted acceptance matrix; give S5 only verified reader/activity seams.

### Validation and evidence collection

Host checks: targeted reader controller/widget/route/settings/transform tests;
real temp SQLite migration/restart/failure tests from S4b; worker/file lease
tests from S4a; deterministic fake clocks, pointer and lifecycle tests; geometry
and golden conservation for fixed/mixed content; analyzer regression vectors;
fixture/privacy inventory and build-mode checks. After final code changes run
`dart run build_runner build`, `dart format --set-exit-if-changed lib test
tool/reader tool/diag tool/ci`, `flutter analyze`, and `flutter test` (include
any added integration-test format scope). Use Git Bash for shell syntax and
`bash tool/ci/check_ios_build_modes.sh` on Windows. No host test proves iPhone
presentation, platform font availability, OS suspension or peak reader memory.

Early device gate at end S4a: generated complex fixed/spread/mixed fixtures,
reflow and font/image cases through the actual prepared surface/motion path,
all seven conditions inventoried, corrected capture and bounded resource
report. This is feasibility/risk closure, not UI parity or final release.

Final S4c device gate: at least three repetitions per mandatory scenario;
nominal 120 Hz motion has >=99% frames within 8.333 ms UI and raster budgets
separately, P95 admitted warm latency <=16.7 ms, no unexplained >=50 ms stall,
zero skipped/duplicated content/false acceptance, and >=100 alternating turns.
Cover cold/warm/rapid/reverse/hold/chapter boundaries, long paragraphs, single
images, complex SVG/XHTML/spreads, mixed boundaries, zoom/pan, settings and
panels, image viewer, network/delivery load and real background/return.

Record actual build/engine/OS identity, viewport/DPR/orientation/settings,
scenario/cache state, power/refresh declarations, observed vsync distribution,
all overflows/omissions, queue/preparation/settle wait and raw timestamps.
Keep software timing, cadence, correctness and physical presentation verdicts
separate. Device-limited 60 Hz runs remain distinct correctness evidence;
normal screen recordings and `FrameTiming.totalSpan` are not scan-out proof.
Missing mandatory physical evidence keeps the parent full target unverified.

Reuse Windows + existing free hosted macOS + iPhone workflow and fixed app ID;
preserve shared run-number/build identity across app/probe. No local Mac,
paid service, NAS mutation from CI, or Apple secrets in CI. Push/CI/device
operations occur only in their authorized execution stage. Personal book data,
NAS addresses and raw captures remain ignored local evidence; tracked reports
contain anonymous counts and generated-fixture references only.

## Caveats / Not Found

- No new product intent question was found: fixed/mixed support, fit/pinch/pan,
  horizontal LTR boundary and performance target are already decided. Font
  exhaustion recovery and final hard bounds require a concrete technical spike
  and reviewed evidence, not a claim that session disposal unloads fonts.
- No source code, build, test, phone run, push, NAS call or task activation was
  performed for this research. This note does not close any S2 condition.
- Official Flutter API search/open attempts returned no document content in
  this run; no new external API claim is based on those attempts. Existing
  repo contracts and source are the basis for this plan. Recheck pinned SDK
  lifecycle/timing/font APIs before implementing changes to those boundaries.
