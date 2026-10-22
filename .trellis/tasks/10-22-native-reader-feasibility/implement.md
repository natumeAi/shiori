# Execution plan: native reader feasibility (S2)

Executor: Codex, continuous mode (user decision 2026-10-22). Run phases in
order. Commit once at the end of each phase on the local branch. Stop and
report when a gate fails or when Phase F is done. Never push, never touch
`D:/Projects/lan-reader`, never run anything against the user's NAS.

Context order: `implement.jsonl` entries → `prd.md` → `design.md` → this file.
Before writing code in a layer, load the matching `.trellis/spec/flutter/`
guide (the `trellis-before-dev` skill does this).

## Current checkpoint — stopped after Phase B

Phases 0, A and B passed and are committed locally (`4e15862`, `74932bb`, then
the Phase B commit). The user asked to stop after Phase B (2026-10-22).
Phase C starts only on the user's explicit instruction; continuous mode does
not resume by itself. Do not archive the task or restart earlier phases.

## Phase 0 — branch and baseline

- [x] Confirm `git status` shows only planning changes under `.trellis/tasks/`
  (this task directory, the parent `task.json` and `implement.md`), HEAD is
  `a570cfc` on `ios-build/s1-probe`, and `D:/Projects/lan-reader` is clean at
  `a4bda23`. If not, stop and report.
- [x] Create local branch `ios-build/s2-reader-probe` from HEAD.
- [x] Run the baseline gate (below); record exit codes in
  `local-validation.md` in this task directory.
- [x] Commit the S2 planning artifacts: `docs(task): plan S2 native reader feasibility`.

## Phase A — oracle tooling and fixtures (design §2)

- [x] Scaffold `tool/oracle/` with exact-version `package.json` and committed
  lockfile; add the `.gitignore` entries from design §10.
- [x] Vendor the reference files with provenance headers; implement
  `check-reference` against `a4bda23`.
- [x] Build the page bundle that reproduces the `foliateEngine.ts` load path
  and the inert projection; drive it with Playwright WebKit and Chromium.
- [x] Author fixture sources for every row of design §2.3 and the
  deterministic builder writing `assets/reader_fixtures/` + `manifest.json`.
  Register the assets in `pubspec.yaml`.
- [x] Generate committed vectors into `test/fixtures/reader/oracle/` and the
  Unicode range table source for Phase B. Write `tool/oracle/README.md`
  (commands, versions, what is committed and what stays local).
- [x] Run `vectors-local` on the four books in `D:/Projects/lan-reader/docs/`
  into `build/oracle-local/` (gitignored). Do not copy the books anywhere.
- **Gate A:** two clean `build-fixtures` + `vectors` runs are byte-identical;
  `check-reference` passes; WebKit/Chromium differences are listed in
  `research/oracle-notes.md` with the authoritative engine per case.
- [x] Commit: `feat(oracle): reference vector tooling and synthetic EPUB corpus`.

## Phase B — source model, CFI, canonical (design §3–§4)

- [x] Evaluate and add the ZIP/XML/HTML/CSS packages; record versions,
  licences and reasons in `prd.md` (dependency section) and the approved
  dependency table in `.trellis/spec/flutter/quality-guidelines.md`.
- [x] Implement `data/epub`, `data/source` (parser selection, inert
  projection), `data/cfi`, `data/canonical` with the generated Unicode table.
- [x] Golden tests over every committed vector; a local-only test (skipped
  when `build/oracle-local/` is absent) for the four books.
- [x] Interop loop: export native CFIs for sampled points, run
  `npm run resolve`, compare.
- **Gate B:** 100% agreement on all committed vectors and the local book
  vectors. A mismatch you cannot fix by matching reference behavior stops the
  run (report the vector, both outputs and your analysis).
- [x] Commit: `feat(reader): EPUB source model, CFI and canonical text v1`.
  Phase B was finished by Sonnet 5.5 implement agents in the Claude session
  after the Codex pause; the user then asked to stop here. Phase C starts only
  on the user's explicit instruction.

## Phase C — layout, page map, anchors, detection (design §5–§6)

- [ ] Style subset and cascade with reader overrides; block/inline model;
  paragraph building with source maps; line packing; page plans and map.
- [ ] Raster images, SVG wrapper fast path, vector SVG through the evaluated
  renderer (add dependency per Phase B rules) or surfaced-unsupported.
- [ ] Anchor export, resolution, proof and reflow restore.
- [ ] Unsupported-layout detection and its recoverable state.
- [ ] Tests: conservation check for every fixture at the three settings in
  design §5.6; per-page anchor round trip; oracle-CFI landing; injected proof
  failure keeps the previous anchor; style-matrix widget/golden tests where
  meaningful; detection tests. Run the conservation check locally on the four
  books (skipped when absent).
- [ ] Record host-side (Windows `flutter test`) layout timings for the long
  paragraph as indicative only.
- **Gate C:** all of the above pass; every style-matrix row has an outcome in
  a draft `feasibility-report.md`.
- [ ] Commit: `feat(reader): native layout, page map and position proof`.

## Phase D — motion controller and surfaces (design §7)

- [ ] Port gesture/engine functions and controller semantics; prepared
  surfaces with bounded lifetimes; reader widget with local motion state.
