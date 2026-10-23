# First S2 iPhone export analysis

Analysis date: 2026-10-23. Branch `ios-build/s2-reader-probe`, HEAD
`862d999`; device build `862d999010fa-gha-7`. This document records evidence
and analyzer results; it makes no GO / NO-GO decision.

Only `default-a1` (30 exports), `default-a2` (6), `default-r11` (4),
`manual-lifecycle` (1), and `cametal-b` (2) are acceptance inputs.
`default-a1-extra-r09` and `default-r11-personal` are excluded. No personal
book identities or device JSON are copied here or into synthetic fixtures.
All gate thresholds remain unchanged. App, Swift, specs, coordinator task
files and journals are outside this change.

## 1. Admission latency — requires App change

Source evidence: `turn_controller_pointer.dart` emits `inputReceived` at
pointer down and `pointerAdmitted` immediately after accepting that pointer,
before any movement or release. It freezes gesture tracking, not the PRD's
recognized turn input. `_pointerMove` detects dragging after the 10 px axis
lock but emits no timing event for that transition. `_pointerUp` recognizes
a tap at release and posts `_run`; `turn_controller_work.dart` emits
`admitted` inside `_run`. For a drag, `_run` starts release settlement, after
drag motion has already been submitted. `turnPage` emits `inputReceived`
when called and later `admitted` in `_run`, but exports have no input-source
field to separate those calls from pointer turns.

`reader_probe_recorder.dart` records `firstMotionSubmission` on the first
same-frame post-frame motion callback for an input identity, using recorder
monotonic time and the engine frame number. This is a submission proxy, not
scan-out or touch-to-photon time.

The exported fields cannot consistently identify recognized admission for
taps and drags. In each R02 repeat, all three recorded `admitted` events
occur after that input's first submission. R03 has the same ordering for its
one turn. Using the earliest of `pointerAdmitted` and `admitted` reproduces
pointer receipt; choosing the later event creates negative drag latency.
Neither implements NC7 or parent native-reader-contracts section 4.

Verified receipt-to-first-submission P95 (microseconds, repeats 1/2/3):

| A1 scenario | Receipt P95, informational |
| --- | --- |
| R01 | 25157 / 25207 / 25176 |
| R02 | 316856 / 316940 / 316887 |
| R05 | 25135 / 25152 / 25238 |
| R10 | 25151 / 25145 / 25150 |

The scenario runner presses on one frame and releases on the next; slow
drags move only after axis lock, and preparation can further delay motion.
These receipt numbers cannot establish a 16700 us admission-gate failure
or pass. The analyzer must retain aggregate parity with the App's legacy
receipt aggregate, label it informational, and mark warm recognized
admission latency unavailable.

Required App instrumentation: emit one input-identity/epoch-scoped
`turnInputAdmitted` event at tap recognition on release, at the first
horizontal-lock transition for a drag, and at direct turn command admission.
Record input source and preserve separate queue promotion/wait and cold
preparation evidence. Keep pointer receipt and first submission unchanged.
Do not infer these missing timestamps offline. Item stopped at that boundary.

## 2. Stall candidates — classification requires App change

Each R02 repeat has two >=50000 us submission gaps within a recorded
first-submission/settle window; each R03 repeat has one. None has a >=50000 us
matched UI/raster stage or consecutive matched engine interval. All six
exports have zero ring overflow. Counts below are individual candidate
observations, with no overlapping engine-interval observations in these runs.

| Scenario / repeat | Submission gaps (us) | (a) recorded deliberate hold | (b) proven idle/no request | (c) proven late/missing due frame | Unresolved |
| --- | --- | --- | --- | --- | --- |
| R02 / 1 | 649721, 308654 | 0 | 0 | 0 | 2 |
| R02 / 2 | 649704, 308599 | 0 | 0 | 0 | 2 |
| R02 / 3 | 649699, 308982 | 0 | 0 | 0 | 2 |
| R03 / 1 | 108317 | 0 | 0 | 0 | 1 |
| R03 / 2 | 108414 | 0 | 0 | 0 | 1 |
| R03 / 3 | 108401 | 0 | 0 | 0 | 1 |

