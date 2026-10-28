# Reader admission and demand evidence (S4a A0)

## 1. Scope / Trigger

Applies to reader motion/surface sinks, `ReaderProbeRecorder`, native sampling
and the independent reader-export analyzer. The record schema remains v1;
new evidence is explicitly capability-versioned. This is implemented capture
infrastructure, not an accepted iPhone measurement or fixed-layout renderer.
Keep the privacy and clock boundaries in [Diagnostics](./diagnostics.md).

## 2. Signatures

- `TurnTimingEvent` adds `inputRecognized`, `recognizedAdmission`, `dragDirty`,
  `dragClean`, `holdStart/End`, `frameDemandStart/End`,
  `preparationBarrierStart/End`, `visualMutation`, and `noMotionRequired`.
- `TurnFrameSink.submitted({frameNumber, schedulerUs, rawSchedulerUs,
  generation, offset, input})` records actual same-frame submission identity.
- `ReaderDemandAnalysis(events, metadata, stoppedUs)` in
  `tool/diag/reader_demand_analysis.dart` replays raw events without app imports.
- `PresentationReport.lossAccountingVersion` is an optional integer; present
  version 1 identifies the new native loss-accounting contract.

## 3. Contracts

### Capture and submission

`engine.metadata.readerDemandVersion: 1` and the existing integer
`captureEpoch` declare demand evidence. New timing events use the existing
sequence, recorder-monotonic time, generation, active generation, queue depth,
epoch and input identity fields. Pointer admission is not gesture recognition.
Recognition, actual admission, queueing and preparation remain separate events.

`motionSubmission` is recorded for actual visual mutations, including a final
settled or zero-offset reset. `firstMotionSubmission` remains available for
legacy reduction. `PreparedReader` schedules control-task mutations into a
frame and reads the engine frame ID post-frame. It coalesces writes before
paint and guards owner, generation, capture epoch, mounted state and mutation
identity. Same-value ticks must not manufacture visual work. A global reset may
have no input identity; it still satisfies the final coalesced visible state.

No parsing, layout, font loading, resource decoding or storage is introduced
into input/ticker callbacks. Timing and source evidence remain reader-owned
interfaces; the reader does not import diagnostic implementations.

### Independent analysis

The warm gate uses recognized admission to first actual submission, for warm,
unqueued inputs with a complete valid timeline. A preparation miss disqualifies
the input from warm latency. Receipt-to-submission legacy aggregates remain
readable but cannot substitute for missing recognized-admission capability.
Keep existing queue/preparation, stage cost and cadence reports separate.

Dirty drag, visual mutation and frame demand are independent outstanding work.
An intentional hold does not cancel any of them. Pending intervals are measured
through capture stop; an observed interval of at least 50,000 us is a failure
candidate even if the capture is otherwise incomplete. An unmatched preparation
barrier, open demand, invalid transition, missing recognized input/submission
chain or relevant ring loss prevents a passing modern absence claim. The
capability marker alone is not evidence that those events were captured.

Join by capture epoch and input identity, never an input number alone. Event
times must be monotonic and no later than stop. Modern stall output preserves
long execution-stage failures and adds explicit demand candidates; it does not
use inferred timestamp offsets or script intentions to excuse them. The existing
8.333 ms stage, 16.7 ms warm-submission and RSS rules are unchanged.

### Native loss

The ring stays bounded at 16,384 samples. `overflow` includes evictions and
contention; `contentionDrops` is a subset. `unmatchedCallbacks` remains separate.
The analyzer's native-loss gate fails on observed overflow/unmatched callbacks;
zero can pass only with an available stream and `lossAccountingVersion == 1`.
Old captures without the capability remain unavailable for this stronger claim.

`Runner-Bridging-Header.h` provides the Clang atomic counter operations used by
Swift. A ticket carries capture epoch and active state; a late failed try-lock
cannot charge a later capture. Stop disables the counter before exporting its
snapshot. Stable storage avoids concurrent Swift `inout` access. The product
FlutterMetalLayer and A1/A2/B evidence distinctions stay unchanged. Windows
source/adapter tests do not establish Swift compilation, ABI or device races;
those require the hosted and physical-device gates.

## 4. Validation & Error Matrix

| Condition | Outcome |
| --- | --- |
| Missing demand capability | New warm-admission evidence unavailable; legacy data remains readable |
| Nonmonotonic or post-stop event time | Invalid input; no successful timeline |
| Pending/dirty interval reaches 50 ms | Recorded failure candidate, including at stop |
| Capability present but required chain absent | Modern absence verdict unavailable |
| Hold overlaps pending work | Hold retained; pending work is still evaluated |
| Event/frame/motion ring loss | No passing absence claim from retained samples alone |
| Unknown native loss capability version | Payload rejected |
| Native loss observed / capability absent | Failed / unavailable respectively |
| Late owner/generation/epoch callback | Suppressed; cannot submit into the next capture |

## 5. Good/Base/Bad Cases

Good: a held pointer is recognized, admitted after queue/preparation rules,
mutates the view and has a guarded post-frame submission. Base: an old export
still reproduces its legacy aggregates with new evidence unavailable. Bad:
marking a capture stall-free because its demand events were dropped, or treating
an intentional hold as permission to ignore a dirty update.

## 6. Tests Required

Maintain `reader_demand_analysis_test.dart`, `reader_demand_export_test.dart`,
recorder, controller/motion and `reader_submission_test.dart` coverage. Assert
admission timing, queue/cold exclusion, holds, missing/late/open demand,
generation/epoch changes, final/reset submission, modern completeness and native
loss capability. Exercise a long capture under the real event-ring limit and
keep independent exported-aggregate parity. Device evidence remains separate.

## 7. Wrong vs Correct

Wrong: use `pointerAdmitted` or receipt time as recognized admission, count every
ticker callback as submission, or promote a legacy zero-loss count to a modern
pass. Correct: replay explicitly versioned raw boundaries, tie submission to
real visual mutation, and retain every failure or evidence omission.
