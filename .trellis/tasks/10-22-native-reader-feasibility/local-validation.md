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

The first two clean build-fixtures + vectors runs matched SHA-256 for all 43 generated files (exit 0). Review then found fflate uses local calendar getters for ZIP DOS timestamps. The builder now uses a fixed local Date rather than a UTC instant. Both `TZ=UTC node src/build-fixtures.mjs` and `TZ=Asia/Hong_Kong node src/build-fixtures.mjs` exited 0 with 180 s timeouts; all 14 generated asset files are byte-identical. See evidence/oracle-timezone-reproducibility.json. The final clean vector comparison below supersedes pre-fix archive digests.

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

Two clean builds/extractions under UTC and Asia/Hong_Kong: 45 generated/attribute files, 0 SHA-256 differences; exit 0. Scoped .gitattributes were preserved during cleanup. Every generation command had a 180 s process timeout and a 240 s wrapper bound. See evidence/oracle-final-reproducibility.json for final hashes.

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

Two clean builds/extractions under UTC and Asia/Hong_Kong: 45 generated/attribute files, 0 SHA-256 differences; exit 0. Scoped .gitattributes were preserved during cleanup. Every generation command had a 180 s process timeout and a 240 s wrapper bound. See evidence/oracle-final-reproducibility.json for final hashes.

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

Review after the initial Phase A commit found that Git eol attributes had normalized index blobs without rewriting seven preexisting CRLF worktree files. In particular, only.xhtml and the packaged Roboto NOTICE made two EPUBs differ from a clean checkout. Ordinary oracle text was normalized to LF in the worktree; the intentional Unicode mixed-newline fixture and both font binaries were preserved. All 86 tracked tool/oracle files now compare byte-for-byte equal to HEAD blobs, with zero mismatches; exact vendored reference drift checks also pass (exit 0). See evidence/oracle-source-lf-normalization.json for affected paths and before/after digests.

The reproducibility script now checks raw source hashes against Git path-filtered hashes before building. From those exact committed source bytes, two clean UTC/Hong_Kong generations again match all 45 output/attribute files, with zero differences and sourceFilterMismatches empty. The one-page EPUB is 2130 bytes and styles EPUB 360562 bytes; these final digests supersede the earlier pre-normalization outputs. Corpus assertions remain 13 EPUBs, 39 sections and 4807 CFI samples per engine, with zero engine differences.

The complete quality gate was rerun for the corrected bundled assets: codegen exit 0 (0 outputs), formatter exit 0 (70 files, 0 changed; tool/diag still absent), analyzer exit 0 (no issues), tests exit 0 (91 passed). See evidence/quality-gate-A-source-lf.json. No reader code, dependency selection, local-book extraction behavior or protected source changed; local book vectors therefore did not require regeneration. No extra commit or push was made by the implementer.

## Phase A post-stage determinism review

Trellis checker: PASS after correction. Compared raw bytes of all 86 tracked oracle files with both HEAD and index blobs: 86/86 identical, zero raw/filter mismatches. Independently checked all 45 generated file hashes and their raw/filter agreement; self EOL attributes are correct. Decompressed asset changes are only CRLF-to-LF in one-page XHTML (-1 byte) and font NOTICE (-2 bytes); vector changes are fixture digests only. All four vendored payloads still match. Corrected full gate: all exit 0, codegen 0 outputs, 91 tests. The initial Phase A commit is amended to include this correction before starting Phase B.

## User pause — Phase B incomplete

Paused on 2026-10-22 at the user's explicit request. Dependency installation exited 0 (`evidence/reader-dependency-install.json`); no Phase B codegen, format, analysis, tests or review completed. Partial source/parser and CFI model drafts remain uncommitted. Both implementers report no remaining subprocesses. See `resume-handoff.md` and the source/CFI resume research notes. No further implementation, phase commit, push or task archive was performed during pause recording.

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
  `evidence/oracle-final-clean-*.json` files show the final run only. Fixed by
  normalizing through `JSON.parse(JSON.stringify(...))` before layout.
- Reproducibility: two clean generations (UTC, Asia/Hong_Kong) — 32
  generated/attribute files, 0 SHA-256 differences, exit 0
  (`evidence/oracle-final-reproducibility.json`). 45 → 32 files: the 13 Chromium vectors.
- Lossless check: all 29 previously committed vector files (13 WebKit, 13
  Chromium, summary, Unicode table, differences) parse to deep-equal content
  in their new locations. Assets and fixture sources are byte-unchanged.
- Size: `test/fixtures/reader/oracle/` 27 MB → 6.7 MB; ~1.14 M → ~99.5 k lines.
- `flutter test`: exit 0, 347 passed (local books: 4, 60 sections, 168,677
  CFI samples). No Dart reader changed.

## Phase C — layout, page map, anchors, detection

Local commands only; host (Windows) Flutter test engine with the Ahem test font.

- Style engine and unsupported-layout detection (C1) and layout, pagination,
  images/SVG and anchors (C2) are implemented under `lib/features/reader/engine/`
  with tests under `test/features/reader/engine/`.
- Integration: `list-style-type` added to `ComputedStyle` (additive), parsed from
  `list-style-type` and the `list-style` shorthand, UA defaults ul disc / nested
  circle then square / ol decimal; layout markers follow the type, `ol start` and
  `li value`; markers are synthetic. Inline `<style>` and linked `@font-face`
  both carry real archive paths and load (test on the `styles` fixture).
- Dependencies: `csslib` 1.0.2, `flutter_svg` 2.3.0 (+ `vector_graphics` 1.2.4,
  `vector_graphics_compiler` 1.3.2), `xml` pin `^7.0.1` (resolved 7.0.1). Phase B
  data tests re-run on 7.0.1: 256 passed.
- Conservation: 10 supported fixtures x 3 settings pass; four local books pass at
  all three gate settings (tables in `feasibility-report.md`).
- Anchors: every page of every fixture round-trips; 2,980 oracle CFIs land;
  2,413 native CFIs resolve identically in WebKit and Chromium (4,826/4,826);
  reflow and injected-failure behaviour tested.
- Host timing (indicative, Ahem): 100,000-unit paragraph layout median ~5-11 ms,
  whole-section preparation ~25-52 ms.
- The main session's Phase A/B history rewrite re-checked files out with CRLF under core.autocrlf; the canonical table test now compares content with normalized line endings.

### Phase C gate (sequential)

| Command | Exit |
| --- | --- |
| `dart run build_runner build` | 0 |
| `dart format --set-exit-if-changed lib test tool/reader` | 0 (165 files, 0 changed) |
| `flutter analyze` | 0, no issues |
| `flutter test` (whole suite) | 0: 638 passed, 1 skipped (`native_cfi_export_test`, runs only with `SHIORI_NATIVE_CFI_OUT`) |

`git status`: no changes under `tool/oracle/`, `assets/reader_fixtures/` or
`test/fixtures/reader/oracle/`.

## Phase D — motion controller and surfaces

2026-10-23; local Windows commands, Flutter 3.47.7 / Dart 3.13.5.
Branch `ios-build/s2-reader-probe`, HEAD `73835bb`; reference `a4bda23`.
Resumed the existing uncommitted implementation. The motion baseline passed
62 tests before edits. No commit, push, branch change or reference edit.
The supplied process-only Git configuration allowed the sandbox SDK to start;
this session did not change trust configuration or sandbox permissions.

### Built and completed

Paths below are relative to `lib/features/reader/`.

- Motion (`engine/motion/`): `page_turn_gesture.dart`, `page_turn_engine.dart`,
  `turn_clock.dart`, `turn_session.dart`, `turn_intent_queue.dart`,
  `turn_acceptance.dart`, `turn_motion.dart`, `reader_turn_controller.dart`,
  `turn_controller_work.dart`, `turn_controller_pointer.dart`,
  `turn_controller_drag.dart`. Reader-local numeric motion, frozen admission
  ruler, 1+8 FIFO with explicit overflow, accepted-origin rebase, lifecycle
  cancellation, generation rejection, paired motion and proof before acceptance.
- Surfaces (`engine/surface/`): `page_surface_pool.dart`,
  `prepared_page_position.dart`, `prepared_reader_session.dart`,
  `surface_frame.dart`, `prepared_reader.dart`. Retained pictures, reference-
  counted leases, repaint-only Flow transforms, stable page subtrees, real
  Phase C anchor/visibility proof and reduced-motion acceptance.
- Bounds: three presented surfaces plus one declared reserve; pending owners
  count against the same bound. Picture budget 16 MiB, decoded-image budget
  48 MiB. No idle picture cache. Last release disposes pictures and releases
  image leases; pending decode cannot publish after pool close. Closing a
  session is idempotent and late controller cleanup cannot touch its notifier.
- Guard: `data/source/reader_work_guard.dart` marks pointer/ticker zones in
  debug mode. Checks precede parsing, shaping, decode starts, font loading,
  pagination, canonical traversal, archive resource reads and JSON projection.
  Data remains isolate-safe with no `dart:ui` or providers. S2 has no filesystem
  position/activity storage; its existing archive byte/text reads are guarded
  as storage work. No product persistence was added.
