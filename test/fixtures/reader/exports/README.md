# Synthetic reader exports

These nineteen deterministic JSON files are test artifacts for the independent
pure Dart analyzer. They contain a synthetic SHA-256 identity (`a` repeated
64 times) and `synthetic-export` fixture ID, with no book text or filenames.
They are not device measurements or evidence of physical presentation.

Raw samples are hand-built in `test/helpers/reader_analyzer_exports.dart` and
`test/helpers/reader_device_analysis_exports.dart`. These helpers construct
and serialize the production `ReaderFeasibilityRecord` and compute
its expected aggregates with production `ReaderProbeSummary.aggregate` and
`DiagnosticSummary.aggregate`. It never imports the analyzer. Serialization
uses the production record's JSON encoder, including nested S1 frames/motion.
The unknown-version fixture changes only the top-level version after encoding.

From the repository root in PowerShell, regenerate with:

```powershell
$env:REGENERATE_READER_EXPORTS = '1'
try {
  flutter test test/tool/diag/reader_export_parity_test.dart --reporter expanded
} finally {
  Remove-Item Env:REGENERATE_READER_EXPORTS
}
```

The same test without that environment variable checks committed JSON against
fresh app output, then independently checks every reader and engine aggregate.
Comparison is structural, so CRLF/LF changes do not affect reproducibility.
No fixture files are rewritten during ordinary tests.

| File | Exercises |
| --- | --- |
| `passing-120hz-a1-1.json` | Six matched 120 Hz-like frames; separate stage budgets, exact 8333 us boundary, warm submission across generations, queue wait, warm/cold preparation, paragraph layout, fallback, rejection, proven acceptance, resource slopes, A1 cadence |
| `passing-120hz-a1-2.json` | Same samples in a separate capture; repeat 2 |
| `passing-120hz-a1-3.json` | Same samples in a separate capture; repeat 3; complete repeat summary |
| `failing-budgets-a2.json` | All UI and raster costs over budget; A2 half-open periods with 0, 1 and >=2 commits and an outside-period commit |
| `stall-b.json` | A 58.333 ms consecutive engine interval and recorder submission gap inside a motion window; B presented and zero-at-stop drawables, unsigned ID, presentation intervals |
| `negative-missing-frames.json` | Unavailable negative identities, missing engine frame 3 and missing motion frame 5; neither bridges cadence adjacency |
| `overflowed-rings.json` | Evicted event, layout, resource, engine and motion samples; native loss total 2 including contention subset 1; partial-evidence gate results |
| `resources-100-turns-unavailable.json` | Legacy v1 without correctness capability, explicit commits/destinations/epochs or caps; 100 acceptances and RSS trends cannot fill missing evidence |
| `resources-100-turns-bounded.json` | 100 explicitly committed inputs, one destination each, declared caps, stable RSS; correctness and resource gates pass |
| `double-acceptance.json` | One committed input accepts twice; correctness fails despite aggregate parity |
| `cap-breach.json` | 100 turns with picture bytes above the declared cap; resource gate fails despite aggregate parity |
| `unknown-schema.json` | Unsupported top-level version 2; CLI refuses it |
| `latency-release-after-motion.json` | Legacy admission after first motion: recognized admission remains unavailable, receipt aggregate stays informational |
| `stall-script-intent-unresolved.json` | R03 identity alone cannot explain a gap; all ambiguous candidates remain visible and failed |
| `stall-long-stage.json` | Inclusive 50000 us execution-stage stall: proven late frame |
| `display-phase-and-epsilon.json` | Recorded phase and epsilon overlaps, clipped half-open periods without double counting |
| `queue-cancelled-open-window.json` | Eight queued, seven queue overflows, invalidation without commit or settlement: unavailable gates |
| `rss-cold-growth.json` | Cold resource growth remains failed under the unchanged 5% rule |
| `drawable-gap-classes.json` | Native pipeline: acquisition activity versus endpoint cadence, pending and internal zero presentations |

