# S4a execution log

## Activation: 2026-10-27

- The owner requested implementation of S4 with `gpt-6.1-sol` at `high`
  reasoning effort and checking with `gpt-6-astra` at `high`.
- The previous final S4 planning summary was located in session
  `01a17c40-301b-7462-b8e6-348951d724f6`; this request approves that plan.
  Scope and product decisions have not changed.
- `task.py validate` passed with five implement and four check entries.
  `task.py start` activated this child in the current Codex session.
- Execution order remains A0 through A5, followed by dependency-gated S4b
  and S4c. An implementation agent owns A0 code/test/tool changes; the main
  session coordinates, updates specifications and preserves approval gates.
- Initial dirty state consists entirely of existing parent S4 planning
  changes and the three new child task directories. No product-code changes
  existed at activation. These planning changes are preserved and are not
  automatically included in any future commit.
- No device, build, push or NAS-write success is asserted by activation.

## Phase evidence

A0 implementation and self-validation evidence is recorded in `research/`.
Formal review has not run.

## Owner-directed parallelism and review timing

The owner subsequently requested parallel development and clarified that
formal checking should happen after the entire S4a implementation finishes.
The completed `research/a0-review-checklist.md` is preparation only: no code
review or quality gate ran during its creation. Phase self-tests and measured
dependency gates remain required.

Three gpt-6.1-sol high implementation owners now work independently:

| Owner | A0 write scope |
| --- | --- |
| s4a_implement | Diagnostics, motion/submission, Swift capture, offline analyzer, capability corpus/browser oracle and their tests. |
| s4a_native_spikes | New `tool/reader/fixed_layout_spike*` native experiments, dedicated tests, and `research/a0-native-spikes.md`. Corpus/oracle inputs are read-only. |
| s4a_resource_policy | `scene_resource_budget.dart`, `process_font_budget.dart`, their dedicated tests, and `research/a0-resource-policy.md`. Production integration remains A3 work. |

The main session coordinates interface changes and shared test-tool usage.
The gpt-6-astra high checker waits for the final S4a handoff.

For later phases, first establish A1's minimal shared identity/unit/navigation
contracts after A0 passes. Then overlap remaining A1 work with A2 rendering and
A3 resource/lifetime work under disjoint ownership. Prepare independent A4
test/runbook work early; its final integration gate still requires A1-A3.

## A0 resource-policy handoff

The resource/font policy owner delivered its two standalone modules, two test
files and `research/a0-resource-policy.md`. Its final focused self-validation
passed: 21 tests, no analysis issues, four formatted files unchanged. The report
records fixture-derived logical counters, provisional bounds, native-memory
exclusions and A3 integration seams. No production FontRegistry/preparer/pool
integration occurred in this branch, and neither A0 nor S4a is declared complete
by this partial handoff. Formal full-S4a review remains pending.

## Current stop boundary

The owner subsequently instructed: complete A0, then stop. This supersedes
automatic continuation into A1-A4 for the current run. Finish the existing A0
implementation, self-validation and evidence reports, record every unresolved
feasibility gate truthfully, and stop without starting A1 or the formal checker.
S4a remains in progress; the overall task and device gate are not complete.

## Repair validation scope

The owner instructed that repairs should be verified with the affected tests,
without repeating the full suite. The implementation owner was notified and
the execution instructions now preserve this rule. The already-started full
rerun had finished when this instruction was handled (2319 passed, two existing
optional skips, no failures); no further full run is requested. The preceding
repair had also passed its focused isolation/evidence/loss regression tests.

## Final A0 handoff and stop

All implementation owners have handed off their reports. The consolidated
`research/a0-implementation-report.md` records the delivered diagnostics,
52 browser cases, 18 native raster experiments, standalone resource/font
policies, private-data guard and local evidence. Final affected regression
testing passed 75 tests; codegen, format (556 files unchanged), analysis,
reference integrity and oracle/privacy checks passed. The already-finished
full suite reported 2319 passed and two existing optional skips.

The A0 experiment delivery is complete, but its feasibility gate is not passed:
native `fidelityGate` is false, actual text geometry exceeds the unchanged
0.5px tolerance, strict pixel differences remain, and semantic admission
coverage has identified gaps. The 100-turn synthetic pressure test records
40400 attempted events, 16384 retained and 24016 lost; this validates loss
accounting, not a zero-loss capture. Production resource integration remains
A3 work. Swift/iOS compilation, physical rendering and A5 evidence are absent.

Work has stopped at the requested A0 boundary. A1 did not start and the formal
checker did not run. Keep S4a in progress and preserve the unresolved gates;
do not archive it or infer approval to continue. No commit or push occurred.

## Post-A0 review and plan revision: 2026-10-27/28

The main session reviewed the A0 evidence read-only and recorded the result
in `research/a0-measurement-review.md`. A0 remains not passed. Most text
deltas above 0.5 px compare non-equivalent quantities: ligature component
metrics and WebKit's integer-snapped DOM Range boxes. The remaining work is
a real curved `spacingAndGlyphs` miss, the public-API cluster gap, undefined
pixel/defect rules, corpus semantic gaps, WOFF/WOFF2 conversion, capture
volume and an uncompiled Swift change.

The owner decided D1-D4 on 2026-10-27: HarfBuzz FFI probe (A0b), curved
textPath stays required, narrow WebKit-defect exceptions and the conservative
edge rule. On 2026-10-28 the owner added D5 (S4b B2/B3 and wire-DTO fixtures
may run in parallel with S4a) and D6 (narrow exception for edge characters
that differ only because of reference integer snapping). PRD, design,
rendering plan and this execution plan were revised. The S4b/S4c plans and
the parent plan were synchronized. The 0.5 px value, the 120 Hz target and
required rows are unchanged.

No code, test, oracle or reference changed. No phase started; A0 closure
items, A0b, A1 and A3 each wait for an explicit owner instruction. No commit
or push occurred.

## A0 closure and standing continuation: 2026-10-28

The owner started the A0 closure items. Part 1 (corpus/oracle) ran with
gpt-6.1-sol high via the Codex CLI and was verified by the main session. Both
unsupported cases are now applied constructs, there are 12 case and 3 probe
reference PNGs, and the data includes an unsnapped foreignObject baseline and
fixture-declared cluster maps. New corpus SHA `aa61e477...`, oracle SHA
`4eb18eb6...`. Part 2 (native harness: channel geometry, D4, D3, per-row
verdicts, corrected required flags) was dispatched next. The D3 record is
`research/reference-defect-exceptions.md`.

While part 2 ran, the owner instructed: after A0 closure, start the remaining
S4a phases directly. A0b and A1-A4 therefore proceed without per-phase
approval, in the dependency order of `implement.md`. Plan-defined review
returns, third-party downloads, commits/pushes and A5 device work still stop
for the owner.

A0 closure part 2 delivered and was verified by the main session. Rows
filters/clip-mask/foreign-object pass; svg-text fails at the `fi` cluster end
(per-grapheme slicing versus a rigid WebKit ligature) and stays open for A0b;
the other nine rows await native coverage in A1/A2. A0 is closed, and A1
shared contracts start next under the standing instruction. A0b additionally
awaits the owner's answer on downloading HarfBuzz 14.6.0 win64.

## A1 shared contracts and parallel slice 1: 2026-10-28

A1 shared contracts were delivered (pure `data/layout`, `data/geometry` and
`engine/support/section_capability.dart`, 24 tests). The main session verified
them: rerun 24/24 passed, and the pure data layer has no `dart:ui`/Flutter
imports. `research/a1-contracts.md` assigns a single owner to each shared
seam. The main session additionally granted A2 the A0 spike harness files.

Three gpt-6.1-sol high sessions then started in parallel in this checkout,
each limited to its ownership row:
- A1-rest slice 1: metadata, dimensions, composition, navigator.
- A2 slice 1: XHTML style profile, positioned boxes, paint/stacking,
  geometry export and harness rows cascade/box/paint/stacking.
- A3 slice 1: process fonts, WOFF 1.0 conversion and a WOFF2 assessment,
  warm/prepare coalescing, parser hardening.

Progress goes to `research/a-phase-progress.md`. A0b waits for the owner's
HarfBuzz download answer.

## A0b start: 2026-10-28

The owner approved downloading HarfBuzz 14.6.0 win64. The main session
downloaded `harfbuzz-win64-14.6.0.zip` (6315868 bytes) into ignored
`build/third_party/harfbuzz-14.6.0/download/`. Its SHA-256
`a773b8e9...b0b3` equals the GitHub release digest. The archive (30 entries,
no unsafe paths) was extracted separately. `libharfbuzz-0.dll` SHA-256 is
`54f305d0...63c3`; besides system DLLs it imports `libglib-2.0-0.dll` from the
same archive. The "Old MIT" COPYING for tag 14.6.0 was fetched alongside it.
No binary is tracked.

A0b started with gpt-6.1-sol high, using new `tool/reader/harfbuzz_probe*`
files only. The time box set by the main session under the standing
instruction is this session plus at most one follow-up. A miss returns its
evidence for owner review (D2).

## Slice 1 interruptions: 2026-10-28

- The first A2 session stopped before implementation, correctly under its
  "state differs" rule. The main session's work order had wrongly claimed
  that the oracle held computed styles and text baselines for cascade/box/
  paint/stacking. A2 was redispatched with a correction and temporary
  ownership of the fixed-layout oracle generator and fixtures: it adds
  baselines, computed-style snapshots, PNGs and cluster maps for those 12
  variants first, keeping the existing records byte-identical.
- A1-rest ended mid-turn on a server-side "Selected model is at capacity"
  error after partial edits. After a capacity probe succeeded, the main
  session resumed the same session (`01a1805f-f031-...`) to finish and verify
  its own edits.

## A0b slice 1 result: 2026-10-28

HarfBuzz 14.6.0 FFI confirmed every fixture-declared cluster (`fi` [3,5),
`é` [6,8)). Shaped advances equal Paragraph and WebKit exactly
(40.29296875 / 72.763671875). Each glyph is painted once as outline Paths,
and native objects return to zero. The svg-text row still fails as measured.
The session stopped on fixture-pin drift: A2's concurrent oracle extension
changed the corpus/oracle hashes. No inputs were reconciled.

Main-session analysis of `build/harfbuzz-probe/report.json`:
- In every case the cluster after `fi` starts within 0.03-0.05 px of WebKit.
  The failing `fi` "cluster-end" (0.78-1.78 px; 11.16 px under spacing)
  compares against WebKit's last-component end inside the ligature, and
  WebKit's own per-component rotations differ within one rigid glyph.
  Path-none passes D4 entirely.
- Hypothesis to verify: under `lengthAdjust` spacing WebKit drops the
  optional `fi` ligature, as CSS Text requires for non-zero spacing, while
  HarfBuzz still ligates.

The follow-up (the last session allowed by the time box) starts once A2
publishes final oracle pins. It must report both the current
cluster-end gate and a same-definition alternative (next-cluster start plus
the run advance against `computedTextLength`, with D4 pixels). Main decides
any contract change from that evidence and reports it to the owner.

## Slice 1 results and next dispatch: 2026-10-28

- A1-rest slice 1 delivered after one resume: rendition, dimension resolver,
  composer and navigator, with 105 focused tests (49 new). Composition matches
  the oracle in 48/52 cases. The 3 mixed-navigation differences are the
  intended "never pair reflow with fixed": the oracle ran Foliate's all-fixed
  `getSpreadOf` on reflow sections. `metadata-unsupported` is a typed rejection.
- A3 slice 1 delivered:
  - process-font integration;
  - bounded WOFF 1.0, where the shaped width 72.763671875 equals SFNT and
    differs from the absent-family 180;
  - WOFF2 kept as a typed unsupported format, because `archive` has no Brotli
    and the dependency choice is open;
  - warm/prepare coalescing;
  - template/noscript hardening.
- A2 slice 1 completed the oracle extension (corpus `eb8379f5...`, oracle
  `33708a0f...`) and most of the scene work. It ended on a remote
  `invalid_compaction_state` error after about 376k tokens, before formatting
  and reporting.
- Main-session run of `test/features/reader` and `test/tool/reader`: 1103
  passed, 2 skipped, 4 failed. All four failures are cross-owner interactions:
  - corpus-test PNG coverage, caused by A2's extension;
  - paragraph_factory font alias, caused by A3's process aliases;
  - worker graph audit rejecting A1's `SectionRendition`;
  - HarfBuzz probe DLL dependency loading without PATH (A0b).

Dispatched in parallel:
- A2 remaining work in a fresh session (no oracle regeneration);
- A3 slice 2: both regressions in its area, then reading-unit session/pool for
  reflow units with navigator and constituent accounting; fixed scenes wait
  for A2's API;
- A0b round 2 on final pins: DLL loading, H1 spacing/ligature, H2 upper run,
  and report under gate definitions A and B for a main-session decision.

## A2 slice 1 result and next fixes: 2026-10-28

A2 slice 1 completed in a fresh session with 177 style/fixed/geometry/scene
tests passing and format/analyze clean; hashes were not regenerated. Row
verdicts are fail for cascade, box and paint (largest gated delta 18.59 px)
and pass on geometry for stacking (0.146 px), with stacking-boundary marked
malformed because of a singular transform.

Main-session analysis of `build/fixed-layout-native/scene-report.json`:
- The 18.59 px delta and the 3 px baseline shift sit on U+1F600 in the shared
  fixture text `Ab fi é 😀 Z`. Roboto lacks it, so host WebKit uses Segoe
  UI Emoji (27.46 px advance) while `flutter test` uses another fallback (8.87
  px). This is not a same-font comparison, and D4 support-bound failures come
  from the same glyph. The design now keeps fallback characters in a dedicated
  case, checked as painted and source-mapped on the host, with geometry and
  pixels gated in A5.
- The 1.26 px delta in `nested flow` is at the undeclared `fl` ligature. Cluster
  maps must come from measured ligature evidence.
- In stacking-boundary, a singular-transform element should render as
  invisible with no proof; it should not make the section malformed.

A2 slice 2 begins after A0b round 2 releases the oracle pins: move fallback
characters into a dedicated case, derive cluster maps from measured ligature
evidence, fix the singular-transform capability, and add A3's
requiredFonts/cancellation/descriptor requests.

## A0b round 2, A3 slice 2 and next dispatch: 2026-10-28

- A0b round 2 (final within its time box) made DLL loading self-contained
  (libintl -> GLib -> HarfBuzz by absolute path). It reported each case under
  gate definitions A and B:
  - B geometry maxima are 0.08-0.36 px, all within 0.5 px.
  - Path-none passes everything under B.
  - The other cases fail only D4 topology. In the upper run, WebKit's fi
    paints as one component and native as two. A diagnostic that paints
    components with ligature metrics passes D4 (A 0.118 / B 0.089 px). Under
    spacing, the remaining mismatch is the i-dot/e-acute components.
  - H1: simply disabling `liga` is insufficient.
  The svg-text row fails under both A and B. The time box is exhausted, so per
  D2 the evidence returns to the owner for review; A0b is paused.
- A3 slice 2 fixed both regressions: the font-alias test now proves use
  against the absent-family control, and `SectionRendition` was audited as
  immutable before allowlisting. Reflow sessions/pool now run on
  `ReadingUnit`s via the A1 navigator, with constituent accounting (4 units / 8
  sources, exactly-once release). Fixed preparation stays typed unavailable
  until A2's scene seam exists.