R02 input 1 spans a slow drag; input 3 spans reversal and another recorded
preparation miss just before the gap ends. Gap endpoint offsets differ
substantially, so equal endpoints cannot establish stationary content.
R03 is scripted to hold preparation through 30 moves plus 180 ms, then hold
the finger for another 160 ms after releasing preparation. Its observed gap
starts after catch-up, not at the preparation barrier; the final catch-up
offset is approximately -217.85 and the next recorded offset -217.90.
Script intent alone does not prove a recorded hold interval.

Recorder limitation: `turn_controller_work.dart::_tick` clears pointer
`dirty` before `_write`. `prepared_reader.dart::_move` records a sample
only if `controller.needsTick` is still true; once catch-up finishes,
ordinary dirty drag updates can change the rendered offset while this
condition is false. A missing motion sample therefore is not evidence of
no frame or no motion. `ProbeTurnSession.hold/release` have no raw timing
events; pointer move/release, target offset, ticker demand and requests are
also absent from exports. No candidate can safely be reassigned to (a), (b)
or (c) using the recorded fields. All remain unresolved and the conservative
stall rows remain fail. This does not prove physical stalls.

Analyzer change: expose every candidate with source, duration, endpoints
and input identity where available, plus separate class counts. Recorded
>=50000 us execution stages are class (c); ambiguous intervals/gaps remain
unresolved. Threshold remains 50000 us. No script-ID-based exemption.

Required App change: record hold/barrier enter/release intervals and pointer
axis-lock/move/release events with input identity; record whether motion
changed, whether a frame was requested and whether a ticker was settling or
catching up. Fix submission capture so dirty drag updates are observed even
when `needsTick` becomes false during the tick. Item stopped at that boundary.

## 3. A2 display-link anomalies and commit bins

The R01 repeat 3 overlap is 1191.25002 us; R02 repeat 1 has 36 overlaps,
maximum 0.0833534 us. These are positive finite periods in sorted streams,
not malformed records. The old analyzer rejects any positive overlap
(including epsilon overlaps); it must not discard these exports.

The analyzer now records overlap count, maximum and each magnitude,
separating <=1 us numerical overlaps from larger phase overlaps for
reporting only. Bin rule: `[timestamp, min(targetTimestamp, next timestamp))`,
with the final period ending at its target. A boundary tie belongs to the
next period. Holes between target and next start are not filled; commits
there remain outside. Every commit is counted at most once. Per-kind
unsorted timestamps, non-increasing link starts, negative/non-numeric times
and non-positive periods still reject input. No threshold is relaxed.

| A2 scenario / repeat | Periods | 0 | 1 | >=2 commits | Outside | Overlaps / max us |
| --- | --- | --- | --- | --- | --- | --- |
| R01 / 1 | 5195 | 9 | 5183 | 3 | 3 | 0 / 0 |
| R01 / 2 | 5200 | 6 | 5190 | 4 | 1 | 0 / 0 |
| R01 / 3 | 5201 | 4 | 5196 | 1 | 1 | 1 / 1191.25002 |
| R02 / 1 | 682 | 4 | 674 | 4 | 0 | 36 / 0.0833534 |
| R02 / 2 | 682 | 0 | 682 | 0 | 0 | 0 / 0 |
| R02 / 3 | 682 | 1 | 680 | 1 | 0 | 0 / 0 |

Default-path layer-commit cadence comparison (microseconds). These measure
whole-capture commits, without linking native time to Dart motion windows.

| Scenario / repeat | A1 commits | A1 P99 / max / >=12500 | A2 commits | A2 P99 / max / >=12500 |
| --- | --- | --- | --- | --- |
| R01 / 1 | 5193 | 10086 / 49949 / 4 | 5192 | 10121 / 28969 / 6 |
| R01 / 2 | 5193 | 10105 / 25079 / 7 | 5199 | 10009 / 20352 / 4 |
| R01 / 3 | 5191 | 10181 / 24877 / 6 | 5199 | 10086 / 22897 / 5 |
| R02 / 1 | 684 | 10009 / 15196 / 2 | 682 | 10443 / 15435 / 1 |
| R02 / 2 | 682 | 9307 / 13589 / 1 | 682 | 9019 / 13148 / 1 |
| R02 / 3 | 682 | 8976 / 13270 / 1 | 682 | 9505 / 11244 / 0 |

