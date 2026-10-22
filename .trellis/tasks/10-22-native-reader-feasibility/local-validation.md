# S2 local validation

Local commands only. No push, workflow trigger, signing, or device run.

## Phase 0 preflight

- Initial branch: `ios-build/s1-probe`; HEAD:
  `a570cfc2b687f7e2651a2c6718f55bb97713473f`.
- Initial status: only the existing parent `implement.md`, parent `task.json`,
  and untracked S2 task directory. Their existing content was preserved.
- Parent verified the read-only reference checkout clean at
  `a4bda23fd3e82e285a22566d88576e67d3e8756b` (exit 0).
- `git switch -c ios-build/s2-reader-probe`: sandbox attempt exit 128
  (`cannot lock ref ... Permission denied`); identical escalated command exit 0
  (`Switched to a new branch 'ios-build/s2-reader-probe'`).
- The first sandbox run of `run_local_gate.py 0` stalled at
  `dart run build_runner build` before launching a Dart process. Read-only
  elevated process inspection confirmed only its `cmd.exe` child was present.
  The verified S2 Python process tree was terminated (taskkill exit 0;
  gate wrapper exit 1), so no command result or test failure is inferred from
  that incomplete attempt. The same gate is rerun with SDK cache/process access
  outside the sandbox below. No SDK or OS setting was changed.
- `tool/diag` does not exist at the baseline. The requested formatter command
  is retained verbatim; its exit and output are recorded below.

## Phase 0 — 2026-10-22T08:16:20.539863+00:00

All commands run at the repository root with explicit timeouts.

### `dart run build_runner build`

Exit: 0; timeout: 900 s; duration: 2.571 s; timed out: False.

```text
  0s riverpod_generator on 53 inputs; lib/app/app.dart
  0s riverpod_generator on 53 inputs: 53 skipped
  0s freezed on 53 inputs; lib/app/app.dart
  0s freezed on 53 inputs: 53 skipped
  0s json_serializable on 106 inputs; lib/app/app.dart
  0s json_serializable on 106 inputs: 106 skipped
  0s go_router_builder on 106 inputs; lib/app/app.dart
  0s go_router_builder on 106 inputs: 106 skipped
  0s source_gen:combining_builder on 106 inputs; lib/app/app.dart
  0s source_gen:combining_builder on 106 inputs: 106 skipped
  Built with build_runner/aot in 1s; wrote 0 outputs.
```

### `dart format --set-exit-if-changed lib test tool/diag`

Exit: 0; timeout: 180 s; duration: 0.768 s; timed out: False.

```text
No file or directory found at "tool/diag".
Formatted 70 files (0 changed) in 0.11 seconds.
```

### `flutter analyze`

Exit: 0; timeout: 180 s; duration: 3.801 s; timed out: False.

```text
Analyzing shiori...
No issues found! (ran in 1.8s)
```

### `flutter test`

Exit: 0; timeout: 900 s; duration: 6.452 s; timed out: False.

```text
00:00 +69: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:00 +70: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:00 +71: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:00 +72: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:00 +73: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:00 +74: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:00 +75: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:00 +76: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:00 +77: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:01 +78: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: shows loading then retained marker and saves edits
00:01 +79: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: shows loading then retained marker and saves edits
00:01 +80: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: shows loading then retained marker and saves edits
00:01 +81: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: storage error has localized retry and recovery
00:01 +82: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: capture stops, drains, exports and copies matching summary
00:02 +83: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: motion reads current engine identity only after ticker callbacks
00:02 +84: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: queued motion is ignored after same-frame lifecycle stop
00:02 +85: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: dispose before queued post-frame motion never reads identity
00:02 +86: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: auto duration stops animation and background never restarts capture
00:02 +87: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: failed export preserves partial record and can retry
00:02 +88: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: declaration edits are frozen into the captured record
00:03 +89: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: dispose during async export does not publish stale UI
00:03 +90: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: marker save error remains editable at 200 percent text scale
00:03 +91: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: (tearDownAll)
00:03 +91: All tests passed!
```

## Phase 0 pre-commit review

Trellis checker: PASS. Verified branch/HEAD, phase-scoped file inventory, gate evidence consistency, Python harness syntax, and git diff --check (exit 0). No fixes required. Existing parent planning contents were preserved.

## Phase A — check-reference

`npm.cmd run check-reference` in tool/oracle.

Exit 0; timeout 180 s; duration 0.417 s.

```text

> shiori-reader-oracle@1.0.0 check-reference
> node src/check-reference.mjs

PASS client/src/utils/canonicalText.ts 6eb746b7fe90914094f08fe6ac3616e9f8ba3321547285ea483f317e6e72eeff
PASS client/src/reader/contentSecurity.ts 9e49bd543b4261dd689ca0efb8fd61981624fe3c6d7d11d28cfca0b33fcd43ca
PASS client/src/reader/visiblePageAnchor.ts 14870e5b4848bf85d9c085cf2c1b6486e41b998d09487d2957c6a97cad5f7bc8
PASS shared/src/readingStats.ts c48fad4df03ec20d96f3caf40650c558fe49218afc8dcd0021ee68e87b75325d
```

## Phase A — ci

`npm.cmd ci --no-audit --no-fund --fetch-retries=0 --fetch-timeout=45000` in tool/oracle.

