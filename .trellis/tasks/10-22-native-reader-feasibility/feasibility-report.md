# S2 native reader feasibility report (Phases A-F and first device run)

**Status: final S2 report; S4 conditional GO (有条件通过), user decision
2026-10-23.** Every acceptance row remains independent. NC1-NC6 below retain
their local results; NC7-NC8 now report the first iPhone run, including failed,
partial and unverified gates. Conditional GO authorizes S4 architecture work,
not product release or a claim that every NC7 gate passed.

Device build: `862d999010fa-gha-7`; analysis reviewed at HEAD `417daf4` on
`ios-build/s2-reader-probe`. [CI packaging](local-validation.md#push-and-ci-build-of-phases-d-f)
verified Swift compilation and both IPAs; the first device run supplied hook
and export evidence. [Device analysis](device-analysis.md),
[run protocol](device-runbook.md), and [user decisions](device-analysis.md#11-decisions-after-the-first-device-run)
define the evidence boundaries. Local tests use the Windows host/Ahem and
Windows Playwright engines; they do not imply iPhone cadence or presentation.

## Rows

| Row | Status | Evidence |
| --- | --- | --- |
| NC1 oracle | PASS locally (Phase A) | Two clean UTC/Asia/Hong_Kong generations: final 32 generated/attribute files byte-identical, zero source-filter mismatches. WebKit 27.2 / Chromium 156.0.8078.4; 13 fixtures, 39 sections, 4,807 sampled CFI points per engine; four local sample books, 60 sections, 168,677 samples, zero cross-engine differences. Vendored reference matches `a4bda23`. [Final reproducibility](evidence/oracle-final-reproducibility.json), [reference check](evidence/oracle-check-reference-final.json), [source-byte correction](local-validation.md#phase-a-post-staging-source-byte-correction), [final vector slimming](local-validation.md#post-phase-b-review-oracle-vector-slimming). Earlier 45-file results predate slimming. |
| NC2 source, CFI, canonical | PASS locally (B, re-run in C) | 256 reader-data tests; zero mismatches on synthetic and local-book vectors, including 168,677 local CFI samples. Native-exported vector CFIs resolve identically 4,807/4,807 per browser; Phase C adds 2,413 page anchors x 2 engines = 4,826/4,826. `xml` 7.0.1 re-verified. [Phase B results/test counts/gaps](local-validation.md#phase-b-evidence--2026-10-22), [Phase C](local-validation.md#phase-c--layout-page-map-anchors-detection). |
| NC3 conservation and matrix | PASS locally (Phase C) | Ten supported fixtures and the four local sample books pass all three gate settings; zero text loss/duplication/order/geometry failures. Tables and documented differences below. Three unsupported fixtures are refused recoverably, never opened empty. [Phase C evidence](local-validation.md#phase-c--layout-page-map-anchors-detection). |
| NC4 anchors | PASS locally (Phase C, D integration) | Every supported fixture page round-trips at three settings; four local sample books pass conservation/anchors; 2,980 visible oracle CFIs land; 2,413 native anchors resolve identically in both engines. Reflow/injected failure preserve the accepted anchor; Phase D adds turn-target proofs. [Phase C](local-validation.md#phase-c--layout-page-map-anchors-detection), [Phase D proof inventory](local-validation.md#ported-reference-inventory), details below. |
| NC5 motion state machine | PASS locally (Phase D) | Reference ports and native equivalents cover thresholds, easing, axis lock, rebound, late neighbor, 1+8 FIFO/overflow, rebase, cancellation/generation, proof-before-acceptance, reduced motion and lifetime/callback-work bounds. Implementation contributed 146 tests; review added lifecycle-resume regression. Whole suite 785 passed, 1 skipped after review. [Built/completed and port inventory](local-validation.md#phase-d--motion-controller-and-surfaces), [deferrals](local-validation.md#deferred-cases-and-native-substitutions), [review](local-validation.md#phase-d-review-and-independent-re-run). |
| NC6 harness and quality gate | PASS locally (Phase E) | Probe R01-R11, bounded/private v1 exports, independent analyzer parity over 12 synthetic exports, negative correctness/resource fixtures and fixture/privacy guard pass. Post-review format: 253 files, 0 changed; analyze: no issues; whole suite: 969 passed, 1 skipped, all exits 0. Existing product/S1 tests pass. [Phase E implementation/gate](local-validation.md#phase-e--probe-harness-analyzer-native-spike-ci), [independent review/final gate](local-validation.md#phase-e-independent-trellis-check-review--2026-10-23). Swift/IPA execution remains unverified, not a claimed local result. |
| NC7 device scenarios | MIXED: resource FAIL; latency/stalls UNVERIFIED; lifecycle PARTIAL | Stage budgets pass A1 30/30 and R11 4/4; correctness passes where evaluable. RSS failures remain under the unchanged 5% rule. Recognized admission and stall classification are unverified because of measurement limits; R09 has no accepted turn after OS return. [Per-gate results](#nc7-first-device-run), [analysis §§1-6](device-analysis.md#6-device-gate-matrices-and-evidence-qualifications), [corrected declarations §10](device-analysis.md#10-operator-declaration-corrections-2026-10-23). |
| NC8 presentation evidence | PASS reporting requirement; qualified native evidence | A1/A2/B data arrived with inventory and loss accounting. A1/A2 measure layer commits; B measures system drawable presentation on a non-product path. Product-path physical presentation and touch-to-photon remain unverified. [Per-mode evidence](#nc8-native-evidence), [analysis §§3,5,6](device-analysis.md#3-a2-display-link-anomalies-and-commit-bins). |
| NC9 GO / NO-GO | PASS decision/report requirement; S4 conditional GO | NC1-NC9 are independently reviewed in this table. User decision on 2026-10-23: conditional GO (有条件通过), with explicit S4 entry/exit items. [Conditions](#nc9-s4-decision-and-conditions), [decision record §11](device-analysis.md#11-decisions-after-the-first-device-run). Failed and unverified NC7 gates are not waived or relabeled as passes. |

## NC7: first device run

Acceptance inputs are default A1 R01-R10, three repeats each; four manual R11
sample captures; and one separate manual OS lifecycle supplement. A2/B are
comparisons, not substitutes for default-path NC7. All five sets passed strict
aggregate parity (30/6/4/1/2 exports respectively), which validates analysis
inputs, not engineering gates. [Analysis §9](device-analysis.md#9-final-validation-and-saved-analyzer-outputs).

| Gate | Status | Device evidence and qualification |
| --- | --- | --- |
| UI stage <=8333 us in >=99% of matched motion frames | PASS retained samples | A1 30/30: minimum 99.96% (R05/3); other A1 rows 100%. R11 4/4: all 100%. |
| Raster stage, same independent budget | PASS retained samples | A1 30/30: minimum 99.02% (R08/1: 202 of 204 matched frames, exceedances 11717 and 8520 us); other A1 rows 100%. R11 4/4: minimum 99.55% (sample 2), sample 3 99.96%, others 100%. Neither stage establishes display presentation. |
| Correctness | PASS where evaluable; R04 UNAVAILABLE | No observed proof failure, stale publication or invalid committed acceptance. R04 each repeat: 16 receipts, 8 queued, 7 queue-policy overflows, 1 safely rejected stale callback, 0 commits/acceptances. Jump cancellation leaves no destination to evaluate; policy overflow is not recorder loss. |
| Warm recognized-admission -> first submission P95 <=16700 us | UNVERIFIED: measurement limit | Tap recognition/drag axis lock/direct command admission cannot consistently be identified from exports. Receipt P95 is informational: R01 25157/25207/25176 us; R02 316856/316940/316887; R05 25135/25152/25238; R10 25151/25145/25150. None is an admission pass or fail. |
| No unexplained >=50000 us stall | UNVERIFIED: measurement limit | Conservative analyzer failures remain visible for R02/R03 and R11 samples 1/3, with unresolved gaps below. Dirty-drag submission loss and missing hold/frame-demand events prevent classification. R04/R09 and R11 samples 2/4 have unavailable absence evidence (open windows/adjacency); passing rows elsewhere apply only to retained windows. |
| Resource trend | FAIL observed RSS breaches; other rows qualified | R06 passes x3 with 308 accepted turns each. R10 has 100 each: fail/pass/pass. R08: fail/fail/unavailable, with 4/3/6 turns. R11 samples 2/3 also fail RSS despite <100 turns; samples 1/4 unavailable. Other A1 resource rows lack 100 turns. |
| R11 manual minimum >=50 accepted turns per sample | PASS 4/4 | Samples 1-4: 63/70/96/57 accepted turns. This minimum is separate from the >=100-turn resource criterion. |
| Real OS lifecycle recovery | PARTIAL | Scripted R09 accepts 1 turn per repeat but is controller simulation. Manual supplement accepts 1 turn before backgrounding, none after return; 13 invalidations/cancellations and 2 safe stale-callback rejections establish observed interruption handling only. User declined redo. |

Stage/correctness/resource matrices and qualifications:
[analysis §6](device-analysis.md#6-device-gate-matrices-and-evidence-qualifications);
[admission §1](device-analysis.md#1-admission-latency--requires-app-change);
[stall recorder limits §2](device-analysis.md#2-stall-candidates--classification-requires-app-change);
[R04/RSS §4](device-analysis.md#4-r04-unavailable-rows-and-r08r10-resource-failures).
All exports retain incomplete trailing timing batches. No Dart event, layout,
resource, frame or motion ring loses samples in these sets; native loss is
reported separately under NC8. Missing dirty-drag submissions still limit
coverage even with zero ring overflow.

Unresolved submission-gap durations (us), not proven physical stalls:

| Run | Repeat 1 | Repeat 2 | Repeat 3 |
| --- | --- | --- | --- |
| A1 R02 | 649721, 308654 | 649704, 308599 | 649699, 308982 |
| A1 R03 | 108317 | 108414 | 108401 |
| R11 sample 1 | 57885 | not applicable | not applicable |
| R11 sample 3 | 99697, 333255 | not applicable | not applicable |

R02/R03 have no matched UI/raster stage or consecutive matched engine interval
>=50000 us; missing motion samples cannot prove deliberate hold, idle or a due
frame. R11 durations come from the private `default-r11/analyzer-output.md`
stall-candidate rows. **Subjective operator evidence:** the user saw no visible
stutter, freeze, frame skipping or input lag during all scripted runs and R11
reading of the four samples. This does not replace measurement. By the user's
2026-10-23 decision, S2 stops instrumentation/rebuilds for all three missing
observation points in [analysis §8](device-analysis.md#8-app-changes-needed--unavailable-conclusions).

RSS outcomes below retain the existing endpoint/projected-OLS <=5% rule;
amounts are bytes and growth percentages use the first positive RSS. These
are real failures of that observational rule, not proof of a leak. Cold-start
or allocator warm-up is a possible explanation, not a reason to remove data.
Surface/picture/image caps remain 3+1 / 16 MiB / 48 MiB; none is breached in
these R08/R10 captures. [Analysis §4](device-analysis.md#4-r04-unavailable-rows-and-r08r10-resource-failures).

| Run | First -> last RSS | Maximum RSS | Endpoint / projected OLS growth | Resource result |
| --- | --- | --- | --- | --- |
| R08/1 | 152190976 -> 180846592 | 180846592 | 18.8287% / 18.0644% | FAIL |
| R08/2 | 156483584 -> 164544512 | 164544512 | 5.1513% / 4.5118% | FAIL |
| R08/3 | 171753472 -> 164249600 | 171753472 | -4.3690% / 0.8597% | UNAVAILABLE (<100 turns) |
| R10/1 | 240025600 -> 268468224 | 277348352 | 11.8498% / 8.5227% | FAIL |
| R10/2 | 275644416 -> 273645568 | 287408128 | -0.7252% / 4.7511% | PASS |
| R10/3 | 288210944 -> 279216128 | 288210944 | -3.1209% / 2.7648% | PASS |

### Cold preparation, queue wait and static fallback

Source: private `local-evidence/s2/default-a1/analyzer-output.md`, each R01-R10
distribution/counter table. Each cell lists repeats 1/2/3; `n:P95` uses us.
`U` means zero samples and unavailable distribution, never a measured zero.
Cold input preparation and whole-section preparation are different intervals.

| A1 run | Cold section n:P95 | Cold input n:P95 |
| --- | --- | --- |
| R01 | 1:119072 / 1:120265 / 1:117763 | U / U / U |
| R02 | 3:4171 / U / U | 4:4353 / 4:761 / 4:701 |
| R03 | 1:120429 / 1:153149 / 1:154943 | 1:426467 / 1:426572 / 1:426602 |
| R04 | 2:1326 / 2:2052 / 2:1989 | 1:387 / 1:407 / 1:403 |
| R05 | 60:3959 / 60:2506 / 61:2647 | 30:4868 / 30:3198 / 29:4265 |
| R06 | 2:120014 / 2:121080 / 2:117895 | 308:12714 / 308:12587 / 308:12478 |
| R07 | 2:1720 / U / U | 3:3361 / 3:3218 / 3:3172 |
| R08 | 1:8783 / 1:18015 / 1:15778 | 4:1506 / 3:978 / 6:1076 |
| R09 | 2:1541 / 2:2143 / 2:1798 | 2:444 / 2:500 / 2:461 |
| R10 | 13:166055 / 13:159375 / 13:162993 | U / U / U |

A1 queue wait has 0 samples in all 30 runs (distribution unavailable).
Static fallback count is 0 in all 30: rate 0.0 where defined, unavailable in
R04's three zero-acceptance runs. This is separate from queue overflow.

### R11 per sample and R09 supplement

Source: private `local-evidence/s2/default-r11/analyzer-output.md`, identified
only by the approved prefixes below; [analysis §6](device-analysis.md#6-device-gate-matrices-and-evidence-qualifications).
All four pass correctness and the manual minimum; warm admission is unverified.
All have zero recorder/native ring loss and zero static fallbacks (rate 0.0).

| Sample | Accepted | UI / raster within budget | Analyzer stalls -> acceptance interpretation | Resource | Cold section n:P95 us | Cold input n:P95 us | Queue n:P95/max us |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 (`6e4ed2a7`) | 63 | 100% / 100% | FAIL, 1 unresolved -> UNVERIFIED | UNAVAILABLE | 3:68556 | 64:20899 | 66:3438062/3460829 |
| 2 (`aac482b2`) | 70 | 100% / 99.55% | UNAVAILABLE -> UNVERIFIED | FAIL, RSS +16.0393% | 3:47154 | 70:10464 | 6:67227/67227 |
| 3 (`a595d98d`) | 96 | 100% / 99.96% | FAIL, 2 unresolved -> UNVERIFIED | FAIL, RSS +29.3733% | 10:54387 | 96:41585 | 65:274891/349625 |
| 4 (`9bfc26bc`) | 57 | 100% / 100% | UNAVAILABLE -> UNVERIFIED | UNAVAILABLE | 4:63273 | 57:52566 | 42:166657/183739 |

Sample 1 additionally records 67 queue-policy rejections, not lost samples.
Manual R09: cold section 2 samples, P95/max 7316 us; cold input 3 samples,
P95/max 8111 us; queue 0 samples (unavailable); static fallback 0, rate 0.0.
Its recorded UI/raster are 100%/100%, correctness passes, latency/stalls are
unverified and resources unavailable. Source: private
`local-evidence/s2/manual-lifecycle/analyzer-output.md`; recovery remains partial.

**Declaration corrected, corroborated:** A1 R01 repeats 1-3 had Limit Frame
Rate off (raw `on` was a selection error); R11 samples 1/3/4 and manual R09 had
both Low Power and Limit Frame Rate off (raw `unknown`). Other A1/A2/B and R11
sample 2 already declare both off. Native Low Power false and near-120 Hz
cadence corroborate, without rewriting raw declarations. Charging/device-warm
unknowns stay unknown. [Analysis §10](device-analysis.md#10-operator-declaration-corrections-2026-10-23)
supersedes the earlier declaration caveats in §§6/9, including the A1/A2 R01
limiter mismatch; it does not isolate observer causality.

## NC8: native evidence

Native data arrived in every acceptance capture: `available=true`, omission
`null`. Inventory reports `maximumFramesPerSecond=120`, native Low Power false,
iOS 27.0.1 and ring capacity 16384. Default A1/A2 use `FlutterMetalLayer` with
no `FLTUseFlutterMetalLayer` key (exported null); B uses `CAMetalLayer` with the
key false. [Analysis §§3,5,6](device-analysis.md#3-a2-display-link-anomalies-and-commit-bins)
and the private per-set analyzer native tables are the sources.

| Mode | Availability, retained sample inventory and losses | Evidence level |
| --- | --- | --- |
| A1 | 30 scripted captures: 108916 layer commits total. R11 samples 1-4: 3560/4108/5392/3248 commits; manual R09: 315. R06 retains 16384 commits per repeat and loses 3249/3292/3199 native observations; other A1 captures lose 0. Contention drops/unmatched callbacks 0 throughout A1. | `layer_commit_cadence`; whole-capture native timestamps, no Dart motion-window mapping. R06 cadence describes a surviving suffix, not loss-free coverage. |
| A2 | 6 captures: 17636 commits and 17642 auxiliary display-link periods. R01 commit counts 5192/5199/5199; R02 682/682/682. Native overflow/contention/unmatched callbacks all 0. | `layer_commit_cadence_per_display_period`; auxiliary link is an observer that can sustain high refresh. |
| B | 2 captures: R01 5139 drawable acquisitions, 5136 positive presentations, 3 zero by stop; R02 681 acquisitions, 679 positive, 2 zero. R01 overflow 1 includes contentionDrops 1 (not two losses); unmatched callbacks 0. R02 all loss counters 0. | `system_drawable_presentation_non_product_path`; system drawable time on the alternate path only. Zeros may be pending/lost callbacks, not proven physically missed frames. |

All Dart rings report zero loss across the five sets; all exports explicitly
retain incomplete trailing engine timing batches. Native loss qualifies
absence claims independently. No A1/A2/B mode establishes **product-path
physical presentation or touch-to-photon latency**. Frame-number matching
establishes engine identity, not scan-out; native and Dart clocks stay separate.
A1 has no auxiliary display periods and cannot supply A2-style period bins.

### A1 commit cadence and A2 observer comparison

Values below are whole-capture layer commits; each cell lists repeats 1/2/3.
Full remaining A1 inventory/cadence is retained in
[analysis §6](device-analysis.md#remaining-a1-native-cadence-retained-layer-commits).

| Run/mode | Commits | Interval P99 us | Maximum interval us | Intervals >=12500 us |
| --- | --- | --- | --- | --- |
| R01 A1 | 5193/5193/5191 | 10086/10105/10181 | 49949/25079/24877 | 4/7/6 |
| R01 A2 | 5192/5199/5199 | 10121/10009/10086 | 28969/20352/22897 | 6/4/5 |
| R02 A1 | 684/682/682 | 10009/9307/8976 | 15196/13589/13270 | 2/1/1 |
| R02 A2 | 682/682/682 | 10443/9019/9505 | 15435/13148/11244 | 1/1/0 |
| R06 A1 (lossy) | 16384/16384/16384 | 18408/17655/18009 | 45876/47852/46604 | 258/259/258 |
| R10 A1 | 6484/6482/6483 | 10114/9947/9913 | 137011/131642/129342 | 23/21/22 |

The private A1/A2 analyzer distribution tables give these per-repeat P95
ranges (us); these are ranges of three P95 values, not pooled percentiles:

| Run | UI A1 / A2 | Raster A1 / A2 | Engine vsync interval A1 / A2 |
| --- | --- | --- | --- |
| R01 | 241-278 / 237-267 | 931-998 / 935-963 | 8407-8410 / 8411-8414 |
| R02 | 282-338 / 276-289 | 746-876 / 722-745 | 8413-8430 / 8408-8440 |

Stage/commit cadence is broadly similar, with repeat variation and no
consistent improvement/regression. Possible observer perturbation remains;
this comparison does not isolate the auxiliary link's causal effect. The
corrected A1 R01 declaration is corroborated (§10), not silently overwritten.

A2 auxiliary period durations round to 8340 us throughout all six raw sample
streams (`targetTimestamp - timestamp`, native seconds converted to us).
The analyzer reports these clipped half-open period bins:

| A2 run/repeat | Periods | 0 commits | 1 commit | >=2 commits | Outside periods |
| --- | --- | --- | --- | --- | --- |
| R01/1 | 5195 | 9 | 5183 | 3 | 3 |
| R01/2 | 5200 | 6 | 5190 | 4 | 1 |
| R01/3 | 5201 | 4 | 5196 | 1 | 1 |
| R02/1 | 682 | 4 | 674 | 4 | 0 |
| R02/2 | 682 | 0 | 682 | 0 | 0 |
| R02/3 | 682 | 1 | 680 | 1 | 0 |
| Total | 17642 | 24 | 17605 | 13 | 5 |

These are commit bins (repeated/new/overwritten proxies), not observed physical
frames. R01/3 retains one 1191.25002 us phase overlap; R02/1 retains 36 numeric
overlaps, maximum 0.0833534 us. Bins clip to the next link start, preserve
holes and count each commit at most once; no anomalous export is discarded.
[Analysis §3](device-analysis.md#3-a2-display-link-anomalies-and-commit-bins).

### B presentation intervals and limits

| B run | Positive-time intervals | P50 / P95 / P99 / max us | >=12500 us | No / some acquisition strictly between presentations |
| --- | --- | --- | --- | --- |
| R01 | 5135 | 8340 / 8340 / 16680 / 33360 | 63 | 8 / 55 |
| R02 | 678 | 8340 / 8340 / 8340 / 8340 | 0 | 0 / 0 |

Of R01's 63 gaps, 4 have endpoint acquisitions <12500 us apart and 59 have
slower acquisition cadence. Eight gaps without an interior acquisition are
not proven idle: the pipeline may already hold a drawable. All five zero-time
acquisitions precede their capture's final positive presentation; R01 includes
one older zero and two tail zeros, R02 two tail zeros. Zero and loss evidence
cannot prove an unpresented physical frame. A definitive idle/deadline-miss
split needs native demand/expected-period and stop/drain evidence; S2 stops
that instrumentation. [Analysis §5](device-analysis.md#5-b-native-presentation-gaps).

B engine raster budget **fails independently**: R01 72.27%, R02 64.15% within
8333 us. Positive B presentation cadence does not override those costs or
describe the product `FlutterMetalLayer` path. This is the first device
iteration with both variants; no App fix/rebuild iteration is taken after
the user's stop decision.

## NC9: S4 decision and conditions

**Conditional GO (有条件通过), decided by the user on 2026-10-23.** Proceed
with the native Flutter reader architecture in S4. The Rows table independently
reviews NC1-NC9: six local passes, mixed device gates, fulfilled native-evidence
reporting, and this explicit decision. Resource failures remain failures;
warm admitted latency/stall classification remain unverified; lifecycle
recovery remains partial. The operator's smoothness observation supports the
decision subjectively and does not replace the missing measurements.

At S4 entry, carry the following items into its plan with owners and evidence
requirements. Their verification criteria are S4 exit items; condition 1
explicitly blocks product release until measured on the device. This report
does not deliver persistence, reading history/outbox, visibility/idle sampling,
NAS/downloads or the product reader UI: those remain outside S2 as specified
in [the PRD](prd.md#out-of-scope).

1. **Recognized-admission instrumentation and warm latency.** Reason: current
   events measure pointer receipt or release settlement inconsistently.
   Record input identity/source and recognized tap/drag/direct admission,
   preserving cold preparation and queue wait separately. **Verify:** on the
   device, warm admitted input -> first motion submission P95 <=16.7 ms before
   product release. The private, gitignored
   `local-evidence/s2/i1-partial-instrumentation.patch` is only a local starting
   point; it is not applied or device-verified evidence.
2. **Dirty-drag submission capture plus hold/frame-demand evidence.** Reason:
   `_tick` clears dirty state before the recorder checks `needsTick`; missing
   submissions and hold/request events leave the recorded gaps unresolved.
   **Verify:** corrected capture observes dirty drag updates and records
   hold/barrier intervals, changed motion, target/request/ticker demand; device
   runs establish **no unexplained >=50 ms stall**, retaining all candidates
   and distinguishing deliberate hold/idle from a late or missing due frame.
3. **Memory investigation, RSS-rule review and loss-free native recording.**
   Reason: R08 reflow and R10 cold-start RSS fail the current 5% rule; R11 also
   has growth, and R06 saturates the native ring. Investigate allocation/growth
   and review the 5% endpoint/projected-OLS rule against device data, keeping
   current failures visible. Enlarge or redesign the native sample ring.
   **Verify:** device captures explain or fix reflow/cold-start growth, document
   the reviewed rule and bounded trend over >=100 alternating turns, preserve
   cap checks, and complete long R06 runs with zero native sample loss.
4. **Real OS background/foreground recovery.** Reason: the manual R09 capture
   verifies interruptions but has no completed accepted turn after return;
   scripted controller simulation cannot close that gap. **Verify:** a real OS
   background/foreground capture includes a completed, proven accepted turn
   after return, with interruption/recovery during motion and cold preparation
   evidenced or explicitly identified as still unverified.
5. **Unsupported-layout handling for mixed books.** Reason: one additional
   personal EPUB was refused; current detection rejects a whole book if any
   section is fixed-layout, vertical or right-to-left. **Verify:** a mixed-layout
   case receives per-section handling or clear user-facing unsupported-layout
   handling with an explanation/action, rather than unexplained whole-book
   refusal. Do not expose that book's identity or content in evidence.
6. **Existing carry-forward items.** Reason: retained preparation, asset,
   lifetime, parser and native synchronization limits remain relevant to the
   product. Carry forward ZIP bounded inflation and a worker isolate before
   opening downloaded books; fixtures out of product assets; FontRegistry
   bounds; HTML parser gaps; deprecated `OSAtomic*`; warm/prepare coalescing.
   **Verify:** bounded ZIP/worker behavior, a fixture-free product asset bundle,
   a bounded font/session policy, parser regression coverage for supported
   cases or explicit unsupported outcomes, a reviewed CI/device synchronization
   decision, and coalesced concurrent warm/prepare with cap/lifetime checks.
   Preserve the S3 dependency for downloaded-book preparation and the detailed
   [existing carry-forward record](#carry-forward-to-later-stages).
7. **Keep the product presentation path on `FlutterMetalLayer`.** Reason: B
   measures the alternate `CAMetalLayer` path and independently fails raster
   budgets. **Verify:** product build/runtime inventory remains on
   `FlutterMetalLayer`; B results stay labeled non-product-path evidence and
   never satisfy product physical-presentation or touch-to-photon claims.

The user stops further S2 instrumentation and does not redo manual R09.
[Analysis §11](device-analysis.md#11-decisions-after-the-first-device-run)
records those decisions. Closing this documentation does not close the above
conditions or change the acceptance thresholds.

## Local validation checkpoints

These are historical sequential gates, not additional device runs. Codegen,
format, analysis and tests passed at each completed phase; the linked log
retains the exact command scope and timeout. Later reviews supersede test
counts without rewriting earlier JSON.

| Checkpoint | Whole-suite result | Evidence |
| --- | --- | --- |
| Baseline / Phase A | 91 passed | [Baseline](evidence/quality-gate-0.json), [corrected A](evidence/quality-gate-A-source-lf.json) |
| Phase B | 347 passed; 256 reader-data tests | [Phase B](local-validation.md#phase-b-evidence--2026-10-22) |
| Phase C | 638 passed, 1 skipped | [Phase C gate](local-validation.md#phase-c-gate-sequential) |
| Phase D implementation -> review | 784 -> 785 passed, 1 skipped | [D JSON](evidence/quality-gate-D.json), [review](local-validation.md#phase-d-review-and-independent-re-run) |
| Phase E parts 1 / 2 / 3a / 3b | 823 / 869 / 918 / 962 passed, each 1 skipped | [Verification chain](local-validation.md#phase-e-execution-and-verification-chain), [3b JSON](evidence/quality-gate-E.json) |
| Phase E independent review | 969 passed, 1 skipped; zero failures | [Final gate](local-validation.md#phase-e-independent-trellis-check-review--2026-10-23) |

## NC3: conservation

Viewport 430x932 logical (content box 334x812 at the defaults), C1 `CssStyleResolver`.
Settings: D = defaults; L = font size 26 + line height 2.0; M = font size 14 +
letter spacing 0.12 em + horizontal margin 48. Every cell passed: page text in
order equals the eligible source text, paragraph maps reproduce text from source,
lines placed once in order, each image/SVG placed once or listed, nothing crosses
the content rectangle. Pages are summed over a fixture's sections.

| Fixture | Sections | D pages | L pages | M pages | Source characters |
| --- | ---: | ---: | ---: | ---: | ---: |
| cfi-structure | 1 | 1 | 1 | 1 | 70 |
| html-fallback | 5 | 5 | 5 | 5 | 29 |
| inert-content | 1 | 1 | 1 | 1 | 19 (SVG placed, math surfaced) |
| opf-variants | 4 | 4 | 4 | 4 | 45 |
| unicode | 1 | 1 | 1 | 1 | 57 |
| styles | 1 | 2 | 4 | 2 | 191 |
| images | 3 | 4 | 5 | 4 | 35 (6 images/SVG) |
| long-content | 3 | 546 | 1530 | 504 | 264,923 |
| chapters | 16 | 16 | 48 | 16 | 5,550 |
| one-page | 1 | 1 | 1 | 1 | 6 |

Four local books at all three settings D/L/M (approved prefixes only, no text;
D pages shown): sample 1 (`6e4ed2a7`) 3 sections / 20 pages / 5,278 characters /
2 images; sample 2 (`aac482b2`) 3 / 36 / 9,622 / 1; sample 3 (`a595d98d`)
33 / 347 / 86,475 / 0; sample 4 (`9bfc26bc`) 21 / 443 / 128,385 / 14
(SVG wrappers). All passed with zero unsupported items. A negative test shows the
check fails when expected text is withheld.

### Style matrix outcomes (resolver and layout merged)

| Area | Outcome |
| --- | --- |
| `p`, `div`, `h1`-`h6`, `blockquote`, `section`, `figure`, `hr` | Supported (UA margins, author margin/padding, backgrounds behind text lines, hairline rule). |
| `ul`/`ol`/`li` | Supported with difference: marker is generated text inside the item (not hanging). `list-style-type` (none, disc, circle, square, decimal, lower/upper alpha and roman; UA disc/circle/square nesting, decimal for `ol`), `ol start` and `li value` honored; markers are synthetic (no CFI or canonical slot). |
| `span`, `b`/`strong`, `i`/`em`, `a`, `br`, `small` | Supported. |
| `sup`/`sub` | Supported with difference: smaller size, no baseline shift. |
| `ruby`/`rt`/`rp` | Supported with difference: annotation text is author source text with its coordinates, set inline at half size; generated parentheses (synthetic) only when no `rp` exists. |
| margin, padding, text-indent (incl. `em`), text-align incl. justify, `display` | Supported. Negative margins are ignored. |
| font-size units and keywords, weight, style, family, line-height, letter-spacing, colors | Supported. Reader overrides follow `useReaderSettings.ts`. |
| `@font-face` (linked sheet and inline `<style>`) | Supported: real archive paths, loaded with `loadFontFromList`; both fixture faces load. Non-sfnt (WOFF) fonts and missing files are recorded, not fatal. |
| `white-space` normal / pre / pre-wrap / pre-line / nowrap | Supported for space and newline handling; `pre` and `nowrap` still wrap at the content width (difference `nowrap-wraps`). |
| `img` (width/height/max-width, taller than page) | Supported; contained to content width and page height; undecodable, missing and remote images become listed markers. |
| SVG wrapper around a full-size raster (guard `contentImage.ts:403`) | Supported; nine guard-refusal cases fall to vector; outer `svg` is the anchor. |
| Vector SVG | Supported through `flutter_svg` for shapes/paths (pixel-tested); `text`, `foreignObject`, filters and external images are not painted: listed as `svg-partial` with a corner badge. |
| Tables | Surfaced-unsupported with text flow: flattened to blocks, marker plus `table` entry. |
| `math`, `video`, `audio`, `canvas`, `object`, `embed`, `iframe` | Surfaced-unsupported: marker plus list entry. |
| Borders, `text-transform`, `::before`/`::after` content | Not rendered (see gaps). |

### Unsupported-layout detection (C1, `engine/support`)

| Cue | Result |
| --- | --- |
| `rendition:layout` pre-paginated (package, itemref property, display-options file) | fixed layout, refused |
| spine `page-progression-direction="rtl"` | refused |
| vertical `writing-mode` on root or any rendered element (vendor aliases included, undisplayed ones ignored) | refused, section named |
| `dir="rtl"` / computed `direction: rtl` on root or body; RTL publication language without explicit direction | refused |
| isolated RTL run inside an LTR section | supported, counted informationally |
| fixtures `unsupported-fixed`, `unsupported-vertical`, `unsupported-rtl` | refused with their reasons; the ten supported fixtures and the four books are supported |

`requireSupported()` throws `UnsupportedLayoutException`; the accepted in-memory
anchor is not touched by detection.

## NC4: anchors

- Round trip: for every page of every supported fixture at all three settings the
  exported anchor (reference midpoint policy, image-element fallback) proves and
  resolves back to the same page with its glyph or image box inside the content
  rectangle (2,580 anchors for `long-content` alone; four books: 20 + 36 + 347 +
  443 anchors, every page).
- Oracle landing: 2,980 WebKit vector CFIs whose resolved start is laid out all
  prove, and the page's source spans contain the node/offset; 1,693 samples are in
  the head or hidden text and are not rendered.
- Interop loop: 2,413 native page-anchor CFIs fed to `npm run resolve`; WebKit and
  Chromium resolve to the native node/offset 4,826/4,826.
- Reflow: the accepted anchor remains provable and visible after font size 22,
  size 22 with line height 2.0, size 14 with line height 1.3 and letter spacing
  0.08, and margins 36/24; `reflow` never rewrites the accepted CFI.
- Injected proof failure: `accept`, `acceptPage` and `reflow` keep the previous
  CFI. No page-one, nearest-paragraph or percentage fallback exists.
- Coverage limitation: `notVisible` and `roundTrip` rejections have no natural
  trigger with whole-line packing; only the injected path exercises rejection.
  Phase D now supplies local turn-target proof tests (inventory below); device
  observations are now reported under NC7; physical presentation stays unverified.

## Fonts

Reader font options map to iOS families (`font_mapping.dart`): system stack to the
platform default; PingFang SC/TC/HK as is; Microsoft YaHei, Heiti SC and Noto Sans
CJK to PingFang SC; SimSun and Noto Serif CJK to Songti SC; KaiTi to Kaiti SC;
`serif` to Times New Roman. The chain is recorded per section
(`PreparedSection.fontChains`); Flutter cannot report which family actually
rendered. The four local books reference fonts missing from their archives
(diagnosed as `stylesheetNotFound:@font-face`, 57 occurrences in three books; the fourth only has 42 ignored `border-radius` declarations) and so use the
mapped families.

## Host timing (indicative, host-only)

The 100,000-code-unit CJK paragraph: 5,556 lines, 199 pages at the defaults;
`Paragraph.layout` median about 5.5-10.6 ms over repeated runs (cold first call
30-60 ms); whole-section preparation (layout, line table, paging) about 25-52 ms.
Font was Flutter's test font Ahem (every glyph a square), so shaping cost is far
below a real CJK font. These numbers say nothing about iPhone cost; the device run
owns that.

## Phase D: motion controller and prepared surfaces

The local core uses reader-local numeric motion and repaint-only Flow
transforms over retained page pictures. Tests cover the frozen admission ruler,
axis lock, thresholds, flick/reversal/rebound, tap zones/easing/settlement,
late neighbor admission, 1+8 FIFO with explicit overflow, accepted-origin
rebase, lifecycle cancellation/resume, stale-generation rejection and exactly
one proven destination per committed input. Reduced motion and static fallback
are explicit outcomes; no real position/history persistence was added.

Prepared surfaces have three presented owners plus one reserve, counting
pending owners; picture and decoded-image caps are 16 MiB and 48 MiB. Lease
and decode tests check disposal, close and late callbacks. A debug work guard
rejects parsing, shaping, decoding, font loading, pagination, canonical
traversal, archive reads and JSON projection in pointer/ticker zones; its 38
tests cover real entry calls and all nine work categories. This is local
correctness/isolation evidence, not a measurement of phone callback cost.

The [port inventory](local-validation.md#ported-reference-inventory) records
all eight reference test families and their native equivalents. Browser
pointer-capture hooks, fixed-layout frame proof, mutable DOM cache invalidation
and product image hit-testing/viewer cases are explicitly deferred or replaced
by native preparation/lifetime tests with reasons in
[deferred cases](local-validation.md#deferred-cases-and-native-substitutions).
They are not silently counted as implemented product features.

The implementation gate in [evidence/quality-gate-D.json](evidence/quality-gate-D.json)
is preserved at 784 passed / 1 skipped. Independent review fixed the real
background/foreground resume bug and added a widget regression; the final
coordinator gate was **785 passed / 1 skipped**, format 196 files / 0 changed,
analyze no issues. The warm/prepare race remains a bounded S4 hardening item
below. [Phase D review](local-validation.md#phase-d-review-and-independent-re-run).

## Phase E: harness, analyzer, guard and packaging

- **Probe and recorder:** the isolated `lib/main_probe.dart` app retains S1
  capture and adds `阅读器可行性探针`, bundled fixtures, top-level Documents
  EPUB inventory by SHA-256, settings/reflow/jumps, scripted R01-R10 and manual
  R11. Scripted moves inject at most one move per actual frame, without catch-up.
  R09 explicitly simulates the controller/session lifecycle; R11 has no scripted
  substitute and requires >=50 accepted turns in one capture per book.
- **Export:** `kind: reader_feasibility`, schema version 1, with nested engine
  timings, reader events, layout costs, resource snapshots and native report.
  `shiori-reader-<BUILD_ID>-<runId>.json` is written to Documents; the bounded
  clipboard summary identifies it. Book/page identities are digests, not text,
  titles, assertion CFIs or user filenames. Correctness joins include capture
  epoch plus input ID, and carry explicit commits, active generation, proof and
  hashed destination. Event loss/missing fields cannot prove a passing absence.
- **Analyzer parity:** twelve app-produced synthetic exports have independently
  recomputed reader/engine aggregates; the unknown-schema fixture is deliberately
  rejected. Double acceptance and cap breach fail their measurement gates with
  aggregate parity intact. The bounded 100-turn fixture passes correctness and
  resource rows; the legacy 100-turn record remains unavailable for missing
  capability/caps. Privacy tests also check fixture prose, filenames and CFIs.
  `--strict` checks aggregate mismatches, not measurement-gate exit status.
- **Native spike:** diagnostic-only install/start/stop/dispose and inventory,
  A1 layer-commit cadence, A2 auxiliary-display-link periods, and B drawable
  callbacks have local Dart/channel tests and pinned-engine source review.
  Hooks are lazy; registration alone neither installs them nor allocates the
  sampling buffer. A1/A2 require exact FlutterMetalLayer; B requires exact
  CAMetalLayer plus explicit false flag. Local Phase E did not compile or run
  Swift; subsequent CI compilation and device hook evidence are reported above.
- **Fixture/privacy guard:** the real repository and 17 guard tests pass. Git's
  tracked plus nonignored-untracked inventory is checked before building,
  including tracked ignored files. Only the asset manifest and the two exact
  hashed Phase B source-edge EPUBs are allowed; new files, drift, invalid
  manifests, traversal/duplicates or symlink payloads fail closed. It does not
  exempt the source-edge directory wholesale.
- **Packaging:** shell syntax passes. The script retains the lockfile/pin and
  arm64/bundle checks, builds `lib/main_probe.dart` once, and packages unchanged
  default and false-flag CAMetal copies. Both are revalidated, ZIP-tested and
  entered in `sha256.txt` and provenance with actual/effective Metal-layer flag.
  The existing workflow upload covers both IPAs. Phase E verified source/syntax;
  the subsequent hosted build succeeded as recorded in the CI/device outcomes.

[Phase E implementation, fields, scenarios and gate](local-validation.md#phase-e--probe-harness-analyzer-native-spike-ci)
contains the measured details. The preserved
[evidence/quality-gate-E.json](evidence/quality-gate-E.json) has seven successful
commands and **962 passed / 1 skipped** before review. The independent review
fixed cross-epoch input joins, unhandled native-stop completion errors, explicit
block bridging and unmatched-callback accounting. Its post-fix gate is **969
passed / 1 skipped**, 253 formatted files / 0 changed, analyze no issues, shell
syntax and fixture guard passing; export fixtures remain unchanged.
[Review and final gate](local-validation.md#phase-e-independent-trellis-check-review--2026-10-23),
[execution chain and retained decisions](local-validation.md#phase-e-execution-and-verification-chain).
Existing ordinary-app and S1 tests remain green; no product route/entry behavior
change or product persistence is claimed.

### Local-only switches and evidence boundaries

The sole final-suite skip is `native_cfi_export_test.dart` without
`SHIORI_NATIVE_CFI_OUT`; setting it enables local native-CFI file generation
for the oracle interop loop. The optional four-book tests depend on private
`build/oracle-local/` vectors and the local source directory; they ran in the
recorded local gates. Neither those vectors nor private books enter CI.
`REGENERATE_READER_EXPORTS=1` deliberately regenerates synthetic analyzer
fixtures; ordinary tests check them without rewriting. This documentation
session does not regenerate either corpus.

The [31-file evidence index](evidence/README.md) preserves each raw JSON and
its SHA-256 relocation manifest. Historical pre-review gates are not edited
to look like later runs; later counts are linked to their validation sections.

## CI/device outcomes and remaining verification limits

- CI verified Swift compilation and single-build/two-IPA packaging, bundle
  checks and provenance. The historical local NC6 row's Swift/IPA caveat is
  superseded by [the CI result](local-validation.md#push-and-ci-build-of-phases-d-f),
  not by a new local test run.
- Device execution, sample-book import/read/export and A1/A2/B hook data are
  evidenced above. Their observed operation does not establish a complete
  ABI/ownership/callback-identity audit or isolate actual observer overhead.
  Signing/update/re-sign retention is not independently quantified here.
- R01-R10 repeat coverage and corrected declarations, four qualifying R11
  minimums, >=100-turn resource rows, failures and omissions are reported in
  NC7. Real OS recovery after return remains partial; actual rendered font
  family and independent CJK visual fidelity are not measured by stage budgets.
- Warm recognized-admission latency and stall classification are unverified
  because of measurement limits; definitive native idle/deadline-miss
  classification is also unavailable. Product physical presentation and
  touch-to-photon remain unverified. NC7-NC9 review and the conditional S4
  decision are final; the S4 verification conditions remain open.

## Carry-forward to later stages

The four Phase A/B review items below are copied from `implement.md`:

- **S3:** `lib/features/reader/data/epub/epub_archive.dart` checks ZIP sizes
  declared in headers; `archive` inflates a whole entry before the length
  check, so a hostile EPUB can briefly allocate past the limit. Add bounded or
  streamed inflation and parse in a worker isolate before opening downloaded
  books.
- **S4:** `assets/reader_fixtures/` is registered in the shared `pubspec.yaml`,
  so product builds also carry ~1.2 MB of synthetic fixtures. Move them behind
  the diagnostic entry point (or out of product assets) before a product build.
- **S4:** `FontRegistry` (`engine/layout/font_registry.dart`) never unloads
  fonts (the engine cannot); each font is capped at 32 MB but the count is
  unbounded across books. Bound it per reading session or restart policy.
- **S4:** known HTML-mode parser gaps (head-level `<template>`, `<noscript>`
  content that closes an open `<p>`, attribute URLs in script-enabled
  `<noscript>` raw text) are listed in `local-validation.md`; add fixtures if
  the NAS library contains such books.

Additional retained review items:

- **S4, low severity (Phase D):** `PreparedReaderSession.warm()` coalesces warm
  calls per direction, but a concurrent controller `prepare()` for the same
  target can briefly hold another lease. The 3+1 cap bounds it; over-cap work
  becomes a static-fallback prepare failure, not a leak. Coalesce warm/prepare
  work during S4 hardening. [Review](local-validation.md#phase-d-review-and-independent-re-run).
- **Native diagnostic follow-up (Phase E, kept by decision):** deprecated
  `OSAtomic*` calls remain; replacing synchronization without a Swift compiler
  was judged riskier. Verify compiler warnings/runtime behavior in CI/device
  before choosing a replacement. This local review did not compile Swift.
- **Device judgement (Phase E, kept by decision):** the 5% RSS rule bounds both
  endpoint growth and projected OLS growth over the captured duration relative
  to positive first RSS. It is observational, not specified numerically by NC7
  and not proof of no per-cycle/indefinite growth. Judge against device data,
  including R10's cold start/warm-up and actual alternating-cycle coverage;
  retain observed failures and do not silently change the gate.

## Known differences and gaps

- `sup`/`sub`: no baseline shift.
- Borders (and `border-radius`) and `text-transform` are not rendered.
- `::before` / `::after` generated content is not rendered.
- Tables are flattened to blocks with a visible marker.
- `white-space: pre`/`nowrap` wrap at the content width.
- List markers are inline generated text, not hanging.
- Block backgrounds are painted behind text lines only (no padding/margin boxes).
- Inline images split their paragraph into text, image block, text.
- SVG `text`, `foreignObject`, filters and external images are not painted.
- Songti SC, Kaiti SC and Heiti SC actual rendering on iOS is unverified; the
  first device exports do not identify the rendered family/fallback chain.
- `Paragraph.getLineBoundary` costs time linear in the paragraph per call (about
  2 ms at 100,000 units on the host); the line table uses `getLineNumberAt` with
  galloping and bisection instead. Whether device cost behaves the same is unknown.
- CJK newline segment-break rules are not applied (newlines collapse to spaces).
- No locale is set on paragraphs (Han glyph variants follow the system).
- Windows WebKit is not the iPhone's Safari; iPhone parsing behaviour is unverified.
- `xml` is held at 7.0.1 because every `flutter_svg` release requires `xml <=7.0.1`.
