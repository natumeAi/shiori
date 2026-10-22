# Research: Reader planning review

- Query: Review final parent/bootstrap plans against native reader research.
- Scope: internal, read-only review; only this review artifact written.
- Date: 2026-10-22

## Findings

**Result: no blocking contradiction found in the reviewed scope.**

### Files reviewed

Paths are relative to `.trellis/tasks/10-22-flutter-lan-reader-parity/`.

- `prd.md` — accepted novel scope, cross-client correctness and full acceptance ownership.
- `design.md` — source/canonical/layout separation, native preparation and motion boundaries.
- `implement.md` — S1–S7 sequencing and interoperability-before-write gates.
- `research/performance-acceptance.md` — proposed thresholds and distinct evidence levels.
- `../10-22-ios-free-device-bootstrap/prd.md` — installation/export/retention acceptance.
- `../10-22-ios-free-device-bootstrap/design.md` — separate synthetic probe and bounded capture.
- `../10-22-ios-free-device-bootstrap/implement.md` — local/cloud/device checks and honest status.

### Confirmed contracts

- **Isolates:** `design.md:159` keeps transferable parsing/hash work in workers and Flutter layout on the root isolate; `:164` requires measuring indivisible costs. It does not promise background `TextPainter`/`Paragraph` layout.
- **Source/CFI:** `design.md:141` and `:166` preserve source nodes, namespaces, OPF paths, text chunks and UTF-16 offsets; restoration requires round-trip and foreground proof. Native page numbers cannot replace source anchors.
- **Statistics:** `design.md:210` separates canonical coordinates from CFI, requires normalization/FNV/length/interval equivalence before real writes, and preserves clock/completion/retry semantics. `implement.md:40` places these fixtures before real reading-history mutations.
- **Motion:** `design.md:180` separates controller/ticker work from parsing, layout, decode and persistence; `:190` gates acceptance on verified generation/target. It does not treat `RepaintBoundary` as a performance guarantee.
- **Novel scope:** `design.md:148` includes ordinary-style fixtures plus ruby, superscript/subscript and embedded fonts; `:155` requires fix/escalation instead of narrowing scope. `:173` preserves SVG anchors and requires non-wrapper static SVG rendering. The only accepted layout-class deferrals remain fixed/vertical/RTL.
- **Performance:** parent `prd.md:77` and `research/performance-acceptance.md:7` distinguish engineering timing/cadence from physical presentation. The proposed 99%/8.333 ms and submission-latency gates are not presented as measured results or sufficient scan-out proof.
- **Bootstrap:** child `design.md:54` labels synthetic motion explicitly; child `prd.md:48` and `:57` require observed export/feasibility results, with omissions and unknown evidence visible. Child `implement.md:27` prevents completion on CI success alone. No mandatory Mac, paid service, engine patch or high-speed camera is introduced.

### Carry into the detailed S2 plan (nonblocking cautions)

1. `design.md:162` mentions bounded long-paragraph windows. Source/glyph boundaries alone do not prove unchanged shaping or line context. Require window-boundary fixtures that detect lost/duplicated/reordered content and shaping changes; no arbitrary UTF-16 split. One layout call remains synchronous. The current feasibility/escalation gate already permits resolving this honestly.
2. `design.md:166` caches canonical intervals in the page map. Treat these as candidate geometry/source mappings, not reading observations. S4 must recheck accepted generation, foreground/clip visibility, idle delay and panel/image-viewer eligibility before crediting them, as required by `research/native-reader-contracts.md:73` and parent R6.
3. A truthful “presentation unverified” feasibility row can complete that reporting obligation; it cannot complete parent AC4. Keep installation/export success independent from final presentation acceptance. The current evidence-level wording supports this distinction.

### Related specs and references

- `.trellis/spec/flutter/state-management.md`, `widget-guidelines.md`, `testing.md`, `directory-structure.md`: ownership, local motion state, UI conventions and validation.
- `research/native-reader-contracts.md`: pinned source anchors and official Flutter/CFI/Apple documentation; no new external claims or package survey in this follow-up.

## Caveats / Not Found

- This review establishes planning consistency, not native reader feasibility, device installation or 120 FPS achievement.
- No product/task artifacts were edited; no benchmarks, tests, account actions or device runs were performed.