A1 and A2 are broadly similar at this evidence level, with variation
between repeats and no consistent improvement or regression. A2's auxiliary
display link is an observer; these comparisons do not isolate its causal
effect or prove presentation cadence. A1 has no display periods to bin.

## 4. R04 unavailable rows and R08/R10 resource failures

No analyzer gate fix is justified for these rows. R04 in every repeat
records 16 receipts, one pointer admission/current turn, eight queued
intents and seven input-queue overflows. These are queue policy events, not
lost recorder samples: all ring-loss counters are zero. The jump invalidates
the active generation and closes the queue; one stale callback is rejected
safely. There are zero commits, acceptances and proof failures. Correctness
is unavailable because no committed destination can be evaluated, not
because seven queue overflows are correctness failures. The first submission
has no `settleEnd`; the open window prevents a passing stall-absence claim.
Keep correctness/stalls unavailable; do not fabricate settlement at a jump
or count safe rejection as a stale publication.

Resource failures follow the existing rule: observed cap/RSS breaches fail
even when fewer than 100 turns were accepted. Lack of 100 turns prevents a
pass, but cannot erase observed growth. RSS amounts below are raw bytes;
OLS growth is slope times observed duration divided by first RSS.

| A1 scenario / repeat | Accepted | First RSS | Last RSS | Max RSS | Endpoint growth | Projected OLS growth | Resource row |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R08 / 1 | 4 | 152190976 | 180846592 | 180846592 | 18.8287% | 18.0644% | fail |
| R08 / 2 | 3 | 156483584 | 164544512 | 164544512 | 5.1513% | 4.5118% | fail |
| R08 / 3 | 6 | 171753472 | 164249600 | 171753472 | -4.3690% | 0.8597% | unavailable (<100 turns) |
| R10 / 1 | 100 | 240025600 | 268468224 | 277348352 | 11.8498% | 8.5227% | fail |
| R10 / 2 | 100 | 275644416 | 273645568 | 287408128 | -0.7252% | 4.7511% | pass |
| R10 / 3 | 100 | 288210944 | 279216128 | 288210944 | -3.1209% | 2.7648% | pass |

All six runs remain within surface/picture/image caps (3+1 surfaces, 16 MiB
picture cache, 48 MiB image cache). Maximum live surfaces is 1 and image
bytes 0. R08 picture maxima are 1848/2192/2192 bytes. R10 picture maxima
are 1064 bytes each. Thus RSS, not a retained-surface cap, causes the fails.
R08 performs `largeText()` reflow inside the capture. R10 begins with a cold
jump and includes cold jumps after its 100 alternating turns; its first
repeat has a maximum paragraph cost of 46823 us versus 6278/6166 us later.
This is compatible with first-run preparation/allocator warm-up, but the
exports do not attribute RSS allocations or prove a leak. Do not trim the
capture, remove initial samples or move the 5% baseline. The actual bounded
observation fails for R10/1; a different experiment requires an App decision.

## 5. B native presentation gaps

Only native acquisition (`timestamp`) and drawable `presentedTime` are used.
The Swift hook records an acquisition immediately after `nextDrawable`,
then updates that sample in the presented callback. Native seconds are never
mapped onto Dart input/motion windows. B is the alternate CAMetalLayer build,
not default-path presentation evidence.

| B metric | R01 / 1 | R02 / 1 |
| --- | --- | --- |
| Drawable acquisitions | 5139 | 681 |
| Positive presentations / intervals | 5136 / 5135 | 679 / 678 |
| Interval P99 / max (us) | 16680 / 33360 | 8340 / 8340 |
| Intervals >=12500 us | 63 | 0 |
| No acquisition strictly between presentations | 8 | 0 |
| Acquisition(s) strictly between presentations | 55 | 0 |
| Endpoint acquisitions <12500 us apart, presentation gap >=12500 us | 4 | 0 |
| Endpoint acquisitions >=12500 us apart | 59 | 0 |
| No observed presentation by stop | 3 | 2 |
| Of those, acquisition precedes final positive presentation | 3 | 2 |
| Zero acquired >=12500 us before final acquisition | 1 | 0 |
| Native overflow / contention subset / unmatched callbacks | 1 / 1 / 0 | 0 / 0 / 0 |

