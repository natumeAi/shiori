# S2 resume handoff — paused during Phase B

> **Update 2026-10-22 ~17:40 (user instruction, supersedes step 8 below):**
> Phase B resumed in the Claude session using Sonnet 5.5 (medium effort)
> implement agents. Finish and commit Phase B only, then stop. Phase C starts
> only on the user's explicit instruction.
>
> **Update 2026-10-22 ~19:00:** Phase B finished, checked (trellis-check PASS)
> and committed as `feat(reader): EPUB source model, CFI and canonical text v1`.
> The sections below describe the earlier paused state and are historical.
> Next: Phase C, only when the user says so.

Recorded 2026-10-22, approximately 17:05 Asia/Hong_Kong (UTC+08:00).
The user explicitly requested a pause and will resume in a new chat. Do not
continue implementation until that request to resume arrives. This is not a
failed gate or a completed task. Trellis status remains `in_progress`; the
pause is recorded in task metadata and these notes.

## Repository checkpoint

- Workspace: `D:/Projects/shiori`.
- Local branch: `ios-build/s2-reader-probe`.
- HEAD: `74932bb7fae0c3eb85d961e048023207fa1bc851`.
- Phase 0 commit: `4e15862b5a92848efd34e442288ede5668079a2d`,
  `docs(task): plan S2 native reader feasibility`.
- Phase A commit: `74932bb7fae0c3eb85d961e048023207fa1bc851`,
  `feat(oracle): reference vector tooling and synthetic EPUB corpus`.
- Phase B is unfinished and uncommitted. Its rough effort estimate at pause
  was 25%; no Phase B test or gate result exists.
- Nothing was pushed; no remote branch, PR, workflow run, signing or device
  action was performed. The ordinary app entry point/routes and native iOS
  files have not changed.
- The parent task remains `planning`. Do not activate it or another task.

## Completed and verified

Phase 0 baseline and Phase A passed their checks. Final Phase A evidence:

- 13 synthetic EPUBs, 39 sections, 4,807 CFI samples per engine.
- WebKit 27.2 / Chromium 156.0.8078.4: zero observed differences, including
  the generated Unicode exclusion table.
- Four real books read in place: 60 sections, 168,677 samples per engine,
  zero observed differences. Private vectors remain in `build/oracle-local/`.
- Two clean UTC/Hong Kong runs: all 45 output/attribute files byte-identical.
- Four vendored reference payloads match the pinned source byte-for-byte.
- Native-export-style oracle CLI smoke test: 156 endpoint results matched.
  This was a tooling smoke test; actual native CFI interoperability is Phase B.
- Latest full gate: codegen zero outputs, formatting unchanged, analyze clean,
  all 91 existing Flutter tests pass.

See `local-validation.md`, `quality-gate-0.json`,
`quality-gate-A-source-lf.json`, `oracle-final-reproducibility.json`, and
`research/oracle-notes.md` for evidence and reference ambiguities.

Phase A's initial commit was amended after catching source EOL drift: Git
attributes alone did not normalize existing CRLF working files. All 86 tracked
oracle source files now have raw bytes equal to the committed blobs; mixed
Unicode newlines and font binaries are intentionally preserved. The
reproducibility script now checks raw versus Git-filtered source hashes.
Use the final HEAD above rather than the superseded Phase A commit `6304095`.

## Uncommitted Phase B state

Installed runtime packages, recorded in `reader-dependency-install.json`:

| Package | Resolved version | Licence |
| --- | --- | --- |
| archive | 4.5.2 | MIT |
| xml | 7.1.0 | MIT |
| html | 0.15.7 | MIT |
| csslib | 1.0.2 | BSD-3-Clause |

`pubspec.yaml` and `pubspec.lock` changed. Transitive `meta` moved from 1.18.3
to 1.19.0; `petitparser` 7.1.0 and `posix` 6.5.2 were added. Existing router
and build-runner pins remain. Phase B dependency justification in `prd.md`
and the approved dependency table in `quality-guidelines.md` is still pending.

Written source drafts (untracked):