Run the analyzer with:

```powershell
dart run tool/diag/analyze_reader_export.dart --strict test/fixtures/reader/exports/passing-120hz-a1-1.json
```

`--strict` makes aggregate mismatches exit 1; invalid JSON/schema/input exits
65; usage errors exit 64. Measurement failures are printed as failed gate rows
and do not change the exit status when aggregate recomputation matches.

Gate constants live only in `tool/diag/reader_export_data.dart`. Percentile
conventions intentionally differ: S1 uses `ceil((n-1)*p)`, the reader uses
`ceil(n*p)-1`. Resource slopes use ordinary least squares per recorder second.
Input IDs are scoped to one export/capture epoch and are never joined across
files or by generation. Stalls report long motion stages and gaps inside
recorded first-submission/settle windows, with no clock-epoch inference.

Schema v1 now adds `engine.metadata.readerCorrectnessVersion: 1`,
`captureEpoch`, and `resourceCaps` (`liveSurfaceCap`, `liveSurfaceReserve`,
`pictureCacheBytes`, `imageCacheBytes`). The latter come from the active pool
and image cache, including their actual configured byte limits. Each turn
event carries `captureEpoch`, opaque `inputId`, `generation` (callback token)
and `activeGeneration`. `inputCommitted` marks the controller's navigation
handoff decision after settlement; boundary/rebound/no-turn inputs do not
commit. `staleCallbackRejected` records a discarded callback; rejection is
safe, while publishing an acceptance after invalidation, with a rejected
generation, a different active generation, or a foreign capture epoch fails.
`accepted.destination` contains section/page indexes, layout generation and
SHA-256 page identity; no CFI, layout-key string or book text is exported.

Correctness requires zero proof failures, zero stale publications, exactly
one acceptance per explicit commit, and no acceptance before a commit.
Missing capability or required fields stays unavailable; observed failures
still fail when evidence is partial. An event overflow cannot establish a
passing absence claim. The engine-owned optional sink adds observation only.

Resource boundedness requires >=100 accepted turns, nonoverflowed events and
snapshots, live-surface maximum <= cap + reserve, and picture/image maxima
<= their declared byte caps. RSS first/last/max and OLS slope per second are
reported independently. `ReaderGates.maximumRssGrowthFraction = 0.05` bounds
both `last - first` and `slope * observedDuration` to 5% of first RSS, inclusive.
At least two distinct sample times and positive first RSS are required. This
is a bound over the observed capture, not proof against indefinite growth.
The R10 scenario supplies alternating turns; resource telemetry does not
independently certify gesture direction or cycle completeness. Missing caps
or samples stay unavailable; any observed breach fails even with overflow.

Trailing-batch omissions and all overflow counts remain explicit. Native
contention loss is a subset, not an extra loss.
A2 bins `[timestamp, min(targetTimestamp, next link timestamp))`; the last
ends at its target. Holes remain outside and boundary ties go to the next
period. All overlaps are reported; <=1 us is an informational epsilon class,
not a tolerance that hides data. Per-kind unsorted streams still reject.
B reports acquisition activity inside each >=12500 us presentation gap and
whether endpoint acquisitions are <12500 us apart. Pending pipeline work
means no interior acquisition alone cannot prove idle; slower acquisition
alone cannot prove a presentation deadline miss. B zero means
no presentation observed by stop, including pending/lost callbacks. All native
metrics stay in native time and never establish product-path physical
presentation or touch-to-photon latency.

The legacy App `warmInputToFirstSubmission` aggregate is receipt-based and
retained for parity, explicitly informational in reports. `pointerAdmitted`
occurs at pointer down, while `admitted` starts release settlement for a drag.
Neither records recognized admission consistently. The unchanged 16700 us
admission gate is unavailable until the App records that event. Ambiguous
stall gaps have no recorded request/hold proof and remain unresolved; script
identity never grants an idle/hold exemption.
