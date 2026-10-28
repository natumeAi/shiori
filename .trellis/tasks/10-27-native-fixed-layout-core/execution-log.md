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