The first two gap classes answer the literal acquisition-between-presentations
question: 8 without / 55 with. They do **not** justify an unconditional
idle / real-miss split. B is pipelined: R01 acquisition-to-presentation
delay ranges from 12089 to 25399 us (median approximately 16806 us). A
drawable acquired before the previous presentation can still be pending
through a gap with no new acquisition. Six of the eight no-interior-
acquisition gaps have slower endpoint acquisition cadence; two have timely
endpoint acquisitions. Conversely 53 of 55 gaps with acquisition activity
also have slower endpoint acquisition cadence.

The four intervals with <12500 us endpoint acquisition separation but
>=12500 us presentation separation demonstrate presentation pacing gaps
despite timely relative acquisition cadence. The other 59 also have
acquisition gaps; none is proven idle without render-demand/deadline
evidence. The one contention loss qualifies all absence claims in R01.
Zeros are explicitly retained: R01 has one zero acquired 31.592 seconds
before its final acquisition and two at the tail; R02 has two at the tail
(8491 and 0 us before its final acquisition). All five acquisitions precede
their run's final positive presentation because of the pipeline. An older
zero can be a lost callback and tail zeros can be pending when capture
stops. Neither proves an unpresented physical frame. R02 has no positive-
interval gap.

Analyzer change: report both acquisition-activity bins and endpoint-cadence
classes, every gap, acquisition-to-presentation distribution, internal/tail
zeros and loss qualification. No Dart clock comparison, guessed native
epoch, dropped drawable or gate change. A definitive binary idle/real-
deadline-miss classification needs an App change: record native frame
demand/expected display period per acquired drawable and capture stop/drain
coverage, with loss-free callbacks. Stop that unsupported part of item 5
here; existing raw samples cannot supply those missing facts.

## 6. Device gate matrices and evidence qualifications

P = pass, F = fail, U = unavailable. These are raw analyzer rows within
recorded scope, not acceptance decisions. UI/raster thresholds remain
>=99% of matched motion frames <=8333 us; warm recognized admission remains
P95 <=16700 us; stall threshold remains 50000 us. Stall class counts
are a/b/c/unresolved as defined in item 2.

| A1 scenario / repeat | UI | Raster | Warm admitted | Stalls (a/b/c/unresolved) | Correctness | Resource | Accepted |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R01 / 1 | P | P | U | P (0/0/0/0) | P | U | 80 |
| R01 / 2 | P | P | U | P (0/0/0/0) | P | U | 80 |
| R01 / 3 | P | P | U | P (0/0/0/0) | P | U | 80 |
| R02 / 1 | P | P | U | F (0/0/0/2) | P | U | 3 |
| R02 / 2 | P | P | U | F (0/0/0/2) | P | U | 3 |
| R02 / 3 | P | P | U | F (0/0/0/2) | P | U | 3 |
| R03 / 1 | P | P | U | F (0/0/0/1) | P | U | 1 |
| R03 / 2 | P | P | U | F (0/0/0/1) | P | U | 1 |
| R03 / 3 | P | P | U | F (0/0/0/1) | P | U | 1 |
| R04 / 1 | P | P | U | U (0/0/0/0) | U | U | 0 |
| R04 / 2 | P | P | U | U (0/0/0/0) | U | U | 0 |
| R04 / 3 | P | P | U | U (0/0/0/0) | U | U | 0 |
| R05 / 1 | P | P | U | P (0/0/0/0) | P | U | 90 |
| R05 / 2 | P | P | U | P (0/0/0/0) | P | U | 90 |
| R05 / 3 | P | P | U | P (0/0/0/0) | P | U | 88 |
| R06 / 1 | P | P | U | P (0/0/0/0) | P | P | 308 |
| R06 / 2 | P | P | U | P (0/0/0/0) | P | P | 308 |
| R06 / 3 | P | P | U | P (0/0/0/0) | P | P | 308 |
| R07 / 1 | P | P | U | P (0/0/0/0) | P | U | 3 |
| R07 / 2 | P | P | U | P (0/0/0/0) | P | U | 3 |
| R07 / 3 | P | P | U | P (0/0/0/0) | P | U | 3 |
| R08 / 1 | P | P | U | P (0/0/0/0) | P | F | 4 |
| R08 / 2 | P | P | U | P (0/0/0/0) | P | F | 3 |
| R08 / 3 | P | P | U | P (0/0/0/0) | P | U | 6 |
| R09 / 1 | P | P | U | U (0/0/0/0) | P | U | 1 |
| R09 / 2 | P | P | U | U (0/0/0/0) | P | U | 1 |
| R09 / 3 | P | P | U | U (0/0/0/0) | P | U | 1 |
| R10 / 1 | P | P | U | P (0/0/0/0) | P | F | 100 |
| R10 / 2 | P | P | U | P (0/0/0/0) | P | P | 100 |
| R10 / 3 | P | P | U | P (0/0/0/0) | P | P | 100 |

