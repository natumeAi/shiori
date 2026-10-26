# Planning readiness record

## Current scope revision: 2026-10-26

Status: parent scope/interaction revision recorded, detailed S4 child planning
pending. S1/S2 are archived; S3 remains planned and awaits renewed review.

- The user explicitly included both simple fixed image pages and complex
  static fixed layout plus whole-page fit/pinch/pan. PRD R11/AC10 were revised
  and AC11-AC12 added; vertical/RTL reading and scripted content were not added.
- PRD, design and implementation plan agree on per-section routing, authored
  geometry, mixed-book behavior, source/activity correctness and unchanged
  performance requirements. Research records primary specification/source
  evidence without including private book identity or content.
- S4a/S4b/S4c are proposed independent deliverables with explicit dependency
  and acceptance ownership. No new child has been created or activated.
- S3-R7/AC7 and its worker handoff preserve valid fixed/mixed sources without
  making a rendering-support claim. S3's revised plan awaits review; S4's
  page-viewing behavior does not expand S3 into a renderer.
- Q-FXL-1 is resolved by the user's explicit fit-page plus pinch/pan choice.
  The PRD has no remaining scope/interaction question from this expansion.
  Final S4 child review still requires its detailed capability/renderer/
  geometry/resource plan; the parent decision is not implementation approval.
- Parent context manifests have 9 implementation and 6 check entries,
  including the new fixed-layout research. To stay within the 131072-byte
  injection cap, historical `ios-device-workflow.md` and detailed
  `reader-fidelity.md`, plus the general cross-layer thinking guide, remain
  available for phase-specific loading instead of unconditional parent
  injection. Their requirements remain in the parent artifacts; the documents
  were not removed. S3 retains 8 and 7 entries.
- `task.py validate` passes for both tasks. Product code, global specs,
  dependencies, reference checkout and archived S2 evidence remain unchanged.
  Planning consistency checks are not a native fidelity/device test result.

## Historical planning review: 2026-10-22

Status at that time: final plan review pending; no implementation started.
The coverage and counts below describe that earlier review, not the current
expanded scope or task status.

- Parent PRD was rewritten through the required convergence pass and read
  top to bottom. It retains R1–R11, AC1–AC10, source anchors, accepted device,
  budget, reflow and first-release content decisions.
- Parent design, execution plan and backend handoff are present. UI01–UI14
  provide the complete UI/interaction evidence inventory.
- S1 child `10-22-ios-free-device-bootstrap` has its own PRD/design/execution
  plan and an explicit parent link. Both tasks remain `planning`; the session
  still targets the parent.
- Plan review revision (2026-10-22, user-approved scope): GitHub Actions on
  the already-public repository is the primary build host with Codemagic as
  fallback; the app identifier is fixed as `io.github.natumeai.shiori` before
  the first install; raw diagnostics are Documents files retrieved over USB
  with a bounded clipboard summary; refresh-limiting settings are declared per
  run and the vsync-interval distribution is reported; build number/build ID,
  `ios/` diff capture, diagnostics storage ownership and push confirmation are
  specified. S1 gained requirement B7, and every B1–B7 maps to an acceptance
  criterion.
- Parent context manifests have 9 implementation and 7 check entries;
  child manifests have 11 implementation and 7 check entries (testing and
  data-layer specs added to child implementation). All are real existing
  spec/research paths, without seed rows or duplicates.
- Estimated injected artifacts/context are below the configured 131072-byte
  total cap: parent implementation 96805, parent check 87326, child
  implementation 88653, child check 79304 bytes after the revision.
- Backend and native-reader research reviews found no blocking factual
  contradiction. Their nonblocking cautions are retained in the design and
  early feasibility/acceptance gates.
- Automated planning checks passed for files, JSONL syntax/paths, task
  linkage, requirement/acceptance/UI IDs and Markdown fence structure.
- Git status shows only the two new task directories. No product code,
  dependency installation, native build, device measurement, NAS mutation,
  deployment or code-test suite execution occurred in this planning phase.

Outstanding next action: present the final planning summary and wait for a
subsequent explicit user approval before activating S1. Technical feasibility
is deliberately tested in S1/S2; its uncertainty is not an implementation
result or a reason to silently relax the original performance goal.
