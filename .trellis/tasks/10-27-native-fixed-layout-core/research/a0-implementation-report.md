# A0 implementation and self-validation

Date: 2026-10-27. This report covers the approved A0 work on Windows. The
experiment delivery and local self-validation are complete; the A0 feasibility
gate is **not passed**. The native report deliberately records
`fidelityGate: false`. No A1 implementation or additional A1 planning follows
this handoff, in accordance with the latest user instruction. S4a and A5 are
not complete. Formal checking remains deferred until the whole S4a
implementation, as requested by the user.

## Delivered files

Diagnostics and controller implementation:

* `lib/features/reader/engine/motion/{reader_turn_controller,turn_controller_drag,turn_controller_pointer,turn_controller_work,turn_intent_queue,turn_session}.dart`
* `lib/features/reader/engine/surface/prepared_reader.dart`
* `lib/features/diagnostics/data/{reader_probe_recorder,presentation_probe,presentation_payload}.dart`
* `ios/Runner/AppDelegate.swift`, `ios/Runner/Runner-Bridging-Header.h`
* `tool/diag/{reader_demand_analysis,reader_export_analysis,reader_export_report,reader_native_resources}.dart`
* Corresponding evidence, recorder, submission and method-channel tests, plus
  `test/tool/diag/reader_demand_analysis_test.dart` and
  `test/tool/diag/reader_demand_export_test.dart`.

Reference and capability evidence:

* `tool/oracle/src/fixed-layout-{corpus,fonts,oracle,paint-controls}.mjs`
* `tool/oracle/package.json`, `tool/oracle/README.md`
* `test/fixtures/reader/fixed_layout/` contains the pinned baseline, synthetic
  corpus, measured oracle/cross-engine differences, paint controls and generated
  same-table font wrappers/manifest.
* `test/features/reader/data/epub/fixed_layout_corpus_test.dart` independently
  replays source identity, namespace, every UTF-16 CFI and worker metadata.

Parallel owners delivered the finite policy modules
`scene_resource_budget.dart` / `process_font_budget.dart`, their two test files,
and the four `tool/reader/fixed_layout_spike*.dart` files plus their experiment
test. Detailed measurements and ownership contracts are in
[a0-resource-policy.md](a0-resource-policy.md) and
[a0-native-spikes.md](a0-native-spikes.md). Main owns all PRD/status/spec changes;
this report does not attribute those edits to the implementation owner.
Pre-existing dirty planning files were preserved. No commit, push, NAS write or
reference-checkout write was performed. Canonical v1 and the product
FlutterMetalLayer remain unchanged.

## Reference and matrix evidence

The pinned read-only reference is
`a4bda23fd3e82e285a22566d88576e67d3e8756b`; Foliate is
`78914aef4466eb960965702401634c2cb348e9b1`. The installed baseline is Flutter
3.47.7 / Dart 3.13.5, framework
`abaf9c523780a608bd46686fd5e53740a07077f8`, engine
`deb287481e3ce9468f3434937ced4240a70539ca`. Dependencies actually inspected are
flutter_svg 2.3.0, vector_graphics 1.2.4, vector_graphics_compiler 1.3.2 and
vector_graphics_codec 1.1.13. Existing compiler omissions were not treated as
proof that the proposed native alternatives are impossible.

Node v24.19.0 / Playwright 1.64.1 ran WebKit 27.2 as the authoritative host
reference and Chromium 156.0.8078.4 as a separately recorded cross-check. Every
one of 52 sources was measured in both engines. No oracle success was invented.
The actual pinned protection transform and Foliate `CFI.fromRange` were bundled
from the read-only checkout for source projection; raw and protected text
records remain distinct. All projected UTF-16 offsets agree with the independent
Dart parser/CFI implementation. Canonical v1 still excludes text below SVG,
including XHTML foreignObject descendants. Raw/effective rendition and section
source sequences were replayed through the actual worker importer for all cases.

