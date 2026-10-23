# S2 device runbook

Prepared on 2026-10-23 from the committed Phase A-E implementation. This is a
user-operated procedure after the push gate; no S2 cloud build, signing,
installation or device measurement is established by this document.
Raw exports stay private. [The report](feasibility-report.md) keeps NC7-NC9
pending and the S4 GO / NO-GO undecided until those results are reviewed.

## 1. Preconditions and push gate

1. Finish and review the local Phase F documentation/spec work separately.
   Nothing is built until the user confirms the exact public push in chat,
   including branch `ios-build/s2-reader-probe` and reviewed commit. This
   session performs no commit, push, workflow trigger, signing or installation.
   At this handoff HEAD is `bf12416`; only Phase C (`73835bb`) and earlier are
   pushed, so an older successful run cannot validate Phases D/E.
2. After that confirmation, the authorized push to `ios-build/**` triggers
   **Unsigned iPhone probe**. `workflow_dispatch` also exists. Select the run
   for the approved branch/commit. Source pins select `macos-15`, Xcode 26.3,
   stable Flutter 3.47.7 arm64. Actual hosted execution is still unverified.
3. Download artifact `shiori-probe-<full commit SHA>-gha-<run number>` within
   its 14-day retention. Its `build/ios-probe/` upload contains:

   | File | Intended use |
   | --- | --- |
   | `shiori-probe-<BUILD_ID>.ipa` | Default product presentation path; all NC7 runs, A1/A2 |
   | `shiori-probe-<BUILD_ID>-cametal.ipa` | Mode B and the R01/R02 comparison only |
   | `sha256.txt`, `provenance.json` | Both IPA checksums and per-variant identity |
   | `flutter-version.json`, `toolchain.txt` | Flutter/engine and actual runner/Xcode/SDK |
   | `bundle-info.txt`, `bundle-info-default.txt`, `bundle-info-cametal.txt` | Source and staged plist checks |
   | `build-exit-code.txt`, `ios-status.txt`, `ios-project.diff` | Build result and native migration review |

   `ios-untracked.zip` is additionally saved if native migration creates
   nonignored files. Upload runs even on failure: artifact presence alone is
   not success. Keep failure logs and stop if compilation/package checks fail.
4. Verify the Actions commit equals `provenance.commit`, and `BUILD_ID` equals
   the first 12 commit characters followed by `-gha-<run number>`.
   `provenance.buildId`/`buildNumber`, job summary and `toolchain.txt` must
   agree. `build-exit-code.txt` must be `0`.

   | Pin / variant | Required value |
   | --- | --- |
   | `flutter`, stable channel in `flutter-version.json` | `3.47.7`, `stable` |
   | `framework` | `abaf9c523780a608bd46686fd5e53740a07077f8` |
   | `engine` | `deb287481e3ce9468f3434937ced4240a70539ca` |
   | `variants[].variant = default` | Default IPA filename; actual `FLTUseFlutterMetalLayer` is `null` when absent, effective `true` |
   | `variants[].variant = cametal` | `-cametal` filename; actual and effective `FLTUseFlutterMetalLayer` both `false` |

   Compare each IPA's `Get-FileHash -Algorithm SHA256` result with both
   `sha256.txt` and `variants[].sha256` (case-insensitive). Check
   `variants[].file`, `FLTUseFlutterMetalLayer` and
   `FLTUseFlutterMetalLayerEffective` against its staged bundle-info file.
   The default plist is copied unchanged; only the CAMetal copy changes the
   Metal-layer key. Both IPAs come from one validated unsigned `Runner.app`.
5. Review the successful log: `iphoneos`, identifier
   `io.github.natumeai.shiori`, `CFBundleVersion` equal to the run number,
   arm64 executable plus `Flutter.framework`/`App.framework`, and both ZIP
   validations. Inspect each IPA as a ZIP for `Payload/Runner.app/Info.plist`
   and the nonempty executable/frameworks. Review native diffs before accepting
   any migration. Source: `tool/ci/build_ios_unsigned.sh:45-168` and
   `.github/workflows/ios-unsigned.yml:1-53`.