- Guard-only entry edits in `data/source/`: `source_parser.dart`,
  `html_adapter.dart`, `xml_parser.dart`, `source_document.dart`;
  `data/canonical/canonical_text.dart`; `data/cfi/`: `cfi_parser.dart`,
  `cfi_expression.dart`, `cfi_step.dart`; `data/epub/`: `epub_archive.dart`,
  `epub_loader.dart`, `epub_package.dart`.
- Guard-only engine entry edits in `engine/layout/`: `paragraph_factory.dart`,
  `font_registry.dart`, `image_cache.dart`, `svg_picture.dart`;
  `engine/pagination/`: `section_preparer.dart`, `section_paginator.dart`;
  `engine/style/`: `css_stylesheet.dart`, `reader_settings.dart`. Expression
  bodies became block bodies only where a guard needed to precede the return.
  The inherited `engine/pagination/page_painter.dart` image-lease integration
  was preserved and formatted.

### Ported reference inventory

Reference paths are relative to `D:/Projects/lan-reader/client/test/`; Dart
paths are relative to `test/features/reader/`. Counts expand parameterized
reference cases. Motion tests inject `TestTurnClock`; pure canonical/image
functions have no clock dependency. No sleeps or wall-time assertions were added.

| Reference file | Dart test file(s) | Cases ported / deferred |
| --- | --- | --- |
| `pageTurnEasing.test.ts` | `engine/motion/page_turn_easing_test.dart` | 6/6 ported; 7 Dart tests including tap-zone boundary checks; none deferred |
| `readerPageTurnEngine.test.ts` | `engine/motion/page_turn_engine_test.dart` | 14/14 ported; none deferred |
| `readerInputQueue.test.ts` | `engine/motion/reader_input_queue_test.dart`, `reader_input_queue_lifecycle_test.dart` in the same directory | 30/31 ported; browser pointer-capture hook deferred |
| `readerTurnProof.test.ts` | `engine/motion/reader_turn_proof_test.dart` | 15/15 ported; none deferred |
| `readerMotionIsolation.test.ts` | `engine/motion/reader_motion_isolation_test.dart` | 7 native equivalents plus 2 pending-admission reversal regressions; browser animation/disposer mechanics replaced by native picture/lease evidence |
| `foliateTurnTargetProof.test.ts` | `engine/surface/foliate_turn_target_proof_test.dart` | 10/11 ported; fixed-layout frame proof deferred |
| `readingActivityText.test.ts` | `data/canonical/reading_activity_text_test.dart` | 6/7 ported; mutable browser DOM cache case deferred |
| `contentImage.test.ts` | `engine/layout/content_image_test.dart` | 2 source-side ports, 3 preparation subcases, 1 additional dimension check; 9 UI/viewer cases remain deferred (3 have preparation coverage) |

Additional tests: `engine/motion/reader_work_guard_test.dart` has 38 cases
(29 real entry calls inside/outside callbacks and all 9 work categories).
`engine/surface/prepared_reader_test.dart` has 5 widget cases: actual painted
offset changes with unchanged page-build count, final-lease/widget disposal,
3+1 live bound, disposal during an active drag, reduced motion proving and
accepting once. `engine/surface/page_surface_pool_test.dart` has 6 cases:
picture/image disposal, both byte budgets, pending-decode ownership through
close, assertion-before-release mutation and coalesced neighbor warming.
Helpers: `engine/motion/motion_test_support.dart` (inherited, formatted),
`engine/surface/surface_test_support.dart` (real 25-page native preparation).
The Phase D files contribute 146 passing tests: 62 inherited plus 84 added here.

### Deferred cases and native substitutions

| Reference file:line | Deferred subject / reason |
| --- | --- |
| `readerInputQueue.test.ts:241` | React hook / DOM `setPointerCapture`, capture failure and late `lostpointercapture`; Flutter uses native pointer routing, and S2 has no browser capture hook. The four engine lifecycle cases at :224 and :280 were added. |
| `foliateTurnTargetProof.test.ts:154` | Fixed-layout spread/frame visibility. Rendering fixed-layout publications is explicitly outside S2. Reflowable own-page visibility/round-trip checks are ported. |
| `readingActivityText.test.ts:74` | Mutable DOM identity cache and mutation invalidation. S2 indexes immutable `SourceDocument` snapshots explicitly and exposes no mutable DOM cache. No activity tracking feature was added. |
| `contentImage.test.ts:31` | Reader tap through a link to the original resource: original archive-path preservation is covered; product hit testing/viewer dispatch belongs to S4–S6. |
| `contentImage.test.ts:69`, `:98` | Disabled hit testing and positioned image tap recovery require the product gesture/hit-test layer. |
| `contentImage.test.ts:135`, `:150` | Background/hidden image exclusion at a tap point requires product hit testing; the existing S2 block-preparation exclusions are covered separately. |
| `contentImage.test.ts:171` | Occlusion-aware tap resolution is product image hit testing, absent from S2. |
| `contentImage.test.ts:230` | Viewer SVG export with captured publication styles, absolute resource placeholders and font embedding is absent from S2. Native SVG serialization is covered at :196. |
| `contentImage.test.ts:273` | Viewer-time external resource fetching/data-URL embedding is absent from S2; no network service or viewer was implemented. |
| `contentImage.test.ts:335` | Hover zoom cursor belongs to the product image viewer/gesture layer. |

At `readerMotionIsolation.test.ts:98`, browser disposal is asynchronous and
WAAPI must wait for retirement. Native picture disposal is synchronous: its
equivalent retains an owner until final lease release, refuses over-capacity
preparation, then admits a replacement. A separate real codec test proves
pending asynchronous decode remains an owner through close until it drains.
The native current foreground is included in the 3+1 count; the browser's
provider-owner count excludes its foreground. Neither reference constants nor
the declared native bound were weakened.

### Reference/design comparison and bugs caught

- No unresolved semantic disagreement with design §7 or the reference source.
  Round-trip equality is structural `Cfi.compare == 0`, matching
  `foliateEngine.ts:397`; it is not CFI string identity. The test uses an offset
  that resolves through ToUint32 but cannot structurally round-trip, while
  distinct valid anchors on the same visible page are accepted.
- The execution-plan validation snippet still names `tool/diag`; the current
  Phase C evidence and this handoff name `tool/reader`. The requested existing
  `tool/reader` directory was checked; planning files were left untouched.
- Previous session's port caught waiting inputs resolving as committed after
  a post-acceptance callback rejected. Its fix is retained: the accepted intent
  stays committed, waiting inputs fail, and only one destination is published.
- Widget tests caught double-disposal of the session frame notifier. Close is
  now idempotent; late bind/unbind/navigation/proof/restore reject closed state.
- The callback test caught final release mutating its reference/released state
  before asserting. The guard now runs before any lease mutation, so a rejected
  callback release can still be performed normally by its owner.
- The held-drag isolation port caught overlapping preparations while a drain
  was pending, retaining an extra neighbor. Pointer preparation is serialized;
  newest samples/reversals are preserved and cancellation returns to one owner.
  A related repeated-warm regression caught duplicate warm owners; in-flight
  warming is coalesced and stale-origin results are released.
- All six reported analyzer infos were fixed. Formatting exposed additional
  multiline-if lint cases, also fixed; final analysis has no issues.

### Phase D gate (sequential)

Final successful sequence, repository root; machine records use the same six
fields as `evidence/quality-gate-A.json` in `evidence/quality-gate-D.json`.

| Command | Timeout | Exit / result | Duration |
| --- | --- | --- | --- |
| `dart run build_runner build` | 900 s | 0; 0 outputs written | 5.273 s |
| `dart format --set-exit-if-changed lib test tool/reader` | 180 s | 0; 196 files, 0 changed | 0.802 s |
| `flutter analyze` | 180 s | 0; no issues | 3.486 s |
| `flutter test` | 900 s | 0; 784 passed, 1 skipped, 0 failed | 14.311 s |

The sole skip is the existing `native_cfi_export_test.dart:75`, conditional on
`SHIORI_NATIVE_CFI_OUT`; local-book tests ran and passed. Host tests establish
state-machine, proof and lifetime behavior, not iPhone 120 Hz presentation or
touch-to-photon performance. Phase E/probe/device evidence remains outside
this Phase D handoff.

Scope review: only authorized reader lib/test paths and these two Phase D
evidence files changed. The three pre-existing coordinating-session edits
(`task.json`, workspace `index.md`, `journal-1.md`) retained their exact SHA-256
bytes. Prior validation text is preserved as an append-only prefix (CRLF
normalized for comparison). Reference worktree remains clean at `a4bda23`.

### Phase D review and independent re-run

- Executor: Codex CLI (`gpt-6.1-sol`, reasoning high, `workspace-write`
  sandbox with the Flutter SDK, pub cache and `.dart-tool` as extra writable
  roots). Three earlier runs stopped on upstream stream disconnects; the
  finishing session needed process-only `safe.directory` environment
  variables for `D:/DevTools/flutter` and `D:/Projects/lan-reader` because the
  sandbox runs as a different Windows user. No global Git or trust setting
  changed.
- The coordinating session re-ran the four gate commands independently before
  review: all exit 0, `flutter test` 784 passed, 1 skipped.