| Matrix row | Four variants measured and source/CFI replayed | Additional actual A0 evidence | Gate limit |
| --- | --- | --- | --- |
| metadata | yes | OPF raw/effective layout, orientation, spread and section side/sequence | No production reading-unit/navigation integration yet |
| dimensions | yes | Browser viewport/viewBox and element geometry | Native dimension admission/transform proof pending |
| cascade | yes | Linked/imported/inline declarations and computed output | General native cascade pending |
| box | yes | Browser box/range geometry | General native box layout pending |
| text | yes | Browser contextual text/ranges; actual SFNT native shaping | General native line/box fidelity pending |
| paint | yes | Browser paint/visibility samples | General native paint admission pending |
| stacking | yes | Browser transform/order source records | General native stacking/inverse geometry pending |
| clip-mask | yes | Three native mask variants; four samples each exact | Raw AA/reference differences retained; full fidelity not closed |
| svg-graphics | yes | Reference shapes/resources/nested viewport records | General native vector/reference admission pending |
| svg-text | yes | Native contextual/path/adjustment experiments and exact source conservation | Actual painted-slice geometry exceeds 0.5px |
| foreign-object | yes | Native XHTML paragraph/border/clip experiment and source conservation | Range metric discrepancy and reference raster disagreement remain |
| filters | yes | All seven primitives consumed in an ordered native graph; samples exact | Strict positive PNG differs; wider region/mode support unproven |
| mixed-navigation | yes | Six-section mixed/reflow/fixed/nonlinear metadata and source order | Production grouping/blank/fragment navigation pending |

The 13-by-4 matrix is a reproducible baseline, **not proof of exhaustive
subvalue coverage or successful native admission**. In particular,
`dimensions-unsupported` currently has the same source geometry as its positive
case; its classification alone does not exercise an actual unsupported dimension.
Some declarations inside false `@supports` conditions likewise cannot prove
rejection of a used declaration. These are explicit remaining corpus/admission
gate gaps; the structural count test does not validate such semantics. The
outside-profile native rows have no successful partial-output marker. The broad
renderer and its complete required-value/admission coverage are not delivered
by these A0 spikes.

Exact final fingerprints:

* Corpus SHA-256:
  `e2feb591f8f9c7a9e6062a3e16dda2aaa0b154325f4434e674f2cd50b452844a`.
* Oracle SHA-256:
  `5cd38ddb11970e200c58f1ec1825d6d8cc2d06ea99b54327dfcdc79c58352954`.
* Native harness SHA-256:
  `42ddd6706e7a3e6e9c96f805425297a9222387f27c24ebf74e9205c0349ec4fe`.

The final oracle regeneration is byte-identical to the preceding output. Raw
PNG data and two-rAF stability observations are retained. Full Chromium and
native reports/images are under ignored `build/` directories; synthetic
authoritative evidence is in the fixture directory. Private local-book data
remains ignored.

## Native feasibility results

The focused test executes eighteen real native raster experiments and three
font usability probes, plus exact source coverage/CFI/canonical assertions.
Its passing execution result is separate from its failing fidelity result.

* The ordered filter graph uses native blur, offset, color matrix, flood,
  composite, blend and merge, including linear-RGB alternatives. All four
  sample pixels match in every executed variant. The sRGB positive full PNG
  differs at one pixel: WebKit XHTML SVG paints black alpha38 at (0,0).
  Twenty isolated HTML/XHTML controls reproduce this even for empty inline SVG;
  HTML/WebKit and Chromium controls remain transparent. No exclusion was applied.
* Luminance/alpha masks and group opacity really affect output: sampled alpha64
  versus alpha128 is exact. The positive full PNG has six differences: that
  reference artifact and five alpha1 native circle-edge pixels. There is no
  implicit antialiasing waiver.
* Contextual paragraph slices preserve all source offsets and author transforms.
  The parent textLength is ignored by WebKit around this textPath; applying it
  naively produced a measured 105.873133px error. The compatible experiment
  still has 1.384887px actual painted-slice/DOM metric delta, despite a separate
  0.294022px nominal diagnostic and matching whole-text alpha-support bounds.
  Child textPath none/spacing/spacingAndGlyphs produce primary deltas
  1.366096 / 1.492119 / 3.572766px. All exceed the unchanged 0.5px gate.
  Nominal metrics do not replace actual painted geometry. Public Paragraph
  selection splits contextual ligature advances differently from SVG character
  metrics; GlyphInfo supplies grapheme layout bounds rather than glyph IDs,
  outlines or shaping-run ligature clusters. Path traversal also differs.
* foreignObject retains native contextual XHTML/source geometry, but unrounded
  fractional Paragraph ranges versus WebKit enclosing DOM ranges differ by up
  to 1.048828125px. Full-node canvas/native advance matches exactly. The reference
  relative-span paint disagrees with its DOM vertical rectangle, reproducibly
  in isolated HTML and XHTML. Its positive PNG has 305 changed pixels. Neither
  arbitrary rounding nor a wider tolerance was used to turn this green.
* Required SFNT is actually used: native shaping 72.763671875px matches WebKit
  canvas and differs from the absent-family control 180px. WOFF/WOFF2 load in
  both browsers. On this native host their registration futures finish but
  shaping stays 180px. Those direct formats are **not admitted**. They need a
  bounded conversion/validation route or platform-specific proof; callback
  completion is not usable-font proof. Total attempted font bytes are 418144,
  of which 171676 are usable SFNT and 246468 have unusable/uncertain retention.

