# Actual-visible coverage and reference occlusion exception

Date: 2026-10-27. Status: user-approved acceptance policy; fixture execution
and reference fix remain future work.

## Decision and evidence

The user chose native actual-visible text coverage and a documented known
difference from reference occlusion overcounting. Parent AC6 and S4b B-AC2 own
acceptance. On 2026-10-28 the user approved exactly one further coverage
exception (D6, S4b design). It covers edge characters that differ only because
the reference classifies WebKit's integer-snapped rectangles. No other
cross-client coverage exception exists.

Read-only source audit: D:/Projects/lan-reader/client/src/reader/visibleText.ts
checks computed visibility/opacity and clipping at the inspected :132/:201/
:235 boundaries, but does not establish arbitrary inter-element occlusion.
S4b research/position-activity-contracts.md records the precise limitation.
This plan does not claim a fixture was run or the deployed NAS/browser
version was verified. S4a/B0 pin source provenance and reproduce each claimed
difference before labeling a result with this exception.

## Required paired synthetic fixture

Create a generated fixed page with stable packaged-font body text and an
opaque positioned overlay covering selected characters. Include unobscured,
partially covered, fully covered, transformed and clipped control cases.
Record source node/UTF-16 ranges, canonical text/signature, geometry/paint
order, viewport/view transform and expected actual-visible intervals.

Run the same fixture through pinned reference and native samplers. Native
must report only proven visible characters. A demonstrated reference extra
interval caused by the overlay is an approved interval/character-total
difference; record both results and the corresponding reference source
issue. No reproduced difference means no exception is claimed for that case.
Missing native visible text, unrelated clipping bugs or invented source
coordinates remain failures. Masks/partial opacity need their own proven
visibility oracle and cannot be excused simply by naming this exception.

## Boundaries

- Canonical text, source order, FNV signature, normalization version and
  source-to-canonical coordinates remain identical. Hidden/covered text can
  remain part of canonical identity without being observed.
- Time, completion, duplicate delivery, immutable retry, date/hour/DST and
  unrelated coverage/totals retain exact compatibility.
- The backend continues accepting the existing interval schema. No API,
  database migration or server normalization change is required for this
  native correction. Existing reading history is not rewritten.
- A later browser fix is separately owned by the user; it does not block S4.
  Mixed-client aggregate history may already include browser overcounting,
  so native correctness cannot retroactively prove an exact clean total.

## Reference frontend follow-up

Recommended change in the read-only reference: make visibleText's observation
stage evaluate overlap/paint occlusion under the same source/generation/clip
contract, preserve canonical v1, and add the paired fixture to readingActivity
geometry/session tests. Avoid importing native screen coordinates into CFI or
changing completion/time logic. Validate that deduplicated server totals only
add newly observed intervals. The user implements/deploys this separately;
shiori does not modify D:/Projects/lan-reader.