- trellis-check (Sonnet 5.5, medium): PASS with one fix.
  - High, fixed: `engine/surface/prepared_reader.dart` suspended the
    controller on every non-`resumed` lifecycle state but never resumed it, so
    one app switch or Control Center pull left the reader refusing input. The
    widget now tracks a local suspended flag and calls `controller.resume()` on
    `resumed`; new widget test `background suspends the controller and
    foreground resumes it` in `prepared_reader_test.dart`.
  - Low, reported (S4 hardening): `PreparedReaderSession.warm()` coalesces only
    warm calls per direction; a controller `prepare()` racing a warm for the
    same target can briefly hold a second lease. The 3+1 owner cap bounds it
    and an over-cap result becomes a static-fallback prepare failure, not a
    leak.
  - Info: Dart `round()` (half away from zero) and JS `Math.round` (half up)
    agree for the positive thresholds used.
- Post-fix gate (coordinating session): `dart format --set-exit-if-changed lib
  test tool/reader` exit 0 (196 files, 0 changed); `flutter analyze` no
  issues; `flutter test` exit 0, **785 passed, 1 skipped**, 0 failed.
  `evidence/quality-gate-D.json` keeps Codex's pre-fix records (784 passed).

### Phase E part 1

Completed locally on 2026-10-23 on `ios-build/s2-reader-probe`, starting from
the previous session's uncommitted Dart implementation. This is the part 1
handoff only; native sampling, analyzer/CI work and device evidence remain
for subsequent parts. No commit, push or branch operation was performed.

Files by area (paths relative to the repository):

- App: modified `lib/app/probe_app.dart`, added its generated
  `probe_app.g.dart`. Probe-only typed routes expose a home, the unchanged S1
  synthetic screen and reader feasibility. Product entry point/routes unchanged.
- Shared diagnostics: added `lib/core/diagnostics/bounded_ring.dart`; added a
  source-subscription generation guard in `diagnostic_recorder.dart`. S1
  `DiagnosticRecord` schema v1, defaults, generated models and existing tests
  are unchanged.
- Reader probe data: added `lib/features/diagnostics/data/book_digest.dart`,
  `probe_book_repository.dart`, `reader_preparation_repository.dart`,
  `probe_turn_session.dart`, `presentation_probe.dart`,
  `reader_probe_recorder.dart`, `reader_probe_summary.dart`,
  `reader_export_repository.dart`, `reader_feasibility_record.dart` and its
  generated `.freezed.dart` / `.g.dart`.
- Reader probe UI: added `lib/features/diagnostics/presentation/reader_probe/`
  files `reader_probe_screen.dart`, `reader_probe_controller.dart`,
  `reader_probe_controls.dart`, `reader_probe_settings.dart`,
  `reader_probe_capture.dart`, `reader_scenario_runner.dart`,
  `scenario_frames.dart`, `scenario_scripts.dart`, `scenario_target.dart`.
  Includes digest-only Documents book selection, unsupported/error states,
  settings, section jumps, declarations, capture, automatic per-repeat export
  and bounded clipboard summary.
- Engine hooks: modified `lib/features/reader/engine/motion/` files
  `reader_turn_controller.dart`, `turn_controller_pointer.dart`,
  `turn_controller_drag.dart`, `turn_controller_work.dart`, `turn_session.dart`,
  plus `engine/surface/prepared_reader.dart`. Diff review confirms optional
  sink interfaces/calls, opaque input access and a test-only frame reader;
  admission decisions, gesture constants, motion curves, queue bounds,
  navigation/proof/acceptance and surface ownership behavior are preserved.
  Reader core imports no diagnostics.
- Localization: `lib/l10n/app_zh.arb` plus generated
  `app_localizations.dart` / `app_localizations_zh.dart`.
- Tests: added `test/app/probe_app_test.dart`; diagnostics data tests
  `probe_book_repository_test.dart`, `reader_export_repository_test.dart`,
  `reader_probe_recorder_test.dart`; presentation tests
  `reader_probe_screen_test.dart`, `reader_scenario_runner_test.dart`,
  `reader_submission_test.dart`; helper `test/helpers/reader_probe_fixtures.dart`.
  Added optional timing injection to the existing
  `test/features/reader/engine/surface/surface_test_support.dart`.

Scenario coverage (default three scripted repeats; R11 is one manual run):

| ID | Implementation | Fixture | Deferred evidence |
| --- | --- | --- | --- |
| R01 | 40 next and 40 previous taps, warm neighbors | `long-content` | Device timing/presentation |
| R02 | Slow drag, flick, reversal, first/last-page rebound | `chapters` | Device timing/presentation |
| R03 | Cold neighbor held behind probe preparation barrier; release while finger remains down | `long-content` | Device late-neighbor observation |
| R04 | 16 rapid taps exercise FIFO/overflow; jump cancels pending turns | `chapters` | Device timing/presentation |
| R05 | Cold/warm chapter crossings in both directions | `chapters` | Device timing/presentation |
| R06 | Locate the section containing a >=100,000-code-unit text block, then traverse all its pages | `long-content` | Device long-paragraph cost |
| R07 | Traverse all sections/pages containing text, raster and SVG cases | `images` | Device visual/presentation check |
| R08 | Mid-book font size/line height reflow, CFI anchor restore, subsequent turns | `styles` | Device typography/anchor observation |
| R09 | Suspend/resume controller during motion and held preparation | `chapters` | Actual OS lifecycle run; scripted run explicitly declares simulation |
| R10 | 100 alternating turns and 12 cold jumps with memory/cache snapshots | `long-content` | Device resource trend |
| R11 | Manual user-book capture, one repeat, >=50 accepted turns; early stop explicitly incomplete | Documents book, SHA-256 identity only | User places/reads each real book on device |

Scripted input uses `GestureBinding.handlePointerEvent` through the real
`PreparedReader` Listener. It sends at most one move per actual frame, keeps
actual timestamps on slower displays, and declares nominal 8333-us cadence
and `synthetic_injected`; manual input is `manual_touch`. Schedule tests
cover R01-R11 event counts, cadence, cancellation and control API calls.
They do not establish real-device scenario results.

Correlation contract for the next parts:

- Engine `TurnTraceSink.recordTurn(...)` and `TurnFrameSink.submitted(...)`
  receive the same opaque `TurnIntent` identity. The recorder maps it through
  a per-capture `Expando<int>` to exported `inputId`; no intent, anchor, CFI or
  book text is serialized. A drag's release generation change keeps the same
  input ID and produces only one first-submission event. FIFO inputs retain
  their own IDs for queue-wait and warm-input submission aggregates.
- `PreparedReader` snapshots input, controller generation, controller owner
  and sink `frameEpoch`, then reads the engine frame number in a same-frame
  post-frame callback. Owner/generation/epoch changes reject pending samples.
  Start/dispose increment the capture epoch; the S1 source-generation guard
  rejects callbacks retained from previous subscriptions.
- Fixed an integration failure where an offset rewrite in a control task
  read scheduler timestamps outside a frame. The additive sampling hook now
  skips idle/post-frame writes; the next ticker samples the rendered motion.
  The real injected-drag test verifies post-frame reads, the first submission's
  exact engine frame number, matching raw timing/motion frame IDs and the same
  opaque/exported input ID through receipt, submission and acceptance.
- Fixed the privacy integration test's timing race by awaiting real neighbor
  preparation before advancing its injected motion clock. It still runs the
  real preparation, navigation and proof pipeline, then checks exported JSON
  for absence of fixture title, prose, EPUB filename and CFI.

Export is `kind: reader_feasibility`, `schemaVersion: 1`, with top-level keys
`kind`, `schemaVersion`, `bookSha256`, `fixtureId`, `scenarioId`, `repeatIndex`,
`repeatCount`, `input`, `engine`, `readerEvents`, `layoutCosts`, `resources`,
`presentation`, `aggregates`, `overflow`, `omissions`. `engine` composes the S1
v1 timing schema with reader scenario identity, build/viewport metadata,
declarations, raw frames/motion, clock boundaries and stage aggregates.
Exports use `shiori-reader-<BUILD_ID>-<runId>.json` in Documents; clipboard
summaries stay within 4000 UTF-8 bytes. Invalid/missing schema versions are
rejected at the repository boundary. Reader events/layout/resources default
to 16384 samples each; the screen uses 65536 engine samples, a ten-minute
capture limit and the existing 1200-ms drain. Overflow and trailing-batch
incompleteness remain explicit; no threshold was weakened.

Part 2 implements `PresentationProbe` in
`lib/features/diagnostics/data/presentation_probe.dart`:
`Future<PresentationReport> install()`,
`Future<void> start({required String runId, required PresentationMode mode})`,
`Future<PresentationReport> stop()`, `Future<void> dispose()`. Modes are
`inventory`, `a1`, `a2`, `b`. Return availability/evidence/omission, inventory,
raw samples and native overflow through `PresentationReport`; native clock
epochs stay separate from Dart. Inject the client into `ReaderProbeRecorder`
at `reader_probe_screen.dart`. The current unavailable implementation exports
`native_client_not_installed_phase_e_part_1` and explicit unverified evidence.
Native hooks/client, offline analyzer and packaging/privacy guards are deferred
because they belong to parts 2/3. Physical presentation and touch-to-photon
remain unverified; NC6 as a whole also awaits part 3's analyzer reproduction.