- Main-session run of `test/features/reader` and `test/tool/reader`: 1117
  passed, 2 skipped (existing optional), 0 failed.
- Dispatched in parallel:
  - A2 slice 2a: fallback-character case, measured cluster maps,
    singular-transform capability, oracle regeneration, row re-verdicts.
  - A3 slice 3: reader lease, worker reservation, shutdown order,
    picture/image preallocation, eviction protection.

## A0b time-box extension: 2026-10-28

The owner chose one more A0b round. Gate definition B (cluster starts, run
advance against `computedTextLength`, single-component rotation, D4) is
adopted in `design.md`; component end and multi-component rotation stay
diagnostics. Round 3 targets the remaining D4 topology. Its working
hypothesis is that WebKit computes ligature metrics but paints
positioned/path-text clusters as per-character glyph fragments. It must
derive one general rule from evidence, not per-case adjustments. Round 3 runs
alongside A2 slice 2a, so it pins svg-text/probe records by canonical content
hash instead of the whole-file hash.

## A2 slice 2a result and 2b dispatch: 2026-10-28

A2 slice 2a moved U+1F600 into `text-boundary` (device-gated; painted and
source-mapped on host), measured cluster maps for 67 text nodes and 3 probes
(`fl` [7,9): normal 11.357 / ligatures off 11.797 px), and fixed the
singular-transform capability. The oracle was regenerated byte-identically
twice (corpus `2b4881df...`, WebKit oracle `b6d27584...`), and svg-text/probe
measured values are unchanged. Row verdicts:
- pass: cascade (0 px), box (0.014), paint (0.012), stacking (0.146), and
  filters, clip-mask and foreign-object;
- fail: svg-text (A0b pending).
One failing image-cache test traces to A3's in-progress preallocation change
in `image_cache.dart`, to be checked when A3 slice 3 reports.

A2 slice 2b dispatched: the production fixed-preparation seam for A3
(plan/reserve/prepare/publish/cancel/dispose), required fonts and
cancellation, parsed @font-face descriptors, the oracle extension and native
verdicts for the text, dimensions and metadata rows.

## A0b round 3 result (final): 2026-10-28

The derived rule: keep whole-run HarfBuzz advances, paint ligature components
(`liga=0`) as independently positioned fragments in their half-ligature metric
slots, and keep combining marks with their base. Path traversal follows
WebKit's observed 256-chord quadratic subdivision. Under definition B the
geometry maxima are 0.00012-0.00048 px in all six required cases. D4 passes in
four; nested (8 vs 7 components) and spacingAndGlyphs (7 vs 8) fail only the
component sub-rule. Interior, edge band, support bounds and samples pass, and
svg-text/probe canonical content was unchanged throughout.

Main-session check of the PNGs: each component mismatch comes from faint
antialiasing pixels that join or split adjacent glyph pieces. spacingAndGlyphs
native alpha is 4/23/18 at x=121 where WebKit has 0; nested WebKit alpha is
12/25 at x=67 where native has 0. These are rasterizer differences, not
geometry. The time box is exhausted, so per D2 the row stays required and open.
Returned to the owner: keep D4 as is, or count components only at alpha >= 32
(other D4 sub-rules unchanged; the interior rule still catches missing faint
areas larger than 3x3).

## Decision D7: 2026-10-28

The owner approved computing D4 components on pixels with alpha >= 32. The
other D4 sub-rules keep alpha > 0. Recorded in PRD, design and the parent plan.
The shared D4 helper (`tool/reader/fixed_layout_spike_pixels.dart`) is
A2-owned, and A2 slice 2b is running. The change and a rerun of every row
(A0 spike, scene harness, HarfBuzz probe) are therefore the first item of A2's
next slice, which must confirm that no other row changes verdict.

## A3 slice 3 result: 2026-10-28

A3 slice 3 delivered:
- an independent reader file lease (full identity checked before queued
  reopen/preload; route release keeps the reader pin);
- an explicit worker reservation, with conflicting preparation waiting;
- the designed shutdown order;
- picture reservation before recording, with reconciliation afterwards;
- image peak admission before codec allocation, with old and new counted
  together;
- live-section eviction protection.

345 focused tests passed. Fixed preparation stays typed unavailable until A2's
seam lands. Production wiring (route acquisition, retirement shutdown,
closeAndDrain, shared budgets, cache pins) is integration work for A4.

The main session found that `pagination_test.dart:309` ("image cache stays
within its byte bound and keeps leased images") fails, because it encodes the
old "leased entries may exceed the bound" contract that the design replaces
with pre-decode admission. A3 slice 3b updates that case and proves existing
image fixtures do not hit refusal at 48 MiB (raising the budget is not
allowed). It also confirms a refused lease surfaces as a typed failure that
keeps the accepted page.

## A3 slice 3b result: 2026-10-28

The image-cache test now encodes pre-decode admission: refusal before
allocation, leased retention and unleased eviction. Every-page passes under
all three gate settings at the unchanged 48 MiB budget had zero refusals:
- synthetic: 2 fixtures, 2593 visits, peak 12.4 MB;
- private: 4 books, 60 sections, 3486 visits, peak 33.2 MB (host
  accounting, not RSS; counts only).
A refused lease keeps the accepted page/proof and publishes nothing partial.
542 tests passed with the 2 optional skips.

Open: `pool.prepare` catches `ImageAdmissionException` and returns null, so the
session exposes only a generic unavailable state. End-to-end typed resource
failure goes into A3's next slice, together with fixed-preparation
integration once A2 slice 2b publishes its seam.

## A2 slice 2b result and next dispatch: 2026-10-28

A2 slice 2b published `FixedSectionPreparer`: plan, then caller reservation,
then prepare, then complete-scene publication. Cancellation is separated from
physical drain, owners dispose exactly once, fonts load with
`requiredFonts: true` plus cancellation, and parsed face descriptors are
exposed. The oracle gained text/dimensions evidence (WebKit `4c017aa1...`,
corpus unchanged). Verdicts:
- metadata: pass;
- dimensions: geometry 0 px, positive fails D4 only on the RD-1 (0,0) pixel
  because the RD-1 JSON enumerates only A0 cases. The recorded rule already
  covers XHTML-hosted SVG cases, so it becomes rule-based, still (0,0) only;
- text: fail, 11.82 px, caused by unimplemented `vertical-align` super/sub
  and its line-box growth. That is a required value, so it will be
  implemented.

451 tests passed. Dispatched in parallel:
- A2 slice 2c: the D7 helper change with a before/after rerun of every row,
  RD-1/RD-2 rule-based eligibility, and sub/super implementation;
- A3 slice 4: descriptor-aware face selection, physical font drain,
  fixed/spread/mixed session integration through the seam, and typed
  failures end to end.

## A2 segment plan and parallel start: 2026-10-28

The owner asked which remaining A2 work can run in parallel. A2 is executed in
segments sized to avoid session failure (segment 1 died after about 376k
tokens):
- done: 1 (oracle extension, XHTML rows), 2 (fixture fixes), 3 (preparation
  seam, text/dimensions/metadata);
- running: 4 (D7 rerun, RD rules, sub/super);
- remaining: 5 (SVG graphics), 6 (production filters/masks/foreignObject),
  7 (HarfBuzz text in the app), 8 (mixed navigation and integration fixes).

5 and 7a (the host-side module) were started now as sub-owners "A2-svg" and
"A2-text", each with exclusive new files. A2-svg also holds svg-graphics-only
oracle extension rights. Hooking them into `fixed_scene.dart` waits for
segment 4. 6 depends on 5's SVG scene, and 8 depends on A3 slice 4. 7's iOS
static build (CI source download plus push) needs owner approval; its script
is drafted unwired, with the source SHA pinned at approval time (the GitHub
API was rate-limited).

## A2 segment 4 result and D7 reassessment: 2026-10-28

A2 segment 4 (internally "slice 2c") delivered:
- D7 in the shared helper; RD-1/RD-2 now rule-based; sub/super with CSS
  line-box growth (text delta 11.82 -> 0.165 px).
- Before/after over 12 rows (`build/a2-slice2c/before-after.md`): dimensions
  FAIL -> PASS, no passing row regressed. Text still fails D4, now from
  underline rendering.
- D7 flipped HarfBuzz svg-text cases: positive/boundary/path-none
  PASS -> FAIL and spacingAndGlyphs FAIL -> PASS, all component-only.
- A0b round 3's near-pass used Windows GDI transform-aware grid fitting for
  outlines (documented as host-only; production `lib/` does not use GDI).
- The corpus test fails because A2-svg added svg-graphics PNGs while it is
  still running; resolve when A2-svg reports.

Main-session assessment: glyph-component topology flips with the alpha
threshold and with rasterizer hinting, and iOS (CoreText vs Impeller) differs
again, so it is not a stable host gate for text. Proposed D8 for the owner:
- text glyph pixels are excluded from the D4 component sub-rule;
- glyph presence is gated by cluster conservation (every shaped cluster
  painted exactly once, source mapping exact) plus definition-B geometry at
  0.5 px;
- interior, edge-band, support-bound and sample rules still cover text;
- non-text paint keeps the component rule;
- text raster parity is judged again on the device in A5.

## Decision D8 and A2 segment 4 wrap-up dispatch: 2026-10-28

The owner adopted D8: text glyph pixels are excluded from the component
sub-rule; glyph presence is gated by cluster conservation plus definition-B
geometry; non-text keeps D7; text raster parity is device-gated (A5).
Recorded in PRD, design and the parent plan. The A2 wrap-up was dispatched:
D8 in all harnesses (HarfBuzz verdict on unhinted HarfBuzz outlines, GDI
diagnostic only), underline/decoration from font metrics, and a full
before/after rerun.

## Pause for MCP reload: 2026-10-28

The owner asked to run the A2 segment-4 wrap-up (D8, underline, full rerun)
through dsh `dsh_prompt`, with `deepseek-v4.1-flash` at high reasoning.
- The sol run of the same work order was stopped before it made any edits
  (0 patches).
- dsh offered no `deepseek-v4.1-flash`; the owner chose `deepseek-v4-flash`.
  `dsh_prompt` has no reasoning parameter, so "reasoning effort: high" was
  stated in the prompt text.
- Turn 1 (D8 only) returned "Request timed out" on the MCP side. All dsh
  sessions (bce8953e..., 7c796737..., session-fc8ca065...) were idle
  afterwards.
- Within its scope, `tool/reader/fixed_layout_spike_filters.dart` and
  `_fonts.dart` show newer modification times. Verify them before resuming;
  D8 itself belongs in the pixels helper and harnesses.

The owner then paused to restart Claude and reload the updated MCP servers.
Still running independently of Claude (sol via Codex CLI): A3 slice 4, A2-svg
segment 5, A2-text segment 7a. After restart:
- re-arm watchers for those three;
- inspect the dsh session state and partial edits;
- resume the wrap-up via `dsh_prompt` (one session, three turns).

## dsh dispatch attempt after MCP reload: 2026-10-28

After the reload, `dsh_options` lists DeepSeek-V4.1-Flash as model id
`deepseek-official/deepseek-flash`, with reasoning effort `high` as default.
The A2 wrap-up was split into four short `dsh_prompt` turns. Turn 1 returned
"Request timed out" about one minute after dispatch. The new DSH session
(48a636b8...) was idle afterwards, and no in-scope file changed. The
earlier "newer" spike files actually date from 10-27. The MCP client call
times out after roughly 60 s and the DSH turn does not survive it, so
blocking `dsh_prompt` cannot run multi-minute coding turns in this host. No
DSH CLI is on PATH. Options were put to the owner: an async/progress-capable
dsh MCP or a larger MCP tool timeout, versus running the wrap-up with sol.

The owner chose to wait for a dsh MCP fix (async/progress or a longer
timeout) before running the A2 segment-4 wrap-up through dsh with
`deepseek-official/deepseek-flash` (V4.1 Flash, reasoning high). Until then
the wrap-up is held. The shared D4 helper, the A0 spike, the scene harness
and the HarfBuzz probe stay reserved for it, so no other owner edits them.
A3 slice 4, A2-svg and A2-text continue under sol.

## A2-text segment 7a result: 2026-10-28

The production HarfBuzz module (`lib/features/reader/engine/text/harfbuzz/`,
11 files) supports configurable library/prefix with typed symbol failures,
admitted-font ownership, layout shaping plus `liga=0` paint fragments, fragment
Paths with shaped `ClusterGeometry`, and positioned/textLength/256-chord path
placement. It uses no GDI (main session verified). The main-session rerun
passed 17/17 tests.
- Definition-B maxima are 0.00012-0.00048 px for all six cases.
- D4 still fails only on components in nested, spacing and spacingAndGlyphs.
  This is the pre-D8 rule; D8 in the shared helper is held for the dsh
  wrap-up.
- Reservations precede allocation; teardown and cancellation are proven.

The iOS draft `tool/ci/build_harfbuzz_ios.sh` (unwired, SHA placeholder) and
`research/harfbuzz-ios-packaging.md` need owner approval for the official
source download/SHA and link integration. The plan is to batch that approval
with the hosted-macOS compile of the A0 Swift changes before A5.

Requests: A2-svg consumes the prepared fragments in the SVG scene; A3 supplies
admitted face identity, immutable bytes, prepaid accounting and drain
ownership.

## A3 slice 4 lost session and resume: 2026-10-28

A3 slice 4 ended on `invalid_compaction_state` after about 419k tokens, at
17:06, without a report. The main session verified that the on-disk A3 state is
consistent: 389 surface/motion/layout/worker tests pass. A fresh
remaining-work session (`a3-s4b`) audits the original six items against the
code, completes the gaps (drainFonts, spread/mixed/server-switch/cancel-drain
tests, the typed-failure matrix, 4/8 accounting) and writes the progress
section.

## A2 segment 4 wrap-up via dsh: 2026-10-28

The owner's dsh fix adds `dsh_wait`: `dsh_prompt` returns a job id when a turn
outlasts the client call, and the turn keeps running. The wrap-up was sent as
turn 1 of 3 (D8 in the shared helper and all three harnesses) with model
`deepseek-official/deepseek-flash` (V4.1 Flash, reasoning high, the default):
job `j1`, session `328050c2-e099-48fa-82e9-21e12804b0ab`. Turn 2 fixes the
underline; turn 3 reruns everything and writes the report. The main session
collects results with `dsh_wait` and never re-sends a prompt.

## A3 slice 4 complete and A4 segment 1 start: 2026-10-28

A3 slice 4's remaining-work session audited all six items: done, with no
production corrections. It added spread/mixed/invisible-anchor tests; 391
surface/motion/layout/worker tests pass. Done:
- face selection;
- physical font drain;
- fixed/spread/mixed session integration;
- typed failures (seven kinds);
- server switch, cancel/drain and 4/8 accounting.
A3's remaining scope: WOFF2 (needs an owner dependency decision) and product
wiring requests for A4.

A4 segment 1 started on sol, independent of A2 rendering: zero-loss capture
sizing (Dart recorder/export/analyzer, minimal native change flagged as
CI-compile pending) and the A5 device runbook/evidence schema draft. The dsh
job `j1` (A2 D8) was still running at 9 min with 263 tool calls.

## A2 wrap-up dsh turn 1 result: 2026-10-28

dsh turn 1 (job `j1`, 600 s, 274 tools, DeepSeek-V4.1-Flash high) implemented D8:
- The text mask is the union of native text paint (alpha > 0, dilated 1 px)
  and oracle text geometry (+1 px), applied to both images. Only the
  component topology is suppressed.
- Interior/edge/support/sample still cover text. Provenance and excluded
  counts are in `pixels.textMask`.

Main-session verification of the HarfBuzz path: all six svg-text cases pass
D4, definition B and cluster conservation, with the row device-gated (A5).
Scene rows pass except text, which fails only on the underline region. The A0
spike's Paragraph-slice svg-text stays fail; it is superseded by the D1
HarfBuzz route and kept as evidence. Nine harness/test files changed, 10
focused tests passed.

The DSH shell could not write under the workspace at the confinement layer,
so it ran the SDK commands once with full access. It changed no ACLs; this
was reported to the owner. Turn 2 (decoration rendering) is running as job
`j2`.

## A2 wrap-up dsh turn 2 result: 2026-10-28

dsh turn 2 (job `j2`, 846 s) fixed fixed-layout decorations. Flutter had
decorated each paint paragraph separately. The fixed path now paints one
font-metric line band:
- Roboto `post` underlinePosition -150 and thickness 100 at upem 2048;
- WebKit device-row snapping (top = round(baseline + offset), rows =
  ceil(top + thickness) - floor(top), minimum 1);
- floor(text-box) horizontal edges;
- the indent placeholder excluded, plus space/subscript skip-ink gaps taken
  from paragraph boxes.
Reflow keeps engine decorations by default. Result: text-positive/nested
geometry 0.165 px and all D4 sub-rules pass; the text row is "device-gated
(A5)" with the host gate true. 392 style/layout/pagination/fixed/scene
tests passed. Open: WOFF/WOFF2 fixed fonts fall back to engine decoration
until their metrics are parsed; skip-ink needs A5 confirmation.

Turn 3 (full rerun, before/after table, progress section) is running as job
`j3`.

## Owner instruction: no new sol dispatch: 2026-10-28

The owner instructed: once the two running sol tasks (A2-svg segment 5 and A4
segment 1) finish, assign no new tasks. The running dsh job `j3` (A2
segment-4 wrap-up, turn 3) is current work and completes normally. Whether
later work moves to dsh or pauses entirely is being clarified with the
owner. Until then, nothing new is dispatched after those completions.
The owner clarified: pause entirely. Once A2-svg segment 5, A4 segment 1 and dsh
job `j3` finish, the main session verifies and reports their results and then
dispatches nothing further, whether to sol or dsh, until the owner resumes S4a.

## A2 wrap-up dsh turn 3 result: 2026-10-28

dsh turn 3 (job `j3`, 252 s) re-ran all harnesses and wrote
`build/a2-segment4b/before-after.md` and the "A2 segment 4 wrap-up (dsh)"
progress section. Final verdicts:
- A0 filters/clip-mask/foreign-object pass; A0 svg-text superseded by the D1
  HarfBuzz route (evidence only);
- scene cascade/box/paint/stacking/dimensions/metadata pass, text
  device-gated (A5);
- HarfBuzz svg-text device-gated (A5), with GDI as diagnostic only.
13 cases changed and there are 0 regressions. 388 affected tests passed with 2
skipped. A transient compile failure in A2-svg's in-progress
`svg_graphics_markers.dart` was outside scope and is rechecked when A2-svg
reports.

## A2-svg segment 5 lost session: 2026-10-28

A2-svg segment 5 ended at 18:05 on `invalid_compaction_state` after about
688k tokens, without a report or progress section. It added 13 files under
`engine/fixed/svg/`, a harness and tests. It left a compile break:
`svg_graphics_markers.dart:13-14` references `pp.SvgPathSegType`, which
`package:path_parsing/path_parsing.dart` (1.1.0, a transitive dependency
that is not in pubspec) does not export. `dart analyze lib` reports exactly
these 2 errors plus 1 other issue. Fixed-scene and SVG tests cannot compile
until fixed. Under the owner's pause, no remaining-work session is
dispatched. The owner was asked whether the main session should apply a
minimal compile fix (compare the enum by `.name` without importing the
private type) before pausing. Finishing segment 5 waits for resume.
The owner approved the minimal compile fix. The main session changed
`svg_graphics_markers.dart` to compare `segment.command.name` against
`moveToAbs`/`moveToRel` instead of the unexported enum. `dart analyze lib`
reports no issues, and `test/features/reader/engine/fixed` plus
`test/tool/reader` pass (46 tests). Segment 5's remaining scope (marker
completion, svg-graphics verdict, progress report) waits for the owner to
resume.