- `lib/features/reader/data/source/source_attribute.dart`
- `lib/features/reader/data/source/source_node.dart`
- `lib/features/reader/data/source/source_document.dart`
- `lib/features/reader/data/source/source_position.dart`
- `lib/features/reader/data/source/source_parser.dart`
- `lib/features/reader/data/cfi/cfi_exception.dart`
- `lib/features/reader/data/cfi/cfi_step.dart`
- `lib/features/reader/data/cfi/cfi_expression.dart`
- `lib/features/reader/data/cfi/cfi_range.dart`

These are drafts, not verified implementations. They have not been formatted,
analyzed, compiled or tested. `cfi.dart` has NOT been written. No EPUB/package
or canonical implementation, Unicode Dart table, or Phase B tests exist yet.
Do not discard these files and do not commit them as a passed Phase B.

Detailed implementation knowledge is saved in:

- `research/source-resume.md`: source API, parser draft limitations,
  package/resource projection plan, canonical API proposal and dependencies.
- `research/cfi-resume.md`: agreed facade API, exact algorithm notes and
  vector test plan. Only four CFI model files are actually written.

All implementation agents stopped. Both implementers report no remaining
subprocesses or sessions. The checker attempted an early Phase B dependency
review but its turn failed because the selected model was at capacity; there
is no completed Phase B review. No canonical agent was started.

## Resume sequence

1. Load the Trellis start/continue context and this handoff. Inspect the actual
   branch, HEAD and dirty files; preserve all current drafts and pause records.
2. Current-task pointers are per session. An empty pointer in a new chat is
   expected, not a repository mismatch. Set only this task's pointer:

   ```powershell
   python ./.trellis/scripts/task.py start .trellis/tasks/10-22-native-reader-feasibility
   python ./.trellis/scripts/task.py current --source
   ```

3. Read every `implement.jsonl` entry, then `prd.md`, `design.md`,
   `implement.md`, entry evidence and the two resume research notes. Continue
   the existing Phase B; do not repeat Phase 0 or create another branch/task.
4. Dispatch implement/check agents under the configured Trellis auto mode;
   agree ownership before editing. Prior chat agent identities are historical,
   not resumable workers in a new chat. Canonical work has no assigned worker.
5. Repair/analyze the source and CFI model drafts, then finish the parser,
   package/resource graph, canonical index and CFI facade/resolver/exporter.
   Browser XML fallback and final protected reparse semantics govern; the
   Dart XML package is more permissive and needs a measured compatibility layer.
6. Run all synthetic and private local-book goldens plus native-to-oracle CFI
   interoperability. Private failure logs must report safe digests/coordinates,
   never copyrighted prose. Do not import golden vectors into production to
   manufacture matching source projections.
7. Complete dependency documentation, full timed quality gate and Trellis
   review before the prescribed Phase B commit:
   `feat(reader): EPUB source model, CFI and canonical text v1`.
8. After the user resumes, the original authorization is to continue phases
   B through F, committing per phase, stopping on a failed gate or after F.
   No new permission is needed for that already authorized local scope.

## Constraints that remain in force

`implement.md` is the authoritative ordered checklist. Preserve the original
handoff scope: no product entry/route changes, source Info.plist/bundle/signing
changes, workflow trigger/permission changes, master changes, parent/archive
artifact edits, or writes in `D:/Projects/lan-reader`. That reference was last
verified clean at `a4bda23fd3e82e285a22566d88576e67d3e8756b`.

No push/PR/remote workflow trigger without the user's explicit confirmation.
No NAS/library network access, accounts or paid services. Never copy, commit
or upload the four EPUBs or their prose. Private outputs stay in ignored
`build/oracle-local/` or `local-evidence/`. No WebView/JavaScript in the app,
content dropping, scope reduction or frame-target reduction to pass a gate.

SDK commands require access to the SDK cache/process environment outside the
sandbox here; the sandbox-only baseline stalled before Dart launched. Use
proper escalation for the same authorized command, explicit subprocess
timeouts and UTF-8 evidence, not another long stalled attempt. Do not kill
unrelated processes. No physical-iPhone presentation claim has been verified.