- [ ] Port the reference tests listed in `research/s2-entry-evidence.md` as
  Dart tests with injected clocks; add the callback-work guard test.
- **Gate D:** all ported and new tests pass.
- [ ] Commit: `feat(reader): page-turn controller and prepared surfaces`.

## Phase E — probe harness, analyzer, native spike, CI (design §8–§10)

- [ ] Probe home, reader feasibility screen, Documents EPUB listing, settings
  controls, scenario runner R01–R11, reader recorder and `reader_feasibility`
  export with clipboard summary. Keep S1 synthetic capture working unchanged.
- [ ] `tool/diag/analyze_reader_export.dart` with tests on committed synthetic
  exports.
- [ ] Swift presentation probe (inventory, A1, A2, B) behind the method
  channel; Dart client used only by the probe. Check hook points against the
  pinned engine sources named in `research/s2-entry-evidence.md`.
- [ ] Build script: two-variant packaging and the fixture/privacy guards;
  update the workflow only if needed. Run `bash -n` on the script.
  The "no `*.epub` outside `assets/reader_fixtures/`" guard must also accept
  `test/fixtures/reader/source_edge/edge-{html,xhtml}.epub` (Phase B edge
  fixtures) through a hashed manifest, not a blanket folder exemption.
- **Gate E:** full local gate passes; `flutter run -t lib/main.dart` behavior
  is unchanged (existing app tests green); analyzer tests pass; a scan of a
  generated export finds no fixture text.
- [ ] Commit: `feat(diagnostics): reader feasibility probe and presentation spike`.

## Phase F — handoff to the device step (then STOP)

- [ ] Write `device-runbook.md` in this task directory, modeled on S1's: build
  provenance check, which IPA to sign in 全能签 for which runs, copying the
  four books into Files → On My iPhone → Shiori, pre-capture declarations,
  per-scenario steps and repeat counts, A1/A2/B procedure, export retrieval,
  where to put exports locally (`local-evidence/`, gitignored) and how to run
  the analyzer.
- [ ] Update specs (Trellis step 3.3): add `.trellis/spec/flutter/reader-engine.md`
  for the source/CFI/canonical/layout/motion contracts; update
  `directory-structure.md` (engine layer, tool dirs), `quality-guidelines.md`
  (dependencies), `diagnostics.md` (reader record, native probe, evidence
  levels), `testing.md` (oracle vectors, local-only tests) and the spec index.
- [ ] Fill `feasibility-report.md` with every local row and placeholders
  marked "pending device run" for NC7–NC9.
- [ ] Consolidate the per-command evidence files in this task directory
  (`oracle-*.json`, `quality-gate-*.json`, `reader-dependency-install.json`)
  into one evidence folder or index, keeping their content.
- [ ] Copy the "Carry-forward to later stages" items below into the report.
- [ ] Commit: `docs(task): S2 device runbook, spec updates and local results`.
- [ ] STOP. Do not push. Reply with the report format in the handoff prompt.

## Carry-forward to later stages (from Phase A/B review)

- **S3:** `lib/features/reader/data/epub/epub_archive.dart` checks ZIP sizes
  declared in headers; `archive` inflates a whole entry before the length
  check, so a hostile EPUB can briefly allocate past the limit. Add bounded or
  streamed inflation and parse in a worker isolate before opening downloaded
  books.
- **S4:** `assets/reader_fixtures/` is registered in the shared `pubspec.yaml`,
  so product builds also carry ~1.2 MB of synthetic fixtures. Move them behind
  the diagnostic entry point (or out of product assets) before a product build.
- **S4:** known HTML-mode parser gaps (head-level `<template>`, `<noscript>`
  content that closes an open `<p>`, attribute URLs in script-enabled
  `<noscript>` raw text) are listed in `local-validation.md`; add fixtures if
  the NAS library contains such books.

## After the user confirms a push (outside Codex's continuous run)

1. Push `ios-build/s2-reader-probe`; CI builds both IPAs.
2. The user signs and installs the default IPA, places the books, runs
   R01–R11 (three repeats, limiters off) plus A1/A2, exports; then installs the
   `-cametal` IPA over it for Mode B and one R01/R02 comparison run.
3. Exports go to `local-evidence/`; the analyzer fills the NC7/NC8 rows; the
   report gets its GO / NO-GO; the task finishes through `trellis-finish-work`.

## Validation commands

```powershell
dart run build_runner build
dart format --set-exit-if-changed lib test tool/diag
flutter analyze
flutter test
```

Plus, from `tool/oracle/`: `npm ci`, `npm run check-reference`,
`npm run build-fixtures`, `npm run vectors`, and `git diff --exit-code` on the
committed vectors and assets afterwards. Use explicit timeouts on long
commands; if Windows console encoding garbles output (seen in S1 with GBK),
force UTF-8 rather than ignoring the result.

## Stop points (report, do not work around)

- The repository or lan-reader state differs from Phase 0 expectations.
- Any gate A–E fails and the fix would change reference semantics, accepted
  scope, the frame target, or would need lan-reader changes.
- A dependency cannot be added compatibly with the pinned Flutter/Dart and
  the existing version pins.
- A step would need a push, an account, a paid service, a Mac, or a device.
- An ordinary novel feature in the corpus cannot be represented without
  dropping content.