## A4 segment 1 result and full pause: 2026-10-28

A4 segment 1 delivered zero-loss capture: 786432 preallocated packed event
rows keep every analyzer field, with no maps, serialization or scheduling in
motion.
- Measured warm/cold/held/reverse load: 310/315/410/310 events per 50-frame
  turn.
- Envelope: 10 min at 120 Hz, 4096 turns. Engine capacity 131072; native
  262144 (Swift capacity/version only, CI-compile pending).
- Three independent 100-turn captures and an R06 stress run lose zero events.
  Capacity-exceeded tests still report loss.
- Host R06 RSS was 233 MB before stop and peaked at 686 MB with
  analysis/export. Device memory is unverified, and the preallocated
  ~74 MiB must be reviewed against A5 RSS evidence on resume.
- `research/a5-device-runbook.md` drafted; 246 diagnostics tests passed.
- Request: synchronize `diagnostics.md` and `reader-admission-diagnostics.md`.

The main session also updated `fixed_layout_corpus_test.dart`'s `paintRows` to
include `svg-graphics`, matching the PNGs A2-svg added (positive/boundary/nested
only), which its lost session never reconciled. Final checkpoint:
- `dart analyze lib test tool` reports no issues;
- reader, tool/reader, diagnostics, tool/diag and library tests: 1966 passed,
  2 optional skips, 0 failed.

S4a is paused by the owner, with no further dispatch to sol or dsh. Remaining
on resume:
- A2-svg segment 5 completion (markers, svg-graphics verdict, report);
- A2 segment 6 (production filters/masks/foreignObject);
- A2 segment 7b (HarfBuzz in the SVG scene, plus the iOS build: owner approval
  for source download/push);
- A2 segment 8 (mixed navigation);
- A4 integration/host gate and probe wiring;
- WOFF2 (owner dependency decision);
- spec synchronization;
- A5 device work.
Nothing is committed.

## Owner resume via dsh: 2026-10-29

The owner resumed S4a: implementation goes to dsh with DeepSeek-V4.1-Flash
(`deepseek-official/deepseek-flash`, `reasoningEffort: high`, now a real
`dsh_prompt` parameter), and checks go to the Codex CLI with gpt-6-astra high.
The standing continuation rule applies again (stop only at A5, plan-defined
review returns, downloads, commits/pushes and scope changes).

Resume audit: worktree clean at `4f52269`. SVG graphics tests pass (14);
geometry passes all variants (max 1.41e-05 px). Positive/boundary fail D4 only
on the RD-1 (0,0) pixel because `fixed_layout_svg_harness.dart` still
intersects the shared rule-based D3 decision with the registry's case lists,
which contradicts the slice-2c rule-based decision. Fixtures were rewritten at
17:57 after the last determinism audit. The A1-rest immutable-value allowlist
request is already resolved (`prepared_publication_graph_test` passes).

Dispatched in parallel, disjoint files:
- A2-svg segment 5 completion: rule-based D3 in the SVG harness, marker
  verification, oracle double-run/HEAD determinism, verdict and progress
  section. dsh job `j1`, session `0c87fe41-9e74-4605-bf47-8794d7c9e234`.
- A2 segment 8 (owner "A2-mixed"): first mixed-navigation row verdict through a
  dedicated harness over the real rendition/composer/navigator, with reflow
  sides recorded as a requirement-traced difference. dsh job `j2`, session
  `87db00e2-93ca-4467-9743-23bbe267caae`.
Main session: diagnostics spec synchronization requested by A4 segment 1.

## Segment 5 completion and segment 8 results: 2026-10-29

dsh `j1` (530 s, 252 tools) closed A2-svg segment 5: the SVG harness now uses
the shared rule-based D3 decision; a multi-subpath/closepath/arc marker test was
added with no production marker change; two corpus and two oracle generations
are byte-identical to each other and to HEAD. Verdicts: positive PASS, nested
PASS, unsupported typed PASS, boundary FAIL only on the exact-sample sub-rule at
(10,10), native red 204 vs reference 205. 83 affected tests passed.

Main-session diagnosis of the boundary sample: over the first gradient rect
(7..43 px) native differs from WebKit by +/-1 in a single channel on 665 of
1369 pixels, in both directions, while WebKit matches round(255 x (1 - t))
exactly. This is Flutter's always-on gradient dithering; the Dart UI API has
no dithering control (`enableDithering` is gone). Exact gradient sample values
are therefore unreachable through `ui.Gradient`. Proposed owner decision D9 is
pending (not applied): sample points on gradient-painted pixels allow at most
1/255 per channel; all other D4 sub-rules and solid-colour samples stay exact;
gradient raster parity is re-checked on the device in A5.

dsh `j2` (658 s, 260 tools) delivered A2 segment 8: `fixed_layout_mixed_harness`
and its test over the real rendition/composer/navigator. Row mixed-navigation
PASS: positive/boundary/nested pass checks a-e; unsupported yields typed
`rtlProgression` + `rtlDirection` with zero units. Reflowable sources 0 and 5
are recorded as a requirement-traced difference from the all-fixed reference.
No production bug was found; 144 tests passed. Request: the session must
consume the RTL direction issues before composing/publishing (not proven by
this harness).

Both DSH sessions report that the DSH workspace-write sandbox runs with a
low-integrity token that refuses workspace writes, so write-bearing commands
ran through DSH's one-shot full-access path; no ACL was changed.

Review: Codex CLI gpt-6-astra high, session `01a1852e-d1e5-72c3-8a47-d5c776ec9389`,
covers the whole segment 5 production code (never reviewed) and segment 8.

## Decision D9: 2026-10-29

The owner adopted D9: a D4 sample point on gradient-painted pixels may differ
by at most 1/255 per channel. Gradient-painted means the native topmost paint
and the reference's computed paint of the same source element both use a
gradient paint server; classification never comes from pixel values. Solid
samples and the other D4 sub-rules stay exact; gradient raster parity is
re-checked on the device in A5. Recorded in PRD, design and the parent plan.
Implementation (shared D4 helper per-sample API plus SVG harness wiring) is
queued for the A2 DSH session after segment 5i, because 5i owns the SVG harness.

## Astra review of segments 5 and 8: 2026-10-29

Codex gpt-6-astra high (session `01a1852e...`): 249 tests passed, analysis
clean, corpus/oracle checks pass. Part 1 (SVG) and Part 2 (mixed) are both
"accept after fixes". It confirmed the dithering cause (installed Flutter
`dl_sk_conversions.cc:54` always enables gradient dithering). Findings:
- blocker: `fixed_layout_spike_pixels.dart:173` skips every pixel whose
  maximum channel delta is <= 2 before the interior/edge rules. D4's text says
  "zero interior mismatches" and never defined a changed pixel; this threshold
  dates from A0 and every row verdict so far used it.
- major (SVG module): CSS rendering declarations such as `transform` in
  `style` are dropped while the capability stays complete
  (`svg_presentation.dart:37`); detached gradient resources lose inherited
  presentation such as `currentColor` (`svg_graphics_values.dart:143`); empty
  fill bounds suppress userSpaceOnUse pattern strokes
  (`svg_graphics_patterns.dart:165`); zero-length dashes lose round/square caps
  (`svg_graphics_dash.dart:60`).
- major (harnesses): the SVG harness does not require complete fragment
  coverage, per-use instance mapping or paint order (`:284`); the mixed
  harness's RTL "zero published units" is a literal 0 (`:202`) and traversal
  never checks the active source (`:684`).

Main-session measurement of the blocker (all scene, A0 and SVG native PNGs
against the oracle, (0,0) excluded): pixels with delta 1 or 2 matter in only
two places. stacking-boundary has 100 pixels of its `opacity:.7` square at
alpha 178 natively vs 179 in WebKit (0.7 x 255 = 178.5), 64 of them interior;
svg-graphics positive/boundary have 2979/4186 gradient-dither pixels outside
the edge band. No case anywhere has a delta-2 pixel. The threshold choice is
put to the owner (proposed D10).

Dispatched: mixed fixes as dsh `j4` (session `87db00e2...`); SVG semantics
fixes as dsh `j5`, new owner "A2-svg-fix" (session
`0cf39402-6f47-4bb4-8c75-6d9595359a75`), limited to the four part files and a
new test file. The SVG harness finding joins the queued D9 turn for the A2
session, which owns that harness.

## Decision D10: 2026-10-29

The owner adopted D10: outside samples, a D4 pixel is changed when its maximum
channel delta is at least 2; an exact 1/255 difference is not a change. This
replaces the undocumented "greater than 2" threshold the reviewer flagged as a
blocker, and is stricter. Recorded in PRD, design and the parent plan. It is
added to the queued D9 turn (same shared helper), with a full before/after run.

## Segment 5i, review fixes and next dispatch: 2026-10-29

- dsh `j3` (1253 s, 372 tools) delivered segment 5i: inline SVG in XHTML now
  prepares through `FixedSectionPreparer`; the rect-only route is gone. SVG
  base charges are inside `FixedPreparationPlan.resources` and the whole-unit
  reservation (`prepare(preReserved: true)`), with tests for no double charge
  and dispose-once. The SVG harness also runs every svg-graphics case through
  the preparer with identical verdicts. Scene rows unchanged. Request: the
  product fixed source loader must put local SVG `<image>` targets into
  `FixedSourceLease.images`; no production loader exists yet (only the
  injected `FixedSourceLoader`), so this joins A4 product wiring. Open: SVG
  scene picture bytes are charged as `vectorBytes`, not reconciled through
  `FixedSceneAdmission.pictureBytes`.
- dsh `j5` (616 s): all four SVG semantics findings confirmed and fixed (CSS
  `transform` applied and other rendering declarations typed unsupported;
  inherited `currentColor`/stop values; userSpaceOnUse pattern strokes on
  zero-height geometry; zero-length dash caps); 6 new tests.
- dsh `j4` (298 s): mixed check c now asserts the active source per step
  (reference `fixed-layout.js:166-180, 246-250, 265-269, 300-307`) and passes;
  check e now drives the real path and FAILS: the composer/navigator compose
  5 RTL units because no typed direction admission exists. Negative tests added.
- Main-session merged run after all three: 329 passed, 2 optional skips;
  `dart analyze` of engine/tool/tests clean.

Dispatched:
- `j6`, new owner "A2-gates" (session `227552ad-fd17-4be2-8fc7-384b6b1fec02`):
  D9 per-sample classification, D10 threshold, SVG harness fragment/instance/
  paint-order strengthening, before/after across all harnesses.
- `j7` (A2-mixed, session `87db00e2...`): typed RTL/vertical admission in the
  composer/navigator, session propagation proof or request.