Exit 0; timeout 180 s; duration 0.775 s.

```text

added 6 packages in 612ms
npm warn allow-scripts 1 package has install scripts not yet covered by allowScripts:
npm warn allow-scripts   esbuild@0.28.2 (postinstall: node install.js)
npm warn allow-scripts
npm warn allow-scripts Run `npm approve-scripts --allow-scripts-pending` to review, or `npm approve-scripts <pkg>` to allow.
```

## Phase A — build-fixtures-1

`npm.cmd run build-fixtures` in tool/oracle.

Exit 0; timeout 180 s; duration 0.263 s.

```text

> shiori-reader-oracle@1.0.0 build-fixtures
> node src/build-fixtures.mjs

cfi-structure: 2524 bytes
chapters: 27798 bytes
html-fallback: 4489 bytes
images: 11877 bytes
inert-content: 10682 bytes
long-content: 778175 bytes
one-page: 2131 bytes
opf-variants: 4271 bytes
styles: 188561 bytes
unicode: 2368 bytes
unsupported-fixed: 2327 bytes
unsupported-rtl: 2239 bytes
unsupported-vertical: 2338 bytes
```

## Phase A — vectors-1

`npm.cmd run vectors` in tool/oracle.

Exit 0; timeout 180 s; duration 13.601 s.

```text

> shiori-reader-oracle@1.0.0 vectors
> node src/run-oracle.mjs vectors

webkit 27.2
chromium 156.0.8078.4
cfi-structure webkit: 1 sections
cfi-structure chromium: 1 sections
chapters webkit: 16 sections
chapters chromium: 16 sections
html-fallback webkit: 5 sections
html-fallback chromium: 5 sections
images webkit: 3 sections
images chromium: 3 sections
inert-content webkit: 1 sections
inert-content chromium: 1 sections
long-content webkit: 3 sections
long-content chromium: 3 sections
one-page webkit: 1 sections
one-page chromium: 1 sections
opf-variants webkit: 4 sections
opf-variants chromium: 4 sections
styles webkit: 1 sections
styles chromium: 1 sections
unicode webkit: 1 sections
unicode chromium: 1 sections
unsupported-fixed webkit: 1 sections
unsupported-fixed chromium: 1 sections
unsupported-rtl webkit: 1 sections
unsupported-rtl chromium: 1 sections
unsupported-vertical webkit: 1 sections
unsupported-vertical chromium: 1 sections
```

## Phase A — build-fixtures-2

`npm.cmd run build-fixtures` in tool/oracle.

Exit 0; timeout 180 s; duration 0.277 s.

```text

> shiori-reader-oracle@1.0.0 build-fixtures
> node src/build-fixtures.mjs

cfi-structure: 2524 bytes
chapters: 27798 bytes
html-fallback: 4489 bytes
images: 11877 bytes
inert-content: 10682 bytes
long-content: 778175 bytes
one-page: 2131 bytes
opf-variants: 4271 bytes
styles: 188561 bytes
unicode: 2368 bytes
unsupported-fixed: 2327 bytes
unsupported-rtl: 2239 bytes
unsupported-vertical: 2338 bytes
```

## Phase A — vectors-2

`npm.cmd run vectors` in tool/oracle.

Exit 0; timeout 180 s; duration 15.092 s.

```text

> shiori-reader-oracle@1.0.0 vectors
> node src/run-oracle.mjs vectors

webkit 27.2
chromium 156.0.8078.4
cfi-structure webkit: 1 sections
cfi-structure chromium: 1 sections
chapters webkit: 16 sections
chapters chromium: 16 sections
html-fallback webkit: 5 sections
html-fallback chromium: 5 sections
images webkit: 3 sections
images chromium: 3 sections
inert-content webkit: 1 sections
inert-content chromium: 1 sections
long-content webkit: 3 sections
long-content chromium: 3 sections
one-page webkit: 1 sections
one-page chromium: 1 sections
opf-variants webkit: 4 sections
opf-variants chromium: 4 sections
styles webkit: 1 sections
styles chromium: 1 sections
unicode webkit: 1 sections
unicode chromium: 1 sections
unsupported-fixed webkit: 1 sections
unsupported-fixed chromium: 1 sections
unsupported-rtl webkit: 1 sections
unsupported-rtl chromium: 1 sections
unsupported-vertical webkit: 1 sections
unsupported-vertical chromium: 1 sections
```

## Phase A — local-books

`npm.cmd run vectors-local -- "D:\Projects\lan-reader\docs\[入间人间].电波女与青春男 外传 8月×日 今夜星光必将灿烂（网翻）.epub" "D:\Projects\lan-reader\docs\[入间人间].电波女与青春男~外传 请让我回家（网翻）.epub" D:\Projects\lan-reader\docs\和非常可爱的我交往吧！_短篇.epub "D:\Projects\lan-reader\docs\综上所述，我们证明了初恋 - 02.epub"` in tool/oracle.

Exit 0; timeout 600 s; duration 159.495 s.

