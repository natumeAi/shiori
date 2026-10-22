# Proposed reader performance acceptance

This is a plan-review contract, not a measured result. The original goal is
stable high-refresh page turning; the available iPhone 14 Pro Max tops out at
120 Hz. The technical evidence limits below must remain visible in reports.

## Evidence levels

| Level | What it can establish | What it cannot establish alone |
| --- | --- | --- |
| Correctness tests and page proofs | No skipped/duplicated content; one accepted destination; cancellation/lifecycle safety. | Real-device frame timing. |
| Release-device Flutter timings | UI/raster costs, budget exceedance, pipeline latency and scheduling cadence during motion. | Actual scan-out of a particular Flutter drawable or touch-to-photon latency. |
| Supported presentation trace or independent measurement | Displayed-frame cadence/latency to the extent measured by that method. | Unlimited device/content/thermal guarantees beyond the recorded setup. |

Do not relabel scheduled callbacks, a desktop FPS counter or a normal screen
recording as proof of 120 distinct displayed frames. `FrameTiming.totalSpan`
is pipeline latency, not an FPS reciprocal. The first device milestone proves
which metrics are available; the reader feasibility milestone investigates a
supported presentation-evidence route within the user's setup. If that route
is unavailable, report physical presentation as unverified and return the
acceptance limitation for review; do not close the full performance target.

## Recorded setup

- Physical iPhone 14 Pro Max, actual iOS version, release/AOT build, pinned
  Flutter/engine revision and app commit.
- Logical viewport, DPR, orientation, effective typography/theme, resource
  digest, scenario/run ID and cache state.
- Reduced-motion and power/thermal/refresh conditions where observable.
  Low Power Mode and Accessibility → Motion → Limit Frame Rate are recorded
  as user declarations before each run, because the app cannot read them.
  Every report includes the observed engine vsync-interval distribution, so
  a system 60 Hz cap (uniform ~16.7 ms intervals, low stage cost) is visible
  and distinct from application misses; the reported display refresh rate is
  metadata only. Unknown fields remain unknown. System-limited runs are
  retained as separate correctness evidence, not selectively removed to
  improve the result.
- No NAS traffic is required for generated-fixture animation tests. Separate
  network/download waits from page-preparation and moving-frame windows.

## Proposed engineering gate

For nominal 120 Hz continuous-motion windows, the interval budget is
8.333 ms. Measure at least three repetitions per mandatory scenario.

- At least 99% of motion frames meet the UI budget and, separately, the raster
  budget; report P50/P95/P99/max and all over-budget counts for each stage.
- No unexplained application stall of 50 ms or greater in a motion window.
- Warm, admitted input: P95 input-receipt-to-first-motion-submission no more
  than two nominal frame intervals. This is explicitly a submission proxy.
- Report queue wait, cold preparation, settle/handoff, static-fallback rate
  and total user-visible wait separately; intended 420 ms animation duration
  is not input latency. Warm-only results cannot hide cold/cross-chapter work.
- Zero skipped/duplicated pages, false acceptance, blank handoff, invalid
  saved positions, preview-counted activity or stale-generation publication.
- At least 100 alternating turns plus a repeated navigation/resource run;
  active cache ownership remains within declared caps and released resources
  do not grow with each cycle. Record memory/cache trends after warm-up.

These numerical engineering thresholds are a proposed minimum for the first
optimization loop. They do not redefine the full target as "average FPS" or
make missing presentation evidence a pass. Failed gates cause investigation
or a reviewed plan change, not an implicit reduction to 60 FPS/WebView.

## Mandatory scenarios

1. Tap next/previous and continuous slow drag/settle.
2. Flick, reverse before release, held-finger late neighbor and rebound.
3. Rapid queued turns, queue overflow, TOC jump and book boundaries.
4. Cold/warm chapter crossing, long chapter and very long single paragraph.
5. Mixed text/images, image-only page, SVG wrapper and real vector SVG.
6. Typography/font readiness changes, orientation/viewport changes.
7. Background/foreground, settings/TOC/image-viewer blocking and disposal.
8. Download interruption/recovery and activity delivery while reading.

Generated fixtures provide controlled work; the four local sample EPUBs
provide realistic content checks. Do not upload their prose to CI by default.

## Collection and reporting

Use a bounded in-memory ring while recording. Append inexpensive samples;
serialize and aggregate after motion. Include omissions/overflow, dropped
event/outcome records and clock-correlation status in every export. Capture
release timing batches after the recorded window before finalizing a report;
missing trailing samples mark it incomplete.

Preserve raw samples and scenario IDs. Reports state correctness result,
engine-budget result, cadence result, presentation-evidence status, and
remaining limitations independently. A build or simulator success satisfies
none of the physical-device criteria by itself.

Technical details and official API references:
`native-reader-contracts.md` section 6 and `ios-device-workflow.md`.