## 2. Sign and install the correct IPA

Use the S1 route: import the verified **default** IPA into 全能签, sign with
the user's existing certificate/profile, and install over Shiori. Keep the
installed bundle identifier, certificate/team and profile consistent. Keep
dylib/plugin injection and executable patch options off. The user handles
credentials locally; none enter chat, source, CI or evidence documents.
Launch from the home screen without a debugger. Match build identity in the
probe export (`engine.buildId`, `engine.metadata.buildNumber`) to provenance;
the reader screen has no dedicated build-ID label. The S1 synthetic screen
also remains available as `S1 合成动画采集`.

S1 proved same-certificate build 3 -> 4 update and same-build re-sign retained
the saved Application Support marker. It did not prove S2 book/JSON retention,
cross-team updates, expiry or revocation behavior. Export before changing
variants; check the marker and Documents inventory after each install. Do not
delete the app to make an update pass. S2's accepted reader position is
in-memory only and is not a retained reading-history promise.

Run R01-R10 (three repeats each), R11 (one qualifying capture per local book)
and A1/A2 on the default IPA. Only after retrieving those exports, sign the
`-cametal` IPA with the same identity and install over it for B. Record actual
launch, identity, retention and any signer plist changes separately from CI.
S1 evidence: archived runbook, BC2-BC4 at lines 243-245.

## 3. Place the four local sample books

The Files -> Windows export direction worked in S1; importing EPUBs into
Shiori's Documents in the reverse direction is **untested**.

1. Transfer the four local sample books through the user's existing private
   transfer route into Files. In Files, copy/move them to **On My iPhone ->
   Shiori**, at that folder's top level. Do not put them in the repository,
   CI, artifacts or a nested Documents subfolder. Keep names/text out of notes
   and screenshots; refer to the four local sample books by SHA-256 only.
2. Open `阅读器可行性探针`, open the tune icon (`探针控制`), then
   `选择书籍 / 刷新列表`. User entries read `用户书籍 SHA-256：<digest>`;
   synthetic entries read `夹具：<id>`. The inventory lists top-level `.epub`
   files case-insensitively and hashes their bytes; it does not recurse.
3. If Shiori is absent, launch it and complete/export a short synthetic
   capture to exercise Documents creation, then check Files again. If the
   transfer still fails, try **Apple Devices -> Files -> Shiori** (or an
   existing iTunes **File Sharing -> Shiori** setup) to add the files. This
   import fallback is also unverified; record the app/version and outcome.
4. Record transfer method, destination visibility, refresh result, four digest
   entries and open success/failure, without book names or text. Preserve the
   exact non-sensitive UI error. If no import route works, continue synthetic
   runs and mark R11 blocked/pending; never substitute fixtures for real books.

Inventory source: `probe_book_repository.dart:27-54`; labels:
`lib/l10n/app_zh.arb:5-15`. No import button or file picker exists in this probe.

## 4. Before every capture

Use the same portrait orientation, reader settings and device conditions for
comparisons. Set Low Power Mode off and Settings -> Accessibility -> Motion ->
Limit Frame Rate off. On a ProMotion device, record ProMotion capability and
reported maximum rate; **there is no separate ProMotion declaration/control**
in this UI. Do not infer effective refresh from that capability or metadata.

In `探针控制`, enter the real fields exactly as shown:

| UI label | Entry / meaning |
| --- | --- |
| `设备型号（手动填写，可留空）` | Enter actual model; it remains user-provided, not hardware detection |
| `低电量模式（用户声明）` | `关 / 否` for mandatory runs |
| `辅助功能 → 动态效果 → 限制帧速率（用户声明）` | `关 / 否` for mandatory runs |
| `正在充电（用户声明）` | Actual condition |
| `手机感觉发热（用户声明）` | Actual condition |

The other choices are `开 / 是` and `未知`. Use `未知` if uncertain; those
captures do not establish the limiter-off gate. Record actual iOS version,
charging/heat changes and native `maximumFramesPerSecond`, `lowPowerMode`,
`thermalState`, `layerClass` and `FLTUseFlutterMetalLayer` when available.
Limit Frame Rate stays a declaration, not a native API reading.

