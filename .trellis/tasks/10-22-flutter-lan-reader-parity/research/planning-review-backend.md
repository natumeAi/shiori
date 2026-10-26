# Research: backend review of parent planning artifacts

- Query: Review current PRD, design, execution plan and backend handoff against the backend contract audit.
- Scope: internal; read-only planning-document review, no further broad source exploration.
- Date: 2026-10-22 (UTC)

## Findings

**No blocking factual inconsistency found.** No required correction identified in the requested backend-review scope.

Files reviewed (paths relative to this task directory):

| File | Reviewed concern |
| --- | --- |
| prd.md | Backend reuse, progress guarantees, content-cache limits and ownership. |
| design.md | URL/HTTP handling, timestamps, caching and position/activity delivery. |
| implement.md | Validation order, real-data protection and separately owned backend work. |
| backend-handoff.md | Existing APIs and additive capability/content/CAS proposals. |
| research/backend-contract-audit.md | Existing-route/source evidence used as the review baseline. |

Confirmed consistency:

- Existing APIs and inherited file validators are reused; health/content identity remain recommended and position CAS conditional (backend-handoff.md:9,29,33,68,106).
- Source position timestamps remain raw UTC SQLite text and are not treated as device-local time or unique CAS tokens (design.md:91; backend-handoff.md:119).
- Position serialization and uncertain-write reconciliation do not claim protection from concurrent external writers; backward reading remains valid (design.md:202; prd.md:117; backend-handoff.md:112).
- File validators are not called byte identities; fallback validation, local byte digests and explicit refresh retain the known size/mtime limitation (design.md:114; prd.md:129; backend-handoff.md:70,102).
- Activity immutability, per-record/section outcomes and snapshot/statistics separation match the audited contract (design.md:210–223; implement.md:66).
- lan-reader remains user-owned and read-only for this task; any new requirement is handed off separately (prd.md:46,95; design.md:274; implement.md:70; backend-handoff.md:3).

## Deferred Risks — Not Planning Defects

- NAS version/proxy behavior is unverified; read-only compatibility checks and later disposable-data tests remain necessary (design.md:84; implement.md:87).
- Existing last-write-wins cannot prevent simultaneous-writer loss; the plan explicitly excludes the stronger guarantee pending separate review (prd.md:117; backend-handoff.md:108).
- Metadata-preserving EPUB replacement can defeat current validators. The content-digest proposal correctly requires detection beyond the same size/mtime shortcut (backend-handoff.md:88).
- A changed or incorrectly normalized section cannot automatically merge with prior server coverage. Exact normalization fixtures must pass before writing real history (implement.md:40,110).
- Position CAS and content-generation publication are proposed contracts, not implemented backend capabilities or verified NAS behavior.

## Related Specs and External References

- Existing audit cites the relevant Flutter data/error specs and lan-reader backend/statistics contracts.
- No additional external research was necessary; this review uses the pinned source evidence in research/backend-contract-audit.md.

## Caveats / Not Found

- Review is factual/documentary only; no tests, live NAS calls, product edits or deployment actions were performed.
- Only this review file was written.