```text

> shiori-reader-oracle@1.0.0 vectors-local
> node src/run-oracle.mjs vectors-local D:\Projects\lan-reader\docs\[入间人间].电波女与青春男 外传 8月×日 今夜星光必将灿烂（网翻）.epub D:\Projects\lan-reader\docs\[入间人间].电波女与青春男~外传 请让我回家（网翻）.epub D:\Projects\lan-reader\docs\和非常可爱的我交往吧！_短篇.epub D:\Projects\lan-reader\docs\综上所述，我们证明了初恋 - 02.epub

webkit 27.2
chromium 156.0.8078.4
6e4ed2a78ea62c9fc610545070626e8d816acdd9a9bcbe9373736eec18a15210 webkit: 3 sections
6e4ed2a78ea62c9fc610545070626e8d816acdd9a9bcbe9373736eec18a15210 chromium: 3 sections
aac482b2d33f76c1994f6c9bb728f8e93649211d8f5a5d23b3b20326086107d8 webkit: 3 sections
aac482b2d33f76c1994f6c9bb728f8e93649211d8f5a5d23b3b20326086107d8 chromium: 3 sections
a595d98d44007a7ce905e449c7342688211f934044527dfa3bb176d5df723160 webkit: 33 sections
a595d98d44007a7ce905e449c7342688211f934044527dfa3bb176d5df723160 chromium: 33 sections
9bfc26bc676d2175697e47bcdb5d803461626a55264bdf4054a6f5af939af2e0 webkit: 21 sections
9bfc26bc676d2175697e47bcdb5d803461626a55264bdf4054a6f5af939af2e0 chromium: 21 sections
```

## Phase A fixture source checks and timezone reproducibility

Parent fixture static check exited 0: all 39 referenced section sources exist; expected XML sections parse with ElementTree (the deliberate HTML-fallback group is excluded); Unicode source bytes retain CRLF and bare CR.

The first two clean build-fixtures + vectors runs matched SHA-256 for all 43 generated files (exit 0). Review then found fflate uses local calendar getters for ZIP DOS timestamps. The builder now uses a fixed local Date rather than a UTC instant. Both `TZ=UTC node src/build-fixtures.mjs` and `TZ=Asia/Hong_Kong node src/build-fixtures.mjs` exited 0 with 180 s timeouts; all 14 generated asset files are byte-identical. See oracle-timezone-reproducibility.json. The final clean vector comparison below supersedes pre-fix archive digests.

### npm install --no-audit --no-fund --fetch-retries=0 --fetch-timeout=45000

Exit 0; timeout 180 s; duration 2.25 s. Package/browser versions are recorded in tool/oracle/README.md.

### npx playwright install webkit chromium

Exit 0; timeout 240 s; duration 32.294 s. Package/browser versions are recorded in tool/oracle/README.md.

## Phase A — vectors-final-1

`npm.cmd run vectors` in tool/oracle.

Exit 0; timeout 180 s; duration 11.237 s.

```text

> shiori-reader-oracle@1.0.0 vectors
> node src/run-oracle.mjs vectors

webkit 27.2
chromium 156.0.8078.4
cfi-structure webkit: 1 sections
cfi-structure chromium: 1 sections
chapters webkit: 16 sections
chapters chromium: 16 sections
html-fallback webkit: 5 sections
html-fallback chromium: 5 sections
images webkit: 3 sections
images chromium: 3 sections
inert-content webkit: 1 sections
inert-content chromium: 1 sections
long-content webkit: 3 sections
long-content chromium: 3 sections
one-page webkit: 1 sections
one-page chromium: 1 sections
opf-variants webkit: 4 sections
opf-variants chromium: 4 sections
styles webkit: 1 sections
styles chromium: 1 sections
unicode webkit: 1 sections
unicode chromium: 1 sections
unsupported-fixed webkit: 1 sections
unsupported-fixed chromium: 1 sections
unsupported-rtl webkit: 1 sections
unsupported-rtl chromium: 1 sections
unsupported-vertical webkit: 1 sections
unsupported-vertical chromium: 1 sections
```

## Phase A — build-fixtures-final-1

`npm.cmd run build-fixtures` in tool/oracle.

Exit 0; timeout 180 s; duration 0.254 s.

```text

> shiori-reader-oracle@1.0.0 build-fixtures
> node src/build-fixtures.mjs

cfi-structure: 2603 bytes
chapters: 27807 bytes
html-fallback: 4489 bytes
images: 11877 bytes
inert-content: 10682 bytes
long-content: 778175 bytes
one-page: 2131 bytes
opf-variants: 3665 bytes
styles: 360564 bytes
unicode: 2368 bytes
unsupported-fixed: 2327 bytes
unsupported-rtl: 2239 bytes
unsupported-vertical: 2338 bytes
```

## Phase A — vectors-reviewed-1

`npm.cmd run vectors` in tool/oracle.

Exit 0; timeout 180 s; duration 11.974 s.

```text

> shiori-reader-oracle@1.0.0 vectors
> node src/run-oracle.mjs vectors

webkit 27.2
chromium 156.0.8078.4
cfi-structure webkit: 1 sections
cfi-structure chromium: 1 sections
chapters webkit: 16 sections
chapters chromium: 16 sections
html-fallback webkit: 5 sections
html-fallback chromium: 5 sections
images webkit: 3 sections
images chromium: 3 sections
inert-content webkit: 1 sections
inert-content chromium: 1 sections
long-content webkit: 3 sections
long-content chromium: 3 sections
one-page webkit: 1 sections
one-page chromium: 1 sections
opf-variants webkit: 4 sections
opf-variants chromium: 4 sections
styles webkit: 1 sections
styles chromium: 1 sections
unicode webkit: 1 sections
unicode chromium: 1 sections
unsupported-fixed webkit: 1 sections
unsupported-fixed chromium: 1 sections
unsupported-rtl webkit: 1 sections
unsupported-rtl chromium: 1 sections
unsupported-vertical webkit: 1 sections
unsupported-vertical chromium: 1 sections
```

