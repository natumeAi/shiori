# Execution: S4a

Status: in progress, activated on 2026-10-27 after the user approved starting
the previously presented S4 plan. Local implementation/checking is authorized;
build/push/device steps retain their existing workflow boundary.
Latest owner instruction: finish A0 implementation, self-tests and evidence,
then stop this run. Do not begin A1 or formal checking at that boundary.
A0 was delivered on 2026-10-27 with its gate not passed. This plan was revised
after the A0 measurement review (owner decisions D1-D4,
`research/a0-measurement-review.md`). On 2026-10-28 the owner instructed: after
A0 closure, start the remaining S4a phases (A0b, A1-A4) without per-phase
approval. Plan-defined review returns, third-party downloads, commits/pushes
and A5 device work still stop for the owner.
After a repair, rerun only the affected tests; do not repeat the full suite.
Dependencies: completed S2/S3, parent fixed/mixed scope and this child's
latest plan review. Next child S4b requires A5's report and accepted handoff.

## Phase order and gates

| Phase | Work / main files | Gate before continuing |
| --- | --- | --- |
| A0: oracle and feasibility | Pin reference/SDK baseline; generate capability fixtures in tool/oracle and tool/reader; probe fonts, SVG text/filter/mask and source geometry; repair diagnostics/admission/demand/native sampling. Delivered 2026-10-27; finish the closure items below. | Every required row has an oracle case and failure criterion; concrete source/layer/font admission policy; analyzer timelines expose omissions and stalls. Each row has its own verdict under the revised contract; rows owned by A0b may stay open. Infeasible required constructs return for review before broad renderer work. |
| A0b: text geometry route (D1) | One bounded HarfBuzz FFI probe under `tool/reader`, no production code; the owner sets its time box when starting it. Check pinned version, licence, Windows host test build and an iOS static packaging plan. Shape the pinned-font run `Ab fi é Z` once and keep the UTF-16-to-cluster map. Paint each cluster's outlines as Paths on straight and quadratic baselines, with startOffset, spacing, spacingAndGlyphs and an overhang crossing an advance boundary. Confirm the same glyphs and advances as Paragraph for that font. | Per-cluster start/end/rotation within 0.5 px of WebKit; every glyph painted exactly once; exact UTF-16 coverage; D4 pixels; glyph/outline/face resources accounted. A miss keeps the affected A2 text rows open and returns measured evidence for review (D2). |
| A1: metadata and units | Extend layout facts/capability routing, dimensions, reading-unit/slot identity, spread/center/blank composition and navigator. | Metadata and bidirectional mixed/TOC/nonlinear sequences conserve exact sources; malformed/vertical/RTL outcomes remain distinct. |
| A2: authored scene | Extend existing typed CSS; build fixed boxes/text/resources/ordered SVG scenes and source geometry. Curved/positioned SVG text and foreignObject inline text use the A0b route once it passes. | Entire required matrix passes under the per-channel geometry contract, the D4 pixel rule and the D3 exceptions only, with reflow/CFI/canonical vectors unchanged. Missing required features keep the phase open. |
| A3: lifetime and resources | Generalize surface/session ownership; independent file lease and shared worker reservation; 3+1 units with constituent accounting, font admission with WOFF/WOFF2-to-SFNT conversion, warm/prepare coalescing, optional-work suppression, parser hardening. | Cancellation/disposal/replacement/server-switch races retain no stale owners; preallocation/caps and source geometry remain complete; converted WOFF/WOFF2 fixtures actually shape. |
| A4: integrated probe and host review | Feed all layouts through actual motion/preparation and minimal probe. Add fixtures/analyzer and resource conservation checks; size capture volume for >=100-turn runs; review every affected layer. | Full host gate; anonymous all-section private regression result; a synthetic >=100-turn capture with zero Dart and native loss; early device runbook and evidence schema ready. |
| A5: early iPhone gate | Use approved free build/install flow; run complex/spread/mixed/reflow, cold/warm/rapid/reverse/held inputs, long turns and real interruption with repaired capture. | A-AC1-A-AC8 evidence, three repeats, >=100 turns, separate fidelity/resource/performance/presentation verdicts. Failed or missing required evidence returns for review before dependent activation. |

A0-A4 can execute locally after approval; A5 needs the existing user-authorized
push/build/sign/device workflow and the physical phone. Do not infer device
passes from host checks. No scheduled dates/effort promise is made while
native filter/text/font feasibility is unmeasured. Compile the A0 Swift/C
changes on hosted macOS CI at the next owner-approved push, before A5.

### A0 closure items

These are fixture/harness corrections. None changes the 0.5 px value or a
required row.

1. Make `dimensions-unsupported` exercise a real unsupported or conflicting
   dimension; it is now byte-identical to the positive case.
2. Make `cascade-unsupported` use an unknown declaration that actually applies;
   the current one sits inside a false `@supports` block.
3. Capture a reference PNG for every measured variant; nine boundary/nested
   cases fail pixels only because the reference is missing.
4. Compare text per the design channel table: per shaping cluster, and
   unsnapped advances in place of WebKit DOM Range boxes. Keep the old
   per-component and snapped-box numbers as diagnostics.