The strict PNG and text geometry gates therefore remain open/failed. Non-positive
full PNG reference evidence is also absent. These results do not establish
arbitrary filter regions/modes, all SVG values, iPhone rendering or 120Hz budgets.

## Finite resource and font policy

The executable provisional policy reserves before changing counters/allocating,
coalesces process font admission by SHA-backed face identity, and retains pending
or uncertain native outcomes across books. It does not clear process fonts on
book close. Twenty-one focused tests cover shared reservations, rejection,
cancellation/draining and pending registration behavior.

Aggregate provisional limits are four units/eight real pages; 32MiB source and
100000 nodes; 8192 paragraphs/4194304 shaping UTF-16 units; 16MiB vector payload
and 100000 operations; 4096 references/stops; 8388608 temporary RGBA pixels/32MiB;
source/reference/layer depths 64/32/8; and 64MiB/32 process fonts. Existing encoded
128MiB, retained picture 16MiB and image 48MiB owners remain authoritative rather
than duplicated. The policy modules are **not integrated into production**;
preparer/pool/FontRegistry integration and lifetime proof remain A3 work.

Measured native sRGB/linear filter graphs own nine/eleven images, lower-bound
2764800/3379200 bytes. Native scratch/saveLayer/GPU uploads/font retention/VM/RSS
are not included. These are finite engineering proposals, not proven device-safe
memory ceilings.

## Diagnostics contracts and evidence

New captures advertise `metadata.readerDemandVersion: 1`. Controller events add
`inputRecognized`, `recognizedAdmission`, `dragDirty`, `dragClean`, `holdStart`,
`holdEnd`, `frameDemandStart`, `frameDemandEnd`, `preparationBarrierStart`,
`preparationBarrierEnd`, `visualMutation` and `noMotionRequired`. Recognition is
actual horizontal/tap recognition (programmatic receipt is immediately
recognized); queued work is admitted only on promotion. Warm cache-hit
classification probes and immediately releases a ready lease, while retaining
the original bounded prepare/drain/control-task execution path.

Every actual changed offset, including final settle and zero reset, emits a
mutation. The surface records actual post-frame submission; `motionSubmission`
contains sequence/event/captureEpoch/monotonicUs/generation/frameNumber/inputId/
offset. Writes coalesced before one paint are accounted as the final visible
global state. Stale controller/generation/epoch callbacks are discarded. The
existing first-submission event remains deduplicated.

The pure Dart analyzer joins the capture epoch and input identity, checks
monotonic time, and separately exports actual admission-to-first-submission,
holds, preparation barriers, dirty demand and pending mutations. Warm latency
excludes queued/cold/no-motion work. Legacy receipt aggregates stay named as
receipt aggregates; missing admission capability is unavailable, not inferred.
At >=50000us, due-late/missing demand, dirty or mutation intervals are reported,
including intervals still open at capture stop. Holds never excuse that work.
Final fields include recognizedInputs, demandStarts, visualMutations,
motionSubmissions, incompleteDemandInputs, invalidTransitions, incompleteInputs,
openIntervals and openPreparationBarriers. Complete transition/sample evidence
and no relevant losses are required to claim stall absence.

Native exports add `lossAccountingVersion: 1`; absent legacy version remains
absent and cannot establish zero sampling loss. The Swift try-lock path now
counts failed acquisition with an atomic capture-epoch ticket, including
off-main callbacks. End capture reports ring eviction plus contention drops;
unmatched commits remain separately visible. A ticket from an older/ended
capture cannot increment the next one. Dart and CLI validate version 1 and
reject an unknown present version. **The C/Swift changes have not been compiled
or exercised on iOS on this Windows host.**

Both rings remain finite (16384). The deliberate 100-turn Dart pressure test
attempts **40400** events, retains **16384**, and reports **24016 lost**. That is
a successful loss-accounting test with actual loss, **not a zero-loss capture**.
Affected absence/percentile claims become unavailable. It does not prove that
the required long R06/device captures fit these rings without loss; real capture
volume/export strategy and physical native sampling still require validation.
Loss cannot be hidden by the larger native ring while Dart events overflow.

Meaningful fake-timeline/export tests cover pre-recognition dwell, delayed queue
admission, missing first submission, open demand at capture stop, a hold with
pending dirty/mutation/demand, real clean hold, final mutations, foreign epochs,
preparation barriers, missing capability/chain, monotonic rejection, global
reset coalescence, inclusive warm thresholds, reader-event loss, native loss and
legacy capability unavailability. A real CLI invocation validates serialized
pending-demand reporting.

## Final self-validation