Baseline settings: `字体` = `默认`, `字号` = 18, `行高` = 1.6,
`字距（em）` = 0, both `水平附加边距`/`垂直附加边距` = 0,
`主题` = `明亮`, `减少动态效果` off. Record system Reduce Motion too;
the export distinguishes `reducedMotion` and `systemReducedMotion`. A reduced
motion/static capture is useful separate evidence, not the 120 Hz motion run.
R08 deliberately changes font size/line height: restore this baseline before
each new scenario or comparison set. Opening a fixture does not reset settings.

Controls/declarations: `reader_probe_controls.dart:63-175`,
`reader_probe_capture.dart:4-38`, `lib/l10n/app_zh.arb:16-56`.

## 5. Run R01-R11

Open any supported fixture once to enable `开始阅读器采集`. In
`探针控制`, choose `场景`, set `重复次数（默认 3）` to **3**, keep
`手动触摸采集（R11 必须使用用户书籍）` off for R01-R10, and select
`原生呈现证据（仅诊断）` = `A1 图层提交（无辅助显示链接）`.
Close the drawer, press `开始阅读器采集`, and leave the screen unobstructed.
The script opens its mapped fixture automatically; no physical gesture is
needed for scripted input. Each repeat creates a separate export. Wait for
drain/export and controls to return before the next set. Do not press
`停止采集` during a qualifying scripted run.

| Scenario (real menu label) | Fixture | Implemented workload / operator check |
| --- | --- | --- |
| `R01 前后各 40 次轻点` | `long-content` | Cold jump to first section; warm before each of 40 next taps then 40 previous taps. Observe ordered turns and return. |
| `R02 拖动、快滑、反向和边界回弹` | `chapters` | Slow 90-move drag, 6-move flick, 24-move out-and-back reversal, then first/last-page boundary drags. Observe settlement, reversal and rebound without an extra accepted page. |
| `R03 按住手指等待冷邻页` | `long-content` | Cold start; delay preparation during a 30-move drag, hold 180 ms, release preparation, wait 160 ms, then release pointer. Observe late neighbor arrival without a stale/duplicate acceptance. |
| `R04 队列溢出和跳转` | `chapters` | 16 taps without settlement waits, then jump to final section while pending intents remain; wait 600 ms. Observe queue/overflow/cancellation and correct jump. |
| `R05 冷热双向跨章` | `chapters` | Cross every section boundary in both directions: cold destination then warmed reverse/forward turns. Observe chapter ordering and report cold preparation separately. |
| `R06 十万字长段落` | `long-content` | Find a section containing a text block of at least 100,000 UTF-16 code units; traverse the entire section. Leave it running; check for missing/clipped/repeated lines. The UI says 十万字, but the code measures code units. |
| `R07 图文和 SVG` | `images` | Jump to every section and traverse every page. Inspect text/images, image-only content and SVG; record visible differences/unsupported markers and decode failures. |
| `R08 字号行高重排和锚点恢复` | `styles` | Jump to midpoint, change font size (26, or 20 if already 26) and line height (1.9, or 1.6 if already 1.9), then 3 next/3 previous taps. Observe accepted-anchor restoration. Settings persist/toggle across repeats; record starting settings, then restore baseline for later sets. |
| `R09 运动及准备时模拟后台恢复` | `chapters` | Suspend/resume once during motion and once during held preparation, then turn again. This is controller simulation, not a real OS app switch. Verify reader accepts input afterward; do the manual supplement below separately. |
| `R10 百次交替翻页和跳转资源采样` | `long-content` | Cold start/snapshot, 100 alternating warmed turns with a snapshot each, then 12 cold section jumps with snapshots. Let the entire script finish; record >=100 actual acceptances and resource/cap/RSS results. |
| `R11 用户书籍手动阅读至少 50 次` | Each of the four local sample books | Select a digest entry first; R11 forces manual input and exactly one capture. Physically turn >=50 accepted pages per book, then stop. See below. |