## Phase A — verify-vectors

`npm.cmd run verify-vectors` in tool/oracle.

Exit 0; timeout 180 s; duration 0.346 s.

```text

> shiori-reader-oracle@1.0.0 verify-vectors
> node src/verify-vectors.mjs

PASS 13 EPUBs; 39 sections; 4807 CFI samples per engine; nested nav/NCX, literal Blob prose and resource aliases verified.
```

## Phase A — final-clean-1-build-fixtures

`npm.cmd run build-fixtures` in tool/oracle.

Exit 0; timeout 180 s; duration 0.246 s.

```text

> shiori-reader-oracle@1.0.0 build-fixtures
> node src/build-fixtures.mjs

cfi-structure: 2603 bytes
chapters: 27807 bytes
html-fallback: 4489 bytes
images: 11877 bytes
inert-content: 10682 bytes
long-content: 778175 bytes
one-page: 2131 bytes
opf-variants: 3665 bytes
styles: 360564 bytes
unicode: 2368 bytes
unsupported-fixed: 2327 bytes
unsupported-rtl: 2239 bytes
unsupported-vertical: 2338 bytes
```

## Phase A — final-clean-1-vectors

`npm.cmd run vectors` in tool/oracle.

Exit 0; timeout 180 s; duration 12.224 s.

```text

> shiori-reader-oracle@1.0.0 vectors
> node src/run-oracle.mjs vectors

webkit 27.2
chromium 156.0.8078.4
cfi-structure webkit: 1 sections
cfi-structure chromium: 1 sections
chapters webkit: 16 sections
chapters chromium: 16 sections
html-fallback webkit: 5 sections
html-fallback chromium: 5 sections
images webkit: 3 sections
images chromium: 3 sections
inert-content webkit: 1 sections
inert-content chromium: 1 sections
long-content webkit: 3 sections
long-content chromium: 3 sections
one-page webkit: 1 sections
one-page chromium: 1 sections
opf-variants webkit: 4 sections
opf-variants chromium: 4 sections
styles webkit: 1 sections
styles chromium: 1 sections
unicode webkit: 1 sections
unicode chromium: 1 sections
unsupported-fixed webkit: 1 sections
unsupported-fixed chromium: 1 sections
unsupported-rtl webkit: 1 sections
unsupported-rtl chromium: 1 sections
unsupported-vertical webkit: 1 sections
unsupported-vertical chromium: 1 sections
```

## Phase A — final-clean-1-verify-vectors

`npm.cmd run verify-vectors` in tool/oracle.

Exit 0; timeout 180 s; duration 0.343 s.

```text

> shiori-reader-oracle@1.0.0 verify-vectors
> node src/verify-vectors.mjs

PASS 13 EPUBs; 39 sections; 4807 CFI samples per engine; nested nav/NCX, literal Blob prose and resource aliases verified.
```

## Phase A — final-clean-2-build-fixtures

`npm.cmd run build-fixtures` in tool/oracle.

Exit 0; timeout 180 s; duration 0.247 s.

```text

> shiori-reader-oracle@1.0.0 build-fixtures
> node src/build-fixtures.mjs

cfi-structure: 2603 bytes
chapters: 27807 bytes
html-fallback: 4489 bytes
images: 11877 bytes
inert-content: 10682 bytes
long-content: 778175 bytes
one-page: 2131 bytes
opf-variants: 3665 bytes
styles: 360564 bytes
unicode: 2368 bytes
unsupported-fixed: 2327 bytes
unsupported-rtl: 2239 bytes
unsupported-vertical: 2338 bytes
```

## Phase A — final-clean-2-vectors

`npm.cmd run vectors` in tool/oracle.

Exit 0; timeout 180 s; duration 11.929 s.

```text

> shiori-reader-oracle@1.0.0 vectors
> node src/run-oracle.mjs vectors

webkit 27.2
chromium 156.0.8078.4
cfi-structure webkit: 1 sections
cfi-structure chromium: 1 sections
chapters webkit: 16 sections
chapters chromium: 16 sections
html-fallback webkit: 5 sections
html-fallback chromium: 5 sections
images webkit: 3 sections
images chromium: 3 sections
inert-content webkit: 1 sections
inert-content chromium: 1 sections
long-content webkit: 3 sections
long-content chromium: 3 sections
one-page webkit: 1 sections
one-page chromium: 1 sections
opf-variants webkit: 4 sections
opf-variants chromium: 4 sections
styles webkit: 1 sections
styles chromium: 1 sections
unicode webkit: 1 sections
unicode chromium: 1 sections
unsupported-fixed webkit: 1 sections
unsupported-fixed chromium: 1 sections
unsupported-rtl webkit: 1 sections
unsupported-rtl chromium: 1 sections
unsupported-vertical webkit: 1 sections
unsupported-vertical chromium: 1 sections
```