All A1 raster rows are 100% within stage budget; UI is 100% except R05/3
at 99.96%. These rows cover retained matched samples; the drag-submission
omission in item 2 limits coverage. R09 includes interruptions with open
motion windows, so stall absence is unavailable despite one accepted turn
per repeat. No correctness failure or proof failure is observed. All A1
resource U rows lack 100 accepted turns; observed RSS breaches still fail.

**Declared limiters:** A1 R01 repeats 1-3 say Low Power Mode off but Limit
Frame Rate on. Their NC7 limiter-off prerequisite is not met; do not replace
this declaration with a guess based on measured cadence. Other A1 runs and
all A2/B runs declare both off. R11 sample 2 declares both off; samples 1,
3 and 4, and the manual R09 supplement, declare both unknown. Native
inventory is a separate source and does not prove the user switch was off.
The analyzer now prints the original declarations.

| R11 sample (approved digest prefix only) | Accepted / manual minimum | UI / raster | Warm admitted | Stalls (unresolved) | Correctness | Resource |
| --- | --- | --- | --- | --- | --- | --- |
| sample 1 (`6e4ed2a7`) | 63 / true | P / P | U | F (1) | P | U |
| sample 2 (`aac482b2`) | 70 / true | P / P | U | U (0) | P | F |
| sample 3 (`a595d98d`) | 96 / true | P / P | U | F (2) | P | F |
| sample 4 (`9bfc26bc`) | 57 / true | P / P | U | U (0) | P | U |

The R11 minimum is 50 manual turns, not the independent >=100-turn
resource gate. All four meet the manual minimum and have zero recorder
loss; sample 2 RSS grows 16.0393% and sample 3 29.3733%, so their resource
rows fail despite <100 turns. Raster fractions are 99.55% for sample 2
and 99.96% for sample 3; all other R11 stage rows are 100%. Queue overflow
in sample 1 is explicit (67 policy rejections), not ring loss. R11 U
stall rows reflect incomplete windows/adjacency, not proven stall absence.

| Supplement | Accepted | UI / raster | Warm admitted | Stalls | Correctness | Resource | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R09 manual OS lifecycle | 1 | P / P | U | U | P | U | partial |

The manual supplement has three receipts/first submissions, one settle/
commit/acceptance, 13 generation-invalidations/cancellations and two safe
stale-callback rejections, with no ring loss or proof/stale-publication
failure. The sole accepted turn precedes backgrounding; subsequent turns
are interrupted, with no completed accepted turn after return. This proves
observed interruption handling only. It does not complete recovery/continued-
reading acceptance. The user declined a redo; no extra R09 or personal
export is substituted.

### Remaining A1 native cadence (retained layer commits)

The R01/R02 A1 comparison table is in item 3; A2 bins and the B native table
are in items 3 and 5. The remaining A1 scenarios are below. Each cell lists
repeats 1 / 2 / 3. Native time is whole-capture time, not Dart motion time.
No row establishes physical presentation or touch-to-photon latency.