- `j8` (A2-svg-hooks, session `0cf39402...`): feature seams so filters,
  clip/mask, foreignObject and SVG text can be built in parallel part files,
  plus a host interface for foreignObject layout and admitted text fonts; no
  verdict change. The SVG harness row registry follows after `j6`.

## A4 segment 2 start and WOFF2 status: 2026-10-29

The owner asked which A1/A3/A4 work can start now.
- A1: only `j7` (RTL admission) remains.
- A3: SVG picture-bytes reconciliation waits for `j8` (same files); session
  consumption of the typed RTL outcome waits for `j7`; WOFF2 needs an owner
  decision.
- A4: product wiring is unblocked. Dispatched dsh `j9`, new owner "A4"
  (session `99c9edc7-172f-45ef-8a42-863021a244c1`): production fixed source
  loader/`FixedUnitSources` from `PreparedBook` (S3 handoff), images map for
  CSS background and SVG `<image>`, probe wiring for fixed/mixed books, and
  an anonymous all-section private regression.
WOFF2 evidence: the four private books in `D:/Projects/lan-reader/docs` embed
no fonts at all and none is pre-paginated (counts only). WOFF2 stays a required
A3 capability in the plan; route options are put to the owner.

## WOFF2 route decision and dispatch: 2026-10-29

The owner chose the pure-Dart WOFF2 route, approving the one download it
needs. The main session fetched the Brotli static dictionary from
google/brotli tag v1.1.0 (commit `ed738e842d2fbdf2d6459e39267a633c4a9b2f5d`)
into an empty scratch folder: 122784 bytes, SHA-256
`20e42eb1b511c21806d4d227d07e5dd06877d8ce7b3a817f378f313653f35c70`, plus the MIT
LICENSE. The same bytes appear verbatim at offset 12096 in the locally
installed Brotli 1.2.0 `libbrotlicommon.dll` (Git for Windows), an independent
cross-check. Vendored as `third_party/brotli/{dictionary.bin,LICENSE,README.md}`.
The dictionary has no NUL bytes and 431 LF bytes, so `.gitattributes` now marks
`third_party/**` binary to keep autocrlf from rewriting it. Recorded in the
design Fonts row; the MIT notice joins the S4c licence-registry handoff.
Dispatched dsh `j10`, new owner "A3-woff2" (session
`8a146c77-1376-42bb-b6c8-50ec2bbc07a2`): pure-Dart Brotli + WOFF2 conversion,
checked dictionary generator, brotli.exe-generated test vectors, shaping proof.

## D9/D10, RTL and hooks results; segments 6a/6b and review round 2: 2026-10-29

- dsh `j6` (A2-gates, 756 s): helper takes per-sample records
  (`SpikeSampleRecord`, `classifySpikeSamplePaint`), constants
  `d9GradientSampleMaximumDelta = 1`, `d10ChangedPixelMinimumDelta = 2` in every
  report root, per-case `deltaOnePixels`. D9 classification walks native paint
  by descending ordinal through inverse transform/clip/fill path/stroke width
  and requires a reference gradient `url` on the same node. SVG harness now
  requires element/fragment bijection, use-instance chains once and paint
  order, with negative tests. Only change: svg-graphics-boundary F -> P, so
  the svg-graphics row passes. Correction to the main-session D10 estimate:
  delta-2 pixels do exist, all inside the edge band (box/paint/stacking/
  clip-mask/svg-text/HarfBuzz cases, up to 29); changed counts rise, no verdict
  flips. 126 tests passed.
- dsh `j7` (A2-mixed, 279 s): `ReadingUnitSection.directionIssues`;
  `ReadingUnitComposer.plan` throws `UnsupportedDirectionCompositionException`
  (rtlProgression, rtlDirection, verticalWritingMode) before any unit; no
  navigator is built; pool owners stay 0. Mixed check e passes from the real
  refusal; row PASS. Request (A4/main): production `ReadingUnitSection`
  construction must fill `directionIssues` from `SectionLayoutFacts` and map
  the exception to the typed preparation failure before opening a session.
- dsh `j8` (A2-svg-hooks, 803 s): `SvgFeature` contract and registry
  (`svg_feature_hooks.dart`), four refusing part files, `SvgFeatureHost` with
  unavailable foreignObject layout and text font services threaded through
  `FixedSectionPreparer.svgFeatureHost`; contract doc
  `research/a2-svg-feature-hooks.md`; 6 fake-feature tests. Open: mask evidence
  needs a geometry type (`SourceFragment.maskIds` is incomplete-only).
- Main-session merged run: 347 passed, 2 optional skips; analysis clean except
  one lint in A4's in-progress test.

Dispatched: `j11` segment 6a filters (owner "A2-filters", session
`dd5574a2-4647-4074-8b2e-d83206fff725`); `j12` segment 6b clip/mask with a mask
evidence type in `data/geometry` (owner "A2-clipmask", session
`83726722-a40a-4379-b08d-a85e6b80c810`). Segments 6c (foreignObject host
layout in the fixed scene) and 7b (SVG text with the host font service in the
preparer) wait for review round 2, because they edit the 5i files under
review. Review round 2: Codex gpt-6-astra high, session
`01a1855d-47cc-7bd1-86d0-4596ca221887`, verifies the eight round-1 findings
and reviews 5i, hooks, D9/D10 and RTL admission.

## Review round 2 result and fixes: 2026-10-29

Codex gpt-6-astra high (session `01a1855d...`). Its own test run was blocked by
a transient `flutter_tester` holding `build/native_assets/windows/sqlite3.dll`
(a concurrent DSH run); the main session reran the same set afterwards: 164
passed, 1 failed (`svg_feature_hooks_test` refusal-identifier test, expected
because filters is being implemented). Analysis clean.

Round-1 status: fixed 4 (pattern strokes), 7 (mixed check e), 8 (active
source); partially fixed 1 (D10 not applied to support/components), 2 (other
rendering CSS still dropped), 3 (integration overrides inherited color), 5
(initial zero-length dash), 6 (paint order across instance chains).
New findings: blocker D9 classification counts paint that does not paint
(hidden/transparent gradient); major: D10 support/component consistency;
global paint-order check; `preReserved` ledger lets sub-leases exceed the
prepaid total; SVG geometry gets `box.transform` twice; every SVG clip attached
to every fragment; XHTML ordinals after SVG can repeat; XHTML `color`
projection overrides SVG attributes; hook geometry complete by default and
`paintDefault` unchecked; features inside markers/patterns skip the lifecycle;
a throwing disposal skips remaining releases. Verdicts: RTL accept; round-1
fixes, 5i, hooks and D9/D10 accept after fixes.

Dispatched by file ownership: `j13` "A2-scene-fix" (new session
`d0f4572e-0830-4e34-924d-9925974d3e10`, fixed scene files); `j14` A2-svg-hooks
(module/contract, source-compatible completion rule for feature owners); `j15`
A2-gates (D9 effective-paint classification in a shared
`fixed_layout_svg_samples.dart`, D10 support/component rule, global paint
order). 6c/7b still wait for `j13`/`j14` because they build on those files.

## A4 segment 2 result and WOFF2 unblock: 2026-10-29

- dsh `j9` (A4, 1746 s): `engine/surface/publication_fixed_sources.dart` and
  `publication_fixed_composition.dart` build `FixedUnitSources` from a
  `PreparedBook` (one `ReaderPublicationLifetime`, worker `preloadSection`, the
  existing `CssStyleResolver`, images map for CSS background and SVG `<image>`
  via `fixedImageRequest`); the probe opens fixed/mixed publications through
  `PreparedReaderSession.openUnit`. 11 new tests; surface/diagnostics/library
  726 passed. Private regression: 4 books, 60 sections, 1537 reflow units,
  0 fixed units, 0 typed failures. The planned private mixed book with fixed
  image pages is not in the default folder. Requests: mixed session opened on a
  reflow page is rejected by `PreparedReaderSession.open` when the lifetime
  layout is a fixed identity (A3 seam); CSS background URLs are matched by raw
  value (needs a resolved base in `AuthoredStyle`); the probe screen has no
  `PreparedBook` source yet (product route). The RTL `directionIssues`
  population request from `j7` is still open.
- dsh `j10` (A3-woff2, 1661 s): blocked with no code changes. It verified the
  dictionary and the fixture's Brotli header but lacked the RFC 7932
  block-count code. Main session supplied that table and the WOFF2 triplet/
  255UInt16/UIntBase128 rules as claims to verify byte-exact against
  `brotli.exe`. It found that the Roboto fixture uses null glyf/loca
  transforms; the main session located eight real transformed-glyf WOFF2 files
  in the Flutter SDK DevTools bundle, to be read in place by tests (not
  copied). Resumed as `j16`.
- A4 follow-up dispatched as `j17` (session `99c9edc7...`): RTL
  `directionIssues` population and typed mapping, mixed-aware session layout
  check (A3 seam), resolved CSS background URLs, probe route to `PreparedBook`.
- The private 23-section regression sample (six SVG-wrapped JPEG fixed pages,
  parent `research/fixed-layout-expansion.md`) is not in
  `D:/Projects/lan-reader/docs` or `local-evidence` (6 EPUBs scanned, none with
  fixed itemrefs); its location is asked of the owner.

## Owner routing change: 2026-10-29

The owner instructed: once the current batch of dsh tasks finishes, new
implementation goes to the Codex CLI with gpt-6.1-sol at medium reasoning.
Continuations of dsh jobs already in the batch stay on their dsh sessions;
newly dispatched work (segments 6c and 7b onward, and later repair rounds)
goes to sol medium. Reviews stay on gpt-6-astra high.
The private-sample path the owner supplied is a folder named `.epub` that holds
three PNG images and no EPUB structure (no mimetype, container or OPF), so it
is not the 23-section sample; asked again. No name or path is recorded here.
- The owner then supplied the private regression sample (an EPUB outside the
  repository; no name, path or digest is recorded). Counts: ZIP CRC valid,
  23 spine itemrefs, 6 fixed (pre-paginated) itemrefs, package layout not
  fixed, 8 images, 0 embedded fonts. It is the only EPUB in its folder, so the
  private regression runs with `SHIORI_LOCAL_EPUB_DIR` pointing there. The run
  waits for `j17`, which is editing the loader and the regression test.

## Batch results and first sol-medium dispatch: 2026-10-29

- dsh `j13` (A2-scene-fix): all five scene findings fixed (single placement,
  per-item clip chains, ordinal advance past SVG, SVG attribute inheritance
  kept, aggregated disposal). Request: scene harness must key the background
  image by the resolver's resolved path now that A4 resolves CSS URLs.
- dsh `j14` (A2-svg-hooks): six module/contract findings fixed; contract now
  requires `markCovered`/`markIncomplete` per owned node and exactly one
  `paintDefault`; feature content inside pattern/marker refuses. Requests:
  filters need a once-only source capture; clip/mask must call completion;
  fixed plan `sourceNodes` undercounts the SVG plan's reference charge.
- dsh `j15` (A2-gates): D9 classifies from effective paint only (shared
  `fixed_layout_svg_samples.dart`); D10 support/topology use the union of both
  images where delta < 2; global paint-order sequence. No verdict changes.
- dsh `j11` (A2-filters): bounded filter graph implemented; all four cases
  passed before the contract change, then refused (`svg-layerPixels`, and the
  paint-default rule) after it.
- dsh `j12` (A2-clipmask): turn timed out at 1800 s during final verification;
  `GeometryMask` evidence, feature, harness and tests are on disk; cases now
  fail as incomplete geometry (completion API not called).
- dsh `j16` (A3-woff2): still blocked; block-count ranges verified against the
  local DLL, but the prefix-code reading rules (RFC 7932 sections 3.4-3.5)
  remain unavailable offline. Asked the owner about the specification text.
- Main-session state: `dart analyze lib tool test` clean except one A4 lint;
  fixed/tool tests 88 passed, 8 failed (filters and clip/mask only).

Under the new routing, Codex gpt-6.1-sol medium sessions (scratchpad
`run-sol.sh`) were started for new work:
`sol-filters` (session `01a18583-cffd-7f61-8ccd-915ac598f593`: capture hook,
layer reservation, filters row), `sol-clipmask`
(`01a18583-e31e-7bd0-8921-6c2cc6e580be`: finish 6b), `sol-fo`
(`01a18583-f661-7c93-a63f-f836eb5dfab2`: segment 6c plus the two scene
requests), `sol-text` (segment 7b with the host font service).
dsh `j17` (A4 follow-ups) is the last running job of the dsh batch.

## dsh batch close, specs and private sample: 2026-10-29

- dsh `j17` (A4 2b, 1154 s): direction issues filled and mapped to a typed
  `FixedPreparationFailure`; mixed-aware layout check in
  `prepared_reader_session.dart`; CSS background URLs resolved against the
  declaring stylesheet/document (`css_stylesheet.dart`, resolver passes the
  section path); probe route prepares a `PreparedBook` through
  `PrepareBookService` and calls `openPublication`. 999 tests passed. Open:
  fixed-session settings reflow and section jump are still no-ops; the probe
  inventory has no server-backed entries yet.
- The owner approved downloading the two specification documents (reference
  only, kept outside the repository): RFC 7932 text (389979 bytes, SHA-256
  `394abd1879e016f4eac89512c2acaf92f7b2d67feb8ab58b6b118c213be07146`) and the
  W3C WOFF File Format 2.0 Recommendation HTML (125108 bytes, SHA-256
  `65dfdde1efb57bf123526b9c15a4025ecc78158426a28fefdb396ecf4fc26dc8`). WOFF2
  resumed on its dsh session as `j18` (continuation of the batch).
- `sol-text` stopped at once because Trellis's per-session current-task
  pointer is empty for Codex sessions (degraded mode); the shared constraints
  now say this is expected, and `sol-text` was relaunched.
- Private regression with the owner's sample (`SHIORI_LOCAL_EPUB_DIR`): 5
  books, 83 sections, 1537 reflow units, 0 fixed units, one
  `composition:invalid-input` (the sample); the test only reports counts, so
  A-AC8 is not met. Structure (no text): six fixed itemrefs with
  `rendition:layout-pre-paginated rendition:spread-none
  rendition:page-spread-center`, four also with undeclared `access:*`
  properties; each fixed page is a viewport XHTML with a `width/height="100%"`
  SVG wrapper and one `xlink:href` image. Dispatched `sol-sample` (owner
  "A1-sample", sol medium) to fix composition, report the next blocker (inline
  SVG percentage sizing belongs to the fixed-scene owner) and make the private
  regression a conservation gate.
- `sol-fo` also stopped on the empty current-task pointer before any edit
  (147k tokens of reading). Resumed in place with `codex exec resume`
  (scratchpad `run-sol-resume.sh`, same session `01a18583-f661...`, sol medium)
  and a note that the empty pointer is expected. `sol-filters` and
  `sol-clipmask` are already patching and were not affected.
- `sol-text` (relaunched, session `01a18585-d14f-7c01-b947-6955338d4303`) stopped
  at an ownership boundary with no code change: the text part cannot import
  HarfBuzz (imports live in `svg_graphics.dart`), and the host font service
  needs A3's canonical face descriptor. Resumed in place with two narrow
  grants: import lines only in `svg_graphics.dart`, and one additive public
  accessor in `font_registry.dart`/`process_font_budget.dart` (no routing
  lines, which `j18` is editing). Bytes come from the section's admitted
  resource source and `HarfBuzzAdmittedFont.load` coalesces with the existing
  process admission; WOFF2 faces may refuse until `j18` lands.