For R09's **separate manual OS supplement**, select `chapters`, R09 and the
manual switch. Start capture, initiate a physical page turn, switch the app
to background and return, then verify further turns work. Attempt a separate
background/return while cold preparation is actually pending (manual capture
starts with a cold reload). Record what was observed and which interval was
hit. If preparation finishes too quickly to interrupt, mark that part
unverified. Stop/export the supplemental record; its `manual_touch` input
must not replace the three `synthetic_injected` R09 repeats. Do not background
the mandatory scripted capture to simulate this test.

For **R11**, use `选择书籍 / 刷新列表`, choose one user digest, then select
R11. The manual switch is forced on and repeat control disabled; a fixture
selection is rejected. Start, wait for cold reload, then physically tap the
right zone (~78% of width) for next, left (~22%) for previous, and use drags
as appropriate. Count actual accepted position changes, not attempts or
boundary rebounds. Use alternating next/previous turns if the book has fewer
than 50 forward pages. After >=50 accepted turns, press `停止采集`, wait for
export and copy the summary. Repeat once for each of the four local sample
books. Check `omissions.manualMinimumMet` is true and review raw acceptances;
the UI does not supply a dedicated accepted-turn counter. An early stop is
retained as incomplete evidence, never filled by a scripted surrogate.

### Qualifying runs and failures

- Keep all three repeats and review each independently. Do not average away a
  failed repeat. A scripted result needs `engine.stopReason =
  scenario_complete`; interruption, duration limit (10 minutes), cancellation
  or `probe_failure` makes it partial. R11 normally ends with `user_stop`.
- Wrong build/variant, wrong declarations, unexpected system Reduce Motion,
  manual input in a scripted set, a changed viewport/settings baseline or an
  obscuring drawer invalidates comparability. Preserve the file and record
  why; missing repeats remain pending. R08's documented reflow is intentional.
- Missing/mismatched frames, ring overflow, native loss and trailing timing
  omissions must be retained. Unavailable evidence cannot pass an absence
  claim. The expected `trailingTimingBatch`/incomplete trailing state is always
  explicit; do not call every export invalid just because that flag is true.
- A proof failure, stale publication, duplicate/missing committed acceptance,
  cap breach, unexplained stall or visible content error is a **failed
  observation**, not a reason to discard a run and select a nicer replacement.
  Report cold preparation, queue wait and static-fallback rates separately.

Scenario sources: `reader_scenario_runner.dart:23-35,134-164`,
`scenario_scripts.dart:10-120`, `reader_probe_capture.dart:42-124`,
`reader_probe_recorder.dart:63-71,133-151`; long-block/reflow details:
`reader_probe_controller.dart:198-218` (all diagnostic basenames under
`lib/features/diagnostics/presentation/reader_probe/` or `data/` as applicable).

## 6. A1 / A2 / B procedure and time box

Use the same R01/R02 workload/settings/conditions for comparisons. Keep run
IDs, repeat numbers, mode and signed variant in private operator notes. Collect
baseline default A1 first, default A2 second, CAMetal B last. Retrieve each set
before an update; keep any fix iteration in a separate local folder.

| Mode / exact menu option | Build and precondition | Interpretation |
| --- | --- | --- |
| `系统信息` | Either IPA; actual FlutterView layer must be found | Inventory metadata only, no cadence samples expected |
| `A1 图层提交（无辅助显示链接）` | Default; exact `FlutterMetalLayer` class | `setContents:` main-thread timestamps, `layer_commit_cadence` |
| `A2 图层提交及辅助显示链接` | Default; exact `FlutterMetalLayer` class | A1 plus auxiliary CADisplayLink periods, `layer_commit_cadence_per_display_period` |
| `B 非默认路径的 drawable 呈现` | `-cametal`; exact `CAMetalLayer` class and explicit plist flag `false` | Acquired drawable IDs and callback `presentedTime`, `system_drawable_presentation_non_product_path` |

1. Use the three default A1 R01 and R02 repeats already collected above as
   baseline. Native inventory accompanies the export; optionally use
   `系统信息` for a separately labeled metadata capture if debugging setup.
