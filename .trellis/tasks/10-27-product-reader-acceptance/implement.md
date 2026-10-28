# Execution: S4c

Status: planning, 2026-10-27; revised 2026-10-28 for the S4a post-A0
contract (`../10-27-native-fixed-layout-core/research/a0-measurement-review.md`).
Depends on S4a accepted rendering/session/early-device handoff and S4b accepted
proof/storage/delivery contracts. S4b's D5 parallel track does not change this
dependency. No activation is implied by creating this plan.

## Phase order and gates

| Phase | Work / ownership | Gate |
| --- | --- | --- |
| C0: integration baseline | Reconcile S4a/S4b APIs, current source/UI baseline, tokens and all seven retained conditions. Include S4a's per-row capability verdicts, recorded D3/D6 exceptions, cluster-granular SVG geometry, typed font-conversion failures and the A0b text route outcome. Pin paired iPhone comparison setup and schema ownership. | No missing dependency or unowned condition; no hidden scope change. Any S4a required row still open is listed, never treated as passed. |
| C1: product session | Typed reader route/controller, independent pin, loading/retry/restore, active intent and return context; later adjacent settings/intent migration only if needed. | Restart/exit/server switch/failed restore and stale result tests; B delivery gates preserved. |
| C2: controls/settings | Chrome, nested TOC/current item, native/source progress, exact settings/fonts/themes, debounce and anchor-preserving reflow. | UI09/UI10/UI13 widgets/goldens, panel blocking and fixed typography boundary. |
| C3: images/view/lifecycle | Image viewer and source hits, whole-page fit/pinch/pan/reset, pointer arbitration, rotation/reduced motion/OS eligibility and stable-view proof. | UI11/UI12/UI14 transform/gesture/lifecycle tests, no speculative writes or coverage. |
| C4: release hardening | Product/probe asset separation and packaged inventory; verify A-owned fonts/parser/coalescing/synchronization in integrated runtime. If A0b adopted HarfBuzz, also inventory its pinned native library and register its licence notice through `LicenseRegistry`. Confirm `tool/ci/check_ios_build_modes.sh` covers the static link and record the binary-size change. | Full host check, fixture-free product, correct layer/build identity, complete third-party notice inventory and complete device runbook. |
| C5: final iPhone acceptance | Paired UI02/UI09-UI14, web/native resume, local-priority/retry/time/completion, full fixed/mixed/reflow performance/resource/lifecycle and same-ID update. | C-AC1-C-AC8; seven-condition ledger with raw evidence and independent verdicts. Missing physical proof stays unverified; no full-target completion claim. |

## Required context and checks

Read injected bounded specs/research, then reader-engine.md and state-
management.md for C0/C1/C3; data-layer.md for persistence/delivery integration;
diagnostics.md and archived S2 feasibility-report NC9/S3 s4-handoff before C4/
C5. Large authoritative files are loaded per phase, not silently truncated.
Use parent research/ui-parity-plan.md as the UI ID authority.

Test typed route return/startup, intent clear/retain, storage migration,
settings sanitization/debounce/reflow, transforms and inverse hits, pointer
ownership, viewer/panel blocking, replacement and retirement. Include S4b
fake-delivery/local-priority fixtures and S4a resource/cancellation cases.
Goldens do not establish actual iPhone fonts or touch/lifecycle behavior.

After final code changes:

```powershell
dart run build_runner build
dart format --set-exit-if-changed lib test tool/reader tool/diag tool/ci
flutter analyze
flutter test
```

Include added integration/tool directories. Run existing shell syntax and
`bash tool/ci/check_ios_build_modes.sh` through Git Bash where appropriate,
plus oracle/analyzer/privacy checks for changed tools. Inspect actual app
asset manifest, not just pubspec configuration.

## C5 device runbook requirements

- Record actual build/engine/iOS and reference baseline, viewport/DPR/fonts/
  theme/cache/scenario, power/refresh declarations and observed vsync.
- Three repeats for cold/warm/rapid/reverse/held turns, chapters, long text,
  complex XHTML/SVG, images/spreads, fixed/reflow boundaries, zoom/pan,
  panels/viewer, delivery/network load and OS interruption.
- >=99% active UI and raster stages within 8.333 ms separately, admitted
  warm submission P95 <=16.7 ms, no unexplained >=50 ms stall, >=100
  alternating turns and bounded retained/peak/trend evidence.
- Preserve sample omissions, historical RSS failures and prospective rule
  changes; required long native captures need zero sample loss. Use the
  capture sizing S4a A4 delivers; a larger native ring cannot hide Dart loss.
- Compare fixed pages with S4a's per-channel geometry contract and D4 pixel
  rule. Before applying a D3 WebKit-defect exception to device evidence,
  reproduce the defect on the device's own Safari version; Playwright WebKit
  results do not transfer automatically.
- Complete a proven accepted turn after real OS background/return during
  motion and cold preparation. All 23 private regression sections/six fixed
  pages remain anonymous in tracked evidence.
- Separate correctness/UI, resource, engine budget, cadence, submission and
  physical-presentation verdicts. Missing mandatory evidence returns for
  review and cannot close the full target.
- Test same-identifier update with durable pending activity/settings/intent.
  Free existing Windows/cloud/iPhone flow; no unapproved push or charges.

## Dispatch, rollback and final handoff

Phase-scoped trellis-implement then trellis-check, with native injection and
mandatory fallback loads; main owns specs/plan revisions and reviewed commits.
Final check covers complete reader/core/library/CI/native scope. No product
or diagnostic build is performed during planning.

Risky boundaries: navigation/lease transfer, active-intent migration, competing
pointer owners, reflow/transform generation, asset-mode packaging and native
evidence. Revert code only with state/schema preservation; never clear
outbox/checkpoints to recover a build.

- [ ] Subsequent user review approves this child after dependencies pass.
- [ ] All manifests valid; UI ID and seven-condition mapping complete.
- [ ] C5 evidence and unresolved limits are reviewed without relabeling.
- [ ] Hand S5 verified active-reader/return/delivery-refresh ports; hand S7
      complete reader evidence. Whole-app parity remains outside this child.