Part 1 checks, final sequential run from repository root:

| Command | Timeout | Exit / result | Duration |
| --- | --- | --- | --- |
| `dart run build_runner build` | 900 s | 0; generated outputs refreshed, no extra tracked diff | 5.544 s |
| `dart format --set-exit-if-changed lib test tool/reader` | 180 s | 0; 226 files, 0 changed | 0.835 s |
| `flutter analyze` | 180 s | 0; no issues | 3.239 s |
| `flutter test --reporter expanded` | 900 s | 0; 823 passed, 1 skipped, 0 failed | 15.184 s |

The requested focused `flutter test test/features/diagnostics test/app` run
also passed: 60 tests, exit 0, within its 600-s timeout. The full suite's sole
skip is the existing optional native-CFI export guarded by
`SHIORI_NATIVE_CFI_OUT`. `tool/diag` does not yet exist and was omitted from
formatting as requested. Initial failures (gesture integration, privacy-test
clock ordering, formatting and nine lint findings) were fixed without dropping
assertions or reducing coverage. Coordinating workspace files retained exact
bytes. No prohibited/product/native/CI/reference/fixture files changed.
Cross-part contracts and the sampling regression lesson are retained here
for later spec synchronization within the coordinator's broader scope.

### Phase E part 2

Implemented on 2026-10-23, on `ios-build/s2-reader-probe`, without committing,
pushing, changing the product plist, or changing the Xcode project. **The Swift
code was not compiled locally.** Windows cannot verify Swift compilation,
Objective-C IMP ABI/ownership, or device presentation. Native modes remain
unverified until the later macOS CI build and device iteration. This is a
local part-2 PASS, not completion of NC6-NC9 or the whole Phase E gate.

Pinned source recheck: local `bin/cache/flutter.version.json` confirms Flutter
3.47.7 / Dart 3.13.5, framework
`abaf9c523780a608bd46686fd5e53740a07077f8`, engine
`deb287481e3ce9468f3434937ced4240a70539ca`. Paths in the following table are
relative to `D:/DevTools/flutter/engine/src/flutter/shell/platform/darwin/ios/`.
Every cited hook matched `research/s2-entry-evidence.md`; no replacement
engine-private hook was invented.

| Mode | Checked hook or boundary | Pinned source file:line | Matches note |
| --- | --- | --- | --- |
| Inventory / all | FlutterView layer selection | `framework/Source/FlutterView.mm:193-195`; `rendering_api_selection.mm:59,65-68` | yes |
| Inventory / variants | Default enabled; only explicit false disables FlutterMetalLayer | `framework/Source/FlutterMetalLayer.mm:459-470` | yes |
| A1 / A2 | Main-thread contents assignment inside CATransaction | `framework/Source/FlutterMetalLayer.mm:398-414` | yes |
| A1 / A2 | Texture timestamp and main-thread dispatch | `framework/Source/FlutterMetalLayer.mm:425-442` | yes |
| A2 | Existing layer display link, rate range, double-commit boost, idle pause | `framework/Source/FlutterMetalLayer.mm:187-189,203-228,415-421` | yes |
| B | Alternate CAMetalLayer selected when default layer disabled | `rendering_api_selection.mm:65-68`; `framework/Source/FlutterMetalLayer.mm:459-470` | yes |
| B exclusion on default | FlutterDrawable presentedTime is zero; handler only warns | `framework/Source/FlutterMetalLayer.mm:118-119,133-135` | yes |

Registration was also checked against `framework/Headers/FlutterEngine.h:456-490`
and `framework/Headers/FlutterPlugin.h:297,472`. The implicit-engine registrar
provides the messenger; SceneDelegate is untouched. `ios/Runner/Info.plist`
still has no `FLTUseFlutterMetalLayer` key. `FlutterMetalLayer.mm` has no own
`setContents:` implementation: A adds an override to that class with
`class_addMethod`, preserving CALayer's inherited original IMP. It does not
replace CALayer's implementation.

Swift static self-review (source review only; SDK availability must still be
confirmed by the macOS compiler):

- [x] Flutter APIs: existing `FlutterAppDelegate.application` and
  `FlutterImplicitEngineDelegate.didInitializeImplicitFlutterEngine`,
  `GeneratedPluginRegistrant.register`, `pluginRegistry.registrar(forPlugin:)`,
  `messenger()`, `FlutterMethodChannel`, `setMethodCallHandler`,
  `FlutterMethodCall.method/arguments`, `FlutterResult`, `FlutterError`, and
  `FlutterMethodNotImplemented` are from the pinned framework. Retain the
  channel in AppDelegate; registration does not instantiate the probe.
- [x] UIKit: `UIApplication.shared.connectedScenes`, `UIWindowScene.windows`,
  `UIWindow.isKeyWindow`, `UIView.subviews/layer` find the current key-window
  FlutterView without loading another controller. Scene APIs require iOS 13;
  project deployment target is iOS 15. `UIScreen.main.maximumFramesPerSecond`
  (iOS 10.3+) and `UIDevice.current.systemVersion` provide inventory only.
  Missing view/class/variant yields an explicit omission. Multiple-window
  selection and view readiness need a device check.
- [x] Foundation: `NSObject`, `Thread.isMainThread`, `Bundle.main` /
  `object(forInfoDictionaryKey:)`, `NSNull`, `NSLock.lock/try/unlock`, and
  `ProcessInfo.processInfo.isLowPowerModeEnabled/thermalState.rawValue` are
  available below the iOS 15 baseline (low power: iOS 9; thermal: iOS 11).
  Control/UI work runs on main. Ring state, weak target layer, generation,
  counters and lookup slots are all protected by the buffer lock.
- [x] QuartzCore: `CALayer`, `CACurrentMediaTime`, `CADisplayLink` creation,
  `timestamp`, `targetTimestamp`, `add(to:forMode:)`, `invalidate`, main/common
  run loop, and `CAFrameRateRange` / `preferredFrameRateRange` are compatible
  with the iOS 15 baseline (frame-rate range requires iOS 15). A1 has no extra
  display link; A2 requests 60-120 Hz, preferred 120, and invalidates on
  stop/dispose. This request can perturb pacing and cannot establish scan-out.
- [x] Objective-C runtime: `NSClassFromString`, `NSStringFromClass`,
  `NSSelectorFromString`, `object_getClass`, `class_getInstanceMethod`,
  `class_addMethod`, `method_getImplementation`, `method_getTypeEncoding`,
  `method_setImplementation`, `imp_implementationWithBlock`, and
  `imp_removeBlock` are longstanding APIs below iOS 15. Exact class identity
  guards A/B; FlutterMetalLayer's custom `isKindOfClass:` is not trusted.
  C IMP signatures and block bridging require compiler/device confirmation.
- [x] Metal: `CAMetalLayer.nextDrawable`, `CAMetalDrawable.layer`,
  `MTLDrawable.drawableID`, `presentedTime`, and public `addPresentedHandler:`
  are below the deployment baseline (presentation handlers/time/ID: iOS 10.3).
  B calls the original +0-returning nextDrawable IMP using `Unmanaged` before
  attaching a handler. The shared Objective-C callback block is bridged once
  at install and passed to the public handler method through its typed IMP;
  no fresh Swift closure bridge is constructed per drawable. The callback
  can run off main and only accesses the thread-safe buffer. Validate ABI,
  +0 ownership, handler invocation, and Metal's internal block retain/copy
  costs on Mac/device. The original nextDrawable can itself wait in Metal;
  the probe does not add a waiting lock.
- [x] Swift storage/runtime: `UnsafeMutablePointer.allocate/initialize`,
  `Unmanaged.passUnretained/toOpaque/takeUnretainedValue`, `unsafeBitCast`,
  `type(of:)`, identity comparisons, and `@convention(c/block)` are standard
  Swift/runtime facilities. Preallocate 16384 sample structs, 16384 lookup
  indices and one Int64 contention counter at install; keep them alive for
  permanent hooks and late callbacks. Native hooks create no sample maps,
  arrays, strings, tasks or per-frame capture closures. Export allocation
  happens after disabling capture. Confirm actual allocation overhead with
  native profiling; source review cannot certify framework internals.
- [x] Darwin `OSAtomicIncrement64Barrier` and `OSAtomicAdd64Barrier` count
  failed try-locks using stable allocated Int64 storage, avoiding concurrent
  Swift inout access to a stored property. These APIs predate iOS 15 and are
  deprecated since iOS 10; their Swift import/link availability and warnings
  need the pinned Xcode build. Every hook buffer lock uses `NSLock.try()`;
  only the control plane uses a waiting lock. No dispatch or blocking probe
  synchronization is introduced in the callback path.
- [x] Bounds/lifecycle: head/count always index modulo 16384; the drawable-ID
  hash lookup is bounded and validates ID, object address and run generation
  before updating a slot. Reset lookup on start, disable before exporting,
  ignore callbacks while disabled and never free hook-owned storage on
  dispose. Eviction, active lookup misses and try-lock drops increment loss
  counters. Confirm drawable identity lifetime and stale callbacks across
  repeated runs on device. Swizzles install once and remain inert afterward.