2. On default, select A2 and run R01 then R02, **three repeats each**, with the
   same baseline settings. Compare engine UI/raster and vsync cadence plus A1
   commit intervals against A2. A2 additionally bins recorded display periods:
   0 commits = repeated, 1 = new, >=2 = overwritten. The auxiliary display
   link requests 60-120 Hz, preferred 120; it may itself sustain high refresh.
   Any A1/A2 difference must be reported as possible observer perturbation.
3. Export/retrieve, then install the signed `-cametal` variant over default.
   Verify retention and native inventory (`CAMetalLayer`, explicit `false`).
   Select B and set repeats to **1**. Run one R01 and one R02 as the single
   comparison set, keeping baseline settings. These B captures provide native
   evidence and engine comparison only; they do not replace default NC7
   repeats. The analyzer will label non-R11 single-repeat coverage unavailable.
4. Inspect `presentation.available`, `omission`, `samples`, `overflow`,
   `contentionDrops` and optional `unmatchedCallbacks`. In B, a positive
   `presentedTime` is system-reported presentation on this alternate path;
   zero means none observed by stop, including pending/lost callbacks. Never
   subtract native seconds from Dart timestamps or claim touch-to-photon.
5. Time box: **one device iteration with both variants, plus at most one fix
   iteration**. A fix build requires its own reviewed change and confirmed
   push. This document authorizes none. If usable data is still absent, record
   **unverified**, with the observed failure, build/run, inventory, sample/loss
   counts and omission. Do not extend the spike or change the product path.

Expected failure details include `requires_FlutterMetalLayer`,
`requires_cametal_variant`, `setContents_hook_unavailable`,
`nextDrawable_hook_unavailable`, `flutter_view_layer_unavailable`,
`no_native_samples`, `no_layer_commit_samples`, `no_display_link_samples`,
`no_presented_drawables_at_stop`, and Dart `missing_plugin_<method>` /
`platform_error_<method>`. Native source: `ios/Runner/AppDelegate.swift:190-315`;
Dart fallback: `method_channel_presentation_probe.dart:23-57`.

## 7. Retrieve exports and run the analyzer on Windows

After each set, wait for `已写入：<path>`. `写入 / 重试导出文件` writes
the last record again; earlier repeat files are already in Documents.
`复制简短摘要` copies the last record's filename, run/repeat/input, digest,
sample counts and evidence label, not the raw arrays. The summary is capped
at 4000 UTF-8 bytes. A copied summary alone cannot replace the export.

Use the route that actually worked in S1: **Files -> On My iPhone -> Shiori**,
long-press `shiori-reader-<BUILD_ID>-<runId>.json` -> **Share**, and transfer
it to Windows through the user's existing private file-transfer channel.
No USB route was used in S1. If sharing fails, preserve the file and record
the failure; an existing Apple Devices/iTunes file-sharing setup is an
unverified alternative for this S2 export.

Store received files under repository-root **`local-evidence/`**, which is
gitignored. Suggested private subfolders: `local-evidence/s2/default-a1/`,
`default-a2/`, `cametal-b/`, `manual-lifecycle/`, and separate fix-iteration
folders. Do not mix repeated attempts with duplicate repeat indices. Check
nonempty JSON, `kind = reader_feasibility`, `schemaVersion = 1`, filename vs
`engine.buildId`/`runId`, build number/pins, `bookSha256`, `fixtureId`,
`scenarioId`, `repeatIndex`/`repeatCount`, `input` and `presentation.mode`.
Match sample counts to the summary; retain raw arrays, declarations, errors,
omissions and all loss counters. Keep books, original names and text private.

From `D:/Projects/shiori`, this exact command checks the committed synthetic
example (it is **not device evidence**):

```powershell
dart run tool/diag/analyze_reader_export.dart --strict test/fixtures/reader/exports/passing-120hz-a1-1.json
```

For a retrieved default A1 set, after placing only that set's JSONs in the
suggested folder, run:

```powershell
$exports = @(Get-ChildItem -LiteralPath local-evidence/s2/default-a1 -Filter 'shiori-reader-*.json' -File | Sort-Object Name | Select-Object -ExpandProperty FullName)
if ($exports.Count -eq 0) { throw 'No reader exports in the selected set' }
dart run tool/diag/analyze_reader_export.dart --strict @exports
$LASTEXITCODE
```