All final commands exited zero. The host batch wrappers stalled; the actual
successful Flutter invocation was the installed SDK executable below, with
equivalent subcommands. SDK lockfile access outside the workspace required the
approved escalation. No dependency/version update was performed.

```powershell
$taskDart = 'D:/DevTools/flutter/bin/cache/dart-sdk/bin/dart.exe'
$taskFlutter = 'D:/DevTools/flutter/bin/cache/flutter_tools.snapshot'
& $taskDart run build_runner build
& $taskDart format --set-exit-if-changed lib test tool/reader tool/diag tool/ci
& $taskDart $taskFlutter analyze --no-pub
& $taskDart $taskFlutter test --no-pub --reporter expanded
& $taskDart run tool/ci/check_reader_fixtures.dart
node tool/oracle/src/check-reference.mjs
node tool/oracle/src/fixed-layout-corpus.mjs --check
node --check tool/oracle/src/fixed-layout-corpus.mjs
node --check tool/oracle/src/fixed-layout-fonts.mjs
node --check tool/oracle/src/fixed-layout-oracle.mjs
node --check tool/oracle/src/fixed-layout-paint-controls.mjs
node tool/oracle/src/fixed-layout-oracle.mjs
node tool/oracle/src/fixed-layout-paint-controls.mjs
```

| Check | Actual result | Local evidence |
| --- | --- | --- |
| Final codegen | 6s, wrote 2 outputs; no generated content diff | `build/a0-codegen-final.log` |
| Final format | 556 files, 0 changed | `build/a0-format-final.log` |
| Final analyze | No issues, 2.7s | `build/a0-analyze-final.log` |
| Full final Flutter suite | **2319 passed, 2 skipped, 0 failed**, 35s | `build/a0-full-tests-final.log` |
| Focused late regression run | 75 passed | `build/a0-final-regressions.log` |
| Peer resource focused tests | 21 passed; analyzer/format clean | resource report |
| Peer native focused test | 1 passed, executing 18 rasters and 3 fonts; fidelity false | native report and `build/fixed-layout-native/report.json` |
| Fixture/privacy guard | PASS reader fixture manifests and EPUB privacy guard | command output |
| Vendored reference integrity | All four pinned source hashes pass | command output |
| Corpus check | 13 rows, 52 cases, exact SHA above | command output |
| Four new Node modules syntax | All exit 0 | command output |
| Final oracle rerun | 52 cases per engine; 3 browser font formats loaded; exact byte-repeat | `build/a0-fixed-oracle-final.log` |
| Independent paint controls | 20 real fresh-context measurements | `build/a0-paint-controls.log` and fixture |

The two skips are existing optional evidence paths: `SHIORI_NATIVE_CFI_OUT` was
not set, and `build/d4/pre-seam-pages.json` was absent (`D4_REQUIRE_BASELINE=1`
makes it required). The existing local private-book comparison did execute:
four books, sixty sections, 168677 CFI samples; no private files were exported.
Generated tracked files may appear in `git status` because of local line-ending
metadata, but `git diff --numstat -- '*.g.dart' '*.freezed.dart'` is empty. No
destructive normalization/reset was used.

The first full run found a real prepare-drain isolation regression introduced
by bypassing prepare for a cache hit. That shortcut was removed; the original
bounded prepare/drain path and an immediately released hit-classification probe
now coexist. The focused regression run and complete final suite passed after
that fix. No further optional testing or implementation follows this handoff.
The user's latest testing preference is to run only affected tests after a fix;
the full run above had already finished when that instruction arrived. Future
fix validation must use the relevant targeted regression tests unless the user
requests a wider run. No additional full run was started after that instruction.

## Remaining gate and next technical action

The useful A0 artifacts are executable and independently measured, but they do
not authorize broad rendering by implying a passing gate. First resolve the
same-object text geometry contract using actual painted clusters/coverage and
source UTF-16 ranges, retaining independent SVG nominal metrics as diagnostics.
The next bounded mechanism experiment can measure native alpha-mask coverage
per retained shaping group, preserving author per-character transforms, or
evaluate a source-backed native shaping seam if public APIs cannot expose the
required runs. Preserve the 0.5px tolerance and raw counterexamples. Resolve the
foreignObject reference raster/DOM conflict and strict pixel differences through
explicit evidence, not an implicit exclusion. Correct the identified semantic
corpus gaps before calling the required admission corpus complete.

No iOS compile/CI run, signed build, install, physical presentation, 120Hz
performance, native loss-concurrency test or long capture with proven zero loss
was performed here. Production resource integration, full fixed-layout
renderer/navigation and A5 physical-device acceptance remain unimplemented or
unverified as specified. Work stops at the A0 handoff; main owns the subsequent
decision and task status.