Dart implementation and tests:

- `lib/features/diagnostics/data/method_channel_presentation_probe.dart`: inert
  construction; install/start/stop/dispose; missing-plugin and platform-error
  fallback with safe omission codes; best-effort native disposal on channel
  failures. `presentation_payload.dart` validates mode/evidence, inventory,
  bounded sample shapes, finite native seconds, unsigned drawable-ID strings
  and counters, throwing typed `ParseException` for malformed data.
- `presentation_probe.dart`: mode evidence labels, contention loss metadata,
  configurable `UnavailablePresentationProbe` fallback (supersedes part 1's
  temporary omission code). `reader_probe_recorder.dart` exports selected
  mode and completes pending captures with native parse errors.
- `reader_probe_screen.dart` injects the channel client only into the reader
  probe; `reader_probe_capture.dart` surfaces parse failures safely. Existing
  mode selector reused; `app_zh.arb` removes its part-1 placeholder and names
  A1/A2/B clearly. Both generated localization Dart files were regenerated
  with `flutter gen-l10n` (exit 0). No model/codegen input changed.
- New `test/features/diagnostics/data/method_channel_presentation_probe_test.dart`
  (37 tests), `presentation_export_test.dart` (7),
  `test/app/product_presentation_isolation_test.dart` (1), and
  `test/helpers/presentation_probe_fixtures.dart`; expanded
  `test/features/diagnostics/presentation/reader_probe_screen_test.dart` (+1).
  Mock channels use `TestDefaultBinaryMessengerBinding`; tests cover all
  modes, lifecycle, malformed payloads, fallbacks, raw clock/overflow export,
  recoverable native-stop failure, actual selector-to-channel wiring, and
  the real product entry point making zero channel calls.

Final local gate (explicit subprocess timeouts; no gate constants changed):

| Command | Timeout | Exit / result |
| --- | --- | --- |
| `dart format --set-exit-if-changed lib test tool/reader` | 180 s | 0; 232 files, 0 changed |
| `flutter analyze` | 180 s | 0; no issues |
| `flutter test --reporter expanded` | 900 s | 0; 869 passed, 1 skipped, 0 failed |

46 tests were added to the part-1 baseline. The existing optional native-CFI
export remains the sole skip. Initial focused-test binding setup and six
test-only missing-brace lint findings were corrected before this gate.
`tool/diag` still does not exist, so it is omitted from formatting.

Part 3 handoff: identify variants from both inventory.layerClass and the
nullable inventory.FLTUseFlutterMetalLayer (`null` means absent): default
FlutterMetalLayer with absent/default key; B requires exact CAMetalLayer and
explicit false. Packaging must create the false-key variant; this session
does not modify Info.plist or CI. Evidence labels are exactly `metadata`,
`layer_commit_cadence`, `layer_commit_cadence_per_display_period`, and
`system_drawable_presentation_non_product_path`. Native channel start returns
null; install/stop return report maps. Export `presentation.mode` is the
selected mode even when the channel is unavailable.

Raw sample shapes: `{kind: layer_commit, timestamp: seconds}`,
`{kind: display_link, timestamp: seconds, targetTimestamp: seconds}`, and
`{kind: drawable, timestamp: acquisitionSeconds, drawableId: decimalString,
presentedTime: secondsOrZero}`. Treat drawable IDs as unsigned decimal strings,
not signed codec integers. B records acquisitions immediately with zero, then
updates the retained slot when its presented callback arrives. Zero at stop
means no presented time observed by that stop, including pending/lost callbacks;
do not infer scan-out failure from zero. All-zero B yields
`no_presented_drawables_at_stop`; A2 missing either stream yields an explicit
omission. Native capture includes the reader engine's timing-drain interval.
No Dart/native clock epoch or event correlation is inferred.

`overflow` is the total lost native-event count (evicted samples, unmatched
active drawable updates, try-lock drops), not a count of unique lost frames;
`contentionDrops` is the included try-lock subset. Both are exported; native
overflow is also in the record's `overflow.native`. Any losses must qualify
cadence/binning conclusions. A2 bins raw commits against display-link periods
(0 repeated, 1 new, >=2 overwritten); compare A1/A2 for link perturbation and
do not fabricate missing periods or physical/touch-to-photon evidence. The
spike's one-device-iteration plus at-most-one-fix time box remains pending.

### Phase E part 3a

Implemented the offline reader export analyzer on 2026-10-23. This section
records part 3a only; part 3b owns packaging, privacy guards and the final
Phase E decision. No commit, push, branch switch or product/native edit.

Files added:

- `tool/diag/analyze_reader_export.dart`: pure Dart CLI, multiple input files,
  `--strict`, schema/kind refusal, Markdown output and documented exit codes.
- `tool/diag/reader_export_data.dart`: independent JSON access, percentile
  conventions, symmetric aggregate comparison and all named gate constants.
- `tool/diag/reader_engine_analysis.dart`: engine frame-number matching, stage
  and interval distributions, missing-identity accounting and motion stalls.
- `tool/diag/reader_input_analysis.dart`: capture-local input identity joins,
  reader distributions, event counters and per-input proof/acceptance counts.
- `tool/diag/reader_native_resources.dart`: resource OLS trends and mode-specific
  native-clock reductions, including explicit loss/contention accounting.
- `tool/diag/reader_export_analysis.dart` and `reader_export_report.dart`: gate
  decisions, omissions/overflow, aggregate differences and repeat summaries.
- `test/helpers/reader_analyzer_exports.dart`: deterministic raw samples,
  production model encoding and app-generated reader/engine aggregates.
- `test/tool/diag/reader_export_{parity,metrics,contract,evidence,cli,privacy}_test.dart`.
- Nine JSON exports plus `test/fixtures/reader/exports/README.md`.

The analyzer imports only Dart SDK libraries and its own tool helpers. It
imports no application model, summary, Flutter package or `dart:ui`. The
fixture generator deliberately imports production summaries on the reference
side: `ReaderProbeSummary.aggregate` and `DiagnosticSummary.aggregate`. It
never imports analyzer code. All eight supported fixture exports independently
match every reader and nested engine aggregate; the ninth tests version refusal.
S1 and reader percentile conventions are preserved separately.

| Aggregate / gate row | Raw source | Threshold / interpretation | Coverage |
| --- | --- | --- | --- |
| UI and raster P50/P95/P99/max, over8333Us, within-budget fraction | Engine frames joined to nonnegative motion frame IDs | Each stage independently >=99% <=8333 us | `motion stage distributions and separate 99 percent budgets`; exact 99/98% and budget boundary tests |
| Engine cadence distribution and classification | Vsync-start deltas only for consecutive matched engine frame numbers | atLeast12500Us; cadence is engine identity evidence | `engine cadence is consecutive matched engine identity only` |
| Motion stall candidates | Matched stage costs, consecutive engine intervals and recorder submission gaps within first-submission/settle windows | >=50000 us; a candidate fails pending explanation; missing IDs/adjacency/windows or overflow prevent an absence claim | Stall, idle-window, inclusive-threshold and open-window tests |
| Warm admitted receipt-to-first-submission P95 | readerEvents inputId within one export/capture epoch | <=16700 us; unqueued, no preparationMiss; generation changes do not break identity | Warm-latency, incomplete-join, epoch-isolation and inclusive-boundary tests |
| Queue wait, all input preparation, cold input/section preparation, paragraph layout | Reader events and layoutCosts.layoutUs | Report separately; no invented cold/queue threshold | Warm/queue/preparation and paragraph-layout tests |
| Fallback count/rate, accepted turns, event/proof/rejected counters | Reader events, accepted denominator | Proof failures=0; one accepted per proofPassed input proxy | `paragraph layout, fallback rate and observable correctness`; proof/duplicate/unpaired tests |
| Per-input accepted destination counts and stale callbacks | inputId proofPassed/accepted counters | Explicit commit/destination identities and stale-callback observations are absent in v1; broader correctness stays unavailable | Correctness, missing-identity and omission tests |
| Resource first/last/max, RSS delta and OLS slope per second | resources monotonicUs/liveSurfaces/pictureBytes/imageBytes/rssBytes | >=100 accepted turns; bounded ownership cannot be certified without caps/warm-up/cycle/direction evidence | 100-turn, missing-time and nonuniform-time OLS tests |
| A1 commit interval distributions | Native layer_commit.timestamp | Layer-commit cadence only | `native A1 intervals retain their own clock` |
| A2 commits per recorded display period 0/1/>=2 | layer_commit plus display_link timestamp/targetTimestamp | Half-open periods; outside-period commits counted; no missing periods invented | A2 boundary/bin and overlap tests |
| B presented/not-observed-by-stop counts and presentation intervals | drawable.presentedTime, zero excluded from interval computation | System drawable evidence on non-product path; zero may be pending/lost | B mixed/zero-only and native-epoch tests |
| Native metadata, omissions and overflow | presentation and top-level omissions/overflow; engine errors/trailing state | contentionDrops is a subset of native overflow; no cross-clock epoch inference | Metadata/mode/stream/subset, overflow and omission tests |
| Repeat summary and app aggregate parity | Separate raw reductions per export, grouped by scenario/book/fixture/input/native mode | >=3 repeats except R11; duplicate/missing/inconsistent repeats explicit; --strict mismatch exit=1 | Repeat-summary, nine fixture-parity and CLI tests |