Repeat with each other folder by changing `-LiteralPath`. The CLI accepts one
or more explicit paths; PowerShell builds that list instead of passing a
literal wildcard. Save analyzer output privately with its corresponding set.
`--strict` exits **1 for app/analyzer aggregate mismatches**, **65 for invalid
input/schema**, **64 for usage**, and **0 when aggregates match**, even if
measurement gates fail or remain unavailable. Review every printed gate row.

The report must use the raw-sample recomputation, not clipboard impressions:

| Report row | Evidence to enter after device runs |
| --- | --- |
| NC7 | Each default R01-R10 repeat separately, four R11 digests with >=50 accepted turns each, manual OS supplement, settings/limiter declarations and provenance. UI and raster each >=99% within 8333 us; no unexplained >=50 ms motion stall; warm admitted input -> first submission P95 <=16700 us; zero correctness failures; R10 >=100 accepted alternating turns and bounded caps/RSS trend. Report cold preparation, queue wait, fallback rate and omissions separately. |
| NC8 | Per-mode availability, inventory, sample/loss counts, A1 commits, A2 display-period bins and possible observer perturbation, B positive/zero drawable times and omissions, each at its actual evidence level. Missing data remains unverified with the observed failure. |
| NC9 | Review all nine rows independently; then record S4 GO / NO-GO and specific remaining S4 work. Until device review the decision stays explicitly undecided. |

The 5% RSS endpoint/projected-OLS rule is the analyzer's current observational
rule, to be judged against device data; it is not a new numerical threshold
specified by NC7. R10 begins cold and telemetry alone does not certify warm-up
or alternating-cycle completeness. Other scenarios with <100 accepted turns
normally cannot pass the resource row. Native clocks are separate from Dart,
engine frame IDs establish correlation only, and none of A1/A2/B establishes
product-path physical presentation or touch-to-photon latency.

Analyzer/contract sources: `tool/diag/analyze_reader_export.dart:8-39`,
`reader_export_data.dart:4-18`, `reader_export_report.dart:166-228`,
`test/fixtures/reader/exports/README.md:46-98`; export:
`reader_export_repository.dart:18-29,61-80`, recorder:
`reader_probe_recorder.dart:116-151`.

## 8. Troubleshooting

| Symptom | Action / evidence to retain |
| --- | --- |
| CI artifact exists but build failed / a variant missing | Check exit code and logs; retain failure. Do not sign a partial package. |
| 全能签 update/launch fails | Record actual identifier, same-identity check, tool version and non-sensitive error. Preserve retrieved exports; do not delete app/data to pass. |
| Files has no Shiori folder or books do not appear | Launch/export once; verify top-level `.epub` placement; use `选择书籍 / 刷新列表`; try the explicitly unverified import fallback in section 3. |
| `此书包含固定版式、竖排或从右至左布局，探针无法打开。可选择其他书籍。` | Recoverable unsupported layout. Record digest/reason; do not count an empty/failed open as a successful R11 run. |
| `无法打开、准备或证明阅读位置，请重试或选择其他书籍。` | Retain scenario/digest/conditions and any partial export; mark incomplete/failed evidence. Do not invent a restored position. |
| A1/A2/B unavailable | Check variant, exact layer class/flag, omission and loss counters; follow the one-plus-one iteration time box. |
| Script stops early or R11 minimum false | Retain partial JSON and stop reason; record missing workload/repeats. Do not combine incomplete R11 files into one qualifying run. |
| Export fails / no Windows file | Retry `写入 / 重试导出文件`; inspect Files and Share again; copy summary to identify the expected record. Keep retrieval pending if raw JSON is absent. |
| Analyzer exits 0 but prints fail/unavailable | Exit 0 is aggregate parity only. Transfer failed/unavailable rows unchanged into the device review. |

Stop at this handoff. CI, signing, device actions and the S4 decision are later
user-operated work after the confirmed push; spec updates belong to Phase F
part 2. No scope narrowing, lower frame target or alternate reader architecture
is implied by an unverified result.