- `sol-filters` (A2-filters-2, 115k tokens): `captureDefault()` records the
  default paint once into a scene-owned picture; duplicate prepare-time layer
  reservations removed (admission already includes them), undersized
  pre-reserved ledgers refuse before allocation. Filters row: positive,
  boundary, nested PASS (geometry 0, all D4 sub-rules, samples 0, RD-1 only at
  (0,0) where eligible), unsupported typed. Its final directory run was blocked
  by other owners' mid-edit compile errors (clip/mask, foreignObject); recheck in
  the merged run.
- `sol-clipmask` (A2-clipmask-2, 129k tokens): fixed the missing completion
  calls, absent-mask evidence check, sibling clip union, percentage units,
  transforms, rotated mask regions, mask/luminance reservations and a stale
  per-case D3 scope. Clip/mask row: positive, boundary, nested PASS (geometry 0,
  complete evidence, all D4, samples 4/4 exact, RD-1 at (0,0) where eligible),
  unsupported typed `svg-clip-path`. 13 unit and 228 geometry/CFI/canonical
  tests pass; final directory runs were blocked by foreignObject/text owners'
  mid-edit types. Requests for the shared hook owner: CSS `clip-path`/`mask`
  projection in production, instance-specific evidence annotation, review of
  luminance layer-depth accounting.
- `sol-sample` (A1-sample, 188k tokens): root cause was page-dimension
  precedence: the inline SVG's percentage size invalidated the explicit XHTML
  viewport; rendition parsing produced no issue (unknown property names stay
  ignored, unknown values of known properties stay typed unsupported). Fixed
  with synthetic 17-reflow/6-fixed EPUB tests and a private conservation gate
  over the real worker import. Private run: 1952 reflow units, 6 fixed units,
  0 composition failures; all 6 fixed preparations now refuse with
  `UnsupportedSectionCapability` / `authored-viewport` (inline SVG percentage
  sizing in the fixed scene). A-AC8 stays open; the request (resolve inline SVG
  percentages against the XHTML containing block in planning and scene layout)
  goes to the fixed-scene owner after `sol-fo` returns.
- dsh `j18` (A3-woff2, 838 s): added the checked dictionary generator
  (`tool/fonts/brotli_dictionary.dart`), generated
  `brotli_dictionary_data.dart` (hash verified) and `brotli_decoder.dart`
  covering RFC 7932 sections 3-9; byte-exact vs `brotli.exe -d` for q0/q11,
  English q11, uncompressed and metadata vectors, but q5/q9 and the real Roboto
  payload fail in complex prefix codes (code-length-code sum > 32). No WOFF2
  code yet; debug prints remain. Main session pointed it to RFC 7932 section
  3.5 lines 882-885 and 905-915: both code-length sequences end early once the
  Kraft space is filled (trailing zeros omitted). Resumed as `j19`.
- `sol-fo` resumed (312k tokens) delivered segment 6c: host foreignObject
  layout service on the existing fixed box/inline/paint machinery with owned
  paragraphs, geometry, clips and ordered paint; typed refusals for
  requiredExtensions, active content, forms, embedded browsers, unsupported
  overflow; canonical v1 unchanged. foreign-object positive/boundary/nested
  PASS (max geometry 0.01171875 px), unsupported typed, `foreignStatic` PASS
  without exemptions, rule-based RD-2 eligible on all three required variants.
  Scene requests: repeated SVG references now count in whole-unit
  `sourceNodes`; scene harness keys the resolved `tile.svg`. 65 harness/corpus
  tests pass; one stale SVG-text expectation in `fixed_section_preparer_test`
  belongs to `sol-text`. Open: mask/filter/custom-clip combinations need a
  per-source evidence postpass (currently incomplete geometry).
- Same session resumed for the A1-sample request (inline SVG percentage sizing
  against the XHTML containing block in planning and scene layout; synthetic
  23-section case to success; private run).
- `sol-text` (resumed) died on `invalid_compaction_state` after 387k tokens
  without a report; on disk: `svg_feature_text.dart` (748 lines),
  `fixed_svg_text_fonts.dart`, text harness/tests, preparer changes and the
  granted `FontRegistry.admittedIdentity` accessor. Main-session measurement:
  analysis clean; text harness prepares positive, nested, path-none,
  path-spacing, path-spacingAndGlyphs and the positive/nested parent-length
  diagnostics with hostGate true; boundary (and its diagnostic) refuse on
  `unsupportedProperty:font-kerning`; unsupported typed `svg-text-vertical`;
  one stale preparer test expectation.
- `sol-fo` resume for inline SVG sizing died immediately on
  `invalid_compaction_state` at 314k tokens; no edits.
- Fresh sol-medium sessions: `sol-text2` (owner "A2-svgtext-2": audit,
  `font-kerning`, stale test, verdict, progress) and `sol-svgsize` (owner
  "A2-svgsize": inline SVG percentage sizing against the XHTML containing
  block, synthetic and private sample). Lesson recorded: do not resume Codex
  sessions above ~250k tokens.
- `sol-text2` (A2-svgtext-2, 196k tokens): fixed anchor spacing, cluster
  continuity, path-reference accounting, silent attribute handling, typed HB
  failures and the stale preparer test; `font-kerning` auto/normal -> kern=1,
  none -> kern=0 (module-level boundary B .000115 px). svg-text: positive,
  nested (and their parent-length diagnostics), path-none, path-spacing,
  path-spacingAndGlyphs PASS (B <= .000485 px, conservation, D4 with D8, exact
  solid samples, RD-1 only); unsupported typed; boundary (and its diagnostic)
  still refused because the XHTML style diagnostic at `fixed_scene.dart:209`
  flags `font-kerning` before the SVG module sees it. That namespace-aware
  handoff goes to the fixed-scene owner after `sol-svgsize`.
- `sol-svgsize` (A2-svgsize, 161k tokens): inline SVG sizing against the
  XHTML containing block (CSS over attributes, percentages of the content box,
  indefinite percentage height -> auto with intrinsic ratio), shared by
  planning and layout; standalone SVG unchanged. 189 fixed/corpus/resolver
  tests pass. Private gate: 83/83 sections conserved, 1952 reflow units, but
  0/6 fixed units prepared: every fixed page now refuses on
  `svg-attribute-version`. The synthetic 23-section test fails the same way.
  `dimensions-unsupported` no longer exercises an unsupported dimension (its
  inline 50%/75% now resolves), so the scene harness fails that case.
- Dispatched `sol-closeout` (owner "A2-closeout", sol medium): admit no-op
  `version`/`baseProfile`, namespace-aware handoff of SVG presentation
  properties (unblocks `font-kerning` on svg-text-boundary), replace the
  `dimensions-unsupported` input with a genuinely unsupported page dimension
  with deterministic regeneration and protected-record proof, rerun all rows
  and the private gate.
- `sol-closeout` (A2-closeout, 145k tokens): admitted inert
  `version`/`baseProfile`; namespace-aware SVG style handoff (svg-text-boundary
  and its diagnostic FAIL -> host pass); `dimensions-unsupported` now uses a
  `width=device-width` viewport (EPUB fixed-layout dimensions are authored CSS
  pixels), typed `UnsupportedDimensions`. Corpus SHA-256
  `746ed75288a3ab8b60b7b2eafd0c27cbec19a6ab66b86f2a5553f035ef9ba5cd`, oracle
  `84effbc0c417ac358301377e91b45821085585758375f2a4526f39c542a23fdb`; two
  regenerations byte-identical, the other 51 records identical, both checks
  pass. All 13 rows pass on host (text and svg-text host-pass, raster parity
  A5). Synthetic 23-section test prepares all six fixed constituents. Private
  gate still FAIL: 83/83 sections, 6 fixed units, 0 prepared
  (`resource:scene-admission` 5, `resource:capability` 1).
- Dispatched `sol-admission` (owner "A3-admission", sol medium): identify the
  refusing resource class per page, fix display-resolution decode/charging
  defects without changing any cap, and return measured numbers for an owner
  decision if a cap itself is the limit.
- `sol-admission` (A3-admission, 183k tokens): at view 400x600/DPR 1 the six
  pages refuse on authored-size evidence and layers, not decode: one page on
  `svg-layerPixels` 9,106,344 / 8,388,608 px, five on `vectorBytes`
  46-103 MB / 16,777,216 (page-sized one-CSS-pixel alpha grids); all image
  requests fit 48 MiB. Removed one duplicate outer-SVG alpha term in
  `fixed_preparation_plan.dart`; caps unchanged; no cap request because the
  design's display-resolution behavior is not implemented yet.
- Main-session design decision (design resource row "Display-resolution
  preparation"): (1) lossless uniform coverage regions at the published
  one-CSS-pixel resolution, grids only for non-uniform paints sized to their
  bounds; (2) decode targets and layers at the preparation scale (fit x DPR,
  never above intrinsic), zoom above fit as a separate bounded generation.
  Corpus comparisons run at scale 1. Dispatched `sol-coverage` (owner
  "A2-coverage") for (1); (2) follows after it because the files overlap.
- Review round 3 (Codex gpt-6-astra high) started on the SVG features, sizing,
  fixture correction and A1/A4 wiring, excluding the files under coverage edit.

## Review round 3 result and fixes: 2026-10-29

Codex gpt-6-astra high: 415 tests passed, analysis clean, corpus/oracle checks
pass; the fixture correction is deterministic and genuine. Verdicts:
foreignObject accept; fixture correction accept; clip/mask, SVG text and
sizing accept after fixes; filters reject; A1/A4 wiring reject.
P1: filter geometry claims the whole region as solid coverage while keeping
unfiltered footprints; named filter inputs rerender exponentially; the probe
deadlocks on the shared `PrepareBookQueue` when replacing a publication; the
probe's shutdown closes the replacement's turn controller. P2: probe inputs
and generation not frozen; element opacity applied before filtering;
objectBoundingBox primitive subregions use the filter region;
`filter/clip-path/mask: none` resets dropped before the cascade; SVG text
stylesheet hrefs resolved from the archive root; replaced-element constraints
applied per axis; clip/mask objectBoundingBox from source children instead of
expanded `use` instances; D9 classification skips text/foreignObject paint.
Dispatched (sol medium): `fix-filters` ("A2-filters-3"), `fix-probe`
("A4-probe-fix"), `fix-svgmisc` ("A2-svg-misc"). The clip/mask bounds and D9
classification findings wait for `sol-coverage`, which edits those areas.
(A first launch of these three failed before start because a shell heredoc did
not write the orders; they were rewritten with the file tool and relaunched.)

## Owner pause: 2026-10-29

The owner said: stop all current work. Main session stopped the four Codex
sol-medium `exec` processes it had launched (process trees via `taskkill /T`):
`sol-coverage` (20 patches, no report), `fix-filters` (3 patches),
`fix-probe` (2 patches), `fix-svgmisc` (4 patches). Other Codex processes
(IDE agents, app server) were not touched. No DSH turn was running; dsh `j19`
(WOFF2) had already ended incomplete: Brotli byte-exact on six vector classes,
the real Roboto stream still fails in an HSKIP=3 code-length-code tree (sum
34), no WOFF2 conversion yet, debug code left in `brotli_decoder.dart`.

State after the stop (nothing committed; checkpoint `4f52269` unchanged):
`dart analyze lib tool test` reports 4 errors, all in the in-progress
`test/features/diagnostics/presentation/reader_probe_fixed_route_test.dart`
(test doubles implementing final classes); `lib/` compiles. 61 tracked files
changed (+7204/-495) plus new files. The four stopped sessions' partial edits
are unreviewed and their tests unverified; coverage changes in
`data/geometry/**`, the fixed scene/plan and SVG geometry/plan may be
internally inconsistent until finished.

Open on resume (in order): finish or revert-check the four stopped slices
(lossless coverage, filters P1/P2, probe lifecycle, SVG misc); then the
display-scale decode/layer slice; clip/mask instance bounds and D9
text/foreignObject classification; private gate (A-AC8); WOFF2 (proposed move
to sol medium, owner decision pending); review round 4 (coverage, scale and
the round-3 fixes) and the final full astra review; spec sync for the new
contracts; A5 device work (needs owner: push/CI compile of Swift/C and the
HarfBuzz iOS build approval, signing, iPhone).

## Owner resume: 2026-10-30

The owner resumed S4 with the 2026-10-29 resume list and changed routing: all
implementation goes to the Codex CLI with gpt-6.1-sol at high reasoning;
reviews stay on gpt-6-astra high; WOFF2 moves from DSH to sol high.

Audit of the stopped slices before dispatch: `sol-coverage` had landed about
20 patches (geometry, fixed scene/plan, SVG geometry/plan/clip-mask, two new
uniform-coverage test files; one clip/mask equivalence test failing).
`fix-filters`, `fix-probe` and `fix-svgmisc` had only landed their regression
tests (tests first); no fix had landed, and the probe tests do not compile
(doubles implement final classes). WOFF2: a partial 898-line Brotli decoder
with debug prints and a dictionary generator; no tests, no WOFF2 decoder.

Dispatched five fresh sol-high sessions with resume orders (on-disk partial
state declared as the expected start, ownership unchanged): `sol-coverage`
("A2-coverage"), `fix-filters` ("A2-filters-3"), `fix-probe`
("A4-probe-fix"), `fix-svgmisc` ("A2-svg-misc"), `a3-woff2` ("A3-woff2").
The display-scale decode/layer slice and the clip/mask instance-bounds plus D9
text/foreignObject findings follow `sol-coverage` (same files).
- `fix-filters` (A2-filters-3, sol high, 127k tokens): all four round-3
  findings confirmed and fixed (no invented coverage; cached DAG with bounded
  work/layers; opacity applied after filtering, alpha 64; objectBoundingBox
  subregions). Unit tests 13/13 (rerun by main session). Filters row now FAILs
  positive/boundary/nested (were PASS): every filtered element's geometry is
  marked incomplete because no filtered-output alpha evidence exists yet.
  Follow-up "A2-filters-4" (filtered-output alpha footprints from the rendered
  filter result) waits for `sol-coverage`, which owns the footprint contract.
  Three clip/mask unit failures it saw belong to the in-progress coverage edit.
- `fix-svgmisc` (A2-svg-misc, sol high, 146k tokens): all three round-3
  findings confirmed and fixed (`none` resets kept through the cascade;
  document/sheet-relative SVG text stylesheet links and imports with media
  eligibility; replaced-element constraints recompute the auto axis, 100x75).
  Graphics/text/foreignObject/scene harnesses and the mixed wrapper regression
  unchanged (15 pass). Main session reran its three test files: 38/38 pass.
  Remaining reported failures (3 mask-index unit tests, filters row) belong to
  `sol-coverage` and A2-filters-4.
- `fix-probe` (A4-probe-fix, sol high, 154k tokens): all three round-3
  findings confirmed and fixed (old publication drained before the
  replacement acquires the queue slot; shutdown bound to its own turn
  controller; inputs frozen and generation validated after every await, stale
  candidates released once). Illegal final-class doubles replaced by real
  instances. Main session reran `test/features/diagnostics`: 157/157 pass;
  analysis of diagnostics lib/test clean. Review round 4 must check that
  draining the old publication before replacement keeps the accepted-state
  rules when the replacement fails.
- `sol-coverage` (A2-coverage, sol high, 465k tokens, partial by its own
  account): `GeometryAlphaFootprint` uniform form (128 bytes) plus trimmed
  non-uniform grids at one CSS pixel; XHTML backgrounds, SVG rects/images,
  masks and rectangular clips compress when provably uniform; every alpha
  reader audited, equivalence tests native-checked. Corpus reservations 52-case
  total 93.6 MB -> 62.8 MB (max 7.94 MB -> 4.05 MB); synthetic wrapper 13.9 MB
  -> 4.1 MB. Private gate: no vector refusal remains; 2/6 fixed pages prepare;
  pages 1/2/3/6 refuse on layer pixels (display scale, part 2). Open: exact
  shared-ledger charging (plans keep safe upper bounds; needs reconciliation
  through SVG prepare, preparer, FixedSceneAdmission and the ledger), and
  `fixed_section_preparer_test` read-before-refusal (one raw-section read from
  `FixedSvgTextFontService._presentation`).
- Dispatched three sol-high sessions with disjoint files: `a3-scale`
  ("A3-scale": display-scale decode/layers, part 2), `a2-filters4`
  ("A2-filters-4": filtered-output alpha evidence), `a2-clipmask3`
  ("A2-clipmask-3": clip/mask `use` instance bounds, D9 text/foreignObject
  classification, the read-before-refusal failure). Exact ledger charging is
  queued after `a3-scale` (same files).
- `a3-scale` (85k tokens) stopped correctly without edits: one-CSS-pixel
  evidence still rasterizes authored-size buffers (private page 1: image plus
  RGBA readback = 9,106,344 px against 8,388,608), which display scale cannot
  shrink honestly. Main-session decision recorded as `design.md` row "Bounded
  evidence rasterization (2026-10-30)": tiled authored-resolution evidence
  streamed into the lossless footprint, display-decoded opaque images drawn
  per tile, a charged authored alpha decode (or typed refusal) for images with
  alpha, reservations = scaled layers + one tile + retained evidence. Resumed
  the same session as `a3-scale-r2` (Part A tiling, then Part B display scale;
  scope adds SVG geometry, scene coverage and an additive geometry builder).
- `a2-filters4` (96k tokens) blocked without production edits: geometry runs
  before paint and filtered-output readback needs an awaited post-paint
  evidence hook plus isolated post-opacity capture in `svg_feature_hooks.dart`
  / `svg_graphics_prepare.dart`. To resume after `a3-scale-r2` (which owns
  `svg_graphics_prepare.dart`) with those files in scope, using the tiled
  evidence path.
- `a3-woff2` (A3-woff2, sol high, 311k tokens): pure-Dart RFC 7932 Brotli
  (windows 10-24, all block kinds, HSKIP=3 fixed, all 121 dictionary
  transforms, debug code removed) and WOFF2-to-SFNT (directory, null and
  glyf/loca/hmtx transforms, checksums, typed collection refusal) under the
  WOFF 1.0 bounds and admission. Roboto: 18 tables match after head
  normalization, 1,294 glyphs match; Paragraph and HarfBuzz both 72.763671875
  px (absent family 180 px). 39 Brotli vectors from offline brotli 1.2.0,
  regeneration byte-identical; fixtures 256 KB. Main session reran
  `test/features/reader/engine/layout`: 149/149 pass; dictionary `--check`
  and analysis clean. Request: `fixed_svg_text_fonts.dart:200` still rejects
  WOFF2 for SVG text; queued after `a2-clipmask3`, which owns that file. Open:
  iPhone decode time and native memory (A5).
- `a2-clipmask3` (A2-clipmask-3, sol high, 189k tokens): clip/mask
  objectBoundingBox bounds now come from expanded instances (six
  use/nested-use/symbol regressions); D9 classifier uses published paint
  evidence through `alphaAt` (text/foreignObject regressions); lazy SVG text
  style recovery restores the zero-read-before-refusal assertion. Clip/mask
  and foreignObject rows PASS, text host gate unchanged. Graphics row PASS ->
  FAIL until the harness callers pass `paints:` (four one-line request patches
  in ignored `build/a2-clipmask-3/request-*.patch`; they no longer apply
  cleanly because `a3-scale-r2` is editing those harness files, so they are
  applied after it finishes).
- Main session: routed WOFF2 faces in `fixed_svg_text_fonts.dart` through
  `Woff2Decoder` (same charging/release as WOFF 1.0) and added
  `svg_feature_text_test.dart` "WOFF2 faces convert and shape like their SFNT
  control" (advance equal to the TTF control within 1e-9). SVG text and
  stylesheet tests 17/17 pass; scoped format/analyze clean.
- `a3-scale-r2` (173k tokens): added additive
  `GeometryAlphaFootprint.fromTiles` (3 tests), but tiled and strip native
  rasterization change rotated-edge AA by one (whole 106, strip 105), so it
  withdrew the integration; production evidence and reservations unchanged;
  Part B not started. Design row revised: rasterize evidence once at authored
  size (exact AA), read back through exact integer-aligned tile copies.
- Main session applied A2-clipmask-3's four `paints:` caller patches (CRLF
  normalized); `test/tool/reader` now fails only the filters row.