| A1 scenario | Commits | Interval P99 us | Maximum interval us | Intervals >=12500 us | Native loss |
| --- | --- | --- | --- | --- | --- |
| R03 | 295 / 290 / 290 | 12620 / 25238 / 25070 | 18417 / 26255 / 25929 | 3 / 6 / 6 | 0 / 0 / 0 |
| R04 | 254 / 254 / 254 | 9796 / 10783 / 10406 | 12868 / 12697 / 13591 | 1 / 1 / 1 | 0 / 0 / 0 |
| R05 | 5876 / 5875 / 5870 | 10208 / 10202 / 10343 | 22972 / 22593 / 46790 | 30 / 28 / 35 | 0 / 0 / 0 |
| R06 | 16384 / 16384 / 16384 | 18408 / 17655 / 18009 | 45876 / 47852 / 46604 | 258 / 259 / 258 | 3249 / 3292 / 3199 |
| R07 | 343 / 342 / 342 | 9986 / 9309 / 9749 | 13893 / 13475 / 12002 | 1 / 1 / 0 | 0 / 0 / 0 |
| R08 | 530 / 531 / 530 | 11473 / 10971 / 9821 | 26752 / 23697 / 21568 | 3 / 4 / 1 | 0 / 0 / 0 |
| R09 | 272 / 271 / 271 | 10436 / 9285 / 9327 | 11645 / 13349 / 12928 | 0 / 1 / 1 | 0 / 0 / 0 |
| R10 | 6484 / 6482 / 6483 | 10114 / 9947 / 9913 | 137011 / 131642 / 129342 | 23 / 21 / 22 | 0 / 0 / 0 |

R06 reaches the 16384-entry native ring cap. Lost native observations are
retained as counters; cadence describes the surviving suffix only. No Dart
event/layout/resource/frame/motion ring loses samples in any of the five
device sets. Native loss occurs only in A1 R06 (above) and B R01 (one
contention loss, already included in overflow). Every export declares
incomplete trailing timing batches; the analyzer preserves this omission.
B's engine raster budget independently fails: 72.27% within budget for R01
and 64.15% for R02. Positive native presentation cadence does not override
these stage costs, and neither B stage nor presentation data describes the
default FlutterMetalLayer path.

## 7. Analyzer changes and synthetic verification

- `reader_export_analysis.dart`: recognized admission row unavailable with
  explicit recorder reason; unchanged 16700 us threshold. Legacy receipt
  aggregate remains independently recomputed for strict App parity.
- `reader_engine_analysis.dart`: exposes every stall candidate and a/b/c/
  unresolved counts; >=50000 us execution stages are proven late, ambiguous
  intervals/gaps remain failed, with no automatic R02/R03 exemption.
- `reader_display_periods.dart` and `reader_native_resources.dart`:
  deterministic clipped half-open bins, complete overlap anomaly reporting
  and malformed/unsorted stream rejection. Linear commit binning.
- `reader_drawable_gaps.dart`: native acquisition/activity and endpoint
  cadence classes, per-gap evidence, zero/pipeline/loss qualifications.
- `reader_export_report.dart`: clearly informational receipt distribution,
  original capture declarations, stall candidates/classes and native B rows.
- R04/R08/R10 rules remain unchanged; tests pin their correct behavior.

Seven new synthetic fixtures use the documented regeneration path in
`test/fixtures/reader/exports/README.md`. The new helper extends the existing
generator and uses production reducers/record serialization, never device
JSON or analyzer output. The existing helper is unchanged. Parity now covers
19 exports, including the existing unsupported-schema fixture. The privacy
test covers all 19 synthetic identities and excludes source prose.

Regression names in `reader_device_analysis_test.dart`:

- `recognized admission unavailable when release follows first motion`
- `R03 script intent cannot explain an unrecorded hold or idle`
- `recorded long stage proves a late execution frame at 50000 us`
- `A2 phase shift and epsilon overlap retain bins and all anomalies`
- `A2 clipped boundary assigns a commit once and preserves holes`
- `native unsorted negative nonnumeric and nonpositive periods reject`
- `queue overflow cancellation proves neither a commit nor settlement`
- `cold RSS growth remains failed and is never trimmed as warmup`
- `B gap classes preserve pending pipeline and zero presentations`

Existing tests now distinguish receipt parity from admission availability,
and accept/report A2 overlaps rather than refusing them. The fixed stage,
stall, resource and turn-count thresholds retain their existing boundary
coverage. A2 phase/epsilon fixtures reproduce App aggregates exactly.

## 8. App changes needed / unavailable conclusions

1. Item 1: record recognized turn-input admission for tap release, drag
   axis lock and direct commands, preserving identity/source/queue/cold data.
2. Item 2: capture dirty drag submissions correctly; record hold/barrier
   intervals and render demand/request/target state. Current gaps cannot be
   proved deliberate, idle or due-late from missing motion samples.