5. Implement the D4 edge rule in the harness report and keep raw differences.
6. Record the two WebKit defects (XHTML-SVG (0,0) pixel, foreignObject
   relative span) as D3 exceptions, citing their existing isolated controls,
   with a reference-fix handoff note.

A0 closes when every row has an executable oracle case, a failure criterion
and its own verdict. Curved/positioned SVG text rows may carry the verdict
"open, owned by A0b". The curved `spacingAndGlyphs` combining-sequence miss
(0.86 px) is recorded as open evidence for A0b, not reclassified.

### Parallel execution after A0

The owner requested parallel work wherever dependencies allow. The phase table
defines acceptance dependencies, not a requirement that every file be written
serially. A1 metadata/navigation and A3 resource/lifetime work do not depend
on text fidelity, so they need only A0 closure, not A0b. After A0 closes,
establish the minimal shared A1 contracts first: source-page identity,
reading-unit/slot shape, layout dimensions and navigation ports. Record these
contracts before assigning concurrent owners. A0b, remaining A1 work, A3
logic and A2 rows whose A0 verdict passed may then proceed in parallel with
disjoint files. A2 curved/positioned SVG text and foreignObject inline text
wait for A0b. Under the 2026-10-28 standing instruction these starts follow
automatically once their dependencies are met.
Production integration waits for the actual owning API; do not invent competing
versions or placeholders that appear to satisfy the gate. A4 test harnesses,
scenario definitions and device documentation may be prepared alongside them;
complete A4 integration and host acceptance wait for A1-A3 deliverables.

## Required context before code

Injected manifests contain bounded specs/research. Read authoritative long
specs on demand before their phase: reader-engine.md for A0-A4; data-layer.md
worker/resource/publication contracts for A1/A3; state-management.md reader/
preparation lifetime for A3; diagnostics.md for A0/A4/A5. All are under
.trellis/spec/flutter/. The archived S3 research/s4-handoff.md is mandatory
before integrating downloaded books. These loads are not optional because
they are absent from the automatic injection set.

Before resuming beyond A0, read `research/a0-measurement-review.md` first, then
`a0-implementation-report.md`, `a0-native-spikes.md`, `a0-resource-policy.md`
and `a0-text-geometry-options.md`. They distinguish completed experiments from
the still-open fidelity gate; do not treat passing harness tests as permission
to start broad rendering.

## Validation

- Reuse and extend existing metadata, worker/preload, source/CFI/canonical,
  anchor/motion/surface, parser and analyzer tests.
- Add generated fixed box/text/SVG/foreignObject/filter/mask/spread golden and
  conservation cases; fake clocks/generations for races; no real network.
- Test resource ownership and allocation refusal, not just configured
  constants. Include simultaneous warm/prepare and up to eight source pages.
- Private inputs use established ignored local-evidence paths; track counts
  only. Pin browser oracle provenance; do not claim an unverified commit.

For the broad phase baseline:

```powershell
dart run build_runner build
dart format --set-exit-if-changed lib test tool/reader tool/diag tool/ci
flutter analyze
flutter test
```

The owner's latest validation instruction takes precedence: after a repair,
run the affected regression tests only, not another full-suite run. Apply
formatting/analysis/code generation only where the change requires them.

Include any added integration/tool directories in format/analysis and run the
relevant existing oracle/analyzer/privacy/build-mode checks. Commands with
optional private inputs must not publish those inputs to CI.

## Dispatch, checkpoints and rollback

On 2026-10-27 the owner requested parallel implementation where dependencies
permit, and one formal trellis-check review after the whole S4a implementation
is finished. Use gpt-6.1-sol high implementers with explicit, disjoint file
ownership; use gpt-6-astra high for that final full-scope review. Implementers
still run their own phase tests and report evidence before crossing the
existing phase gates. The prepared review checklist is not a completed check.
Native context injection is preferred with explicit child-side loading if
absent. No implement/check agent recursively delegates the same role. Main
session owns dispatch, design/spec updates and later reviewed commits.

Risky seams: CSS cascade; page_plan/anchor/TurnPosition; surface pool and
session; worker queue lifetime; global fonts; native diagnostic synchronization.
Keep phase changes independently reviewable and preserve historical evidence.
Do not commit or push automatically during planning.

## Before activation / exit handoff

- [x] Subsequent user approval of the final S4a plan (2026-10-27).
- [x] Context manifests validated; existing planning byte-cap audit retained.
- [x] Parent/child requirements and source research agree; no scope decision open.
- [x] Post-A0 review decisions D1-D4 recorded (2026-10-27); plan revised.
- [ ] A0 closure items complete; per-row verdicts published.
- [ ] A0b verdict recorded (pass, or open with evidence for review).
- [ ] At exit, publish immutable unit/geometry/session contract, cap ledger,
      capability fixture matrix, early device report and remaining S2 ledger.
      The geometry contract is shaping-cluster granular.
- [ ] S4b/S4c plans refreshed if any contract changes materially; fresh review
      precedes their own start.
