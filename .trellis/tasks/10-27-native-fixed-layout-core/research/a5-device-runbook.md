# A5 early iPhone runbook and evidence contract

Draft, 2026-10-28, owner A4 segment 1. No device run or hosted build is
claimed. A1-A4 integration/fidelity gates and owner authorization precede A5.
This is an early prepared-surface gate; S4c still owns product acceptance.

## Existing free build/install route

Use the archived S3 [device runbook](../../archive/2026-10/10-26-runtime-server-library/research/s3-device-runbook.md),
[Phase A device evidence](../../archive/2026-10/10-26-runtime-server-library/research/phase-a-evidence.md#hosted-ios-sqlite-gate-phase-a-exit)
and [E2 build-mode contract](../../archive/2026-10/10-26-runtime-server-library/research/phase-e2-evidence.md).
S3's successful packaging/install/SQLite evidence does not validate S4 Swift.
No new paid runner, service, dependency or signing route is introduced.

1. Coordinator prepares the reviewed integration diff, exact commit/ref and
   host report. Owner approves that specific public push and hosted build.
   This draft does not authorize a commit, push or workflow execution.
2. Use existing `ios-unsigned.yml`, `mode=probe` / `lib/main_probe.dart`, for
   the A5 reader probe. An approved `ios-build/**` push selects probe; an
   approved manual dispatch is `gh workflow run ios-unsigned.yml --ref
   <approved-ref> -f mode=probe`. Keep the installed pinned free Windows +
   hosted-macOS flow. S3 `mode=app` builds `lib/main.dart` for later product
   validation and does not supply the probe controls required here.
3. Hosted macOS must compile A0's atomic bridging-header/C + Swift changes
   and A4's two native changes: `sampleCapacity=262144` and inventory
   `captureBudgetVersion=1`. Status: **CI-compile pending**. Review SDK/ABI,
   atomics, hooks, arm64 binaries/frameworks and generated native migration
   evidence before installing. Windows source tests are not compilation.
4. Download the matching `shiori-probe-<full-sha>-gha-<run>` artifact. Require
   `build-exit-code.txt=0`; match commit, BUILD_ID, BUILD_NUMBER, mode,
   entryPoint, Flutter/engine/Xcode/SDK in provenance/toolchain/bundle-info.
   Review `frameworks.txt`, `ios-status.txt`, `ios-project.diff` and any
   `ios-untracked.zip`; verify IPA with `Get-FileHash -Algorithm SHA256` and
   `sha256.txt`. Preserve these records privately with the evidence manifest.
5. Owner transfers the default `shiori-probe-<BUILD_ID>.ipa` to iPhone Files,
   signs using the existing selected 全能签 certificate/profile locally,
   keeps the existing team/bundle identity, disables injection/patches, and
   installs over the existing app without deleting its data. Owner performs
   trust/Developer Mode steps if the existing profile requires them, then
   launches release/AOT from the home screen without a debugger. Secrets
   stay on the owner's devices. If overwrite requires deletion, stop that
   retention item and record the reason. No new signing purchase is required.
6. Record the exact installed variant and actual runtime `FlutterMetalLayer`.
   A1 is the main cadence evidence; pair A2 to expose display-link observer
   effects. The `-cametal.ipa` / B path is optional diagnostic evidence only;
   it cannot replace A1/A2 or prove product presentation.

## Capture sizing and limits

Existing archived exports are sparse: the normal fixture has 37 events/four
acceptances (9.25/turn); the resource fixture has 517/100 (5.17/turn), both
with only six motion samples. They cannot size dirty-drag captures. Extending
the existing recognized-demand fake timeline at 50 frames/turn measures:

| Variant | Events/turn | Engine/motion | Native A2 model |
| --- | ---: | ---: | ---: |
| Warm | 310 | 50/50 | 100 |
| Cold, including preparation/barrier boundaries | 315 | 50/50 | 100 |
| Held, including hold start/end on every dirty frame | 410 | 50/50 | 100 |
| Reverse | 310 | 50/50 | 100 |

Chosen design: fixed preallocated packed numeric event rows, lazy full-field
map views only after stop. No event coalescing, timestamp approximation or
field removal. Each repeat stops, drains, exports, then resets independently;
three repeats do not share one accumulating ring. Raw JSON schema remains v1.
`engine.metadata.readerCaptureBudget.version=1` identifies the new envelope;
`presentation.inventory.captureBudgetVersion=1` identifies the enlarged native
ring. Legacy files remain readable with the new capacity gate unavailable.

- Events: 786432 rows; ten int64 columns + one float64 + two uint8 = exactly
  70778880 numeric bytes (67.5 MiB). At 8-byte references the digest slots add
  6 MiB: 73.5 MiB plus small array headers and retained SHA-256 strings.
- Envelope per repeat: 600 s, 120 Hz, 72144 frame samples including 1.2 s
  drain, up to 4096 turns. Eight events/frame (held dirty demand/submission)
  plus 24 control/admission/cold/commit events/turn requires 675456 rows,
  leaving 110976 rows of headroom. Frame input is driven by actual frames,
  never catch-up injection. Faster/unbounded external inputs are outside this
  sizing guarantee; observed overflow always fails, never silently truncates.
- Layout/resource rings: 16384 each (four samples per turn at 4096 turns).
  Engine frame/motion rings: 131072 each, replacing the insufficient 65536.
  Native: 262144, versus 216432 at three samples/frame over the same window.
  Native try-lock contention and unmatched callbacks still count as loss;
  capacity cannot guarantee their absence. Every device run must observe zero.
- Expected arm64 native sample stride is 56 bytes: entries + 8-byte lookup
  slots total 16 MiB, plus counter/object overhead; confirm on hosted Apple
  tooling. Engine objects/queues and auxiliary Map overhead are VM-dependent.
  Plan roughly 128 MiB for retained diagnostics at the full envelope before
  the application's baseline, not a hard RSS cap. The previous sealed event
  snapshot can overlap the next repeat by another 73.5 MiB until released/GC.
  Native objects, GPU, strings, export JSON and VM overhead remain additional.
- JSON/aggregation happen after stop; event write methods only fill numeric
  slots. Serialization can allocate a large string, and host offline analysis
  materializes maps. Measure capture, stop/export and next-repeat peaks
  separately on iPhone. Do not quote a host analyzer peak as device capture RSS.
- Host proofs: 100 alternating turns x three independent repeats retain
  33625 events + 5000 frames/motion + 10000 native model samples per repeat.
  R06 stress models 3000 turns/72000 frames (599.976 s), 462000 events,
  144000 native model samples and 3001 resources; all losses zero and raw
  aggregates match independent analysis. The actual scripted R06 waits at
  least 500 ms/tap, so this 0.2 s/turn stress is denser. A separate test writes
  all 675456 envelope rows without growth/materialization/loss.
  Native model/source checks do not prove native runtime or contention safety.
- Measured ASCII wire sizes: the three 100-turn repeats are 7902145,
  7912748 and 7965378 bytes; R06 is 114884822 bytes (109.56 MiB). In the
  focused Windows test process, R06 RSS was 233029632 bytes before stop and
  245641216 after finalization; the process high-water mark including offline
  analysis plus full JSON serialization was 686444544 bytes (654.64 MiB).
  These include the host VM/test baseline and a lazy native model, not real
  native storage. They establish export pressure, not an iPhone memory pass.

## Device matrix and unchanged gates

Record iPhone model/actual iOS, release build, viewport/DPR/orientation,
settings/font/fixture digest, cache state and installed variant. Declare Low
Power Mode, Limit Frame Rate and reduced motion before each repeat; preserve
thermal/max-FPS metadata and measured engine cadence. Unknown stays unknown.
Use generated fixtures first, then private books under anonymous digests.

Run every required row three times, each as a separately identified export:

| Row | Actions and coverage | Evidence |
| --- | --- | --- |
| Complex authored | XHTML text, packaged fonts, positioned/curved SVG text, masks/filters/foreignObject; all required matrix variants | A-AC1/2/3/6, source/cluster/paint geometry and native/reference captures |
| Images/spreads | Image-only, wrappers, vector SVG, two-page/center/blank slots, both directions | A-AC1/2/3/4; both constituents and blank-source absence |
| Mixed | Forward/reverse fixed↔reflow boundaries, TOC jump and nonlinear target | A-AC1/3/4/8; exact ordered sources and identities |
| Reflow/R06 | Existing corpus/settings, >=100k-code-unit paragraph; full section traversal, typography/orientation changes | A-AC2/3/7/8; page totals, timing, peak/trend |
| Inputs/R01-R05 | Cold/warm next/previous, slow drag, flick, rapid queue/overflow, reverse before release, held late neighbor, rebound, first/last boundary | A-AC4/5/7; recognized/admitted/queued/cold/submitted chains |
| Long/R10 | >=100 accepted alternating turns per repeat, then repeated cold navigation/resource cycles | A-AC4/5/7; every stream zero loss; caps and RSS |
| Real interruption | Background during motion, return and proven turn; repeat during cold/held preparation, then turn again | A-AC4/5/6/7; actual OS operations, stale rejection and completed recovery |
| Private regression | All 23 sections including six fixed image pages, remaining novels, long/Unicode/style cases | A-AC8; anonymous counts only |

R09 is a controller simulation and cannot substitute for actual home-screen /
app-switcher operations. R11 manual captures retain repeatCount=1 by contract;
collect three separate R11 runs and group them in the manifest. Their legacy
>=50 marker does not satisfy the >=100 alternating-turn requirement: count
acceptances and verify destination alternation separately. Generated scripts
do not automatically supply manual complex/SVG/spread corpus selection; the
integrated probe must expose those real A1-A3 owners before those rows run.
If R06 reaches duration_limit before full traversal, retain it as incomplete
and return for review; do not call a shorter retained prefix a complete run.

Keep >=99% of UI frames and, separately, raster frames <=8333 us; warm actual
recognized-admission-to-first-submission P95 <=16700 us; no unexplained >=50000
us stall; zero proof/acceptance/stale-publication failures. Keep declared caps,
>=100 accepted turns and both RSS endpoint growth and positive OLS projected
growth <=5% of first RSS. Preserve historical failures unchanged. RSS rules
are observational, not indefinite stability. Report fidelity, resources,
performance, cadence and presentation as separate verdicts. Review failures
before dependent activation. Missing evidence stays unavailable.

## Paired iPhone Safari evidence

For each measured variant, owner opens the same approved synthetic fixture
in iPhone Safari using the existing reference setup and captures its native
counterpart on the same phone. Record reference commit/fixture SHA-256,
iOS/Safari build, viewport in CSS px, DPR, orientation, font readiness, zoom,
settings and screenshot pixel dimensions. Await fonts/images and settled
layout. Record any geometry extraction method actually available; if the
existing Safari setup cannot export required geometry, leave that item open
for the reference owner rather than substitute Windows screenshots. Do not
introduce a new service or modify the reference checkout during this slice.

- Dedicated fallback/emoji case: the authored font must lack those characters;
  verify fallback glyph presence, exact source/UTF-16 cluster coverage and
  geometry/pixels against Safari's iOS fallback, at the unchanged 0.5 CSS px
  geometry gate. Host Segoe UI Emoji/no-system-font observations cannot pass it.
- D8: repeat text raster comparisons for positioned/curved/ligature/combining
  and foreignObject text variants. Preserve exact cluster conservation and
  geometry; exclude only text glyph coverage/reference text geometry expanded
  by 1 px from component counting. Retain interior, edge-band, support-bound
  and exact sample rules. Non-text component counting keeps D7 alpha>=32.
- D3: reverify the XHTML-SVG (0,0) pixel and foreignObject relative-span defect
  candidates with isolated reproducing controls, paired Safari/native PNGs
  and Safari DOM/geometry evidence. Record whether each reproduces on this
  iOS/WebKit. Any exemption stays limited to the named pixels/elements with
  its reference-fix handoff; a native-only deviation fails. No blanket waiver.

Retain each repeat and each measured variant's paired raw PNGs and comparison
report (raw diffs, masks, geometry, cluster/source map, sample points,
per-channel verdict). Record missing tooling/data as unavailable, not pass.

## Evidence schema and collection

Keep raw files under ignored `local-evidence/s4a/a5/<session>/`; the owner
exports JSON through Files -> On My iPhone -> Shiori, then transfers it and
screenshots/video/notes to Windows. Apple Devices file sharing is the existing
USB alternative. Verify hashes after transfer. Track only anonymous digests,
counts and verdicts in the task report. Titles, paths, assertion-bearing CFIs,
server addresses, prose, personal screenshots and credentials stay private.

Manifest schemaVersion=1 (a schema definition, not fabricated run evidence):

| Field group | Required data |
| --- | --- |
| session/build | sessionId, UTC collection time, full commit, BUILD_ID/NUMBER, hosted run, artifact/IPA SHA-256, probe/app entryPoint, installed variant, signing-identity consistency (no certificate/team secrets), toolchain provenance hashes |
| device/setup | model/actual OS, release/AOT/no-debugger, viewport/DPR/orientation, typography/theme/reduced motion, declared power/limiter, native layer/flag, thermal/max-FPS metadata, effective engine cadence |
| input/corpus | scenarioId + matrix row, fixture digest or anonymous book digest, settings hash, cold/warm state, manual/synthetic, planned/completed turns, accepted-turn count, ordered destination digest/side/page sequence, page/section totals |
| repetition | groupId, requiredRepeats=3, observed repeat indices 1..3, each runId and JSON SHA-256; manual R11 record repeatCount remains 1, external group stores the three runs |
| capture/storage | readerCaptureBudget and native captureBudgetVersion, configured capacities, raw counts for all six streams, every overflow counter, contention subset, unmatchedCallbacks, contiguous event sequence, started/stopped/finalized times, stopReason, drain/incompleteTrailingBatch, omissions/errors |
| correctness/fidelity | A-AC1..8 mapping, geometry by channel, cluster/source conservation, source/CFI/canonical v1 regression provenance, each variant's paired PNG/diff/geometry hashes, D3/D7/D8 treatment, missing/duplicate/false/stale outcomes |
| resources | actual owner caps/ledger, surfaces including spread constituents, picture/image/source/decode/font/HarfBuzz/glyph-outline peaks where observable, process-lifetime font accounting, before/after warm-up and cold-navigation samples, RSS endpoint/OLS/max, capture vs export vs repeat-overlap peaks, jetsam/crash evidence if present |
| timing | UI/raster P50/P95/P99/max/count/over8333Us separately, matched frame counts, cadence/adjacency/missing IDs, actual warm admission P95, queue/cold/settle/handoff waits, all >=50ms demand/stage candidates, holds/open intervals/barriers/static fallback |
| lifecycle | actual owner-operated background/return action and UTC time, motion/cold state at interruption, observed return state, post-return accepted proven destination, crash/relaunch details; controller simulation labeled separately |
| native/presentation | A1/A2 mode/evidence, layer inventory, native stream counts/intervals, display-period bins, native clock domain, optional B explicitly non-product; physicalPresentation/touchToPhoton remain unverified without independent measurement |
| results | independent analyzer command/version/exit, aggregate mismatch list, per-row fidelity/resource/performance/cadence/presentation verdicts pass/fail/unavailable/partial with reason, missing repeats/data, reviewer and review decision |

Analyze on Windows, using installed SDK directly, for each three-run group:

```powershell
& 'D:/DevTools/flutter/bin/cache/dart-sdk/bin/dart.exe' tool/diag/analyze_reader_export.dart --strict <repeat1.json> <repeat2.json> <repeat3.json>
```

Read every gate and omission, not just exit 0: the CLI returns 1 for strict
aggregate mismatch and 65 for invalid input; observed measurement failures
can still return 0. Verify >=100 actual alternating acceptances and three
complete repeats externally; the new capacity gate certifies sizing/observed
loss only, not scenario completion or repeat sufficiency. Never merge the
three raw captures or clock domains. Preserve the bounded trailing-timing
qualification even when all recorder loss counters are zero.

## Owner boundary and handoff

Owner is needed for exact-ref push/build authorization, local signing,
physical installation/trust, phone/Safari operations, declarations, real OS
background/return and private evidence transfer. Coordinator can prepare and
review source, commands, manifests and analysis offline; no owner step has
been executed here. A5 starts only after approval and the integration gate.

Map the [parent seven-condition ledger](../../10-22-flutter-lan-reader-parity/s4-plan.md#all-seven-s2-conditions-remain-owned)
explicitly: (1) warm admission, (2) dirty demand/stalls, (3) RSS/native loss,
(4) real OS recovery, (5) all mixed layouts, (6) preload/fonts/parser/coalescing/
synchronization, (7) product FlutterMetalLayer. This draft closes none of the
device or final C5 conditions. Missing integration, required fidelity,
compile/runtime/memory or paired Safari evidence remains open with its owner;
do not activate dependent work by treating a host synthetic pass as A5 pass.
