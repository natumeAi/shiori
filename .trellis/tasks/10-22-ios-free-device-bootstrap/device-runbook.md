# S1 device runbook

Prepared on 2026-10-22 for user-operated steps 7–10. Local source preparation
does not establish a cloud build, valid iPhone package, successful signing,
installation, cadence or data retention. Do not mark the child complete until
the observed results below are recorded. Raw device exports stay local.

## Build provenance and reviewed pins

| Item | Selected value | Verification |
| --- | --- | --- |
| Runner | Standard `macos-15` (arm64) | [runner label table](https://github.com/actions/runner-images/blob/main/README.md) |
| Xcode | `26.3`, `/Applications/Xcode_26.3.app/Contents/Developer` | [macOS 15 arm64 software list](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md) lists version/build/path |
| Flutter | `3.47.7` stable, arm64 | [official macOS release manifest](https://storage.googleapis.com/flutter_infra_release/releases/releases_macos.json), exact version/hash/architecture match |
| Framework | `abaf9c523780a608bd46686fd5e53740a07077f8` | Official manifest and `git ls-remote` for Flutter tag `3.47.7` |
| Engine | `deb287481e3ce9468f3434937ced4240a70539ca` | Local SDK metadata; script checks hosted `flutter --version --machine` |
| checkout | `3d3c42e5aac5ba805825da76410c181273ba90b1` (`v7.0.1`, Node 24) | Claude review: authenticated `gh api` and `git ls-remote` outside sandbox; action inputs/runtime checked |
| flutter-action | `1a449444c387b1966244ae4d4f8c696479add0b2` (`v2.23.0`, composite) | Claude review: authenticated `gh api` and `git ls-remote` outside sandbox; setup inputs checked |
| upload-artifact | `cf430e030ddbb5b0abf93d22962f4752f3646cd9` (`v7.0.2`, Node 24) | Claude review: authenticated `gh api` and `git ls-remote` outside sandbox; upload inputs checked |

The current action SHAs and input/runtime checks were supplied by Claude's
authenticated review outside this sandbox. This sandbox cannot verify GitHub
over TLS, so no independent remote re-verification is claimed and no sign-in
or persistent Git setting change was made. Checkout/upload use Node 24;
flutter-action is composite. The [pinned setup action](https://github.com/subosito/flutter-action/blob/1a449444c387b1966244ae4d4f8c696479add0b2/setup.sh)
receives explicit version/channel/architecture inputs. Its optional caches
are disabled; upload's `archive` input retains its default. Installation on a hosted runner remains
unverified. Runner labels identify a rolling image; `provenance.json` and
`toolchain.txt` record the actual image, macOS, Xcode, SDK and engine.

## Publish a reviewed build branch (separate approval required)

1. Review the complete local diff and the local quality report. Complete the
   later Trellis commit phase separately; this handoff makes no commit.
   Include only approved task files. Existing parent/child planning files
   need their own review before inclusion. Never stage personal diagnostics,
   credentials, server settings or books.
2. Obtain chat confirmation for the exact public push, including branch and
   commit. The repository is public. Use a dedicated `ios-build/s1-...` branch;
   never push this experiment to `master` without separate approval. Example
   commands **after commit review and that push confirmation**:

   ```powershell
   git switch -c ios-build/s1-probe-01
   git log -1 --oneline
   git push -u origin ios-build/s1-probe-01
   ```

3. That push starts **Unsigned iPhone probe** automatically. Open
   [repository Actions](https://github.com/natumeAi/shiori/actions) and select
   the run for the pushed commit/branch. No Apple credentials are used in CI.
   `workflow_dispatch` is also available when GitHub exposes the workflow on
   the default branch: select the build branch in **Run workflow**. The push
   trigger avoids depending on first-run dispatch availability. Do not merge
   to `master` just to obtain the dispatch button.
4. A failed setup/build is a failed BC1. Keep its logs/evidence; do not sign a
   partial artifact. Re-check current runner software if a pinned Xcode was
   removed. Do not switch to paid runners/minutes. A blocked primary route
   requires a reviewed Codemagic fallback configuration.

## Download and verify

1. From a successful run, download `shiori-probe-<full sha>-gha-<run number>`
   within 14 days. Extract the GitHub artifact ZIP to a local folder. Inside,
   locate `shiori-probe-<12-character sha>-gha-<run number>.ipa`.
2. Match the Actions commit and run number with `provenance.json`, the job
   summary and `toolchain.txt`. `build-exit-code.txt` must be `0`.
   `bundle-info.txt` must show `DTPlatformName=iphoneos`,
   `CFBundleIdentifier=io.github.natumeai.shiori` and a `CFBundleVersion`
   matching the run number. The successful log must include the executable
   and both framework arm64 checks, plus ZIP integrity validation.
3. Compare `(Get-FileHash -Algorithm SHA256 <ipa path>).Hash` with the first
   field of `sha256.txt` (case-insensitive). The path in that text file is the
   runner path. Inspect the IPA as a ZIP with an archive viewer: it contains
   `Payload/Runner.app/Info.plist`, its executable and
   `Frameworks/{Flutter,App}.framework` with nonempty binaries. A matching
   checksum establishes artifact consistency, not trust in an unrelated run.
4. Review `ios-status.txt` and `ios-project.diff` even when the build passed.
   Flutter may migrate native integration on macOS. Review tracked patches
   before applying locally. Newly generated, nonignored native files are saved
   in `ios-untracked.zip` when present, with paths relative to the repository
   root; extract to a separate review folder and compare with the status list
   before copying approved files into the project. The ZIP preserves hidden
   paths that the artifact uploader otherwise excludes. Commit approved native changes only in a
   later authorized phase. Do not silently accept recurrent migrations.

## Signing and first launch

**Chosen route (user decision, 2026-10-22):** sign on the iPhone with 全能签
using a certificate (`.p12` + `.mobileprovision`) that a third party supplied
to the user. The user performs all signing; the certificate, its password and
the provisioning profile never enter this repository, CI, chat or agent
tooling (`.gitignore` blocks `*.p12`, `*.mobileprovision`, `*.cer`).

1. Note the certificate type shown by 全能签 or the profile: enterprise /
   distribution (ad hoc) or development, its team name/ID and expiry date.
   A development profile needs Settings → Privacy & Security → Developer Mode;
   an enterprise profile needs Settings → General → VPN & Device Management →
   trust the developer. An ad hoc or development profile must contain this
   iPhone's UDID.
2. Import the verified IPA into 全能签 through any import route it offers
   (Files app share sheet, cloud drive and so on). Keep the bundle identifier
   `io.github.natumeai.shiori` unless the profile is not a wildcard and forces
   its own App ID; record the identifier actually installed. Do not change the
   app name or version, and leave every dylib/plugin injection or patch option
   off: injected code would change both behavior and timing evidence.
3. Install, then launch Shiori from the home screen with no debugger. Match the
   visible build ID/build number to provenance, then close/reopen once.
   Release AOT needs no JIT setup. Record success or the exact failure
   separately from CI success.

Updates keep app data only while the **same certificate team** signs the same
identifier: iOS refuses to upgrade an app whose `application-identifier`
entitlement (team prefix + bundle ID) differs from the installed one, so a
different team's certificate means deleting the app and its data. Shared
third-party certificates can also be revoked at any time, which stops the app
from launching until it is re-signed. Before switching certificates in later
stages, make sure nothing pending (for example unsent reading activity) lives
only on the phone.

### Alternative: AltStore Classic

Use **AltStore Classic**, not AltStore PAL. Follow the official
[Windows installation guide](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)
for current download links and setup: install Apple's direct-download iTunes
and iCloud, install/run AltServer, connect and unlock the phone over USB,
complete device trust and enable Wi-Fi sync. The user handles Apple sign-in
locally, AltStore installation and profile trust. On iOS 16+, enable
Settings → Privacy & Security → Developer Mode and complete its restart and
confirmation. Record tool versions and actual iOS version. If existing Apple
software conflicts, consult the official
[troubleshooting guide](https://faq.altstore.io/altstore-classic/troubleshooting-guide)
before changing the machine's setup. This runbook does not claim Apple Devices
and AltServer's required iTunes stack coexist on this PC.

Before importing: check **My Apps** for a free active-app slot (AltStore counts
toward the documented three-app limit) and **View App IDs** for enough IDs
under the ten-ID limit. IDs expire after a week; wait if quota is exhausted.
Do not invent variant bundle identifiers to bypass it.
[AltStore account/App ID documentation](https://faq.altstore.io/altstore-classic/app-ids),
[active apps and refresh](https://faq.altstore.io/altstore-classic/your-altstore).

Transfer the verified IPA to a local Files location on the iPhone (for example
iCloud Drive used by the user). With AltServer running and the phone connected,
open Classic → My Apps → **+**, choose that IPA, and complete the tool's signing
prompts. This picker path and this Flutter package's compatibility must be
confirmed on the user's installed tool version. Retain any signing error.
Record the actual installed identifier/team shown by the signing tool; it may
rewrite the source identifier. Keep the same tool, Apple ID and installed
identity for the second build. Never delete an existing app/data container to
make installation appear successful.

Launch Shiori from the home screen with no debugger. Match the visible build
ID/build number to provenance, then close/reopen once. Release AOT needs no JIT
setup. Record success or the exact launch failure separately from CI success.

## Before each capture

- Set Low Power Mode **off**.
- Set Settings → Accessibility → Motion → Limit Frame Rate **off**.
- Note whether the phone is charging and whether it feels warm.
- Enter all four declarations in the probe; use **unknown** when uncertain.
  Record the device model as user-declared, actual iOS, viewport and DPR.
- Keep a run with a limiter on as separately labeled evidence. A reported
  refresh rate is metadata, not the measured effective rate.

Create/save a non-sensitive marker such as `s1-retention-01`; reopen and verify
it reloads. Start the synthetic transform capture, let the bounded animation
run, stop, and wait for drain/finalization and its automatic export. Use the
export button to retry writing the same record if needed. Also exercise a
short manual stop and background/foreground interruption. Export the finished
or partial capture and copy its summary. Note build ID, run ID, sample counts,
cadence classification, overflow/omissions, clock correlation, trailing-batch
flags and filename. Missing samples remain an explicit limitation.

## Retrieve evidence over USB

Without a USB route, open the iOS Files app → On My iPhone → Shiori, long-press
`shiori-diag-<BUILD_ID>-<runId>.json` → Share, and send it to the Windows PC
through any channel the user already uses (WeChat/QQ file transfer, email to
self, a cloud drive). The export holds device/run metadata and timings only.

With the phone unlocked/trusted and connected, in **Apple Devices → Files →
Shiori**, select `shiori-diag-<BUILD_ID>-<runId>.json` and **Save** to a private
local folder. If using the iTunes stack instead, select the device → **File
Sharing → Shiori**, select the JSON and **Save**, or drag it to a local folder.
Record which application/version actually worked.
[Apple Devices instructions](https://support.apple.com/en-us/120402),
[iTunes instructions](https://support.apple.com/en-us/120403).

Check the retrieved JSON parses and is nonempty. Match build/run/filename and
sample counts against the copied summary. Keep raw timing arrays and settings
with the record. Application Support contains marker/last record; Documents
contains only user exports. Files → On My iPhone → Shiori is an additional
device-side check, not a substitute for the USB retrieval test.

Motion samples capture timestamps/progress in the ticker and obtain the same
engine frame number in a post-frame callback. Match that number with each
timing sample; raw scheduler timestamps are vsync targets, while `vsyncStart`
is the start, so timestamp equality is not a valid correlation. A negative
frame number is unavailable, excluded from matching and explicitly reported.
Cadence intervals require consecutive frame numbers present in both streams;
a missing engine/motion frame breaks adjacency. On device, confirm nonzero
correlated samples and UI/raster distributions without treating any synthetic
fixture result as proof of device availability.

Engine UI/raster durations and consecutive `vsyncStart` intervals are engine
evidence only. `totalSpan` is pipeline latency. Callback arrival is not frame
presentation. No result here proves physical 120 FPS, input-to-photon latency
or EPUB reader performance. Keep presentation evidence explicitly unverified.

## Second build, update and refresh

1. Preserve the marker and first export. Make a second reviewed source build
   on the same workflow with a higher run number and unchanged source bundle
   identifier. Obtain confirmation for that exact additional public push.
2. Repeat provenance/checksum validation. Sign the second build in 全能签 with
   the **same certificate and profile** and install it over the first build;
   do not delete the app to pass this test. Verify the new visible build
   ID/number, unchanged installed identity, home-screen launch and the exact
   marker value after reopening.
3. 全能签 route: there is no seven-day refresh. Record the certificate expiry
   date instead, and treat "refresh" as re-signing the same build with the
   same certificate: reinstall over the existing app and verify marker plus
   last record again. Revocation or a certificate from another team is out of
   scope for BC4 and must be reported as such, not hidden.
4. AltStore alternative: keep AltServer running and USB connected (same-network Wi-Fi is also
   supported). In Classic, use **Refresh All**; record renewed expiry and any
   error, then reopen Shiori and verify marker plus last record. AltStore's
   documented signing period is seven days. An immediate refresh test does
   not establish behavior after an unobserved seven-day expiration.
   [AltServer connectivity](https://faq.altstore.io/altstore-classic/altserver),
   [refresh behavior](https://faq.altstore.io/altstore-classic/your-altstore).

## Results to fill in

Use `pass`, `fail`, `partial` or `unverified`, with local evidence references.
Do not attach personal raw exports to public task files.

| Criterion | Current status | Evidence/results to enter |
| --- | --- | --- |
| BC1: unsigned cloud device build/package | Pass (2026-10-22) | [Run 39739387588](https://github.com/natumeAi/shiori/actions/runs/39739387588), commit `9472fa0`, build ID `9472fa0b319d-gha-3`; `macos-15` image 20260907.0337.1, macOS 15.7.9, Xcode 26.3 (17C529), iOS SDK 26.2, Flutter 3.47.7 framework `abaf9c5…`, engine `deb2874…`; `Runner`, `Flutter.framework`, `App.framework` arm64; `iphoneos`, `io.github.natumeai.shiori`, `CFBundleVersion` 3, `MinimumOSVersion` 15.0, file-sharing keys present; IPA SHA-256 `955c8601…dd98` (re-checked after download); `ios-status.txt` and `ios-project.diff` empty, no untracked native files. Earlier runs 39738427751 (reserved `FLUTTER_VERSION` define) and 39738887388 (`lipo` argument order) failed and were fixed. |
| BC2: signed install and independent launch | Pass (2026-10-22) | iPhone 14 Pro Max, iOS 27.0.1 (24A446); 全能签 V7.7.3 with a third-party Apple Distribution ad hoc certificate expiring 2027-05-15 (holder, team and device UDID deliberately not recorded in this public file); installed identifier `io.github.natumeai.shiori` unchanged; app launched without a debugger and showed `9472fa0b319d-gha-3` / build 3. 全能签 also rewrote `MinimumOSVersion` to 10.0, removed device-family limits and re-enabled file access (Info.plist only, no injection). |
| BC3: capture and JSON retrieval | Pass (2026-10-22, build 4) | Run `1792655209047637-1` on `5624af50f176-gha-4`: raw `shiori-diag-5624af50f176-gha-4-1792655209047637.json` (846 KB) shared from the Files app to Windows and kept outside the repository. Release build, 15001 ms `duration_limit` capture, declarations Low Power/Limit Frame Rate/charging/warm all `off`, reported refresh 120, viewport 430×932 @3x. 1822 engine frames, 1797 motion samples, all 1797 correlated by engine frame number, no frame-number gaps, no negative identities, `errors` empty, overflow 0, 2 reports during drain, 25 frames outside motion, `incompleteTrailingBatch` true by design. Raw scheduler target minus engine vsync start = 8333–8334 µs, confirming the target/start difference that motivated frame-number correlation. Independent recomputation from raw samples matches the app aggregates exactly: UI P50/P95/P99/max 353/406/1256/12715 µs (1 over 8333, frame 0 at capture start); raster 799/916/1003/2927 µs (0 over); vsync intervals 8339/8402/8458/25118 µs, 1795 of 1796 within 7–10 ms, `atLeast12500Us` 1 (two vsyncs missed right after the 12.7 ms start-transition frame, none afterwards), `observed_near_120hz`. Flutter 3.47.7 / `abaf9c5237` / `deb287481e` reported through `FlutterVersion`. Earlier partial run on build 3: `1792654511245323-1`: 1821 engine frames, 1796 motion samples, 1796 frame-number-correlated (`engine_frame_number_identity`), overflow 0, `incompleteTrailingBatch` true by design. UI P50/P95/P99/max 313/358/630/11612 µs (1 over 8333); raster 736/834/910/18266 µs (2 over); vsync intervals P50/P95/P99/max 8339/8403/8457/25060 µs, `observed_near_120hz`. Declarations were left `unknown`. Clipboard summary received; the raw file `shiori-diag-9472fa0b319d-gha-3-1792654511245323-1.json` has not been retrieved (no USB; Files-app share is the alternative). `vsyncIntervals.over8333Us` = 1143 counts normal jitter above 8333 µs, not missed frames; missed-vsync counting needs a ≥12500 µs threshold. |
| BC4: same-identity update and refresh retention | Pass (2026-10-22) | Marker saved in build 3 (`9472fa0b319d-gha-3`); build 4 (`5624af50f176-gha-4`, [run 39742052566](https://github.com/natumeAi/shiori/actions/runs/39742052566), IPA SHA-256 `3f7dffd6…c0ca0a`) signed in 全能签 with the same certificate and installed over it without deleting the app: marker unchanged. The same build re-signed with the same certificate and reinstalled: marker unchanged. Certificate expiry 2027-05-15. Not tested: expiry, revocation, or a different certificate team (would require deleting the app). |
| BC5: local source quality and ordinary entry point | Pass locally: 91 tests, analyze/format/codegen/syntax green (commit `5624af5`) | Command exit codes/tails in local-validation.md and quality-gate-results.json for the original diff; reruns after each later fix were clean; existing ordinary app tests unchanged |
| BC6: independent feasibility outcomes | Pass (2026-10-22) | See the feasibility matrix below. |

### Feasibility matrix

| Row | Outcome |
| --- | --- |
| Free cloud device build | Pass: GitHub Actions `macos-15`, no secrets, Xcode build about 70 s |
| Signing and independent launch | Pass: 全能签 + third-party Apple Distribution ad hoc certificate |
| Update with retained data | Pass: same certificate, build 3 → 4 and same-build re-sign |
| Seven-day / expiry / revocation behavior | Unverified: certificate expires 2027-05-15; revocation risk documented |
| Raw export retrieval | Pass: Files-app share (no USB) |
| Engine timing data on device | Pass: complete, frame-number correlated, matches independent recomputation |
| Engine cadence | Observed near 120 Hz with declared limiters off; one start-transition miss, none in steady state |
| Physical presentation / touch-to-photon | Unverified: no supported route in this setup yet; S2 must investigate before any parent AC4 claim |
| EPUB reader performance | Not in S1 scope |

Current boundary: S1 acceptance BC1–BC6 is met on branch
`ios-build/s1-probe`, with physical presentation explicitly unverified. On this
Windows machine `gh run download` stalled while a direct download of the same
artifact took about 4 seconds, so download the artifact from the run page in a
browser if the CLI hangs.
