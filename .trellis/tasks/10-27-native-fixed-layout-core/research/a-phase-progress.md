# A-phase progress

## A2

### Slice 1: authored XHTML scene foundation (2026-10-28)

Status: stopped during input audit, before implementation, under the slice's
explicit instruction to stop and report when the checkout differs from the
handoff description. No renderer, style, geometry, harness, oracle, fixture,
or other owner's files were changed.

The active task is in_progress and the ownership table agrees with the
handoff. However, the promised oracle inputs do not agree: all 16 cases of
cascade, box, paint and stacking lack text baseline records and computed-style
snapshots. Every text record has advance.prefixWidths; element boxes,
transforms, opacity, visibility and Range boxes are present. The only
computed-value field found is cascade-unsupported.appliedDeclaration.computedValue
(empty), which is unsupported-declaration evidence, not a style snapshot.
Snapped Range boxes cannot supply the missing unsnapped baseline channel.

Verified oracle SHA-256:
4eb18eb6aa389f648f0ee36b2b6ad740c1c985bd742a8f9154e6e3d7d8349917
(matches the A0 closure report).

Native row verdicts and largest gated deltas: cascade, box, paint and stacking
are unmeasured; no pass/fail or capability result is claimed. All twelve
positive/boundary/nested cases need their own reference PNGs; their pixel
gates remain unverified. Existing svg-text, filters, clip-mask and
foreign-object results were not changed or rerun.

Request to the main session / Part 1 oracle owner: supply the described
computed-style snapshots and independently measured text baselines for these
rows, with explicit unavailable/non-rendered records where applicable. Pin
regenerated corpus/oracle provenance before redispatching this slice. Reference
PNGs remain a separate known handoff and are not a prerequisite to implementing
geometry/sample checks once the input discrepancy is resolved.

Validation: get_context.py (default, phase, packages) exited 0. A Python audit
of all sixteen oracle cases and SHA-256 exited 0. Initial exploratory source
printing exited 1 on the shell's GBK Unicode encoding; the UTF-8 rerun exited 0.
An inventory command exited 1 because engine/fixed/ and this progress file did
not yet exist, both expected for this slice. No SDK analyze/test/format commands
ran because no Dart files changed. No sub-agents or git mutations were used.

### Slice 1 continuation: verification and handoff (2026-10-28)

Resumed the existing authored XHTML implementation after the lost session.
The input discrepancy in the earlier audit above is resolved by the published
A2 oracle extension. Verified all sixteen style/baseline/cluster records and
twelve positive/boundary/nested PNGs. Corpus SHA-256 remains
eb8379f5745d57a42c4bd2b10ed9587fee0260054af3a2747b799f8f6813af44;
oracle remains
33708a0fce1c0b7b523069b7e4e901923a53d4237bb51697de5a822cd1b857af.
No corpus/oracle generation or expected-data editing was performed.

This session changed 24 Dart files through formatting and brace lint fixes,
plus the specifically authorized corpus-test PNG coverage expectation:
engine/fixed/fixed_scene{,_coverage,_geometry,_layout,_paint}.dart;
data/geometry/{paint_geometry,source_fragment,source_geometry}.dart;
engine/style/{authored_style,css_authored_properties,css_properties,
css_style_resolver,css_stylesheet,css_values}.dart;
engine/layout/{paragraph_factory,inline_accumulator}.dart;
test/features/reader/engine/fixed/fixed_scene_test.dart;
test/features/reader/data/geometry/paint_geometry_test.dart;
test/features/reader/engine/style/authored_profile_test.dart;
test/features/reader/data/epub/fixed_layout_corpus_test.dart;
test/tool/reader/fixed_layout_scene_test.dart;
tool/reader/fixed_layout_scene_{harness,input,metrics}.dart.
Production paths above are relative to lib/features/reader. Other owners'
files and progress sections were not changed.

Item 4 is implemented for the admitted XHTML scene: source-order element
anchors/quads and complete UTF-16 Paragraph grapheme partitions, authored
transforms, independent paint ordinals, opacity groups, actual clip regions
and retained per-paint alpha footprints at an explicit one-CSS-pixel grid.
These are native candidate facts, not browser fidelity or accepted visibility.
Unknown masks/clip references/alpha evidence cannot attest CompleteGeometry.
Singular transforms and resource refusal produce explicit incomplete evidence.
Masks and SVG/foreignObject text remain outside this slice's completed scope.

Item 5 is implemented: the harness executes all sixteen authored cases,
checks CFI round trips and geometry, paints twelve PNGs, applies unchanged
0.5 CSS px/D4 gates and reports independent native row verdicts. Execution
success does not close the fidelity gate. Latest ignored artifact:
build/fixed-layout-native/scene-report.json (plus per-case native PNGs).

| Row | Verdict | Largest gated CSS px delta | D4 positive/boundary/nested |
| --- | --- | ---: | --- |
| cascade | fail | 18.59375 | fail / fail / fail |
| box | fail | 18.59375 | fail / fail / fail |
| paint | fail | 18.59375 | pass / pass / pass |
| stacking | fail | 0.146484375 | pass / pass / pass |

Only paint-boundary, stacking-positive and stacking-nested currently pass
all required channels. The 18.59375 px advance difference begins at the emoji
fallback run; cascade/box also disagree in baseline/layout and pixels. The
paint row retains those geometry failures even when clipping hides pixel
differences. Stacking-boundary has matching pixels and a 0.0712890625 px
geometry maximum, but its singular matrix produces MalformedSectionCapability
and IncompleteGeometry; it remains a failed required variant.
All four unsupported variants produce UnsupportedSectionCapability and
incomplete geometry: future-layout, display:grid, background-image and
transform respectively. No required case was relabeled unsupported.

Validation (direct dart.exe / flutter_tools.snapshot, no .bat or pub access):
- Per-file format over the 32-file A2 scope: exit 0; final pass changes none.
- Scoped dart analyze over those 32 files: exit 0, no issues. Initial analysis
  exited 0 with 49 brace lint infos, all corrected in owned files.
- Requested seven test paths, plus data/geometry and section_capability:
  exit 1; 435 passed, 2 skipped, one failure in paragraph_factory_test's
  '@font-face fonts load from the archive once and are used' alias assertion.
  Corpus, spike, scene and all remaining reflow tests passed.
- After intervening audit work, reran only that known A3 font assertion once:
  exit 1, same failure; the test and A3 implementation were not modified.
- Final style/fixed/data-geometry/scene-harness tests after brace cleanup:
  exit 0, 177 passed. Logs and the exact scope are under build/a2-slice1/.

Requests / next slice: A3 still owns the font alias test repair. Carry forward
requiredFonts: true and cancellation wiring into fixed preparation, and
descriptor-aware weight/style mapping, as explicitly out of this slice.
Native fallback/font metrics, contextual ligature endpoints, required singular
transform handling and remaining XHTML fidelity require further work. A0b's
required SVG text route remains open; no SVG adoption/device claim was made.
This closes the continuation's formatting, verification and reporting work,
not A2 fidelity acceptance. No sub-agents, new dependencies, network, build_runner,
repository-wide checks, commits or other git mutations were used. Stop here.

### Slice 2a: fixture correction and row verdicts (2026-10-28)

Completed the three authorized corrections and stopped at the slice boundary.
The corpus stays 13 x four / 52 cases. U+1F600 appears only in the existing
`text-boundary` case, recorded in fallbackCharacters as node 0, UTF-16 [0,2).
The isolated glyph has no decoration/background: native/WebKit paint 68/343
alpha-positive pixels, source/CFI mapping passes, and host conservation passes.
Its geometry/pixels explicitly remain device-gated (A5), pass=false; no host
fallback fidelity acceptance is claimed.

All 67 body text nodes and three SVG probe nodes now carry measured
clusterSource/clusterEvidence. WebKit straight SVG replicas retain computed
typography/writing mode and record per-UTF-16-boundary getSubStringLength
advances, normal versus font-variant-ligatures:none. Minimal substring
getComputedTextLength controls establish ligature spans and merge graphemes.
This is measured ligature membership, not an exported shaper glyph buffer.
`nested flow` fl [7,9) is detected: normal/disabled isolated advances
11.357421875/11.796875 px; run totals 103.095703125/103.53515625 px.
The existing SVG maps are unchanged. All 16 A0 oracle case records and three
SVG probes are byte/value identical after removing only provenance fields;
their original pixels, baselines and character metrics are preserved.

Singular transforms suppress all subtree paint and source/paint proof while
preserving flow layout and a complete section. Numeric-range failure remains
an error. Regression coverage checks descendants, no geometry/proof and exact
remaining sibling pixels. stacking-boundary now passes complete capability,
complete geometry and D4.

| Row | Verdict | Largest gated CSS px delta | D4 |
| --- | --- | ---: | --- |
| cascade | pass | 0 | all three pass |
| box | pass | 0.013671875 | all three pass |
| paint | pass | 0.01171875 | all three pass |
| stacking | pass | 0.146484375 | all three pass |
| filters | pass | N/A: spike has no geometry comparisons | all three pass, existing D3 |
| clip-mask | pass | N/A: spike has no geometry comparisons | all three pass, existing D3 |
| foreign-object | pass | 0.01171875 | all three pass, existing D3 |
| svg-text (A0 adapter) | fail | 1.7453875483049597 | upper P/B fail, N pass; path none pass, spacing/spacingAndGlyphs fail |

Two final generations are byte-identical. New SHA-256 pins:
- Corpus: 2b4881df40befcb77170223865f4c26c9a468c395e87cc5f7ff824c96d836d37.
- WebKit oracle: b6d2758414737f56712762501b13ab542a2e1ae11b22243ccdb5bb37514bdf8f.
- Chromium oracle: ea6e0e61cfee59249878794e213ce687120cd073f2c2e8029aa9935bfe479e73.
- Cross-engine differences: 960cdcc0803f1d6d48c9031d07aae2cb883952f75b41d54a3aa1e72e74875337.
- Paint controls: f1539007368afb52d6fb2fe5dcb1c316f722d39fadd7a5cd850ef49f0f3c7a55
  (unchanged inputs, retained rather than regenerated).

Owned changes: fixed_scene.dart and its layout/paint/geometry parts; its test;
scene harness/metrics and harness test; corpus test; oracle corpus/oracle
generators plus new fixed-layout-clusters.mjs; generated corpus/oracle/cross
engine differences; this A2 section and a0-closure-report's appended slice
section. No other owner's files, source/CFI/canonical v1 or reflow fixtures
were edited. The scene report separates rowFidelityGate=true from its overall
gate including A5 fallback=false. A0 SVG/native adaptation remains open.

Checks: both final generations, both generator --check commands, byte-identity
and provenance audit, fixture guard, final nine-file format (zero changed) and
analyze all exit 0. Requested affected tests exit 1: 423 passed, two optional
skips, one failure in A3's image_cache.dart:129 (ImageAdmissionException).
After a short audit interval, the single failing test was rerun once and still
exits 1; no A3 fix was made. Final corpus + reading_unit_composer/navigator +
scene harness run exits 0, 76 passed. A1 composition remains 48/52 exact,
49 materialized with its existing typed metadata rejection and centered reflow
differences; its files were not edited. Logs and validation-summary.json live
under build/a2-slice2a/; full pins/verdicts/commands are in a0-closure-report.md.

Request: A3 must reconcile pagination_test's expectation of exceeding the
two-image budget with the new intrinsic+output pre-decode admission contract.
Open: required SVG fidelity/A0b decision, A5 fallback/device proof and later
A2 integration; no overall A2/S4a acceptance. No dependencies, downloads,
external network, sub-agents, build_runner, broad format/full suite or git
mutations. No further slice started.

### Slice 2b: production preparation seam and text/dimensions/metadata verdicts (2026-10-28)

Published the retained fixed preparation seam for A3 and stopped at this slice.
The task remains in progress: text fidelity, one dimensions D4 case, general
SVG adoption, font selection integration and device evidence remain open.
Initial task/ownership audit and corpus/oracle hashes matched the dispatch.
No other owner's production/tests/progress section was edited. No sub-agents,
dependency/download, external network, full suite, build_runner, broad format,
git mutation or hand-edited expected data was used.

Production seam (engine/fixed/): FixedSourceLease, FixedImageRequest/Lease,
FixedPreparationPlan, FixedSceneAdmission, FixedSectionPreparer,
FixedPreparationOperation and PreparedFixedScene. Plan borrows immutable source
handles and exposes A1 dimensions/typed capability, all scene resource classes
and depths, 2 MiB per-real-source picture ceiling and inspected decoded bytes
before font/native allocation. The ceiling divides the existing 16 MiB owner
over eight possible real sources; actual picture bytes must reconcile within
it or preparation refuses. It is a policy ceiling, not an inferred native byte
cost per command or opaque allocator/RSS proof. A3 must reserve the full unit
through its existing shared scene/picture/image owners before prepare, including
intrinsic/transient decode bounds in the supplied image acquisition callback.

Prepare consumes source/admission once. It publishes only a complete capability
with CompleteGeometry; partial scene failures are destroyed. result cancels
promptly; drained keeps source/reservations until physical coverage/image/font
work settles and partial disposal finishes. Idempotent result disposal destroys
paint/Paragraphs/images, then releases resources/source and A3's constituent
reservation reference. The last constituent releases the SAME aggregate lease.
No work enters motion callbacks. Reflow SectionPreparer/PreparedSection APIs
remain unchanged; A3 adapts this fixed entry point into its session/pool.

Geometry placement: geometryForUnit composes the slot matrix into every source
fragment, region and alpha grid, namespaces clip/group registries and shifts
paint ordinals. The matching picture is drawn under the slot matrix once.
GeometryAlphaFootprint carries a grid-to-unit matrix and shares immutable alpha
bytes during placement; no resampling/copy or second slot multiplication.
Noninvertible placements are refused. FixedSvgViewport consumes A1's resolver
and retains nonzero viewBox origin, meet/slice/none and alignment in the scene.
The admitted SVG viewport/rect route conserves every child or refuses it;
general SVG text/filter/mask/foreignObject production adoption is still open.

Font wiring: fixed loadResources uses requiredFonts:true and captured
PublicationCancellation. RequiredFontException/process cancellation/resource
failures propagate. Parsed StyleFontFace supplies family/path/weight/style;
unsupported descriptor ranges/angles/values are diagnosed. ParagraphFonts now
sends ordered families, computed weight and style for base/every painted run,
and its cache distinguishes these descriptors. Multiple faces of one family
without A3's selector return typed descriptor-selection-required before loads.
The exact mapping and physical drain requests are documented only in the new
"A2 seam for A3" section of a1-contracts.md; font_mapping/registry were untouched.

Oracle: extended only text/dimensions observations with computed snapshots,
baseline records, per-source-boundary fractional baseline probes for text, and
positive/boundary/nested PNGs. Metadata stays capability/identity-only. The
original measured ligature/grapheme maps and all fallback characters remain
unchanged; fallback is only text-boundary. Two final runs are byte-identical
for WebKit, Chromium and cross-engine differences. Every non-text/dimensions
case and every SVG probe record compares exactly with pre-slice records,
including SVG measured values and PNGs. Corpus/source/CFI/canonical v1 and
existing reflow vectors were not changed. Paint controls were retained.

SHA-256:
- corpus: 2b4881df40befcb77170223865f4c26c9a468c395e87cc5f7ff824c96d836d37.
- WebKit: 4c017aa1fc1184f1b5f63a5d47f2d7027d17e1a4e0f28e4e1e64b942f1bfe5ca.
- Chromium: 89b12c0561a5b6c7499906e6e47f82cce5a63a4640e717b1abd8596d2d07c21a.
- cross-engine: 28333a0aaa135d7ba53ca2ecc51486b4501d3098691f89bac4cd4aa36bb38f9b.
- paint controls: f1539007368afb52d6fb2fe5dcb1c316f722d39fadd7a5cd850ef49f0f3c7a55.

Native verdicts, unchanged 0.5 CSS px and D4:
- text: FAIL, largest required gated delta 11.8212890625 px; positive/nested
  D4 fail. Comparisons cover computed typography, actual cluster-boundary
  baselines/advances, boxes/wrapping and paint. Unimplemented sub/super baseline
  shifting is explicitly UnsupportedSectionCapability plus incomplete geometry;
  it cannot publish a successful partial scene. The host fallback conservation
  remains passing, with text-boundary geometry/pixels device-gated (A5), false.
- dimensions: FAIL overall; positive/nested geometry is exactly 0 px. Nested D4
  passes. Positive has exactly one mismatched reference black-alpha-38 pixel
  at (0,0); it changes support/component counts. The existing RD-1 enumerated
  cases do not include dimensions, so no exemption/registry change was made.
  Boundary is typed malformed with no native allocation/guessed scene;
  unsupported percentages are typed unsupported. ViewBox/alignment/meet/slice/
  none and numeric/malformed cases also have direct production tests.
- metadata: PASS for raw/effective capability and stable source identity only;
  malformed/unsupported metadata remains typed, without a paint gate.
- Existing cascade/box/paint/stacking remain pass at maxima
  0 / 0.013671875 / 0.01171875 / 0.146484375 px, all their D4 variants pass.
  No A0b fidelity decision, failed-row waiver or overall A2 acceptance is claimed.

Validation: direct dart.exe and flutter_tools.snapshot, always --no-pub:
- Scoped final format (22 owned Dart files) and analyze: exit 0, no issues.
- Requested style/layout/pagination/fixed, test/tool/reader, corpus and data
  geometry tests: exit 0, 451 passed, two optional skips. This includes A1's
  reading_unit_* tests read-only and the existing reflow conservation/CFI corpus.
  The previously failing A3 image-cache test passed; no edit/retry was needed.
- After the final picture-ceiling/shared-owner regression, focused fixed/data
  geometry/font-descriptor/scene tests: exit 0, 36 passed (one additional test).
- A1 data/layout/reading_unit_test.dart, read-only: exit 0, seven passed;
  its three engine/pagination reading_unit_* tests passed in the affected run.
- Both oracle generation runs and corpus/oracle --check: exit 0; byte/source/
  protected-record audit and fixture/privacy guard: exit 0.
- Early focused runs passed (1, then 18 tests). Initial own analyzer issues
  (missing font exception import and brace/constructor lints) were repaired;
  final analysis is clean. No cross-owner failure required repair.
Logs, owned-file manifest and validation-summary.json: build/a2-slice2b/.
Native report/PNGs: build/fixed-layout-native/scene-report.json and case PNGs.

Requests/open issues:
- A3: implement/inject ResolvedFontFamilies Function(ParagraphFontRequest)
  selectFace, using its immutable families plus weight/style and the admitted
  StyleFontFace family/archivePath/weight/style list. Registry records/keys must
  distinguish same-family/same-path weight/style faces; never use final alias.
- A3: supply a physical drainFonts barrier for started/coalesced native loads;
  canceled registry waiter futures do not drain them. Inject shared scene/
  picture/image reservations and independent source/file/worker handles, and
  compose/namespace geometry once before generation-guarded publication.
- A2/main: sub/super baseline/line-box/decoration fidelity remains open. Review
  the reproduced dimensions-positive reference pixel against D3 authority before
  any scoped RD-1 extension; raw failed D4 is retained. General SVG/A0b adoption,
  WOFF2, fallback/A5/device and opaque native allocation peaks remain open.

Stopped after slice 2b; no task archive/commit or later slice started.

### A2 slice 2c: D7, rule-based D3 and sub/super (2026-10-28)

This slice is incomplete: text and svg-text fidelity remain failed. Implementation
stopped when the shared oracle changed outside A2's edits; no failed gate is
waived and the task is not complete. FixedSectionPreparer's public API is unchanged.

D7: only 8-connected component support now uses alpha >= 32. Every measured
pixel report records alphaThresholdInclusive=32; A0 and scene also record it
at the report root. Bounds still use alpha > 0; interior, edge neighbourhood,
pairing tolerance and samples are unchanged. Regression tests distinguish alpha
31/32 and retain failures for a missing faint 5x5 interior and distant support.

RD-1/RD-2: shared eligibility no longer reads the registry's case lists. XML
namespace/host, own PNG, native pixel and matching engine/control evidence
decide RD-1, restricted to (0,0). dimensions-positive qualifies (one pixel).
RD-2 identifies the relatively positioned Z inside foreignObject from source,
derives integer translation from source and verifies both independent control
boxes, actual reference/native glyph bounds and the native foreignStatic proof.
Its three A0 scopes remain 413 pixels; no other case qualifies. Every case has
eligible/evidence records, including explicit no-raster decisions. The registry
and reference controls were not edited. A0b consumes these helpers read-only;
all ten A0b source hashes and measured SVG input hashes remain identical.

Sub/super: ancestor shifts follow the horizontal reference UA rule (sub:
parent font-size/5 + 1; super: -(parent font-size/3 + 1), positive y downward).
The source text, ParagraphMap and original Paragraph grapheme geometry stay
intact. CSS 2.2 10.8 line boxes union shifted ascent/descent plus half-leading
and the block strut; following lines move by the resulting line height.
Paint groups reuse the full paragraph text and guard line ranges/widths;
geometry uses the corresponding per-source/per-line displacement. Nested
graphemes and wrapped sub/super have direct regressions. Temporary metric
Paragraphs and retained paint Paragraphs are reserved before allocation,
including duplicated text units, and disposed on success/failure/cancellation.
The planner reserves a conservative upper bound within the existing limits.
No length/percentage vertical-align occurs in this corpus, so those forms
were not added. Vertical/RTL remains typed unsupported.

Text positive/nested now have complete source geometry and admitted capability;
largest gated delta is 0.1650393009185791 px (before 11.8212890625).
The native content height is 68.6666667 versus WebKit 68.65625.
D4 still fails: native underline position/propagation connects glyphs (6/25
components); positive also has 21 outside-edge mismatches, nested zero.
Interior, support bounds and exact samples pass. A custom decoration candidate
was tested and rejected, then removed; its report is retained only as failed
experimental evidence in build/a2-slice2c/scene-decoration-candidate.json.
No baseline/font snap, per-case pixel correction or relaxed gate was retained.

All previously passing rows still pass. Previously passing *cases* do not all
retain their verdict: HarfBuzz positive/boundary/path-none and diagnostic nested
unhinted fragments regress solely on D7 components. spacingAndGlyphs improves
solely on D7. A0 nested-webkit-parent-length and path-none lose D4 only, retaining
their already-failed geometry/fidelity verdicts. The only other overall case
change is dimensions-positive F -> P through RD-1. No unrelated case verdict
changed. All non-component D4 channels are identical for every A0/A0b variant.
A0's sfnt/woff/woff2 font probe records are unchanged; none is relabelled.

Full per-case before/after table below (P/F are measured fidelity gates;
typed unsupported and N/A do not mean a rendered pass). Raw before/after
reports, case-audit.json, PNGs and logs are under build/a2-slice2c/.
Metadata and invalid dimensions have no raster gate; fallback stays A5-gated.

| Harness/group | Case | Verdict before/after | D4 before/after |
| --- | --- | --- | --- |
| a0/cases | clip-mask-positive | P -> P | P -> P |
| a0/cases | clip-mask-boundary | P -> P | P -> P |
| a0/cases | clip-mask-nested | P -> P | P -> P |
| a0/cases | clip-mask-unsupported | N/A -> N/A | N/A -> N/A |
| a0/cases | svg-text-positive | F -> F | F -> F |
| a0/cases | svg-text-positive-webkit-parent-length | F -> F | F -> F |
| a0/cases | svg-text-boundary | F -> F | F -> F |
| a0/cases | svg-text-boundary-webkit-parent-length | F -> F | F -> F |
| a0/cases | svg-text-nested | F -> F | F -> F |
| a0/cases | svg-text-nested-webkit-parent-length | F -> F | P -> F |
| a0/cases | svg-text-unsupported | N/A -> N/A | N/A -> N/A |
| a0/cases | foreign-object-positive | P -> P | P -> P |
| a0/cases | foreign-object-boundary | P -> P | P -> P |
| a0/cases | foreign-object-nested | P -> P | P -> P |
| a0/cases | foreign-object-unsupported | N/A -> N/A | N/A -> N/A |
| a0/cases | filters-positive | P -> P | P -> P |
| a0/cases | filters-boundary | P -> P | P -> P |
| a0/cases | filters-nested | P -> P | P -> P |
| a0/cases | filters-unsupported | N/A -> N/A | N/A -> N/A |
| a0/cases | svg-text-path-none | F -> F | P -> F |
| a0/cases | svg-text-path-spacing | F -> F | F -> F |
| a0/cases | svg-text-path-spacingAndGlyphs | F -> F | F -> F |
| a0/paintControls | foreignStatic | P -> P | P -> P |
| scene/cases | metadata-positive | P -> P | N/A -> N/A |
| scene/cases | metadata-boundary | P -> P | N/A -> N/A |
| scene/cases | metadata-nested | P -> P | N/A -> N/A |
| scene/cases | metadata-unsupported | typed unsupported -> typed unsupported | N/A -> N/A |
| scene/cases | dimensions-positive | F -> P | F -> P |
| scene/cases | dimensions-boundary | P -> P | N/A -> N/A |
| scene/cases | dimensions-nested | P -> P | P -> P |
| scene/cases | dimensions-unsupported | typed unsupported -> typed unsupported | N/A -> N/A |
| scene/cases | cascade-positive | P -> P | P -> P |
| scene/cases | cascade-boundary | P -> P | P -> P |
| scene/cases | cascade-nested | P -> P | P -> P |
| scene/cases | cascade-unsupported | typed unsupported -> typed unsupported | N/A -> N/A |
| scene/cases | box-positive | P -> P | P -> P |
| scene/cases | box-boundary | P -> P | P -> P |
| scene/cases | box-nested | P -> P | P -> P |
| scene/cases | box-unsupported | typed unsupported -> typed unsupported | N/A -> N/A |
| scene/cases | text-positive | F -> F | F -> F |
| scene/cases | text-nested | F -> F | F -> F |
| scene/cases | text-unsupported | typed unsupported -> typed unsupported | N/A -> N/A |
| scene/cases | paint-positive | P -> P | P -> P |
| scene/cases | paint-boundary | P -> P | P -> P |
| scene/cases | paint-nested | P -> P | P -> P |
| scene/cases | paint-unsupported | typed unsupported -> typed unsupported | N/A -> N/A |
| scene/cases | stacking-positive | P -> P | P -> P |
| scene/cases | stacking-boundary | P -> P | P -> P |
| scene/cases | stacking-nested | P -> P | P -> P |
| scene/cases | stacking-unsupported | typed unsupported -> typed unsupported | N/A -> N/A |
| scene/fallbackCases | text-boundary | F -> F | N/A -> N/A |
| hb/cases | svg-text-positive | P -> F | P -> F |
| hb/cases | svg-text-boundary | P -> F | P -> F |
| hb/cases | svg-text-nested | F -> F | F -> F |
| hb/cases | svg-text-path-none | P -> F | P -> F |
| hb/cases | svg-text-path-spacing | P -> P | P -> P |
| hb/cases | svg-text-path-spacingAndGlyphs | F -> P | F -> P |
| hb/featureComparisons | svg-text-positive-liga-off | F -> F | F -> F |
| hb/featureComparisons | svg-text-positive-component-metrics | P -> P | P -> P |
| hb/featureComparisons | svg-text-path-none-liga-on | P -> P | P -> P |
| hb/featureComparisons | svg-text-path-none-liga-off | F -> F | F -> F |
| hb/featureComparisons | svg-text-path-none-component-metrics | P -> P | P -> P |
| hb/featureComparisons | svg-text-path-spacing-liga-on | F -> F | F -> F |
| hb/featureComparisons | svg-text-path-spacing-liga-off | F -> F | F -> F |
| hb/featureComparisons | svg-text-path-spacing-component-metrics | F -> F | F -> F |
| hb/featureComparisons | svg-text-path-spacingAndGlyphs-liga-on | F -> F | F -> F |
| hb/featureComparisons | svg-text-path-spacingAndGlyphs-liga-off | F -> F | F -> F |
| hb/featureComparisons | svg-text-path-spacingAndGlyphs-component-metrics | F -> F | F -> F |
| hb/rasterComparisons | svg-text-positive-unhinted-fragments | P -> P | P -> P |
| hb/rasterComparisons | svg-text-boundary-unhinted-fragments | P -> P | P -> P |
| hb/rasterComparisons | svg-text-nested-unhinted-fragments | P -> F | P -> F |
| hb/rasterComparisons | svg-text-path-none-unhinted-fragments | P -> P | P -> P |
| hb/rasterComparisons | svg-text-path-spacing-unhinted-fragments | F -> F | F -> F |
| hb/rasterComparisons | svg-text-path-spacingAndGlyphs-unhinted-fragments | F -> F | F -> F |
| hb/outlineControl | overhang-straight-and-quadratic | F -> F | N/A -> N/A |

Validation: direct dart.exe only; all Flutter tests use flutter_tools.snapshot
with --no-pub. Scoped format --set-exit-if-changed (13 owned Dart files): exit 0,
zero changes. Scoped analyze on the same 13 files: exit 0, no issues.
Requested style/layout/pagination/fixed + test/tool/reader + corpus: exit 1,
444 passed, two optional skips, one corpus failure. This includes the reflow
pagination/conservation/anchors suites. Focused fixed_scene + scene harness:
exit 0, 10 passed. Focused spike + HarfBuzz: exit 0, eight passed.
The corpus-only retry: exit 1, 57 passed, same one failure.

The outside-owner font_mapping.dart missing StyleFontStyle import initially
blocked scene compilation; a short-wait retry still failed. Its owner later
fixed it, and all layout/fixed tests passed without an A2 edit to that file.
A later outside-owner oracle update added svg-graphics-positive PNG evidence
while fixed_layout_corpus_test.dart's paintRows still excludes svg-graphics.
The oracle SHA changed from 4c017aa1fc1184f1b5f63a5d47f2d7027d17e1a4e0f28e4e1e64b942f1bfe5ca
to 5070ee4aff579fde6baf42cb89767110de5d1fae25e044ffaf3f8a397037b3fb.
The corpus source SHA remains 2b4881df40befcb77170223865f4c26c9a468c395e87cc5f7ff824c96d836d37.
The corpus failure reproduces after waiting; neither oracle nor its test was
edited by this slice. This outside-scope change triggered the requested stop.

Requests/open: main/A0b review the newly exposed D7 component regressions before
any SVG adoption; A2 needs another decoration-fidelity investigation to close
text D4. The oracle owner must synchronize svg-graphics paint evidence and the
corpus contract test. Device fallback/A5, general SVG production adoption and
native opaque allocation peaks remain open. No dependency/download/network,
sub-agent, build_runner, broad format, full suite, commit or archive was used.
Stopped after this slice; no claim of A2/S4a acceptance.

### A2 segment 4 wrap-up (dsh)

Completed the owner-directed D8 and text-decoration work in three turns and
re-ran every native row. No fixture, oracle, expected-data or D3 scope changed.
Validation used the direct SDK commands under a one-shot full-access command
because the DSH workspace-write confinement denied all shell writes; no ACL
change was made.

Turns 1-3 changed: tool/reader/fixed_layout_spike.dart,
fixed_layout_spike_scene.dart, fixed_layout_spike_pixels.dart,
fixed_layout_scene_harness.dart, fixed_layout_scene_metrics.dart,
harfbuzz_probe.dart and the three test/tool/reader harness tests;
lib/features/reader/engine/layout/paragraph_factory.dart;
lib/features/reader/engine/fixed/fixed_scene_inline.dart,
fixed_scene_layout.dart, fixed_scene_paint.dart and
fixed_section_preparer.dart. This section and
build/a2-segment4b/before-after.md are the only turn-3 writes.

D8 mask: text pixels are the union of native text-paint alpha > 0 and oracle
text geometry (SVG per-character extents or XHTML Range boxes), each dilated or
expanded by 1 px and applied identically to both images. Only the alpha >= 32
component sub-rule is suppressed; interior, edge, support-bound, sample and all
D3 rules still cover text. Each pixel result records mask provenance and the
excluded topology-pixel count for native and reference. Non-text components
stay at the D7 alpha >= 32 rule. Text presence is gated by cluster/grapheme
conservation: every shaped SVG cluster or XHTML grapheme is painted exactly
once with exact source mapping.

Decoration rule: fixed text uses the pinned Roboto SFNT post metrics
(underlinePosition -150, underlineThickness 100, upem 2048; at 20 px offset
1.46484375 px, thickness 0.9765625 px) and OS/2 strikeout metrics. WebKit's
observed device-pixel snap is top = round(baseline + offset), rows =
ceil(top + thickness) - floor(top), minimum one. One band is drawn per line
from floor(text-box edges), excluding the indent placeholder and the
letter-spacing gap before a space; a subscript skip-ink gap is derived from its
paragraph box and the next run. Vertical sub/sup shifts never move the band.
Reflow keeps the engine decoration unchanged through the default
paintDecorations/decorationMetrics parameters; fixed WOFF/WOFF2 faces fall back
to engine decoration until their metrics are decoded.

Final row verdicts: A0 filters, clip-mask and foreign-object pass; A0
Paragraph-slice svg-text is F but is superseded by the D1 HarfBuzz route
(evidence only, not the row verdict). Scene cascade, box, paint, stacking,
dimensions and metadata pass; scene text is device-gated (A5) with host gate
true. HarfBuzz svg-text is device-gated (A5) on the adopted unhinted route.
Scene text-positive and text-nested now pass all host D4 sub-rules at a largest
gated geometry delta of 0.1650393009185791 px; HarfBuzz cases are at or below
0.000484398 px. The before/after report records 13 changed cases and zero
regressions; no previously passing row or case flipped to fail.

Final validation: all three native harness tests passed. The affected
style/layout/pagination/fixed scope plus those three harnesses passed 388 tests
with two skips when the two concurrently edited A2-svg tests
(`test/tool/reader/fixed_layout_svg_test.dart` and
`test/features/reader/engine/fixed/svg/svg_graphics_test.dart`) were excluded.
The full required command exited 1 only because
`lib/features/reader/engine/fixed/svg/svg_graphics_markers.dart` was mid-edit
with `SvgPathSegType` undefined; that file is outside this turn's scope and
was not modified. A short-wait rerun still failed to compile.

Open: WOFF/WOFF2 fixed decoration metrics fallback; the subscript skip-ink and
space-gap approximation must be rechecked in A5 on the iPhone; A0
Paragraph-slice svg-text stays evidence only. DSH shell writes remain confined
(ACL probe refused at D:\Projects\shiori\tool; no ACL edits). No commits,
downloads, fixture regeneration or broad formatting were used.

### A2 segment 5i (2026-10-29)

Connected the production SVG module to `FixedSectionPreparer` and removed the
rect-only SVG route. No fixture, oracle, generator, shared-helper, gate or
expected-data change.

Changed: `fixed_preparation_plan.dart`, `fixed_scene.dart`,
`fixed_scene_svg.dart`, `fixed_scene_geometry.dart`,
`fixed_scene_paint.dart`, `fixed_section_preparer.dart`; the SVG seam
`svg_graphics_prepare.dart`; `tool/reader/fixed_layout_scene_harness.dart`,
`fixed_layout_scene_metrics.dart`, `fixed_layout_svg_harness.dart`;
`test/features/reader/engine/fixed/fixed_section_preparer_test.dart`,
`test/tool/reader/fixed_layout_svg_test.dart`, and a color-normalization
expectation in `test/features/reader/engine/fixed/svg/svg_graphics_test.dart`.
This section is the only documentation write.

Hook: `FixedPreparationPlan.inspect` finds top-level inline SVG roots and calls
`SvgGraphicsPlan.inspect` before any font/native allocation. Typed
`AuthoredStyle` values are projected into the presentation map: `color` for
every SVG node, and non-root `opacity`/`visibility`/`display`; `fill`/`stroke`
remain authored attributes. A CSS declaration outside that typed projection on
an SVG page (`filter`, `mask`, `clip-path`, `fill`, `stroke`, ...) makes the
whole plan unsupported with an `svg-<property>` construct, before fonts. The
`svg-graphics` filter case therefore remains `UnsupportedSectionCapability`
with `svg-filter`, no picture and no fragments. SVG plans are stored on
`FixedPreparationPlan` and passed to the builder by root index.

`_layoutSvg` keeps the `FixedSvgViewport`/dimension gate, sets only the flow
translation (the plan applies its own root viewBox/preserveAspectRatio), and
stores the plan on the box. After `_transforms`, `_prepareSvgScenes` awaits
`plan.prepare(..., preReserved: true, placement: box.transform + flow)`, merges
the scene's elements/geometry, and draws the scene picture with unit-space clips,
never `box.transform` twice. The builder/caller owns every
`SvgGraphicsScene` and disposes it exactly once; the fixed-scene catch and
`FixedScene.dispose` both use the same idempotent path.

Resource path: `FixedPreparationPlan.resources` now includes the SVG base
(`vectorBytes`, `vectorOperations`, `references`, `gradientStops`,
`layerPixels`, `layerBytes`) and the source/depth maxima. The external
whole-unit reservation therefore covers it. `SvgGraphicsPreparation.prepare`
gained `preReserved` (skip only the base reserve; pattern/dash sub-leases still
draw from the local ledger) and an optional `placement` overlay. The local
ledger is limited by the plan; a test proves `sourceNodes` peak equals the
document node count, not node count plus SVG node count, and that the ledger
returns to zero on success, refusal, failure and cancellation. Pattern/dash
headroom is bounded by the provisional reference/operation ceilings plus the
dash command bytes; this is conservative and is listed open.

End-to-end proof is in the SVG harness, which runs each fixture through
`FixedSectionPreparer` with the same corpus, oracle, D3 scope and D4 comparator.
It compares capability/constructs, every `SvgGraphicsElement` transform/bounds
and the source-fragment count with the dedicated path, and compares D4
sub-rule pass flags. `fixedPass` is true for all four cases.

Before/after table (unchanged rows are listed once; no case gate flipped):

| Case/row | Before | After |
| --- | --- | --- |
| scene cascade/box/paint/stacking | PASS | PASS |
| scene text | device-gated (A5), host true | same |
| scene dimensions | PASS | PASS; SVG root/rect now measured from the module, box max 0 px |
| scene metadata | PASS | PASS |
| svg-graphics-positive | PASS | PASS; fixed path prepared, elements 17, D4 parity |
| svg-graphics-boundary | FAIL samples (10,10) delta 1 | same; fixed path prepared, D4 parity |
| svg-graphics-nested | PASS | PASS; fixed path prepared, elements 19, D4 parity |
| svg-graphics-unsupported | typed `svg-filter` | same; fixed path refused before fonts, no picture |

The scene harness reports the same seven row verdicts and no changed case gate.
The SVG harness dedicated results are unchanged; the new fixed path adds
`fixed: prepared/refused` with `parityPass: true` for all four cases.

Validation (direct SDK; DSH workspace-write still denies shell writes, so
write-bearing commands used one-shot full access; no ACL change):
- `dart test` on the affected set (`test/features/reader/engine/fixed/
  fixed_scene_test.dart`, `fixed_section_preparer_test.dart`, the existing
  `svg/svg_graphics_test.dart`, `test/tool/reader/fixed_layout_scene_test.dart`,
  `fixed_layout_svg_test.dart`, `harfbuzz_probe_test.dart`,
  `test/features/reader/engine/surface`,
  `test/features/reader/data/epub/fixed_layout_corpus_test.dart`
  `--no-pub --reporter compact`): exit 0, 171 passed.
- Full `test/features/reader/engine/fixed test/tool/reader
  test/features/reader/engine/surface
  test/features/reader/data/epub/fixed_layout_corpus_test.dart`: exit 1 at the
  time of this run, 182 passed, 6 failed. The five failures were in the
  concurrently added, untracked
  `test/features/reader/engine/fixed/svg/svg_graphics_semantics_test.dart`
  (CSS transform, CSS clip-path refusal, currentColor gradient, pattern stroke,
  zero-length dash caps) and one in the other owner's untracked
  `test/tool/reader/fixed_layout_mixed_test.dart`
  (`composed-unsupported` vs `unsupported`). A later rerun after the concurrent
  module/owner edits showed the mixed test passing and two reviewer semantics
  cases (CSS transform, currentColor) still failing. Neither file is mine; the
  failed cases are module/mixed-harness work outside this hook.
- `dart format --output=none --set-exit-if-changed` on the 13 changed Dart
  files: exit 0. `dart analyze` on the same files: exit 0.
- Scene and SVG harness reports were regenerated by the affected run; both
  harness tests pass.

Requests: A3's fixed source loader must include local SVG `<image>` targets in
`FixedSourceLease.images` as admitted raster leases (the harness supplies a
320x240 `/tile.svg` lease); otherwise the module correctly refuses the missing
image. If A3 wants exact rather than ceiling-based pattern/dash reservations,
the plan can expose the computed tile/dash counts in a later turn.

Open: CSS transform is projected from typed `AuthoredStyle` for non-root SVG
nodes, but the module's own `SvgPresentation`/tree still fails the reviewer's
CSS-transform and currentColor cases; those are module repair work for the
separate turn. CSS filter/mask/clip-path and other unsupported SVG presentation
declarations refuse the whole section. Pattern/dash headroom uses the
provisional ceilings. SVG scene picture bytes remain covered by `vectorBytes`,
not by `FixedSceneAdmission.pictureBytes` reconciliation. A5 device raster
parity remains open; the mixed harness belongs to its owner. No commit, push,
stash or ACL change was made.

### A2 D9/D10 implementation (2026-10-29)

Implemented owner decisions D9 and D10 in the shared D4 helper and in the SVG
dedicated/fixed callers, and closed the SVG geometry review finding. A
concurrent SVG-module owner was editing `engine/fixed/svg/` during this turn
(feature hooks, markers, filters, clip/mask, foreignObject, text); those edits
are consumed unchanged and are not claimed here. No fixture, oracle, generator,
D3 registry, production paint behavior, mixed harness or other owner section
was edited.

Changed files: `tool/reader/fixed_layout_spike_pixels.dart`,
`fixed_layout_svg_harness.dart`, `fixed_layout_scene_harness.dart`,
`fixed_layout_spike.dart`, `harfbuzz_probe.dart`,
`lib/features/reader/engine/fixed/svg/svg_graphics.dart` and
`svg_graphics_prepare.dart`, and the two `test/tool/reader` harness tests. The
only engine accessors are read-only evidence fields on `SvgGraphicsElement`:
`fillPath` (local fill geometry) and `clipIds`. They record what was already
painted; they do not alter rendering, ordering or allocation.

Helper API. `SpikeSampleRecord(x, y, maximumChannelDelta, classification,
provenance)` with `SpikeSamplePaintClass.solid|gradient`, plus
`classifySpikeSamplePaint(nativeIsGradient:, referenceIsGradient:)`.
`compareSpikePixels` accepts `samples:`; pass requires every solid delta == 0
and every gradient delta <= `d9GradientSampleMaximumDelta` (1). The report
carries each sample's x/y, delta, class, provenance and pass, per-class counts
and per-class maximum delta. The old `maximumSampleDelta` argument remains the
all-solid exact path, so unchanged callers keep exact behavior.

D9 classification method. SVG samples are tested at the pixel centre
`(x + .5, y + .5)`. Native elements are walked in descending paint ordinal; the
page point is inverse-transformed into local space; clip ids must cover it.
Fill coverage uses the local fill path and fill rule; stroke coverage uses the
path metric distance at half the resolved stroke width. The topmost covering
paint role (fill or stroke) maps by `nodeIndex` to the oracle
`graphics.elements[]` entry. Both the native paint value and the reference
`computedPaint` for that role must resolve to a `linearGradient` or
`radialGradient` `url(...)` in the source document. Anything missing,
duplicated or ambiguous is classified solid and stays exact. Classification
never reads pixel values. `(10,10)` is gradient in positive and boundary and
solid in nested; the boundary sample has delta 1 and now passes.

D10. `d10ChangedPixelMinimumDelta = 2`: a pixel changes when its maximum
straight-RGBA channel delta is >= 2. The same constant now drives changed
counts, interior, edge-band, and neighbourhood flatness. Each case reports
`deltaOnePixels`; every report root records `d10ChangedPixelMinimumDelta`
(SVG, scene, A0 and HarfBuzz). The only prior sub-threshold skips that remain
are delta 0 and 1.

SVG geometry review. Acceptance now compares four independent channels rather
than accepting the completeness flag plus elements/pixels: (1) every native
element has exactly one fragment with the same node and paint ordinal and vice
versa; (2) every required non-definition element is present exactly once; (3)
every `use`-rooted instance chain is derived from the source tree and mapped to
exactly one element/fragment per chain, with no extra use-rooted chains (marker
instances remain the marker feature's evidence); (4) top-level native paint
ordinals and per-chain instance ordinals increase in the oracle paint order.
The negative test drops the referenced-instance fragment (coverage fails) and
swaps the top-level native paint ordinals (paint order fails). The synthetic
case also proves a good row passes all four channels.

Before/after (only sample result and overall case verdict; `n/a` means no
raster for that case). Baselines are the pre-change reports saved under
`build/a2-d9d10/before`; the after reports are under `build/a2-d9d10/after`.

| Case | Sample before | Sample after | Verdict before -> after |
| --- | --- | --- | --- |
| svg-graphics-positive | pass / 0 | pass / 0 (gradient) | P -> P |
| svg-graphics-boundary | fail / 1 | pass / 1 (gradient) | F -> P |
| svg-graphics-nested | pass / 0 | pass / 0 (solid) | P -> P |
| svg-graphics-unsupported | n/a | n/a | P -> P |
| scene metadata-positive | n/a | n/a | P -> P |
| scene metadata-boundary | n/a | n/a | P -> P |
| scene metadata-nested | n/a | n/a | P -> P |
| scene metadata-unsupported | n/a | n/a | typed unsupported -> typed unsupported |
| scene dimensions-positive | pass / 0 | pass / 0 | P -> P |
| scene dimensions-boundary | n/a | n/a | P -> P |
| scene dimensions-nested | pass / 0 | pass / 0 | P -> P |
| scene dimensions-unsupported | n/a | n/a | typed unsupported -> typed unsupported |
| scene cascade-positive | pass / 0 | pass / 0 | P -> P |
| scene cascade-boundary | pass / 0 | pass / 0 | P -> P |
| scene cascade-nested | pass / 0 | pass / 0 | P -> P |
| scene cascade-unsupported | n/a | n/a | typed unsupported -> typed unsupported |
| scene box-positive | pass / 0 | pass / 0 | P -> P |
| scene box-boundary | pass / 0 | pass / 0 | P -> P |
| scene box-nested | pass / 0 | pass / 0 | P -> P |
| scene box-unsupported | n/a | n/a | typed unsupported -> typed unsupported |
| scene text-positive | pass / 0 | pass / 0 | P -> P |
| scene text-nested | pass / 0 | pass / 0 | P -> P |
| scene text-unsupported | n/a | n/a | typed unsupported -> typed unsupported |
| scene paint-positive | pass / 0 | pass / 0 | P -> P |
| scene paint-boundary | pass / 0 | pass / 0 | P -> P |
| scene paint-nested | pass / 0 | pass / 0 | P -> P |
| scene paint-unsupported | n/a | n/a | typed unsupported -> typed unsupported |
| scene stacking-positive | pass / 0 | pass / 0 | P -> P |
| scene stacking-boundary | pass / 0 | pass / 0 | P -> P |
| scene stacking-nested | pass / 0 | pass / 0 | P -> P |
| scene stacking-unsupported | n/a | n/a | typed unsupported -> typed unsupported |
| scene fallback text-boundary | n/a | n/a | device-gated -> device-gated |
| A0 clip-mask-positive | pass / 0 | pass / 0 | P -> P |
| A0 clip-mask-boundary | pass / 0 | pass / 0 | P -> P |
| A0 clip-mask-nested | pass / 0 | pass / 0 | P -> P |
| A0 clip-mask-unsupported | n/a | n/a | outside-spike-profile -> outside-spike-profile |
| A0 svg-text-positive | pass / 0 | pass / 0 | F -> F |
| A0 svg-text-positive-webkit-parent-length | pass / 0 | pass / 0 | F -> F |
| A0 svg-text-boundary | pass / 0 | pass / 0 | F -> F |
| A0 svg-text-boundary-webkit-parent-length | pass / 0 | pass / 0 | F -> F |
| A0 svg-text-nested | pass / 0 | pass / 0 | F -> F |
| A0 svg-text-nested-webkit-parent-length | pass / 0 | pass / 0 | F -> F |
| A0 svg-text-unsupported | n/a | n/a | outside-spike-profile -> outside-spike-profile |
| A0 foreign-object-positive | pass / 0 | pass / 0 | P -> P |
| A0 foreign-object-boundary | pass / 0 | pass / 0 | P -> P |
| A0 foreign-object-nested | pass / 0 | pass / 0 | P -> P |
| A0 foreign-object-unsupported | n/a | n/a | outside-spike-profile -> outside-spike-profile |
| A0 filters-positive | pass / 0 | pass / 0 | P -> P |
| A0 filters-boundary | pass / 0 | pass / 0 | P -> P |
| A0 filters-nested | pass / 0 | pass / 0 | P -> P |
| A0 filters-unsupported | n/a | n/a | outside-spike-profile -> outside-spike-profile |
| A0 svg-text-path-none | pass / 0 | pass / 0 | F -> F |
| A0 svg-text-path-spacing | pass / 0 | pass / 0 | F -> F |
| A0 svg-text-path-spacingAndGlyphs | pass / 0 | pass / 0 | F -> F |
| A0 paint-control foreignStatic | pass / 0 | pass / 0 | P -> P |

No scene-harness or A0-spike sample lands on a gradient. The non-SVG cases
whose sources mention gradients are clip-mask/filters controls (all sampled
fills are solid) and `paint-unsupported` (typed unsupported, no raster); the
A0 and scene harnesses therefore remain on the legacy all-solid exact path.

Other measured changes. D10 now counts delta-2 pixels in every harness, which
the main-session prediction expected not to occur. None flips a verdict.
Observed changed-count increases are scene box-positive +1, paint-positive +4,
paint-nested +11, stacking-nested +18; A0 clip-mask-positive +3,
clip-mask-nested +1, svg-text-positive +1, svg-text-positive-webkit-parent-length
+3, svg-text-boundary +1, svg-text-boundary-webkit-parent-length +3,
svg-text-nested-webkit-parent-length +4, svg-text-path-none +3,
svg-text-path-spacing +3, svg-text-path-spacingAndGlyphs +1; HarfBuzz raster
comparisons have delta-2 counts up to 29 (for example the positive and boundary
cases have 24), so their changed counts rise but all 23 comparisons still pass.
SVG positive/boundary changed counts rose +44/+45 from delta-2 dithering; the
larger SVG-nested increase is from the concurrent marker/feature support, not
from D9/D10. The only verdict change anywhere is svg-graphics-boundary F -> P,
caused by D9's gradient sample (delta 1) and confirmed by the fixed-route D4
parity.

Validation (direct SDK, `--no-pub`, expanded reporter):
- `test/tool/reader/fixed_layout_svg_test.dart`: exit 0, 2 passed.
- `test/tool/reader/fixed_layout_scene_test.dart`: exit 0, 1 passed.
- `test/tool/reader/fixed_layout_spike_test.dart`: exit 0, 8 passed.
- `test/tool/reader/harfbuzz_probe_test.dart`: exit 0, 3 passed.
- `test/tool/reader test/features/reader/engine/fixed
  test/features/reader/data/epub/fixed_layout_corpus_test.dart`: exit 0,
  126 passed (includes the concurrent module tests).
- `dart format --output=none --set-exit-if-changed` on the nine changed Dart
  files: exit 0. `dart analyze` on the same files: exit 0, no issues.
- Shell writes to `build/` and to the edited source files were denied under
  workspace-write; the SDK commands above used one-shot full access. No ACL
  change, dependency, download, build_runner, repo-wide format, full suite or
  git mutation was used.

Open: the SVG before/after pixel counts are not a pure D9/D10 experiment
because the concurrent SVG feature expansion landed between the baseline and
the after run; the sample and verdict comparison above is isolated, while the
changed-count deltas for SVG are labelled accordingly. D9 remains a sample-only
relaxation; gradient raster parity and all remaining D4 sub-rules stay exact or
unchanged and are still owned by A5. The negative geometry test covers a
dropped instance fragment and a swapped top-level paint order; a swapped
instance-chain paint order is enforced by the same ordinal check but is not
separately synthesised.

#### Review round 2 fixes (2026-10-29)

All three A2-gates review findings were confirmed. Fix 1 (D9 effective paint):
the old classifier walked every element path, so a gradient rectangle above a
solid sample granted the tolerance even when that rectangle was hidden. The
moved classifier now skips `display="none"`, `visibility:hidden|collapse`,
effective opacity <= 0 from the matching `SourceFragment` (so group opacity is
included), clipped-out points (clips checked before path coverage), and
non-painting fill or stroke (`none`, `transparent`, opacity 0, zero-alpha
rgba/8-digit hex). Fill and stroke visibility are evaluated separately, so an
invisible fill cannot claim the topmost paint while a visible stroke still can.
Missing fragment or unresolvable stroke width/paint remains solid. A test
covers a visible gradient control plus visibility, display, group opacity,
fill-opacity and fully clipped gradient variants above a solid rectangle; all
hidden variants classify solid.

Fix 2 (D10 support/component consistency): the exact rule now recorded in each
pixel report as `supportComponentThresholdRule` is: for a pixel whose maximum
straight-RGBA channel delta is < 2, support uses the union of `alpha > 0` and
component topology uses the union of `alpha >= 32` on both images; for a pixel
with delta >= 2, each image uses its own alpha; D3-exempt pixels and the D8
text mask remain excluded. `subThresholdUnionPixels` records how many pixels
used the union. New tests prove 0 vs 1 alpha and 31 vs 32 alpha leave both
support and components unchanged, while 0 vs 2 changes support and 30 vs 32
changes component topology.

Fix 3 (global paint order): validation now builds one expanded source paint
sequence (source order, `use` targets expanded at the referencing node, nested
`use` retained, markers excluded) and requires every native ordinal to follow
the expected rank strictly. This catches two complete instance sequences
swapping positions, which the former top-level-plus-per-chain checks accepted.
A negative test swaps the `rect` and `circle` instance sequences and asserts
`paintOrderPass=false`; the correctly ordered control passes. Marker instances
are excluded by the referencing node's `marker-start|mid|end` URL, not by the
marker definition index.

Fix 4 (shared helper): `tool/reader/fixed_layout_svg_samples.dart` now owns
`classifySvgSamples(document:, elements:, clips:, fragments:,
referenceComputedPaint:, samples:, actual:)` and
`svgReferenceComputedPaint(document:, reference:)`. The SVG harness calls it
for both its dedicated and fixed-route images; the filter/clip-mask owners can
pass their own node-to-computed-paint map instead of copying the classifier.
Behavior is identical to the previous round apart from fix 1.

Before/after: no case verdict changed in the isolated round-2 run. SVG
positive/boundary/nested/unsupported all remain pass, and fixed-route D4
parity is true again. Scene, A0 and HarfBuzz remain pass/typed as before.
Changed counts and component counts are unchanged in every case. The D10 union
changes support-bound values only: HarfBuzz reference bounds grow by one pixel
on the bottom edge for the positive (`183x92 -> 183x93`), path-none
(`107x100 -> 107x101`) and path-spacing (`217x100 -> 217x101`) families,
including their feature/raster comparisons; every support pass flag stays true.
`subThresholdUnionPixels` is 9006 for scene paint-positive and 376 for the
HarfBuzz positive case, showing the union is active without changing a gate.

Validation: format `--set-exit-if-changed` on the eight changed Dart files exit
0; scoped analyze exit 0. SVG harness test exit 0 (4 cases, including the new
D9 and paint-order tests; fixedPass true). Scene test exit 0 in the isolated
run; a later concurrent CSS-profile change made paint-positive/nested fail
capability with "Authored content outside admitted CSS profile" and source
geometry incomplete, while their pixel D4 gate still passes, so this is not a
D9/D10 regression. A0 spike test exit 0 (9 tests). HarfBuzz test exit 0 (3
tests). `test/tool/reader` retried once after a short wait: exit 1; the SVG and
A0/HarfBuzz tests pass, while the filters/clip-mask owner tests fail at their
own assertions, the mixed test fails to load on concurrent nullable
`Error.throwWithStackTrace` errors, and scene fails on the concurrent CSS
profile refusal above. No fixture, oracle, generator, production rendering
code, filters/clip-mask harness or mixed harness was changed.

Open: the concurrent SVG/CSS module and surface work is still changing
`lib/**` and `test/tool/reader`; the scene/mixed failures above must be resolved
by those owners. D9 still only relaxes the sample sub-rule, and D10's union is
evidence-only for support/topology, never a changed-pixel tolerance. A5 still
owns gradient raster parity.

## A0b

### Slice 1: HarfBuzz FFI cluster outlines (2026-10-28)

Added only five tool/reader/harfbuzz_probe*.dart files, its identity-only JSON
manifest, test/tool/reader/harfbuzz_probe_test.dart and the assigned research
report a0b-harfbuzz-probe.md. Existing shared helpers and production/fixture
files were consumed read-only. No sub-agents, downloads, new dependencies,
repository-wide checks or git mutations.

The approved DLL/ZIP and pinned font hashes verify; runtime HB is 14.6.0.
Default whole-run shaping confirms every declared fi [3,5) and combining
[6,8) cluster. Advances for Ab fi and Ab fi e\u0301 Z are 40.29296875 and
72.763671875 px, exactly Paragraph and WebKit. Every glyph is emitted once
without slicing, all original UTF-16 units are conserved, and all source CFI
round trips pass. Actual ClusterGeometry provenance is shaped. Independent
f\u0301 straight/quadratic controls retain an outline overhang of 0.029296875 px.

Measured required maxima/D4: positive 1.230398/fail, boundary 1.230398/fail,
nested 1.230398/fail, path-none 0.775690/pass, path-spacing 11.162514/fail,
path-spacingAndGlyphs 1.775340/fail. Only the existing eligible RD-1 pixel
is exempted. The required svg-text row is **fail**, not a completed A2 gate.
No failed channel, component count or tolerance is relaxed.

Resource ledger: 1 blob/face/font/draw_funcs, 13 buffers, 5 callback thunks,
76 outlines, all owned counters/payloads zero after teardown. Peak outline
owners=12; font input=171676 bytes, borrowed glyph payload=320 bytes,
outline logical payload=3500 bytes. Engine font registration and DLL modules
persist for the process; opaque caches, actual Path storage and RSS remain
unmeasured. The research report records scoped images/Paragraph disposal and
an unexecuted iOS 14.6.0 source/static-XCFramework plan with full symbol
prefixing to avoid Flutter-engine HarfBuzz collisions and Old MIT notices.

Focused format/analyze exit 0; the directly invoked flutter_tools.snapshot
test exits 0 (one executed/passed), with the DLL folder prepended to PATH.
Test execution success is explicitly separate from the failed row verdict.
Missing host binary/non-Windows runs skip with a reason and never download.

Stopped during the final evidence audit under the input-discrepancy rule:
actual corpus SHA-256 eb8379f5745d57a42c4bd2b10ed9587fee0260054af3a2747b799f8f6813af44
and oracle 33708a0fce1c0b7b523069b7e4e901923a53d4237bb51697de5a822cd1b857af
differ from the closure report's aa61e477... / 4eb18eb6... pins. This is not
CRLF normalization. No further executable checks or input reconciliation
followed. Existing ignored build/harfbuzz-probe/report.json and PNGs describe
only their exact measured inputs; closure-pinned fidelity remains unverified.

Requests: main/oracle owner must review and republish authoritative input pins
before follow-up; A2 keeps the required SVG text route open. Whole-run shaping
and SVG placement disagree around fi, especially the separated reference f/i
under spacing; native/WebKit curve sampling and D4 components remain open.
The probe has not demonstrated a passing general route. Stop after this slice;
at most one follow-up remains within the dispatched time box.

### Slice 2: final HarfBuzz evidence (2026-10-28)

The new dispatch resolves slice 1's input stop: final corpus
eb8379f5745d57a42c4bd2b10ed9587fee0260054af3a2747b799f8f6813af44 and oracle
33708a0fce1c0b7b523069b7e4e901923a53d4237bb51697de5a822cd1b857af are checked
before execution. No fixture/reference/expected data or shared helper changed.
Only A0b tool/manifest/test/research files changed; no sub-agent, network,
download, pub dependency, git mutation or production adoption occurred.

Windows is self-contained: PE imports establish HB -> GLib -> libintl ->
Windows DLLs. Absolute preloads of libintl then GLib resolve the chain before
opening HB; dependency hashes are manifest-checked. Plain test/tool/reader
runs without PATH changes. Missing main DLL/non-Windows keeps the explicit
skip; an installed binary with missing dependencies fails visibly.

A remains the current start/end/rotation-displacement gate. B keeps starts,
computedTextLength run advance and single-component rotation displacement;
ends/multi-component rotation remain diagnostics. D4 is identical. No A/B
choice or tolerance change is made. Final required cases retain the default
whole-cluster route; feature experiments are separately named diagnostics.
Maxima below are geometry CSS px; P/F after the slash is the complete verdict.

| Case | A max/final | B max/final | D4 |
| --- | --- | --- | --- |
| svg-text-positive | 1.230398/F | 0.103859/F | F |
| svg-text-boundary | 1.230398/F | 0.103859/F | F |
| svg-text-nested | 1.230398/F | 0.103859/F | F |
| svg-text-path-none | 0.775690/F | 0.103859/P | P |
| svg-text-path-spacing | 11.162514/F | 0.095346/F | F |
| svg-text-path-spacingAndGlyphs | 1.775340/F | 0.356530/F | F |

svg-text row **A=FAIL, B=FAIL**. B geometry passes all six, but D4 still fails
five. Every required source unit/glyph and CFI round trip remains conserved.

H1: PNGs/character positions support decomposed fi painting under spacing,
but raw liga=0 is insufficient: start max=1.142271 px and D4 fails (7/8
components); raw width increases by 0.72265625 px while WebKit retains the
ligated computedTextLength. A whole-run default-slot/liga=0 diagnostic gives
spacing starts=0.076281, A max=0.181220, but D4 still fails (6/8: native dot-i
and e-acute support merge versus distinct reference components). No adjusted
probe passes starts plus full D4, so no blanket liga switch was adopted.
spacingAndGlyphs raw liga=0 worsens starts to 2.642196; default-slot diagnostic
still fails D4 and A max=0.877365. CSS Text 3 section 7.2 recommends optional
ligature suppression for nonzero effective spacing; this alone neither proves
SVG implementation details nor mandates it for pure glyph scaling. Full source
citation, feature tables and all PNG names are in a0b-harfbuzz-probe.md round 2.

H2: upper A bounds differ only 1 px, b matches exactly. The sole unmatched
upper components are fi: native [173,27,183,42] plus [178,32,183,43], reference
one [173,26,183,42]. fi start is exact and all rotations are 10 degrees, so
position/rotation are excluded here. Its current end miss is 1.230398 px.
Default-slot/liga=0 positive diagnostic passes all D4 (7/7), A max=0.118032,
B max=0.088848; path-none also passes this model. This supports component
decomposition with retained ligature metrics, beyond the simple spacing H1.
It is retained as evidence, not a silently substituted required-case result.

Checks: six changed Dart files scoped format/analyze exit 0; direct dart.exe
flutter_tools.snapshot test test/tool/reader --no-pub --reporter expanded
exit 0, 7 tests passed without PATH setup. Focused A0b runs exit 0. All owned
native handles/callbacks/outline/feature payload counters finish at zero;
31 buffers, 218 outlines, five callbacks, peak retained outlines=26 and logical
outline payload=7564 bytes. DLLs/font registration/opaque caches/RSS retain
the round-1 limitations. No full suite/build_runner/broad formatting ran.

Open: adjusted-curve D4 raster topology, scaled combining end/rotation, general
SVG behavior; iOS source pin/static XCFramework/symbol-prefix and link-map
proof, release callbacks, notices, on-device pixels/lifetimes/RSS. Main chooses
A or B; A2 keeps required curved SVG text open. No shared-helper change request.
Final bounded probe ends here; no further slice or task completion is claimed.

### Slice 3: owner-extended fragment placement and raster rule (2026-10-28)

Definition B is now adopted; A remains diagnostic. Read the extension and
recorded the inferred rule before implementation in a0b-harfbuzz-probe.md.
No sub-agent, network, download, pub dependency, commit or production edit.
Only A0b probe/companion/test/research files and this owner section changed.
Shared geometry/D4/D3 helper hashes equal their pre-slice values.

Confirmed bounded placement inference: default whole-run HB metrics provide
equal component slots within a layout cluster, while liga=0 supplies painted
component fragments, with combining continuations retained alongside the base.
Path tangents use the first character's slot midpoint, not the whole fragment's
natural advance. WebKit 27.2 rotations recover quadratic chord slopes at
t=(odd integer)/512; one source-driven 256-chord traversal explains every
required path origin within .000485 px. No case-specific offsets/angles.
Spacing uses original UTF-16 indices; scaling applies to slots and outlines.
This is evidence for fragment placement, not proof of separately shaped
character runs or general path subdivision outside the bounded profile.

Unhinted fragment painting passes positive/boundary/nested/none D4 but retains
6/8 components on both adjusted probes. A local GDI query with GetFontData
byte-for-byte identity confirms nominal-20px fitting raises i's yMax from
14.4140625 to 15 and e-acute's from 15 to 16, explaining adjusted top bounds.
Nominal-only fitting fails other cases. Transform-aware GDI fitting changes
the rotated/scaled glyph shapes and passes spacing, but remains an unaccepted
uniform candidate: nested and spacingAndGlyphs still fail topology. The probe
applies it equally to all six required cases and retains all six unhinted
comparisons plus the eleven round-2 feature diagnostics. It never selects a
paint backend by case/opacity/mode to assemble a false pass.

| Case | B max px / geometry | A max px diagnostic | D4 / components | B final |
| --- | --- | ---: | --- | --- |
| svg-text-positive | .000115495 / P | .000122662 | P / 7:7 | P |
| svg-text-boundary | .000115495 / P | .000122662 | P / 7:7 | P |
| svg-text-nested | .000115495 / P | .000122662 | F / 8:7 | F |
| svg-text-path-none | .000115495 / P | .000122662 | P / 4:4 | P |
| svg-text-path-spacing | .000484398 / P | .000484398 | P / 8:8 | P |
| svg-text-path-spacingAndGlyphs | .000471645 / P | .000475706 | F / 7:8 | F |

**svg-text row B=FAIL; diagnostic A=FAIL. No general painting rule closes D4.**
Nested's hinted path fi splits; scaled f and i-dot remain joined. All other
D4 channels pass, including exact samples and zero interior mismatches. The
unchanged .5 px geometry gate passes every case. Existing D3 only: RD-1 at
(0,0) in positive/boundary/all path probes, none in nested; RD-2 nowhere.

Painted unit is explicitly component-fragment. Geometry exports actual HB
paint membership plus default layoutClusterUtf16, first-slot placementAdvance,
outline and path provenance. GDI selects each HB glyph ID from the exact font;
HB advances stay unchanged and no contour is cropped. Full cases emit 14
glyphs/15 UTF-16 units; path probes 9/10. All source/CFI and exactly-once glyph
checks pass. The original unhinted overhang control stays independent and
reference-unverified. GDI is a Windows host experiment, not an iOS backend.

Ledger: 58 HB buffers, 485 outlines, 28 feature inputs, five callbacks;
one blob/face/font/draw_funcs and one GDI memory-font/DC/font. All owned live
handles/bytes end at zero. Peak outlines=27 / logical payload=8129 bytes;
borrowed payload=360; scoped GDI scratch=171676. GDI/engine opaque allocation,
Path/GPU/RSS and process-retained DLL/ui-font costs remain unmeasured.

Canonical measured-content hashes match at start/end and the pre-edit snapshot:
corpus 6c0db5fba6b3b76b7ed9d9bf45d3510b2fb1db3375b4cea86e27ec0212e70b65;
oracle 699af229946ad242b4cff9d9184b856467ce85ecb01db635185716ac8492af87.
Hash all SVG text case/probe records, recursively sorted-key compact UTF-8 JSON,
excluding clusterSource/clusterConfirmation and evidence/provenance fields;
retain measurements, sources, maps, samples and PNGs. Whole-file pins removed.

Final focused format/check exit 0, analysis exit 0/no issues, direct
flutter_tools.snapshot test test/tool/reader/harfbuzz_probe_test.dart --no-pub
--reporter expanded exit 0, three passed. An intermediate control-mode test
failure and two brace infos were fixed and rerun. No broad suite/build_runner.
Full per-case raw data and candidate/unhinted/reference images are retained
in build/harfbuzz-probe, with a round3-inspect.png contact sheet.

A5 must re-verify component/ligature/combining placement, lengthAdjust/parent
behavior, path subdivision at other curves/scales, actual Safari/iOS glyph
rasterization and topology, DPR/nested opacity/clip and independent D3 controls.
Existing static HB packaging/symbol-prefix/source-pin/device risks remain.
Requests: main/A2 keep svg-text open under D2; no shared-helper edit is needed.
The remaining raster rule is not established. Stop after this extended slice;
no further slice, renderer acceptance or task completion is claimed.

## A3

### Slice 1: fonts, WOFF, coalescing and parser hardening (2026-10-28)

Owned implementation and focused host checks delivered. Required-fixed caller
wiring and the external WOFF2 package review remain open requests below; this
does not close A3, the required WOFF2 corpus, or device/resource acceptance.
No reading-unit/pool generalization, worker/preload lifetime changes, other
owner edits, dependency/download, sub-agent, commit or git mutation was made.

Files: engine/layout/{font_registry,font_format,woff_decoder}.dart;
engine/surface/prepared_reader_session.dart;
engine/motion/{turn_session,reader_turn_controller}.dart;
data/source/html_adapter.dart; matching new font_admission_test,
woff_decoder_test and prepared_reader_coalescing_test; existing
font_resource_seam_test.dart and data/epub/source_edge_test.dart. Paths are
relative to lib/features/reader or test/features/reader as appropriate.

FontRegistry defaults to ProcessFontBudget.shared: SHA-256 plus normalized
index=0/weight/style determines the process alias; CSS scope/family/path only
identify local diagnostics/mappings. It retains the 32 MiB pre-read check,
also checks actual bytes, propagates process/encoded admission and cancellation,
and wraps required failures in RequiredFontException. Ordinary reflow missing,
invalid-format and native failures retain fallback. Native errors cannot
certify rejection, so the process owner keeps its uncertain charge. Cancellation
abandons only a waiter, including converted-buffer ownership through physical
registration completion. Two registries and different CSS families coalesce.

WOFF 1.0: 32 MiB input/output, 16 MiB/table, 128 tables. Header/directory,
sorted unique tags, alignment, disjoint table/metadata/private ranges, exact
SFNT/table lengths and table checksums are checked. Chunked platform zlib
decodes into admitted fixed-size table views; over/under-output fails. The
head adjustment is rebuilt. Additional SFNT bytes are reserved from the existing
shared encoded owner before allocation and retained through physical font-load
drain; converted bytes are then charged by the process owner before native
registration. No extra conversion capacity or unload API is introduced.

Shaping proof: register/shape WOFF first, then the pinned SFNT control; at 20 px,
Ab fi e-combining-acute Z measures 72.763671875 px for both versus 180 px for
the absent family. Conversion output is 171676 bytes. Tests also generate zlib
tables in memory, verify identical reconstruction and exercise corruption,
overlapping/oversized declarations, count caps, admission rollback and bounded
over/under-output. Committed fixtures and expected vectors were not edited.

WOFF2 finding (offline source audit): archive 4.5.2 is MIT and contains zlib/
deflate, but no Brotli or WOFF2 decoder; Dart's zlib API is likewise insufficient.
No reviewed app-accessible decoder is installed. Host Git supplies Brotli 1.2.0
(MIT): libbrotlidec.dll 62461 bytes + libbrotlicommon.dll 143429 bytes = 205890
bytes; its optional brotli.exe is 72001 bytes. These Windows host files are not
mobile dependencies and do not implement WOFF2 glyf/loca reconstruction. Flutter
has a Brotli build rule/license, not a public Dart WOFF2-to-SFNT API, and its
referenced Brotli source directory is absent from this SDK checkout.
External option requiring review: a pinned Google WOFF2 decoder plus Brotli and
a bounded Dart/native bridge, with Windows/iOS source and static-library builds.
No candidate package artifact/version/license bundle or mobile binary size is
available locally, so exact external package/license/size vetting remains open
under the no-network/no-download constraint; no guessed size is substituted.
WOFF2 produces FontFormatFailure.unsupportedFormat before native registration
(a RequiredFontException cause for required content). Nothing was added.

Warm/direct prepare share one adjacency/recording job under full existing
layout/page/origin/CFI/direction and session generation, validate resolved target
content/layout generation, and reuse completed live surfaces. Every consumer
has a distinct retained lease. Logical cancellation cannot destroy another
consumer, close rejects late results, and stopAndDrain waits physical work.
Optional admission suppresses new warm and late optional publication while a
required consumer may finish. TurnPreparationInvalidation lets controller
cancel/settings/layout changes revoke publication synchronously even with no
bound pair; native releases stay in the posted control task. unbind/close also
invalidate. This preserves 3+1 owners and existing exactly-once acceptance.

Parser: tokenizer-level head/body template isolation excludes fragment content
without leaking body/formatting state, including nested/raw-text cases. Disabled
body noscript participates in normal tree building so child blocks close an
open paragraph; final enabled noscript remains raw text. Entities decode once;
ignored select tags cannot rename ancestors; foreign templates retain namespace.
Both existing WebKit source-edge/CFI vectors pass. The original single head
noscript raw-URL exclusion is unchanged; that mismatch remains documented.

Validation uses direct dart.exe and flutter_tools.snapshot, always --no-pub.
Final scoped format and analyze cover the 12 changed Dart files only.
Commands/test groups (repository root):
- dart.exe format --set-exit-if-changed <12 changed Dart files>: exit 0.
- dart.exe analyze <12 changed Dart files>: exit 0, no issues.
- dart.exe flutter_tools.snapshot test <font_admission_test,
  font_resource_seam_test, woff_decoder_test, source_edge_test> --no-pub:
  exit 0 across affected runs (19 distinct tests); WOFF decoder final run 5/5.
- Same test command for prepared_reader_coalescing_test,
  reader_motion_isolation_test, prepared_reader_test, page_surface_pool_test:
  exit 0, 26 tests, including real pending pagination drain and acceptance.
Earlier cross-owner compilation attempts exited 1 (viewportWidth, incomplete
CSS parts, FunctionTerm.params); A2 edits resolved them before the final pass.
An initial local optional-interface promotion error was repaired and rechecked.
The existing ten process_font_budget_test cases also passed during the earlier
blocked combined invocation. No full suite, build_runner or broad format ran.

Requests / open issues:
- A2: fixed preparation must call FontRegistry.loadResources(...,
  requiredFonts: true, cancellation: capturedToken). Existing SectionPreparer
  remains the reflow default; do not infer fixed completeness from its fallback
  map. Route RequiredFontException/SceneAdmissionException without publishing a
  partial successful scene. No FontRegistry construction change is required.
- A2: per-face process aliases expose the existing family-only mapping seam;
  multi-weight/style fixed families need descriptor-aware selection in the
  paragraph consumer rather than taking a family's final alias. Request the
  concrete mapping contract before that integration; those files were untouched.
- Main: obtain/review a pinned external WOFF2 decoder artifact and its exact
  licence/source/Windows/iOS binary sizes before approving any dependency. The
  host Brotli sizes above are not a mobile-size estimate or a WOFF2 solution.
- Main: update reader-engine/resource-admission carry-forward specs after the
  owning fixed caller is wired; current host evidence is not an iPhone verdict.
Reading-unit composition integration and broader scene/worker budgets remain
the later A3 slice, as dispatched. Stop here; no completed-task claim is made.

### Slice 2: regression closure and reflow reading-unit session/pool (2026-10-28)

Delivered the two regression repairs and the opt-in A1 navigator-backed reflow
session/pool path. This slice does not close A3, fixed-scene integration,
preallocation/resource-class admission, worker reader reservations or device
acceptance. No other owner's production files, corpus/expected vectors,
dependencies, downloads, sub-agents or git mutations were used.

Regression decisions:
- Keep the content/face-derived process alias (`shiori-face-`): CSS scope is
  not native registration identity. The old test's content-prefix expectation
  was obsolete. Its body-font fixture was also overwritten by the intentional
  reader override, so the previous non-18-multiple assertion did not prove use.
  The repaired test builds an in-memory EPUB using the same archived Roboto
  bytes, explicitly requests FixtureRoboto on a descendant Latin paragraph,
  and compares actual buildParagraph output with an absent-family control.
  Shaping differs by more than 0.5 px; a completed registration alone fails.
  Repeated preparation still produces no additional registry records.
- Audited SectionRendition and RenditionIssue before extending the transferred
  graph allowlist. All instance fields are final; the sole private rendition
  constructor is reached through defensive Map/List.unmodifiable copies;
  issue fields are enum/string scalars; getters compute without lazy state.
  The VM probe now traverses nonempty invalid rendition issues, mutates the
  original input collections to prove detachment, and verifies all four
  published collections reject mutation. Existing lazy book/archive rejection
  remains intact. The worker graph regression passes.

Files changed in this slice (relative to lib/features/reader/ unless noted):
- engine/surface/{prepared_reader_session,page_surface_pool}.dart and new
  prepared_unit_navigation.dart.
- test/features/reader/engine/layout/paragraph_factory_test.dart;
  test/features/reader/data/worker/prepared_publication_transfer_probe.dart.txt.
- test/features/reader/engine/surface/{surface_test_support,
  page_surface_pool_test}.dart and new prepared_unit_session_test.dart and
  unit_surface_accounting_test.dart; this A3 progress section only.
Existing prepared_reader.dart/motion/coalescing modifications belong to earlier
work and were not edited in this slice.

Session seam: open(..., navigator: ComposedReadingUnitNavigator, activation:
ServerSession, isActivationCurrent: guard). A unit session requires a captured
activation plus guard, validates its server against the full unit content, and
matches each borrowed PreparedSection to the navigator's exact layout key,
digest and actual page count. The prepared surface carries the ReadingUnit;
its section retains LayoutIdentity, and the session captures activation plus
reader epoch across awaits. Same BookKey/layout after A -> B -> A cannot make
first-A work publish into the new activation. Closing/draining remains explicit.

Adjacency, nonlinear scan, boundaries, TOC fragments and source-position lookup
use A1's actual navigator. prepareTocTarget / prepareSourcePosition return
ordinary PreparedTurn candidates; navigate/prove/accept/restore retain the
existing TurnPosition/TurnSession proof and handoff flow. TOC candidates use
distinct coalescing keys and cannot be mistaken for an adjacent warm result.
Existing prepared-session motion/surface tests now use the unit-backed harness;
the separate numeric/fake-session motion tests retain their original coverage.

Pool accounting: UnitSurfaceReservation is the sole pending/retained owner
set; owners is its size. Each reservation atomically calls
SceneResourceBudget.reserveUnit(sourcePages: unit.realSourceCount), before
surface work. It is not an idle cache or another four-unit capacity. The same
reservation transfers into the picture surface and is released only after its
last reference destroys picture/images, or failed/canceled physical work drains.
Close forbids publication but does not release live/pending owners early.
Legacy prepare calls are charged one unit/one source, without fabricated IDs.

Evidence: nine new tests cover 9-page/3-section forward/reverse equivalence to
old reflow arithmetic, restore, nonlinear TOC/source lookup, candidate isolation,
cancellation with a remaining waiter, and A -> B -> A with a late first-A load.
They also cover mixed reflow -> fixed unavailable without a false end boundary;
four pending spread owners charge eight real sources, blanks charge one rather
than two, fifth-owner refusal, atomic budget refusal, shared-budget old/new
pool overlap, idempotent release and zero counters after teardown. Existing
actual image/picture tests additionally verify charges survive pending close
and retained references, and return to zero after disposal/refusal.

Validation (direct dart.exe; tests use flutter_tools.snapshot and --no-pub):
- format --output=none --set-exit-if-changed <8 changed Dart files and the
  standalone .dart.txt audit>: final exit 0, zero changes (9 files). First
  final-format check exited 1 for the audit template; scoped format fixed it.
- analyze <8 changed .dart files>: final exit 0, no issues. The standalone
  mirror audit is compiled/executed by prepared_publication_graph_test instead.
- test test/features/reader/engine/surface test/features/reader/engine/motion
  test/features/reader/engine/layout/paragraph_factory_test.dart
  test/features/reader/data/worker --no-pub --reporter expanded: exit 0,
  270 passed; ignored build/a3-slice2-tests.log records this run.
- Earlier combined run: exit 1, 260 passed / 1 failed at the strengthened
  shaping assertion; the unchanged reader body override explained the failure.
  Three focused shaping attempts exited 1, then the explicit descendant test
  passed (exit 0); new unit tests separately passed before the final group.
- Scoped git diff --check: final exit 0. No broad format/analyze, full suite,
  build_runner, dependency change, fixture regeneration or commit.

Requests / remaining integration seams:
- A2 must publish its actual complete fixed-scene result and preparation API:
  per-real-source identity, authored paint/geometry and completeness, resource
  plan before allocation (including conservative picture bound, decoded-image
  bounds, source/shaping/vector/layer classes and depths), retained source/
  resource handles with idempotent disposal, cancellation and physical drain.
  A3 supplies the pool reservation before work and must transfer that SAME
  owner into the retained unit, reconcile actual picture bytes, and retain
  old/new allocations until actual disposal. Required-font failures must
  propagate as already requested in slice 1. No competing scene API is added.
  prepareFixedUnit returns FixedUnitPreparationUnavailable with no allocation;
  mixed adjacency reports unavailable while preserving the reflow foreground.
- Main/probe owner: the old diagnostic open caller supplies only a string
  contentId/section loader, not full ContentIdentity/source inputs. It remains
  an explicit compatibility path with old arithmetic; no fake server/content
  identity or eager whole-book preparation was invented. Wire its publication
  identity, exact paginated ReadingUnitSection inputs/documents/locator and
  activation guard into navigator-backed open. New unit sessions require these.
- Source sections remain borrowed from the caller's existing preparation owner;
  this is not proof against eviction by that owner's four-section cache. A2's
  retained scene/source handles and main's worker/file ownership must precede
  downloaded fixed/mixed integration. Shared SceneResourceBudget injection is
  required when old/new pools overlap; it is exercised by the race tests.
- Current picture/image byte checks still follow native record/decode. This
  slice enforces unit/constituent admission, not a preallocation byte/RSS gate.
  Do not infer source/vector/layer/process memory safety or fixed fidelity from
  the passing unit counters. WOFF2 and the earlier whole-phase provenance
  requests remain open; no later slice or whole-task completion is claimed.

Stopped after slice 2.

### Slice 3: reader leases, worker reservation and preallocation (2026-10-28)

Delivered the A3-owned lifetime, queue and allocation seams and focused host
checks. Production route/cache wiring is an explicit request below because
those files are outside the A3 ownership row. Fixed preparation remains
FixedUnitPreparationUnavailable without allocating an A2 scene. This slice
does not close A3, fixed fidelity, WOFF2 or device/resource acceptance.

Files changed in this slice (relative to lib/features/reader/):
- data/worker/publication_worker{,_reservation,_preload,_queue,_exception}.dart.
- engine/surface/{reader_publication_lifetime,page_surface_pool,
  prepared_reader_session,prepared_unit_navigation}.dart;
  engine/layout/image_cache.dart.
- engine/motion/{reader_turn_controller,turn_controller_work}.dart.
- test/features/reader/data/worker/publication_worker_reservation_test.dart.
- test/features/reader/engine/surface/page_surface_pool_test.dart plus new
  reader_publication_lifetime_test, reader_publication_cancellation_test,
  reader_shutdown_drain_test and section_eviction_protection_test.dart.
- This A3 progress section only. Existing other-owner changes and earlier
  A3 slice files were preserved; no fixture/expected data was edited.

ReaderPublicationLifetime.open takes the still-owned PreparedBook, captured
activation/layout and current guard, an independent acquireHead callback,
the EXISTING shared PrepareBookQueue and the session worker getter. It rejects
the route lease object itself, validates full BookKey/digest/parser/canonical
versions plus validated path/length/local metadata, and enters the shared queue
before getting/reserving/reopening the immutable path. Only then can preload
run. The route can release PreparedBook after open without ending this pin.
Every file/queue/worker/open/preload await checks captured activation, lifetime
or generation/layout before publication. Abandoned preload resources dispose.

The reader holds the existing preparation queue through final detach, so a
normal concurrent prepare is deferred as one complete staged/import/detach
transaction. PublicationWorkerReservation additionally protects direct worker
calls: open/prepare/detach/close cannot retire the reader adapter. Adapter reads
without its token fail typed reserved; reader operations carry that token.
Conflicting deferred waiters share the eight-pending bound, canceled waiters
unregister, reservation acquisition refuses already-running/queued work, and
release waits behind physical canceled work before detach. Releasing tokens is
idempotent; failed detach physically closes the worker before permitting final
file release. Shutdown detach cannot be starved by a full deferred queue.
The existing shared 128 MiB encoded budget and its accounting are unchanged.

Publication-backed session close disables work, invalidates generations,
cancels/drains motion and preparation, disposes its surface references, awaits
all remaining pool references, disposes source/resource adapters, detaches the
worker, then releases the independent file pin. closed exposes that barrier.
ReaderTurnController.closeAndDrain tracks physical turn work and injected-clock
control tasks, rather than equating a canceled TurnResult with physical drain.
Cleanup-hook failure retains the pin/reservation instead of disposing beneath
live objects. Compatibility probe close remains synchronous as before.

SurfaceAllocationBudget shares the existing 16 MiB picture and 48 MiB image
owners across overlapping old/new pools. Reflow reserves a conservative plan
before decode/record: 64 KiB base, 4 KiB per fragment, 128 bytes per paragraph
UTF-16 unit, 1 KiB per painted background and referenced vector picture bytes.
Actual approximateBytesUsed reconciles downward; a plan overrun disposes the
candidate rather than growing unadmitted storage. Native opaque allocation/RSS
is not proven by this estimate. A2 must provide its own complete fixed-scene
resource plan; this reflow estimate is not a fixed-scene admission contract.

Image admission reserves full intrinsic RGBA plus requested RGBA output before
instantiateCodec/getNextFrame. Pending peaks and retained images share one cap,
with safe dimension checks; old leases remain counted during replacement.
Oversize/refusal throws ImageAdmissionException; pool failure returns null and
releases partial work instead of recording a successful replacement placeholder.
Decode failures retain the legacy reflow fallback semantics. Capacity refusal
does not evict any leased raster. Buffers/descriptors/codecs dispose explicitly.

Pool pinsSection covers pending records, all live surfaces/reference counts,
and temporary source pins across session position/preparation awaits. A shared
allocation owner preserves those pins across old/new pools. The real existing
four-section ReaderPreparationRepository is tested with owner.pinned =
pool.pinsSection: repeated fifth/sixth-section eviction attempts retain the same
live PreparedSection. Final release removes its pin exactly once. The diagnostic
controller's production frame-only callback is outside A3 ownership and still
needs the wiring request below; no end-to-end product eviction claim is made.

Evidence: real immutable cache, SQLite, worker and fake transport tests prove
route release under cache pressure, blocked concurrent prepare, full identity
mismatch before worker access, final eviction after shutdown, and exact-once
file release. Message gates cover cancel at lease/queue/worker/open and both
preload worker phases, plus stale result disposal, delayed physical detach,
worker exit during reservation release and A -> B -> A rejection. Intermediate
navigation awaits also recheck the captured lifetime before further work.
Fake motion clocks prove logical cancellation
cannot finish drain early. Surface tests prove no picture/image allocation on
near-limit refusal, actual-byte reconciliation, old/new overlap, retained raster
protection, external surface references through shutdown and live cache pins.

Validation used direct dart.exe and flutter_tools.snapshot only:
- format --output=none --set-exit-if-changed <18 changed Dart files>: exit 0,
  zero changes; scoped analyze of those same 18 files: exit 0, no issues.
- test test/features/reader/engine/surface test/features/reader/engine/motion
  test/features/reader/data/worker test/features/reader/data/resources plus
  test/features/library/data/publications/{prepare_book_test,
  prepare_book_lifecycle_test,prepare_book_integration_test,
  prepare_book_corruption_test,session_publication_worker_test}.dart
  --no-pub --reporter expanded: exit 0, 345 passed.
- Scoped git diff --check: exit 0. Exact Dart file scope and final test log
  are ignored build/a3-slice3-files.txt and build/a3-slice3-tests.log.
- Initial affected run: exit 1, 285 passed / one old picture assertion failed
  because it expected post-record refusal. Updated it to prove no record on
  admission failure. Initial focused shutdown run: exit 1 for a missing test
  enum import; corrected only the new owned test, focused retry exit 0.
- No full suite, broad formatting/analysis, build_runner, dependency/download,
  real network, sub-agent, git mutation or another owner's file edit occurred.

Requests / open integration:
- Main/library route owner: call ReaderPublicationLifetime.open with the actual
  cache/queue/session worker before releasing the route PreparedBook; register
  activation retirement to close the reader and await session.closed. Pass
  cancelAndDrainMotion: controller.closeAndDrain and the real source-owner
  cancel/drain/dispose hooks to publication-backed PreparedReaderSession.open.
  The supplied guard must capture the full activation, not only ServerKey.
  Deferred worker.close now requires this coordinated reader shutdown.
- Main/diagnostics cache owner: replace the frame-only owner.pinned callback
  in reader_probe_controller.dart with the shared allocation owner's
  pinsSection; share SurfaceAllocationBudget and SceneResourceBudget across
  old/new pools. ReaderPreparationRepository's existing callback needs no
  competing cache implementation. Tests demonstrate the actual seam, not
  production wiring. If a future source cache exceeds four real pages, its
  owner must retain every live constituent rather than evicting one.
- A2: publish the complete fixed-scene preparation/resource/retained-source API
  and required-font/cancellation propagation requested in slices 1/2. No new
  fixed success wrapper, fidelity claim or additional capacity was invented.
- Required WOFF2, whole-phase provenance review and device native/RSS/opaque
  picture/decode measurements remain open as recorded in earlier slices.

Stopped after slice 3; no whole-task completion is claimed.

### A3 slice 3b: image admission regression reconciliation

2026-10-28. Changed only the granted image-cache case in
test/features/reader/engine/pagination/pagination_test.dart and added two
A3-owned surface tests. No production code or another owner's files changed.
The old all-leased overshoot expectation is replaced with typed refusal,
unchanged leased entries/pending accounting, and eviction of an unleased
entry before admitting the next intrinsic-plus-output decode peak. An
impossible target with invalid bytes proves refusal precedes encoded-data
inspection. Existing page_surface_pool_test.dart's "decode peak refuses before
image allocation and keeps old leases" independently uses ui.Image.onCreate
to prove zero image allocation on refusal and protection of the old lease.

New reflow_image_admission_test.dart performs every-page surface preparation
at all three existing gate settings, default 430 x 932 viewport / DPR 3,
unchanged 48 MiB image cap. Three prior page leases remain held while a fourth
is prepared, including across section boundaries. ui.Image.onCreate samples
the cache while intrinsic + output + retained reservations are still charged;
these are logical admitted RGBA peaks, not native opaque/RSS measurements.
All owners and decoded bytes return to zero after each book/settings pass.

Anonymous results (counts only, no private titles, filenames or text):
- Two synthetic fixtures, six sections, three settings, 2,593 page visits,
  12 decode allocations; zero surface/image admission refusals.
  Image-fixture peak 12,422,232 bytes, retained peak 12,397,656 bytes.
  Long-content peak 0 bytes / 0 decodes; that fixture contains no raster work.
- Optional local regression inputs were present: four distinct books, 60
  sections, three settings, 3,486 page visits, 51 decode allocations;
  zero surface/image admission refusals. Maximum admitted peak 33,211,752
  bytes; maximum retained 21,390,696 bytes. Default cap is 50,331,648 bytes.
- All full passes reached four concurrent pool owners. No budget was raised.

New image_refusal_surface_test.dart, "image refusal retains accepted page
without publishing partial surface", forces a second incoming image to fail
after the first incoming image has allocated. It proves the partial lease is
disposed, the accepted raster/picture/proof/position survive, no incoming
picture is recorded, no frame is published, and only the accepted owner stays.
Surfacing gap: ReaderImageCache throws typed ImageAdmissionException, but
PageSurfacePool.prepare catches it and returns null; PreparedReaderSession
returns TurnNavigationKind.unavailable with no resource-specific outcome.
Thus typed resource failure is proved only at cache admission, not end-to-end.
No production reconciliation of this newly identified gap was attempted.

Validation (direct dart.exe and flutter_tools.snapshot, no .bat wrappers):
- format --output=none --set-exit-if-changed and analyze on the three changed
  Dart files: exit 0 each, zero formatting changes / no analysis issues.
- flutter_tools.snapshot test test/features/reader/engine/pagination
  test/features/reader/engine/layout test/features/reader/engine/surface
  test/features/reader/engine/motion test/features/reader/data/worker
  test/features/reader/data/resources plus the prior five library tests under
  test/features/library/data/publications/: prepare_book_test.dart,
  prepare_book_lifecycle_test.dart, prepare_book_integration_test.dart,
  prepare_book_corruption_test.dart, session_publication_worker_test.dart,
  --no-pub --reporter expanded: exit 0, 542 passed / two optional skips.
- Final focused rerun of both new surface test files after strengthening the
  decode assertion: exit 0, three passed. Logs: ignored
  build/a3-slice3b-tests.log and build/a3-slice3b-image-pass.log.
- Scoped git diff --check: exit 0. Optional skips were the unset native CFI
  export destination and missing pre-seam baseline capture; private tests ran.
- Initial focused run: exit 1, the new refusal fixture did not account for
  default DPR 3 in its tiny test-only budget; corrected its geometry/output
  charge. The cache reconciliation and existing allocation-hook test passed.

Requests / open issues: A3/main must define and preserve a typed resource
failure through pool/session navigation; generic unavailable currently erases
the admission reason. Accepted-state retention and absence of partial output
are proved, but the requested typed session outcome is not claimed complete.
No broad tests/format, build_runner, downloads/network, sub-agents, git commit,
push, stash, reset or checkout. Stopped after slice 3b.

### A3 slice 4: fixed session integration and recovery audit (2026-10-28)

Recovered the interrupted slice from its on-disk diff; no implementation was
restarted. The published A2 seam and all A2 SVG/oracle/harness/helper files were
read-only. Existing A3 implementation already supplied descriptor selection,
physical drain, fixed/mixed session integration and typed failures. Recovery
changed only fixed_session_failure_test.dart, fixed_session_integration_test.dart
and this section. The 42-file check manifest includes existing A3 changes;
format changed only those two tests. No production correction was necessary.

Audit of the original work order (paths below are relative to
lib/features/reader/ or test/features/reader/ as indicated):

| Item | At recovery | Final | Evidence |
| --- | --- | --- | --- |
| 1. Descriptor-aware face selection; unchanged reflow | Done | Done | engine/layout/font_mapping.dart:18; font_registry.dart:82; test engine/layout/font_face_selection_test.dart, "CSS style then weight order, family order and the 400/500 interval" and "same family/path retains distinct descriptor aliases; reflow keeps its map". |
| 2. Physical started/coalesced font drain | Done | Done | engine/layout/font_registry.dart:72,166,197; test font_face_selection_test.dart, "both canceled registries drain one coalesced native registration"; fixed_session_failure_test.dart, "cancel during native font work retains reservations through physical drain". |
| 3. Plan/reserve/prepare/publish fixed units; mixed boundaries and ownership | Done | Done | engine/surface/fixed_unit_surface.dart:51,90,147,182; page_surface_pool.dart:233; test fixed_session_integration_test.dart, "A0 mixed source: reflow, single, spread and reverse/TOC retain exact sources"; fixed_motion_session_test.dart. |
| 4. Typed admission/font/capability failures keep accepted state | Done (requested types) | Done | engine/motion/reader_preparation_failure.dart; engine/surface/prepared_reader_session.dart:527,856; image_refusal_surface_test.dart; fixed_session_failure_test.dart:38 now exercises every failure kind, plus fixed-anchor-proof at :132. |
| 5. Corpus single/spread, mixed, recompose, cancel/drain, server switch, failure and 4/8 tests | Partial: existing requested cases passed; final anchor branch and capacity/refcount evidence needed strengthening | Done | fixed_session_integration_test.dart:37,121,209; fixed_session_failure_test.dart:132,187,232; fixed_motion_session_test.dart; fixed_image_reservation_test.dart. Recovery adds encoded-admission/anchor cases and fifth-unit/native-picture disposal assertions. |
| 6. Scoped format/analyze/tests and progress record | Partial: interrupted before final record | Done | 42-file scoped format/analyze exit 0; all four requested test directories exit 0, 391 passed; this audit section. |

Face selection preserves ordered CSS families, matches style before CSS weight
order (including 400/500), and uses each admitted descriptor's native alias.
Same family/path with different weight/style remains distinct. Required fixed
fonts fail explicitly; ordinary reflow still receives its last-family map.

FontRegistry tracks the physical, uncanceled load future, including a coalesced
process registration. A canceled waiter cannot write a late local face record.
A2 receives drainFonts and retains source/tickets through operation.drained;
the process font charge remains after successful native registration. The
two-registry test proves one registration, pending drain until native completion,
and no retired registry records. Session cancellation and A -> B -> A tests prove
late work cannot publish, old proof is rejected after retirement, and fresh A
can prepare. These checks use controlled native completion, not timing guesses.

Fixed singles/spreads use A1 composition/navigation and A2 plan/prepare. Every
real constituent has an independent source/resource lease; blanks acquire none.
Unit resources, picture plans and image output reservations precede preparation;
decoded images additionally use intrinsic/transient admission. Shared 16/48 MiB
owners preserve old/new overlap. Geometry is placed through the slot transform
once. Forward/back, nonlinear TOC, same-spread active side, portrait recomposition,
both mixed boundaries and existing motion exactly-once acceptance are covered.

Typed failure matrix (all return failed with original typed cause, unchanged
accepted position/frame/proof, zero frame publications, and cleaned candidate):

| Failure | Session evidence |
| --- | --- |
| pictureAdmission | Fixed plan exceeds remaining picture owner before recording. |
| imageAdmission | Oversize fixed output refuses before acquire/decode; reflow test also destroys a partially decoded candidate. |
| processFontExhausted | Real process-font owner refuses the required face. |
| requiredFont | Invalid required font bytes propagate RequiredFontException. |
| fixedCapability | Reflow-style input cannot stand in for fixed styles; additional unpainted-source case reaches RenderSectionCapability/fixed-anchor-proof after preparing and disposes that scene. |
| sceneAdmission | Real shared paragraph limit refuses the candidate. |
| encodedAdmission | Zero-capacity ReaderResourceBudget refuses inside the source loader and propagates through session navigation. |

Accounting proof: four prepared spreads retain four reading units/eight sources,
eight native scene pictures and four composites. A fifth preparation refuses
without changing the retained charges/pictures and releases its acquired sources
once. Closing the pool and double-releasing the original leases leaves the
extra retained spread alive; final double release drains everything. Source
release and resource-adapter disposal maps equal acquisition counts, every
picture is disposed, all scene classes/picture bytes are zero. The separate
fixed-image test proves output credit exchange, intrinsic peak charging and
final image disposal. Native opaque/RSS memory is not inferred from these counts.

Validation used direct dart.exe and flutter_tools.snapshot only:
- format <42 A3 Dart files>: exit 0, two test files formatted;
  format --output=none --set-exit-if-changed on the same manifest: exit 0,
  zero changes; analyze on the same 42 files: exit 0, no issues.
- test test/features/reader/engine/surface test/features/reader/engine/motion
  test/features/reader/engine/layout test/features/reader/data/worker
  --no-pub --reporter expanded: exit 0, 391 passed, no skips/failures.
- Focused recovery failure tests: exit 0, 10 passed; accounting/integration:
  exit 0, 3 passed. Scoped git diff --check: exit 0.
- Exact manifest/logs: ignored build/a3-slice4-recovery-files.txt and
  build/a3-slice4-recovery-{format,analyze,tests,focused,accounting}.log.

Requests: none for this slice. Existing main/library/diagnostics route wiring
requests from slice 3 remain with those owners; required WOFF2 conversion,
A2 fidelity/oracle closure and device/native memory acceptance remain separate
work. No new dependency, network, codegen, full suite, broad format/analyze,
sub-agent, commit/push/stash/reset/checkout or other-owner edit occurred.
Stopped after slice 4; this is not whole-A3, whole-S4a or device acceptance.

## A1-rest

### Slice 1: metadata, dimensions, composition and navigator (2026-10-28)

Implementation delivered; the 49 new tests and 56 related regression tests
pass. Full cross-owner regression closure remains open for the two existing
test seams below. This is not session/pool integration or renderer acceptance.
No other owner's production/test files, fixture expectations, dependencies,
source/CFI/canonical implementation, or git state were edited.

Production files changed (relative to lib/features/reader/):
- data/layout/section_rendition.dart: immutable raw/effective rendition and
  typed malformed/unsupported issues, package defaults, legacy layout input,
  itemref overrides, conflict detection and reference spread=portrait support.
- data/layout/section_source_facts.dart: dimension extraction from the existing
  source tree, preserving SVG root identity and preserveAspectRatio.
- data/layout/authored_dimension_resolver.dart and verified_raster_wrapper.dart:
  document viewport > package viewport > verified raster wrapper; SVG absolute
  root viewport > viewBox extent. Relative SVG dimensions, missing dimensions,
  malformed declarations and conflicting viewports never receive guessed sizes.
  viewBox origins/aspect metadata remain separate from page dimensions.
- data/layout/reading_unit_section.dart: immutable section composition inputs,
  original source/spine identity and actual reflow page count/layout key.
- data/worker/publication_layout_facts.dart and publication_import_facts.dart:
  validated rendition crosses the existing worker snapshot; direction issues
  remain separate. Legacy mode is an import hint; resolvedMode is null for
  unvalidated/invalid metadata. Uninspected sections retain null source/style.
- engine/support/layout_flags.dart: sectionRendition adapter, retaining the
  contract's legacy S2 detector behavior. Fixed metadata is valid in the new
  rendition route and supplies no unsupported issue by itself.
- engine/pagination/reading_unit_composer.dart: diagnostic source-slot plan
  and dimensions-validated units; centered/blank/paired pages, run boundaries,
  per-item spreads, portrait recomposition and individual source identities.
- engine/pagination/reading_unit_navigator.dart: ComposedReadingUnitNavigator,
  physical-adjacency then linear-scan behavior, source/TOC-fragment lookup,
  explicit nonlinear targets, boundaries and immutable viewport replacement.
  Reflow viewport replacement requires fresh pagination and its locator.

New tests/helpers (relative to test/features/reader/):
- data/layout/{section_rendition_test,authored_dimension_resolver_test,
  fixed_layout_test_support}.dart
- engine/pagination/{reading_unit_composer_test,reading_unit_navigator_test,
  reading_unit_reflow_test,reading_unit_test_support}.dart

Composition evidence: 48/52 exact landscape slot-plan matches against
oracle.cases[].referenceSpreadSlots. All 52 cases are checked, with no changed
expected data. Differences are explicit:
- metadata-unsupported: reference assigns source 0 to right slot 0; native
  refuses future-layout/diagonal/future-spread via typed metadata issues.
- mixed-navigation-positive, mixed-navigation-nested and
  mixed-navigation-unsupported: source 0/unit 0 and source 5/unit 4 are centered
  reflow pages, while the all-fixed oracle assigns right and left respectively.
  Every source and unit index, and every fixed-side slot, still matches.
49 cases materialize units. The other three are metadata-unsupported plus
dimensions-boundary and dimensions-unsupported; diagnostic planning for the
two dimension cases is not rendering acceptance or guessed geometry.

Dimensions: positive/nested resolve to 320 x 240 CSS px, matching WebKit within
the unchanged 0.5 px threshold; nonzero viewBox origins do not inflate size.
Boundary width=0,height=NaN is malformed; width=50%,height=75% is unsupported.
Additional tests cover absolute SVG units, precedence, verified raster-only
fallback, conflicts, missing/invalid/relative values and malformed duplicates.
Metadata/mixed raw/effective rows pass, including unknown values, all override
families, original spine slots, separate vertical/RTL facts and immutable
typed worker transfer. Mixed forward/reverse, nonlinear partner retention,
TOC fragments, UTF-16 CFI round trips and viewport source identity pass.
All ten existing reflow fixtures run under all three gateSettings: one unit
per prepared page, bidirectional adjacency, actual anchor/TOC lookup and
viewport repagination preserve the original source identity.

Validation used D:/DevTools/flutter/bin/cache/dart-sdk/bin/dart.exe directly:
- format --output=none --set-exit-if-changed <the 17 changed Dart files>:
  exit 0, zero changes; analyze <the same 17 files>: exit 0, no issues.
- dart.exe D:/DevTools/flutter/bin/cache/flutter_tools.snapshot test <the five
  new *_test.dart files above> <existing publication_import_metadata_test.dart,
  publication_import_test.dart, publication_import_values_test.dart,
  unsupported_layout_test.dart> --no-pub --reporter expanded:
  final exit 0, 105 passed (49 new + 56 existing).
- An earlier affected 11-file run included prepared_publication_graph_test.dart
  and fixed_layout_corpus_test.dart. A targeted retry with --name
  'the measured WebKit corpus pins every row and variant|PreparedPublication
  contains only immutable values' exited 1: the same two failures remain.
  The other corpus source/CFI/canonical v1 and all-OPF worker tests passed in
  the affected run. A mistaken --plain-name alternation selected no tests;
  the corrected --name invocation above is the actual retry evidence.
- Scoped git diff --check: exit 0. No full suite, build_runner, repository-wide
  formatting, downloads, sub-agents or git mutations.
Initial A2 style compile errors were retried once and reported. After A2
supplied its correction, focused tests compiled normally. Own TOC URI failure
handling and the test's empty-id selector were corrected and verified.

Measured input provenance (not a rewrite of the A0 closure report):
- corpus SHA-256: eb8379f5745d57a42c4bd2b10ed9587fee0260054af3a2747b799f8f6813af44
- oracle SHA-256: 33708a0fce1c0b7b523069b7e4e901923a53d4237bb51697de5a822cd1b857af
- oracle.corpusSHA256 matches the actual corpus; referenceDirty is false.
- reference commit a4bda23fd3e82e285a22566d88576e67d3e8756b;
  Foliate commit 78914aef4466eb960965702401634c2cb348e9b1.
- Pinned and installed fixed-layout.js SHA-256 both equal
  7aee1d15d8e0479b8a6c59a20304b250dafc4c7dc158147a2b2c6bed9e180b4c.
The whole corpus/oracle hashes differ from the older closure report pins;
main/oracle owner must reconcile that provenance before whole-phase closure.

Requests / open issues:
- A3/main: review and extend prepared_publication_transfer_probe.dart.txt's
  immutable-value allowlist for SectionRendition and RenditionIssue. The existing
  audit fails at SectionRendition before traversing its final fields; it was
  not weakened or edited here. The new worker test verifies actual typed
  transfer and unmodifiable raw/effective/issues collections.
- Main/oracle owner: fixed_layout_corpus_test.dart:62 still expects no PNG for
  cascade-positive, but the current oracle contains one. Review the expanded
  PNG coverage and update that owned assertion/provenance; no fixture or
  existing expected data was edited here.
- A2: consume typed rendition/dimension outcomes in capability preparation.
  SVG origin/aspect transforms belong in the authored scene; slot transforms
  only place each page in its unit. Direction/inspection facts still require
  capability handling; the diagnostic plan is not a Complete verdict.
- A3: integrate the navigator with the existing session/pool, supplied source
  documents and PageAnchors.locate callbacks. Retain captured LayoutIdentity,
  activation/generation and constituent leases; unit IDs are not stale-result
  tokens. This slice intentionally stops before that integration.

Stopped after slice 1. Full task completion is not claimed while the two
cross-owner regression seams and whole-phase provenance review remain open.

## A2-text

### A2-text segment 7a (2026-10-28)

Delivered the isolated host text module under
`lib/features/reader/engine/text/harfbuzz/`: harfbuzz.dart plus hb_abi,
hb_bindings, hb_source, hb_resources, hb_font, hb_drawing, hb_shape, hb_run,
hb_placement and hb_path parts. Added harfbuzz_test.dart, module_fixture.dart
and module_measurements.dart under the matching test directory. Added the
unwired `tool/ci/build_harfbuzz_ios.sh` draft and
`research/harfbuzz-ios-packaging.md`. No fixed/layout/SVG scene, dependency,
native project, CI workflow, probe, fixture or oracle file was edited.

Bindings eagerly resolve the whole required ABI, fail with a typed missing
symbol/version/library/identity reason, and check 14.6.0 plus C structure sizes.
Windows verifies all three pinned DLL hashes and preloads intl, GLib and HB
by absolute path; iOS selects process symbols with the shiori_ prefix. Only
dart:ffi is used; no package:ffi, dependency or download was added.

HarfBuzzAdmittedFont.load reuses A3's exact canonical process-font descriptor
and shared admission. HarfBuzzFont.open consumes immutable admitted SFNT bytes.
One shapeRun request performs two whole-run shapes: requested features for
layout, and the same plus liga=0 for paint. Layout cluster advances supply
equal UTF16 slots; independently placed paint fragments retain combining marks
with their base. The public result exposes both maps/glyph IDs. place supports
authored x/y/dx/dy/rotation/middle anchor, spacing/spacingAndGlyphs and quadratic
path startOffset (absolute/percent), using the first-slot midpoint and exactly
256 chords. Prepared Paths and shaped-provenance ClusterGeometry are retained;
placement never reshapes and remains valid after font teardown. The proven
placement profile is LTR; other directions return typed unsupportedRun.

All six required host cases executed against the existing oracle, with the
unchanged 0.5 CSS px B gate and shared D3/D4/D7 helpers. Painting uses HB OT
unhinted outlines consistently; no GDI candidate or per-case switch is adopted.

| Case | B maximum CSS px | D4 under D7 | Components native/reference |
| --- | ---: | --- | --- |
| svg-text-positive | 0.000115495404 | pass | 7/7 |
| svg-text-boundary | 0.000115495404 | pass | 7/7 |
| svg-text-nested | 0.000115495404 | FAIL | 7/9 |
| svg-text-path-none | 0.000115495404 | pass | 4/4 |
| svg-text-path-spacing | 0.000484397841 | FAIL | 7/8 |
| svg-text-path-spacingAndGlyphs | 0.000471644710 | FAIL | 7/8 |

Every case passes zero interior mismatch, edge neighbourhood, support bounds
and exact samples. The remaining failures are component topology. Geometry
tests record raster results without treating their own successful exit as
svg-text fidelity acceptance. The required svg-text row remains open.

HarfBuzzResources uses the injected scene policy before native object/malloc,
copied shaping output, traversal and Path allocation. Outlines are first
counted through synchronous callbacks, then fully reserved before Path creation;
the emission pass cannot exceed the count reservation. Transformed copies are
reserved while original paths remain charged. All module live counters and
scene used counters finish at zero, with created == destroyed, including
partial failure, native glyph refusal, cancellation, and repeated dispose.
Tests also prove replacement refusal leaves the old font charged/usable,
motion guards prevent mutation, explicit features preserve oracle advances,
and later placements create no buffers. A canceled registration waiter keeps
its started registration charged through physical completion; success remains
permanently charged. The main fixture process owner retains one registered
171,676-byte face after module teardown. DLLs, HB interned languages/caches,
allocator overhead, Path backing/GPU and RSS remain outside these logical
payload measurements. Native HB preallocation is not a hard allocator cap.

Validation from repository root, using direct installed SDK entry points:
- `dart.exe format --output=none --set-exit-if-changed
  lib/features/reader/engine/text/harfbuzz
  test/features/reader/engine/text/harfbuzz`: exit 0, 14 files, zero changes.
- `dart.exe analyze` on those same two owned directories: exit 0, no issues.
- `dart.exe flutter_tools.snapshot test
  test/features/reader/engine/text/harfbuzz/harfbuzz_test.dart --no-pub
  --reporter expanded`: exit 0, 17 passed, zero skipped on this Windows host.
- Git Bash `bash -n tool/ci/build_harfbuzz_ios.sh`: exit 0 (syntax only).
  Embedded Python compile and owned-file whitespace checks: exit 0.
Initial module analysis caught one test Matcher return-type error and an unused
import, fixed within ownership. The first test run caught two test-only
assertions (UTF16 literal length and MapEntry identity comparison), corrected
without altering expected fixtures. No cross-owner compile failure occurred.

The iOS draft fails before download while the SHA-256 TODO remains. It proposes
one source prefix map for C/private/C++ namespace identifiers, static arm64
device plus arm64/x86_64 simulator archives, and a static XCFramework. Audits
reject unprefixed HB names and unexpected non-prefixed globals. CMake option
drift, generated symbols and compiler helpers fail closed for approved-toolchain
review. The packaging document records link retention/exports, final Runner
link-map/runtime checks, Podfile/Xcode integration, full Old MIT LicenseRegistry
notice handoff, binary-size comparison method and device/allocator risks.
No iOS build, script execution, workflow wiring, network access or git mutation
was performed. Only shell syntax and embedded Python compilation were checked.

Requests:
- A2-svg: call shape/place in preparation after font/style resolution, pass
  flattened authored character positions and correct child textLength scope,
  retain placed Paths, map run ranges to original source nodes, and attach
  nested/page transforms once plus actual clip/mask/opacity/paint evidence.
  Keep default layout membership and refined paint membership explicit.
- A3: supply the same canonical admitted face/index, immutable encoded-font
  lease, shared process owner and font-registration drain barrier. Account
  direct module charges once or provide an admitted prepaid subledger, with
  original/placed and old/new overlap. Do not create a new unit/process budget.
- Main/native owner: approve and pin the official source tarball hash/download,
  toolchain/architecture set and reviewed prefix audit; integrate static
  framework retention/exports and S4c licence assets in their owned files later.
- A2 segment 4/main: keep all three measured module D4 topology failures open;
  this module does not replace that owner's ongoing raster-rule investigation.

Stopped after segment 7a. Host module/API tests pass; SVG scene integration,
full-row fidelity, actual Apple build/symbol/runtime evidence and device
resource/performance acceptance are not claimed complete.

## A4

### A4 segment 1: zero-loss sizing and A5 device runbook (2026-10-28)

Delivered the per-repeat capture budget and lossless packed event storage,
independent versioned analyzer gate, native capacity adapter, and draft
`research/a5-device-runbook.md`. This is the assigned A4 slice, not whole-A4
integration, A5 device acceptance or closure of the parent's seven conditions.

Measurement: existing sparse export fixtures have 37 events/four acceptances
(9.25/turn) or 517/100 (5.17/turn), with only six motion samples. Extended the
existing recognized-demand fake timelines with the real six dirty-frame
events, cold barriers, held/reverse input and proven committed destinations:
50-frame warm/reverse = 310 events/turn, cold = 315, held = 410. Original
40400-event/16384-capacity pressure test is unchanged and still reports
24016 lost; it remains evidence of loss accounting, not zero loss.

Design: fixed 786432-row event buffer with ten int64 columns, one float64 and
two uint8 columns; exactly 70778880 numeric bytes (67.5 MiB), plus 6 MiB of
digest reference slots at 8 bytes/reference, array headers and actual digest
strings. All old fields, full timestamps, identities, destinations, sequence,
offsets and preparation cache facts survive. Motion appends construct no event
Map, do no JSON/I/O/reduction and schedule no tasks. Immutable lazy snapshots
are sealed after stop and survive reset/disposal; explicit mid-capture
inspection copies only live rows without affecting subsequent writes.

Envelope: 10 minutes at 120 Hz + 1.2 s drain = 72144 frame samples, up to
4096 turns; 8 events/frame + 24 control events/turn = 675456, leaving 110976
event slots. Auxiliary rings stay 16384 each; reader engine rings rise from
65536 to 131072 each. Each repeat stops/drains/exports/resets independently.
Native 262144 holds 216432 samples at three/frame across the envelope.
Contention and unmatched native callbacks remain losses, not excused by sizing.
Outside-envelope/unbounded inputs are not covered by the sizing guarantee.

Schema v1 remains unchanged. New engine.metadata.readerCaptureBudget.version=1
and presentation.inventory.captureBudgetVersion=1 declare capabilities. The
CLI independently checks configuration, raw bounds/sequence and all losses;
unknown versions are rejected. Legacy files remain readable and cannot pass
the new long-capacity gate. New capacity does not claim complete trailing
delivery, three observed repeats, physical presentation or scenario completion.

Zero-loss proofs: 100 alternating accepted turns x three repeats, 33625 events,
5000 engine/motion and 10000 native model samples each; all six overflow counts
zero, serialized/decoded independent aggregates match, warm/stall/correctness/
native-loss/capacity gates pass. Snapshots keep their original epoch across
repeats. R06 stress: 3000 turns, 72000 frames/motion over 599.976 s, 462000
events, 144000 native model samples and 3001 resources; all counts retained,
zero loss, valid independent analysis and serialized full-field export. Native
is explicitly a host capacity model, not an executed Swift buffer/race proof.
Another test appends all 675456 envelope rows without materialization/loss.
Zone guards reject timers/microtasks during motion; source guards prevent
map/storage/async work in numeric append and blocking/channel/export work in
native callbacks. Existing small-capacity and native-loss tests still pass.

Wire bytes: repeats 7902145 / 7912748 / 7965378; R06 114884822 (109.56 MiB).
Focused Windows R06 RSS before stop 233029632, after finalization 245641216;
high-water mark with offline analysis/full JSON serialization 686444544
(654.64 MiB). This includes host VM/test baseline and lazy native modeling.
Packed event storage is 73.5 MiB plus strings/headers; expected arm64 native
entries+lookup 16 MiB (stride 56, CI confirmation pending). Engine/Map/VM/GPU
overhead and prior-repeat overlap remain explicit. Estimated retained diagnostic
payload is roughly 128 MiB plus app baseline; this is not a hard RSS ceiling or
an iPhone memory pass. Stop/export peak must be measured separately on device.

Changed Dart files: data/reader_capture_budget.dart, reader_event_buffer.dart,
reader_probe_recorder.dart, presentation_payload.dart, reader_export_repository.dart;
presentation/reader_probe/reader_probe_screen.dart; tool/diag/reader_capture_analysis.dart,
reader_export_analysis.dart; diagnostics data tests reader_capture_fixture.dart,
reader_capture_volume_test.dart, reader_event_buffer_test.dart,
method_channel_presentation_probe_test.dart; test/tool/diag/reader_capture_analysis_test.dart.
Also changed ios/Runner/AppDelegate.swift (capacity/comment + inventory version)
and added the A5 runbook. Swift: **CI-compile pending**, together with A0's
unchanged atomic bridging-header/C changes. No native compilation is claimed.

Validation used installed dart.exe / flutter_tools.snapshot directly:
- format --output=none --set-exit-if-changed <13 changed Dart files>: exit 0,
  zero changes; analyze <same 13>: exit 0, no issues.
- flutter_tools.snapshot test test/features/diagnostics test/tool/diag
  --no-pub --reporter expanded: exit 0, 246 passed (before the two additional
  packed-buffer unit tests). Original loss-accounting and legacy/CLI tests pass.
- test reader_capture_volume_test.dart reader_event_buffer_test.dart with
  --no-pub --reporter expanded: exit 0, 6 passed. After adding full R06 JSON
  sizing and the Dart append source guard, reran only reader_capture_volume_test.dart:
  exit 0, 4 passed. No other-owner compile failure occurred.
- Scoped git diff --check: exit 0. Python owned-file whitespace/link review:
  exit 0, 16 files, four runbook references resolve, unique A4 heading.
  Initial analysis infos were fixed inside ownership before final checks.

Runbook: existing free Windows/hosted macOS/全能签 iPhone route, exact artifact/
identity review, A-AC1..8 matrix, three independent repeats, >=100 alternating
turns, full R06, real OS return, unchanged gates, versioned private evidence
schema, A1/A2 observer distinction, and paired Safari fallback emoji/D8 text
raster/D3 re-verification. It names owner push/build approval, signing,
installation, actual phone/Safari operation and private evidence transfer.

Requests/open: main owner should synchronize diagnostics.md and
reader-admission-diagnostics.md's old capacities with this versioned contract;
those specs are outside this slice's write scope. Actual A1-A3 probe integration,
all required fidelity rows, owner-approved hosted Swift/C compilation, native
contention/ABI/runtime, device capture/export/overlap memory, real interruption
and paired Safari evidence remain open. No host result closes those gates.
No new dependency, download/network, reader/library edit, generated/expected
fixture edit, codegen/full-suite/broad format, sub-agent or git mutation occurred.
Stopped after A4 segment 1; no A5 build/device step was attempted.

### A4 segment 2 (2026-10-29)

Connected prepared publications to the fixed/mixed reading path. The loader is
production code, not a test wrapper: it takes the route `PreparedBook` before
release, opens the existing `ReaderPublicationLifetime` (independent file/worker
pin plus the shared preparation queue), and opens one root `EpubBook` from the
same immutable path only for the existing `CssStyleResolver`. Section
`SourceDocument` and encoded resources come from the existing worker
`preloadSection`; there is no second parser, cascade or resource graph.

Files changed:
- new `lib/features/reader/engine/surface/publication_fixed_sources.dart`:
  `PublicationFixedSources.open`/`unitSources`; fixed-profile
  `CssStyledDocument` with the authored viewport; validated `SectionRendition`
  from import facts (fallback `sectionRendition`); one `FixedSourceLease` per
  source; worker cancel/stale/closed mapped to `PreparationCancelled`.
- new `lib/features/reader/engine/surface/publication_fixed_composition.dart`:
  real reflow `SectionPreparer` for reflow sections, authored dimensions for
  fixed ones, `ReadingUnitSection` with rendition/direction facts,
  `ComposedReadingUnitNavigator`, `PageAnchors.locate`, and the shared
  `fixedSectionLayout` identity. Failures publish no unit.
- modified `lib/features/diagnostics/presentation/reader_probe/reader_probe_controller.dart`:
  `openPublication` opens fixed/mixed through `PreparedReaderSession.openUnit`
  with `fixedSources`; reflow-only publications return false and keep the old
  probe path; mixed sessions that begin on a reflow page keep that page on the
  reflow path.
- new tests `publication_fixed_test_support.dart`, `publication_fixed_sources_test.dart`,
  `publication_fixed_session_test.dart`, `publication_fixed_lifecycle_test.dart`,
  `private_publication_regression_test.dart`, and
  `test/features/diagnostics/presentation/reader_probe_publication_test.dart`.

Image routing: raw CSS `background-image` URLs and SVG `<image>` `href` values
are matched to the worker plan's `PublicationResourceReference` (then section
resolved), inspected with `ui.ImageDescriptor` before decode, and admitted
through `fixedImageRequest`. Keys stay exactly the raw values consumed by the
scene and SVG modules, so missing local raster targets remain missing and the
module refuses them. A test covers both a background key and a distinct
`./page.png` SVG `<image>` key resolving to the same encoded bytes.

Lifecycle: source leases release exactly once; `disposeBook` is a single future;
`close` cancels the lifetime, drains a pending worker preload through the
`disposeScenesAndSources` barrier, closes the root book once, then releases the
file/worker pin. Tests cover retired activation, close during a paused worker
preload, and idempotent source release. Mixed sessions opened on a reflow page
do not receive the lifetime because `PreparedReaderSession.open` requires
`section.identity == publication.layout`; the probe owns that close instead
(see Requests).

Validation (direct SDK; tests via `flutter_tools.snapshot --no-pub`):
- `dart analyze` on the 3 production and 6 new test files: exit 0, no issues.
- `dart format --output=none --set-exit-if-changed` on those files: exit 1,
  eight files changed; after `dart format` the same check is exit 0.
- New tests together: exit 0, 11 passed.
- Required suites `test/features/reader/engine/surface`,
  `test/features/diagnostics`, `test/features/library`: exit 0, 726 passed.
- Private regression: exit 0, 1 test; report written to ignored
  `build/a4-private-regression/report.json` with counts only.

Private regression counts (anonymous): 4 books, 60 sections, 1537 reflow units,
0 fixed units, 0 blank slots, 0 prepared fixed units, 0 typed outcomes, 0
import/composition failures; peak/retained resource counters all 0 because the
private books contain no fixed pages. The four private books were read in place;
no name, path, text, CFI or image entered the report.

Requests/open issues:
- A3 seam: `PreparedReaderSession.open` rejects a mixed session whose initial
  unit is reflow when the lifetime layout is a fixed-section identity. The probe
  currently passes `publication: null` for those openings and closes the source
  owner itself. Request a mixed-aware lifetime/layout validation so one
  publication lifetime can cover a mixed session opened on either path.
- A2/A3: CSS background URLs are resolved by matching the raw declaration value
  against the section's reference inventory. Two stylesheets using the same
  relative URL with different bases can be ambiguous; a resolved path or base on
  `AuthoredStyle` would remove the guess.
- A2/A3: `ui.ImageDescriptor` inspection on the root accepts raster targets only.
  Vector `<image>` targets and SVG filters/masks/foreignObject/text continue to
  return the module's typed unsupported/failed preparation; no partial page.
- Main/library route: the probe screen still lists local `ProbeBook` entries and
  has no `PreparedBook` source, so it does not call `openPublication` yet. The
  controller entry point and tests are ready; product route wiring remains.
- Probe settings reflow and section `jump` are no-ops while a fixed session is
  active; recomposition must build a fresh composition/pool (A3's shared owners)
  rather than fall back to the reflow-only probe path.

#### Segment 2b (2026-10-29)

Closed the four wiring requests. No fixed/geometry/layout/tool/fixture/spec
changes; no codegen, dependency or network.

1. Direction admission: `PublicationFixedComposition` already populated
   `ReadingUnitSection.directionIssues` from `SectionLayoutFacts.directionIssues(
   pageProgressionDirection: facts.pageProgressionDirection)`. It now catches
   `UnsupportedDirectionCompositionException` from A1's composer and raises
   `FixedPreparationFailure(UnsupportedSectionCapability(...))` with
   `direction:<issue>` constructs before any pool/session exists. A synthetic
   RTL progression test asserts the typed failure and zero pool owners. No
   composer mapping hook was needed.

2. Mixed lifetime: `PreparedReaderSession` gained `_samePublicationLayout`,
   which compares content identity, layout generation, viewport, DPR, settings
   and style version, but not section index or font signature. Both `open` and
   `openUnit` use it. The probe and test support now always pass the publication
   lifetime for fixed/mixed sessions; the reflow-start workaround is removed.
   The mixed reflow-start session test and existing stale/exactly-once surface
   tests pass.

3. CSS background bases: `css_stylesheet.dart` resolves local `background-image`
   URLs when declarations are built, against the declaring stylesheet for linked
   rules, `@import` sheets and `<style>` blocks, and against the section path for
   inline `style` attributes. External/data/fragment URLs stay raw.
   `AuthoredStyle.backgroundImage` is therefore already an archive path; the
   fixed loader keys CSS backgrounds by that path and still keys SVG `<image>`
   by its raw href. New style test covers `.a` and `.b` linked stylesheets using
   the same relative `tile.png` from different directories, plus an inline
   declaration. Fixed image/source tests pass with the resolved key.

4. Probe S3 route: `ReaderProbeScreen` now accepts a `bookKey` mapper and a
   test-injectable preparation callback. `prepareProbeBook` obtains a
   `PreparedBook` through `PrepareBookService.prepare`; the default
   `_prepareFromServer` resolves the selected server session and calls that
   service. `_open` then calls `openPublication`; reflow-only publications fall
   back to the existing reflow probe path using the prepared immutable file.
   Typed `FixedPreparationFailure`, `PrepareBookException` and silent
   cancellation are surfaced with the existing probe messages. New diagnostics
   test prepares a server-backed fixed book through S3 and opens the session.

Validation (direct SDK; tests via `flutter_tools.snapshot --no-pub`):
- Scoped `dart analyze` on 7 production + 5 test files: exit 0, no issues.
- Scoped `dart format --output=none --set-exit-if-changed`: exit 0, 0 changed.
- Focused new/relevant tests (background base, fixed sources/session/lifecycle,
  probe S3 route, probe fixed publication): exit 0, 13 passed.
- Required suites `test/features/reader/engine/surface`,
  `test/features/diagnostics`, `test/features/library`,
  `test/features/reader/engine/style`,
  `test/features/reader/engine/pagination` (including the private regression):
  exit 0, 999 passed, 2 pre-existing optional skips.
- Private regression report remains 4 books / 60 sections / 1537 reflow units /
  0 fixed units; typed outcomes and resource peaks remain 0 because no private
  book contains a fixed page.

Requests/open:
- The probe inventory still lists local assets/Documents books only; the screen's
  `bookKey` mapper is wired, but the product/library screen must supply the
  server-backed inventory. Reflow-only server books reuse the prepared file,
  never a second download.
- CSS background images support one URL per declaration; multi-layer
  `background-image` lists and shorthand-layer semantics remain outside the
  supported cascade.
- Vector SVG `<image>` and SVG text/filter/mask/foreignObject remain typed
  unsupported/failed; root `ui.ImageDescriptor` admits raster targets only.
- Probe settings reflow/jump on a fixed session remain no-ops pending
  recomposition wiring.

## A2-svg

### A2-svg segment 5 (2026-10-29)

Closed the production SVG graphics segment at the checkpoint `4f52269` plus
this work. No commit, push, stash or ACL change was made.

Files delivered by the segment: `lib/features/reader/engine/fixed/svg/`
`svg_graphics.dart`, `svg_graphics_dash.dart`, `svg_graphics_geometry.dart`,
`svg_graphics_markers.dart`, `svg_graphics_patterns.dart`,
`svg_graphics_plan.dart`, `svg_graphics_prepare.dart`,
`svg_graphics_shapes.dart`, `svg_graphics_tree.dart`,
`svg_graphics_validation.dart`, `svg_graphics_values.dart`,
`svg_path_bounds.dart`, `svg_presentation.dart`; plus
`fixed_scene_svg.dart` and `fixed_svg_viewport.dart`. Proof:
`tool/reader/fixed_layout_svg_harness.dart`,
`test/tool/reader/fixed_layout_svg_test.dart`,
`test/features/reader/engine/fixed/svg/svg_graphics_test.dart`, and
`tool/oracle/src/fixed-layout-svg-graphics.mjs`. The svg-graphics records in
`corpus.json`/`oracle.json` were regenerated by the generator; no expected data
was hand-edited.

Reuse and source identity: `vector_graphics_compiler` normalizes path commands
and compiles only one identified leaf's markup (`_leafMarkup` ->
`vc.encodeSvg`); `flutter_svg`'s `vg.loadPicture` loads those bytes through the
per-leaf `_SvgBytes` loader, so no process-global compilation cache outlives the
scene reservation. Patterns and dash masks are the only composed pictures.
Whole-tree order, references, clips, opacity groups and
`nodeIndex`/`instancePath` come from `SvgGraphicsPlan` walking the
`SourceDocument`; the compiled picture is paint storage, never the source map.
`path_parsing` supplies authored segment boundaries, so an arc expanded to
several cubics still contributes one marker vertex. `FixedSvgViewport` is
shared by the fixed scene and the SVG plan. The harness re-proves source
identity (tag/id order, one element per non-definition SVG node, CFI round-trip)
and source geometry completeness.

D3 fix: the SVG harness no longer intersects `SpikeReferenceDefects.scope()`
with the registry's case lists. It passes `scope.$1` directly to
`compareSpikePixels` and retains `scope.$2` unchanged, exactly as the scene
harness does. RD-1 is eligible only at (0,0); positive and boundary each exempt
one pixel, nested none. The unsupported case records explicit `unmeasured`
RD-1/RD-2 decisions. The report now verifies `oracle.corpusSHA256` and records
the corpus, oracle, reference-defect registry and paint-control hashes.

Marker finding: added a 14-instance test over two open subpaths plus a closed
triangle and an arc subpath. It asserts start/mid/end at every authored vertex,
no mid marker at a subpath start, marker-end at the closepath point, and only
the arc endpoint as a vertex. The arc endpoint error is 1.94e-6 px (asserted at
1e-3 px). The existing arc test still passes; no production marker change was
needed. A move-only subpath still forms a one-vertex contour and is not covered
by the corpus.

Oracle determinism: corpus
`bca95cf36e9ef381fb5532d7d46c3ae6bb7e9ca54e638a0453267d307049e239`;
oracle
`1a13eb31ce69d198ecd068c2360ef46e5adaeb7faaa70c8b3e27733a51abd48f`.
`npm run fixed-corpus` was run twice and `npm run fixed-oracle` twice; both
pairs were byte-identical to each other and to HEAD (`git diff` empty, SHA-256
equal); therefore all 52 oracle cases, including the 48 non-svg-graphics
records, are byte-identical and no protected record changed.
`npm run check-fixed-corpus` and `npm run fixed-oracle -- --check` exit 0.
Reference checkout is the clean pinned `a4bda23`; WebKit 27.2, Chromium
156.0.8078.4, node v24.19.0.

Verdicts (0.5 CSS px geometry gate, D7 components at alpha >= 32; D8 text mask
is not applicable to this row):
- positive PASS. Geometry 26 comparisons, max 0 px; D4 interior, edge,
  support [4,4,200,161] on both, 9 components on both and samples all pass.
  541 changed pixels, 1 RD-1 exemption, sample delta 0.
- boundary FAIL. Geometry 32 comparisons, max 1.4085e-05 px; D4 interior,
  edge, support [4,4,231,221] on both and 17 components on both pass. Samples
  fail at (10,10): native RGBA 204,0,50,255 vs reference 205,0,50,255 (delta 1)
  on the reflected userSpaceOnUse gradient. 854 changed, 1 RD-1 exemption.
- nested PASS. Geometry 30 comparisons, max 0 px; all D4 sub-rules pass.
  527 changed pixels, no exemption.
- unsupported PASS as a typed refusal: `UnsupportedSectionCapability`,
  construct `svg-filter`, picture null, zero fragments/paint, required=false.
  No partial scene is published.

Resource reservation peaks: positive sourceNodes 55, sourceBytes 6792,
vectorBytes 8474336, vectorOperations 2659, layerPixels 614400, layerBytes
2457600, gradientStops 18, references 60; boundary 73, 12268, 9915296, 4683,
614400, 2457600, 22, 65; nested 57, 7234, 8631104, 2734, 691200, 2764800, 18,
60. The ledger returns to zero after every case and the harness throws on a
leak.

Validation (direct SDK): `dart test test/tool/reader
test/features/reader/data/epub/fixed_layout_corpus_test.dart
test/features/reader/engine/fixed/svg/svg_graphics_test.dart --no-pub
--reporter expanded` exit 0, 83 passed; `dart format
--output=none --set-exit-if-changed` on the changed harness/test exit 0;
`dart analyze` on the same files exit 0. The DSH workspace-write confinement
still denies every shell write, so write-bearing commands ran under one-shot
full access; no ACL change was made.

Integration hook A2 needs in `fixed_scene.dart` (not changed here):
import `svg_graphics.dart`; add `SvgGraphicsScene? svgScene` to `FixedBox` and
own a `List<SvgGraphicsScene>` in `FixedScene`/`FixedSceneBuilder` disposed
exactly once. In `_layoutSvg`, keep the `FixedSvgViewport`/dimension gate, then
replace the rect-only loop with
`SvgGraphicsPlan.inspect(document: document, rootIndex: index, page: page,
size: size, resolvedPresentation: ..., placement:
_translation(flow.dx, flow.dy).compose(viewport.transform!))`. Because `_layout`
is synchronous, record the plans and `await plan.prepare(budget: budget,
images: SvgGraphicsImages(...), cancellation: cancellation)` in
`FixedSceneBuilder.build()` before `_transforms`/`_paintContext`; merge
`scene.geometry.fragments/clips/paint/opacityGroups` and draw
`scene.picture` under the box clip/transform. The blockers are the CSS
projection (`SvgGraphicsPlan` needs resolved SVG presentation strings while
`CssStyledDocument` exposes typed `ComputedStyle`/`AuthoredStyle`) and the
section preparer's admitted raster/vector image map for `<image>` resources.

Open: boundary gradient sample delta 1 keeps the svg-graphics row at FAIL; no
gate was weakened. Move-only subpaths and mixed zero-length subpaths are not
covered by the corpus or the marker reference counts. Per-leaf `vc.encodeSvg`
is a leaf compiler, not a whole-SVG source proof. A5 device raster parity
remains device-gated, and the CSS projection and admitted-image map above are
the remaining production integration work. The worktree also carries concurrent
main-session edits to `execution-log.md` and two diagnostics specs; they were
not touched here.

## A2-mixed

### A2 segment 8 (2026-10-29)

Added `tool/reader/fixed_layout_mixed_harness.dart` and
`test/tool/reader/fixed_layout_mixed_test.dart`. The harness runs all four
`mixed-navigation` corpus variants through `EpubBook`/`importLayoutFacts`,
`sectionRendition`, `resolveAuthoredDimensions`, real single-page reflow
preparation, `ReadingUnitComposer` and `ComposedReadingUnitNavigator`; it writes
`build/fixed-layout-mixed/report.json`. The initial segment and review-fix
passes were superseded by the RTL admission work below. The test reuses
`FixedSessionFixture` and `unitSection`, and treats the report's
`execution.completed` as independent of `rowVerdict`; injecting a failed check
into a deep copy makes `mixedRowVerdictFor` return `fail`.

| Variant | Outcome | a | b | c | d | e |
| --- | --- | --- | --- | --- | --- | --- |
| mixed-navigation-positive | 5 units / 6 sources | pass | pass | pass | pass | pass |
| mixed-navigation-boundary | 6 single units / 6 sources | pass | pass | pass | pass | pass |
| mixed-navigation-nested | 5 units / 6 sources | pass | pass | pass | pass | pass |
| mixed-navigation-unsupported | typed refusal; 0 units | n/a | n/a | n/a | n/a | pass |

Final row verdict is **pass**, 0 failed checks after the RTL admission below.
Check a verifies filtered spine source order, original spine order, no
mixed-mode unit, and a synthetic padded-spread blank probe (a blank slot is
`BlankSourcePageSlot`; it carries no source/CFI geometry). Check b compares
every fixed-source `(unit index, side)` with `referenceSpreadSlots` exactly.
Check c covers forward `0,1,2,5` / reverse `5,3,1,0` for positive and nested,
forward `0,1,2,3,5` / reverse `5,3,2,1,0` for boundary, both reflow-to-fixed
crossings, six TOC fragment targets, explicit nonlinear source 4, same-spread
activation on the `[p2,p3]` unit, and portrait (6 one-page units; single-page
reflow reused). Check d round-trips every source's element and text CFI with
`Cfi.export`/`Cfi.resolveLocal` (6/6). Check e reads
`SectionDirectionIssue.rtlProgression`/`rtlDirection` from the real import
facts, feeds them through `ReadingUnitSection.directionIssues`, and receives
`UnsupportedDirectionCompositionException` with 0 units.

Named differences (requirement-traced, not silent passes): positive and nested
sources 0 and 5 are centered reflow units in native, while the all-fixed
reference assigns source 0 to `unit 0/right` and source 5 to `unit 4/left`.
The reference's implied blank left slot in unit 0 and blank right slot in unit 4
are absent natively; check b records both implied blanks with no source. This
cites `research/rendering-plan.md` section 3 row "Mixed navigation" and the
corpus criterion; all fixed slots still match. Boundary reflow sources are
recorded in check b as centered with `sideChanged=false`, so they are traced
but not claimed as a difference. The unsupported variant is recorded as a typed
unsupported difference from the all-fixed reference.

Validation (direct `dart.exe`; tests via `flutter_tools.snapshot`, `--no-pub`):
- `format --output=none --set-exit-if-changed <two new Dart files>`: exit 0,
  0 changed.
- `analyze <two new Dart files>`: exit 0, no issues.
- `test test/tool/reader/fixed_layout_mixed_test.dart
  test/features/reader/engine/pagination test/features/reader/data/layout
  test/features/reader/engine/surface/fixed_session_integration_test.dart
  --reporter expanded`: exit 0, 144 passed, 2 pre-existing optional skips
  (native CFI export and pre-seam baseline).
- Initial report: `build/fixed-layout-mixed/report.json`, row verdict `pass`;
  corpus/oracle hashes `bca95c...` / `1a13eb...`, oracle `corpusSHA256` matches.
  The RTL admission below restores the pass after the review-fix fail.

Sandbox note: confined writes under `D:\Projects\shiori\tool`, `test` and
`build` were denied by Windows permissions, and the confined analyzer could not
start. The bundled ACL diagnostic found no package ACE and returned
`PRECONDITION`/refused at `tool` because the signed-in user lacks `WRITE_DAC`
(the folder owner is SID `...-1003`). No ACL change was made. The scoped
format/analyze/test commands above were rerun with approved full access; this is
an environment limitation, not a code result.

Requests:
- A3/main: populate `ReadingUnitSection.directionIssues` from the real
  `SectionLayoutFacts` when production composition inputs are built, and map
  `UnsupportedDirectionCompositionException` to the typed preparation failure
  before opening a pool/session. The composer/navigator refusal is implemented
  below; only the production input wiring remains.
- Oracle owner: A1's recorded corpus/oracle hashes are stale; the current pair
  is internally consistent and was used unchanged. No fixture/oracle edit was
  made here.

Open issues: this is a host composition/navigation verdict only. It does not
close fixed-scene fidelity, device raster/geometry, session integration of the
unsupported gate, or production navigation wiring. Portrait recomposition uses
the same single-page reflow sections (asserted page count 1), not a repagination
stress case.

#### Review fixes (2026-10-29)

At review time check e no longer bypassed composition: the unsupported fixture
ran the same `FixedSessionFixture.prepareNavigation()` rendition/reflow/
composer/navigator path with the real `importLayoutFacts` issues
(`rtlDirection`, `rtlProgression`). It yielded 5 candidate units, so check e
failed and the row failed on `mixed-navigation-unsupported:e`. The missing
boundary was a typed direction admission check before `ReadingUnitComposer`/
`ComposedReadingUnitNavigator`. This is historical; the RTL admission
subsection below implements that boundary and restores check e to pass. A
test-only `refused` seam was the positive control.

Check c now asserts direction-specific active sources at every step, not only
unit IDs: positive/nested forward `[0,1,2,5]`, reverse `[5,3,1,0]`; boundary
forward `[0,1,2,3,5]`, reverse `[5,3,2,1,0]`. The rule comes from
`fixed-layout.js:166-180` (`showSpread` side and blank handling), `:246-250`
(index uses the active side), `:265-269` (same-spread `render(side)`), and
`:300-307` (`next` passes left, `prev` right for LTR). The same-spread TOC
`[p2,p3]` check now also asserts active sources `[2,3]` and unchanged slots.

Negative tests use harness seams only. Replacing the reverse spread entry's
active source with p2 while retaining the unit ID yields reverse sources
`[5,2,1,0]`; check c and the row fail. Injecting an accepted unsupported
outcome makes check e and the row fail; a test-only refused seam is the positive
control (row pass) used to demonstrate both transitions.

At review time, `format --output=none --set-exit-if-changed` on the two files
exited 0 with 0 changed; scoped `analyze` exited 0 with no issues; the new test
plus `test/features/reader/engine/pagination` exited 0, 111 passed, 2
pre-existing optional skips. No production file was changed then. The RTL
admission below supersedes this with a real composer/navigator refusal.

#### RTL admission (2026-10-29)

Refusal point: `ReadingUnitSection.directionIssues` now carries the typed
`SectionDirectionIssue` values from `PublicationLayoutFacts`. After the existing
metadata/identity validation and before any physical/portrait unit is built,
`ReadingUnitComposer.plan` throws `UnsupportedDirectionCompositionException`,
a `UnitCompositionException` subclass exposing the offending issue set.
`ComposedReadingUnitNavigator` composes through that method, so a refused
publication has no navigator to open a session with. LTR/absent direction is
unchanged; malformed metadata and missing dimensions keep their existing base
exception and are not mislabeled as direction failures.

Regression tests cover `rtlProgression`, `rtlDirection` and
`verticalWritingMode` in composer plan/compose and navigator construction, plus
LTR composition, metadata precedence, and a missing-dimension base refusal. New
`test/features/reader/engine/surface/unsupported_direction_admission_test.dart`
builds the unsupported fixture from real import facts, proves navigator
construction throws with both issues, and proves `PageSurfacePool.owners == 0`;
no session or publication is entered.

The mixed harness now builds the unsupported sections with the real per-section
direction issues and constructs the real navigator. Check e passes with
`refused`, 0 units produced/published, issues `rtlDirection, rtlProgression`,
boundary `ReadingUnitComposer.plan -> UnsupportedDirectionCompositionException`;
the row verdict is **pass**, 0 failed checks. This supersedes the review-fix
fail.

Validation: changed files formatted with `--set-exit-if-changed` (exit 0, 0
changed) and scoped `analyze` (exit 0, no issues). The mixed harness plus
`engine/pagination`, `data/layout` and `engine/surface` exited 0: 216 passed,
2 pre-existing optional skips. The focused admission/harness run exited 0 with
22 passed. No A3 production file was edited.

Request: when A3/main wires production composition inputs, populate
`ReadingUnitSection.directionIssues` from
`SectionLayoutFacts.directionIssues(pageProgressionDirection: facts.pageProgressionDirection)`
and map `UnsupportedDirectionCompositionException` to the typed preparation
failure before opening a pool/session. No session path is reachable without the
refused navigator; that production construction site is the remaining wiring.

## A2-svg-fix

### Review fixes (2026-10-29)

Verified all four Codex findings and fixed them in the SVG part files. No
A2-owned seam, harness, fixture, expected data, spec or pubspec changed.

1. Confirmed. `svg_presentation.dart` ignored `transform` and unknown rendering
   declarations. Added `transform` to resolved presentation; the transform
   parser now accepts CSS lengths/angles (`translate(40px,0px)`, `deg/rad/grad/
   turn`, `translateX/Y`, `scaleX/Y`, `skew`) plus the existing SVG syntax.
   Unsupported rendering declarations (`clip-path`, `mask`, `transform-origin`,
   `paint-order`, `vector-effect`, ...) now produce
   `UnsupportedSectionCapability` for the whole section. While verifying this,
   found and fixed a related extraction defect: csslib `expression.span` stops
   at the first token, so `url(...)`/function values were stored truncated; the
   authored declaration text is now preserved. Tests: "CSS transform
   declarations are applied, not silently dropped" and "unsupported CSS
   rendering declarations refuse the whole section".

2. Confirmed. `_xml` copied definitions with only their own attributes, so
   `<defs color="red">` plus `stop-color="currentColor"` compiled black. Detached
   resource markup now merges inherited presentation from the original ancestor
   chain (`_svgPaint` plus `stop-color`/`stop-opacity`), follows paint servers
   introduced by that inheritance, and resolves a stop's `currentColor` from its
   inherited `color` because the installed compiler only reads currentColor from
   the root theme. Pattern content is seeded from the same ancestor paint. Tests:
   "gradient stops resolve inherited currentColor from ancestors"; existing
   gradient/pattern tests still pass. Sources are resolved from attributes/CSS
   per SVG 2 paint-server inheritance; no fixture/oracle change was needed.

3. Confirmed. A horizontal line's zero-height fill bounds suppressed a valid
   `userSpaceOnUse` patterned stroke. Visibility now comes from stroked bounds
   for strokes; an `objectBoundingBox` paint server on a zero-width/height box
   is still not rendered. Tests: "userSpaceOnUse pattern strokes paint a
   zero-height line" and "objectBoundingBox pattern on zero-height geometry is
   not rendered".

4. Confirmed. Zero-length painted dashes were skipped. `_dashPath` now emits a
   sub-pixel tangent-aligned segment for each zero-length on-dash when the cap
   is round or square, so the existing stroke paint emits the SVG 2 cap
   dot/square; butt caps stay invisible. Test: "zero-length dashes paint round
   and square caps only". Spec: SVG 2 painting, stroke shape / zero-length
   subpaths; no oracle fixture change.

Files: `svg_presentation.dart`, `svg_graphics_values.dart`,
`svg_graphics_patterns.dart`, `svg_graphics_dash.dart`; new
`test/features/reader/engine/fixed/svg/svg_graphics_semantics_test.dart`.

Validation (direct SDK; tests via `flutter_tools.snapshot`, `--no-pub`), all
exit 0:
- new semantics test: 6 passed.
- `test/features/reader/engine/fixed/svg`: 20 passed.
- `test/tool/reader/fixed_layout_svg_test.dart`: 1 passed.
- `dart format --output=none --set-exit-if-changed` on the five changed Dart
  files: 0 changed.
- `dart analyze` on the same files: no issues.

The confined sandbox still blocks the Flutter runner's piped subprocesses and
the formatter's writes, so those scoped commands ran with approved one-shot full
access; no ACL change was made. No commit, push, stash, sub-agent, dependency,
network, fixture/generator or other-owner edit occurred.

Open issues: none for these four findings. CSS transform origins/boxes and 3-D
transforms are deliberately typed unsupported, not partially applied. Oracle
pixel re-verification of the new dashed-cap and inherited-color cases was not
added because that requires fixture/generator changes outside this slice.

## A2-svg-hooks

### Feature seams (2026-10-29)

Added the internal feature-hook contract and four registered part files without
changing any verdict. The default registry still refuses filters, clipPath/mask,
foreignObject and text with the previous identifiers; no fixture, oracle, spec,
pubspec, tool/reader or test/tool/reader file was edited.

Contract (`lib/features/reader/engine/fixed/svg/svg_feature_hooks.dart`):
`SvgFeature` declares tags/definition tags/attributes/presentation properties,
`presentationRefusal`/`presentationIgnored`, `opaqueChildren`, admission
(including `charge`, `chargeLayers`, `resolveReference`, `addReference`,
`refuse`), an async `prepare` (post-reservation/tree, pre-paint; `reserve`,
`setPicture`/`addPicture`, `onDispose`), a geometry pass (add fragments/paint/
clips/groups, `addClipTo`/`addMaskTo` on existing node evidence, or explicit
`incomplete`), and an outermost-first paint wrapper around `paintDefault`.
`SvgFeatureRegistry` is the single registration point; per-plan state lives in
the preparation/geometry contexts, not on const feature objects.

Call order is: tag admission, attribute/presentation admission and shared
charges in `inspect`; base reservation then tree; feature `prepare` in registry
order; `prepareNode` ordinals/geometry/paint records; feature `geometry`; feature
paint wrappers; scene ownership. `SvgGraphicsScene.dispose` releases picture,
pictures, leases and feature owners exactly once; failure/cancellation release
the same set before returning or throwing. Feature reservations go into the
module lease list; feature layer charges add to `reservation()` before
allocation.

Host: `SvgFeatureHost` carries a `SvgForeignObjectLayoutService` (owned layout
picture/bounds/fragments/clips) and `SvgTextFontService` (admitted
`SvgTextFontAsset` bytes/faces plus a release lease; host owns drain).
`SvgFeatureHost.unavailable()` is const and never allocates.
`FixedSectionPreparer.svgFeatureHost` is the injection point;
`FixedPreparationPlan.inspect` and `SvgGraphicsPlan` carry it;
`_prepareSvgScenes` passes it explicitly. Behavior is unchanged while both
services report `available == false`.

Part ownership: `svg_feature_filters.dart` owns filter/fe* tags and the filter
attribute/property; `svg_feature_clip_mask.dart` owns clipPath/mask tags,
clip-path/mask attributes and CSS presentation refusals;
`svg_feature_foreign_object.dart` owns foreignObject and keeps XHTML opaque;
`svg_feature_text.dart` owns text/tspan/textPath. Shared plan/tree/prepare only
call the contract, so each later owner changes its own part file plus its
assigned tests/harness.

Proof: new `test/features/reader/engine/fixed/svg/svg_feature_hooks_test.dart`
(6 tests) uses a test-only fake feature registered through the registry to
prove admission of a feature-owned attribute, resource/layer reservation
summing, async prepare before paint, nested-group paint enter/exit order,
geometry merge plus clip annotation, and exactly-once dispose on success,
failure and cancellation. It also asserts the unchanged typed identifiers
`svg-filter`, `svg-clipPath`, `svg-mask`, `svg-fe-*`, `svg-foreignObject`,
`svg-text`, `svg-tspan`, `svg-textPath`, `svg-attribute-*` and
`svg-css-clip-path`/`svg-css-mask`, and the unavailable host services.

Files: `svg_graphics.dart` (part lines, host, scene owner disposal),
`svg_feature_hooks.dart` and the four feature part files,
`svg_graphics_plan.dart`, `svg_graphics_tree.dart`,
`svg_graphics_prepare.dart`, `svg_graphics_patterns.dart` (paint call only),
`svg_presentation.dart`, `fixed_preparation_plan.dart`, `fixed_scene_svg.dart`,
`fixed_section_preparer.dart`; new test and contract document
`research/a2-svg-feature-hooks.md`.

Validation (direct SDK; tests via `flutter_tools.snapshot`, `--no-pub`):
- `test/features/reader/engine/fixed`: exit 0, 53 passed.
- `test/tool/reader/fixed_layout_svg_test.dart`: exit 0, 2 passed.
- `test/features/reader/engine/surface`: exit 0, 74 passed.
- scoped `format --output=none --set-exit-if-changed`: exit 0, 0 changed;
  scoped `analyze`: exit 0, no issues.

The confined sandbox still blocks the Flutter runner's piped subprocesses and
the formatter's writes, so those scoped commands used approved one-shot full
access; no ACL change was made. No commit, push, stash, sub-agent, dependency,
network or other-owner edit occurred.

Open issues: the four features are admitted only enough to refuse; no native
filter/clip/mask/text/foreignObject path is implemented. The text host still
needs A3's admitted faces and drain wiring; the foreignObject host needs the
XHTML layout/profile owner. Masks cannot yet publish complete geometry
(`SourceFragment.maskIds` is incomplete-only), so a later mask owner must use
`incomplete(mask, ...)` until that data contract is approved. Pattern content
also uses the feature paint chain; feature-specific pattern content remains
untested.

#### Review round 2 fixes (2026-10-29)

Confirmed and fixed all six second-review findings in the shared module; the
two in-flight feature owners only need the documented completion calls.

1. CSS geometry properties `x/y/width/height/cx/cy/r/rx/ry/d` are now recorded
   from style and behave like the matching attributes (`d` accepts `path("…")`).
   A comprehensive SVG rendering-property set makes every other unowned
   rendering declaration a typed `svg-css-<property>` refusal; feature-owned
   attributes remain admitted. Test: CSS geometry applies and `font-size:12px`
   refuses.
2. Dash offset no longer consumes an initial zero-length painted interval, and
   the iterator emits zero-length caps at subpath start/end. Tests cover both
   endpoints, a 24 px path whose end is a dot, and `stroke-dashoffset="6"`.
3. `preReserved` now debits the base plan on the local ledger; the debit is
   limited to capacity not already used by the fixed scene, and direct callers
   still reserve the full plan. Test: a 4096-tile pattern cannot reserve its
   4096 references on top of the base.
4. Every feature-owned node instance must call `markCovered`/`markIncomplete`
   (available on both preparation and geometry contexts); a missing call now
   produces `IncompleteGeometry`. Each paint wrapper must call `paintDefault()`
   exactly once or preparation returns the typed `svg-feature-paint-default`
   refusal. Tests: no-completion incomplete, skip/repeat typed refusal.
5. Feature-owned content inside `pattern`/`marker` is refused with
   `svg-feature-in-pattern`/`svg-feature-in-marker` until those builders run the
   feature lifecycle. Test covers both.
6. The refusal-identifier test now uses a test-only refusing registry instead of
   the live defaults, so implemented feature parts cannot break it.

Contract document updated with the completion rule, marker/pattern exclusion and
a "Contract change 2026-10-29" note. Own tests: `svg_graphics_semantics_test`
7 passed, `svg_feature_hooks_test` 10 passed. Required runs:
`test/features/reader/engine/fixed/svg` 38 passed with 5 failures confined to
`svg_feature_clip_mask_test.dart` (expects CompleteGeometry without calling
`markCovered`) and `svg_feature_filters_test.dart` (multi-input graph calls
`paintDefault` more than once, now `svg-feature-paint-default`);
`test/tool/reader/fixed_layout_svg_test.dart` 4 passed. Scoped format 0 changed;
scoped analyze no issues. The two owner failures are the documented contract
change and were not edited here; a 30 s wait and rerun showed no owner update.
No other-owner, fixture, oracle, spec, pubspec or gate edit was made.

## A2-filters

### Segment 6a (2026-10-29)

Implemented the bounded SVG filter graph in `svg_feature_filters.dart` and
proved the `filters` row through `FixedSectionPreparer`. No shared SVG/fixed
file, fixture, oracle, generator, spec, pubspec or existing harness was edited.

Supported profile: `filter` attribute/property admission with local `#id` /
`url(#id)` resolution; `filterUnits`/`primitiveUnits` in `userSpaceOnUse` and
`objectBoundingBox`; filter regions and primitive subregions; inherited
`color-interpolation-filters` with `sRGB`/`linearRGB`; the `in`/`in2`/`result`
graph with `SourceGraphic`, `SourceAlpha` and named results; and
`feGaussianBlur` (finite non-negative stdDeviation), `feOffset`, matrix/
saturate/hueRotate/luminanceToAlpha `feColorMatrix`, `feFlood` (named, 3/4/6/8
digit hex, rgb/rgba), `feComposite` (`over`, `in`, `out`, `atop`, `xor`,
`lighter`), `feBlend` (the standard separable/non-separable modes) and
`feMerge`/`feMergeNode`. Refusals are typed: other primitives keep
`svg-<feTag>`, unresolved/external filters keep `svg-filter`, unsupported
inputs `svg-filter-reference` (so `BackgroundImage`/`FillPaint`/`StrokePaint`
refuse), bad units `svg-filter-units`, region/area over the bound
`svg-filter-region`, duplicate results `svg-filter-result`, graph size
`svg-filter-complexity`, arithmetic composites
`svg-feComposite-arithmetic`, and singular transforms
`svg-filter-transform`.

Reservation/bounds: admission parses the referenced graph before allocation and
charges `2 * viewportPixels * (primitives + 5)` layer pixels/bytes; `prepare`
reserves the same per painted instance as an exact lease. A region is refused
before any layer allocation when it is non-finite/non-positive, exceeds 4096 px
on either axis, or exceeds twice the viewport-area cap. Paint uses bounded
`saveLayer` regions (no `ui.Image` pipeline, so nothing outlives the picture);
subregions clip every stage, `linearRGB` converts the source and final result
with `srgbToLinearGamma`/`linearToSrgbGamma`, and flood colors are linearized in
that mode. Scene disposal releases the feature leases exactly once; failure and
cancellation release the same set.

Geometry: filtered elements keep their source fragments and exact source paint.
The finite filter region is recorded as a conservative solid `GeometryPaint`
bound (the fixed preparer refuses incomplete geometry); source evidence stays
exact and visibility over-approximates the filter box rather than inventing
source outside it.

Proof: new `tool/reader/fixed_layout_svg_filters_harness.dart` and
`test/tool/reader/fixed_layout_svg_filters_test.dart` run all four cases through
`FixedSectionPreparer`, compare oracle element boxes at 0.5 CSS px, D4 with
D7/D10, D9 samples and rule-based D3, and write
`build/fixed-layout-svg-filters/report.json`. New
`test/features/reader/engine/fixed/svg/svg_feature_filters_test.dart` covers
each primitive, units/subregions/graph references, linearRGB, typed refusals
before allocation, and exactly-once lease release on success/failure/
cancellation. The existing hooks test now expects `feTurbulence` (not the
newly supported `filter`/`feGaussianBlur`) to keep the old typed refusal.

Verdicts (geometry max 0 px; D4 interior/edge/support/components/samples all
pass; D9 sample max delta 0; RD-1 is the only exemption):
- filters-positive PASS. 1 changed pixel, 1 RD-1 exemption, support
  [40,40,140,136] on both, 1 component; reservation layerPixels 2457600.
- filters-boundary PASS. `stdDeviation=0` and linearRGB; 1 changed pixel,
  1 RD-1 exemption, support [40,40,132,128], 1 component.
- filters-nested PASS. Host translate/opacity; 0 changed pixels, no exemption,
  support [47,49,147,145], 1 component.
- filters-unsupported PASS as a typed refusal (`UnsupportedSectionCapability`,
  construct `svg-filter`, no picture or fragments).
Row `PASS` in `build/fixed-layout-svg-filters/report.json`; every case reports
`budgetUsedZero: true`.

Validation (direct SDK; `flutter_tools.snapshot test ... --no-pub --reporter
expanded`): `test/features/reader/engine/fixed`,
`test/tool/reader/fixed_layout_svg_test.dart` and
`test/tool/reader/fixed_layout_svg_filters_test.dart` exit 0, 68 passed.
Scoped `format --output=none --set-exit-if-changed`: exit 0, 0 changed; scoped
`analyze`: exit 0, no issues. The confined sandbox blocks the runner's piped
subprocesses and formatter writes, so these scoped commands used approved
one-shot full access; no ACL change was made. No commit, push, stash,
sub-agent, dependency or network access occurred.

Requests/open issues: the fixed CSS projection still emits
`StyleDiagnosticKind.unsupportedProperty` for the `filter` property, so CSS
`filter:` remains refused by `fixed_preparation_plan.dart` even though the
feature hook admits it; supporting it needs a shared-owner change. Filter
regions are capped at twice the viewport area, and non-uniform/rotated element
transforms scale blur sigma by column norms (bounded approximation). The
existing `svg_feature_hooks_test.dart` expectation change is limited to the two
now-supported filter identifiers.

Post-run shared-contract note (2026-10-29, after the 68-test run above): a
concurrent shared-file edit added `paintDefaultCalls != 1 ->
svg-feature-paint-default` in `svg_graphics_prepare.dart`. The bounded graph
must replay the source for each graph input (the `feMerge` corpus case reads
`SourceGraphic` beside the blurred chain), so the live fixed route now refuses
all three required filter cases with `svg-feature-paint-default`; the recorded
row PASS predates that check and no expected data was changed. Required
contract change: either allow `SvgFilterFeature` to call `paintDefault` more
than once (its coverage is already bounded by the finite filter region), or add
a feature hook that captures the default source once as an owned
picture/image. Without one of those, the production filter row cannot compile
against the new gate. No shared file was edited here.

## A2-scene-fix

### Review fixes (2026-10-29)

Verified and fixed all five review findings in the segment-5i fixed-scene SVG
integration. Changes are confined to the allowed fixed-scene files, the new
test file and this section. No fixture, oracle, gate, spec, `engine/fixed/svg`,
`data/geometry`, `tool/reader`, layout/surface or pubspec file was changed.

1. Double placement was real: the SVG module's scene geometry already includes
   the `box.transform + flow` placement, but merging composed `box.transform`
   again. Fix: keep scene clip/paint/inner regions, alpha footprints and
   fragment `sourceToUnit` as already placed. Regression test uses a translated
   XHTML ancestor and asserts the rect fragment, rect paint and viewport-clip
   transforms all equal `box.transform.compose(box.svgContentTransform)`.
2. Every scene clip was attached to every merged fragment/paint. Fix: still
   register all clips, but attach only host `box.clipIds` plus each item's own
   `p.clipIds`/`f.clipIds` chain, prefixed. Test uses two disjoint nested SVG
   viewports and proves each rect carries its own viewport clip, not its
   sibling's, while both clips remain registered.
3. `_ordinal += paint.length` undercounted container ordinals. Fix: one
   `_advanceSvgOrdinal` walks scene elements/fragments/paint and sets
   `_ordinal = max(_ordinal, box.paintOrdinal + maximum + 1)`; hidden-SVG and
   absent-picture paths use the same helper. Test proves the following XHTML
   paint ordinal is greater than the SVG maximum and paint ordinals are unique.
4. Unconditional `color` projection overrode SVG presentation attributes and
   attribute inheritance. Fix: `_declaresSvgColor` projects only inline CSS
   `color` or a computed color that differs from the parent's (inheritance
   cannot change the computed value); the top-level SVG root still projects the
   host's inherited CSS color when it has no own `color` attribute. Test through
   `FixedSectionPreparer` proves `<defs color="red">` + `currentColor` paints
   red while a genuine `defs{color:red}` CSS declaration still wins.
5. A throwing feature owner aborted `FixedScene.dispose` before later scenes,
   paragraphs and leases, and `_run`/`PreparedFixedScene` cleanup had the same
   hazard. Fix: scene, prepared-scene and preparation cleanup release every
   picture, SVG scene, paragraph/inline, image, source lease and admission,
   aggregate errors, and rethrow only after all releases; the original
   preparation failure is preserved. Test uses a throwing feature plus a
   counting second scene: dispose throws after both owners release, the budget
   returns to zero and a second dispose is a no-op.

New file
`test/features/reader/engine/fixed/fixed_scene_svg_integration_test.dart`
contains five tests; each failed at its intended assertion before the fixes and
passes after. Production changes: `fixed_scene.dart`,
`fixed_scene_geometry.dart`, `fixed_scene_paint.dart`,
`fixed_preparation_plan.dart`, `fixed_section_preparer.dart`.

Harness verdict check:
- `fixed_layout_svg_test.dart` exit 0 (4 passed). `fixedPass` and every case
  fidelity/fixed-parity channel are unchanged from
  `build/a2-d9d10/round2-after/svg-report.json`.
- `fixed_layout_scene_test.dart` exits 1 only on row `paint`. Comparison with
  `build/a2-d9d10/round2-after/scene-report.json` shows exactly two changed
  cases, `paint-positive` and `paint-nested`, both capability-only
  (`background-resource-missing` on the source div); their pixel and geometry
  passes are unchanged, as are all other 25 cases/channels. Cause is a
  concurrent style-owner edit (`css_style_resolver.dart`/`css_stylesheet.dart`
  now resolve `background-image` URLs against the section path): the resolver
  returns `tile.svg`, while the A2-gates-owned scene harness still supplies
  `/tile.svg`. This is not an SVG-integration regression and no harness/fixture
  was edited. The corpus has no translated XHTML ancestor around SVG, so the
  placement fix changes no scene case verdict.

Validation (direct SDK, `--no-pub`, expanded reporter; sandbox-denied process/
write paths used one-shot full access; no ACL change):
- New integration test: exit 1 before the fixes at the five intended
  assertions; exit 0 after, 5 passed.
- Owned fixed tests (`fixed_scene_test`, `fixed_section_preparer_test`,
  `fixed_svg_viewport_test`, new integration test): exit 0, 32 passed.
- `test/features/reader/engine/fixed`: exit 1, 70 passed / 5 failed; all five
  failures are in other owners' in-flight `svg_feature_clip_mask_test.dart` and
  `svg_feature_filters_test.dart`. Owned fixed tests pass.
- `test/features/reader/engine/surface`: exit 0, 82 passed (including optional
  private fixtures; no skips observed).
- Scoped `format --output=none --set-exit-if-changed` on the five changed
  production files plus the new test: exit 0, 0 changed; scoped `analyze`:
  exit 0, no issues.

Requests: A2-gates must update its scene-harness background-image key from
`/tile.svg` to the resolver's `tile.svg` (or use the same resolution) after the
concurrent style URL change; otherwise the paint row stays externally failed.
No module change was required.

## A2-clipmask

### Segment 6b (2026-10-29)

Implemented the production clip/mask row through `SvgClipMaskFeature` and the
fixed preparer. No fixture, oracle, generator, gate, spec, pubspec, existing
harness or shared helper changed; no commit/git mutation/ACL change.

Geometry contract (additive): `paint_geometry.dart` adds `GeometryMask`,
`GeometryMaskKind` (alpha/luminance) and `GeometryMaskUnits`, plus an optional
`masks` list on `GeometryAlphaFootprint`. `GeometryMask` retains the mask source
node, units, content units, kind, unit-space region and a retained page-grid
alpha/coverage footprint; `placed()` composes region and coverage with the slot
matrix and can namespace the id. `SourceGeometry.masks` derives the explicit
registry from paint alpha footprints and rejects conflicting ids; complete
geometry now requires every fragment `maskIds` entry to resolve (missing
evidence still throws). `placeSourceGeometry` namespaces mask ids and the
retained evidence together, so `geometryForUnit` composes masks exactly like
clips and alpha grids. `GeometryPaint.masks` exposes the evidence without a new
paint kind or duplicate paint record.

Feature: attribute `clip-path`/`mask` referencing local `<clipPath>`/`<mask>`
definitions. Supported clip profile: `clipPathUnits` user/object space, child
shapes/groups/use (text-free), `clip-rule` nonzero/evenodd, and nested
`clip-path` on a clipPath (cycle/depth bounded). Supported mask profile:
`maskUnits`/`maskContentUnits`, explicit/default region, alpha/luminance
`mask-type` from attribute or inline `style`, and shape/group/use content.
Clipped paint alpha is filtered by the exact unit-space path; mask coverage is
retained per sample grid. Layer reservations are charged before allocation
(`chargeLayers`, two page buffers per mask). Refusals stay typed: empty
definitions keep `svg-clipPath`/`svg-mask`; unresolved attributes keep
`svg-attribute-*`; filter/text/foreignObject/image content gives
`svg-clipPath-content`/`svg-mask-content`; bad units/rule/type give
`svg-clipPath-units`/`svg-clipPath-rule`/`svg-mask-units`/
`svg-mask-content-units`/`svg-mask-type`; CSS `clip-path`/`mask` stay
`svg-css-*`.

Narrow shared style change: `css_properties.dart` now treats the feature-owned
SVG declarations (`mask-type`, `clip-rule`, `clipPathUnits`, `maskUnits`,
`maskContentUnits`) as no-diagnostic no-ops. `CssStyleResolver` previously
reported inline `mask-type` as `unsupportedProperty`, and `fixed_scene`
refuses the whole scene on every CSS diagnostic; without this the three
required fixtures refused before the feature ran. The SVG feature reads the
authored declarations itself. This is the only change outside the assigned
SVG/geometry paths.

Harness: `tool/reader/fixed_layout_svg_clipmask_harness.dart` runs all four
`clip-mask` cases through `CssStyleResolver`, `FixedPreparationPlan`,
`FixedSectionPreparer`, the real resource ledger and `geometryForUnit`. It
compares source boxes (0.5 CSS px), clip/mask evidence resolution, mask
kind/region/coverage, D4 (D7/D10), D9 solid samples and the shared D3 scope, and
writes `build/fixed-layout-svg-clipmask/report.json` plus per-case PNGs.

Verdicts (row **pass**; largest gated geometry delta 0 px):

| Variant | Geometry/evidence | D4 | Samples |
| --- | --- | --- | --- |
| clip-mask-positive | complete; 2 clips, 1 luminance mask, region [0,0,320,240], coverage 128 | all pass; 9 changed, 85 delta-1, RD-1 exempt | 4/4 solid delta 0 |
| clip-mask-boundary | complete; 2 clips, 1 alpha mask, region [0,0,320,240], coverage 255 | all pass; 1 RD-1 exempt | 4/4 solid delta 0 |
| clip-mask-nested | complete; 2 clips, 1 luminance mask, region [7,9,320,240], coverage 128 | all pass; RD-1 not eligible | 4/4 solid delta 0 |
| clip-mask-unsupported | typed refusal `svg-clip-path`, no picture/fragments | n/a | n/a |

`geometryForUnit` evidence passed for all required cases with namespaced
`slot:` mask ids and all fragment clip/mask ids resolved. The fixed merged
scene reports 4/5 clips (viewport/merge duplicates) and one mask; the module
scene is the exact source geometry channel.

Validation (direct SDK, `--no-pub`, expanded; DSH workspace writes are denied,
so the tests ran in a disposable source mirror with the same files):
- `test/features/reader/data/geometry test/features/reader/engine/fixed
  test/tool/reader/fixed_layout_svg_test.dart
  test/tool/reader/fixed_layout_svg_clipmask_test.dart -j 1`: exit 0,
  78 passed.
- New unit test: 7 passed; new harness test: 1 passed.
- Surface scope excluding the concurrently added
  `publication_fixed_lifecycle_test.dart`: exit 0, 78 passed, 1 pre-existing
  optional skip. The excluded test reproducibly times out at 30 s in isolation
  while waiting for its paused worker preload event; it is an untracked
  concurrent-owner file not touched here.
- Scoped `format --output=none --set-exit-if-changed` on the ten changed Dart
  files: exit 0, 0 changed; scoped `analyze`: exit 0, no issues.

Requests:
- CSS `clip-path`/`mask` property support remains unreachable in the fixed
  production path: `CssStyleResolver` still diagnoses those declarations and
  `fixed_preparation_plan._svgPresentation` does not project them, so only XML
  attributes reach the feature. Supporting the CSS property needs a shared
  projection of resolved `clip-path`/`mask` values (or a targeted SVG-owned
  diagnostic carve-out), not a feature-part change.
- Review the narrow `css_properties.dart` carve-out. A future owner that adds
  another feature-owned SVG CSS declaration must extend that set, or
  `fixed_scene` will refuse every page using it.

Open: path clip evidence in `GeometryClip` remains a transformed region; exact
visibility is carried by the clipped paint alpha footprint and mask coverage,
which S4b must use. Mask coverage is a page-grid raster (no resampling); the
slot transform moves it without copying bytes. The fixed merged mask evidence
is proven for these single-document pages; a document with multiple SVG roots
needs unique mask ids from the feature (it already derives them from the
referencing node/instance identity).
## A2-svgtext

### Segment 7b (2026-10-29)

Stopped at the integration boundary before production edits. The text part
still refuses svg-text/svg-tspan/svg-textPath and the default host text service
is unavailable. No production verdict, harness report or completed gate is
claimed for this segment.

Blocking owner request (A2-filters-2): svg_feature_text.dart is a Dart part of
svg_graphics.dart. The containing library has no HarfBuzz import, and a part
cannot declare its own imports. Please add an import of
package:shiori/features/reader/engine/text/harfbuzz/harfbuzz.dart to
svg_graphics.dart (optionally prefixed hb), or explicitly transfer permission
for this one additive import. That shared file is outside this owner's scope;
no shared file was changed and no dynamic or duplicated shaper was introduced.

Font service design/request (A3): retain the section resource owner through
scene disposal, expose immutable admitted SFNT bytes with canonical descriptor,
face index and alias, use the registry's processBudget and drainFonts, and
release logical font leases once without implying native font unload. Current
FontRegistry exposes records/selectFace aliases, not admitted-byte leases;
WOFF conversion is private to _loadFace and its converted bytes are disposed
after registration. Please expose an admitted-byte lease API for the exact
selected face, including converted faces, so the host need not duplicate A3's
conversion/admission implementation. Missing/unadmitted required faces must
remain RequiredFontException failures. No second process budget is proposed.

Validation used the direct installed dart.exe/flutter_tools.snapshot:
- test test/features/reader/engine/fixed
  test/features/reader/engine/text/harfbuzz
  test/features/reader/engine/layout/font_face_selection_test.dart
  --no-pub --reporter expanded: first exit 1 (92 passed, 3 filter tests failed).
- Same command after a short wait: exit 0, 95 passed. No other-owner fixes.
  Rerun log: build/a2-svgtext-baseline-tests.log.
- No Dart files changed; format/analyze and new tests are not applicable.

Production variants positive/boundary/nested/path-none/path-spacing/
path-spacingAndGlyphs/unsupported were not run through a new text harness;
B maxima, cluster conservation, D4 with D8 and D9 samples are unmeasured here.
The existing isolated HarfBuzz tests are baseline evidence only. A5 text raster
parity remains device-gated; existing prefixed-process lookup fails typed when
iOS symbols are missing, with no silent fallback. No iOS device run occurred.
Only this appended section and an ignored baseline test log were written.
No sub-agent, dependency, network, git mutation or out-of-scope edit occurred.

## A2-filters-2

### Filters completion (2026-10-29)

Implemented the additive `SvgFeaturePaint.captureDefault() -> ui.Picture` hook.
It records the next wrapper/default in root coordinates once, counts as the
single default call, returns the same borrowed picture on subsequent capture
calls, and supports arbitrary `canvas.drawPicture` replay. Mixing direct and
captured default calls refuses with `svg-feature-paint-default`. Existing public
feature paint APIs and other owners' call sites remain source-compatible.
Pictures enter the scene's owned-picture list and existing picture-byte check;
failure/cancellation release captures and unfinished recording outputs. A new
post-paint cancellation check prevents transferring a canceled capture scene.

Confirmed layer refusal cause: filter admission already calls `chargeLayers`,
which is included in the base `reservation()`, while filter preparation reserved
the same pixels/bytes again. Removed that second reservation. The admission audit
recursively follows references and charges repeated source instances, so repeated
`use` instances are covered without an additional preparation lease. Preserved
the shared `preReserved` local debit and added an early rejection when the layer
request exceeds the entire local pixel/byte capacity; the remainder clamp must
not admit an undersized ledger. Existing caller-owned leases stay caller-owned.

Filters now replay one captured source for every SourceGraphic/SourceAlpha read,
including graphs that never read their source. Each owned no-effect node is
marked covered; a missing graph/bounds remains explicitly incomplete rather
than successful partial evidence. Active filter instances mark covered only
after layout and conservative filter-region evidence are complete.

Tests added: cached capture/replay pixels, one inner-wrapper invocation,
scene/failure/cancellation release, mixed-call refusal, exact layer budgets for
repeated source instances (direct and preReserved), already-debited outer lease
ownership, and one-pixel/one-byte budget excess refusing before any picture is
created. The already-debited subcase and final explicit missing-evidence handling
were added after the last executing test run; runtime revalidation is blocked
by concurrent files as described below.

Files changed in this slice: `svg_feature_hooks.dart`,
`svg_graphics_prepare.dart` (capture/layer reservation paths only),
`svg_feature_filters.dart`, `svg_feature_hooks_test.dart`,
`svg_feature_filters_test.dart`, `research/a2-svg-feature-hooks.md`, and this
appended section. No other feature, fixed_*, data, harness, shared helper,
fixture/oracle/generator, spec or pubspec edit was made.

Last executing production harness: `build/fixed-layout-svg-filters/report.json`,
row PASS; no difference from the pre-contract successful measurements:
- positive PASS: geometry max 0 CSS px; D4 interior/edge/support/components/
  samples all PASS; sample max delta 0; D3 RD-1 only at (0,0), 1 changed/exempt
  pixel; support [40,40,140,136] matches; 1 component.
- boundary PASS: geometry max 0; all five D4 sub-rules PASS; sample max 0;
  D3 RD-1 only at (0,0), 1 changed/exempt pixel;
  support [40,40,132,128] matches; 1 component.
- nested PASS: geometry max 0; all five D4 sub-rules PASS; sample max 0;
  no D3 exemption, 0 changed pixels; support [47,49,147,145] matches;
  1 component. RD-2 is ineligible in all required variants.
- unsupported PASS: typed `UnsupportedSectionCapability` / `svg-filter`,
  no picture/fragments; geometry/D4/samples/D3 not applicable.
All four cases report `budgetUsedZero: true`; 0.5 px and D3/D4/D7-D10 unchanged.

Validation uses the requested direct dart.exe and flutter_tools.snapshot,
with `test ... --no-pub --reporter expanded`:
- Initial hooks + filters + filters harness: exit 0, 16 passed.
- Required SVG directory + filters harness + graphics harness, after new capture
  and budget regressions: exit 1, 45 passed, 1 load failure confined to another
  owner's `svg_feature_clip_mask_test.dart:168` (`SourceGeometry.paintOrder`).
- After a short interval doing documentation/checks, the same required command
  reran once: exit 1, 7 load failures. Concurrent `svg_feature_clip_mask.dart:
  359-360` refers to undefined `instance`; `fixed_scene.dart:37` references the
  not-yet-present `fixed_scene_foreign_object.dart`. These were not edited.
- Final scoped `format --output=none --set-exit-if-changed` on the five changed
  Dart files: exit 0, 0 changed. Final scoped `analyze` on those files: exit 0,
  no issues. Scoped `git diff --check`: exit 0.

Requests: A2-clipmask-2 to finish its compile fixes; A2-foreignobject to finish
its new part file. Main owner must rerun the required SVG directory and two
harness tests after those edits settle; final checkout-wide runtime validation
is not claimed. Existing CSS filter admission and transformed blur limitations
from the original A2-filters handoff remain outside this slice. No sub-agent,
commit/push/stash/reset/checkout, dependency, download or network access occurred.


## A2-clipmask-2

### Segment 6b (2026-10-29) - continuation

#### Completion (2026-10-29)

This is an append-only continuation of the existing A2-clipmask Segment 6b.
The initial measured state matched the handoff: two clip/mask unit failures
were reproduced, both caused by missing explicit feature completion calls.

Gaps fixed in `svg_feature_clip_mask.dart`:
- Completion is reported in geometry after attaching clips/masks with
  `addClipTo`/`addMaskTo` and retaining coverage. Missing paint/mask coverage,
  singular coverage transforms and repeated-source instance ambiguity call
  `markIncomplete` with a reason; complete instances call `markCovered`.
  The previous inverted mask-evidence membership check could miss absent
  evidence; it now refuses to attest completion. Empty masked nodes have an
  explicit missing-footprint regression, including the issue reason.
- Paint wrappers still call `paintDefault()` exactly once.
- Sibling clip shapes now union, while nested clipPaths intersect; percentage
  objectBoundingBox content uses the normalized viewport. Group bounds apply
  each descendant transform once; footprint sample points use the forward
  grid-to-unit transform. Rotated mask regions clip their actual quadrilateral
  in painting and retained coverage instead of accepting the enclosing box.
- Layer charges count mask applications and the luminance conversion layer;
  repeated instances reserve additional capacity before mask allocation.
- Resolved local-URL CSS clip-path/mask values are admitted by the feature;
  unsupported shapes/content remain typed refusals, including effects reached
  through referenced definition content. Inline mask-type overrides its
  presentation attribute.
- Harness D3 scope is local to each case, preventing a refused case from
  inheriting the previous case's reference-defect evidence; tool regression
  requires empty D3 evidence on that refusal.

Files changed in this continuation: the feature part, its unit test,
`tool/reader/fixed_layout_svg_clipmask_harness.dart`, its tool test, and this
appendix. The additive geometry implementation was audited and tested without
further geometry-model changes. No shared hook/graphics/fixed/style file,
fixture, oracle, generator, gate, spec, dependency or other owner's section
was edited.

Last successful production harness report (after completion/union/region fixes,
before the final extra regressions and per-case D3 reset): all four variants
received verdicts, row pass. These are retained measurements, not a claim that
the final concurrently edited checkout passed:

| Variant | Geometry / evidence | D4 sub-rules and samples | D3 |
| --- | --- | --- | --- |
| positive | complete; max delta 0 CSS px; 2 clips, 1 luminance mask; no unresolved ids | interior, edgeNeighbourhood, supportBounds, components, samples pass; 4/4 solid delta 0; 9 changed / 85 delta-one pixels | RD-1 eligible only at (0,0); RD-2 ineligible |
| boundary | complete; max delta 0 CSS px; 2 clips, 1 alpha mask; no unresolved ids | all five sub-rules pass; 4/4 solid delta 0; 8 changed / 80 delta-one pixels | RD-1 eligible only at (0,0); RD-2 ineligible |
| nested | complete; max delta 0 CSS px; 2 clips, 1 luminance mask; no unresolved ids | all five sub-rules pass; 4/4 solid delta 0; 20 changed / 268 delta-one pixels | RD-1/RD-2 ineligible |
| unsupported | typed UnsupportedSectionCapability, svg-clip-path; no scene | geometry/D4/samples not applicable | no applicable exemption; final reset removes stale inherited scope |

Required cases also passed fixed geometry/slot namespacing. Gates remain
0.5 CSS px, D7 alpha >=32, D9 exact solid samples and D10 delta >=2; D8 is
not applied to these non-text cases. Evidence: existing ignored
`build/fixed-layout-svg-clipmask/report.json` and per-case PNGs.

Validation uses direct dart.exe / flutter_tools.snapshot, --no-pub, expanded:
- Original clipmask unit test: exit 1, 5 passed / 2 failed, matching handoff.
- Clipmask unit + harness immediately after initial fixes: exit 0, 8 passed.
- Final clipmask unit test: exit 0, 13 passed (six new regressions).
- `test/features/reader/data/geometry test/features/reader/data/cfi
  test/features/reader/data/canonical`: exit 0, 228 passed. Source/CFI/canonical
  data and v1 contract unchanged.
- Requested geometry/fixed/surface + clipmask/svg tool tests with -j 1:
  exit 1 initially; short-wait retry exit 1, 80 passed / 25 loading failures.
  Retry failures were outside ownership: foreignObject part references missing
  SvgForeignObjectEvidenceLayoutService/SvgForeignObjectEvidence and a
  non-const ParagraphFonts constructor in a const default. See ignored
  `build/clipmask-completion-tests-retry.log`. No exclusions or fixes applied.
- Final harness-only check after the harness D3 reset: exit 1 at loading,
  now blocked by concurrent svg_feature_text.dart references to absent
  _SvgTextInput/_SvgPreparedText. See `build/clipmask-harness-final.log`.
  The last successful report was not overwritten or hand-edited.
- Final scoped analyze (feature, geometry, geometry tests, unit, harness, tool
  test): exit 0, no issues. Scoped format check: exit 0, 0 changed.

Requests:
- A2-foreignobject/A2-svgtext: finish the currently missing types/parts; main
  owner rerun the requested five scopes and harness after edits settle. Final
  production row revalidation remains open; do not promote the retained report
  to a final-checkout gate pass.
- Shared fixed/style owner: project resolved CSS clip-path/mask into SVG
  presentation and admit them in typed CSS. Current production diagnostics
  refuse them and `_svgPresentation` does not project them. Feature-level
  resolved-presentation coverage passes; production CSS completion is open.
- Hook/geometry owner: add instance-specific evidence annotation (the public
  addClipTo/addMaskTo only accept a source node index). Reused source nodes with
  distinct effects remain explicitly incomplete here rather than falsely
  claiming per-instance evidence. Review shared layer-depth accounting for
  the extra luminance conversion layer (three rather than two).

No sub-agents, commit/push/stash/reset/checkout, downloads or network access.
Stopping at this slice with final production checks blocked by concurrent work.

## A1-sample

### Private sample conservation (2026-10-29)

Root cause: rendition issues are empty. Unknown itemref property names,
including undeclared-prefix names, are already ignored and retained raw;
known layout/orientation/spread properties with unknown values still produce
RenditionIssueKind.unsupported. The metadata-unsupported test remains typed
unsupported (three issues). The installed reference selects only recognized
property tokens; no network or dependency change was needed.

Composition failed because resolveAuthoredDimensions validated embedded SVG
percentage lengths as independent page dimensions, even after resolving an
explicit XHTML viewport. Moved explicit page-viewport return before embedded
SVG checks. SVG root resolution and the standalone inline-SVG refusal remain
unchanged. The dimensions-unsupported source still has typed unsupported SVG
lengths; only its independently authored XHTML page dimensions now resolve.
No scene capability or fidelity gate was relaxed.

Anonymous completed diagnostic before: 5 books, 83 sections, 1537 reflow units,
0 fixed units, 1 composition failure, 6 unsupported dimension outcomes,
0 rendition issues, 0 import failures.
After page-dimension fix (before final gate/import refactor): 5 books,
83 sections, 1952 reflow units, 6 fixed units, 0 prepared fixed units,
0 composition/import failures, 6 UnsupportedSectionCapability failures with
an authored-viewport dimension construct. All retained resource counters 0.
These are measured intermediate results, not a claim that preparation passes.

Private regression now calls real PublicationWorker.prepare, checks original
spine coverage, unique section identities, document presence, expected per-source
page multiplicity (one for fixed; real pagination count for reflow), unique unit
IDs and all fixed constituents prepared. Failures and null preparation produce
anonymous typed outcomes and fail the test. Archive/import errors are caught
inside the anonymous boundary. No-private-input skip remains. Reports expose
construct kinds instead of arbitrary source-derived identifiers. A completed
4-book default-folder run after this refactor conserved 60/60 sections with
1537 reflow units and zero outcomes. Final extra-input run is compile-blocked.

Synthetic in-memory EPUB: new surface/mixed_svg_wrapper_regression_test.dart
builds 17 reflow + 6 fixed XHTML sections without package rendition/progression,
with optional undeclared-prefix itemref properties, a linked synthetic sheet,
div > percentage-sized SVG > xlink:href raster and explicit 320x240 viewport.
Composition and property-name/value tests are ready; the preparation test records
the current typed refusal, not successful completion. No private data was copied.

Requests:
- A2-foreignobject: FixedPreparationPlan.inspect independently runs
  FixedSvgViewport.resolve over every embedded SVG, replacing the valid XHTML
  page dimensions with unsupported percentage dimensions. _layoutSvg also calls
  the same resolver without a containing block. Keep source page dimensions
  separate from the replaced-element viewport; resolve inline SVG width/height
  percentages using the actual XHTML containing block (including CSS used size
  and definite/indefinite height rules). Preserve viewBox origin/aspect transform;
  never substitute viewBox extent as guessed page or containing-block size.
- Ready synthetic case: syntheticMixedSvgPublication() in the new test. Its
  sheet gives html/body/div definite 100% width/height from the authored viewport;
  expect each SVG viewport 320x240, one admitted local raster, six prepared fixed
  constituents, 23 distinct conserved sections, complete geometry and no leaked
  owners. Replace the current typed-refusal assertion with successful preparation
  assertions when implementing the scene fix; also test 50%/75%, CSS overrides
  and indefinite containing-block height. Do not merely remove the preflight:
  both planning and scene layout must use the resolved replaced-element size.
- Concurrent SVG text/foreignObject files were mid-edit. Initial missing font/
  evidence types became a non-const ParagraphFonts default; later retries still
  lack _SvgPreparedText and _SvgTextInput methods in svg_feature_text.dart.
  These are outside A1 ownership; no edits made there.

Validation: direct dart.exe and flutter_tools.snapshot, --no-pub, expanded.
- Scoped format check, analyze (4 changed Dart files), diff --check: exit 0.
- test/features/reader/data/layout: exit 0, 31 passed, including all metadata rows.
- test/features/reader/data/worker separately: exit 0, 112 passed.
- pagination + surface + worker: exit 1, 286 passed, 2 skipped, 7 failures;
  concurrent fixed-scene compile errors. Pagination + worker retry: exit 1,
  217 passed, 2 skipped, 3 failures, concurrent SVG text compile errors.
- Private diagnostic before/after: exit 1 as intended after adding failure gate;
  anonymous counts above. Final private plus new synthetic tests: exit 1,
  compilation blocked by concurrent SVG text files after retry.
- No engine/fixed edits, full suite, codegen, fixture/oracle changes, network,
  sub-agents or git mutations. Stopped at scene-owner handoff; A-AC8 remains open.

## A2-foreignobject

### Segment 6c (2026-10-29)

Implemented the required production foreign-object fixture row through
FixedSectionPreparer and the foreignObject hook. The degraded-mode empty
current-task pointer is expected; no task.py start/finish was run.

Host: FixedForeignObjectLayoutService reuses FixedSceneBuilder's existing
_layout, inline paragraph, _transforms, paint, alpha coverage and geometry
export routines. A neutral foreignObject containing box supplies the exact
viewport while preserving the projected document/node indices. The SVG CTM
and x/y translation place its geometry once. XHTML overflow clips and the
foreign viewport clip retain their source-specific registry chains. Relative
inline offsets use existing paragraph paint groups without changing shaping,
advances or line height; inline siblings share the same host line.

Ownership: the actual host picture transfers to the SVG picture list (and its
retained-picture byte check), while a registered evidence owner retains and
releases the host paragraphs/inline paragraphs and prepaid sub-ledger leases.
FixedScene's private picture-ownership bit prevents a second disposal. Host
failure, cancellation, invalid returned source identity and normal/idempotent
disposal have tests. The optional SvgForeignObjectEvidenceLayoutService and
SvgForeignObjectEvidence extension live only in the owned feature part; the
shared hooks contract was not edited. A picture-only host explicitly produces
IncompleteGeometry rather than attesting missing internal paint evidence.

Feature: opaque static XHTML uses the admitted fixed box/inline profile,
x/y/width/height, transforms and clipped foreign viewports. Namespace audit,
requiredExtensions, active attributes, scripts/forms/form controls and embedded
browsers produce typed refusals. Negative sizes are malformed, zero sizes do
not allocate, and explicit overflow:visible remains a typed profile refusal.
Descendant nodes/bytes/text/paragraphs/paint operations are charged during
admission. Real host paint-source instances obtain ordinals during shared tree
traversal before the following SVG sibling; their typed fragments and exact
per-source paint evidence replace the aggregate foreignObject paint record.
markCovered/markIncomplete are explicit; inherited paint calls paintDefault
exactly once. Canonical v1 and projected CFI identity are unchanged.

Conservative integration boundary: SVG masks, filters and custom clipPath
wrappers currently publish evidence before this feature's internal paint
records. Those combinations explicitly report incomplete occlusion geometry
and cannot publish through FixedSectionPreparer. No complete verdict is
claimed for them. SVG viewport/ancestor clips and the host's own XHTML clips
are supported. A regression test pins the incomplete custom-SVG-clip outcome.
Requests: shared feature owners should provide a per-source evidence postpass
for these combined effects before extending this profile.

Scene request (a): whole-unit sourceNodes now includes each SVG plan's expanded
charge above its original subtree count, retaining the original-document
charge without charging an unreferenced subtree twice. A 30-use regression
proves the plan exceeds the original-node count, covers repeated SVG charges,
and refuses a unit budget sized only to the original document.
Scene request (b): only the scene harness background image key changed from
/tile.svg to the resolver's tile.svg. The new resolved-background tool test
proves paint-positive and paint-nested capability, geometry and pixels pass.

First production verdict: build/fixed-layout-svg-foreign-object/report.json.
- foreign-object-positive: PASS; maximum geometry delta 0.01171875 CSS px.
- foreign-object-boundary: PASS; maximum geometry delta 0.01171875 CSS px.
- foreign-object-nested: PASS; maximum geometry delta 0.01171875 CSS px.
- foreign-object-unsupported: PASS; typed svg-foreignObject-input refusal
  after inert projection; no picture published.
- foreignStatic HTML control: PASS, zero exemptions.
- Row verdict: PASS for all four required corpus variants/control channels.
  D3 RD-2 eligibility comes only from SpikeReferenceDefects and the passing
  real production static control; eligible in all three required variants.
  RD-1 is eligible in positive/boundary, ineligible in nested. The 0.5 CSS px
  gate and D4/D7/D8/D9/D10 rules are unchanged. D9 uses the shared SVG sample
  classifier, projected CFI vectors compare exactly, canonical v1 excludes
  the foreign text, and native grapheme/source coverage is conserved.

Owned changes: fixed_scene.dart, new fixed_scene_foreign_object.dart,
fixed_scene_layout.dart, fixed_scene_inline.dart, fixed_scene_geometry.dart,
fixed_scene_svg.dart, fixed_preparation_plan.dart,
svg/svg_feature_foreign_object.dart; tool/reader/fixed_layout_scene_harness.dart
(request b only); new fixed_layout_svg_foreign_object_harness.dart;
new svg_feature_foreign_object_test.dart, fixed_layout_svg_foreign_object_test.dart
and fixed_layout_scene_resolved_background_test.dart; this appended section.
No fixed_section_preparer.dart, shared SVG hooks/graphics, other feature part,
data/style/surface, fixture/oracle/helper/spec/pubspec edit was made by this owner.

Validation used direct dart.exe/flutter_tools.snapshot, --no-pub and expanded
reporting; final test runs also pass --no-version-check.
- New foreignObject unit tests: exit 0, 19 passed.
- test/features/reader/engine/fixed: exit 1, 110 passed / 1 failed. Remaining
  other-owner failure is fixed_section_preparer_test.dart:591, "unsupported
  SVG refuses before font/native work with no partial scene"; it still expects
  UnsupportedSectionCapability/svg-text after the SVG-text owner enabled text.
  A second stale CSS/text-refusal test was corrected concurrently by its owner.
  Earlier transient SVG-text compilation failures were retried after waiting;
  no other-owner source or test was edited here.
- test/tool/reader/fixed_layout_scene_test.dart,
  test/tool/reader/fixed_layout_svg_test.dart,
  test/tool/reader/fixed_layout_svg_foreign_object_test.dart,
  test/tool/reader/fixed_layout_scene_resolved_background_test.dart,
  test/features/reader/data/epub/fixed_layout_corpus_test.dart:
  combined exit 0, 65 passed.
- Scoped format --output=none --set-exit-if-changed: exit 0, 13 files, 0 changed.
  Scoped analyze: exit 0, no issues. Scoped git diff --check: exit 0.
- Logs: build/a2-foreignobject-unit-final.log,
  build/a2-foreignobject-fixed-final.log,
  build/a2-foreignobject-tools-corpus-final.log.
- One earlier Flutter freshness check attempted git fetch --tags and failed
  opening SDK .git/FETCH_HEAD; subsequent commands disabled version checking.
  No network download, dependency change, codegen, full-suite run, sub-agent,
  git mutation, ACL change or task-pointer mutation was performed.

Requests: A2-svgtext should update its stale fixed_section_preparer_test.dart
unsupported-text expectation. Shared feature owners should coordinate the
per-source SVG effect evidence postpass described above. No preparer injection
change is needed: planning installs the fixed foreign host and scene preparation
binds registered paragraph fonts, preserving the independently supplied text
service unchanged.

## A2-svgtext-2

### Segment 7b completion (2026-10-29)

Resumed the named in-progress task in degraded-pointer mode. The supplied
748-line text part, 415-line harness, new service/tests and existing report
matched the handoff. No new task, sub-agent, network/download, dependency,
fixture/oracle/generator, spec, git mutation or other owner's implementation
edit was performed. This slice is finished with the production svg-text row
FAIL, hostGate=false. The required boundary variant is still refused by a
global CSS diagnostic outside this owner's scope; it is not waived.

Files audited/carried forward:
- lib/features/reader/engine/fixed/svg/svg_feature_text.dart (updated here).
- lib/features/reader/engine/fixed/fixed_svg_text_fonts.dart (inherited host
  service, reviewed, unchanged here).
- tool/reader/fixed_layout_svg_text_harness.dart (extracted the same geometry
  measurement into a reusable module-diagnostic function; gates unchanged).
- test/features/reader/engine/fixed/svg/svg_feature_text_test.dart (updated).
- test/tool/reader/fixed_layout_svg_text_test.dart (inherited; unchanged and
  deliberately still fails on the required boundary, with its full report).
- fixed_section_preparer.dart (inherited text-host injection; clarified its
  comment) and test/features/reader/engine/fixed/fixed_section_preparer_test.dart
  (stale unsupported-text test now uses writing-mode=vertical-rl).
- lib/features/reader/engine/fixed/svg/svg_graphics.dart: preserved the granted
  HarfBuzz import and formatted only that import's alias continuation.
- lib/features/reader/engine/layout/font_registry.dart: preserved/reviewed the
  existing 18-line admittedIdentity(scope, face) accessor, descriptor
  index=0;weight=...;style=..., alias and faceIndex=0. No registry edit here;
  A3's WOFF2 routing remains outside this owner.
- This appended progress section. Logs/report/PNGs are ignored build artifacts.

Design/audit and gaps fixed:
- text/tspan/textPath flatten source UTF-16 positions through ancestor lists;
  deepest x/y/dx/dy overrides win and rotate repeats. Horizontal LTR only;
  vertical/bidi, unsupported children/paths/styles and partial length scopes
  retain typed refusals. Text attributes now use an explicit profile rather
  than accepting arbitrary shape/gradient attributes with no text behavior.
- end anchor now includes additional dx, letter spacing and word spacing.
  Anchored y-created chunks refuse alongside x-created chunks. First-slot
  placement cannot silently consume a positioned combining continuation:
  unsupported continuation changes now refuse after shaping and release.
- textLength/lengthAdjust scope remains explicit: a whole-run tspan may own
  length; textPath establishes its own scope and does not inherit parent
  textLength. Only the proven absolute M/Q quadratic profile is admitted,
  with absolute/percent startOffset and the existing 256-chord traversal.
  Its href is now recorded/charged through the feature admission API.
- font-kerning auto/normal explicitly send HB kern=1; none sends kern=0 in
  both layout and paint shapes. Other values refuse. The existing host SVG
  CSS cascade resolves the boundary's svg{font-kerning:none}; an AVATAR
  control proves auto=normal and none has a different advance. No other new
  text-property refusal appeared in the corpus run; vertical is expected.
- The exact boundary source/reference also passed the production SVG module
  diagnostic: B maximum 0.00011549540383006247 CSS px, 12 comparisons,
  clusterConservation=true. This diagnostic bypasses the fixed-scene wrapper
  by design and is NOT credited to the production row or its hostGate.
- Layout clusters must now form a contiguous, positive-length exact partition
  of the run and have placed paint membership. Existing per-source mapping
  refuses a shaping cluster crossing source nodes rather than splitting or
  duplicating it. Glyph index count/uniqueness and every UTF-16 unit remain
  checked; placed Paths survive font/run disposal and release with the scene.
- Module paint ordinals and one sourceToUnit transform are retained. Tests
  exercise nested translation, paint before/after text, and exactly-once font
  leases/process admission. The service selects the registry-admitted face,
  reuses its canonical alias/process owner and never registers a second face.
  TTF and existing WOFF decoding retain their explicit ownership; WOFF2 in
  this text byte service still has a typed refusal pending A3 coordination.
- Completion uses markCovered after prepared output, inherited default paint
  calls paintDefault once, and no custom paint wrapper/GDI path was added.
  HarfBuzz OT unhinted outlines remain the only text painting backend.
- Audit found clip/mask/filter geometry executes before source text fragments
  exist and can otherwise leave per-source effect evidence incomplete while
  replacing the generic leaf paint. Text under these effects now refuses
  svg-text-effect-profile until an owner-coordinated evidence handoff exists.
  Plain viewport/host overflow clips remain supported. Unsupported use-instance
  style inheritance also refuses explicitly. These are additional profiles,
  not exemptions or removals of any required corpus variant.
- HB failures now keep svg-text-harfbuzz-<failure> typed at the SVG boundary;
  cancellation still follows the existing cancellation path and cleanup.

Fresh production report: build/fixed-layout-svg-text/report.json. B gate is
unchanged at 0.5 CSS px. D4 retains D7/D8/D9/D10 and recorded D3 scopes.

| Variant | B maximum CSS px | Clusters | D4/D8 | D9 samples | D3 RD-1/RD-2 | hostGate |
| --- | ---: | --- | --- | --- | --- | --- |
| positive | .00011549540383006247 | pass | pass/applied | 4 solid, delta 0 | 1/0 | true |
| boundary | unmeasured | unmeasured | unmeasured | unmeasured | none applied | false |
| nested | .00011549540383006247 | pass | pass/applied | 4 solid, delta 0 | 0/0 | true |
| unsupported | N/A, typed svg-text-vertical | N/A | N/A | N/A | N/A | true |
| positive-webkit-parent-length | .00011549540383006247 | pass | pass/applied | 4 solid, delta 0 | 1/0 | true |
| boundary-webkit-parent-length | unmeasured | unmeasured | unmeasured | unmeasured | none applied | false |
| nested-webkit-parent-length | .00011549540383006247 | pass | pass/applied | 4 solid, delta 0 | 0/0 | true |
| path-none | .00011549540383006247 | pass | pass/applied | 0 oracle samples | 1/0 | true |
| path-spacing | .0004843978413104107 | pass | pass/applied | 0 oracle samples | 1/0 | true |
| path-spacingAndGlyphs | .0004716447097303635 | pass | pass/applied | 0 oracle samples | 1/0 | true |

RD-1 remains only the recorded (0,0) pixel; RD-2 nowhere. Every prepared
variant passes interior/edge/support/components with D8 only on the component
sub-rule. All ten cases report resourcesReleased=true. No gradient samples
exist in these variants; empty probe samples are not invented coverage.
Both boundary refusals are unsupportedProperty:font-kerning. A5 text raster
parity is separately device-gated for every supported variant, not host pass.

Validation (direct installed SDK entry points, no .bat wrappers):
- SDK = D:/DevTools/flutter/bin/cache/dart-sdk/bin/dart.exe;
  Flutter tool = D:/DevTools/flutter/bin/cache/flutter_tools.snapshot.
- SDK format --output=none --set-exit-if-changed on the eight owned/inherited
  Dart files listed above excluding font_registry.dart: final exit 0, eight
  files, zero changes. First exit 1 identified only the granted HB import's
  line wrapping; formatted that import and reran successfully.
- SDK analyze on those eight files plus font_registry.dart: exit 0, no issues;
  build/a2-svgtext-2-final-analyze.log.
- SDK Flutter-tool test test/features/reader/engine/fixed
  test/features/reader/engine/text/harfbuzz
  test/features/reader/engine/layout/font_face_selection_test.dart
  test/tool/reader/fixed_layout_svg_text_test.dart --no-pub --reporter expanded:
  final exit 1, 143 passed, one failed (the boundary production hostGate).
  build/a2-svgtext-2-final-tests.log; this run regenerated the production report.
- SDK Flutter-tool test test/features/reader/engine/fixed --no-pub
  --reporter expanded: final exit 0, 123 passed;
  build/a2-svgtext-2-fixed-tests.log.
- SDK Flutter-tool test test/features/reader/engine/text/harfbuzz
  test/features/reader/engine/layout/font_face_selection_test.dart --no-pub
  --reporter expanded: exit 0, 20 passed; build/a2-svgtext-2-hb-font-tests.log.
- Text feature test alone: exit 0, 12 passed, including boundary-module-only
  B evidence; build/a2-svgtext-2-feature-tests.log. Final full fixed run also
  covers its final attribute/anchor changes.
- Scoped git diff --check: exit 0. Initial focused execution and one retry
  both exited 1 due to concurrent fixed_svg_viewport.dart missing required
  width. That owner repaired it; no out-of-scope fix here. Later runs execute.

iOS without the static library: bindings eagerly resolve shiori_-prefixed
process symbols; missing symbols fail before native HB allocation. The text
feature maps missingSymbol to svg-text-harfbuzz-missingSymbol, releases its
lease and publishes no partial scene. Existing HB tests verify eager typed
missing-symbol behavior. No GDI/platform-text fallback, static library build,
link/device claim or A5 acceptance is made in this slice.

Requests/open:
- CSS/fixed-scene owner: global styles.diagnostics becomes an unconditional
  refusal at fixed_scene.dart:209 for the boundary's font-kerning declaration.
  Provide a precise namespace/selector-aware diagnostic handoff for declarations
  fully handled by SVG text, preserving unsupported XHTML kerning behavior.
  Do not blanket-delete font-kerning diagnostics. A scope question was issued;
  absent authorization, no change to fixed_scene*.dart or engine/style/** here.
  Rerun the unchanged required row assertion after this handoff.
- Clip/mask/filter owners: coordinate per-source text effect footprints and
  fragment annotations before lifting svg-text-effect-profile.
- A3: coordinate immutable admitted bytes for converted WOFF2 faces; the
  existing accessor alone does not provide the converted-byte lease.
- Main/native owner: static HB packaging/linking and Safari/device raster
  parity remain A5 work. Required svg-text production adoption stays open.

## A2-svgsize

### Inline SVG sizing (2026-10-29)

Implemented shared CSS content-box sizing for XHTML containing blocks and
embedded SVG used viewports. Page dimensions remain independently resolved;
standalone SVG page resolution is unchanged. Percentage height in an indefinite
normal-flow containing block computes to auto (CSS 2.1 10.5), then replaced
sizing uses definite width and intrinsic ratio, or the 300x150 default object
box when there are no intrinsic dimensions. A viewBox contributes only its
ratio and content transform, never a guessed page/containing-block extent.
CSS dimensions, including explicit auto, override SVG attributes. Existing
stylesheet parsing/selectors identify declared dimensions; computed styles
remain the winning-value authority. Intrinsic/shrink-to-fit containing widths
requiring text measurement are explicitly unsupported before native allocation.
Planning freezes each used viewport in the SVG resource/geometry plan and its
root presentation; scene layout reuses that exact size. XHTML layout uses the
same content-box calculation and tracks definite height. The html root now
participates in sizing, while geometry retains body/descendant CFI anchors
because the document element has no local CFI step.

Files: fixed_preparation_plan.dart, fixed_svg_viewport.dart,
fixed_scene.dart, fixed_scene_layout.dart, fixed_scene_geometry.dart,
fixed_scene_svg.dart; new fixed_scene_sizing.dart, fixed_scene_svg_sizing.dart,
fixed_inline_svg_sizing_test.dart; mixed_svg_wrapper_regression_test.dart.
No data resolver, feature-owner file, fixed_section_preparer file/test,
engine/layout file, fixture, oracle, generator, spec or dependency was edited.

New isolated tests: 7 passed, including definite html/body/div, 50%/75%, linked
CSS percentage/absolute/auto overrides, indefinite height, containing-block
padding/border, nonzero viewBox origin, content transforms and released owners.
The synthetic mixed test now requires 23 distinct conserved sections, six
prepared fixed constituents, 320x240 SVG plan/scene viewports, one admitted
raster per fixed source, complete geometry and zero retained resources.
It still fails before preparation: its existing generated version="1.1"
attribute is rejected as svg-attribute-version by the shared graphics audit.
The five synthetic sizing variants hit that same audit. The source attribute
and new success assertions were retained; no pass was manufactured.

Anonymous private result: 5 books, 83/83 conserved sections, 1952 reflow units,
6 fixed sections/units, 0 prepared fixed sections/units, 6 SVG-kind unsupported
outcomes, 0 composition/import failures. All printed retained resource counters
are 0. This is a measured blocked result; A-AC8 is NOT closed.

Validation: installed dart.exe / flutter_tools.snapshot, --no-pub, expanded;
final commands also use --no-version-check. Scoped Trellis checks ran inline,
without subagents or a current-task pointer change.
- test/features/reader/engine/fixed + fixed_layout_corpus_test.dart +
  authored_dimension_resolver_test.dart: exit 0, 189 passed (final rerun).
- test/features/reader/engine/surface with the authorized private-input switch:
  exit 1, 83 passed / 7 failed after retry; six synthetic preparation failures
  plus the anonymous private preparation failure. All navigation/CFI tests pass.
- Scene/background/graphics/filter/clipmask/foreignObject harness combination:
  exit 1, 8 passed / 1 failed. Scene-only retry: exit 1 with the same failure.
  dimensions-unsupported is actually a valid 50%/75% inline SVG in an explicit
  320x240 XHTML page, so it now prepares. The test still expects unsupported.
  Required scene rows retain their reported gates; dimensions-boundary remains
  typed malformed, and standalone relative SVG page sizes remain unsupported.
- Scoped format --output=none --set-exit-if-changed: exit 0, 10 files unchanged.
- Scoped analyze: exit 0, no issues. Scoped diff whitespace check recorded below.
- Logs: build/a2-svgsize-fixed-final.log, a2-svgsize-surface-retry.log,
  a2-svgsize-harness-tests.log, a2-svgsize-scene-retry.log.

Requests:
- Shared SVG graphics owner: admit/audit the inert standard SVG version
  attribute in svg_graphics_plan.dart, then rerun the synthetic/private gates.
  This file is outside A2-svgsize's granted scope; no workaround was applied.
- Fixture/oracle owner: replace dimensions-unsupported with genuinely
  unsupported page dimensions and regenerate through the authorized workflow.
  Its current percentage-element case is explicitly required to succeed by
  this order; keeping that case unsupported would contradict the sizing rule.
  No fixture, expected data or gate was hand-edited. A-AC8 remains open pending
  the shared graphics fix and successful integrated preparation.

Final scoped diff --check: exit 0. Final sizing-helper format/analyze and the
7 isolated sizing tests after the fixed-position classification review: exit 0.

## A2-closeout

### Closeout (2026-10-29)

Completed the three authorized fixes. A-AC8 remains OPEN: the private gate now
passes SVG attribute admission but exposes resource refusals. No resource limit,
gate, tolerance, D-rule, feature part, layout implementation, spec, dependency,
private payload or other owner's section was changed. No subagents, network,
downloads, codegen, full-suite execution, git mutation or task-pointer mutation.

1. Added only `version` and `baseProfile` to the SVG attribute allow-list,
   documenting their inert legacy metadata semantics. A unit test admits SVG
   1.1/full and 2.0/tiny and keeps an unknown attribute explicitly unsupported.
2. SvgPresentation now records diagnostic kind/detail ownership from the raw
   declarations and matching selector namespaces, including inline declarations.
   FixedSceneBuilder hands SVG-only diagnostics to that existing module result.
   Any matching XHTML declaration (including a mixed selector list or a separate
   rule producing the same aggregate diagnostic) preserves the XHTML refusal.
   Tests prove valid sheet/inline SVG kerning reaches prepared SVG text, invalid
   kerning returns the SVG feature refusal, and XHTML kerning still refuses.
   Presentation collection is needed only when styles have diagnostics; it must
   not eagerly invoke the text-only sheet collector for ordinary image wrappers.
3. The generator keeps the valid 50%/75% inline SVG and changes only the
   dimensions-unsupported page viewport to `width=device-width,height=240`.
   EPUB 3.3 fixed XHTML uses explicit authored viewport dimensions in CSS pixels;
   a device-dependent width cannot supply a stable authored page coordinate
   system. The dimensions row requires finite positive authored page sizes.
   The existing A1 resolver explicitly returns UnsupportedDimensions with reason
   `Device-relative authored viewport`; conflicts instead return malformed and
   would not exercise this required unsupported case. Corpus and dimension
   resolver tests now assert this generated input's actual typed outcome.
   Oracle-observed inline SVG geometry remains unchanged. No expected data was
   hand-edited and no whole-file hash pin needed changing.

Regeneration and isolation evidence (SHA-256; public synthetic files only):
- corpus before/HEAD:
  bca95cf36e9ef381fb5532d7d46c3ae6bb7e9ca54e638a0453267d307049e239
- corpus after:
  746ed75288a3ab8b60b7b2eafd0c27cbec19a6ab66b86f2a5553f035ef9ba5cd
- oracle before/HEAD:
  1a13eb31ce69d198ecd068c2360ef46e5adaeb7faaa70c8b3e27733a51abd48f
- oracle after:
  84effbc0c417ac358301377e91b45821085585758375f2a4526f39c542a23fdb
- Ran fixed-corpus/fixed-oracle three times; the final two captured outputs are
  byte-identical for both files. All regeneration commands exited 0.
- Compared both pre-change working bytes and `git show HEAD:<path>` with output:
  51/51 other records are value-identical AND their original serialized JSON
  byte slices are identical in corpus and oracle. Other metadata is identical
  except the oracle's necessary derived corpusSHA256. Both pre-change working
  files were themselves byte-identical to HEAD. Only dimensions-unsupported
  record data changed; no other generated tracked file changed.
- npm run check-fixed-corpus and npm run fixed-oracle -- --check: exit 0.

Every corpus case, using the production row harnesses (P/B/N/U are positive,
boundary, nested, unsupported). PASS includes the expected typed outcome;
M is expected malformed. HOST means host checks pass with A5 raster proof open.

| Row | P | B | N | U |
| --- | --- | --- | --- | --- |
| metadata | PASS | PASS | PASS | PASS |
| dimensions | PASS | PASS (M) | PASS | PASS (typed unsupported) |
| cascade | PASS | PASS | PASS | PASS |
| box | PASS | PASS | PASS | PASS |
| text | HOST | HOST (fallback conservation) | HOST | PASS |
| paint | PASS | PASS | PASS | PASS |
| stacking | PASS | PASS | PASS | PASS |
| clip-mask | PASS | PASS | PASS | PASS |
| svg-graphics | PASS | PASS | PASS | PASS |
| svg-text | HOST | HOST | HOST | PASS |
| foreign-object | PASS | PASS | PASS | PASS |
| filters | PASS | PASS | PASS | PASS |
| mixed-navigation | PASS | PASS | PASS | PASS |

All three SVG parent-length diagnostics and path-none/path-spacing/
path-spacingAndGlyphs have passing production hostGate. Definition B maxima:
ordinary/parent .00011549540383006247, path spacing .0004843978413104107,
path spacingAndGlyphs .0004716447097303635 CSS px; clusters conserved.
Changes from before: dimensions-unsupported now produces the expected typed
unsupported page outcome instead of a valid scene; svg-text-boundary and
svg-text-boundary-webkit-parent-length hostGate changed false -> true; synthetic
preparation changed failure -> success. Other production case verdicts unchanged.
The exploratory fixed_layout_spike report still records its expected SVG-text
pixel/row FAIL; this is not replaced by the production host result. HarfBuzz
hostFidelityGate/hostD8Gate pass; SVG-text raster verdict stays device-gated (A5).
All 0.5 CSS px, D3/D4/D7/D8/D9/D10 and reference-defect scopes are unchanged.

Private gate (only anonymous printed counts, same on standalone and retry):
5 books, 83/83 conserved sections, 1952 reflow units, 6 fixed sections/units,
0 prepared fixed sections/units, 0 blanks, 1 fixed preparation failure,
0 composition/import failures. Typed outcomes: resource:capability=1,
resource:scene-admission=5; unsupported construct kinds empty. Every printed
peak/retained picture/image/scene/source resource counter is 0. Gate FAIL;
A-AC8 is NOT closed. No private identity, path, prose, CFI, image or digest copied.
Synthetic gate PASS: 23 distinct sections, six prepared fixed constituents,
complete geometry and released retained owners; standalone file 8/8 passed.

Validation (installed dart.exe + flutter_tools.snapshot, --no-pub,
--no-version-check, expanded reporter):
- Focused graphics/integration tests: exit 0, 22 passed.
- All nine requested test/tool/reader files plus fixed_layout_corpus_test.dart:
  exit 0, 81 passed. Scene harness also rerun alone: exit 0, 1 passed.
- engine/fixed + engine/surface + data/layout with SHIORI_LOCAL_EPUB_DIR set:
  final retry exit 1, 246 passed / 1 failed, only the private resource gate.
  An earlier stale dimensions-unsupported test expectation was corrected above.
- Synthetic file alone: exit 0, 8 passed. Private file alone: exit 1, same counts.
- Scoped format check (7 Dart files): exit 0, unchanged. Scoped analyze: exit 0,
  no issues. Scoped diff --check: exit 0. Trellis check performed inline.
- Logs/snapshots: build/a2-closeout/{focused,harnesses,scene-standalone,
  engine-surface-layout-retry,synthetic-final,private-final,oracle-check}.log;
  corpus/oracle-before.json and corpus/oracle-run2.json retain public proof.
  Production scene report is build/fixed-layout-native/scene-report.json;
  report.json in that directory belongs to the exploratory spike harness.

Requests: A3/scene resource owner must investigate the newly exposed fixed-page
resource capability/admission failures and reservation accounting without raising
limits or weakening gates. Resource implementation is outside this slice's scope.
Rerun the unchanged private gate before closing A-AC8. A5 raster/device evidence
remains independently open. This slice stops at that handoff.

## A3-admission

### Private sample admission (2026-10-29)

Partial correction delivered; A-AC8 remains OPEN. The baseline matches the
handoff. No cap, limit constant, refusal gate, fixture, oracle, specification,
layout-owned file or private payload was changed. No subagents or git mutations.
Private inputs were read in place; all retained measurement artifacts contain
anonymous numeric resource facts only. Throwaway probes live under ignored
build/a3-admission; no production logging was added.

Before correction, all six units use view 400 x 600 / DPR 1. Intrinsic raster
sizes equal the respective authored page sizes below. Requests are bytes except
pixel/node columns; all available capacities are the unchanged empty-ledger
defaults. These are logical payload admissions, not measured native/RSS peaks.

| Anonymous page | Authored / intrinsic | First refusal | Requested / available |
| --- | --- | --- | --- |
| 1 | 1810 x 2560 | Resource capability: svg-layerPixels | 9,106,344 / 8,388,608 pixels; corresponding bytes 36,425,376 / 33,554,432 |
| 2 | 1448 x 2048 | Scene vectorBytes | 102,831,520 / 16,777,216 |
| 3 | 1448 x 2048 | Scene vectorBytes | 102,831,520 / 16,777,216 |
| 4 | 1500 x 866 | Scene vectorBytes | 46,244,408 / 16,777,216 |
| 5 | 1150 x 1600 | Scene vectorBytes | 64,591,832 / 16,777,216 |
| 6 | 1443 x 2048 | Scene vectorBytes | 102,482,556 / 16,777,216 |

Other BEFORE-plan classes (same anonymous order):
- Scene vector bytes: 129,783,296; 102,831,520; 102,831,520; 46,244,408;
  64,591,832; 102,482,556. Page 1 is an incomplete aggregate because its SVG
  reservation already throws; do not treat that subtotal as a sufficient cap.
- Scene layer pixels: 9,267,200; 11,733,472; 11,733,472; 5,141,576;
  7,258,904; 11,692,732, against 8,388,608. Corresponding layer bytes:
  37,068,800; 46,933,888; 46,933,888; 20,566,304; 29,035,616;
  46,770,928, against 33,554,432.
- Source nodes: 22; 26; 26; 26; 26; 26, against 100,000. Source payload
  bytes: 5,632; 6,656; 6,656; 6,656; 6,656; 6,656, against 33,554,432.
- Image output AND intrinsic bytes: 18,534,400; 11,862,016; 11,862,016;
  5,196,000; 7,360,000; 11,821,056. Existing conservative decode admission
  reserves intrinsic plus output, so peaks are respectively 37,068,800;
  23,724,032; 23,724,032; 10,392,000; 14,720,000; 23,642,112, all below
  the available 50,331,648. These decodes do NOT actually start on refusal.
- Per-source picture request/ceiling is 2,097,152; unit request includes a
  further 65,536 composite ceiling, against 16,777,216 available. No private
  picture is recorded: all six refuse before image allocation, with zero
  ui.Image.onCreate events, and all retained counters/sources return to zero.
- Actual SVG used viewports are approximately 1794 x 2537.3702;
  1432 x 2025.3702 (twice); 1484 x 856.7627; 1134 x 1577.7391;
  1427 x 2025.2918. They are authored-layout viewports, not display pixels.
  Complete per-class requests/available capacities are in before.json;
  after.json also records these used sizes and zero allocation counts.

Defects and correction:
1. FixedPreparationPlan billed a full-page XHTML alpha map for every outer SVG
   root in addition to the SVG module's own coverage reservation. The fixed
   painter delegates that box directly to its SVG scene and never creates that
   XHTML alpha map. Removed only this duplicate term; SVG coverage and its
   admission remain intact. No reservation was lowered below its allocation.
2. Added fixed_svg_admission_regression_test.dart: entirely generated
   1400 x 1400 authored wrapper with an 1810 x 2560 opaque raster. The former
   request is 17,812,512 vector bytes (over 16,777,216); corrected request is
   13,892,512. It now prepares under unchanged defaults, retains real SVG alpha
   evidence and complete geometry, then double-release disposes picture/source
   and returns image/picture/scene/source counters to zero.
3. Remaining confirmed behavior: PublicationFixedSources requests intrinsic
   decode dimensions rather than displayed dimensions. SvgGraphicsPlan reserves
   authored-size coverage buffers; svg_graphics_geometry.dart::_coverage really
   allocates that authored raster. Merely lowering the plan would undercharge.
   The XHTML estimate additionally counts nonpainting head/whitespace text and
   sums its page scratch with SVG scratch; broader tightening needs separate
   allocation/lifetime proof. Those conservative terms remain unchanged.
4. Generated image-only measurements at fitted display resolution have output
   bytes 905,600; 905,600; 369,600; 891,200; 908,800 for the five distinct
   size classes. Intrinsic-plus-output peaks are 19,440,000; 12,767,616;
   5,565,600; 8,251,200; 12,729,856, within 50,331,648. This is a standalone
   decode experiment, NOT implemented product display/zoom behavior. A recorded
   image picture reports 232 bytes. Two generated full-intrinsic preparations
   report 640-byte source / 448-byte SVG / 840-byte composite pictures; decoded
   pixels do not cause the hypothesized 2 MiB picture refusal on this host.

After correction, private counts remain 5 books, 83/83 conserved sections,
1952 reflow units, 6 fixed sections/units, 0 prepared, 0 import/composition
failures, resource:capability=1 and resource:scene-admission=5. Corrected vector
requests are 120,516,096; 96,900,512; 96,900,512; 43,646,408; 60,911,832;
96,572,028. Same first refusals, zero private image allocations and retained
counters. The duplicate correction alone does not close the private gate.

Requests: the remaining essential changes require svg/svg_graphics_plan.dart
and svg/svg_graphics_geometry.dart, neither granted by this slice (only image/
layer charging in svg_graphics_prepare.dart is granted). General XHTML coverage
resolution also needs fixed_scene.dart/fixed_scene_coverage.dart. Request an
owner for those seams, then connect display/DPR and a bounded zoom policy while
preserving authored coordinates, the one-CSS-pixel alpha/proof contract and
refusal-before-allocation. Never just downsample proof or bypass reservation.
No cap increase requested: correct display-resolution behavior is not yet
implemented/proved, so a smallest design-compliant cap change cannot be claimed.
The largest current authored two-buffer SVG operation alone needs 717,736 more
pixels / 2,870,944 more bytes than its caps; this is current-algorithm evidence,
not a recommendation to raise caps or proof that the approved design cannot fit.

Validation, direct dart.exe + flutter_tools.snapshot, --no-pub,
--no-version-check --reporter expanded:
- Requested surface + fixed + data/resources + scene_resource_budget_test.dart:
  final SERIAL run exit 1, 249 passed / 1 failed, only the private admission
  gate. Existing refusal-before-allocation and release tests pass. Initial
  parallel test invocations collided in Flutter's compiler cache; that run was
  stopped and replaced by the serial result, without changing another file.
- mixed_svg_wrapper_regression_test.dart + new regression: exit 0, 9 passed.
- Private gate alone before AND after correction: exit 1, same anonymous
  counts; also included in the final serial requested-suite run.
- Generated five-size probe: exit 0, 1 passed; largest wrapper refuses with zero
  decode allocation, all cleanup assertions pass. Final private/boundary probes
  together: exit 1 (boundary passes; private gate remains the only failure).
- Scoped format/check and analyze for both owned Dart files and the two main
  build probes: exit 0, no analysis issues. Trellis check performed inline.
- Scoped git diff --check: exit 0.
- Logs and numeric reports: ignored build/a3-admission/{before.json,after.json,
  synthetic.json,requested-final-serial.log,synthetic-final.log,
  measurement-final.log}. No private source/assets or identity copied there.

Stopped after this slice. Further implementation and A-AC8 closure are blocked
by the explicit ownership boundary above, not by an approved cap-change decision.
## A2-filters-2 (continued by A2-filters-3)

#### Review round 3 fixes (2026-10-29)

Resumed and completed on 2026-10-30 as owner A2-filters-3. Audited the
unreported tests and partial filter edits directly; retained the regression
cases and corrected their implementation-specific image-count expectation.
No unexpected starting-state difference was found. Initial filters unit run
returned exit 1: 6 passed, 5 failed (the four findings plus the already-written
incomplete-geometry expectation in the repeated-instance budget test).

All four findings confirmed and addressed:
- P1 output coverage: removed the invented exact solid filter-region paint and
  the original input paint records for the filtered instance's entire subtree.
  Source fragments remain for source identity, but markIncomplete explicitly
  records unavailable filtered-output alpha coverage. This prevents transparent
  flood, composite-out and alpha-zero color matrix output from proving input
  visibility. Tests cover both leaves and filtered groups/descendants.
- P1 graph work: SourceGraphic, SourceAlpha and each primitive are materialized
  once into bounded root-space images in DAG order; input reads only replay
  cached images. Admission charges bounded work and at most 24 primitives / 256
  aggregate input reads (also bounded while parsing a single merge). Existing
  layer reservation covers two sources, N results and three scratch/output
  buffers, each limited to twice viewport pixels. Actual transformed, outward
  rounded raster dimensions are checked before graph capture/recording. Images
  belong to the scene and release exactly once on success, failure/cancellation.
  Tests exercise a 24-stage alternating blend/merge repeated-input chain,
  single-merge and aggregate input excess, transformed allocation bounds,
  exact reservation limits, and late failure/cancellation after cached results.
- P2 opacity order: moved element/group opacity outside feature wrappers in
  _paintTree, so filter then clip/mask output receives opacity; child opacity
  remains part of its parent's SourceGraphic. Three leaf/group/nested-opacity
  regression shapes give alpha 64 for the opaque flood under opacity .25.
- P2 primitive subregions: explicit objectBoundingBox coordinates/dimensions
  resolve against the filtered element bounds, then intersect the filter region.
  Regression covers numeric/percentage lengths with user-space and expanded
  objectBoundingBox filter regions, plus explicit clipping to a smaller region.

Production filters harness rerun: build/fixed-layout-svg-filters/report.json.
Row FAIL, with the existing required-row PASS assertions deliberately unchanged:
- filters-positive: FAIL (was PASS), RenderSectionCapability/incomplete-geometry.
- filters-boundary: FAIL (was PASS), same refusal.
- filters-nested: FAIL (was PASS), same refusal.
- filters-unsupported: PASS (unchanged), UnsupportedSectionCapability/svg-filter.
All variants release the shared budget to zero. Required variants publish no
picture/fragments; geometry/D4/D9 pixel comparisons are not reached, so no
current pixel/geometry parity PASS is claimed. Old PNGs in the build folder are
not fresh evidence. The 0.5 CSS px gate, D3/D4/D7/D8/D9/D10, corpus, oracle and
required cases remain unchanged. Restoring the row requires real filtered-output
alpha/source evidence, not relabeling input footprints or relaxing admission.

Validation (direct dart.exe / flutter_tools.snapshot; tests --no-pub
--reporter expanded):
- test/features/reader/engine/fixed/svg/svg_feature_filters_test.dart: exit 0,
  13 passed, including all four regressions and resource cleanup.
- test/tool/reader/fixed_layout_svg_filters_test.dart: exit 1, row FAIL above.
- test/features/reader/engine/fixed/svg: initial exit 1, 89 passed / 12 failed;
  after independent checks/added filter tests, the required single rerun exits 1,
  100 passed / 3 failed, all outside scope in svg_feature_clip_mask_test.dart:
  rotated mask region (line 311), alpha/luminance mask coverage (338), and bbox
  mask coverage (374). Each is a RangeError indexing changed coverage dimensions;
  no failure reaches the opacity wrapper. Presentation-reset failures from the
  initial run disappeared as its concurrent owner finished edits.
- Scoped analyze of the three changed Dart files: exit 0, no issues.
- Scoped format --output=none --set-exit-if-changed: exit 0, 0 changed.
- Scoped git diff --check: exit 0. SVG rerun log: build/a2-filters-3-svg.log.

Only svg_feature_filters.dart, svg_graphics_prepare.dart (opacity order), the
filters unit test and this appended continuation were edited. No harness gate,
fixture, other feature, coverage/geometry shared file, dependency, network,
sub-agent or git mutation was used. Trellis check performed inline.
Requests: coverage/clip-mask owner to align the three out-of-scope mask tests
with the new footprint dimensions; main owner to schedule filtered-output
alpha/source geometry evidence before claiming the required filters row passes.
Stopped after this slice; the four defects are repaired, while row closure and
the three external test failures remain explicitly open.
## A2-svg-misc

### Review round 3 fixes (2026-10-29)

Resumed, audited and completed this slice on 2026-10-30. The three production
files and inherited tests matched the supplied partial state. Kept the valid
regressions, corrected the scene-root/color-printer test assumptions, and added
lower-priority reset controls, URL-form imports and extra constraint cases.
Used trellis-start, trellis-before-dev and trellis-check inline for the named
in-progress task; the absent session pointer is expected. No task creation,
subagents, git mutation, network, dependency, fixture, gate, spec or other
owner's implementation changes were made. Only the six scoped Dart files and
this appended section were edited; build logs are ignored artifacts.

Findings verified and fixed:
1. CONFIRMED: presentationIgnored discarded effect resets before selection.
   SvgPresentation retains those no-effect values as none through specificity,
   source order, inline and important selection, so the winning reset overrides
   both earlier declarations and the presentation attribute. Nine preparation
   regressions cover filter/clip-path/mask resets; three controls prove a weaker
   reset cannot disable the winning effect. Audit also exposed csslib's legacy
   IE filter parser consuming none !important. A shared SVG parser entry point
   temporarily aliases filter property identifiers, preserving source offsets,
   comments and strings, then restores those identifiers before cascade and
   diagnostics. The text sheet collector uses the same entry point.
2. CONFIRMED: linked CSS was read from archive root and inline imports had no
   base. Resolve links against page.stableId and imports against their declaring
   sheet using resolveUrl, stripping the fragment as the existing style resolver
   does. Reuse CssSheetBuilder.matchesMediaAttribute with authored dimensions for
   links, styles and imports; alternate/external/non-CSS/ineligible sheets skip.
   The production loader rewrites inline import URLs to resource tokens, so
   recover authored style text by ordinal from the section resource, following
   CssStyleResolver's existing recovery/fallback behavior. This does not change
   projected source nodes, offsets, canonical v1 or CFI. Three tests exercise
   linked, quoted inline and url() inline imports, nested relative directories,
   fragments, viewport media and absent ineligible resources. Existing injected
   source integration tests also pass with the original-text fallback.
3. CONFIRMED: independent clamping broke the dependent auto dimension. Constrain
   a definite axis before deriving its auto partner from the intrinsic ratio;
   constrain that partner separately. For two auto axes, choose the CSS 2.2 10.4
   common scale, then enforce each limit when cross-axis constraints conflict.
   Explicit dimensions remain independently constrained. Nineteen constraint
   vectors cover min/max, width/height symmetry, both-auto limits, conflicting
   limits and min-over-max precedence. The reported 320px / 4:3 case is 100x75.

Validation (all tools use D:/DevTools/flutter/bin/cache/dart-sdk/bin/dart.exe;
Flutter tests invoke D:/DevTools/flutter/bin/cache/flutter_tools.snapshot with
--no-pub --reporter expanded):
- Before fixes: test the three scoped test files, exit 1, 8 passed / 21 failed;
  corrected/reset controls alone remained red: exit 1, 3 passed / 9 failed.
- Initial fixed focused run: same three files plus reset controls, exit 0,
  32 passed. Final expanded run below contains all 38 current focused tests.
- Test test/features/reader/engine/fixed/svg plus
  fixed_svg_text_stylesheet_test.dart, fixed_svg_viewport_test.dart,
  fixed_inline_svg_sizing_test.dart and fixed_scene_svg_integration_test.dart:
  first exit 1, 138 passed / 5 failed; corrected original-text fallback, then
  reran once: exit 1, 140 passed / 3 failed. All 38 scoped focused tests and
  sizing/integration tests pass. Remaining failures are exclusively the external
  svg_feature_clip_mask_test.dart cases: rotated mask region (311), alpha and
  luminance mask coverage (338), and bbox mask coverage (374). They directly
  index coverage using an old 100px stride despite actual footprint dimensions,
  raising RangeError. Their helper bypasses all three modified production files.
  The concurrent A2-filters-3 continuation independently records these failures.
- Required harness command, before AND after fixes: test
  test/tool/reader/fixed_layout_svg_test.dart,
  fixed_layout_svg_text_test.dart, fixed_layout_svg_foreign_object_test.dart,
  fixed_layout_scene_test.dart and
  test/features/reader/engine/surface/mixed_svg_wrapper_regression_test.dart:
  exit 0, 15 passed on each run. Graphics/foreignObject/scene required verdicts
  and the synthetic mixed preparation verdict remain PASS; SVG text hostGate
  stays true, with raster verdict still device-gated (A5). No requested verdict
  changed, and no tolerance or required row was relaxed.
- Additional final harness command adds fixed_layout_svg_filters_test.dart and
  fixed_layout_svg_clipmask_test.dart to that set: exit 1, 16 passed / 1 failed.
  Clip/mask and every required command member still pass. Filters row FAIL:
  positive/boundary/nested refuse incomplete-geometry; unsupported stays PASS.
  This matches A2-filters-3's independently documented verdict change caused by
  removing invented filtered-output coverage, and is outside this patch.
  Single-file filters retry: exit 1 before test execution because another
  process holds build/native_assets/windows/sqlite3.dll; no process was killed.
- Scoped dart format --output=none --set-exit-if-changed, six files: exit 0,
  zero changes. Scoped dart analyze, same files: exit 0, no issues.
- Scoped git diff --check, changed tracked Dart paths: exit 0. Untracked files
  were directly read and covered by scoped format/analyze/tests.
- Logs: build/a2-svg-misc-{before,reset-before,after,tests,tests-retry,
  harness-before,harness-after,harness-final,filters-retry,analyze}.log.

Requests: A2-coverage/main owner to coordinate updating the three mask tests to
sample the actual coverage dimensions/transform. Main owner to retain the open
filters required-row failure until real filtered-output alpha/source evidence
is implemented, as A2-filters-3 requests. The retry's native-assets DLL lock is
an additional concurrent-run limitation, not a passing filters result. A5 device
raster evidence remains open. Stopped after this slice; no broader S4a closure
is claimed.

## A4-probe-fix

### A4 segment 2 (continued; owner A4-probe-fix)

#### Review round 3 fixes (2026-10-29)

Resumed and completed on 2026-10-30. Audited the interrupted owner's controller,
screen and fixed-route tests against checkpoint 4f52269, the existing fixed
sources/composition and real-session test support. The expected four illegal
`implements` declarations were present; replaced them with real final-class
instances rather than changing any class modifier or adding a mocking seam.
The queue/lifetime regression now uses the actual shared PrepareBookQueue and
ReaderPublicationLifetime. All three review findings were confirmed before
controller edits: the compilable regression run exited 1 (six failures), exposing
the queue stall, wrong turn shutdown and mixed layout identities after input
changes. The retired-route regression separately failed before its screen fix.

1. P1 shared queue: retire the old reader before requesting another lifetime.
   Clear its displayed session/turn and notify so the widget detaches; wait for
   its frame when scheduled, close/drain its session and own motion controller,
   then release its fixed sources and previous reflow owner. Concurrent requests
   share that retirement barrier. `releasePublication` also applies the barrier
   before the screen calls S3 prepare, which uses the same queue. Failed
   replacement retains the exact accepted TurnPosition and publishes no new
   position; the retired display remains cleared. Regressions cover two real
   opens on one queue, worker failure preserving accepted, another real S3
   preparation, and replacement with a mounted PreparedReader.
2. P1 shutdown capture: each session hook captures its local candidateTurn,
   never the mutable public controller.turn. The real-turn regression replaces
   that public field, closes the session, and verifies only its own turn closes.
   Disposal now lets session shutdown own the composition/source barrier before
   closing the fixed source owner; removed delayed reflow cleanup that read
   mutable fixed-owner fields.
3. P2 request identity: capture width, height, DPR and immutable ReaderSettings
   once. All fixed layout closures, composition, theme and turn width use that
   snapshot. Input setters and settings requests revoke the request generation;
   openPublication checks its token/activation before retirement, after each
   preparation await and immediately before publication. Published source
   loaders retain their original layout inputs. Rejected candidates use one
   finally cleanup path; an existing candidate closes through its session's
   adapter barrier, with no second composition disposal. Stale failures return
   false silently. The screen falls back only for reflow-only publications.
   Regressions cover lease-gated width/height/DPR/settings/disposal, identical
   request supersession, paused real source-preload races (including resize
   back), an actual candidate revoked during turn setup, frozen later source
   loading, and stale fixed-route refusal. Independent lease callbacks release
   exactly once and the real queue becomes idle.

Validation uses D:/DevTools/flutter/bin/cache/dart-sdk/bin/dart.exe directly;
Flutter tests use D:/DevTools/flutter/bin/cache/flutter_tools.snapshot.
- Fixed-route regression file: 18 tests in final directory run; all pass.
- `flutter_tools.snapshot test test/features/diagnostics test/features/reader/engine/surface --no-pub --reporter expanded`: exit 0, 248 passed.
  SHIORI_LOCAL_EPUB_DIR was explicitly removed in the command's child shell;
  existing suites may still discover their documented default local inputs.
  Log: build/a4-probe-fix-tests.log (ignored local output).
- `dart analyze` on reader_probe_controller.dart, reader_probe_screen.dart and
  reader_probe_fixed_route_test.dart: exit 0, no issues.
- `dart format --output=none --set-exit-if-changed` on the same three files:
  exit 0, 0 changed. Scoped `git diff --check`: exit 0.

Only those three Dart files and this appended owner section changed in this
slice. No class modifiers, fixed/geometry/layout code, library schema, fixture,
spec, dependency, codegen, network, git mutation or sub-agent work was used.
Requests: none. Stopped after this review-fix slice; no wider S4a/A5 acceptance
or task completion is claimed.


## A2-coverage

### Lossless uniform coverage (2026-10-29)

Resumed/audited on 2026-10-30. PARTIAL slice: lossless storage and consumer
compatibility are implemented and checked; exact shared-ledger charging remains
open at the ownership boundary below. Required host/private gates remain open.
The previous session's partial edits were the starting state, not a divergence.
No cap, gate, D-rule, fixture, oracle, spec, dependency, image decode/layer scale,
layout-owned file or private payload was changed by this slice.
No subagents, code generation, download, network access or git mutation was used.

Audit and representation:
- XHTML decoration/text pictures formerly retained page-sized alpha grids;
  planning also counted nonpainting whitespace/head/source nodes. SVG billed
  source-node-count times page pixels, although containers/definitions retain
  no independent paint footprint. The duplicate outer-SVG XHTML term remains
  removed. Mask readback and clip-copy payloads were additional grid producers.
- GeometryAlphaFootprint.uniform stores one byte value plus the rectangle's
  authored sample dimensions/origin/pixelSize and existing grid-to-unit matrix.
  A read-only virtual List<int> preserves every existing indexed alpha read;
  placement and withMasks share the same immutable samples. Logical retained
  accounting is 128 bytes plus explicit-grid bytes, with no uniform grid.
- fromRgba/fromSamples classify borrowed samples and trim only zero margins.
  Retained payload admission precedes allocation. Nonuniform grids keep every
  original one-CSS-pixel sample, including AA; no downsampling or enclosing-box
  substitution. alphaAt inverse-maps unit points; singular placement is unknown.
- XHTML integer-aligned solid backgrounds avoid alpha rasterization. Other
  decoration/image/border/text paints classify the actual native readback.
  SVG integer-aligned solid unrounded/strokeless rects use one native alpha
  sample only after analytic eligibility; rotations/fractional edges fall back
  to exact readback. Opaque raster images, alpha/luminance masks and rectangular
  clip results compress whenever their retained samples prove uniform. Clip
  composition no longer allocates a temporary full grid for an analytic result.
- Every alpha reader was audited: fixed_position_proof indexed iteration and
  inverse mapping, scene/foreignObject/text harness metrics, SVG clip composition
  and mask attachment. The virtual view preserves these reads. Mask harness and
  its tests now sample through alphaAt instead of hardcoded page row strides.
  Existing mask/group proof policy was not broadened or silently replaced.

Equivalence and lifetime evidence:
- Five pure geometry tests cover alpha values 0/1/32/128/254/255, equality/hash,
  immutable views, translated/rotated/scaled/skewed placement, clip/mask ids,
  opacity groups, inverse samples, fractional pixelSize, trimming and refusal.
- Five native coverage tests compare every authored pixel for solid rectangles,
  fractional/rotated AA, opaque color-varying images, transparent holes, rectangle
  clips and composed mask/group output against independent native controls.
  The interrupted test's .5 SVG mask is natively 127, not its old expected 128;
  the test now compares against the independent control's actual native alpha.
- Refusal before native image creation and idempotent cleanup return all local
  ledger counters to zero. Existing wrapper integration double-release checks
  also pass. No scratch probe is imported by production code or committed tests.

Reservation measurements (bytes; BEFORE snapshot versus this shared checkout).
Each cell orders positive, boundary, nested, unsupported; these are independent
per-case admission requests, not simultaneously retained totals. Clip/mask copy
upper bounds can increase; none was reduced below a possible stored allocation.

| Corpus row | Before | After |
| --- | --- | --- |
| metadata | 410112, 410112, 410624, 410112 | 179840, 179840, 180352, 179840 |
| dimensions | 2499040, 90624, 2499648, 90624 | 2268768, 90624, 2269376, 90624 |
| cascade | 463872, 495104, 464384, 488960 | 233600, 264832, 234112, 258688 |
| box | 818176, 717312, 657920, 668160 | 357632, 333440, 274048, 284288 |
| text | 1112576, 596480, 1113088, 1129472 | 575616, 366208, 576128, 592512 |
| paint | 950272, 985088, 950784, 972800 | 489984, 524800, 490496, 512512 |
| stacking | 632320, 651776, 632832, 649216 | 325376, 344832, 325888, 342272 |
| clip-mask | 3279776, 3288992, 3280288, 262144 | 3973920, 3983136, 4051360, 108544 |
| svg-graphics | 6478560, 7937120, 6637312, 269824 | 3408480, 4023136, 3490560, 116224 |
| svg-text | 2894816, 2906080, 2895328, 2911712 | 2280544, 2291808, 2281056, 2297440 |
| foreign-object | 3350880, 3361120, 3351392, 2985376 | 2275808, 2286048, 2276320, 2217376 |
| filters | 4141568, 4141888, 4142400, 265216 | 2298496, 2298816, 2299328, 111616 |
| mixed-navigation | 712704, 712704, 713216, 722432 | 329088, 329088, 329600, 338816 |

52-case totals: 93,614,336 -> 62,843,136; maximum 7,937,120 -> 4,051,360.
Synthetic 1400x1400 wrapper: 13,892,512 -> 4,092,640 planned vector bytes
(17,812,512 before the earlier duplicate-outer-SVG correction). With the original
portrait raster's fractional letterbox edges, retained evidence is 990x1400,
1,386,128 bytes. An otherwise identical square opaque raster retains 128 bytes
for all 1400x1400 samples; its conservative shared plan is still 4,092,640.

Private gate (anonymous numbers only; unchanged 8,388,608 layer-pixel cap):

| Page | First outcome after | Requested pixels | Planned vector bytes after |
| --- | --- | --- | --- |
| 1 | svg-layerPixels | 9,106,344 | n/a: SVG reservation already refused |
| 2 | layerPixels | 11,733,472 | 5,034,288 |
| 3 | layerPixels | 11,733,472 | 5,034,288 |
| 4 | prepared | 5,141,576 admitted | 3,404,748 |
| 5 | prepared | 7,258,904 admitted | 3,922,508 |
| 6 | layerPixels | 11,692,732 | 5,023,134 |

Pages 2-6 before vector requests were respectively 102,831,520; 102,831,520;
46,244,408; 64,591,832; 102,482,556 against 16,777,216. No vector refusal
remains. Pages 4/5 each retain uniform coverage in 128 bytes (1476x849 and
1126x1570 sample rectangles). Other pages allocate zero native images on refusal.
83/83 sections conserved, 6 fixed sections, 2/6 fixed preparations successful;
all retained picture/image/scene/source counters return to zero. Layer scale is
part (2), deliberately untouched; the private gate is FAILED, not waived.

Validation (direct dart.exe/flutter_tools.snapshot, --no-pub, expanded, -j 1):
- data/geometry + engine/fixed: exit 1, 190 pass / 1 fail. The remaining failure
  is fixed_section_preparer_test's unsupported SVG before-read assertion:
  expected zero resource reads, actual one. Isolated rerun also fails. The
  out-of-scope FixedSvgTextFontService._presentation reads the raw section to
  recover styles during planning; this slice does not alter that path/test.
- All fixed_layout_*_test.dart + harfbuzz_probe_test + fixed_layout_corpus_test:
  exit 1, 81 pass / 1 fail. Filters positive/boundary/nested now refuse with
  incomplete-geometry in the concurrent filter owner's file. Isolated retry
  fails too. Other stored report verdicts match BEFORE exactly, including A5
  device-gated text. Unknown filtered coverage continues to fail closed.
- The earlier row/corpus + data/cfi + data/canonical command: exit 1, 294 pass /
  1 filter failure; all 213 CFI/canonical cases pass.
- engine/surface with private inputs enabled: exit 1, 90 pass / 1 private gate
  failure (above). No other surface failure; reflow admission passes.
- Final uniform geometry/native plus square wrapper: exit 0, 11 pass. Original
  wrapper + 52-case reservation probe: exit 0, 2 pass. Clip/mask suite and row
  harness pass after changing absolute sample access to alphaAt.
- Scoped format check, analyze and diff --check: exit 0, no issues. Flutter
  tests use a session-local APPDATA config/build directory under ignored build/
  because another session held the default native sqlite library open. No
  shared Flutter configuration was changed.

Open requests / ownership boundary:
1. Task 3's exact shared reservation is NOT complete. XHTML suballocation already
   admits actual storage bytes, but the shared FixedPreparationPlan and SVG base
   reservation retain safe predecode upper bounds. Inspect cannot know raster
   alpha, and prepare may override placement (making a rect nonuniform). Simply
   lowering these plans to 128 would undercharge; an attempted static tightening
   was audited and removed. Completing exact charging needs authorized coverage
   callbacks/reconciliation through svg_graphics_prepare.dart,
   fixed_section_preparer.dart, FixedSceneAdmission and the shared unit ledger.
   Those edits were requested asynchronously and not authorized in this run.
2. Owning sessions must resolve the filter unknown-coverage host failure and the
   raw-section read-before-refusal failure, then rerun their affected gates.
3. Remaining four private layer admissions belong to display-scale part (2).

Ignored evidence: build/a2-coverage/{before,after}-reservations.json,
wrapper-reservations.json, wrapper-square-reservations.json,
verdict-comparison.json, private-detail/report.json and *-final.log. The private
report contains anonymous resource numbers only. This slice stops here without
claiming the whole task, exact shared accounting, or host/private gate complete.

## A2-filters-4

#### Filtered-output evidence (2026-10-30)

Status: BLOCKED at the shared SVG lifecycle boundary; filtered-output evidence
is not implemented and the filters row remains FAIL. The starting filter state
matches the handoff. Only this appended section was edited by this owner.

Readback audit:
- `_drawFilter` materializes SourceGraphic, SourceAlpha and each primitive in
  `use.images` during `SvgFilterFeature.paint`. The final cached primitive image
  is still before element/group opacity, outer clip/mask wrappers and final
  linearRGB conversion. Reading it alone cannot attest post-opacity output.
- `svg_graphics_prepare.dart` runs synchronous `feature.geometry` and
  `featureCoverage.require` BEFORE `_paintTree`. The latter runs the filter DAG
  and applies element/group opacity outside feature wrappers. The complete
  post-opacity output currently exists only in the final scene picture, which
  also contains unrelated sibling paints; reading that picture cannot identify
  each filtered instance's output.
- Installed Flutter's `ui.Image.toByteData` returns `Future<ByteData?>`;
  `toImageSync` does not provide synchronous alpha readback. No awaited
  post-paint feature callback exists. An async-void geometry override or an
  unawaited readback would publish geometry before evidence/admission finishes
  and would break cancellation/drain/release guarantees. Neither was added.
- Once an isolated final instance capture is available, rasterize its outward
  rounded root/unit-space filter bounds at pixelSize=1, independent of display
  scale. `fromRgba` can classify/trim these borrowed native samples with origin
  equal to the rounded bounds' top-left and identity grid-to-unit placement in
  that space; subsequent unit placement composes the existing footprint matrix.
  Do not apply the filtered node's local transform again. Preserve opacity and
  mask provenance so consumers do not apply captured effects twice.
- Retained evidence must be charged before allocation through the existing
  filter admission/preparation lease path (worst case 128 + 2*viewportPixels
  per admitted instance, then classify actual storage before copying). Existing
  cached stage/scratch layer admission alone does not charge retained vector
  alpha payload. New evidence has not been allocated or charged in this slice.

Incomplete cases retained: missing source graph, unavailable source bounds,
and all filtered outputs pending the awaited readback seam. Source paint for
the entire filtered subtree stays removed. Existing transparent-output tests
continue to prove that source evidence cannot claim visibility; they do not
prove newly available filtered-output evidence. No new evidence tests were
added because the production lifecycle prerequisite is unavailable in scope.

Validation, using direct dart.exe and flutter_tools.snapshot:
- `test test/features/reader/engine/fixed/svg
  test/tool/reader/fixed_layout_svg_filters_test.dart --no-pub --reporter
  expanded`: exit 1, 103 passed / 1 failed. All SVG-directory tests pass,
  including all 13 existing filter tests; only the required filters harness
  assertion fails. No outside-owner failure or sqlite DLL failure occurred.
- Fresh `build/fixed-layout-svg-filters/report.json`: positive FAIL, boundary
  FAIL, nested FAIL, each RenderSectionCapability / incomplete-geometry;
  unsupported PASS, UnsupportedSectionCapability / svg-filter. Every variant
  has budgetUsedZero=true. Required cases publish no picture/fragments, so
  geometry/D4/D9 comparisons are not reached and no fresh pixel PASS is claimed.
- `format --output=none --set-exit-if-changed` on svg_feature_filters.dart,
  its unit test, filters harness test and filters harness driver: exit 0,
  0 changed. `analyze` on the same four files: exit 0, no issues.

Requests: the shared SVG owner must provide an awaited post-paint evidence
finalization hook in svg_feature_hooks.dart / svg_graphics_prepare.dart, before
featureCoverage.require and SourceGeometry publication. It must expose or
capture each filtered instance's final root-space output after its wrappers
and opacity, with explicit ancestor opacity/mask provenance, and preserve
scene-owned pictures, preallocation admission, cancellation checks and draining
before release. Then this owner can attach real fromRgba/fromSamples evidence
and add the requested output/admission regressions entirely in the filter
files. These shared files are outside this order's edit scope; no workaround,
scope expansion, geometry API addition, gate relaxation or display-scale edit
was made. No subagents, commit/push/stash/reset/checkout, dependencies,
downloads or network access were used.

## A3-woff2

### WOFF2 (2026-10-30)

Delivered the scoped pure-Dart decoder/conversion slice. This closes the
FontRegistry WOFF2 conversion refusal, with real SFNT shaping and HarfBuzz
proofs. It does not close A3/A2/A5 or the separate SVG font-owner integration
request below. The initial untracked 898-line Brotli decoder and dictionary
artifacts matched the resume description; their correct pieces were retained.
No task pointer, git mutation, third_party input, pre-existing fixed_layout
fixture, dependency, network operation, native decoder or other owner's source
was changed. No subagents were used.

Design and audit repairs:
- RFC 7932 input/output bounds, windows 10..24, compressed/uncompressed/metadata
  blocks, simple/complex prefix codes, literal contexts, context maps/MTF,
  block switching, command/distance codes and all 121 dictionary transforms.
  Code-length-code reading honors HSKIP, stops exactly at zero space, rejects
  negative/incomplete multi-symbol space, and handles a single nonzero symbol.
- Removed every BROTLI debug print, unused reverse/length/transform declarations
  and the unsafe 15-bit boundary-retry path. Block-type counts/trees/lengths
  are read in category order; block lengths use their actual prefix trees.
  Repeated code lengths are accounted as deltas while reading, final-byte
  padding cannot hide trailing input, and length canonicality checks use the
  most significant encoded nibble/byte. Prefix reading never peeks beyond
  the number of bits actually required.
- The dictionary remains generated from the pinned 122784-byte binary. Its
  SHA-256 is checked lazily on first dictionary use as well as by the generator.
  UTF-8 affixes include the two-byte NBSP. The generator received formatting
  only; the already generated embedded bytes were preserved, not copied.
- WOFF2 single-face header/directory, 63 known tags plus explicit tags,
  UIntBase128/UInt255, unique tables, legal/null transforms, matching glyf/loca
  and head index formats, metadata/private bounds/alignment/non-overlap and
  padding are validated. Collections produce typed unsupportedFormat.
- One exact-size Brotli stream supplies all tables. glyf/loca reconstruction
  handles every triplet flag, both curve states, computed/explicit bboxes,
  composites/component transforms/instructions, empty glyphs and overlap.
  overlapSimpleBitmap is LSB-first; bboxBitmap is MSB-first. hmtx supports each
  omission combination, deriving xMin from reconstructed or null-transformed
  glyf. Checksums and head.checkSumAdjustment are rebuilt.

Bounds and lifetime:
- Input/output and total transformed stream: 32 MiB; individual original,
  transformed and reconstructed tables: 16 MiB; table count: 128. Brotli
  supports caller-supplied exact or maximum output and a separate input cap;
  no growing output list or per-byte output allocation is used.
- Reserve the temporary stream from the existing ReaderResourceBudget before
  decoding. For transforms, reserve fixed typed glyph scratch (65536 points)
  and per-glyph loca/xMin arrays before allocation. A validating size pass
  determines actual reconstructed SFNT sizes; reserve that exact additional
  buffer before allocating/emitting it. Temporary charges release on return;
  all charges roll back on failure. These are shared encoded-owner charges,
  not an independent conversion capacity or a process-RSS claim.
- ConvertedFont retains its SFNT charge through physical native-load drain.
  FontRegistry uses the same process-byte/face admission/coalescing and typed
  required-font/reflow-fallback behavior as WOFF 1.0. Cancellation abandons a
  waiter only; tests retain both converted buffers while a shared registration
  is pending and release them only after drain. Native failure releases the
  conversion charge but preserves the process owner's uncertain registration.

Files, relative to repository root:
- lib/features/reader/engine/layout/brotli_{decoder,dictionary,huffman}.dart;
  retained/generated brotli_dictionary_data.dart; formatted
  tool/fonts/brotli_dictionary.dart.
- lib/features/reader/engine/layout/woff2_{decoder,binary,directory,glyf,points,
  metrics}.dart; font_registry.dart WOFF2 routing only; woff_decoder.dart shares
  ConvertedFont admission and SFNT checksum/padding helpers. font_format.dart
  needs no enum change: existing typed failures/RequiredFontException are used.
- test/features/reader/engine/layout/{brotli_decoder_test,woff2_decoder_test,
  woff2_directory_test,woff2_transforms_test,woff2_harfbuzz_test,
  woff2_glyph_test_support,woff2_test_support,font_admission_test}.dart.
- test/fixtures/reader/fonts/: generators, provenance README, manifests,
  39 .br vectors, random.bin, structural/dictionary oracle pairs and one
  generated transformed Roboto WOFF2 (71476 bytes).

Vector provenance and proofs:
- Installed Git for Windows Brotli 1.2.0, D:/DevTools/git/mingw64/bin/brotli.exe;
  no runtime test dependency. 39 vectors span qualities 0/1/4/5/6/9/11 and every
  window 10..24. Independent bit-level HSKIP=3 space/single-symbol and metadata
  frames, plus all dictionary transforms 0..120, were decompressed by the
  native CLI to obtain expected bytes. Generation commands are in fonts/README.
- Existing Roboto WOFF2 uses null glyf/loca transforms. All 18 tables match the
  pinned SFNT byte-for-byte after zeroing head.checkSumAdjustment; the full
  converted checksum is 0xb1b0afba and the SFNT is 171676 bytes. Its decoded
  171363-byte Brotli stream matches the native oracle SHA-256 recorded in README.
- An independent stdlib Python forward transform of the pinned SFNT creates
  roboto-transformed.woff2, compressed with Brotli -q 11 -w 22. SHA-256:
  7d3b5f7711e07776590b156703e47fe9995d6d46f7700badcfae75237454acd8.
  All 1294 semantic glyphs match: coordinates, on-curve flags, contour endpoints,
  overlap, bounding boxes, instructions and composite bytes; unaffected metric
  and layout tables match byte-for-byte. Different glyph padding/loca offsets
  are not treated as outline differences.
- Paragraph shaping at 20px: original WOFF2 conversion, transformed WOFF2
  conversion and SFNT control each measure 72.763671875px for Ab fi e-combining-
  acute Z; absent family measures 180px. The existing Windows HarfBuzz 14.6.0
  host module opens both converted buffers; glyph IDs/clusters/advances/offsets
  equal the SFNT and the advance is exactly 72.763671875px. Native HB resources
  and buffers return to zero in its test ledger. This is host proof only.
- Additional Dart-framed stored-block fonts cover all 128 triplet flags,
  explicit/computed bbox, short/long loca, all hmtx omissions (including null
  glyf), UInt255 alternatives, 65535-byte composite instructions, malformed
  directories/transforms, caps, admission rollback, native failure and drain.

Validation, repository root; SDK executables used directly throughout:
- python test/fixtures/reader/fonts/generate_brotli_vectors.py: exit 0.
- python test/fixtures/reader/fonts/generate_dictionary_vectors.py: exit 0.
- python test/fixtures/reader/fonts/generate_woff2.py: exit 0.
  A second generation/hash audit confirmed all 44 vector artifacts byte-identical.
- D:/DevTools/flutter/bin/cache/dart-sdk/bin/dart.exe
  tool/fonts/brotli_dictionary.dart --check: exit 0; pinned length/SHA match.
- Same dart.exe format --set-exit-if-changed <20 owned Dart files>: exit 0,
  zero changes. Same dart.exe analyze <same 20 files>: exit 0, no issues.
- Same dart.exe D:/DevTools/flutter/bin/cache/flutter_tools.snapshot test
  <brotli_decoder_test,woff_decoder_test,woff2_decoder_test,woff2_directory_test,
  woff2_transforms_test,woff2_harfbuzz_test,font_admission_test> --no-pub
  --reporter expanded: exit 0, 71 passed, no skips.
- Same direct Flutter test command for test/features/reader/engine/layout:
  exit 0, 149 passed, no skips. No full suite/build_runner/broad format ran.
  Owned-file manifest and final logs: build/a3-woff2/.
- Earlier own-test failures were repaired: PowerShell-to-Python encoding of
  multilingual generator input, an incorrect test-only HbLedger getter, and
  analyzer style infos. No concurrent-owner failure needed a retry or repair.

Requests / open issues:
- A2-svg-misc: fixed_svg_text_fonts.dart still explicitly throws
  RequiredFontException('svg-text-font-woff2') around line 200. Replace that
  owned branch with Woff2Decoder(maxBytes: registry.maxFontBytes).decode(...,
  budget: registry.conversionBudget), preserving its existing ConvertedFont
  ownership/drain lifetime as for WOFF 1.0. This file was read only. The new
  standalone HarfBuzz advance proof does not claim that production SVG branch
  is already integrated.
- Collections remain intentionally typed unsupported. Decode wall time on
  iPhone, opaque native font allocations/RSS, device fallback and A5 acceptance
  remain unmeasured. Conversion is synchronous with finite byte/table/work
  bounds; no device-time or frame-budget claim is made.

Stopped after this owner slice; no task completion/archive or later phase claim.

## A2-clipmask-3

### Review round 3 remainder (2026-10-30)

Owner A2-clipmask-3 resumed the named in-progress task in expected degraded
pointer mode. Used trellis-start, trellis-before-dev and trellis-check inline.
Bounds and the reported read-before-refusal failure are fixed. D9's classifier
and regressions are implemented, but production harness argument wiring and
one existing test's evidence input remain REQUESTED below; this slice does not
claim complete D9 integration or a passing graphics row.

Findings and changes:
- CONFIRMED: _localBounds walked source children, giving empty use bounds.
  It now traverses node._instance's expanded tree and maps each descendant
  through the inverse owner transform. This retains actual use x/y, nested
  references, target transforms and symbol viewport overrides. Shape/image
  leaf bounds use the same instance geometry as painting; layer sizing is
  unchanged. Six new clip/mask regressions cover direct use, nested use and
  symbol targets under objectBoundingBox units, with ancestor/owner transforms.
  Each checks [20,20,30,60] effect bounds, opaque/transparent native pixels,
  retained alphaAt samples and zero remaining budget after disposal.
- CONFIRMED: the D9 helper skipped text/foreignObject without fillPath, allowing
  underlying gradients to supply the sample exemption. It now orders published
  GeometryPaint records and reads alphaFootprint.alphaAt, clip evidence and mask
  coverage before resolving the matching SVG fill/stroke role. Text, foreign
  paint without a unique SVG role, raster images, missing evidence and singular
  mappings require exact samples. Zero alpha can reveal the underlying paint;
  a gradient exemption still needs matching native and reference gradient paint.
  No pixel value selects a paint class. Missing paints default to exact samples.
  Two new harness-helper regressions use actual FixedSectionPreparer output:
  a solid SVG O glyph and a black foreignObject block over a gradient. Delta-1
  samples fail on covered foreground and pass on uncovered gradient; absent or
  singular foreground footprints fail closed. These tests include real uniform
  and trimmed/native footprints, rather than assuming a page row stride.
- CONFIRMED: FixedSvgTextFontService._presentation read the raw chapter for every
  style element during planning. Authored-style recovery is now lazy and only
  requested for eligible inline sheets with imports; ordinary projected rules
  and irrelevant font-face URL tokens reuse the already loaded document.
  The original preparer test is unchanged and now observes zero reads on refusal.
  A new read-spy regression checks inline font-kerning/fill plus ineligible sheets
  without a raw chapter read. Existing linked/quoted/url-import base/media tests
  still pass. Linked/imported styles continue to resolve when actually required;
  this does not assert globally read-free resource-dependent CSS planning.

Harness reports (before and after captured under build/a2-clipmask-3):
- clip/mask: PASS -> PASS; all four variants pass, twelve solid samples delta 0.
- foreignObject: PASS -> PASS; all required cases/static control retained.
- SVG text: hostGate true -> true, all ten cases; raster verdict stays
  device-gated (A5), twenty-four solid samples delta 0.
- graphics: module report pass true -> false, boundary only. Existing callers do
  not supply paints, so two gradient samples with delta 1 now classify solid and
  fail exactly; other cases remain passing. fixedPass stays true, but its current
  wrapper assertion does not establish the failed module sample gate. This is
  an integration gap, not an accepted verdict or tolerance change. The proposed
  four argument additions have NOT been applied outside the granted file scope.

Validation (direct installed dart.exe / flutter_tools.snapshot; tests use
--no-pub --no-version-check --reporter expanded -j 1):
- Regression-first run: clipmask unit, new samples, existing preparer and four
  requested tool tests, exit 1: 33 pass / 9 fail. Failures were the six new bounds
  cases, two real text/foreignObject D9 cases and unchanged zero-read assertion.
  Baseline harness reports passed before fixes.
- Initial standalone new stylesheet-test attempt, exit 1 at loading due to
  concurrent shared SVG coverage signature edits. Its subsequent combined run
  also exposed two local syntax/declaration errors, which were fixed here.
- Final focused four files (clipmask unit, preparer, stylesheet, samples), exit 0:
  39 passed. All new regressions and unchanged preparer assertions pass.
- Final required fixed directory + new samples + four requested tool tests,
  exit 1: 186 passed / 1 failed. All 178 fixed-directory tests passed. The only
  failure is existing fixed_layout_svg_test's hidden/clipped/transparent D9 unit
  input, which supplies no paints but expects a gradient exemption.
- Earlier combined run, exit 1: 187 pass / 2 fail, also included the concurrent
  A3-scale tiled_coverage_test alpha-equivalence failure. Its one isolated retry
  exited 1 at loading during that owner's coverage signature edits. That owner
  subsequently removed the transient test/changes; the final command above has
  no external loading or fixed-directory failure. No outside file was edited here.
- Scoped dart format --output=none --set-exit-if-changed: exit 0, six files,
  zero changes. Scoped dart analyze: final exit 0, no issues. Scoped git diff
  --check and direct untracked-file whitespace review: exit 0.
- Evidence: build/a2-clipmask-3/{before,focused-final,final,tiled-retry}.log,
  before-/after-fixed-layout-svg*.json, owned per-file diffs and request patches.
  The filters row was not changed or used to claim this slice's success.

Requests / scope boundary:
1. Authorize four paints: geometry.paint arguments: two calls in
   tool/reader/fixed_layout_svg_harness.dart and one each in
   fixed_layout_svg_text_harness.dart and fixed_layout_svg_foreign_object_harness.dart.
   Their production files are outside this order's granted paths. Reviewable
   request-<filename>.patch files are under build/a2-clipmask-3; source unchanged.
2. Authorize adding paint/alpha input evidence to the existing D9 unit test in
   test/tool/reader/fixed_layout_svg_test.dart. Its expectations need no change.
   The order permits only adding harness test cases, so this existing case was
   left untouched. A proposal is request-fixed_layout_svg_test.dart.patch.
   Apply these narrowly scoped proposals, then rerun the four requested harness
   tests plus the samples test. D9 integration remains open until that check.
3. No fixed_section_preparer.dart change is needed for the reported refusal.

Only the six owned Dart files and this appended section were changed. No
subagents, task-pointer mutations, commits, downloads/network, dependency,
fixture/oracle/generator/spec/gate/D-rule, font decoder, layer-sizing or other
owner's file/section changes. Stopped after this slice with the requests above.


## A3-scale

### Bounded evidence and display scale (2026-10-30)

PARTIAL, BLOCKED on the required native byte-equivalence proof. Part A is not
complete and Part B was not started. No cap, gate, D-rule, fixture, oracle,
specification, font/filter/clip-mask owner file or private payload was changed.
No subagents, dependency/download, code generation or git mutation was used.

Retained change: additive GeometryAlphaFootprint.fromTiles in paint_geometry.dart.
The producer lends ordered, nonoverlapping RGBA tiles. A first pass detects
nonzero bounds and uniform alpha without storing a page-sized grid. Uniform
results allocate no grid. Nonuniform results reserve the final trimmed alpha
payload first, allocate it once, and replay tiles into that payload without an
additional alpha copy. Existing footprint forms and factories are unchanged.
Three new data/geometry tests cover all prior sample values (0/1/32/128/254/255),
uniform/trimmed/hole/varying samples, equality/hash/immutable views, payload
refusal before a second pass, and missing/unordered/malformed tiles.

Native proof failed, without weakening the equality check:
- A generated 1357x1259 picture contains a fractional rounded rectangle rotated
  by .19 radians. Both 1024x1024 tiles and full-width strips with at most
  1,048,576 pixels differ from whole-raster native alpha. Integer offsets are
  insufficient to preserve native AA on this host.
- An independent raw-native check bypasses every footprint factory: alpha at
  authored pixel (298,25) is 106 for the original whole picture and 106 for a
  whole-sized drawPicture replay, but 105 for the first 1357x772 replay strip.
  Other synthetic samples include (291,62): strip 120 versus whole 123.
- Uniform tiles pass. Tile reservation refuses before image creation and
  cancellation releases every scratch lease. The rotated-edge proof still
  fails, so those lifetime checks do not establish an acceptable tiled renderer.
- Removed the provisional renderer integration and all its reservation changes.
  Production coverage, image decode, geometry and scale-1 behavior therefore
  continue through their existing paths. The failing synthetic diagnostic is
  isolated under ignored build/a3-scale/tiled_coverage_probe_test.dart; it is
  never imported by production or the committed test suite.

Image evidence: production keeps its existing inspected/intrinsic decode;
there is no file-type opacity assumption. Display decode, proven opacity
classification and the separate charged authored-alpha decode remain Part B.
Reservation terms are unchanged: authored page/layer buffers and existing
retained-evidence upper bounds remain charged; no hypothetical tile saving was
applied to a real whole-raster allocation. Shared retained-ledger reconciliation
remains the later owner item from the main-session instruction.

Private gate rerun at view 400x600 / DPR 1, anonymous only:
| Page | First outcome | Requested layer pixels |
| --- | --- | --- |
| 1 | svg-layerPixels | 9,106,344 (SVG request already refuses) |
| 2 | layerPixels | 11,733,472 |
| 3 | layerPixels | 11,733,472 |
| 4 | prepared | 5,141,576 |
| 5 | prepared | 7,258,904 |
| 6 | layerPixels | 11,692,732 |
Unchanged cap: 8,388,608 pixels. Counts: 5 books, 83/83 conserved sections,
6 fixed units, 2 prepared; no import/composition failures. Final retained
picture/image/scene/source counters all zero. Page 1's aggregate vector subtotal
is not a sufficient plan because its SVG reservation already refused.

Validation (direct dart.exe / flutter_tools.snapshot, --no-pub,
--no-version-check --reporter expanded; logs under ignored build/a3-scale):
- New streaming tests: exit 0, 3 passed. Scoped analyze: exit 0, no issues.
- Scoped format --output=none --set-exit-if-changed and diff --check: exit 0.
- Requested fixed + surface + data/geometry: exit 1, 291 passed / 1 failed;
  only private_publication_regression_test remains failed.
- All fixed_layout_* row tests + harfbuzz + corpus: exit 1, 82 passed / 2 failed.
  Known filters row fails. Additionally D9 ignores hidden, clipped and
  transparent gradient paint expects gradient but obtains solid. Both failures
  persist on one rerun (exit 1); those files are outside this patch. No fix or
  attribution to a particular concurrent owner is claimed.
- Corpus alone: exit 0, 58 passed, authored scale unchanged.
- Private numeric probe: exit 1, same per-page outcomes above. Native diagnostic:
  exit 1, two equivalence checks fail and the lifetime/refusal check passes.
- Initial compile also caught concurrent fixed_svg_text_fonts.dart edits; a
  later rerun compiled without modifying that owned file.

Requests: the bounded-evidence design needs an implementation that preserves
the original native raster context/AA, or a separately reviewed exact readback
strategy. Flutter Picture.toImage with a smaller target and integer replay
offsets has a concrete counterexample above; do not approve it by relaxing the
byte check or marking coverage exact. Filter native rasterization and clip/mask
scratch still need their owners' coordination after that decision. Display
scale derivation/plumbing, image opacity/authored-alpha ownership, scaled layer
charges, explicit scale-1 harness arguments and their integration tests remain.

## A3-scale-4

#### Part A completion (2026-10-30)

The lost session had already installed whole authored-size native evidence
rasterization, exact unfiltered integer-aligned tile copies, streaming
`fromTiles` construction, decoded-data opacity checks, and separate prepaid
evidence ledgers for XHTML and SVG. This turn audited those changes, formatted
two production files, and corrected three test expectations/assertions. No
production resource cap, fixture, oracle, D-rule, or public footprint API was
changed. Part B (display-scale decoding/layers) was not started.

At an evidence peak the XHTML builder and SVG coverage helper each own one
authored-size evidence `ui.Image`. They reserve the full raster plus one tile
copy and RGBA readback before allocation, visit tiles serially, release each
tile lease, and release the raster after both `fromTiles` passes. The production
coverage helper has no full-image RGBA readback. Native rotated-edge RGBA and
footprints equal the original whole raster across tile seams; refusal occurs
before native allocation, and cancellation/payload refusal drain owners. Raster
display images are opacity-scanned from decoded alpha, never inferred from
extension. The current decode remains intrinsic/authored, so alpha images use
that exact decoded input; a separate authored-alpha decode or typed refusal is
required when Part B introduces a smaller display decode.

Three SVG failures resolved without weakening the leak check: the feature
reservation expectation adds the intended authored raster (20,020 -> 30,020
pixels); the DAG count adds the one native raster image (28 -> 29); late
failure/cancellation expects six images and compares each created/disposed Dart
object with `identical`, since `identityHashCode` on a disposed native peer
throws. Every created image must still be disposed exactly once, and the
resource ledger must still reach zero. Targeted rerun: 28 passed, exit 0.

Public 52-case reservation probe, before Part A -> after Part A: layer-pixel
sum 22,272,000 -> 22,272,000; maximum 2,457,600 -> 2,380,800. Vector-byte
sum 62,843,136 -> 62,843,136. Different page kinds exchange an authored
layer charge for the exact raster/tile peak; the equal total is coincidental.
The public corpus remains 58/58, exit 0, with no changed verdict.

Private anonymous fixed pages at 400x600/DPR 1, prior first outcome and layer
request -> current prepared scene layer request (8,388,608 cap):

| Page | Before | After |
| --- | --- | --- |
| 1 | svg-layerPixels, 9,106,344 | prepared, 5,077,460 |
| 2 | layerPixels, 11,733,472 | prepared, 3,425,520 |
| 3 | layerPixels, 11,733,472 | prepared, 3,425,520 |
| 4 | prepared, 5,141,576 | prepared, 1,796,076 |
| 5 | prepared, 7,258,904 | prepared, 2,313,740 |
| 6 | layerPixels, 11,692,732 | prepared, 3,415,390 |

Private run: 5 books, 83/83 conserved sections, 6/6 fixed units prepared,
zero fixed preparation failures, and all final retained counters zero. The
standalone SVG diagnostic for page 1 still estimates 9,106,344 layer pixels;
the actual wrapper scene is admitted at 5,077,460. This records measured
admission, not a new fidelity or device verdict.

Validation with direct dart.exe/flutter_tools.snapshot and `--no-pub`:
- Fixed + geometry + surface: exit 0, 296 passed; surface with private sample:
  exit 0, 91 passed.
- Tool reader: exit 1, 25 passed / one known filters geometry row failure
  (`hostGate` false, incomplete geometry pending A2-filters-4). Tool reader +
  corpus: exit 1, 83 passed / the same one failure. Corpus alone: exit 0,
  58 passed.
- `dart analyze lib test tool`: exit 0. Scoped format check: exit 0, ten
  files, none changed. Scoped `git diff --check`: exit 0.

Requests: the filter owner must reconcile `svg_feature_filters.dart`'s
`picture.toImageSync(regionRoot.width, regionRoot.height)` and cached full-page
images with the authored evidence peak; the clip/mask owner must replace
`svg_feature_clip_mask.dart`'s whole `image.toByteData(rawStraightRgba)` and
`GeometryAlphaFootprint.fromRgba` pair with exact tiled `fromTiles` readback,
prepaid raster/tile reservations, and cancellation-safe releases. These are
outside this slice's granted production paths. Part B must pass an
authored-resolution alpha decode or produce typed refusal for nonopaque images
when the display decode is scaled. No patch to those owners' files was made.

## A2-clipmask-4

### Round 4a fixes and bounded readback (2026-10-30)

Both findings CONFIRMED and fixed within the assigned slice. Loaded Trellis
start/before-dev/check context inline; the named task remains in progress in
expected degraded pointer mode. No task-pointer mutation or subagent was used.

Bounds:
- The expanded instance traversal previously transformed each leaf's already
  axis-aligned rectangle. A radius-20 circle rotated 45 degrees therefore
  produced left 21.715729 and width 56.568542 instead of left 30 and width 40.
  A quarter-width objectBoundingBox effect ended before the expected (38,50)
  opaque sample while still publishing complete capability.
- Bounds now use geometry transformed into owner coordinates before taking
  extrema. Native Path.getBounds includes Bezier/conic control points even
  after transformation, so merely transforming that path was insufficient.
  Circle/ellipse extrema are analytic; rounded rectangles combine the
  transformed inset rectangle and ellipse support extents. Cubic commands are
  transformed first and passed through the existing _pathBounds extrema solver.
  Straight geometry uses the transformed path. Expanded use/nested-use/symbol
  chains, owner inversion and descendant union remain intact.
- Eight regressions cover clip and mask on group/use/nested-use/symbol owners:
  quarter region [30,30,10,40], native alpha 255 at (38,50), zero at (42,50),
  complete geometry and corresponding retained alphaAt samples. Another test
  checks transformed cubic, sheared ellipse and rounded-rectangle extrema for
  both effects.

Bounded mask evidence:
- Replaced the feature's whole rawStraightRgba/fromRgba readback with
  AuthoredEvidenceRaster.rasterize, which rasterizes once and streams exact
  integer-aligned unfiltered tile copies through fromTiles. No whole-image
  RGBA buffer coexists with the authored image in this production path.
- Mask preparation is serial and precedes ordinary leaf evidence. A local
  subdivision uses the already prepaid plan.evidencePixels capacity; it does
  not debit the outer ledger twice or introduce another shared plan term.
  Retained mask payload remains covered by the existing coverage-map bound;
  existing display/luminance layer charges remain unchanged.
- Evidence peak is W*H + 2*min(W,512)*min(H,512) RGBA pixels: one authored image,
  one tile image and one tile readback. For 1103x769 this is 1,372,495 charged
  pixels / 5,489,980 bytes. Measured live native image peak is 1,110,351 pixels
  (readback is not a native image); only one authored-size image is created.
- Alpha and luminance masks larger than one tile, with rotated colored edges,
  match every legacy whole-readback alpha byte and the entire lossless
  footprint. Tests require both tile passes and the native-image peak.
  Layer-pixel and layer-byte refusal occurs before any image allocation.
  Cancellation after the raster/first/third tile and failure after mask
  preparation dispose every created image exactly once, release all budget
  counters, and publish no partial scene. Repeated disposal is safe.

Validation (direct installed dart.exe/flutter_tools.snapshot; tests use
--no-pub --no-version-check --reporter expanded -j 1):
- Regression-first unit run: exit 1, 20 passed / 11 failed, reproducing all
  eight rotated-circle bounds cases and the three bounded-readback/lifetime
  expectations before production changes.
- Final clipmask unit + test/tool/reader/fixed_layout_svg_clipmask_test.dart:
  exit 0, 33 passed (32 unit + one production harness).
- Harness row PASS: positive/boundary/nested each pass complete module and
  fixed geometry, all five D4 sub-rules and 4/4 solid D9 samples (delta 0).
  Unsupported remains a typed refusal with no inherited D3 exemption.
  The 0.5 CSS px gate and D3/D4/D7/D8/D9/D10 are unchanged.
- Initial fixed + surface run: exit 1, 279 passed / one filter-test loading
  failure during concurrent edits (constructor arguments and missing test
  helper outside ownership). After a ten-second wait, fixed retry: exit 0,
  207 passed. Separate surface/private retry: exit 0, 91 passed.
- Private anonymous result: 5 books, 83/83 sections conserved, 6/6 fixed
  sections and units prepared, zero fixed/composition/import failures, all
  final retained resource counters zero. No private content is recorded here.
- Scoped analyze: exit 0, no issues. Scoped format check: exit 0, two files,
  zero changes. Logs are under ignored build/a2-clipmask-4/; the public harness
  report is build/fixed-layout-svg-clipmask/report.json.

Changed only svg_feature_clip_mask.dart, its unit test and this appended
section. No harness implementation/case, other owner's file, geometry model,
fixture/oracle/spec/gate/cap/dependency or git state was edited. No download or
network access was used. Requests: none. Stopped after this slice.

## A2-gates-r4

### Review round 4a fixes (2026-10-30)

Owner A2-gates-r4 used trellis-start, trellis-before-dev and trellis-check
inline for the named in-progress task. The missing current-task pointer is
expected degraded mode. Only the six authorized Dart files and this appended
section were edited; no subagents, task creation, git mutation, dependencies,
network, fixtures, oracle, generators, specs, thresholds or other-owner files.
The 0.5 CSS px gate, D3/D4/D7/D8/D9/D10 and canonical v1 remain unchanged.

Findings, regression-first evidence and fixes:
1. CONFIRMED: the graphics test asserted fixedPass/parity without overall or
   independent required geometry/pixel success; fixedPass aggregated parity.
   A serialized real graphics report replay with both boundary pixel verdicts
   false and parity true passed the old assertions, making the new negative
   regression fail as expected. The shared assertion now requires report.pass,
   fixedPass, every case.pass and fixed.pass, both geometry/pixel results, and
   parity. Six further regressions independently falsify module geometry,
   module pixels, fixed geometry, fixed pixelPass, fixed pixels and parity;
   each has a positive replay control. The harness independently compares the
   fixed SVG geometry against the oracle, records full fixed-scene completeness,
   and requires fixed fidelity, expected capability, parity and released budget.
   Required row success includes both paths; identical failure cannot pass.
2. CONFIRMED: continuous centreline distance assigned a dashed gradient stroke
   to a black fill pixel in a gap. Three native-rendered regressions verify the
   gap is opaque black, inject a delta-1 sample, and require failure for butt,
   round and square caps. A separate single-role dashed-gradient stroke remains
   eligible from published coverage. The first test attempt selected x=45 on
   an on-dash; after verifying path traversal, x=95,y=21 reproduced the actual
   misclassification before changing the helper (three classification failures).
   Removed the distance heuristic. Published combined fill/stroke alpha proves
   coverage but cannot distinguish the roles at dashes/caps/joins: mixed visible
   roles now require exact samples. Single visible roles still require native
   alpha/clip/mask evidence and matching reference gradient paint. No D3 scope
   or D9 tolerance was broadened; no color selects the classifier's paint role.
3. CONFIRMED: a text/plain stylesheet link read its absent resource. The read-spy
   regression failed before the fix. Linked discovery now applies the same
   trimmed, case-insensitive empty/text/css type eligibility as inline styles
   before resource access, retaining existing stylesheet/alternate rel rules.
   Tests cover zero reads for text/plain, alternate stylesheet and icon links,
   and successful missing, empty and mixed-case/whitespace text/css types.
   engine/style remains read-only; its existing rel handling was inspected.

Final requested row verdicts:
- Graphics: PASS -> FAIL; fixedPass also true -> false. Positive/nested PASS;
  unsupported PASS via typed refusal. Boundary geometry PASS in both paths,
  maximum 0.000014085071256886295 CSS px; interior/edge/support/components PASS,
  including 17/17 components. Sample (10,10) has channel delta 1 and ambiguous
  combined fill/stroke ownership, so it now requires exact matching and FAILS
  on both paths. The other three samples pass. Parity remains true in all four
  cases; the strengthened gate correctly retains the required failure.
- Filters: initial report inventory showed FAIL; the final production report
  and all four variants PASS, with complete required geometry. This change
  belongs to concurrent A2-filters-4, not this patch. Its report had already
  become PASS before the final combined run; filter/clip-mask file hashes were
  unchanged across that run (concurrent-before/after.json).
- Production clip-mask and foreign-object: PASS, all four variants each.
- Production svg-text: all ten hostGate values true; verdict device-gated (A5).
- XHTML cascade/box/paint/stacking/dimensions/metadata: PASS; text hostGate true,
  verdict device-gated (A5). Mixed-navigation: PASS.
- Legacy A0 spike: filters/clip-mask/foreign-object PASS; provisional svg-text
  remains FAIL for six required geometry cases (all their pixel gates PASS).
  Its saved row verdicts are identical before/after. HarfBuzz hostD8Gate true,
  svgTextRowVerdict device-gated (A5). These are separate from production text.

Validation (direct installed dart.exe and flutter_tools.snapshot; all Flutter
commands use --no-pub --reporter expanded -j 1):
- Regression-before command: graphics test + samples test + stylesheet test,
  exit 1, 12 passed / 5 failed; this includes the initial three incorrect gap
  coordinates noted above. Corrected samples-only red run: exit 1, 2 passed /
  3 failed, all specifically gradient-versus-solid classification mismatches.
- Focused fixed command: those three files + svg_feature_text_test.dart,
  exit 1, 35 passed / 1 failed: only the honestly failing required graphics row.
- Final requested command: test test/tool/reader plus
  test/features/reader/engine/fixed/fixed_svg_text_stylesheet_test.dart and
  test/features/reader/engine/fixed/svg/svg_feature_text_test.dart; exit 1,
  57 passed / 1 failed, solely production SVG graphics boundary. Tool directory:
  35 passed / 1 failed; stylesheet: all 9 passed; SVG feature text: all 13 passed.
  Every new regression passes. No outside-owner test failure required a retry.
- Scoped dart analyze: exit 0, no issues. Final scoped dart format --output=none
  --set-exit-if-changed: exit 0, six files, zero changes. Scoped git diff --check
  and direct whitespace inspection of untracked Dart files: exit 0.
- Evidence: build/a2-gates-r4/{regression-before,dashes-before,focused,
  requested-final,analyze-final}.log; saved graphics baseline, final reports and
  concurrent-owner hashes. The initial formatting parse error was corrected
  before validation; the final files format/analyze successfully.

Requests: the graphics owner needs separate published fill/stroke coverage
(including actual dashes, caps and joins) to resolve the boundary sample's role,
or another fidelity fix that satisfies exact samples. That production evidence
change is outside this scope. Keep the graphics row open; do not waive the
sample, loosen thresholds or infer its role from rendered color. No further
outside-scope change was made, and this task is not marked complete.

## A2-paint-roles

### Fill/stroke evidence (2026-10-30)

Owner A2-paint-roles loaded trellis-start and trellis-before-dev inline for
the named in-progress task; the absent session task pointer is expected.
Stopped before implementation because the actual producer and accounting
locations require changes to files explicitly excluded from this order.
No production/test files, gates, fixtures, oracle, specs or other-owner
sections were changed; no subagents, dependencies, network or git mutations.

Stored evidence inspected: build/fixed-layout-svg/report.json and its module
and fixed boundary PNGs, plus the existing corpus/oracle records. Both paths
fail only the sample sub-rule at (10,10): delta 1, solid classification,
reason "native paint coverage is ambiguous". Geometry, interior, edges,
support bounds and 17/17 components pass; parity passes. Positive and nested
pass, unsupported passes through typed refusal. These are stored verdicts,
not a fresh harness run.

The covering source is node 20, the rect at (5,5) with size 40x40 and identity
transform; native/reference geometry agrees exactly. Oracle computed fill is
url("#grad"), stroke is black, stroke-width is 1px. The pixel centre
(10.5,10.5) is inside the fill and beyond stroke support. Thus its role is
gradient fill in the reference and native drawing, rather than the suggested
gradient stroke. This conclusion uses source/computed paint and geometry,
not pixel color. Reference RGBA is (205,0,50,255); System.Drawing readback of
both saved native PNGs gives (204,0,50,255). Per-role native alpha is still
needed to publish that proof to the classifier; the current FAIL is retained.

Concrete scope dependencies / requests:
1. svg_graphics_prepare.dart: lines 197-225 call _coverage once and construct
   exactly one GeometryPaint. A helper-only change in svg_graphics_geometry.dart
   cannot publish separate list entries through that call contract. Authorize
   a narrow caller change, coordinated with A2-filters-4.
2. svg_graphics_plan.dart: _coverageMaps counts one map per shape; reservation
   prepays that count and _coverage uses reserve: (_) {}. Authorize a narrow
   count/reservation adjustment before retaining multiple role footprints.
3. data/geometry/place_source_geometry.dart: reconstruction at line 65 must
   preserve the additive role during placement; this file is outside scope.
4. svg_feature_hooks.dart: clip attachment reconstructs GeometryPaint at line
   272 and must preserve the role. This file is explicitly excluded; request
   its owner make the additive copy-field change or authorize coordination.

No code implementation, new tests, test-directory/corpus/private runs or
format/analyze runs were attempted after identifying these dependencies.
Anonymous private fixed counts were not remeasured. Read-only report/source
and System.Drawing inspections exited 0. A preliminary Python PNG readback
exited 1 because Pillow is absent; the installed System.Drawing fallback
succeeded without installing anything. This slice remains incomplete.

## A2-filters-4 (continued)

#### Filtered-output evidence completion (2026-10-30)

The shared lifecycle scope was granted and the requested filtered-output slice
is implemented. The filters row is PASS again with real native alpha evidence;
the separate graphics-boundary D9 failure below remains open. No whole-task or
device acceptance is claimed. The prior blocked entry is historical.

Hook/capture contract:
- Added default-no-op awaited `SvgFeature.postPaint` and opt-in `captureOutput`.
  Existing prepare/geometry/paint/default-capture contracts remain unchanged.
  `_paintTree` records an opted-in instance exactly once in root coordinates,
  including all its own feature wrappers and element/group opacity, then draws
  that same scene-owned picture into its parent. Siblings never enter it.
- All post-paint hooks finish, with cancellation checks, before
  featureCoverage.require, geometry construction and publication. A suspended
  hook cannot publish a scene. Captures and unfinished recorders are destroyed
  on failure/cancellation by the same scene ownership path.
- The filter postpass removes source paints again after every geometry hook,
  so later text/foreignObject/custom producers cannot restore input evidence.
  Nested filter intermediates remain source identity only; only the outermost
  filtered instance publishes final paint. Source fragments/anchors/transforms
  and text ranges remain; mask ids consumed inside the filtered subtree are
  collapsed because their effects are already in the final alpha, avoiding
  unresolved registry references and double mask application.

Readback/placement:
- Reused AuthoredEvidenceRaster.rasterize/readImage/fromTiles unchanged. No
  helper additions, duplicated tiling, whole-image RGBA readback, display-scale
  evidence, downsampling or substitute solid region was introduced.
- Raster dimensions are the outward-rounded transformed filter region, at
  one CSS pixel per sample, including output beyond the source bounds. An
  integer translation maps the trimmed grid back to its root/unit position;
  later unit placement composes its existing matrix without copying samples.
- Own opacity is already in the capture. Ancestor opacity layers replay in
  native nesting order. Final paint uses effectiveOpacity=1 and no group/mask
  applications because these effects are baked into its native samples.
  Transparent output compresses to uniform alpha 0 and proves no visible paint;
  flood subregions compress only when all retained samples are equal.
- Incomplete cases retained: missing graph/bounds/capture, and an ancestor
  clip/mask outside the isolated capture. Those ancestor effects cannot be
  attributed to this instance by the current hook, so no output proof is
  invented. Resource/native readback failure refuses preparation; no partial
  result is marked complete. Existing unsupported graphs remain typed refusals.

Admission/lifetime:
- Filter DAG sources/results still materialize once. Every toImageSync cache
  allocation now has a live lease in the same prepaid raster subdivision as
  AuthoredEvidenceRaster. Actual root dimensions are checked before graph work.
  The outer plan retains the sum of each admitted graph's bounded caches and
  scratch, plus the maximum serial evidence peak, not an uncharged overlap.
- With P=ceil(viewport width)*ceil(viewport height), each filter prepays
  2P*(primitiveCount+5) raster pixels and 128+2P retained vector bytes. The
  shared evidence slot is max(base evidence, 2P+2*min(2P,512*512)); only one
  evidence raster and one charged tile/readback pair run at a time.
- fromTiles admits actual retained storage before allocation through a prepaid
  payload sublease. Dart cache handles close after post-paint work; scene
  pictures retain native references and their raster leases until disposal.
  Failed preparation destroys feature cache handles before returning charges.
  Success, late failure and cancellation dispose each image/release each lease
  exactly once. A measured two-stage graph reaches 60,000 live image pixels and
  a 100,000-pixel subdivision peak (including scratch/readback), within its plan.

Verification (direct dart.exe/flutter_tools.snapshot, --no-pub, expanded):
- Filters + hooks + filters harness: exit 0, 36 passed (22 filter tests,
  13 hook tests, one harness). Covers transparent flood/composite-out/zero-alpha
  matrix, opaque/partial flood subregions, blur/offset extension, alpha 64 at
  opacity .25, nested/repeated DAGs, repeated instances, negative/placed grids,
  own clip/mask output, rotated AA and tile seams, deferred hook ordering,
  late source-paint removal, preallocation refusal, shared peaks and cleanup.
  Output footprints are compared at every authored pixel with independent final
  picture readback, including transparent margins and antialiased samples.
- Isolated test/tool/reader/fixed_layout_svg_filters_test.dart: exit 0.
  Fresh report: positive PASS, boundary PASS, nested PASS, unsupported PASS;
  required geometry maximum 0 CSS px and D4/D9 PASS. Retained output evidence
  is 9,728 / 8,224 / 9,728 bytes respectively, pixelSize=1. Each required case
  reserves 2,611,200 layer pixels; every variant reports budgetUsedZero=true.
- test/features/reader/engine/fixed + test/tool/reader: exit 1, 245 passed /
  one failed. All fixed tests pass. The out-of-scope fixed_layout_svg_test.dart
  graphics-boundary case fails D9 at (10,10): ambiguous combined fill/stroke
  coverage, exact-class channel delta 1. It has no filters. The required isolated
  retry also exits 1 (10 passed / one failed); no gate/fixture/oracle was changed.
- test/features/reader/engine/surface with private inputs: exit 0, 91 passed.
  Anonymous counts: 5 books, 83/83 conserved sections, 6/6 fixed sections and
  units prepared, zero fixed/composition/import failures; final retained
  picture/image/scene/source counts all zero. Repeated after the final code edit.
- Scoped format check: exit 0, eight files, zero changes. Scoped analyze:
  exit 0, no issues. Scoped git diff --check: exit 0.

Requests: the graphics/paint-role owner must resolve the already documented
graphics-boundary D9 ambiguity and rerun its gate. Ancestor clip/mask output
is still explicitly incomplete until an isolation contract includes those
outer wrappers. No request is needed for the required filters row. Only the
eight granted Dart files and this appended owner entry were changed; no
AuthoredEvidenceRaster behavior/API, clip/mask/text-font owner file, public
geometry API, cap/gate/D-rule, fixture/oracle/spec, dependency, network access,
subagent or git mutation was used.

## A2-paint-roles (continued)

#### Completion (2026-10-30)

Status: implementation delivered within granted files; slice remains INCOMPLETE
pending two additional copy-field permissions. The requested suite was run in
full and four new assertions expose those remaining integration gaps. This
heading records the completion review, not a successful whole-slice gate.
Loaded the filter/clip-mask completion records before editing shared files;
used trellis-check inline. No subagents, task-pointer changes, dependencies,
downloads/network, git mutation, fixtures/oracle/generators/specs, thresholds or
D-rule changes. AuthoredEvidenceRaster behavior is unchanged.

Representation/producers:
- Added optional GeometryPaintRole { combined, fill, stroke }, default combined,
  with value equality/hash, placement and shared clip-annotation preservation.
- SVG shape evidence now publishes fill and stroke separately in normal SVG
  order, sharing the element ordinal/source fragment. Marker descendants retain
  their later independent ordinals. Unsupported paint-order remains a typed
  refusal; its support was not expanded.
- Mixed shapes replay the existing _compile pipeline once per role with the
  other paint disabled. Pattern construction and dash masks, including caps,
  joins and offsets, are therefore the actual native drawing operations.
  Each result uses existing AuthoredEvidenceRaster exact authored AA and tiled
  readback. Temporary pictures/leases are destroyed on every exit path.
- Plan inspection prepays one worst-case retained footprint per published
  role, including two-role clip-copy capacity, before preparation/allocation.
  Serial role rasterization reuses the existing scratch peak. Single-role
  shapes reuse their original picture; images/features retain combined API.
- Filter postPaint/capture/output evidence is unchanged and its row passes.
  Clip/mask alpha and registries remain unchanged, but the feature's _copyPaint
  drops role labels; this is one of the pending additions described below.

Classifier:
- Orders by descending element ordinal, then stroke above fill for the
  supported normal order. Requires exact native coverage and nonzero alphaAt,
  respecting existing clip/mask/opacity handling; unknown evidence stays exact.
- Uses the covered paint's published role to select only that source element's
  native and reference computed paint servers. Combined legacy mixed-role
  evidence stays ambiguous/exact; no geometric stroke estimate or color-based
  role inference was added. Gradient sample allowance remains exactly 1.
- Fresh graphics boundary passes in module/fixed paths: node 20, ordinal 2,
  sample (10,10), topmost role fill, native url(#grad), reference url("#grad"),
  channel delta 1. Geometry and every other D4 sub-rule pass; parity passes.

Tests and requested final checks:
- Added full-grid alpha comparisons against native single-role controls for
  rect/circle/path across all three caps and joins with dashes, opacity and
  transforms; pattern-fill/dashed-gradient-stroke control; prepaid payload and
  one-byte-short refusal; additive model equality/hash/placement; marker order;
  fill-only, stroke-only, overlap and dash-gap classification for each cap.
- Stored oracle boundary sample replay passes from actual role evidence and
  fails with swapped labels, combined labels or a solid reference fill.
  Existing SVG text/foreignObject foreground and unknown-evidence checks remain.
- New clip-annotation hook regression passes. New clip/mask composition and
  merged-scene role checks expose precisely the excluded reconstruction sites.
- Focused initial final run: exit 0, 55 passed. Later composition checks: exit 1,
  37 passed / two clip-mask role-copy failures. Hook/merged-scene checks: exit 1,
  19 passed / two merged-role failures. All existing tests remain green.
- Final single command: test/tool/reader + engine/fixed + data/geometry +
  engine/surface + data/epub/fixed_layout_corpus_test.dart, with private inputs,
  --no-pub --reporter expanded -j 1: exit 1, 450 passed / 4 failed.
  Directory counts: tool 36 pass / 2 new merged-role failures; fixed 241 pass /
  2 new clip/mask role-copy failures; geometry 24/24; surface 91/91;
  corpus 58/58. Logs: build/a2-paint-roles-final.log.
- Separate private surface command: exit 0, 91 passed. Anonymous results both
  runs: 5 books, 83/83 sections conserved, 6/6 fixed sections and units prepared,
  zero fixed/composition/import failures, all final retained counters zero.
- Scoped format check: exit 0, 12 files, zero changes. Scoped analyze: exit 0,
  no issues. Scoped tracked diff whitespace check: exit 0. Initial broad test
  attempt hit a Flutter shared compiler-cache PathExistsException and was
  interrupted (exit 1); serial retry completed. No sqlite DLL failure occurred.

Every measured row:
- Production graphics: positive/boundary/nested/typed-refusal all PASS, both
  module and fixed required channels and parity. Filters, clip-mask and
  foreignObject: all four variants PASS each.
- Production SVG text: all ten host gates true; device-gated (A5).
- XHTML cascade/box/paint/stacking/dimensions/metadata PASS; text host gate true,
  device-gated (A5). Mixed-navigation PASS.
- Legacy A0 filters/clip-mask/foreign-object PASS; provisional SVG text FAIL
  remains its previously documented geometry limitation. HarfBuzz hostD8Gate
  true and SVG text device-gated (A5). No legacy failure was reclassified.

Requests (asked asynchronously; no authorization received at this checkpoint):
1. Permit only role: paint.role in svg_feature_clip_mask.dart's _copyPaint.
2. Permit only role: p.role in fixed_scene_geometry.dart's SVG paint merge.
These files remain excluded by the original order and were not edited. Ready
one-line patches are build/a2-paint-roles-request-clip-mask.patch and
build/a2-paint-roles-request-scene-merge.patch. Apply after permission and rerun
the four failing regressions plus affected required checks. Do not delete or
weaken the new assertions to make the incomplete integration appear green.

## A3-scale-b

### Display-scale decode and layers (2026-10-30)

Status: INCOMPLETE, blocked before production edits by the interaction between
the unchanged filter evidence producer and the requested reservation formula.
This entry does not claim display-scale implementation or scale equivalence.
Loaded trellis-start, trellis-before-dev and trellis-check inline. The named
in-progress task is active despite the expected absent session pointer. No
subagents, task creation/pointer mutation, dependencies, network, git mutation,
fixture/oracle/spec/gate/cap changes or edits to another owner section occurred.
Only this appended entry and an ignored synthetic diagnostic were written.

Starting state verified: fixed + data/geometry + surface + tool/reader pass
396 tests. The separate corpus passes 58, matching the handoff's 454 tests.
The private regression separately confirms 5 books, 83/83 conserved sections,
6/6 prepared fixed sections/units, no typed failures and zero final retained
picture/image/scene/source counters. No state discrepancy was found.

Allocation/flow audit (paths relative to lib/features/reader/engine/):
- surface/publication_fixed_sources.dart::_inspect records intrinsic raster
  dimensions; _images passes these into PageSurfacePool.fixedImageRequest.
- surface/fixed_unit_surface.dart::fixedImageRequest fixes both cache target
  axes to those dimensions. fixed/fixed_source_lease.dart::FixedImageRequest
  exposes only acquire(cancellation), with no generation/target argument.
- layout/image_cache.dart::lease already accepts target dimensions and
  charges intrinsic codec scratch plus output before codec allocation. The
  fixed plan's decodedImageBytes still sums intrinsic retained outputs.
- fixed/fixed_preparation_plan.dart charges authored page pixels times XHTML
  opacity depth, plus SVG display charges and the serial authored evidence
  maximum. There is no frozen preparation scale on that plan/request.
- fixed/svg/svg_graphics_plan.dart::reservation uses authored dimensions for
  SVG opacity/host-opacity buffers and feature display charges. Its evidence
  grids and retained footprint bounds correctly remain authored-size.
- fixed/svg/svg_feature_clip_mask.dart charges authored viewport-sized mask
  applications, including luminance layers and repeated applications. Native
  display saveLayer calls inherit playback transforms; authored mask evidence
  separately uses AuthoredEvidenceRaster and must remain unchanged.
- fixed/svg/svg_graphics_patterns.dart records pattern opacity, pattern stroke
  masks and dashed-gradient stroke layers; these are deferred saveLayer calls,
  not explicit toImage allocations. They inherit the display canvas transform.
- fixed/fixed_scene_paint.dart similarly records deferred XHTML opacity layers.
  Background auto dimensions currently read ui.Image.width/height; scaling the
  decoded image requires preserving original intrinsic layout dimensions.
- fixed/fixed_scene_foreign_object.dart validates two authored viewport buffers
  and reuses the same XHTML layout/paint/evidence builder inside SVG.
- fixed/svg/svg_feature_filters.dart explicitly materializes authored root-size
  SourceGraphic, SourceAlpha and primitive images with toImageSync. The plan
  charges their caches/scratch as 2P*(primitiveCount+5), alongside evidence.
- surface/fixed_unit_surface.dart::_composeFixedUnit already fits page/spread
  pictures into the frozen CSS view. It allocates no raster layer itself and
  does not multiply that fit by DPR for decode/planning. There is no separate
  fixed raster size set in page_surface_pool.dart or publication composition.

Concrete blocker:
SvgFilterFeature.postPaint reads the isolated picture captured by _paintTree.
That picture contains the very same DAG cache images _drawFilter materializes
for display; AuthoredEvidenceRaster then preserves their pixels exactly. If
those caches are scaled, a final authored-size evidence raster cannot recover
lost alpha. Opaque inputs are insufficient for filters that derive alpha from
color (feColorMatrix), even when the source's opacity was proved correctly.

Independent native diagnostic: build/a3-scale-b/filter_scale_probe_test.dart.
An opaque synthetic 73x61 black-to-white gradient is filtered with a matrix
that maps red into alpha. Native cache scale 1 versus .25, replayed into the
same authored rectangle, differs at 4,268 alpha samples; first pixel alpha is
1 versus 7. The test asserts that a mismatch exists; it is a negative
feasibility control, not a passing equivalence proof. It uses no private input
and does not alter or import AuthoredEvidenceRaster internals.

Keeping authored caches for evidence and separately generating scaled display
caches would preserve the existing producer, but requires charging transient
authored DAG caches beyond the specified scaled-display-plus-one-evidence-
raster formula. Replacing the producer with another exact evaluation strategy
would instead change the expressly excluded evidence production. No smaller
reservation, approximate evidence or unsupported successful partial scene was
introduced. Native image references retained by pictures must also be destroyed
before releasing authored cache leases; closing Dart image handles alone is
insufficient.

Additional alpha-path constraint: opacity observed only after a smaller decode
does not prove that the original had no fine transparent features. A reliable
codec opacity guarantee or a charged original-resolution inspection is needed
before selecting display-only evidence. This is an audit requirement, not an
implemented alpha path. Requested DPR-1/DPR-3 per-page layer/image peaks were
not measured; there is no new display-scale generation to validate.

Validation with direct installed dart.exe/flutter_tools.snapshot, --no-pub,
--reporter expanded; logs under ignored build/a3-scale-b/:
- fixed + data/geometry + surface + tool/reader: exit 0, 396 passed.
- Private regression (SHIORI_LOCAL_EPUB_DIR set locally) + fixed_layout_corpus:
  exit 0, 59 passed; corpus verdicts unchanged, private results above.
- Synthetic filter feasibility control: exit 0, 1 passed (mismatch required).
- dart analyze lib test tool: exit 0, no issues.
- Scoped diagnostic dart format check: exit 0, one file, zero changes.

Requests: authorize an explicit temporary authored filter-DAG cache term in the
peak plan, with authored-cache disposal after evidence and separate scaled
display-cache generation; alternatively authorize leaving filter display
preparation unchanged in this slice. The first option changes the requested
reservation formula; the second leaves part of the requested display switch
open. An asynchronous clarification was sent; no authorization was received
when this checkpoint was written. Production implementation remains unstarted.

## A2-evidence-place

### Review round 4b fix (2026-10-30)

Status: INCOMPLETE. Finding confirmed; regression tests delivered first, but
production changes are unstarted at the explicit ownership boundary. Loaded
Trellis start/before-dev/check inline for the named in-progress task. The absent
session pointer is the expected degraded mode. No subagents, task-pointer
mutation, dependency/network work, git mutation, fixture/oracle/spec/cap/gate/
D-rule changes or edits to another owner's files/sections occurred.

Reproduction:
- An inline 80x80 SVG with placement (100,12) paints native alpha 255 at
  (100,12) while its complete/exact published footprint returns zero there.
- Fractional placement (100.25,12.75) and affine host placement
  [1.2,-0.3,100.25;0.2,0.9,12.75] reproduce the same defect; the latter
  paints native alpha 39 at (109,23), published as zero.
- svg_graphics_geometry.dart::_coverage uses size.width/height at origin zero
  after _paintLeaf has already applied the host placement. The uniform rect
  shortcut intersects against that same unplaced size, so it also drops paint.

Added svg_graphics_evidence_placement_test.dart with 19 failing regressions:
full-grid native alpha comparisons for rect fill (including the uniform
shortcut), equivalent path fill, stroke and admitted alpha image under integer,
fractional and transformed hosts; isolated native controls for both roles of a
mixed dashed fill/stroke; scratch/retained reservations checked against actual
native raster dimensions; and the actual prepare(placement:) override seam.
Every comparison includes transparent pixels as well as every painted pixel.
All scenes/resources and image callbacks are released/restored in finally.
All 19 fail against existing production, on native alpha mismatch rather than
compilation or accounting errors. New tests remain red; no completion is claimed.

Scope blocker / concrete requests:
- fixed_preparation_plan.dart inspects each inline SVG with only its local
  svgSize, then freezes its reservation. It does not pass the enclosing page's
  authored raster extent. fixed_scene_svg.dart supplies host placement later,
  only through prepare(placement:).
- svg_graphics_prepare.dart calls reservation() and evidencePixels before
  _tree applies placement ?? this.placement. Updating only the two allowed
  files from inspected placement cannot cover that real inline-host override;
  enlarging coverage alone exceeds the unchanged prepaid scratch/payload term.
- Preferred narrow extension: allow fixed_preparation_plan.dart's inspection
  call to supply the enclosing authored page evidence extent to a matching
  SvgGraphicsPlan field. Keep the SVG viewport size separate. Geometry and the
  matching reservation can then use that same root-coordinate raster, with
  native matrices unchanged and AuthoredEvidenceRaster untouched.
- If extent is instead derived from effective host placement, also allow the
  narrow svg_graphics_prepare.dart caller change to pass that extent into both
  reservation/evidenceBudget and coverage; enclosing whole-scene preflight must
  still reserve it before preparation. No late uncharged allocation, viewport
  AA resampling, tiled rasterization or typed-refusal workaround was added.
An asynchronous request initially asked for the preparation caller extension;
no scope authorization had arrived when this record was appended.

Validation (installed direct dart.exe / flutter_tools.snapshot, --no-pub,
--reporter expanded, -j 1):
- Regression-first command: exit 1, 0 passed / 19 failed. Log:
  build/a2-evidence-place/regression-before.log.
- Tool reader + corpus baseline: exit 1, 97 passed / 2 concurrent-owner D9
  feFlood failures. Corpus 58/58. Those two failures passed on the later full
  requested-scope run; no edit was made to the D9 owner's files.
- Requested engine/fixed + data/geometry + tool/reader + corpus + engine/surface
  command with private inputs: exit 1, 468 passed / only the 19 new regressions
  failed. Log: build/a2-evidence-place/suites.log. All existing tests passed,
  including the two D9 checks on rerun. Corpus remains 58/58.
- Private anonymous aggregate: 5 books, 83/83 conserved sections, 6/6 fixed
  sections and units prepared, zero preparation/composition/import failures,
  and all final retained picture/image/scene/source counters zero.
- Fresh graphics module/fixed/parity, filters, clip-mask and foreignObject
  reports retain PASS for every variant (unsupported is typed refusal).
  SVG text retains all 10 host gates, device-gated. XHTML and mixed-navigation
  existing gate tests pass. No production row verdict was changed by this
  test-only slice; the new placement cases expose additional uncovered misses.
- Scoped dart format: exit 0, one file formatted; final format check and scoped
  analyze: exit 0, no issues. Final scoped whitespace check: exit 0.

Requests remain open; production fix and green regression verification require
the narrow caller scope extension above. Stop after this slice as ordered.

## A2-d9-filtered

### Review round 4b fix (2026-10-30)

Finding CONFIRMED and fixed in the classifier. A gradient-filled rectangle
filtered to opaque red by feFlood publishes image/combined output evidence.
The old combined-role fallback selected the input's gradient fill: changing
the actual red channel from 255 to 254 incorrectly passed D9. Both attribute
and CSS-filter regressions reproduced that false pass before the fix. The
ancestor-group variant already required exact output and remains a control.

Rule: after proving the topmost paint covers the pixel centre, inspect its
source node, referencing instance chain and their source ancestors. A non-none
filter attribute or oracle computed filter requires an exact sample before
any input fill/stroke role is resolved. Source attributes fail closed even
when computed filter evidence is absent; computed filters cover CSS effects.
The diagnostic records the filter owner, paint kind and published role. No
GeometryPaint field or production API was added, and no exemption was widened.
Raw declarations remain conservative when a cascade reset may disable them.

Regression-first verification uses actual native pictures and published alpha,
not color-based role selection. Three new cases cover attribute, CSS style and
ancestor-group filters. Each asserts the output is opaque red/image/combined,
rejects an injected delta-1 both in its sample record and the D4 samples gate,
and accepts exact filtered output. Each also overlays an unfiltered gradient
above a solid rectangle, with filter=none, and confirms that its topmost fill
role retains the delta-1 exemption. Attribute cases omit computed filter data
to exercise native source evidence; the CSS case supplies computed paint.
All scenes dispose and release their resource budgets.

Fresh row verdicts from the final requested directory run:
- Production SVG graphics: PASS; positive, boundary, nested and typed refusal
  all PASS, including module/fixed fidelity and parity; fixedPass=true.
- Production SVG filters, clip-mask and foreignObject: PASS; all four variants
  of each row PASS. No newly failing production sample was waived.
- Production SVG text: device-gated (A5), all 10/10 hostGate values true.
- XHTML cascade, box, paint, stacking, dimensions and metadata: PASS each.
  XHTML text: device-gated (A5), hostGate=true. Mixed-navigation: PASS.
- Legacy A0 filters, clip-mask and foreign-object: PASS. Provisional SVG text
  retains FAIL for its six required geometry cases (the three parent-length
  variants and path none/spacing/spacingAndGlyphs); each required pixel gate
  passes. These are the previously recorded limitations, not production text.
- HarfBuzz: hostD8Gate=true; SVG text verdict device-gated (A5).

Commands use the installed direct dart.exe and flutter_tools.snapshot, never
SDK bat wrappers. Flutter flags: --no-pub --reporter expanded -j 1.
- Regression-before: test fixed_layout_svg_samples_test.dart --name
  'D9 requires exact feFlood output': exit 1, one pass/two expected failures
  at the injected delta-1 pass assertion. An initial CSS setup attempt first
  failed capability because resolved presentation was omitted; it was corrected
  before the definitive red run (regression-before-resolved.log).
- Final test test/tool/reader: exit 0, 41/41 passed.
- Final test test/tool/reader/fixed_layout_svg_samples_test.dart: exit 0,
  10/10 passed, including all three added cases and existing role regressions.
- Scoped dart analyze on the two changed Dart files: exit 0, no issues.
- Scoped dart format --output=none --set-exit-if-changed: exit 0, two files,
  zero changes. Whitespace/source review passed; both Dart files were already
  untracked at session entry, so tracked git diff alone cannot inspect them.
- Logs and exact copies of all nine final reports: build/a2-d9-filtered/.

Used trellis-start, trellis-before-dev and trellis-check inline for the named
in-progress task; the missing per-session task pointer was expected. Edited
only tool/reader/fixed_layout_svg_samples.dart, its unit test and this appended
section. No lib/owner files, harness drivers, thresholds, D-rules, fixtures,
oracle, specs, dependencies or task pointers were changed; no network,
subagents, full suite, build_runner or git mutation was used. The 0.5 CSS px
gate, D3/D4/D7/D8/D9/D10, required rows and canonical v1 remain unchanged.

Requests: none. This completes only the A2-d9-filtered slice, not S4a/A5.

## A2-clip-exact

### Review round 4b fix (2026-10-30)

Finding CONFIRMED. The old _clipFootprint sampled Path.contains at pixel
centres and kept exactCoverage. A fractional rectangular clip published 255
where independent native clipped alpha is 191 at (10,20); its corner was
published as 255 instead of 96. Coincident fill/clip AA also differed (96
instead of 36), so clipping or multiplying an existing alpha grid is not an
exact replacement for replaying native drawing.

Fix in svg_feature_clip_mask.dart only:
- Removed binary point-in-path footprint clipping. Geometry still attaches
  registered clips and separate mask evidence; an awaited postPaint pass now
  replaces clipped leaf evidence before scene publication.
- Replays the compiled native leaf under its ordered ancestor/own clip paths.
  Mixed shapes replay the existing native compiler separately for fill/stroke,
  preserving native gradient/pattern/dash construction and role labels.
- Uses AuthoredEvidenceRaster.rasterize unchanged: one whole authored raster
  per clipped role, exact integer unfiltered tile copies, lossless trimming and
  uniform detection. No analytic clip shortcut remains. Integer rectangles
  become uniform only after all native samples have been inspected.
- Reuses the shared prepaid postPaint rasterBudget, serial with other evidence.
  Existing per-role clip-copy payload capacity covers retained samples; no new
  plan term, outer debit, cap, gate or threshold was introduced. Temporary role
  pictures/leases release in finally; helper raster/tile owners release there.
- Per-source feature paints that cannot be replayed from their combined owner
  picture are explicitly incomplete instead of attested as clipped/exact.

Regression-first unit run: exit 1, 34 passed / nine failed. Added 13 regressions
in the final unit file: fractional/integer/rotated rectangular clips, cubic
path, nested definitions, ancestor clip chains, use/group owners, independent
fill/stroke controls, coincident paint/clip AA, a 1103x769 rotated clip spanning
tile seams, preallocation refusal, and cancellation/late-failure lifetime.
Every retained sample and every transparent pixel is compared against an
independent native Canvas clip/draw control, including all fill/stroke roles.
Fractional outputs must retain nonuniform AA; the integer control is uniform
255. Large exact footprint equality covers every sample and all tile seams.
One authored raster is observed, native image peak is W*H + 512*512 pixels;
ledger peak remains the existing reservation (raster + tile + readback).
One-short layerPixels/layerBytes/vectorBytes refuses before image allocation.
Cancellation after the clipped raster/first/third tile and failure after clip
postPaint dispose every image exactly once, drain ledgers, and publish no scene.

Validation (direct installed dart.exe/flutter_tools.snapshot, --no-pub,
--no-version-check --reporter expanded -j 1; logs build/a2-clip-exact/):
- Unit + test/tool/reader/fixed_layout_svg_clipmask_test.dart: exit 0, 46 passed.
- All test/tool/reader + fixed_layout_corpus_test.dart: exit 0, 99 passed;
  corpus remains 58/58. Required row verdicts unchanged: graphics module/fixed/
  parity, filters, clip-mask and foreignObject variants PASS; unsupported cases
  typed refusal; SVG text all ten host gates true, device-gated (A5); XHTML
  cascade/box/paint/stacking/dimensions/metadata and mixed-navigation PASS.
  Legacy A0 provisional SVG-text FAIL stays unchanged; no gate reclassification.
- engine/fixed + engine/surface with the private sample: exit 1, 347 passed /
  19 failed, all in concurrent owner A2-evidence-place's newly added
  svg_graphics_evidence_placement_test.dart. After a ten-second wait, that
  excluded file rerun: exit 1, zero passed / the same 19 failed. Its appended
  owner record confirms test-only delivery and pending caller authorization;
  no edit was made to that owner's implementation/tests.
- Private anonymous aggregate: 5 books, 83/83 conserved sections, 6/6 fixed
  sections and units prepared, zero preparation/composition/import failures;
  all final retained picture/image/scene/source counters zero.
- Scoped format check: exit 0, two files, zero changes. Scoped analyze: exit 0,
  no issues. Scoped whitespace/source review passed. Production/unit files
  were already untracked; tracked git diff alone cannot inspect their content.

Requests / integration limits:
- A2-evidence-place's agreed root-coordinate raster extent must also be used
  by clipped evidence and its reservation. This slice deliberately reuses the
  existing authored-size extent; it does not solve the separate host-placement
  truncation defect. Its 19 regressions remain red pending the caller extension.
- The feature hook supplies no borrowed SvgGraphicsImages. Mixed-role replay
  can compile shape-backed patterns, but image-backed patterns need the admitted
  image bindings (or reusable compiled role pictures) from shared preparation.
  With the current hook that combination fails closed through the existing
  missing-admitted-svg-image refusal; it must not be approximated from alpha.
  Request that narrow shared-context handoff before claiming that combination.

Used Trellis start/before-dev/check inline; named task stays in progress in
expected degraded pointer mode. Edited only the assigned production file,
its unit tests and this appended owner section. No subagents, task-pointer/git
mutation, dependency/network work, generators, fixtures, oracle, specs, data
geometry public behavior or display-scale plumbing changed. Stop after slice;
full fixed green verification remains blocked on the separate placement owner.

## A2-evidence-place (continued)

#### Completion (2026-10-30)

Status: COMPLETE for this review slice after the caller scope extension. The
original 19 regression tests now pass. No whole-S4a/device acceptance is claimed.
Used the already loaded Trellis start/before-dev/check guidance inline; no
subagents or task-pointer mutation. The two concurrent owners' production files
were untouched, as were display-scale plumbing, AuthoredEvidenceRaster, public
data/geometry behavior, caps/gates/thresholds/D-rules, fixtures/oracle/specs and
dependencies. No network, git commit/push/stash/reset/checkout or broad suite ran.

Fix and placement contract:
- SvgGraphicsPlan now keeps optional enclosing authored evidenceSize/origin
  separate from the replaced SVG viewport size. FixedPreparationPlan supplies
  the resolved enclosing page extent before whole-unit admission, so inline
  host placement introduced later cannot truncate the raster to the local SVG.
- Direct SVG plans derive their root-coordinate extent from the effective host
  placement plus root transform/x/y. Bounds round outwards on the authored
  integer grid and retain the root canvas. Explicit evidence origins use the
  same grid; fractional host offsets remain in the native drawing matrix.
- SvgGraphicsPreparation passes the effective placement into reservation and
  uses that same evidence extent for the prepaid evidence ledger and each leaf
  role. Coverage and the analytic rectangle intersection now use that extent.
  A shifted raster is mapped back with a sample-sharing footprint translation;
  there is no alpha resampling, downsampling or rotated-box coverage substitute.
- Native evidence still rasterizes once as one whole authored image through
  unchanged AuthoredEvidenceRaster, followed only by exact integer-aligned
  unfiltered tile copies/readback. Roles/inline SVGs run serially and reuse the
  same scratch peak. The uniform rectangle shortcut keeps its native single
  sample only when all retained pixels are provably uniform.

Reservation:
- The evidence raster dimensions charge scratchPixels(actual width,height):
  one authored raster plus one tile image and its RGBA readback. Retained
  footprint payload bounds use the same evidence area, per role. Display-layer
  terms are unchanged. Existing enclosing-unit aggregation still takes a maximum
  of serial evidence peaks, rather than summing one raster per SVG/role.
- Checked evidence dimensions/area refuse beyond the existing layer cap before
  multiplication/native allocation. A prepare-time transformed-host request
  refuses with ResourceSectionCapability when its ledger is one pixel short,
  creates zero native images, publishes no paint/picture and drains all owners.

Tests:
- Original 19 regressions pass: integer/fractional/transformed hosts; rectangle
  shortcut/path fill, stroke, alpha image, separate dashed fill/stroke footprints,
  actual native raster versus reservation, and prepare-time placement override.
- Added explicit enclosing-origin native full-grid comparison, one-pixel-short
  preallocation refusal, and two real FixedSectionPreparer integrations. The
  latter keep the SVG viewport at 80x80, reserve the enclosing 320x240 authored
  evidence raster, and compare every merged footprint alpha with the actual
  native SVG picture under fractional and affine-transformed XHTML hosts.
- Focused original regression command: exit 0, 19 passed. Focused final placement
  plus fixed_section_preparer tests: exit 0, 37 passed.
- Final requested scopes, including private input: exit 0, 493 passed, no skips
  or failures. Corpus remains 58/58. All retained resource assertions pass.
- Anonymous private result: 5 books, 83/83 conserved sections, 6/6 fixed sections
  and units prepared, zero preparation/composition/import failures and all final
  retained picture/image/scene/source counters zero.

Row verdicts:
- Compared every recorded pass/gate/verdict/status field in seven public reports
  before versus after this patch: zero changes. Comparison artifact:
  build/a2-evidence-place/row-verdict-comparison.json.
- Graphics module/fixed/parity, filters, clip-mask and foreignObject retain PASS
  for every required variant (unsupported variants retain typed refusal).
  SVG text retains all ten host gates; XHTML and mixed-navigation gate tests
  pass. Existing device-gated verdicts remain device-gated. Corpus source/CFI/
  canonical vectors and the 0.5 CSS px gate remain unchanged.

Commands use installed direct dart.exe / flutter_tools.snapshot:
- test test/features/reader/engine/fixed test/features/reader/data/geometry
  test/tool/reader test/features/reader/data/epub/fixed_layout_corpus_test.dart
  test/features/reader/engine/surface --no-pub --reporter expanded -j 1,
  with the authorized private-input switch: exit 0 (493 passed).
- Scoped dart analyze on the four changed production and two changed test files:
  exit 0, no issues. Scoped format check: exit 0, six files, zero changes.
- Scoped tracked/new-file whitespace checks: exit 0. Public row comparison:
  exit 0. Logs: build/a2-evidence-place/regression-after.log,
  integration-after.log and suites-after.log.

Requests: none for this slice. The placement fix is ready for the coordinating
owner's review; the broader task and other owners' separate requests stay open.

## A3-scale-b (continued)

#### Implementation and closeout (2026-10-30)

Closed by a Sonnet closeout session after the Codex session that audited the
diff and landed three patches (image_cache.dart selective release,
fixed_preparation_scale_test.dart, fixed_image_reservation_test.dart) was lost
to a provider 503. Those patches were re-reviewed, not redone: ImageLease.release
is single-shot per lease; discard removes an entry only when its final lease
returns (either release order); a rejected cache-hit credit no longer drops the
live entry before throwing. No stale entry or double release was found. Only
change in this session: private_publication_regression_test.dart now keeps the
DPR 1 page geometry and compares the DPR 3 page geometry to it (SourceGeometry
equality, anonymous counts only). No cap, gate, threshold, D-rule, fixture,
oracle, spec, pubspec, data/geometry or svg_feature_clip_mask.dart change; no
git mutation, subagent or network use.

Scale flow: fixed_unit_surface.prepareFixedUnit derives one FixedPreparationScale
= min(viewW/authoredW, viewH/authoredH) x DPR from the frozen LayoutIdentity and
the page or spread extent (_fixedUnitExtent, shared with composition), and passes
it to FixedSectionPreparer.plan -> FixedPreparationPlan (plan.scale). The plan
derives image targets (imageTarget: min(intrinsic, ceil(authored x scale))),
decodedImageBytes, XHTML opacity layers (displayPixels x layers) and, via
SvgGraphicsPlan, SVG opacity/host buffers and feature layers (scaled by
displayPixels/authoredPixels). The same plan is the reservation and the
allocation input (FixedImageRequest.acquireAt targets, ReaderImageCache credit).
Harness drivers pass FixedPreparationScale.authored() explicitly.

Sites at scale: image decode targets, XHTML opacity layers, SVG opacity/host
buffers, clip/mask/pattern/dash feature layers. Authored: all evidence
(AuthoredEvidenceRaster, placed SVG extents, clipped roles), footprints, CFI/source
data, and (design row "Filter display scale") filter DAG caches, filter scratch
(_filterRasterPixels), and every image reachable under a filter
(authoredImagePaths, followed through references). Known limitation: a filtered
region is rendered at 1x authored resolution and may look softer than its
surroundings at DPR above 1; revisit with the S4c zoom generation.

Alpha-image path: every raster is first decoded at intrinsic size and its opacity
proved from decoded samples (no file-type assumption). Opaque: the intrinsic
decode is released and the display decode (smaller than intrinsic) serves display
and evidence, since evidence alpha then depends on geometry only. Alpha: the
intrinsic decode stays leased as the evidence raster until the scene is built,
then is released; the display decode is a second lease. Both are charged in
plan.decodedImageBytes (display + intrinsic). The cache refuses before codec
allocation with ImageAdmissionException (typed imageAdmission). Test: a fine
1x1 authored alpha hole that the 1x1 display decode hides is still in the
evidence. Note: intrinsic decode (not min(intrinsic, authored)) is used because
only the full decode can prove opacity; codec scratch is checked against cache
room at decode time, as before, and is not part of the unit credit.

Scale-1 equivalence: fixed_preparation_scale_test prepares the same source at
scale 1 and at .25 and 1.5 (XHTML opacity/text, placed SVG, mask/pattern/dash,
foreignObject, filter, opaque/alpha/hole images) and expects SourceGeometry
equality (fragments, paint roles, footprints, clips), identical CFIs, and the
documented plan deltas. Private sample: all 6 fixed pages have geometry equal
at DPR 3 versus DPR 1 (6 match, 0 differ). All corpus and tool/reader harness
verdicts are unchanged (authored scale).

Private sample, view 400x600, anonymous pages (requested layerPixels / peak
image bytes), 5 books, 83/83 sections conserved, 6/6 fixed prepared, zero typed
failures, final retained picture/image/scene/source counters all zero:
| Page | DPR 1 | DPR 3 |
| --- | --- | --- |
| 1 | 5,157,888 / 37,974,400 | 5,157,888 / 45,219,200 |
| 2 | 3,489,792 / 24,629,632 | 3,489,792 / 31,881,224 |
| 3 | 3,489,792 / 24,629,632 | 3,489,792 / 31,881,224 |
| 4 | 1,823,288 / 10,761,600 | 1,823,288 / 13,718,400 |
| 5 | 2,364,288 / 15,611,200 | 2,364,288 / 14,720,000 |
| 6 | 3,479,552 / 24,550,912 | 3,479,552 / 31,821,312 |
Layer pixels do not change with DPR because these pages have no opacity
layers; they are dominated by the authored evidence raster. Image peaks
rise with DPR as the display decode grows toward intrinsic. Cap 8,388,608 px
layers and 50,331,648 image bytes unchanged (page 1 at DPR 3 uses 45.2 MB).

Validation (direct dart.exe / flutter_tools.snapshot, --no-pub; logs under
ignored build/a3-scale-close/):
- engine/fixed + data/geometry + engine/layout + tool/reader + corpus: exit 1,
  581 passed / 27 failed; all 27 are svg_clipped_evidence_placement_test
  (owner A2-clip-extent's regressions, svg_feature_clip_mask.dart pending).
- engine/surface + features/diagnostics (no private env): exit 0, 256 passed.
- private regression (SHIORI_LOCAL_EPUB_DIR set for that command only): exit 0,
  both DPR passes, geometry equality asserted.
- scoped dart format --set-exit-if-changed on 19 files: exit 0, 0 changed.
- dart analyze lib test tool: exit 2, only 2 unused-import warnings in
  svg_clipped_evidence_placement_test.dart (A2-clip-extent, not touched).
Not run here: engine/support/local_books_support_test (stale S2 assertion).

Requests: none for svg_feature_clip_mask.dart (it already reads
plan.displayPixels). Dead plumbing: FixedSceneBuilder and the foreign-object
service carry preparationScale but do not read it; harmless, removable later.

## A2-clip-extent

### Placed clipped evidence (2026-10-30)

Finding CONFIRMED. `_clipFootprint` (and the sibling `_maskCoverage`) rasterized
`plan.size` at origin zero with no translation, so a placed, clipped inline SVG
(nonzero/fractional x/y or a transformed host) lost every sample outside the
local viewport box. A previous Codex session died on a provider 503 after
writing only `svg_clipped_evidence_placement_test.dart`; that file was reviewed,
two control bugs were corrected (the native image control lacked the picture's
own `clipRect`, and all controls lacked the root 80x80 viewport clip and one
composed host*clip matrix) and 10 reservation/refusal/mask/override cases added.

Fix, `svg/svg_feature_clip_mask.dart` only:
- New `_placedEvidenceExtent(prep)` returns the same authored root-coordinate
  extent that `_coverage` and the reservation use (`plan._evidenceBounds()`,
  i.e. enclosing evidenceSize/origin or placement-derived outward-rounded
  bounds). Clipped fill/stroke/image replays and mask coverage translate by
  `-extent.origin`, rasterize `extent` through unchanged AuthoredEvidenceRaster
  (one whole raster, exact tiles) and return `footprint.placed(translate(origin))`,
  exactly as `_coverage` does. No alpha resampling or analytic shortcut.
- Fail-closed guard: the extent is used only if the prepaid shared ledger
  (`rasterBudget` layerPixels) equals `_evidencePixels(extent)+_filterRasterPixels`.
  Otherwise clipped paints are marked clip-incomplete and masks refuse
  (`svg-mask-extent`) rather than silently truncating. This covers only a direct
  caller whose `prepare(placement:)` override differs from `plan.placement` while
  `evidenceSize` is null; production (FixedPreparationPlan always supplies
  evidenceSize) is unaffected.

Tests (`svg_clipped_evidence_placement_test.dart`, 46 cases): rectangle, rotated
and cubic-path clips on fill/stroke/image under origin, integer, fractional and
skewed hosts, every pixel of the placed extent equal to an independent native
control; reservation == scratchPixels(placed raster) (+ unchanged display layers);
authored raster allocated at the placed extent, peak 2*W*H, created == disposed;
one-pixel-short layerPixels refuses with zero native images and a drained ledger;
mask coverage equals a native control under all three hosts; the override mismatch
is incomplete. Regression-first: the corrected clip cases fail 27/36 and the new
mask/reservation cases fail on the old extent; all pass after the fix.

Validation (direct dart.exe / flutter_tools.snapshot, --no-pub, -j 1; logs in
build/a2-clip-extent/): engine/fixed/svg + fixed_layout_svg_clipmask_test: exit 0,
247 passed. New test + all test/tool/reader + fixed_layout_corpus_test: exit 0,
145 passed, corpus verdicts unchanged. engine/surface with the private sample:
exit 0, 99 passed; anonymous counts 5 books, 83/83 conserved sections, 6/6 fixed
sections and units prepared, zero blanks. Scoped format check exit 0; scoped
analyze exit 0.

Requests (svg_feature_hooks.dart, not owned): expose the effective evidence
bounds that `SvgGraphicsPlan.prepare` computes (`_evidenceBounds(placement)`) on
`SvgFeaturePreparation`/`SvgFeaturePostPaintContext`. The guard above would then
be replaced by the real extent for the prepare-time-override-with-null-evidenceSize
case, which is currently incomplete instead of exact.

## A3-ledger

### Retained evidence reconciliation (2026-10-30)

Goal: after a successful fixed preparation the shared unit ledger holds the
retained alpha evidence actually stored instead of the safe predecode upper
bound, without ever being below live allocations.

Trace. Planned: `FixedPreparationPlan.retainedEvidenceBytes` is the evidence
share of `resources[vectorBytes]`: XHTML `alphaMaps * (pixels + 128)` plus, per
SVG plan, `_coverageMaps * (retainedPixels + 128)` (`SvgGraphicsPlan.
retainedEvidenceBytes`, same formula `reservation()` now reuses) plus the filter
output payload (128 + 2 x viewport per filter use, attributed in the plan's
feature-admission loop by delta). Reserved: the unit surface (or a test/harness)
reserves `plan.resources` once on the shared `SceneResourceLease`; the scene and
SVG preparation only suballocate it through local ledgers (`FixedSceneBuilder`
budget, `svg_graphics_prepare` base lease, `evidenceBudget`). Stored: footprints
reachable from the published geometry (`GeometryAlphaFootprint.storageBytes`).
Released: unchanged (`FixedSceneAdmission.dispose` -> lease release).
`svg_graphics_prepare.dart` needed no edit: its leases are local accounting.

Change.
- `SceneResourceLease.shrink(resource, amount)` (additive, `scene_resource_budget.
  dart`): lowers one class of a live lease and the budget `used` counter; the
  lease keeps its CURRENT charge so `release()` returns exactly the remainder once.
  `charge` is now a live read-only view. Caps/limits/peaks unchanged.
- `RetainedEvidence.measure` + `FixedSceneAdmission.reconcileEvidence`
  (`fixed_scene_admission.dart`): measures distinct footprints by identity
  (paint footprints and mask coverage, merged geometry plus each SVG scene's) and
  releases `plan.retainedEvidenceBytes - chargedBytes` when positive; otherwise
  releases nothing (the bound stands, never an undercharge). A second call, a
  stale or unconsumed admission is a `StateError`.
- `FixedSectionPreparer`: `reconcileEvidence` is the last fallible step before
  `_result.complete` (after the picture reconcile, cancellation check and
  evidence-image disposal). Failure/cancel never reach it and keep today's single
  full release. `PreparedFixedScene` exposes `retainedEvidence`/`evidenceReleased`.
- Charge = stored `storageBytes` + one 128-byte wrapper per paint footprint and
  per mask application, because `geometryForUnit` (called once by the unit
  composer, outside this slice) creates those `placed()` wrappers that share the
  samples. A second `geometryForUnit` on a scene is a `StateError` (validation
  still throws `ArgumentError` first), so no footprint can appear after
  reconciliation unbilled.

Invariant. Until the single shrink the lease equals the full planned bound, which
already covered every live allocation (the local ledgers are limited by it and
run inside it); the shrink happens after the last footprint exists, to
`stored + placement wrappers`, which is >= every footprint reachable from the
published geometry. Transient rasters, tiles, filter caches, dash/pattern and
text envelopes are separate charges and untouched.

Measured (planned bound -> reconciled charge, bytes; corpus probe prepares each
case through `FixedSectionPreparer` with a shared budget; ignored
build/a3-ledger/corpus.json):
- 52 corpus cases: planned total 22,308,736, max 3,154,048. 35 prepare (17 are
  by-design plan/capability refusals that retain nothing): planned total
  20,231,680, max 3,154,048 -> reconciled total 270,180 (254,948 stored in 119
  footprints + wrapper allowance), max 38,644. Every prepared case releases; none
  stores more than its bound; `used` equals `reserved - released` and returns to
  zero after disposal.
- Private sample (anonymous, 6 fixed pages, 400x600): planned total 16,659,640,
  max 4,633,728 -> reconciled total 16,309,514, max 4,553,428 (350,126 released;
  these pages store page-sized non-uniform grids, so the gain is small); 83/83
  sections conserved, 6/6 fixed prepared, zero failures, zero retained counters.

Tests: `fixed_evidence_reconciliation_test.dart` (22) - measurement oracle
(uniform 128, trimmed grid real size, identity dedupe, mask coverage once,
wrappers per paint); real preparations for uniform XHTML, trimmed text, opacity,
fill+stroke roles, clip, mask+pattern+dash, filtered output, SVG text,
foreignObject: charge == independent sum, ledger == reserved - excess, other
classes untouched, shared charge held at the bound at every sample and at the
last allocating moment (>= the scene sub-ledger), filter bound delta == 128 +
2 x viewport, over-bound releases nothing, spread lease shrinks per page and
releases once, reconcile/placement twice are defects, failure, cancellation and
pre-canceled keep the full charge until one release with zero counters. Plus two
lease tests in `scene_resource_budget_test.dart`.

Validation (direct dart.exe / flutter_tools.snapshot, --no-pub): test/features/
reader + test/tool/reader + test/features/diagnostics with the private sample:
exit 0, 1837 passed, 2 skipped (pre-existing). `dart analyze lib test tool`: exit
0. Scoped `dart format`: exit 0.

Requests: (1) the unit composer owns `geometryForUnit`; if it ever places a scene
more than once the wrapper allowance must scale with the placements. (2) The
local ledgers still hold their prepaid figures until scene disposal; they are
accounting only and were left alone.


## fix-final-b

### Final review B fixes (2026-10-30)

All four findings CONFIRMED and fixed within the granted slice. Loaded
Trellis start/before-dev and applied check/update-spec inline. The named task
remains in_progress in degraded-pointer mode; no task creation/pointer change,
subagent, commit, dependency, network, fixture/oracle/generator or other owner's
implementation edit was performed.

1. Placed text evidence: per-source `_coverage` used the local SVG size and a
   new independent raster ledger. It now receives the preparation's effective
   `evidenceExtent`, shared `rasterBudget` and cancellation callback. Retained
   per-source grid bounds include the effective area plus footprint overhead
   inside the existing prepaid text envelope; uncharged local RGBA scratch was
   removed. The offset XHTML regression keeps the SVG at 80x80, places it at
   x=120 and compares every per-source evidence alpha with the actual native
   picture. Old coverage reports zero at a painted alpha-22 sample; fixed
   coverage matches the whole enclosing authored grid.
2. Filter viewport clipping: final generated primitives now replay inherited
   `SvgFeatureNode.clips` before output drawing, inside the isolated capture.
   Both displayed output and postPaint evidence therefore include the same
   hidden SVG/host viewport clips. The nested hidden 30x30 flood regression
   checks all native/evidence samples and four exterior points; the old output
   paints alpha 255 outside the viewport. The existing negative-output test now
   explicitly requests root overflow=visible, preserving its intended coverage
   while correcting its previous reliance on hidden-overflow leakage.
3. Effective extent: `SvgFeaturePreparation.evidenceExtent` and
   `SvgFeaturePostPaintContext.evidenceExtent` are required root-space Rects,
   populated at `_evidenceBounds(placement)` in graphics preparation. Clip and
   mask rasterization use these exact bounds/origin and the shared raster
   subdivision. Removed the pixel-count guard and redundant mask subdivision;
   equal area cannot attest equal origins. The extent is always available on
   these contexts, so no artificial unavailable-extent refusal remains.
   New clip/mask/text tests plan at +100 and prepare at -100 with identical
   admitted raster area; negative-origin evidence is retained. The existing
   larger-placement test now requires complete admitted evidence, rather than
   the obsolete guard's incomplete result. Full native clipped-grid equality
   and mask inside/outside samples pass; all local resource owners drain.
4. Text geometry gate: retained every original local Definition-B channel and
   additionally gates sourceToUnit-transformed starts, baseline advances and
   single-component rotation displacement. Expected screen placement comes
   from the recorded oracle element boxes and local character extent unions
   for the pinned translation-only corpus; path probes explicitly supply their
   recorded 8px capture-host margin. Missing screen evidence fails separately
   from cluster conservation. All 12 cluster comparisons remain conserved;
   translated, scaled and rotated published mappings fail. Original and nested
   production mappings and all path controls pass. No cap, threshold or D-rule
   changed; the 0.5 CSS px gate remains exact.

Regression-first evidence: tests were written before the implementation.
The initial clip/mask failures and flood leakage are in regressions-before.log
and regressions-before-retry.log under build/fix-final-b. Text execution was
initially blocked by concurrent fixed_scene.dart syntax; one retry still
failed, and the file was left untouched. Once repaired externally, the old
coverage call and ignored-transform behavior were temporarily restored only
in owned files to verify the three new text assertions fail (exit 1,
text-regressions-before.log), then the fixes were restored and tested green.

Final validation uses the installed direct dart.exe and flutter_tools.snapshot
entry points, never the SDK .bat wrappers:
- `test test/features/reader/engine/fixed/svg test/tool/reader
  test/features/reader/data/epub/fixed_layout_corpus_test.dart --no-pub
  --reporter expanded -j 1`: exit 0, 351 passed (251 SVG, 42 tool, 58 corpus),
  build/fix-final-b/suites-final.log. An earlier run had one concurrent XHTML
  text failure; its isolated retry passed before the final full-scope run.
- After separating the missing-screen diagnostic from cluster conservation,
  `test test/tool/reader/fixed_layout_svg_text_test.dart --no-pub --reporter
  expanded -j 1`: exit 0, 2 passed, text-gate-final.log.
- `test test/features/reader/engine/surface/private_publication_regression_test.dart
  --no-pub --reporter expanded -j 1`: exit 0, 2 passed. The private-input switch
  was set for this command only. Anonymous results at both DPR 1 and DPR 3:
  5 books, 83/83 conserved sections, 6/6 fixed sections and units prepared,
  zero import/composition/preparation failures, all retained counters zero;
  all six fixed geometries match across DPRs. private-after.log contains only
  anonymous numeric aggregates.
- Scoped `dart analyze` on all ten changed Dart files: exit 0, no issues;
  analyze-final.log. Final two-file gate diagnostic check: exit 0, no issues.
  Scoped `dart format --output=none --set-exit-if-changed`: exit 0, ten files,
  zero changes. Scoped whitespace/diff check: exit 0.
- Shared sqlite3 DLL deletion conflicts initially returned exit 1. Subsequent
  runs use APPDATA under ignored build/fix-final-b and a build-dir setting in
  that session-local configuration only (config command exit 0). Shared Flutter
  configuration was never changed. The final requested run completed there.

Every row verdict:
- cascade PASS; box PASS; paint PASS; stacking PASS; dimensions PASS;
  metadata PASS; mixed-navigation PASS.
- XHTML text hostGate=true, device-gated (A5).
- svg-graphics module/fixed/parity PASS; filters PASS; clip-mask PASS;
  foreign-object PASS. Positive/boundary/nested and typed-refusal variants
  retain their required gates in each production SVG row.
- Production svg-text: all ten host gates true, device-gated (A5).
- Legacy A0 filters/clip-mask/foreign-object PASS; provisional SVG-text FAIL
  remains unchanged and is not credited as a production/device pass.
- Seven public before/after reports have zero pass/gate/verdict/status changes
  (row-verdict-comparison.json). The additional screen channel raises the six
  ordinary SVG-text maxima from about 0.00011550 to 0.01521887 CSS px because
  of recorded WebKit box snapping; path maxima are unchanged. All original
  local channels remain checked, so this does not hide a local violation.

Updated reader-fixed-layout.md only for SVG text coverage/gate, filtered
viewport evidence and clip/mask effective extent; the concurrent owner's
reconciliation wording and other sections were preserved. Root causes were
missing coordinate-space handoff, incomplete application of viewport clips,
area-as-extent inference and missing integration/falsification vectors; the
new required contexts and native-grid regressions encode those boundaries.

Requests: none. This repair slice is complete; the parent task and A5 remain
with their owners.

## fix-final-a

### Final review A fixes (2026-10-30)

Verified the named in-progress task with the expected absent session pointer.
Used trellis-start, trellis-before-dev and trellis-check inline; no subagents,
task pointer changes, commits, dependencies, network, fixture/oracle/harness edits,
or edits outside this slice's production/test/spec ownership.

Regression-first evidence: added six tests before production changes; the focused
run exited 1 with exactly six intended failures (59 passed): inline SVG had zero
prepared scenes, inline img had zero paints, the wrapped span had zero decoration
paints, inline borders incorrectly returned complete, foreignObject counted one
footprint instead of two, and intrinsic alpha remained charged at the first
post-evidence picture callback (20,400 rather than 1,200 bytes). Log:
build/fix-final-a/regression-before.log. The first SVG pixel assertion incorrectly
assumed integer placement; after routing through real inline layout it was changed
to assert visible red paint plus the exact red center sample at the actual source
box (fractional edges legitimately antialias). No fixture or gate was changed.

1. Confirmed replaced-content loss. Inline SVG, img and inline-block contents use
   atomic paragraph placeholders, retaining their actual boxes, source anchors and
   independent SVG/image painting. Direct paragraph SVG and nested-span SVG are
   both covered. XHTML images preserve intrinsic ratio and constrained/auto sizes,
   and use display rasters for painting and intrinsic alpha rasters for evidence.
   Unsupported replaced elements or missing admitted images refuse typed.
   FixedSceneBuilder checks rendered source text against paragraph mappings and
   replaced roots against prepared boxes/scenes before publication; collapsed CSS
   indentation and hidden/nonrendered subtrees are excluded. Placeholder-only
   paragraphs publish no invented text paint. Planning/paragraph admission charges
   generated shaping units and image/inline-fragment evidence before allocation.
2. Confirmed inline decoration loss. Color backgrounds now paint source-linked
   line fragments before text/replaced children, with their own exact alpha
   evidence, source placement, opacity groups and paragraph content clip. Tests
   cover explicit br and automatic wrapping, indent and overflow clipping. Inline
   borders/background images/nonzero padding/margins/radii and backgrounds around
   replaced placeholders remain explicitly unsupported, never silently accepted.
3. Confirmed missing foreignObject owner. The host service exposes the original
   geometry retained through its disposal callback; FixedScene carries those host
   geometries into RetainedEvidence.measure alongside merged/SVG geometry.
   A uniform probe now charges exactly 384 bytes: 128 original + 128 exported +
   128 prepaid unit-placement wrapper. The independent measurement oracle now
   includes all host owners. The repeated geometryForUnit guard runs before any
   placement allocation; repeat calls fail StateError even with invalid arguments.
4. Partly refuted: intrinsic alpha already released before publication, and
   ReaderImageCache already admitted intrinsic scratch + output before codec
   allocation. The confirmed delay was retention through picture reconciliation.
   Release now occurs immediately when scene evidence production completes, before
   picture/evidence reconciliation, and the evidence-raster map is cleared.
   The regression measures 20,400 cache bytes after decode, then 1,200 at the first
   post-evidence callback and after publication; disposal returns zero. Existing
   codec-peak refusal, one-pixel alpha-hole, failure/cancellation and scale tests
   pass. No image_cache.dart change was necessary.
5. Confirmed stale specs. Updated reader-fixed-layout.md and
   reader-resource-admission.md for implemented reconciliation (including original
   host owners, placement wrappers and guard), inline paint/refusal contracts and
   the superseding intrinsic alpha-decode decision. Preserved concurrent owners'
   SVG text/filter/clip-mask spec edits.

Final validation uses installed dart.exe with flutter_tools.snapshot, test
--no-pub --no-version-check --reporter expanded -j 1. Final exact affected command:
flutter test test/features/reader/engine/fixed test/features/reader/data/geometry
  test/features/reader/engine/surface test/tool/reader/fixed_layout_scene_test.dart
  test/tool/reader/fixed_layout_scene_resolved_background_test.dart
  test/tool/reader/fixed_layout_spike_test.dart
  test/features/reader/data/epub/fixed_layout_corpus_test.dart
Exit 0: 583 passed (build/fix-final-a/verified-final.log). Earlier intermediate
failures from new collapsed-indentation/synthetic-indent checks were corrected;
a transient external SVG filter test failure passed on the single rerun without
editing its owner files. An added clipping test initially assumed one fragment
while its source allowed wrapping; its control now explicitly uses nowrap.

Verdicts unchanged: cascade/box/paint/stacking/dimensions/metadata pass, text
remains device-gated (A5) with hostGate true and no failed cases. Scene harness,
resolved-background, spike and all 58 corpus tests pass. No caps, thresholds,
D-rules, canonical/source/CFI vectors, fixtures, expected data or harness logic
were weakened or changed.

Private input was enabled for the test command only. Anonymous results at both
DPR 1 and 3: 5 books, 83/83 sections conserved, 6/6 fixed sections and units
prepared, 6/6 geometry matches across DPRs, zero typed/import/composition failures,
and zero final retained picture/image/scene/source counters. Image peaks remain
37,974,400 bytes (DPR 1) / 45,219,200 bytes (DPR 3). No private source artifacts
were printed, copied or recorded.

Scoped dart format (14 changed Dart files), dart analyze on the same files and
scoped git diff --check: exit 0; analyzer reports no issues. Initial test startup
hit the shared sqlite3.dll deletion race. APPDATA alone still collided, so the
ignored build/fix-final-a/appdata/.flutter_settings selects a session-only
build-dir of build/fix-final-a/flutter. Shared Flutter configuration is untouched.

Requests: the surface owner must extend PublicationFixedSourceLoader._images in
engine/surface/publication_fixed_sources.dart to admit XHTML img src using its
existing resource resolution/inspection path. This file is outside this slice;
pre-admitted imgs render correctly here, while a missing production admission now
refuses typed instead of publishing a scene that omits the image. No other request.
This slice is complete; the parent task/A5 remain with their owners.

## fix-final-c

### Final review C fixes (2026-10-30)

All four findings were confirmed against the current implementation before
production edits. The first compiled regression run exited 1 with ten failing
tests. Work stayed inline under owner fix-final-c; no sub-agents were spawned.

1. Mixed composition now stores composition metadata separately from retained
   PreparedSections. New surface/ReflowSectionCache is shared by composition
   and diagnostics/ReaderPreparationRepository: four entries, serialized and
   coalesced misses, LRU eviction before incoming preparation, pool section pins,
   and retained source/paragraph/text admission on the same scene ledger as the
   surface pool. Eviction/destruction releases its charge, including with zero
   live surfaces. An asynchronous reflow locator reloads evicted TOC/source
   targets; pagination/reading_unit_navigator.dart accepts FutureOr<int?> for
   this navigation seam. A queued-miss regression separately failed (exit 1)
   before adding the ordinary-task delivery boundary that lets borrowers pin
   before the next eviction. No cap or threshold changed. Retained accounting
   is not a claim about reflow transient native allocation/RSS.
2. Fixed/mixed publication commits capture digest, matching optional fixture ID,
   session, turn and accepted position together. Raw reflow open also commits
   identity only with its prepared session and retires preceding publication
   owners. Scripted capture uses the screen's S3-aware open path and cannot
   start after a failed/stale open using a retired identity. The route's original
   PreparedBook can be released: recomposition acquires/validates a temporary
   route lease before retiring the old independent lifetime, then releases that
   temporary owner in finally. Reflow -> fixed -> reflow drains old sessions,
   section owners, books and publication pins exactly once.
3. Fixed/mixed section/page jumps choose units containing the requested real
   source, including a spread's active side and last-unit selection. Settings
   and viewport/DPR changes prepare frozen replacement inputs and restore by
   source CFI, independent of the old page index. The screen observes metrics
   after layout and remeasures settings actions. Fixed scenario counts use one
   unit per source; long-paragraph scanning skips fixed surfaces safely.
4. reader-engine.md and diagnostics.md now describe these contracts and the
   implemented optional-work suppression/shared warm and demand preparation.
   The stale no-op/pending-coalescing description was removed.

Regression coverage: 18 new tests across publication_mixed_cache_test.dart,
reader_probe_final_c_test.dart and reader_probe_capture_publication_test.dart.
They exercise more reflow sections than capacity, retained ledger charges,
no-surface cleanup, pinned refusal/retry, queued delivery pins, evicted TOC
reload, fixed/mixed manual/scripted capture with current identity/position,
released-route navigation, fixed-safe counts, settings/metric recomposition,
source restore after page-count shrink, cross-route retirement and failed
scripted open suppression. Existing mixed SVG cleanup now disposes composition
before asserting that its retained cache charges have returned to zero. The
private regression passes the real pool into composition so its cache charges
share the measured ledger.

Validation used installed dart.exe and flutter_tools.snapshot directly, with
--no-pub --reporter expanded for Flutter tests. Final results:
- test test/features/reader/engine/surface
  test/features/reader/engine/pagination test/features/diagnostics: exit 0,
  385 passed, 2 pre-existing optional skips. Log: build/fix-final-c/suites-final.log.
- Private publication regression, SHIORI_LOCAL_EPUB_DIR scoped only to that
  child command: exit 0, 2 tests (DPR 1 and 3). Each pass: 5 books, 83/83
  conserved sections, 6/6 prepared fixed sections, 1952 reflow units, 6 fixed
  units, 0 blanks, 0 import/composition/fixed preparation failures, 0 typed
  outcomes; all retained resource counters zero. DPR 3: 6 geometry matches,
  0 differences. Log: build/fix-final-c/private-final.log (anonymous numbers only).
- dart analyze on all 13 changed Dart files: exit 0, no issues.
- dart format --output=none --set-exit-if-changed on those 13 files: exit 0,
  0 changed. Scoped git diff --check: exit 0.

Only the allowed surface/navigation/diagnostics files, their tests, the two
named specs and this appended owner section changed in this slice. No fixed,
image-cache, SVG, font/text, tool, fixture/oracle/generator, dependency, schema,
cap, threshold or D-rule edits; no downloads/network, codegen, broad formatting,
full suite, commit/push/stash/reset/checkout, task-pointer mutation or archive.
Requests: none. Stopped after this slice; no broader S4a/A5 acceptance claimed.

## fix-img-admit

### Inline img admission (2026-10-30)

Confirmed the named in-progress task, expected absent session pointer, and
fix-final-a/fix-final-c handoffs. Used trellis-start, trellis-before-dev and
trellis-check inline; no subagents or task-pointer mutation.

PublicationFixedSources._images now collects XHTML img src alongside SVG image
href/xlink:href, using the same empty/fragment/external filtering, URL set,
_localImagePath resolution, encoded-size inspection and pool request creation.
No srcset/picture selection was added. Updated only the image-admission contract
in reader-resource-admission.md; required images without admission still refuse
instead of publishing missing paint.

Added fixed_img_admission_test.dart through PublicationFixedHarness and the real
publication worker/preload/loader/pool path. Four success cases cover block img,
img nested inside a span, ../ resolution and duplicate src. They verify admitted
intrinsic dimensions, one request per URL, complete geometry, each image's source
paint and red center pixels in the prepared scene. Seven negative cases cover
external, protocol-relative, data, absent/empty/fragment-only src and a missing
local resource, verifying missing-admitted-image typed refusal. Success and
refusal both leave all pool/source/image/scene counters zero after disposal.

Regression-first evidence: the first compiled run, before production edits,
exited 1 with exactly four expected missing-admission failures and seven passes
(build/fix-img-admit/regression-before.log). After the loader change all 11 passed,
exit 0 (regression-after.log).

Validation used installed dart.exe and flutter_tools.snapshot directly:
- test test/features/reader/engine/surface test/features/reader/engine/fixed
  --no-pub --no-version-check --reporter expanded -j 1: exit 0, 517 passed
  (build/fix-img-admit/suites-final.log).
- test test/features/reader/engine/surface/private_publication_regression_test.dart
  with the authorized private-input switch set for that child command only and
  the same flags: exit 0, 2 passed (private-final.log, anonymous counts only).
- dart analyze lib/features/reader/engine/surface/publication_fixed_sources.dart
  test/features/reader/engine/surface/fixed_img_admission_test.dart: exit 0,
  no issues. Scoped dart format and final --output=none --set-exit-if-changed:
  exit 0, two files checked, zero pending changes. Scoped git diff --check: exit 0.

Anonymous private results at both DPR 1 and 3: 5 books, 83/83 conserved sections,
6/6 prepared fixed sections and units, 1952 reflow units, zero blanks, zero typed,
import, composition or fixed-preparation failures, and zero retained resource
counters. DPR 3: 6 geometry matches, zero differences. Image peaks remain
37,974,400 / 45,219,200 bytes. No private source, name, path, text, CFI, image or
digest was printed, copied or recorded.

Only the owned loader, new surface test, named spec contract and this appended
section were edited. No engine/fixed files, caps, thresholds, D-rules, fixtures,
source/CFI/canonical vectors, dependencies, generators, shared Flutter config,
network or git mutation. No broader S4a/A5 acceptance claimed.
Requests: none. This slice is complete; stopped after its handoff.

## fix-svg-position

### Final review B positioning fix (2026-10-30)

Finding CONFIRMED: `_layoutSvg` returned before XHTML containing-block/inset
resolution and translated only by flow. An authored left:120px rectangle
painted at x=10 rather than x=130 while capability was complete. The first
regression run exited 1 with 11 intended failures (9 existing tests passed):
nine native-placement mismatches and two unsupported positioning declarations
that incorrectly prepared complete. Log: build/fix-svg-position/regression-before.log.
A further regression through a static offset wrapper independently reproduced
the initial-containing-block mismatch before its SVG caller fix (exit 1,
initial-block-before.log).

Implementation: extracted XHTML containing-block selection and origin/inset
calculation into `_positioningBlock` / `_positionedOrigin`, reused by XHTML
and the SVG replaced box. The SVG caller passes the initial authored page
when an absolute root has no positioned ancestor, matching the existing
allocation-free sizing pass. Used SVG dimensions remain frozen by the plan.
Absolute/fixed left/top/right/bottom, percentage bases, trailing-size/margin
subtraction and relative offsets now resolve before scene preparation.
Paragraph placeholder and ancestor shifts finish before the existing
`prepare(placement: box.transform.compose(box.svgContentTransform))` call.
That call already feeds the effective evidenceExtent and sourceToUnit; no SVG
feature, graphics-preparation or evidence-allocation changes were necessary.
Position/inset diagnostics and unsupported CSS units are no longer discarded
by the SVG presentation diagnostic handoff: sticky and calc insets refuse
with the existing invalidValue:position / unsupportedUnit:calc identifiers.

Sixteen added checks cover 13 independently authored placement cases, an inline
relative-placeholder control and two typed refusals. Positive cases compare
every native and published alpha pixel across the authored page, including
transparent pixels, and check sourceToUnit, placed source corners, element
CFI round-trip, complete geometry and complete capability. Cases include all
four insets, absolute/fixed percentages, relative left/top and right/bottom,
positioned padding, static/positioned/nested/transformed ancestors and final
right/bottom ancestor shifts. The inline control checks an exact 12px/14px
translation against an independently prepared unpositioned paragraph, including
its fractional native baseline. An initial supplemental inline expectation
incorrectly assumed an integer baseline (one failure, 500 passing); this was
corrected to the native control without rounding or weakening alpha checks.

Validation uses installed direct dart.exe / flutter_tools.snapshot, never SDK
.bat wrappers; test arguments are --no-pub --no-version-check --reporter expanded
-j 1. No shared configuration or session APPDATA workaround was needed.
- `test test/features/reader/engine/fixed test/tool/reader
  test/features/reader/data/epub/fixed_layout_corpus_test.dart`: exit 0,
  503 passed, including 58 corpus tests; suites-final.log.
- Final stronger typed-identifier assertions: `test
  test/features/reader/engine/fixed/fixed_scene_svg_integration_test.dart`:
  exit 0, 25 passed; regression-after.log.
- `test test/features/reader/engine/surface/private_publication_regression_test.dart`:
  exit 0, 2 passed; private-final.log. The private-input environment switch was
  set for this command only and restored in finally. Anonymous results at both
  DPR 1 and 3: 5 books, 83/83 sections conserved, 6/6 fixed sections and units
  prepared, 1952 reflow units, zero import/composition/preparation/typed failures,
  all final retained counters zero. DPR 3 has 6/6 geometry matches with DPR 1.
- Scoped dart analyze and dart format --output=none --set-exit-if-changed on
  fixed_scene.dart, fixed_scene_layout.dart, fixed_scene_svg.dart and the
  integration test: exit 0, no issues / zero formatting changes. Scoped
  git diff --check: exit 0. Logs/artifacts are under build/fix-svg-position.

Public verdicts unchanged: eight before/after reports have zero pass/gate/
verdict/status changes (verdict-comparison.json). Cascade, box, paint, stacking,
dimensions and metadata PASS; mixed navigation checks PASS. Production graphics,
filters, clip-mask and foreign-object PASS. XHTML and production SVG text keep
hostGate=true and device-gated (A5). Legacy A0 filters/clip-mask/foreign-object
PASS and provisional SVG-text FAIL remain unchanged; no device pass is claimed.

Updated only the inline SVG sizing/positioning section in reader-fixed-layout.md.
Applied Trellis start/before-dev/check/update-spec inline for the named existing
in-progress task and expected absent session pointer. Changes stay within the
three granted scene implementation files, their integration test, that spec
section and this appended owner section. No subagents, task pointer changes,
commits, git mutations, dependencies, network, codegen, fixtures/oracle/generators,
caps, thresholds, D-rules or other owner's files/sections were changed.
Requests: none. This positioning slice is complete; stopped after its handoff.

## fix-r2

### Re-review R2 fix (2026-10-30)

R2 CONFIRMED; regression-first portion completed, production fix NOT applied.
The named task remains in_progress with the expected absent per-session task
pointer. Used Trellis start/before-dev/check inline; no subagents or task-pointer
mutation. This slice must not be considered complete or a new fidelity pass.

Added six tests to svg_feature_filters_test.dart. A hidden nested viewport at
(20.5, 25.25), size 30x30, is compared against an independently unfiltered native
control over the entire RGBA grid. The existing render helper separately checks
every native alpha against published evidence. Identity and blur fail on current
production code: the corner control alpha 96 becomes 36 and 29 respectively;
the control's straight top-edge alpha is 191. Flood already matches the control
with single-application AA. Descendant viewport, descendant clip-path and nested
filter/descendant viewport controls pass, preserving their local clipped output
and transparent exterior. Oversized input and a 40x40 admitted filter region
keep blur solid throughout the hidden viewport without changing any caps.

Cause: filter paint calls captureDefault(), whose _paintLeaf traversal applies
the inherited node.clips, and then applies node.clips again around final output.
The callback and instance clip lists are final; safely excluding inherited clips
from capture needs a shared paint/capture seam. Requested scope extension for
svg_feature_hooks.dart and svg_graphics_prepare.dart via an asynchronous user
question; no approval was received before this handoff. Neither out-of-scope
file was edited. No temporary mutation of shared or potentially immutable clip
lists, duplicated wrapper traversal, or alpha compensation was introduced.

Concrete remaining change: captureDefault should pass a set of output clip IDs
through its next-wrapper/default callback and _paintTree; _paintLeaf excludes
only those IDs during input capture. Descendant IDs remain active. Nested filters
must union their capture exclusions with the current exclusions, and replay only
clips not already owned by an outer output capture. The filter's final viewport
clip stays inside its isolated output picture so display and postPaint evidence
consume the same once-clipped output. Update only the filtered-output evidence
paragraph after implementing and verifying this contract. The spec is unchanged
because production behavior is not yet repaired.

Checks used direct dart.exe / flutter_tools.snapshot, --no-pub
--no-version-check --reporter expanded -j 1. Logs: build/fix-r2/.
- Initial shared-build test: exit 1, sqlite3.dll deletion conflict. Session-local
  APPDATA and build-dir under build/fix-r2 configured successfully (exit 0);
  shared Flutter configuration was not changed.
- Initial oversized regression filter region was refused by existing admission;
  reduced test region to admitted 40x40 before recording the meaningful result.
- regression-before.log, viewport-name subset: exit 1, 4 passed / 2 intended
  failures (identity and blur); descendant clip-path is covered in the full run.
- baseline-hooks-harness.log: exit 0, 15 passed (14 hooks + 1 harness).
- targeted-before.log, all three requested test files: exit 1, 42 passed / 2
  intended new regression failures; no existing test failure.
- Scoped dart analyze on the changed test: exit 0, no issues (analyze.log).
- Scoped dart format and final --output=none --set-exit-if-changed: exit 0,
  zero pending changes (format.log).

Every filters row variant from the unchanged production harness report:
filters-positive PASS (prepared), filters-boundary PASS (prepared),
filters-nested PASS (prepared), filters-unsupported PASS (typed refusal).
The row remains PASS; these existing corpus verdicts do not close the R2 defect.

Requests: authorize the two shared paint/capture files named above, or have their
owner add that seam, then resume the production fix and rerun only this scope.
Only the granted test and this appended owner section were edited. No spec,
threshold, D-rule, fixture/oracle/generator, pubspec/dependency, network, git
mutation or other owner's file/section was changed. Stopped at the scope boundary.

#### Completion (2026-10-30)

The owner granted svg_feature_hooks.dart and svg_graphics_prepare.dart for this
input-capture fix. R2 is now fixed; this completion supersedes the pending fix
and scope request above. No subagents were used and no other owner's files
were edited.

SvgFeaturePaint.captureDefault accepts optional excludeViewportClipIds and
unions them with the current input-capture exclusions. The existing wrapper
callback and _paintTree carry that set to leaves; _paintLeaf omits only matching
viewport clip IDs. Ordinary paintDefault/captureDefault calls keep their prior
clipping. SvgFilterFeature excludes its inherited output viewport IDs from
SourceGraphic, then applies the inherited clips once around final output. Nested
filters preserve outer exclusions and apply only viewport clips not deferred to
the outer output. Descendant viewport clips, clip-paths and mask wrappers remain
in the captured input. No clip lists are mutated, no wrapper traversal is copied,
and capture call counts, caching and scene ownership remain unchanged.

Display and postPaint consume the same isolated output picture, including its
single application of viewport AA. The six original regressions all pass:
identity/flood/blur match every control RGBA pixel and every displayed alpha
matches published evidence, retaining edge alpha 191 and corner alpha 96;
exterior leakage remains zero. Descendant viewport, descendant clip-path and
nested-filter descendant clips stay honored. Added two filtered-leaf controls
(with/without an outer filter) for inherited edges and one generic default
capture replay control with fractional inherited/descendant clips. The latter
compares both replayed copies against independently painted viewports and checks
capture disposal and zero remaining budget charges.

Updated only the filtered-output evidence paragraph of reader-fixed-layout.md
with the ID exclusion, nested-filter ownership and single-application AA contract.
Evidence extent/origin, admission, caps, D-rules, fixtures and expected data are
unchanged. Other features' implementations were not edited.

Final validation uses direct dart.exe / flutter_tools.snapshot with session-local
APPDATA/build-dir under build/fix-r2, --no-pub --no-version-check --reporter
expanded -j 1; no SDK .bat wrappers or shared configuration changes.
- Initial post-fix filter suite: exit 0, 29 passed (filters-after.log).
- Final requested six-file run: exit 0, 126 passed (targeted-final.log):
  svg_feature_filters_test.dart 31; svg_feature_hooks_test.dart 15;
  test/tool/reader/fixed_layout_svg_filters_test.dart 1;
  svg_feature_clip_mask_test.dart 45; svg_feature_text_test.dart 15;
  svg_feature_foreign_object_test.dart 19. No failures or skips.
- dart analyze on the three changed implementation files and two changed tests:
  exit 0, no issues (analyze-final.log).
- dart format on those five files and final --output=none --set-exit-if-changed:
  exit 0, zero pending changes (format-final.log).
- Scoped git diff --check: exit 0 (tracked-file whitespace check).

Every filters row verdict: filters-positive PASS (prepared), filters-boundary
PASS (prepared), filters-nested PASS (prepared), filters-unsupported PASS
(typed refusal). Row PASS. Each prepared variant retains filterEvidencePass=true,
its original geometry/D4/D9 gates and zero remaining budget charges. This is a
host slice result, not broader S4a completion or A5/device acceptance.

Requests: none. This slice is complete; stopped after the authorized fix and
checks. No task-pointer mutation, commit/push/stash/reset/checkout, dependency,
network, codegen, broad formatting/test run or unrelated spec/progress edits.

## fix-r1

### Re-review R1 fixes (2026-10-30)

All four findings CONFIRMED. Used Trellis start/before-dev/check inline for the
named in-progress task and expected absent session pointer. No sub-agents,
task-pointer mutation or commit. Changes stayed within this owner's scope.

Regression-first evidence: after correcting test-only import/constructor errors,
the compiled pre-fix run exited 1 with eight intended new failures and 36 passing
existing tests (build/fix-r1/regression-before.log). The stronger image collision
control also failed before its loader/paint changes: four failures, 11 existing
passes (image-before.log). Both resources must enter the preload graph for the
archive-key collision to be observable; the tests preload the root image through
CSS. No expected fixture data or oracle was changed.

1. fixed_scene_layout.dart now detects absolute/fixed descendants at the start
   of inline collection, lays them out through the containing-block path and
   returns before paragraph allocation/placement. The two nested-span SVG tests
   require the authored (120,70) box, unchanged prefix/suffix text without a
   placeholder, exact SVG alpha over the whole page, native red pixels, complete
   geometry and complete capability. Both failed with a paragraph-derived box
   before the production fix.
2. Ancestor _shift recursion skips viewport-fixed child subtrees; each fixed
   element can still perform its own final inset placement. The right/bottom
   ancestor plus intermediate wrapper regression retains SVG (120,70), comparing
   every native/published alpha sample, sourceToUnit, corners, CFI and capability.
   Its pre-fix expected pixel was transparent.
3. fixed_preparation_plan.dart includes relative inline-blocks in the existing
   shifted-inline paragraph/text envelope. The static inline-block control
   prepares, while the relative control failed before the fix. It now prepares
   complete, shifts exactly 10px and has native red and published opaque evidence
   at the placed box. A test-only paint selection was narrowed to the decoration
   channel after the first post-fix run exposed multiple paints for that node.
4. publication_fixed_sources.dart resolves img src and SVG image href/xlink:href
   strictly against the section document before mixing them with CSS requests;
   no raw archive-key/reference fallback applies to element URLs. Raw attribute
   lookup keys remain available to existing img/SVG consumers. When a resolved
   CSS path has the same spelling as a raw element URL, fixedCssImageKey assigns
   CSS its own internal key. fixed_scene_paint.dart uses that key for display,
   intrinsic dimensions and authored evidence replay; the preparation plan uses
   it for CSS filter-input admission. This preserves both resources rather than
   allowing one dictionary entry to overwrite the other. Four production-path
   tests cover img and SVG image, with/without the document-relative resource:
   red section-relative image, independent blue CSS background, alpha at the
   placed image, complete capability only on success, typed refusal without a
   fallback, and drained owners. The final negative controls keep the colliding
   CSS resource actively painted as well. All 15 image admission tests pass.

Updated only the matching replaced-element/positioning/admission sentences in
reader-fixed-layout.md and reader-resource-admission.md. No thresholds, D-rules,
required rows, canonical/source/CFI vectors, fixtures, dependencies, generators,
filter-owner implementation, reflow cache, composition or diagnostics edits.

Validation used installed dart.exe and flutter_tools.snapshot directly. Every
Flutter command used --no-pub --no-version-check --reporter expanded -j 1.
The shared sqlite3.dll deletion race occurred during the pre-fix run. Per the
order, APPDATA was scoped to build/fix-r1/appdata for each later command; its
local .flutter_settings selects build/fix-r1/flutter. Shared Flutter config was
not changed. Environment values were restored in finally.

- test test/features/reader/engine/fixed/fixed_scene_test.dart
  test/features/reader/engine/fixed/fixed_scene_svg_integration_test.dart
  test/features/reader/engine/fixed/fixed_section_preparer_test.dart
  test/features/reader/engine/fixed/fixed_preparation_scale_test.dart
  test/features/reader/engine/surface/fixed_img_admission_test.dart
  test/tool/reader/fixed_layout_scene_test.dart
  test/tool/reader/fixed_layout_scene_resolved_background_test.dart
  test/tool/reader/fixed_layout_spike_test.dart: exit 0, 112 passed
  (build/fix-r1/targeted-final.log).
- test test/features/reader/engine/surface/fixed_img_admission_test.dart after
  strengthening the missing-resource CSS control: exit 0, 15 passed
  (build/fix-r1/image-final.log). No production changes followed the 112-test run.
- test test/features/reader/engine/surface/private_publication_regression_test.dart:
  exit 0, two passed (build/fix-r1/private-final.log). The private-input switch
  was set only for that command and restored in finally. Anonymous results at
  DPR 1 and 3: 5 books, 83/83 conserved sections, 6/6 fixed sections and units,
  1952 reflow units, zero blanks/import/composition/preparation/typed failures,
  and zero final retained picture/image/scene/source counters. DPR 3: 6/6
  geometry matches, zero differences. Image peaks: 37,974,400 / 45,219,200 bytes.
  No private name, path, text, CFI, image or digest was printed/copied/recorded.
- dart analyze on the seven changed Dart files: exit 0, no issues. Final scoped
  dart format --output=none --set-exit-if-changed: exit 0, seven checked, zero
  changes. Scoped git diff --check: exit 0.

Requests: none. This slice is complete; no broader S4a/A5 acceptance claimed.

#### Re-check fix (2026-10-30)

Remaining item 1 CONFIRMED. The inline collector flattens relative non-atomic
inline elements without retaining the CSS first/last fragment containing-block
rectangle. Reusing the enclosing block therefore loses the inline ancestor's
placement. Chose the explicitly authorized typed-refusal route rather than an
offset-only approximation that would still be incorrect for multiline spans.

Regression-first run: recheck-before.log exited 1 with exactly three new failures
(single-line relative span, relative span across br, nested relative span); each
incorrectly published a PreparedFixedScene. The two new positive controls and
29 existing tests passed (31 passes total). Pre-fix successful scenes are disposed
by the tests so this failing baseline does not leak owners.

fixed_scene_layout.dart now checks an absolute descendant's nearest positioned
ancestor before creating its box or SVG scene. A relative non-atomic XHTML inline
ancestor refuses with UnsupportedSectionCapability and the source-linked reason
inline-positioned-containing-block. A nearer positioned block/atomic element
ends the search; viewport-fixed descendants are unaffected. The foreignObject
host remains its own containing-viewport boundary. No partial scene is published.

The three regressions require that typed reason, incomplete capability and the
offending SVG node. Fixed-SVG/positioned-block controls compare every native and
published alpha pixel against their authored positions and remain complete.
Updated the matching reader-fixed-layout.md sentence with this exact limitation.

Validation used direct installed dart.exe and flutter_tools.snapshot with
--no-pub --no-version-check --reporter expanded -j 1 and the existing session-local
APPDATA workaround. Only the eight previously specified public test files ran:
exit 0, 117 passed (build/fix-r1/recheck-targeted.log). The private publication
regression ran separately with its private-input switch scoped to that command:
exit 0, 2 passed (recheck-private.log). At DPR 1 and 3: 5 books, 83/83 sections
conserved, 6/6 fixed sections and units prepared, 1952 reflow units, zero blank,
import/composition/preparation/typed failures and zero final retained resource
counters; DPR 3 geometry matches 6/6, zero differences. No private source data
was copied or reported. Environment values were restored in finally.

Scoped dart analyze on the two changed Dart files: exit 0, no issues. Scoped
dart format --output=none --set-exit-if-changed and git diff --check: exit 0.
Only the layout file, its integration test, matching spec sentence and this
owner subsection changed. No other owner files, thresholds, D-rules, fixtures,
dependencies, network, sub-agents or git mutations. Requests: none; stopped here.

## fix-r3

### Re-review R3 fixes (2026-10-30)

Both findings CONFIRMED in the named in-progress task. Read fix-final-c and the
retained-reflow/probe contracts; used Trellis start, before-dev, check and
update-spec inline. The absent session pointer is expected. No subagents,
new task, task-pointer mutation, commit, or archive.

1. P1: the queued section-5 miss destroyed cached section 4 before its pending
   borrower could install a pool pin. Two compiled regressions (raw cache and
   mixed composition) failed on debugDisposed=true before the fix; see
   build/fix-r3/regression-before-valid.log. Every request now synchronously
   reserves an explicit per-delivery eviction pin, including cached hits and
   each coalesced borrower. borrow() transfers an idempotently released
   ReflowSectionLease; composition metadata/anchor users release in finally.
   The compatible load() path uses synchronous completion to hand off to the
   awaiting borrower's synchronous surface-pin installation before releasing
   its delivery lease. Eviction skips both delivery and surface pins. Capacity
   remains four; coalesced physical loads retain one admission charge. Tests
   also check independent coalesced miss leases, duplicate release, typed
   refusal/retry, null/error/closure cleanup and zero final resource counters.
2. P2: retirement discarded the replacement factory and session==null blocked
   later metrics scheduling. Four screen regressions failed with an empty
   session on the original implementation after the test harness was corrected;
   build/fix-r3/probe-before-valid.log. Retirement now retains the factory and
   accepted source. Later measured changes keep scheduling and supersede stale
   candidates using the latest requested settings; reflow restores from retained
   source position while the display is absent. Explicit release/raw replacement/
   disposal clear intent. A latest reflow that publishes no session raises typed
   ParseException, and overlapping screen actions remain busy until all drain.
   Tests pause real worker preload across two/three metrics changes, each with
   and without interleaved settings, and assert latest layout, original source,
   displayed PreparedReader, idle queue and zero scene charges. A separate
   latest-cancellation test verifies typed failure and successful retry.

Eight added tests total. Initial test-authoring compile/viewport/pumping issues
were corrected before the valid failing baselines above. The initial sqlite3.dll
delete failure used the instructed workaround: subsequent Flutter commands set
APPDATA only in their child shell under ignored build/fix-r3/appdata; shared
Flutter configuration was untouched.

Final validation, direct installed dart.exe / flutter_tools.snapshot with
--no-pub --reporter expanded, no SDK .bat wrappers:
- Targeted test command: the eight requested public suites plus the new
  reflow_section_cache_delivery_test.dart and
  reader_probe_replacement_coalescing_test.dart: exit 0, 61 passed.
  Exact suite paths and results: build/fix-r3/targeted-final.log.
- Private publication regression: exit 0, 2 passed (DPR 1 and 3). The private
  environment switch was set for that child command only and restored in
  finally. Each DPR: 5 books, 83/83 sections conserved, 6/6 fixed sections and
  units prepared, 1952 reflow units, zero blanks/import/composition/preparation
  failures or typed outcomes, and all final retained counters zero. DPR 3:
  6/6 geometry matches, zero differences. Anonymous-only log:
  build/fix-r3/private.log. No private names/paths/text/CFIs/images/digests copied
  or reported.
- Scoped dart analyze on the seven changed Dart files: exit 0, no issues;
  build/fix-r3/analyze-final.log. Scoped dart format --output=none
  --set-exit-if-changed: exit 0, seven files, zero changes. Scoped git diff
  --check: exit 0.

Updated only the authorized cache/composition delivery seam, probe controller/
screen, their tests, matching reader-engine.md / diagnostics.md sentences and
this appended section. No engine/fixed, SVG, source loader, tool, cap, threshold,
D-rule, canonical/source/CFI vector, fixture, dependency or generator changes.
No network/download, broad tests/formatting or private content output.
Requests: none. This slice is complete; no broader S4a/A5 acceptance claimed.

## hb-ios

### HarfBuzz iOS wiring (2026-10-30)

Worked inline in the existing in-progress S4a task with the expected empty
Codex task pointer. Loaded trellis-start, trellis-before-dev and trellis-check;
no task/pointer change, sub-agent, source/tool download on Windows, commit,
push, branch or tag. The pre-existing execution-log.md change was preserved.
The main session owns the push and first hosted build.

Owner approval: "Approve HarfBuzz" on 2026-10-30 authorizes the CI source
download, build and linkage. Pinned official 14.6.0 release source to
20,295,260 bytes and SHA-256
`d07a007327277708a2a73ae437887cdbaf282937f6d03ca5467723e9099af586`;
CI verifies both before extraction. It checks the source COPYING against
`ba8f810f2455c2f08e2d56bb49b72f37fcf68f1f4fade38977cfd7372050ad64`
and retains the complete notice; product licence registration and per-file
notice review remain S4c work.

Changed tool/ci/build_harfbuzz_ios.sh, tool/ci/build_ios_unsigned.sh,
.github/workflows/ios-unsigned.yml, ios/Flutter/{Debug,Release}.xcconfig and
the new ios/Flutter/HarfBuzz.xcconfig, plus this log and the packaging plan.
No Dart/bindings, project.pbxproj, pubspec, product UI, engine, fixture, test
or .trellis/spec files were changed.

The build script now runs before flutter build ios in both existing modes.
It uses the runner's preinstalled CMake, with an explicit prerequisite check
and actual path/version in provenance; it downloads no additional toolchain
and uses no cross-run cache. Each invocation uses a fresh mktemp source/build
directory. Builds static device arm64 and simulator arm64/x86_64 at iOS 15.0,
force-including the same generated hb_/_hb_/C++ namespace prefix map in every
C/C++ translation unit. Keeps the disabled dependency/subset controls,
disables declared optional companion components, rejects enabled optional
HB cache controls and unused CMake arguments, audits each thin archive's
defined/undefined symbols and defining global scopes without an allowlist,
then creates the combined simulator archive and static XCFramework.

The single link owner is HarfBuzz.xcconfig included by Debug/Release (also
Profile through the existing Release base). SDK-conditional OTHER_LDFLAGS
inherits existing values, force-loads only the selected audited archive,
adds all required linker roots and system libc++, and uses export_dynamic
to preserve main-executable process exports without replacing an export list.
Generates a separate build-only HarfBuzz.generated.xcconfig; no generated
Flutter or Pods files are hand-edited. Static libraries are not embedded,
and Flutter's own HarfBuzz is untouched.

HarfBuzzBindings._required in hb_bindings.dart is the sole symbol-list source.
The fail-closed extractor currently returns 33 _shiori_hb_* names; the exact
list was printed with Git Bash/Python and retained at
build/hb-ios/required-symbols.txt. Archive checks, -Wl,-u roots and final
executable checks consume that list; verification regenerates and compares it
to catch source drift during a build. The existing iOS process lookup and
exact runtime 14.6.0 check needed no Dart changes.

After the Flutter Release build/strip, --verify-runner audits the actual app
executable with nm and dyld_info. Every required name must be defined and
exported, and its live link-map entry must belong to the fresh device archive.
Missing, unexported, dead-stripped-only or wrong-owner names fail packaging.
The existing always-upload path includes build/ios-$BUILD_MODE/harfbuzz/:
verified source/input/COPYING hashes, toolchain versions, prefix/root configs,
per-slice configure/build/install logs and CMake caches, raw/demangled symbol
and global inventories, three thin and one fat archive hashes, zipped
XCFramework, Runner inventories/hash/audit and full/excerpted link maps.

Windows validation:
- bash -n on both changed scripts: exit 0. Existing
  check_ios_build_modes.sh syntax and execution: exit 0 (default/probe/app
  plans, package names and all invalid-input refusals unchanged).
- Git Bash --print-required-symbols using installed Python: exit 0, 33 names.
  Eight embedded Python blocks compile; synthetic production-heredoc checks
  cover valid prefix/link-map/export cases and refusal of duplicate/nonliteral
  Dart entries, raw undefined HB, missing archive/final definitions, unprefixed
  C/C++ owners even with prefixed argument types, missing exports, wrong/missing
  live map attribution and enabled optional dependencies: exit 0.
  Generated roots match the 33 names exactly, including paths with spaces.
  Evidence: build/hb-ios/local-audit-checks.log.
- Workflow YAML parsed with the already installed Dart yaml package after
  Python reported PyYAML unavailable; no package installed. Action SHA pins,
  existing runner/timeout and upload behavior checked: exit 0
  (build/hb-ios/workflow-check.log). xcconfig include path, SDK selection,
  inherited flags and single link owner checked: exit 0.
- Direct installed dart.exe + flutter_tools.snapshot test --no-pub
  --reporter expanded -j 1 test/features/reader/engine/text: exit 0, 17 passed,
  no skipped host cases (build/hb-ios/text-tests.log). APPDATA was scoped to
  ignored build/hb-ios/appdata in the child shell and restored in finally.
  Existing measured D4 failures remain failures; this is not an A5 fidelity pass.
- No product Dart changed, so scoped product dart analyze is not applicable.
  git diff --check: exit 0.

Only the first macOS CI run can establish actual preinstalled CMake/Xcode/SDK
availability, all three compiled slices, CMake option compatibility, strict
archive audits, XCFramework packaging and final Release export/map evidence.
Unknown compiler helpers, C++ globals or tool-output drift must fail for review;
no permissive symbol exception or fallback is added. Unsigned CI cannot launch
the device executable: version return, DynamicLibrary.process() in real AOT,
the six fixtures, callback/resource lifetime, device raster and performance
remain A5 device/simulator gates. This session claims wiring and host checks,
not Apple CI success or broader S4a/A5 acceptance.

#### CI fix 1 (2026-10-30)

Owner hb-fix1, inline in the existing task with the expected empty Codex
pointer. CI run 41034103866 configured device-arm64 on macos-15 / Xcode 26.3,
then failed the strict static-cache check: the untyped command-line definition
became BUILD_SHARED_LIBS:UNINITIALIZED=OFF, not the required BOOL=OFF. This
was a cache-type mismatch, not evidence that a shared library was built.

Changed only tool/ci/build_harfbuzz_ios.sh and this progress section. All 24
supplied cache definitions now have explicit types. One retained component
flag manifest drives both configure and exact type/value validation. The
pinned 14.6.0 HB BOOL switches are explicitly OFF; HB_BUILD_GPU_DEMO is
explicitly STRING=OFF. Removed option()-only discovery, which missed this
STRING control. The artifact's help text and INTERNAL choice list identify
AUTO/ON/OFF; AUTO is no longer accepted. Unknown HB cache entries of any type,
wrong types/values, missing required entries and duplicates fail closed. Only
the exact GPU_DEMO choice-list metadata is exempted as non-executable metadata.
The strict BUILD_SHARED_LIBS:BOOL=OFF and unused-argument checks remain;
archive/global/export/link-map checks are unchanged. The rest of both build
scripts has no other CMake cache-type check; build_ios_unsigned.sh needed no edit.

Local checks used the downloaded artifact read-only, with the production
Python heredoc extracted unchanged. Original device cache: exit 1 with the
explicit BUILD_SHARED_LIBS:BOOL=OFF diagnostic. Correcting only that entry:
exit 1 for HB_BUILD_GPU_DEMO:STRING=AUTO. Synthetic cache with both corrected:
exit 0. Regression matrix: exit 0, 237 cases including shared builds, alternate
truthy/false spellings, wrong types, missing/duplicate entries, unknown BOOL/
STRING/INTERNAL controls, metadata drift and malformed flags. Refusals exit 1.
Evidence and synthetic inputs: ignored build/hb-fix1/cache-checks.log and
adjacent files. All seven embedded Python blocks compile: exit 0. bash -n on
both build scripts and check_ios_build_modes.sh: exit 0 each; build-mode
selection/refusal checks: exit 0. git diff --check: exit 0.

No source/tool download, git mutation, sub-agent, workflow pin, xcconfig,
Dart or spec change. The pre-existing execution-log.md edit was preserved.
Source CMakeLists was unavailable locally; the script now retains it in CI
provenance. Next CI must confirm that 14.6.0 consumes STRING=OFF to disable
the GPU demo, with no AUTO fallback or enabled companion/dependency, and
accepts the exact typed cache contract without unused arguments for all three
slices. It must then pass the unchanged static archive/global audits,
XCFramework packaging and final Runner exports/live link-map attribution.
Apple compilation and A5 runtime/device acceptance remain unproven locally.


#### CI fix 2 (2026-10-30)

Owner hb-fix2, inline in the existing in-progress S4a task with the expected
empty Codex pointer. Read trellis-start, trellis-before-dev and trellis-check;
no new task, pointer change, sub-agent, download, git mutation, workflow pin,
Dart, spec, pubspec or xcconfig change. Preserved the pre-existing
execution-log.md edit. Main-session push/CI and A5 acceptance remain separate.

CI run 41042343059 (macos-15, Xcode 26.3, iPhoneOS26.2 SDK) passed configure
then failed device-arm64 C++ compilation with 20 errors. The force-included
lexical map redefined internal macro/template names, including hb_min_size
(hb-null.hh:99) and hb_enable_if (hb-meta.hh:65). Prefixing arbitrary internal
identifiers and namespaces was the root cause; cache typing was already fixed.

Implemented the revised owner decision in tool/ci/build_harfbuzz_ios.sh and
recorded it under "Revised prefixing (2026-10-30)" in the packaging research.
Only HB_EXTERN public C ABI declarators in the pinned CMake-installed hb*.h
set are mapped, minus all source-defined macro names. Generator rejects
unsupported declarations, absent required APIs and namespace/type collisions;
each slice compares its actual installed header set with the input manifest.
The same map is force-included for C/C++ in every slice. No internal helper,
namespace or template renaming remains. Source/download/COPYING pins,
component definitions and the exact CI fix 1 cache checker are unchanged.

The actual source yields 541 mapped functions and 33/33 required binding
names across 32 installed public C headers (31 source headers plus generated
hb-features.h; the C++ .hh header is excluded). Six public declarators also
occur as source macros and are excluded: four hb_color_get_* accessors,
hb_glyph_info_get_glyph_flags and hb_blob_create_from_file_or_fail (a macro
in upstream test programs). These have real C definitions, so a blanket
HB_EXTERN default-visibility override would leak them. Instead the generator
writes public header copies adding explicit default visibility only to mapped
API declarations. CI copies these into its fresh verified source extraction
before building, retaining annotated copies and original/build header hashes.
HB_EXTERN itself stays plain extern; excluded APIs retain hidden visibility.
The Windows inspection source is never edited or executed.

All slices use -fvisibility=hidden -fvisibility-inlines-hidden for C and C++,
with GCC_SYMBOLS_PRIVATE_EXTERN=YES. HarfBuzz.xcconfig needs no change:
force_load, all 33 linker roots, libc++, export_dynamic and live map remain.
Flutter's HarfBuzz is in its dynamic framework; Mach-O two-level namespaces
separate it from our static hidden internals. No runtime/Apple proof is inferred.

Revised audits, without symbol allowlists:
(a) Parse every nm -m -gU defined external record and cross-check against
nm -gUj. Ignore private-extern definitions for export policy; all remaining
ordinary/weak external definitions must be _shiori_* C names. Visible HB C,
internal/C++ or compiler-helper definitions fail; full raw/demangled inventories
remain retained and undefined system/libc++ references are permitted.
(b) Each of the 33 extracted _required names must be defined and non-private
external in all three thin archives; hidden definitions cannot satisfy it.
(c) Final stripped Release Runner must define and export all 33 exact names,
with unique live link-map ownership in the new device archive. Missing exports,
wrong owners and dead-stripped-only entries fail. Its demangled export table
must have no hb_*/_hb_* or HB namespace exports (OT::, AAT::, CFF::, graph::,
etc.); incomplete C++ demangling fails. Hidden symbols and the separate dynamic
Flutter.framework export table are outside this export ban.

Local validation (evidence under ignored build/hb-fix2/):
- Reverified the provided tarball SHA-256 before tarfile data-filter extraction
to build/hb-src-inspect/. Executed no code from it. Production generator,
extracted unchanged from the shell heredoc: exit 0; 541 mappings, all 33 required,
zero source-defined macro names, zero C++ namespace/type/template names.
Independent pinned-header function inventory agrees; all 541 mapped declarations
receive the explicit default attribute and all six excluded APIs remain plain.
Removing that one attribute from each generated copy reconstructs its original
header text. Source grep confirms both reported macro collisions are unmapped.
- All seven embedded Python blocks compile: exit 0. Production-heredoc
regression matrix: exit 0, 488 subprocess cases; positives exit 0, expected
refusals exit 1. Cases include every required archive definition missing/hidden,
ordinary/weak visible leaks, nm output/inventory drift, installed-header drift,
each missing Runner definition/export/live owner, dead-stripped-only ownership,
HB namespace/template exports, incomplete demangling, exact export-name matching,
duplicate live map entries, and the retained cache type/value/dependency matrix.
- bash -n for build_harfbuzz_ios.sh, build_ios_unsigned.sh and
check_ios_build_modes.sh: exit 0 each. Build-mode selection/refusal suite: exit 0.
- Direct installed dart.exe + flutter_tools.snapshot test --no-pub
--reporter expanded -j 1 test/features/reader/engine/text: exit 0, 17 passed,
no skipped host cases. APPDATA was scoped to build/hb-fix2/appdata in the child
shell and restored in finally; the Windows DLL path is unchanged. Existing
measured D4 failures remain recorded failures, not A5 fidelity acceptance.
- Final source archive byte comparison, extraction cleanup, focused diff review
and git diff --check: exit 0. Only the script and these two research files changed
in this slice. The source-inspection directory created by this session was
removed only after resolving it beneath the ignored build/ directory.

No local Apple/C++ compiler is available. Next CI must compile all three slices
with the selective declaration attributes and hidden defaults, pass the exact
typed cache/header/visible-definition audits, create the XCFramework, then pass
Runner export and live ownership checks after Release stripping. Tool-output
drift, visible libc++/compiler helpers or missed generated C++ scopes must return
for review, never gain an allowlist. Actual AOT/process lookup, exact runtime
version, six fixtures, callbacks, device glyph coverage and memory/performance
remain A5 gates. No successful Apple build or broader S4a acceptance is claimed.