## Phase A — final-clean-2-verify-vectors

`npm.cmd run verify-vectors` in tool/oracle.

Exit 0; timeout 180 s; duration 0.361 s.

```text

> shiori-reader-oracle@1.0.0 verify-vectors
> node src/verify-vectors.mjs

PASS 13 EPUBs; 39 sections; 4807 CFI samples per engine; nested nav/NCX, literal Blob prose and resource aliases verified.
```

## Phase A final clean reproducibility

Two clean builds/extractions under UTC and Asia/Hong_Kong: 45 generated/attribute files, 0 SHA-256 differences; exit 0. Scoped .gitattributes were preserved during cleanup. Every generation command had a 180 s process timeout and a 240 s wrapper bound. See oracle-final-reproducibility.json for final hashes.

## Phase A — 2026-10-22T08:42:47.850590+00:00

All commands run at the repository root with explicit timeouts.

### `dart run build_runner build`

Exit: 0; timeout: 900 s; duration: 3.103 s; timed out: False.

```text
  0s riverpod_generator on 53 inputs; lib/app/app.dart
  0s riverpod_generator on 53 inputs: 53 skipped
  0s freezed on 53 inputs; lib/app/app.dart
  0s freezed on 53 inputs: 53 skipped
  0s json_serializable on 106 inputs; lib/app/app.dart
  0s json_serializable on 106 inputs: 105 skipped, 1 same
  0s go_router_builder on 106 inputs; lib/app/app.dart
  0s go_router_builder on 106 inputs: 106 skipped
  0s source_gen:combining_builder on 106 inputs; lib/app/app.dart
  0s source_gen:combining_builder on 106 inputs: 106 skipped
  Built with build_runner/aot in 1s; wrote 1 output.
```

### `dart format --set-exit-if-changed lib test tool/diag`

Exit: 0; timeout: 180 s; duration: 0.709 s; timed out: False.

```text
No file or directory found at "tool/diag".
Formatted 70 files (0 changed) in 0.11 seconds.
```

### `flutter analyze`

Exit: 0; timeout: 180 s; duration: 3.655 s; timed out: False.

```text
Analyzing shiori...
No issues found! (ran in 1.8s)
```

### `flutter test`

Exit: 0; timeout: 900 s; duration: 6.041 s; timed out: False.

```text
00:00 +69: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:00 +70: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:00 +71: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:00 +72: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:00 +73: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:00 +74: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:00 +75: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:00 +76: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:00 +77: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:00 +78: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: shows loading then retained marker and saves edits
00:00 +79: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: shows loading then retained marker and saves edits
00:01 +80: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: shows loading then retained marker and saves edits
00:01 +81: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: storage error has localized retry and recovery
00:01 +82: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: capture stops, drains, exports and copies matching summary
00:01 +83: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: motion reads current engine identity only after ticker callbacks
00:02 +84: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: queued motion is ignored after same-frame lifecycle stop
00:02 +85: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: dispose before queued post-frame motion never reads identity
00:02 +86: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: auto duration stops animation and background never restarts capture
00:02 +87: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: failed export preserves partial record and can retry
00:02 +88: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: declaration edits are frozen into the captured record
00:02 +89: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: dispose during async export does not publish stale UI
00:02 +90: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: marker save error remains editable at 200 percent text scale
00:03 +91: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: (tearDownAll)
00:03 +91: All tests passed!
```

## Phase A — resolve-smoke

`npm.cmd run resolve -- ../../build/oracle-local/synthetic-resolve-input.json` in tool/oracle.

Exit 0; timeout 180 s; duration 6.743 s.

```text

> shiori-reader-oracle@1.0.0 resolve
> node src/run-oracle.mjs resolve ../../build/oracle-local/synthetic-resolve-input.json

webkit 27.2
chromium 156.0.8078.4
Resolved 13 request groups into build/oracle-local/resolve-results.json
```

## Phase A resolve CLI, privacy and scope review

Synthetic resolve CLI smoke: 13 fixture groups, first and last sample from each of 39 sections; all 156 cross-engine endpoint results equal the stored oracle endpoints (exit 0). Inputs/results stayed in build/oracle-local. The final Phase A codegen wrote one same-content output; git diff shows no lib/ or test Dart source changes. All 91 existing tests pass.

Local book extraction completed with exit 0 in 159.495 s under a 600 s bound: 60 spine sections and 168,677 CFI samples per engine; zero cross-engine differences. All four local-book WebKit vectors have zero projected Blob-URL normalization entries, so the subsequent exact-URL/alias-preservation fixes do not change those vectors. Private book text is not printed or copied to task evidence.

## Phase A pre-commit review

Trellis checker: PASS. Independently verified all 45 current SHA-256 output records against the final UTC/Hong Kong reproducibility record, 13 EPUBs / 39 sections / 4807 CFI samples per engine, 156 cross-engine resolve records, four vendored payload hashes, syntax, diff/scope, and private-output ignores. Full Flutter gate evidence: all exit 0; 91 tests. No remaining findings.

## Phase A — check-reference-final

`npm.cmd run check-reference` in tool/oracle.

Exit 0; timeout 180 s; duration 0.293 s.