Fixture list (all use synthetic digest/fixture ID, with no book text):

- `passing-120hz-a1-{1,2,3}.json`: complete three-repeat 120 Hz-like stage
  and A1-cadence example, warm/queued/cold work, layout/fallback/correctness
  counters and resource samples. UI/raster=100%; warm P95=16000 us.
- `failing-budgets-a2.json`: UI and raster both fail; A2 periods exercise
  0/1/>=2 and a boundary/outside-period commit.
- `stall-b.json`: 58333 us engine/submission stall inside motion; B includes
  two observed presentations, one zero at stop and an unsigned drawable ID.
- `negative-missing-frames.json`: negative engine/motion IDs, missing engine
  frame 3 and missing motion frame 5; only one cadence interval remains.
- `overflowed-rings.json`: all retained reader/engine rings have recorded
  loss; native overflow=2 includes contentionDrops=1.
- `resources-100-turns-unavailable.json`: 100 accepted input identities,
  first/last/max/slopes and an explicit native-unavailable omission.
- `unknown-schema.json`: version 2, refused with exit 65.

Regenerate from repository root in PowerShell (full notes in fixture README):

```powershell
$env:REGENERATE_READER_EXPORTS = '1'
try {
  flutter test test/tool/diag/reader_export_parity_test.dart --reporter expanded
} finally {
  Remove-Item Env:REGENERATE_READER_EXPORTS
}
```

Ordinary tests perform structural comparisons with fresh app-produced JSON;
they do not write fixtures, and CRLF/LF differences do not affect parity.
Privacy coverage loads every bundled EPUB via the existing `openFixture`
helper, checks its sentences and the existing 12-character prose-fragment
boundary against all nine exports, and also rejects EPUB filenames/CFIs.
Assertions do not print the prose on failure. Only synthetic book identities
are persisted. No user-book content is read by the analyzer or fixture helper.

Validation (explicit subprocess timeouts; no gate constants changed):

| Command | Timeout | Exit / result |
| --- | --- | --- |
| `flutter test test/tool/diag --reporter expanded` | 180 s | 0; 49 passed, 0 skipped/failed |
| `dart format --set-exit-if-changed lib test tool/reader tool/diag` | 180 s | 0; 246 files, 0 changed |
| `flutter analyze` | 180 s | 0; no issues |
| `flutter test --reporter expanded` | 900 s | 0; 918 passed, 1 skipped, 0 failed |
| `dart run tool/diag/analyze_reader_export.dart test/fixtures/reader/exports/passing-120hz-a1-1.json` | 120 s | 0; Markdown tables; app aggregate MATCH |

49 tests added: 9 fixture parity, 13 metrics, 13 contracts, 8 evidence,
5 CLI and 1 privacy. The existing optional native-CFI test is the sole skip.
Passing samples have no observed budget/submission/stall/proof/count violation;
the intentional budget/stall fixtures fail their measurement rows. Loss,
unavailable modes and unobserved correctness/resource/presentation guarantees
remain explicit. `--strict` governs aggregate parity, not device acceptance.
No app-side aggregation discrepancy was found. Schema-v1 observation gaps
are reported as limitations rather than repaired or inferred in this part.

## Phase E — probe harness, analyzer, native spike, CI

Final local gate: PASS on 2026-10-23, Windows, Flutter 3.47.7 / Dart 3.13.5,
branch `ios-build/s2-reader-probe`, committed base `25bac2d`. Parts 1, 2, 3a
and 3b remain uncommitted. This closes the local Phase E implementation and
validation scope; CI compilation, device acceptance and Phase F remain pending.
The earlier part-by-part entries above retain their historical results.

Part 1 supplies the isolated reader probe, synthetic/manual book inventory,
settings, R01–R11 scenario injection, bounded recorder, preparation/session
adapters and private exports. It reuses the existing reader data/layout/motion
and prepared surfaces. S1 capture/export compatibility remains covered. Part 2
supplies the Swift inventory/A1/A2/B presentation spike and its typed Dart
method-channel client, with native clocks and evidence levels kept separate.
Part 3a supplies the independent pure Dart analyzer, deterministic app-produced
fixtures, parity/CLI/privacy tests and explicit evidence omissions. Part 3b
closes the correctness/resource observation gaps, regenerates the fixture set,
adds the Git/manifest guard and packages the two variants from one build.

Files by area (the full Phase E worktree, including earlier parts):

| Area | Files |
| --- | --- |
| Probe entry and shared capture | `lib/app/probe_app.dart`, `lib/app/probe_app.g.dart`, `lib/core/diagnostics/bounded_ring.dart`, `lib/core/diagnostics/diagnostic_recorder.dart` |
| Diagnostics data | `lib/features/diagnostics/data/book_digest.dart`, `probe_book_repository.dart`, `probe_turn_session.dart`, `reader_preparation_repository.dart`, `reader_probe_recorder.dart`, `reader_probe_summary.dart`, `reader_export_repository.dart`, `reader_feasibility_record.dart`, `reader_feasibility_record.freezed.dart`, `reader_feasibility_record.g.dart`, `presentation_probe.dart`, `presentation_payload.dart`, `method_channel_presentation_probe.dart` (all basenames in that directory) |
| Probe presentation | `lib/features/diagnostics/presentation/reader_probe/reader_probe_screen.dart`, `reader_probe_controller.dart`, `reader_probe_capture.dart`, `reader_probe_controls.dart`, `reader_probe_settings.dart`, `reader_scenario_runner.dart`, `scenario_target.dart`, `scenario_scripts.dart`, `scenario_frames.dart` (all basenames in that directory) |
| Engine observation | `lib/features/reader/engine/motion/turn_session.dart`, `reader_turn_controller.dart`, `turn_controller_pointer.dart`, `turn_controller_drag.dart`, `turn_controller_work.dart`; `lib/features/reader/engine/surface/prepared_reader.dart` |
| Native/localization | `ios/Runner/AppDelegate.swift`; `lib/l10n/app_zh.arb`, `app_localizations.dart`, `app_localizations_zh.dart` (native/localization changes are from earlier parts; not edited in 3b) |
| Analyzer | `tool/diag/analyze_reader_export.dart`, `reader_export_data.dart`, `reader_export_analysis.dart`, `reader_engine_analysis.dart`, `reader_input_analysis.dart`, `reader_native_resources.dart`, `reader_export_report.dart`, `reader_correctness_analysis.dart`, `reader_resource_gate.dart` (all basenames in that directory) |
| CI | `tool/ci/check_reader_fixtures.dart`, `tool/ci/build_ios_unsigned.sh`; workflow unchanged |
| App/probe tests | `test/app/probe_app_test.dart`, `product_presentation_isolation_test.dart`; `test/features/diagnostics/data/probe_book_repository_test.dart`, `reader_probe_recorder_test.dart`, `reader_export_repository_test.dart`, `method_channel_presentation_probe_test.dart`, `presentation_export_test.dart`; `test/features/diagnostics/presentation/reader_probe_screen_test.dart`, `reader_scenario_runner_test.dart`, `reader_submission_test.dart` |
| Engine/tool tests | `test/features/reader/engine/motion/reader_turn_evidence_test.dart`; `test/features/reader/engine/surface/surface_test_support.dart`; `test/tool/diag/reader_export_parity_test.dart`, `reader_export_metrics_test.dart`, `reader_export_contract_test.dart`, `reader_export_evidence_test.dart`, `reader_export_cli_test.dart`, `reader_export_privacy_test.dart`, `reader_correctness_resource_test.dart`; `test/tool/ci/check_reader_fixtures_test.dart` |
| Helpers and fixtures | `test/helpers/reader_probe_fixtures.dart`, `presentation_probe_fixtures.dart`, `reader_analyzer_exports.dart`; `test/fixtures/reader/exports/*.json` (12 files) and `README.md`; `test/fixtures/reader/source_edge/manifest.json` |
| Evidence | This appended section and `evidence/quality-gate-E.json` |

The engine imports no diagnostics code. Part 3b only adds sink observations
in motion code; existing turn, proof, queue, cancellation and resource behavior
is unchanged. Resource metadata reads existing configured values directly from
`PageSurfacePool` and its `ReaderImageCache`; no cap copies or engine cache
changes were needed. Product entry/routes, bundle ID, signing, plist source,
dependencies and workflow triggers/permissions were not changed. Coordinator
journal files were left untouched by this session.

Additive export contract (`kind: reader_feasibility`, `schemaVersion: 1`):