- Resumed `a3-scale-r3` for Part A only under the revised strategy.
- `a3-scale-r3` died on `invalid_compaction_state` at 219k tokens (no
  report) after 17 patches: exact whole-raster tile copy proven (0 RGBA
  differences for `src`/`srcOver`); authored evidence raster with tiled exact
  readback integrated in SVG geometry and XHTML coverage; new
  `authored_evidence_raster_test.dart` 8/8. Main-session rerun: analysis
  clean; three failures (`svg_feature_hooks_test.dart:129` 20020 -> 30020,
  `svg_feature_filters_test.dart:215` 28 -> 29, and the filters cached-DAG
  release test at :142). Dispatched fresh `a3-scale-4` (sol high) to finish
  Part A from the on-disk state; Part B and A2-filters-4 follow.
- Owner asked to start queued work that can run in parallel with
  `a3-scale-4`, with new development on Sonnet 5.5 high. Only two items have
  no file or API dependency on it: spec sync batch 1 (stable contracts: WOFF2,
  probe lifecycle, SVG presentation/stylesheet/viewport, clip/mask bounds, D9,
  uniform footprint form, filter geometry honesty; `.trellis/spec/**` only),
  dispatched to a Sonnet 5.5 high subagent; and review round 4a (read-only,
  Codex gpt-6-astra high) on the finished round-3 fixes, clip/mask/D9 and
  WOFF2, excluding every `a3-scale-4` file. Display scale, exact ledger,
  filtered-output evidence and filter/clip-mask bounded buffers stay queued
  behind `a3-scale-4` (same files or its evidence-raster API).
- `a3-scale-4` (75k tokens) stopped without edits because the order said the
  new evidence-raster test had 8 tests; it has 3 registered `test()` calls
  that run as 8 cases. Owner correction: new development uses Codex model
  `gpt-6-sol` (not `gpt-6.1-sol`), reasoning high. Relaunched fresh as
  `a3-scale-5` on gpt-6-sol high with the corrected count.
- Spec sync batch 1 (Sonnet 5.5 high subagent, `.trellis/spec/**` only):
  new `reader-font-conversion.md` (WOFF/WOFF2 conversion, bounds, admission,
  dictionary provenance, SVG text route) and `reader-fixed-layout.md` (SVG
  presentation resets, SVG text stylesheets, replaced sizing, clip/mask
  instance bounds, D9, uniform `GeometryAlphaFootprint`, filter geometry
  honesty), both indexed; updates to `diagnostics.md` (fixed/mixed probe
  lifecycle), `reader-resource-admission.md`, `reader-engine.md`, `index.md`,
  `testing.md`, `directory-structure.md`, `quality-guidelines.md`
  (+156/-19 plus the two new files). Main session spot-checked the WOFF2
  bounds against `woff2_decoder.dart` (32 MiB / 16 MiB / 128). Batch 2 (after
  the evidence raster, display scale and filtered-output evidence land) must
  also fix two stale statements it reported: `reader-engine.md:433` (the S2
  probe's mixed refusal now applies only to `open`, not `openPublication`)
  and `reader-resource-admission.md` "A3 pending" scene-budget wording. The
  Brotli MIT notice is not in an app licence registry yet; per
  `third_party/brotli/README.md` that is an S4c handoff, not S4a work.
- Owner switched implementation back to Codex `gpt-6.1-sol` high. The
  running `a3-scale-5` (gpt-6-sol) is left to finish its slice; every new
  implementation dispatch uses gpt-6.1-sol high.
- `a3-scale-5` (A3-scale Part A, gpt-6-sol high, 113k tokens): audited and
  kept the lost session's exact evidence raster (one authored-size evidence
  image per peak, one charged tile copy/readback, no whole-image RGBA
  readback in XHTML/SVG coverage); hooks expectation 20,020 -> 30,020 px and
  DAG image count 28 -> 29 are the intended raster; the release test keeps
  exactly-once release (uses `identical`). Private pages requested pixels
  9.11M/11.73M/11.73M/5.14M/7.26M/11.69M -> 5.08M/3.43M/3.43M/1.80M/2.31M/
  3.42M (cap 8.39M). Main session reran fixed+surface+geometry (296 pass) and
  the private regression: 83/83 sections conserved, 6/6 fixed prepared, 0
  failures, all retained counters zero. Part B (display scale) not started.
- Review round 4a (gpt-6-astra high, read-only): accept probe lifecycle,
  WOFF2 (host scope) and the filters round-3 fixes (row honestly open);
  accept after fixes: SVG stylesheet, clip/mask bounds; reject D9. Findings:
  P1 graphics gate asserts module/fixed parity, not fidelity
  (`fixed_layout_svg_test.dart:67`, harness :875); P2 clip/mask bounds
  transform an axis-aligned box (rotated circle 56.57 vs 40, pixel loss);
  P2 D9 stroke role ignores dash gaps; P2 SVG text `<link>` lacks type
  eligibility. Brotli vectors regenerated byte-identical.
- Dispatched (gpt-6.1-sol high, disjoint files): `a2-filters4-r2` (resume:
  post-paint evidence hook, filtered-output evidence through
  `AuthoredEvidenceRaster`, filter rasters under the shared peak),
  `a2-clipmask4` (transformed bounds, bounded mask readback), `a2-gates-r4`
  (graphics gate fidelity, D9 dashes, link type). Part B and exact ledger wait
  for `a2-filters4-r2` (`svg_graphics_prepare.dart`).
- `a2-gates-r4` (gpt-6.1-sol high, 142k tokens): all three round-4a gate
  findings confirmed and fixed (graphics gate requires overall, geometry and
  pixel success plus parity; D9 ambiguous fill/stroke roles require exact
  samples, dashed-gap regressions for each cap; ineligible `<link>` types skip
  reads). Honest consequence: SVG graphics boundary PASS -> FAIL at sample
  (10,10), delta 1, ambiguous role (geometry and other D4 channels pass).
  Filters row observed FAIL -> PASS mid-run, attributed to `a2-filters4-r2`.
  Legacy A0 SVG-text harness stays provisional FAIL (superseded by the
  production svg-text row). Dispatched `a2-paint-roles` (gpt-6.1-sol high):
  separate fill/stroke paint evidence and topmost-role D9 classification.
- `a2-clipmask4` (gpt-6.1-sol high, 162k tokens): objectBoundingBox bounds
  from transformed geometry (rotated circle diameter 40, pixel (38,50) kept
  for clip and mask through group/use/nested use/symbol); mask readback via
  `AuthoredEvidenceRaster`, large rotated alpha/luminance masks byte-equal to
  the old whole readback; peak one authored image plus one tile (1103x769:
  1,372,495 charged px); refusal/cancel/late-failure release tests. Clip/mask
  row positive/boundary/nested PASS, unsupported typed; private 83/83, 6/6
  fixed, zero retained. Main session reran clip/mask unit + harness: pass.
- `a2-paint-roles` (75k tokens) stopped at a scope conflict without code
  edits: sample (10,10) is on the gradient FILL (reference 205,0,50; native
  204,0,50, inside the gradient exemption) but combined fill+stroke evidence
  makes the role ambiguous. Separate fill/stroke entries need
  `svg_graphics_prepare.dart`, `svg_graphics_plan.dart`, `svg_feature_hooks.dart`
  (owned by running `a2-filters4-r2`) and `place_source_geometry.dart`. To
  resume after `a2-filters4-r2` with those four files in scope.
- `a2-filters4-r2` (gpt-6.1-sol high, 284k tokens): awaited `postPaint`
  hooks and isolated captures after wrappers and opacity; filtered-output
  evidence through `AuthoredEvidenceRaster` at one CSS pixel; incomplete kept
  only for missing graph/bounds/capture and uncaptured ancestor clip/mask
  effects; filter caches and evidence share prepaid raster accounting.
  Filters row positive/boundary/nested/unsupported PASS, required geometry
  delta 0, budgets zero; private 83/83, 6/6 fixed. Main session reran
  filters/hooks/filters-harness: 36/36 pass.
- Resumed `a2-paint-roles-r2` with `svg_graphics_prepare.dart`,
  `svg_graphics_plan.dart`, `svg_feature_hooks.dart` and
  `place_source_geometry.dart` in scope.
- `a2-paint-roles-r2` (gpt-6.1-sol high, 274k tokens): optional
  `GeometryPaintRole` fill/stroke/combined with separate native footprints,
  prepaid accounting and topmost-role D9 classification; (10,10) passes
  honestly as gradient fill (delta 1), thresholds unchanged; four
  role-preservation failures left because two copy constructors outside its
  scope dropped the role. Main session added `role:` to
  `svg_feature_clip_mask.dart` `_copyPaint` and `fixed_scene_geometry.dart`.
  Main-session run: fixed + geometry + surface (private 83/83, 6/6, zero
  failures) + `test/tool/reader` + corpus = 454 pass; `dart analyze lib test
  tool` clean. All 13 production rows pass on host (text raster A5-gated).
- Dispatched `a3-scale-b` (gpt-6.1-sol high: display-scale decode/layers,
  authored-alpha evidence path) and review round 4b (gpt-6-astra high,
  read-only: coverage form, evidence raster, reservations, filtered evidence,
  clip/mask, paint roles, D9 and gates).
- Review round 4b (gpt-6-astra high, read-only, 363 tests pass): accept the
  coverage form, reservations/admission (no undercharge or leak verified) and
  filtered alpha evidence; accept after fixes the evidence raster
  integration, clip/mask, paint roles + D9 and gates. P1 placed SVG evidence
  uses an unplaced raster rectangle (`svg_graphics_geometry.dart:273/:305`:
  SVG at x=100 publishes alpha 0 where native is 255); P1 binary
  point-in-path clipping published as exact (`svg_feature_clip_mask.dart:891`:
  native 191 vs 255); P2 filtered output inherits its input's gradient D9
  exemption (`fixed_layout_svg_samples.dart:151`).