```text

> shiori-reader-oracle@1.0.0 check-reference
> node src/check-reference.mjs

PASS client/src/utils/canonicalText.ts 6eb746b7fe90914094f08fe6ac3616e9f8ba3321547285ea483f317e6e72eeff
PASS client/src/reader/contentSecurity.ts 9e49bd543b4261dd689ca0efb8fd61981624fe3c6d7d11d28cfca0b33fcd43ca
PASS client/src/reader/visiblePageAnchor.ts 14870e5b4848bf85d9c085cf2c1b6486e41b998d09487d2957c6a97cad5f7bc8
PASS shared/src/readingStats.ts c48fad4df03ec20d96f3caf40650c558fe49218afc8dcd0021ee68e87b75325d
```

## Phase A — final-clean-1-build-fixtures

`npm.cmd run build-fixtures` in tool/oracle.

Exit 0; timeout 180 s; duration 0.244 s.

```text

> shiori-reader-oracle@1.0.0 build-fixtures
> node src/build-fixtures.mjs

cfi-structure: 2603 bytes
chapters: 27807 bytes
html-fallback: 4489 bytes
images: 11877 bytes
inert-content: 10682 bytes
long-content: 778175 bytes
one-page: 2130 bytes
opf-variants: 3665 bytes
styles: 360562 bytes
unicode: 2368 bytes
unsupported-fixed: 2327 bytes
unsupported-rtl: 2239 bytes
unsupported-vertical: 2338 bytes
```

## Phase A — final-clean-1-vectors

`npm.cmd run vectors` in tool/oracle.

Exit 0; timeout 180 s; duration 12.935 s.

```text

> shiori-reader-oracle@1.0.0 vectors
> node src/run-oracle.mjs vectors

webkit 27.2
chromium 156.0.8078.4
cfi-structure webkit: 1 sections
cfi-structure chromium: 1 sections
chapters webkit: 16 sections
chapters chromium: 16 sections
html-fallback webkit: 5 sections
html-fallback chromium: 5 sections
images webkit: 3 sections
images chromium: 3 sections
inert-content webkit: 1 sections
inert-content chromium: 1 sections
long-content webkit: 3 sections
long-content chromium: 3 sections
one-page webkit: 1 sections
one-page chromium: 1 sections
opf-variants webkit: 4 sections
opf-variants chromium: 4 sections
styles webkit: 1 sections
styles chromium: 1 sections
unicode webkit: 1 sections
unicode chromium: 1 sections
unsupported-fixed webkit: 1 sections
unsupported-fixed chromium: 1 sections
unsupported-rtl webkit: 1 sections
unsupported-rtl chromium: 1 sections
unsupported-vertical webkit: 1 sections
unsupported-vertical chromium: 1 sections
```

## Phase A — final-clean-1-verify-vectors

`npm.cmd run verify-vectors` in tool/oracle.

Exit 0; timeout 180 s; duration 0.337 s.

```text

> shiori-reader-oracle@1.0.0 verify-vectors
> node src/verify-vectors.mjs

PASS 13 EPUBs; 39 sections; 4807 CFI samples per engine; nested nav/NCX, literal Blob prose and resource aliases verified.
```

## Phase A — final-clean-2-build-fixtures

`npm.cmd run build-fixtures` in tool/oracle.

Exit 0; timeout 180 s; duration 0.248 s.

```text

> shiori-reader-oracle@1.0.0 build-fixtures
> node src/build-fixtures.mjs

cfi-structure: 2603 bytes
chapters: 27807 bytes
html-fallback: 4489 bytes
images: 11877 bytes
inert-content: 10682 bytes
long-content: 778175 bytes
one-page: 2130 bytes
opf-variants: 3665 bytes
styles: 360562 bytes
unicode: 2368 bytes
unsupported-fixed: 2327 bytes
unsupported-rtl: 2239 bytes
unsupported-vertical: 2338 bytes
```

## Phase A — final-clean-2-vectors

`npm.cmd run vectors` in tool/oracle.

Exit 0; timeout 180 s; duration 12.418 s.

```text

> shiori-reader-oracle@1.0.0 vectors
> node src/run-oracle.mjs vectors

webkit 27.2
chromium 156.0.8078.4
cfi-structure webkit: 1 sections
cfi-structure chromium: 1 sections
chapters webkit: 16 sections
chapters chromium: 16 sections
html-fallback webkit: 5 sections
html-fallback chromium: 5 sections
images webkit: 3 sections
images chromium: 3 sections
inert-content webkit: 1 sections
inert-content chromium: 1 sections
long-content webkit: 3 sections
long-content chromium: 3 sections
one-page webkit: 1 sections
one-page chromium: 1 sections
opf-variants webkit: 4 sections
opf-variants chromium: 4 sections
styles webkit: 1 sections
styles chromium: 1 sections
unicode webkit: 1 sections
unicode chromium: 1 sections
unsupported-fixed webkit: 1 sections
unsupported-fixed chromium: 1 sections
unsupported-rtl webkit: 1 sections
unsupported-rtl chromium: 1 sections
unsupported-vertical webkit: 1 sections
unsupported-vertical chromium: 1 sections
```

## Phase A — final-clean-2-verify-vectors

`npm.cmd run verify-vectors` in tool/oracle.