| Field/event | Producer and contract | Analyzer rule |
| --- | --- | --- |
| `engine.metadata.readerCorrectnessVersion: 1`, `captureEpoch` | Recorder capability and capture identity; S1 schema remains unchanged | Missing capability/epoch leaves the combined correctness gate unavailable with a reason |
| `readerEvents[].captureEpoch`, `inputId` | Recorder maps opaque engine input objects to capture-scoped IDs; known old inputs retain their original epoch across restart | Join correctness by epoch and ID within one export; never infer identity from generation or join exports |
| `generation`, `activeGeneration` | Engine supplies callback token and current generation | Acceptance with a different active token, foreign epoch or prior invalidation/rejected token is a stale publication and fails |
| `inputCommitted` | Engine emits immediately before `session.navigate`, after settlement; boundary/rebound/no-turn inputs have no navigation commit | Exactly one acceptance per explicit commit, and no acceptance before a commit; duplicate commits/acceptances or missing acceptance fail |
| `staleCallbackRejected` | Engine generation/pair guards report discarded work with its original input/token | Report rejection count separately; safe rejection alone is not a correctness failure |
| `proofPassed`, `proofFailed`, `accepted.destination` | Engine proof/acceptance seam; destination contains `sectionIndex`, `pageIndex`, `layoutGeneration`, and recorder-hashed SHA-256 `pageIdentity` | Zero proof failures; required destination fields must exist; missing evidence is unavailable rather than fabricated |
| `engine.metadata.resourceCaps` | Active pool's `presentedCapacity`, `reserve`, `maxPictureBytes`, and active image cache's `maxBytes` become `liveSurfaceCap`, `liveSurfaceReserve`, `pictureCacheBytes`, `imageCacheBytes` | Observed live maximum <= cap + reserve; picture/image maxima <= their declared byte caps |
| `resources[].rssBytes`, `monotonicUs` | Existing snapshots from `ProcessInfo.currentRss` and recorder monotonic clock | Report first/last/max and OLS slope; apply the named RSS rule below |

Correctness requires zero proof failures, zero stale publications, one accepted
destination per committed input and no acceptance without a commit. Missing
fields and event overflow prevent a passing absence claim; definite observed
violations still fail. Acceptance identity contains no CFI, page text, layout
key string, book title or user-book filename. Hashing happens at handoff, not
per motion tick.

The resource rule requires >=100 accepted turns, complete retained events and
resource snapshots, declared caps, and at least two distinct snapshot times.
`ReaderGates.maximumRssGrowthFraction = 0.05`: both endpoint growth (`last-first`)
and OLS slope projected over the observed duration must be <=5% of positive
first RSS, inclusive. Negative growth is permitted. Any observed cap/RSS breach
is unbounded and fails, including on partial captures; otherwise missing caps,
samples, duration, turns or overflow leave the gate unavailable. This is an
observational bound over the captured run, not an indefinite leak guarantee.
R10 supplies the alternating-turn/repeated-jump workload; telemetry does not
independently certify direction, warm-up completion or cycle completeness.
Existing budget, latency, stall and repeat constants were not weakened.

Scenario coverage implemented and exercised through injected control seams:

| Scenario | Coverage |
| --- | --- |
| R01 | 40 next taps followed by 40 previous taps |
| R02 | Slow settlement, flick, reversal and boundary rebound |
| R03 | Held pointer and delayed neighbor preparation |
| R04 | FIFO/overflow and programmatic section jump |
| R05 | Cold/warm chapter crossings in both directions |
| R06 | Long-paragraph turns |
| R07 | Mixed text/images, image-only pages and SVG paths |
| R08 | Font/line-height reflow and accepted-anchor restore |
| R09 | Controller/session lifecycle simulation during motion/preparation |
| R10 | >=100 alternating turns, repeated jumps and resource snapshots |
| R11 | Manual user-book capture; >=50-turn completion marker |

Automated scenarios use frame-driven synthetic pointer injection through the
real gesture/controller path. Their local tests establish harness behavior,
not iPhone timing or actual OS background/foreground delivery. R11 has no
scripted substitute. The device step still needs three limiter-off repeats
per mandatory scripted scenario and the manual real-book runs.

Fixture regeneration used the documented `REGENERATE_READER_EXPORTS=1 flutter
test test/tool/diag/reader_export_parity_test.dart` path. All 12 exports match
fresh production app aggregates and independent analyzer recomputation
(unsupported-schema fixture is deliberately rejected). The added fixtures
`double-acceptance.json` and `cap-breach.json` fail their respective gate rows
with aggregate parity intact; `resources-100-turns-bounded.json` passes both
new gates. The retained legacy 100-turn fixture stays unavailable. Privacy
tests check all exports against bundled fixture prose, filenames and CFIs;
the actual prepared-reader export test also remains green. `--strict` still
controls aggregate mismatches, not measurement-gate exit status.

The pure Dart guard runs after enforced-lockfile dependency resolution and
before the single Flutter build. It uses Git's NUL-delimited tracked plus
nonignored-untracked inventory, including tracked files that match ignore
rules. Existing EPUBs outside `assets/reader_fixtures/` fail except the exact
two Phase B edge files with matching byte counts and SHA-256 in their new
manifest. A new file in that edge folder or a new manifest exemption fails.
Asset payloads must exactly match the asset manifest: missing/extra files,
byte drift and equal-size hash drift fail. `manifest.json` and `.gitattributes`
are asset metadata, not fixture payload entries. Missing/malformed manifests,
duplicate/traversal entries and symlink payloads fail closed. Messages omit
discovered private book names and contents. The real repository passes; 17
temporary-directory/real-repository guard tests pass. No EPUB or asset manifest
was changed, and no dependencies were added.

Packaging retains the pins, original validation and failure trap. From the
same validated unsigned `Runner.app` it stages `shiori-probe-<BUILD_ID>.ipa`
and `shiori-probe-<BUILD_ID>-cametal.ipa`. The default copy's plist is compared
byte-for-byte with the source; only the CAMetal copy receives
`FLTUseFlutterMetalLayer=false` using `plutil`. Both staged bundles pass the
same iphoneos/bundle ID/version/executable/arm64/Flutter+App framework checks
before ZIP validation. `sha256.txt` records both names and digests. Provenance
records each variant's file, digest, variant name, actual plist value (null
when absent), and effective value (true when absent; false for CAMetal).
The source bundle/plist is unchanged. The existing `build/ios-probe/` upload
already collects both IPAs and metadata, so the workflow was not edited.

Final sequential repository-root gate (all commands completed without timeout):

| Command | Timeout | Exit | Key result |
| --- | --- | --- | --- |
| `dart run build_runner build` | 900 s | 0 | Generated outputs current; no errors |
| `dart format --set-exit-if-changed lib test tool/reader tool/diag tool/ci` | 180 s | 0 | 252 files; 0 changed |
| `flutter analyze` | 180 s | 0 | No issues |
| `flutter test` | 900 s | 0 | 962 passed, 1 skipped, 0 failed |
| `bash -n tool/ci/build_ios_unsigned.sh` | 180 s | 0 | Git Bash syntax validation |
| `dart run tool/ci/check_reader_fixtures.dart` | 180 s | 0 | Real repository privacy/manifests PASS |
| `dart run tool/diag/analyze_reader_export.dart --strict test/fixtures/reader/exports/passing-120hz-a1-1.json` | 180 s | 0 | Reader and engine aggregates MATCH; 7 pass rows, 0 fail, 2 unavailable |

`evidence/quality-gate-E.json` contains these seven final successful records in the
same array/record shape as Phase A: `command`, `timeoutSeconds`, `exitCode`,
`timedOut`, `durationSeconds`, `outputTail`. Full intermediate logs are local
under ignored `build/phase-e-gate/`. Windows executable resolution initially
selected the WSL launcher for the syntax check; the final sequential run
explicitly resolves Git Bash at `D:/DevTools/git/usr/bin/bash.exe`. No sandbox
or trust settings were changed. Two formatting-expanded brace lints found
during iteration were corrected before the final run.

The suite adds 44 passing tests over part 3a's 918: 18 correctness/resource,
3 export parity fixtures, 17 guard, 4 engine evidence, 1 recorder epoch/privacy
and 1 configured-cap round-trip test. The analyzer area now has 70 tests. The
existing optional native-CFI test remains the sole skip. Product app/S1 tests
are green. A separate `git diff --exit-code HEAD` check returned 0 for the
product entry/app/router/routes, dependency manifests, protected asset corpus,
edge EPUB/WebKit files and workflow. `lib/main.dart` behavior is unchanged as
covered by the existing app tests.

Unverified until CI/device:

- Swift compilation and channel/hook integration with the pinned iOS engine;
  local Dart method-channel tests do not compile or execute Swift.
- Actual macOS `plutil`/`lipo` validation, one-build/two-IPA packaging, both
  IPA checksums/provenance, and hosted artifact creation. Only shell syntax
  was exercised locally. Signing, installation and update retention remain
  device operations.
- All S2 device exports: real R01–R11 workload execution, three limiter-off
  repeats where required, resource/RSS behavior over >=100 alternating turns,
  real OS lifecycle delivery, and manual real-book captures.
- Native A1/A2 cadence, auxiliary-display-link perturbation, B presented
  drawable evidence, and any physical presentation claim. B describes the
  nondefault path only; touch-to-photon remains unverified. NC7–NC9 and the
  device feasibility decision remain pending.

Stopped after the authorized Phase E local gate and evidence. No commit, push,
branch switch, signing, deployment or Phase F work was performed.

### Phase E independent trellis-check review — 2026-10-23

Verdict: **PASS with fixes** for the local Phase E gate. Reviewed in this
session without sub-agents, commits, pushes, stash or branch changes. The
coordinator's two workspace files and `evidence/quality-gate-E.json` were not edited.
The latter remains the earlier implementer gate; this section records the
reviewer's subsequent validation.