- `a3-scale-b` (Part B, 132k tokens): allocation audit only, no production
  edits; blocked because filter DAG caches feed display and evidence.
  Main-session decision (`design.md` row "Filter display scale
  (2026-10-30)"): filter caches stay at authored scale, all other display
  decodes/layers scale; limitation recorded for S4c.
- Dispatched (gpt-6.1-sol high, disjoint files) `a2-evidence-place`,
  `a2-clip-exact`, `a2-d9-filtered`; `a3-scale-b` resumes after the two P1
  fixes because it shares their files.
- `a2-evidence-place` (141k tokens): P1 confirmed with 19 failing
  regressions; no production edits because the extent/reservation callers
  sit in `fixed_preparation_plan.dart` and `svg_graphics_prepare.dart`.
  Granted both (no other owner on them) and resumed as
  `a2-evidence-place-r2`.
- `a2-d9-filtered` (gpt-6.1-sol high, 263k tokens): P2 confirmed; D9 now
  requires exact samples wherever a source/reference filter applies on the
  element, its instances or ancestors; no exemption broadened, no new field.
  Regressions failed first; `test/tool/reader` 41/41 and samples 10/10; all
  production rows PASS (text raster A5-gated); legacy provisional SVG text
  keeps its six known failures.
- `a2-clip-exact` (gpt-6.1-sol high, 128k tokens): P1 confirmed; clipped
  evidence now comes from per-role native clipped rasterization through
  `AuthoredEvidenceRaster` (AA kept: 191 at the fractional edge), exact tile
  readback, cancellation-safe release; 13 regressions; clip/mask unit +
  harness 46 pass; tool/reader + corpus 99 pass; private 83/83, 6/6. The 19
  remaining fixed failures are `a2-evidence-place-r2`'s placement regressions.
  Open requests: shared root-extent handoff (to align with the placement fix)
  and mixed image-pattern replay under clip, which now refuses typed (no
  required row affected; for the final review).
- `a2-evidence-place-r2` (gpt-6.1-sol high, 186k tokens): placed SVG fill,
  stroke, image and per-role evidence match native alpha; reservation matches
  the authored root-coordinate raster extent/origin; 19 regressions pass;
  seven reports unchanged; corpus 58/58; private 83/83, 6/6. Main-session
  full run: fixed + geometry + surface (private) + tool/reader + corpus +
  layout + diagnostics = 799 pass; analysis clean.
- Resumed `a3-scale-b-r2` (Part B with the filter decision) and dispatched
  spec sync batch 2 (`spec-b2`, gpt-6.1-sol high, `.trellis/spec/**` only:
  evidence raster, paint roles, filtered evidence, exact clips, D9/gates, two
  stale statements; display scale excluded).
- `spec-b2` (107k tokens) stopped without edits on a real discrepancy:
  `svg_feature_clip_mask.dart` `_clipFootprint` still rasterizes `plan.size`
  at origin zero, so clipped per-role evidence of a placed inline SVG can be
  truncated (the "shared root-extent handoff" A2-clip-exact left open;
  A2-evidence-place fixed `_coverage` and preparation only). Fix queued right
  after `a3-scale-b-r2` (which may edit mask display layers in that file),
  then `spec-b2` resumes.
- `a3-scale-b-r2` died on `invalid_compaction_state` at 233k tokens (no
  report) after 47 patches: new `fixed_preparation_scale.dart`, scale through
  plan/scene/SVG/image cache/surface, DPR-3 surface and private passes, last
  work `ImageLease.release` selective eviction. Main-session run of the disk
  state: `test/features/reader` + `test/tool/reader` + diagnostics with the
  private sample all pass except the S2-era
  `local_books_support_test.dart` (asserts every local book is
  reflow-supported; private book 5 is the mixed fixed-layout publication and
  correctly reports `fixedLayout`; detector unchanged since `4f52269`; stale
  expectation, to fix before commit). Private 83/83, 6/6; analysis clean.
- Dispatched fresh `a3-scale-close` (audit/close Part B, DPR 1/3 numbers) and
  `a2-clip-extent` (placed extent for clipped per-role evidence), disjoint
  files; `spec-b2` resumes after both.
- Both `a2-clip-extent` (155k tokens) and `a3-scale-close` (244k tokens)
  ended on provider `503 Service Unavailable`. clip-extent landed only its
  regression test (`svg_clipped_evidence_placement_test.dart`, failing as
  expected before the fix). closeout landed 3 patches (`image_cache.dart`
  plus two tests), a full run of 664 passing and a private run at 83/83, 6/6;
  its later run's 27 failures are clip-extent's pending regressions. A
  background probe waits for the service before redispatching.
- Provider outage persisted (503 for gpt-6.1-sol, gpt-6-sol and gpt-6-astra
  after 20+ minutes). Owner: "算了，让sonnet5.5 high接手吧". Dispatched two
  Sonnet 5.5 high subagents from the on-disk orders: A3-scale-b closeout
  (review the 3 landed patches, DPR 1/3 numbers, progress) and A2-clip-extent
  (review the regression file, fix `_clipFootprint` placed extent).
- A3-scale-b closeout (Sonnet 5.5 high subagent): audit found no defect in
  the landed patches (`ImageLease.release` single-shot, discard only on the
  final lease, both release orders and late cancel/failure tested); only
  change: the private regression asserts DPR-3 geometry equals DPR 1. Scale =
  min(view/authored) x DPR from the frozen layout, through
  `FixedPreparationPlan` to targets (intrinsic clamp), `decodedImageBytes`,
  reservation and allocation. At scale: image decode, XHTML/SVG opacity
  layers, clip/mask/pattern/dash layers. Authored: all evidence, filter DAG
  caches/scratch and images under filters. Alpha images: intrinsic decode
  proves opacity; opaque -> released, display decode serves both; alpha ->
  intrinsic kept as evidence until scene build plus a display decode, both
  charged; typed `ImageAdmissionException`. Geometry/CFI identical at scale
  1/.25/1.5 and DPR 1 vs 3 on the private pages. Private (400x600, layer px /
  peak image bytes) DPR1 -> DPR3: p1 5.16M/37.97MB -> 5.16M/45.22MB; p2,p3
  3.49M/24.63MB -> 3.49M/31.88MB; p4 1.82M/10.76MB -> 1.82M/13.72MB; p5
  2.36M/15.61MB -> 2.36M/14.72MB; p6 3.48M/24.55MB -> 3.48M/31.82MB; 83/83,
  6/6. Final-review items: page 1 at DPR 3 uses 45.2 of 48 MiB; the alpha
  evidence decode is intrinsic, not min(intrinsic, authored) as the design
  row states; unused `preparationScale` plumbing in the scene builder and
  foreignObject service.
- A2-clip-extent (Sonnet 5.5 high subagent): confirmed; `_clipFootprint`
  and `_maskCoverage` now use `_placedEvidenceExtent` (same extent as
  `_coverage` and the reservation), translate, rasterize through
  `AuthoredEvidenceRaster` and `.placed` back; a guard marks paints
  clip-incomplete / refuses `svg-mask-extent` if the prepaid ledger differs
  from the expected size (only reachable with a prepare-time placement
  override and null evidenceSize). Fixed three control bugs in the Codex
  regression file; 46 cases. Request (for review): expose the effective
  evidence bounds on the hook context to replace that guard.
- Main session fixed the stale S2 `local_books_support_test.dart` expectation
  (fixed-layout books go to the S4a fixed path; any other reason still
  fails). Full run of `test/features/reader` + `test/tool/reader` +
  diagnostics with the private sample: all pass; 83/83, 6/6; analysis clean.
  Codex provider still 503.
- Dispatched Sonnet 5.5 high subagents: `A3-ledger` (exact retained-evidence
  reconciliation) and `spec-b2` (spec batch 2 incl. display scale; ledger
  excluded). Final full review routing (astra unavailable) awaits the owner.
- spec-b2 (Sonnet 5.5 high subagent, `.trellis/spec/flutter/**` only):
  `reader-fixed-layout.md` gains authored evidence raster, paint roles,
  filtered-output evidence (replacing "filter geometry honesty"), clip/mask
  evidence incl. the extent guard and `svg-mask-extent`, display-scale
  preparation (scale flow, display vs authored sites, alpha-image path,
  `ImageLease.release`), final D9/graphics-gate rules; the intrinsic vs
  min(intrinsic, authored) alpha-evidence mismatch is flagged for review.
  `reader-engine.md` probe mixed-refusal and `reader-resource-admission.md`
  "A3 pending" statements corrected; index rows updated. Exact ledger left
  out (in progress). It also found the "mixed image-pattern replay under clip
  refuses" note stale: clip/mask now pass `prep.images.forEvidence`; no test
  covers an image pattern under a clip (final-review item).
- A3-ledger (Sonnet 5.5 high subagent): `FixedSceneAdmission.reconcileEvidence`
  runs as the last fallible step of `FixedPreparationOperation._run`,
  shrinking the unit lease (new additive `SceneResourceLease.shrink`) from
  `plan.retainedEvidenceBytes` to stored `storageBytes` (distinct footprints
  incl. mask coverage) plus a 128-byte wrapper per paint footprint and mask
  application (covers the single `geometryForUnit` placement; a second call
  now throws). Failure/cancel keep the single full release. 22 + 2 tests
  (charge equals an independent sum; ledger never below live allocations).
  Corpus 35 preparing cases: 20,231,680 -> 270,180 bytes (max 3,154,048 ->
  38,644); private 6 pages 16,659,640 -> 16,309,514 (non-uniform page grids).
  Main-session full run: `test/features/reader` + `test/tool/reader` +
  diagnostics with the private sample = 1837 pass (2 pre-existing skips);
  83/83, 6/6; analysis clean. All local S4a implementation slices are done;
  next: final full review (routing pending the owner), then commit approval
  and A5.

## Final review: 2026-10-30

Owner: "astra审，gpt-6.1-sol改"; and "改完之后的复审只审查修改的部分，不跑全量"
(the re-review after fixes covers only the fix diffs and their findings, with
targeted tests, no full suites). The S4a exit review (range: `master` ->
checkpoint `4f52269` plus the working tree) runs as three parallel read-only
gpt-6-astra high sessions: final-A (geometry, fixed XHTML scene, preparation,
admission, evidence raster, display scale, ledger), final-B (SVG renderer,
features, gates/harnesses, corpus/oracle), final-C (fonts/WOFF2/HarfBuzz,
units/navigation, surface/session lifetime, probe/diagnostics, iOS/runbook).
Each judges the seven known items in its area and the A-AC criteria host
evidence can show.
- final-A (astra, 1,122 tests pass): reject fixed XHTML layout/paint. P1
  inline replaced content (inline SVG, `img`) silently dropped while geometry
  is published complete (`fixed_scene_layout.dart:243`); P1 inline
  backgrounds accepted but never painted (:289); P2 ledger reconciliation
  misses foreignObject's retained original host footprints (undercharge);
  P2 alpha evidence decode at intrinsic vs design; P3 two specs still say
  reconciliation is pending. Known items: 1 not a defect (A5 headroom),
  5 nonblocking, 6 accept after the foreignObject fix and moving the
  repeated-placement guard. A-AC2/3/4 not met in its scope until fixed.
- Main-session decision (`design.md` row "Alpha-image evidence decode
  (2026-10-30)"): keep the intrinsic decode (only it proves per-pixel
  opacity), charged before allocation and released right after evidence.
- Dispatched `fix-final-a` (gpt-6.1-sol high) for all five; areas B and C
  still under review.
- final-C (astra, 567 pass): accept fonts/WOFF2/provenance, HarfBuzz route
  (host), reading-unit composer/navigator, capture/analyzer host mechanisms,
  A5 runbook as a pending-evidence contract; accept after fixes the
  publication composition; reject the probe integration. P1 mixed
  composition retains every reflow `PreparedSection` (bypasses the 4-section
  cache and admission); P1 fixed/mixed publication never updates
  `controller.identity` (capture fails or mislabels; scripted `open()` path);
  P2 fixed/mixed jump and settings no-ops, `pageCount` throws on fixed; P3
  `reader-engine.md` optional-work/coalescing statements stale. Known items 1
  and 6 accepted; 2 deferred to final-A's decision.
- Dispatched `fix-final-c` (gpt-6.1-sol high; surface, pagination,
  diagnostics, specs), disjoint from `fix-final-a`.
- final-B (astra, 345 pass): accept graphics/presentation/patterns,
  foreignObject/font service, corpus/oracle generation; accept after fixes
  SVG text, filters, clip/mask, harnesses/gates, specs. P1 SVG text coverage
  ignores the enclosing evidence bounds (placed SVG: 187 painted, 0
  evidenced); P1 filter output ignores inherited SVG viewport clips; P2 inline
  SVG ignores CSS absolute insets (`fixed_scene_svg.dart:38`); P2 SVG text gate
  does not validate `sourceToUnit` (a 100 px displacement still passes); P2
  the clip/mask extent guard compares pixel counts only (equal area,
  different origin bypasses it); P3 reconciliation-pending spec wording (same
  as final-A). Known items: 3 accept (add regression coverage), 4 requires
  correction, 7 accept as recorded limitation.
- Dispatched `fix-final-b` (gpt-6.1-sol high: SVG text coverage extent,
  filter viewport clips, effective evidence extent on the hook context,
  text gate transforms). The inline SVG CSS positioning fix waits for
  `fix-final-a`, which owns `fixed_scene_svg.dart`.
- `fix-final-b` (gpt-6.1-sol high) ended on provider `server_is_overloaded`
  at 265k tokens after 26 patches but had finished: all four findings fixed
  (placed SVG text coverage with the effective `evidenceExtent` and shared
  raster budget; inherited viewport clips replayed on filter output and its
  evidence; required `evidenceExtent` on `SvgFeaturePreparation` /
  `SvgFeaturePostPaintContext`, pixel-count guard removed; SVG text gate now
  also checks unit-space positions with displacement falsification), spec
  and progress written. Main-session check of its scope: SVG + tool/reader +
  corpus + private regression = 353 pass; 83/83, 6/6; scoped analysis clean.
- `fix-final-a` (gpt-6.1-sol high, 471k tokens): inline SVG/img now go
  through replaced layout, painting and source geometry with a
  planned-vs-prepared conservation check; per-line inline background paint
  evidence (unsupported borders/decorations refuse typed); foreignObject
  original/exported/placement owners charged (384 bytes in the probe) and the
  repeated-placement check precedes allocation; alpha intrinsic decode now
  released right after evidence (cache 20,400 -> 1,200 bytes in the
  regression); specs updated. Main-session check: fixed + data + scene budget
  + tool/reader + private regression = 1,025 pass; 83/83, 6/6; analysis
  clean. Request: `publication_fixed_sources.dart` must admit inline `img`
  sources (now refused typed when missing): queued after `fix-final-c`.
- Dispatched `fix-svg-position` (gpt-6.1-sol high: CSS containing-block
  positioning of inline SVG).
- Owner: "复审同样交给astra": the post-fix re-review (changed parts only, targeted tests) runs on gpt-6-astra high.
- `fix-final-c` (gpt-6.1-sol high, 299k tokens): shared four-section admitted
  reflow cache with protected eviction and asynchronous reload (mixed
  composition no longer retains every section); identity published atomically
  with the session, S3-aware scripted capture, exactly-once owner retirement;
  unit/source jumps, fixed-safe counts and settings/viewport recomposition
  with CFI restoration; `reader-engine.md`/`diagnostics.md` updated. Private
  DPR 1/3 83/83, 6/6. Main-session check: surface + pagination + diagnostics
  = 385 pass (2 skips); 83/83, 6/6; `dart analyze lib test tool` clean.
- Dispatched `fix-img-admit` (gpt-6.1-sol high: collect XHTML `img src` in
  `publication_fixed_sources.dart`).
- `fix-img-admit` (gpt-6.1-sol high, 109k tokens): XHTML `img src` admitted
  through the existing image-request path; 11 regressions (4 failed before);
  surface + fixed 517 pass; private 83/83, 6/6 at DPR 1/3; spec updated.
- `fix-svg-position` (gpt-6.1-sol high, 146k tokens): inline SVG reuses CSS
  containing-block/inset positioning; paint, `evidenceExtent` and
  `sourceToUnit` agree; unsupported positioning refuses typed; 11 regressions;
  fixed + tool/reader + corpus 503 pass; eight reports unchanged; private
  83/83, 6/6 at DPR 1/3.
- Main-session full run after all fixes: `test/features/reader` +
  `test/tool/reader` + diagnostics with the private sample = 1902 pass (2
  skips); 83/83, 6/6; `dart analyze lib test tool` clean.
- Re-review (gpt-6-astra high, changed parts and targeted tests only, three
  parallel sessions): R1 (fix-final-a, fix-svg-position, fix-img-admit), R2
  (fix-final-b), R3 (fix-final-c).
- Re-review R1 failed at start on astra `server_is_overloaded`; a background
  probe relaunches it when astra answers.
- Re-review R3 (astra, 66 targeted tests pass): identity/capture and spec
  fixed; mixed retention and navigation partially fixed. New: P1 cache hits
  return an unprotected async borrow (a queued miss can evict the hit before
  it is pinned); P2 a second metrics change during probe replacement leaves
  no displayed session. Overall accept after fixes. Dispatched `fix-r3`
  (gpt-6.1-sol high); its re-check will cover only these two changes.
- Re-review R2 (astra, 149 targeted tests pass): SVG text coverage, clip/mask
  `evidenceExtent` and the text transform gate fixed; filter viewport clips
  partially fixed: new P2 inherited viewport clips applied twice (capture and
  output), so fractional viewport edges darken (191 -> 143, 96 -> 36).
  Overall accept after fixes. Dispatched `fix-r2` (gpt-6.1-sol high,
  `svg_feature_filters.dart` only). R1 relaunched once astra answered.
- Re-review R1 (astra, 127 targeted tests pass): inline replaced content,
  inline backgrounds, foreignObject ledger, alpha decode lifetime and spec
  wording fixed; SVG CSS positioning and img admission partially fixed. New
  P2s: nested out-of-flow SVG inside a span placed as a paragraph placeholder
  (insets lost); ancestor final shifts move viewport-fixed SVG; relative
  inline-blocks miss shifted-paragraph admission (`fixed_preparation_plan.dart`);
  raw `img src` resolved with archive-key priority (path collision selects the
  wrong resource). Overall accept after fixes. `fix-r1` (gpt-6.1-sol high)
  launches once sol has capacity; `fix-r2` waits the same way.
- `fix-r2` (103k tokens) confirmed the double clip (identity 96 -> 36, blur
  96 -> 29) and added six regressions, but the input-capture change lives in
  `svg_feature_hooks.dart` / `svg_graphics_prepare.dart`; granted (no other
  owner on them) and resumed as `fix-r2-r2`. `fix-r1` started once sol had
  capacity.
- `fix-r2-r2` (gpt-6.1-sol high, 149k tokens): inherited viewport clips
  apply once to filtered display and evidence; descendant clips intact; six
  regressions plus other features' capture checks: 126 targeted pass; filters
  row positive/boundary/nested/unsupported PASS; spec updated.
- Owner: "先让astra复查，等astra的复查完成了你再核对": each fix goes to astra re-check first; the main-session verification runs after it. Dispatched astra re-check of fix-r2 (changed parts and targeted tests only).
- `fix-r3` (gpt-6.1-sol high, 134k tokens): synchronous delivery leases
  protect cache hits and coalesced borrowers; probe replacement keeps intent,
  position and latest settings across retirement; 61 targeted pass; private
  83/83, 6/6 at DPR 1/3.
- `fix-r1` (gpt-6.1-sol high, 145k tokens): out-of-flow SVG bypasses inline
  placeholders; viewport-fixed SVG keeps coordinates under ancestor shifts;
  relative inline-blocks budgeted; img/SVG image URLs resolve against their
  section without archive-key fallback; 112 + 15 targeted pass; private
  83/83, 6/6 at DPR 1/3.
- Astra re-checks (changed parts and targeted tests only) dispatched for
  fix-r1, fix-r2 and fix-r3; main-session verification follows them.
- Astra re-check of fix-r2: accept (126 targeted pass; identity/flood/blur match unfiltered controls, edge alpha 191 / corner 96 kept; no new defects in clip/mask, foreignObject, text or default capture).
- Astra re-check of fix-r3: accept (61 targeted pass; delivery pins protect hits and coalesced borrowers; probe replacement survives retirement; no new defects).
- Owner: "全量核对也交给astra": the full verification after the re-checks runs on gpt-6-astra (order `astra-verify`), dispatched once the fix-r1 re-check finishes.
- Astra re-check of fix-r1: items 2-4 fixed; item 1 partially fixed: an absolute SVG inside a `position:relative` span ignores the inline containing block (x=120 vs 150, still complete). Resumed fix-r1 (support it or refuse typed). The full astra verification waits for this.
- `fix-r1` follow-up (177k tokens): typed refusal `inline-positioned-containing-block` for absolute descendants of a positioned inline lacking first/last-fragment geometry; regressions failed first; 117 targeted pass; private 83/83, 6/6 at DPR 1/3. Astra re-check `recheck-r1b` dispatched; `astra-verify` follows if it accepts.
- Astra re-check of the fix-r1 follow-up: accept (65 targeted pass; refusal precise: static-span absolute, viewport-fixed, positioned-block, relative inline SVG/inline-block and relative text controls still prepare). All re-checks accepted; `astra-verify` (full host verification) dispatched.
- `astra-verify` (full host verification): tests 3,133 pass, 0 fail, 2
  optional skips (native CFI export env unset; pre-seam baseline absent);
  analysis clean; dictionary check, `check-fixed-corpus` (13 rows / 52 cases)
  and `fixed-oracle --check` (WebKit and Chromium, 52 cases) pass; private
  DPR 1 and 3: 83/83 sections, 6/6 fixed, zero failures and retained
  resources; all 13 production rows PASS on host (text and SVG-text raster
  A5-gated). Verdict FAIL only for formatting drift in 2 files.
- Main session fixed it: the dictionary generator now appends `;` to the last
  literal (regenerated, `--check` passes) and `svg_graphics_markers.dart` was
  formatted; `dart format --set-exit-if-changed lib test tool` now 0 changes.
  Astra re-check `recheck-format` dispatched.
- Astra `recheck-format`: format check 771 files 0 changed; dictionary check
  and analysis clean; 91 targeted pass; base64 payload equals the pinned
  source (no prior tracked copy to diff); the markers diff adds two trailing
  commas and equals `dart format` of `4f52269` (not whitespace-only, as the
  order's literal wording required; semantically neutral). Astra: host
  verification now PASS. Local S4a work is complete pending owner approval to
  commit and the A5 device phase.

## Commit and CI: 2026-10-30

Owner: "提交并推送CI编译". Committed on `s4a/checkpoint-2026-10-28`:
`2384b52` feat(reader) (code, tests, tools, fixtures, vendored dictionary),
`7f8c4a8` docs(spec), `d8e8b0e` docs(task). Created and pushed
`ios-build/s4a-fixed-layout` at `d8e8b0e` (the branch pattern that triggers
`.github/workflows/ios-unsigned.yml`); CI run 41029374942 (probe mode)
started. The CI build does not wire HarfBuzz (its iOS script is an unwired
draft), so no third-party source is downloaded; the HarfBuzz iOS build still
needs separate owner approval. master is unchanged.
- CI run 41029374942 (unsigned iPhone, probe mode, macos-15 / Xcode 26.3,
  Flutter 3.47.7): success on every step (build, validate and package
  unsigned device app; artifact uploaded). This is the first hosted macOS
  compile of the A0 Swift/C changes.

## HarfBuzz iOS build: 2026-10-30

Owner: "Approve HarfBuzz". Main session pinned the official source after an
approved download into an isolated scratch directory (hashed only, nothing
executed): `harfbuzz-14.6.0.tar.xz` from the GitHub 14.6.0 release, 20,295,260
bytes, SHA-256 `d07a007327277708a2a73ae437887cdbaf282937f6d03ca5467723e9099af586`
(equals GitHub's asset digest); root `COPYING` SHA-256
`ba8f810f2455c2f08e2d56bb49b72f37fcf68f1f4fade38977cfd7372050ad64` (equals the
notice recorded in `research/harfbuzz-ios-packaging.md`). Dispatched `hb-ios`
(gpt-6.1-sol high) to pin it, wire the prefixed static build into the unsigned
iOS CI, link Runner (scoped force_load plus `-u` roots for every required
`shiori_hb_*`), and audit the final executable; the CI runner downloads the
source. Astra re-check, then commit/push for CI follow.
- `hb-ios` (gpt-6.1-sol high, 169k tokens): pinned SHA in `build_harfbuzz_ios.sh`; CI builds prefixed static HarfBuzz 14.6.0 (device arm64, simulator arm64/x86_64, iOS 15.0, dependencies disabled, preinstalled CMake with preflight, no cache); single xcconfig link owner (`ios/Flutter/HarfBuzz.xcconfig` included by Debug/Release) with scoped force_load, 33 `-u` roots generated from `HarfBuzzBindings._required`, additive export; strict archive audits and final Runner verification; inventories/logs/maps/hashes/COPYING/XCFramework uploaded. Local: bash -n, extraction, synthetic audit, YAML checks exit 0; host text tests 17 pass. Astra `recheck-hb` dispatched.
- Astra `recheck-hb`: no blocking defects; hash/size verified before extraction, pins and `persist-credentials: false` intact, audits fail closed, single SDK-scoped link owner with 33 generated roots; ready to push. CI must prove compilation, audits, XCFramework and final Release exports; Debug/simulator app linkage and runtime lookup remain separate gates.
- Committed `3cc86b5` build(ios) and fast-forwarded/pushed `ios-build/s4a-fixed-layout` (d8e8b0e..3cc86b5); CI run 41034103866 started.
- CI run 41034103866 FAILED in "Build, validate and package": source download/verify and CMake configure of device-arm64 succeeded, then the script stopped with "Expected a static HarfBuzz build" (its static-build check rejected the configured build). Not yet fixed; next: inspect that check in `tool/ci/build_harfbuzz_ios.sh` (likely the CMake cache variable it greps), fix via gpt-6.1-sol, astra re-check, re-push.
- Diagnosis (main session, from the run artifact): the configure passes untyped `-DBUILD_SHARED_LIBS=OFF`, so the cache records `BUILD_SHARED_LIBS:UNINITIALIZED=OFF` and the strict `BOOL=OFF` check fails although the build is static; `HB_BUILD_GPU_DEMO:STRING=AUTO` is outside the BOOL-only component check. Dispatched `hb-fix1` (gpt-6.1-sol high): typed definitions, strict checks kept, non-BOOL component switches covered.
- `hb-fix1`: all 24 CMake definitions typed, `HB_BUILD_GPU_DEMO:STRING=OFF` explicit; cache check requires exact types/values and fails closed on unknown, missing or duplicate HB entries; local: old cache fails, static-only fix fails on GPU_DEMO=AUTO, synthetic corrected cache passes; 237-case matrix and syntax checks exit 0. Astra `recheck-hbfix1` dispatched.
- Astra `recheck-hbfix1`: no findings; 24 typed definitions, 14 HB switch types match the artifact, STRING=OFF is a listed choice for GPU_DEMO, the sole HB INTERNAL entry accepted while unknown ones fail; 234 invalid cases rejected. Ready to push.
- Committed `64fd66c` fix(ci) and pushed (3cc86b5..64fd66c); CI run 41042343059 started.
- CI run 41042343059: configure passed (typed definitions accepted);
  compile of `device-arm64` failed (20 errors): the force-included map
  `#define`s every lexical `hb_*` identifier and C++ namespace, colliding with
  HarfBuzz's own macros/templates (`hb_min_size`, `hb_enable_if`). No local
  C++ toolchain exists on this machine, so iteration is CI-only.
- Main-session decision ("Revised prefixing (2026-10-30)", to be recorded in
  `research/harfbuzz-ios-packaging.md`): prefix only the public `HB_EXTERN`
  C API (minus source-defined macros), compile with hidden visibility so
  internal C++ symbols are not exported (Flutter's HarfBuzz is in the dynamic
  Flutter.framework, isolated by two-level namespaces), and audit strictly on
  visible symbols: thin archives export only `shiori_` names, all 33 required
  present, final Runner exports no unprefixed HarfBuzz symbol. Dispatched
  `hb-fix2` (gpt-6.1-sol high).
- `hb-fix2`: HB_EXTERN-only map (541 APIs, all 33 required; source macros and C++ names excluded), hidden visibility in all slices with generated annotations exposing only mapped APIs (six excluded APIs stay hidden), audits (a)-(c) implemented; generator, 488 audit cases, syntax and build-mode checks pass; 17 host tests pass; packaging doc updated. Astra `recheck-hbfix2` dispatched.
- Astra `recheck-hbfix2`: no blocking defects; 541 APIs incl. all 33; the six exclusions are header/test macros (none required); visibility flags cover all three slices; audits strict; ready to push.
- Committed `51e6eea` fix(ci) and pushed (64fd66c..51e6eea); CI run 41046483072 started.
- CI run 41046483072: device-arm64 compiled and installed (fix 2 works);
  failed at `lipo -verify_arch <arch> <file>` (argument order). Main session
  swapped both calls to `lipo <file> -verify_arch <arch...>` (mechanical).
  Astra `recheck-hbfix3` reviews it and pre-reviews every remaining
  never-executed Apple CLI step (nm/c++filt parsers, lipo -create,
  xcodebuild -create-xcframework, dyld_info, link map, xcconfig) to avoid
  further one-error-per-run iterations.
- Astra `recheck-hbfix3`: lipo fix correct; remaining Apple CLI calls statically fine (nm/c++filt/lipo -create/xcframework/dyld_info/ditto/shasum, link map); P1 `ios/Flutter/HarfBuzz.xcconfig` makes every local Debug/Profile/Release build require the CI-generated config (missing include or stale force_load path). Dispatched `hb-fix4` (gpt-6.1-sol high): settings in a generated xcconfig, wrapper `#include?`, CI preconditions explicit.
- `hb-fix4`: wrapper is only `#include? "../../build/third_party/harfbuzz-ios-14.6.0/HarfBuzz.generated.xcconfig"`; all settings generated; local builds link as before without it; CI requires the generated config and device/simulator archives before Flutter; Profile inherits Release. 19 synthetic preflight cases and syntax checks pass. Astra `recheck-hbfix4` dispatched.
- Astra `recheck-hbfix4`: P1 resolved, optional include resolves for Debug/Release (Profile inherits Release), generated settings equal the previous wrapper (33 roots), CI preconditions strict, lipo fixes intact; residual: a stale local generated config fails visibly or reports missingSymbol. Ready to push.