Exit 0; timeout 180 s; duration 0.337 s.

```text

> shiori-reader-oracle@1.0.0 verify-vectors
> node src/verify-vectors.mjs

PASS 13 EPUBs; 39 sections; 4807 CFI samples per engine; nested nav/NCX, literal Blob prose and resource aliases verified.
```

## Phase A final clean reproducibility

Two clean builds/extractions under UTC and Asia/Hong_Kong: 45 generated/attribute files, 0 SHA-256 differences; exit 0. Scoped .gitattributes were preserved during cleanup. Every generation command had a 180 s process timeout and a 240 s wrapper bound. See oracle-final-reproducibility.json for final hashes.

## Phase A-source-lf — 2026-10-22T08:50:53.853335+00:00

All commands run at the repository root with explicit timeouts.

### `dart run build_runner build`

Exit: 0; timeout: 900 s; duration: 2.036 s; timed out: False.

```text
  0s riverpod_generator on 53 inputs; lib/app/app.dart
  0s riverpod_generator on 53 inputs: 53 skipped
  0s freezed on 53 inputs; lib/app/app.dart
  0s freezed on 53 inputs: 53 skipped
  0s json_serializable on 106 inputs; lib/app/app.dart
  0s json_serializable on 106 inputs: 106 skipped
  0s go_router_builder on 106 inputs; lib/app/app.dart
  0s go_router_builder on 106 inputs: 106 skipped
  0s source_gen:combining_builder on 106 inputs; lib/app/app.dart
  0s source_gen:combining_builder on 106 inputs: 106 skipped
  Built with build_runner/aot in 1s; wrote 0 outputs.
```

### `dart format --set-exit-if-changed lib test tool/diag`

Exit: 0; timeout: 180 s; duration: 0.708 s; timed out: False.

```text
No file or directory found at "tool/diag".
Formatted 70 files (0 changed) in 0.11 seconds.
```

### `flutter analyze`

Exit: 0; timeout: 180 s; duration: 3.252 s; timed out: False.

```text
Analyzing shiori...
No issues found! (ran in 1.3s)
```

### `flutter test`

Exit: 0; timeout: 900 s; duration: 8.28 s; timed out: False.

```text
00:01 +69: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:01 +70: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:01 +71: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:01 +72: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:01 +73: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:01 +74: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:01 +75: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:01 +76: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:01 +77: D:/Projects/shiori/test/core/widgets/error_view_test.dart: shows the mapped message and a working retry button
00:01 +78: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: shows loading then retained marker and saves edits
00:01 +79: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: shows loading then retained marker and saves edits
00:01 +80: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: shows loading then retained marker and saves edits
00:02 +81: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: storage error has localized retry and recovery
00:02 +82: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: capture stops, drains, exports and copies matching summary
00:02 +83: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: motion reads current engine identity only after ticker callbacks
00:03 +84: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: queued motion is ignored after same-frame lifecycle stop
00:03 +85: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: dispose before queued post-frame motion never reads identity
00:03 +86: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: auto duration stops animation and background never restarts capture
00:03 +87: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: failed export preserves partial record and can retry
00:03 +88: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: declaration edits are frozen into the captured record
00:04 +89: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: dispose during async export does not publish stale UI
00:04 +90: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: marker save error remains editable at 200 percent text scale
00:04 +91: D:/Projects/shiori/test/features/diagnostics/presentation/diagnostics_screen_test.dart: (tearDownAll)
00:04 +91: All tests passed!
```

## Phase A post-staging source-byte correction

Review after the initial Phase A commit found that Git eol attributes had normalized index blobs without rewriting seven preexisting CRLF worktree files. In particular, only.xhtml and the packaged Roboto NOTICE made two EPUBs differ from a clean checkout. Ordinary oracle text was normalized to LF in the worktree; the intentional Unicode mixed-newline fixture and both font binaries were preserved. All 86 tracked tool/oracle files now compare byte-for-byte equal to HEAD blobs, with zero mismatches; exact vendored reference drift checks also pass (exit 0). See oracle-source-lf-normalization.json for affected paths and before/after digests.

The reproducibility script now checks raw source hashes against Git path-filtered hashes before building. From those exact committed source bytes, two clean UTC/Hong_Kong generations again match all 45 output/attribute files, with zero differences and sourceFilterMismatches empty. The one-page EPUB is 2130 bytes and styles EPUB 360562 bytes; these final digests supersede the earlier pre-normalization outputs. Corpus assertions remain 13 EPUBs, 39 sections and 4807 CFI samples per engine, with zero engine differences.

The complete quality gate was rerun for the corrected bundled assets: codegen exit 0 (0 outputs), formatter exit 0 (70 files, 0 changed; tool/diag still absent), analyzer exit 0 (no issues), tests exit 0 (91 passed). See quality-gate-A-source-lf.json. No reader code, dependency selection, local-book extraction behavior or protected source changed; local book vectors therefore did not require regeneration. No extra commit or push was made by the implementer.

## Phase A post-stage determinism review