Findings and local repairs:

- Medium: app aggregation and independent analyzer joined input events by
  numeric ID alone. A retained old input keeps its previous capture epoch,
  while new inputs restart numbering; late evidence could therefore complete
  another input's latency or motion window. Both reducers now use epoch plus
  ID, with epoch-less legacy records kept separate. First-submission
  deduplication in the recorder also includes the epoch. Added three tests
  for reused IDs, interleaved windows, legacy records and first submissions.
- Medium: the script's unawaited completion observer forwarded malformed
  native-stop errors into an unhandled child future. It now handles that
  observer's failure by cancelling the script; the awaited capture still
  surfaces the typed error through the localized UI. A widget regression
  checks stop failure, no export, no uncaught error and restored controls.
- Medium, defensive native fix: changed the shared `@convention(block)`
  handler conversion from `as AnyObject` to explicit
  `unsafeBitCast(handler, to: AnyObject.self)`. This removes ambiguity at the
  raw handler IMP boundary; this review does not claim the previous cast was
  demonstrated to box incorrectly. Swift/ARC behavior remains a CI/device
  check.
- Low: unmatched drawable callbacks no longer increment ring overflow. A
  separate `unmatchedCallbacks` counter crosses the native/Dart boundary and
  appears in analyzer output. Overflow still includes ring eviction plus
  contention drops, with contention explicitly a subset. Missing new fields
  default to zero; nonzero counts are exported additively. Added three tests
  for channel export, malformed counters and analyzer reporting.

Native review: rechecked the local pinned FlutterMetalLayer contents
assignment and layer-selection flag against the entry evidence. A1 adds an
override only on FlutterMetalLayer and calls the inherited original IMP. B's
global nextDrawable replacement is reached only after mode B starts with the
explicit false plist flag and exact CAMetalLayer class; recording filters the
layer instance. Registration has no buffer allocation or hook installation.
The original nextDrawable call uses +0 `takeUnretainedValue`, then a strong
local and an object-returning block; no explicit unmatched retain/release was
found by source inspection. Runtime ABI/ownership is still unverified.
Deprecated OSAtomic operations were retained: this Swift 5/iOS 15 review
does not introduce a new dependency or an uncompiled atomic replacement.

Other reviewed boundaries: engine changes remain optional additive sink
observations, post-frame engine-ID reads retain owner/generation/epoch guards,
S1 schema/default behavior is preserved, and exports hash page identities
without book text, titles, assertion CFIs or user filenames. Scenario scripts
match R01-R11 fixtures/workloads; R09 explicitly records controller/session
simulation and still requires real OS lifecycle evidence. The analyzer stays
independent of app code and preserves both percentile conventions. The CI
guard precedes the build; insert-versus-replace plist handling, two bundle
validations, checksums/provenance, pins and the original failure trap remain
intact. Only the two exact hashed source-edge fixture names are exempt.

Judgement retained for device review: the existing 5% endpoint/projected-OLS
RSS rule is an implementation-specific observational bound, not a numerical
threshold specified by NC7 and not a proof of no per-cycle growth. R10 starts
with a cold snapshot; warm-up/cycle interpretation still needs the device
report. No gate constants or reference semantics were changed.

Files edited by this reviewer (relative to repository root):

- `ios/Runner/AppDelegate.swift`
- `lib/features/diagnostics/data/presentation_probe.dart`,
  `presentation_payload.dart`, `reader_probe_recorder.dart`,
  `reader_probe_summary.dart`
- `lib/features/diagnostics/presentation/reader_probe/reader_probe_capture.dart`
- `tool/diag/reader_input_analysis.dart`, `reader_native_resources.dart`,
  `reader_export_analysis.dart`, `reader_export_report.dart`
- `test/features/diagnostics/data/reader_probe_recorder_test.dart`,
  `method_channel_presentation_probe_test.dart`
- `test/features/diagnostics/presentation/reader_probe_screen_test.dart`
- `test/tool/diag/reader_input_epoch_test.dart` (new),
  `reader_export_metrics_test.dart`
- This Phase E section of `local-validation.md`

Final checks (explicit subprocess timeouts, no command timed out):

| Command | Timeout | Exit | Result |
| --- | --- | --- | --- |
| `dart run build_runner build` | 900 s | 0 | Generated outputs current |
| `dart format --set-exit-if-changed lib test tool/reader tool/diag tool/ci` | 180 s | 0 | 253 files, 0 changed |
| `flutter analyze` | 180 s | 0 | No issues |
| `flutter test` | 900 s | 0 | 969 passed, 1 skipped, 0 failed |
| `bash -n tool/ci/build_ios_unsigned.sh` | 180 s | 0 | Git Bash syntax passed |
| `dart run tool/ci/check_reader_fixtures.dart` | 180 s | 0 | Manifest/privacy guard passed |

The sole skip is the existing `native_cfi_export_test`, requiring
`SHIORI_NATIVE_CFI_OUT`. Seven regressions were added. All existing export
parity/privacy fixtures pass unchanged; no fixture regeneration was needed.
One new-test null-aware-element lint was corrected before the final gate.
The local log wrapper needed UTF-8 stdout after a successful codegen command;
its command result remained zero. Logs and per-command records are under
ignored `build/phase-e-review/`. A protected-path `git diff --exit-code HEAD`
returned zero for product entry/routes, plist/Xcode/workflow, dependencies,
oracle/assets and task requirement/design/implementation metadata.

Still unverified: native Swift compilation, block/IMP ABI and ownership,
callback identity across repeated captures, actual native hook overhead,
macOS plist/lipo/two-IPA execution, real R01-R11 device runs, A1/A2 observer
effects, B presentation callbacks, and NC7-NC9. This is no claim of physical
presentation or touch-to-photon latency.

### Phase E execution and verification chain

- Implementation: Codex CLI `gpt-6.1-sol` (high, `workspace-write` sandbox,
  reasoning summaries on), split into sequential fresh sessions: part 1 (Dart
  probe, scenarios, recorder, export; finished in a second session after a
  remote-compaction failure), part 2 (Swift presentation probe and Dart
  client), part 3a (offline analyzer), part 3b (export correctness/resource
  fields, fixture guard, two-IPA packaging, final gate).
- Independent gate re-runs after each part: Codex CLI `gpt-6-astra` (high),
  verification only, with before/after file hashes. Results: part 1 823
  passed / 1 skipped; part 2 869 / 1; part 3a 918 / 1; part 3b 962 / 1; all
  scope checks passed each time (product entry/routes, Info.plist,
  project.pbxproj, pubspec, oracle and fixture assets, workflow unchanged).
- trellis-check review: Codex CLI `gpt-6-astra` (high), PASS with fixes (input
  ids across capture epochs, unhandled native-stop error, explicit block
  bridging, separate unmatched-callback counter); post-fix gate 969 passed /
  1 skipped, `bash -n` and the fixture guard pass.
- Kept by decision: deprecated `OSAtomic*` calls (warnings only in Swift 5;
  rewriting synchronization without a compiler is riskier) and the 5 % RSS
  growth rule (to be judged against device data).
- Not verified locally: Swift compilation and hook behaviour, macOS plist
  operations and both IPAs, and all device evidence (NC7-NC9).

## Phase F — runbook, report, evidence and specs (documentation only)

- Implementation: Codex CLI `gpt-6.1-sol` (high). Part 1 wrote
  `device-runbook.md`, completed `feasibility-report.md` (NC1-NC6 pass
  locally, NC7-NC9 pending device run, S4 GO / NO-GO undecided) and moved the
  31 per-command evidence files into `evidence/` with an index; part 2 added
  `.trellis/spec/flutter/reader-engine.md` and updated `directory-structure.md`,
  `quality-guidelines.md`, `diagnostics.md`, `testing.md` and `index.md`.
  Part 2 first hit `account_session_capacity_exceeded` on the upstream proxy
  (also for `gpt-6-astra`) and succeeded on a later retry.
- Verification: Codex CLI `gpt-6-astra` (high), verification only. By the
  user's decision no Flutter gate and no trellis-check review ran for this
  documentation-only phase (part 1's verifier still ran the gate once: 969
  passed, 1 skipped).
  - Part 1: scope, evidence inventory, referenced paths and worktree hashes
    pass. Its "raw bytes differ" result for 30 moved files is a CRLF artefact
    of `core.autocrlf=true`: `git hash-object` of all 31 moved files equals
    the HEAD blobs. Its privacy matches are pre-existing Phase A command
    records (`local-validation.md` Phase A section and
    `evidence/oracle-local-books.json`, unchanged since `f06b933`); the new
    runbook and report contain none.
  - Part 2: scope, dependency versions, numeric claims, S1 text preservation
    and privacy (0 matches) pass. Identifier misses are Flutter SDK or
    package names and an illustrative example, not repository code. One
    pre-existing inaccuracy was corrected by the coordinator:
    `quality-guidelines.md` no longer tells the build to pass SDK, framework
    or engine defines (the Flutter tool injects them; see `diagnostics.md`
    §3). `integration_test/` in `index.md` is an intentional future layer.
- Not verified locally: Swift compilation, both IPAs and all device evidence.