3. Item 5: a definitive idle versus missed-presentation-deadline split
   needs native expected-period/render-demand and stop/drain coverage,
   plus loss-free recording. Existing native activity/cadence classes are
   still usable at their stated evidence level.

No App/Swift changes were made. Rebuild, limiter declarations, possible
future reruns, and acceptance decisions remain with the coordinator/user.
There is no reclassification of an unresolved case to make a row pass.

## 9. Final validation and saved analyzer outputs

All five sets were rerun with the final pure Dart CLI using `--strict`.
Each command used only sorted JSON paths directly under the named set and
a 180-second subprocess timeout. Stdout overwrote that set's private,
gitignored `analyzer-output.md`; raw exports were never changed.

| Input set | Exports | Aggregate matches | Exit | Saved output |
| --- | --- | --- | --- | --- |
| default-a1 | 30 | 30 | 0 | `local-evidence/s2/default-a1/analyzer-output.md` |
| default-a2 | 6 | 6 | 0 | `local-evidence/s2/default-a2/analyzer-output.md` |
| default-r11 | 4 | 4 | 0 | `local-evidence/s2/default-r11/analyzer-output.md` |
| manual-lifecycle | 1 | 1 | 0 | `local-evidence/s2/manual-lifecycle/analyzer-output.md` |
| cametal-b | 2 | 2 | 0 | `local-evidence/s2/cametal-b/analyzer-output.md` |

Exit 0 establishes input validity/aggregate parity only, not passing gates.
A2 no longer exits 65 for phase shifts or floating-point overlap.
R01 A1/A2 observer comparison is additionally limited by A1 R01's declared
frame limiter being on while A2 declares it off; do not attribute differences
solely to the A2 observer.

| Required local check | Timeout | Exit / result |
| --- | --- | --- |
| `dart format --set-exit-if-changed lib test tool/reader tool/diag tool/ci` | 120 s | 0; 257 files, 0 changed |
| `flutter analyze` | 600 s | 0; no issues |
| Whole `flutter test --reporter expanded` suite | 900 s | 0; 985 passed, 1 skipped |
| Documented synthetic regeneration parity test | 300 s | 0; 19 passed |
| `git diff --check` | bounded command | 0 |

The initial focused test run caught the privacy test's obsolete 12-fixture
count; it now verifies all 19 and the whole suite passes. The format check
initially formatted two final tool files; its clean rerun is the result
above. No generated App files, assets, device JSON, Git settings, branch or
commit were changed. New work is limited to the allowed analyzer/tests/
synthetic fixtures and this document. The four coordinator-owned files
already modified at session entry were left untouched. No commit, push,
stash, archive, journal update or feasibility-report edit was performed.

## 10. Operator declaration corrections (2026-10-23)

The raw exports are unchanged; these corrections are the operator's
statements in chat, recorded with the objective evidence that supports them.
Report rows that depend on limiter-off declarations must cite this section
and label the runs "declaration corrected, corroborated" rather than treating
the raw declaration as passing.

| Exports | Raw declaration | Operator correction | Corroborating evidence |
| --- | --- | --- | --- |
| A1 R01 repeats 1-3 | Limit Frame Rate `on`, Low Power `off` | Limit Frame Rate was off; `on` was selected by mistake | Layer-commit interval median 8,342-8,344 us, about 5,010-5,036 intervals near 120 Hz and 0 near 60 Hz per repeat; native `maximumFramesPerSecond` 120; A2 R01 (declared off) shows the same cadence |
| R11 samples 1, 3, 4 (`6e4ed2a7`, `a595d98d`, `9bfc26bc`) | Limit Frame Rate `unknown`, Low Power `unknown` | Both off | Native `lowPowerMode` false; 2,925-5,087 commit intervals near 120 Hz and 2-5 near 60 Hz per book; `maximumFramesPerSecond` 120 |
| R09 manual supplement | Limit Frame Rate `unknown`, Low Power `unknown` | Both off | Native `lowPowerMode` false; 285 commit intervals near 120 Hz, 0 near 60 Hz |

Charging and device-warm declarations for those exports remain as recorded
(`unknown` where not stated); they are not limiter gates.