Trellis checker: PASS after correction. Compared raw bytes of all 86 tracked oracle files with both HEAD and index blobs: 86/86 identical, zero raw/filter mismatches. Independently checked all 45 generated file hashes and their raw/filter agreement; self EOL attributes are correct. Decompressed asset changes are only CRLF-to-LF in one-page XHTML (-1 byte) and font NOTICE (-2 bytes); vector changes are fixture digests only. All four vendored payloads still match. Corrected full gate: all exit 0, codegen 0 outputs, 91 tests. The initial Phase A commit is amended to include this correction before starting Phase B.

## User pause — Phase B incomplete

Paused on 2026-10-22 at the user's explicit request. Dependency installation exited 0 (`reader-dependency-install.json`); no Phase B codegen, format, analysis, tests or review completed. Partial source/parser and CFI model drafts remain uncommitted. Both implementers report no remaining subprocesses. See `resume-handoff.md` and the source/CFI resume research notes. No further implementation, phase commit, push or task archive was performed during pause recording.

## Phase B evidence — 2026-10-22

Windows host only; WebKit 27.2 is the authority (Chromium 156.0.8078.4 cross-check). No device run.

### Results

| Area | Result |
| --- | --- |
| Synthetic fixtures (13 EPUBs, 39 sections) | Package/spine/section bases/TOC, parser selection and error class, projected nodes, canonical version/length/signature/starts/maps: 0 mismatches against `test/fixtures/reader/oracle/*.webkit.json`. |
| Native CFI on native documents | All 4,807 sampled vector CFIs: `Cfi.resolve` equals the vector's resolved node/offset and `Cfi.export` reproduces the CFI, 0 failures. |
| Local books (4 EPUBs, 60 sections) | Same comparisons: 0 mismatches; 168,677 sampled CFIs resolved and exported with 0 failures. Output carries indices only. |
| Source edge fixtures (`test/fixtures/reader/source_edge`, 43 sections) | Hand-written malformed XML, fallbacks, inert content, CSS rewriting, namespaces, HTML tree-builder cases: equal to WebKit vectors including all CFI samples, except one pinned difference (see gaps). |
| Native to oracle interop | `dart run tool/reader/native_cfi_interop.dart export build/interop`; `cd tool/oracle && npm run resolve -- ../../build/interop/cfi-list.json`; `dart run tool/reader/native_cfi_interop.dart compare build/interop`. 13 fixtures, 4,807 native-exported CFIs: Foliate node/offset/section equal the native resolution on WebKit 4,807/4,807 and Chromium 4,807/4,807, 0 mismatches. |

### Test counts and gate

`flutter test test/features/reader`: 256 passed (cfi 203, epub 49, canonical 4). Full gate, run sequentially: `dart run build_runner build` exit 0; `dart format --set-exit-if-changed lib test tool/reader` exit 0 (112 files, 0 changed; tool/diag does not exist); `flutter analyze` exit 0, no issues; `flutter test` exit 0, 347 passed. `csslib` was removed from pubspec (unused).

### Known gaps and caveats

- HTML-mode only: a head-level `<template>` is not isolated; `<noscript>` content that closes an open `<p>` builds a different tree; attribute URLs are not tokenized, so the raw text of a script-enabled `<noscript>` keeps the package href (the single pinned difference in `h2-noscript-head.html`, whose sampled positions are skipped). None occur in the fixtures or the four books. Pure-SVG spine items are not exercised by the oracle.
- Head `<style>` text carries length-neutral resource tokens whose length equals the reference blob URL length for the oracle origin (64); head-text offsets are origin-length dependent. Body positions are unaffected.
- ZIP limits check declared sizes and the size after expansion; `archive` inflates a whole entry in memory, so a lying header can briefly allocate more than the limit before it is rejected.
- Verified on Windows only; iPhone parsing behaviour is unverified.

## Post-Phase-B review: oracle vector slimming

Requested by the user in review before any push, because the public history
would otherwise keep ~27 MB of vectors. Folded into the Phase A commit.

- Change: `npm run vectors` still runs WebKit and Chromium and still writes
  `cross-engine-differences.json`, but commits only `<id>.webkit.json`. Full
  Chromium vectors go to gitignored `build/oracle-chromium/`. Vector files use
  `compactJSON` (same sorted JSON; values that fit 120 columns on one line,
  long primitive arrays wrapped). `verify-vectors` rejects committed Chromium
  files and checks Chromium output when present.
- First attempt: `compactJSON` printed `undefined` object members, which
  `JSON.stringify` drops; `verify-vectors` failed with a JSON syntax error
  (`"properties": undefined`). The rerun overwrote that evidence file, so the
  `oracle-final-clean-*.json` files show the final run only. Fixed by
  normalizing through `JSON.parse(JSON.stringify(...))` before layout.
- Reproducibility: two clean generations (UTC, Asia/Hong_Kong) — 32
  generated/attribute files, 0 SHA-256 differences, exit 0
  (`oracle-final-reproducibility.json`). 45 → 32 files: the 13 Chromium vectors.
- Lossless check: all 29 previously committed vector files (13 WebKit, 13
  Chromium, summary, Unicode table, differences) parse to deep-equal content
  in their new locations. Assets and fixture sources are byte-unchanged.
- Size: `test/fixtures/reader/oracle/` 27 MB → 6.7 MB; ~1.14 M → ~99.5 k lines.
- `flutter test`: exit 0, 347 passed (local books: 4, 60 sections, 168,677
  CFI samples). No Dart reader changed.
