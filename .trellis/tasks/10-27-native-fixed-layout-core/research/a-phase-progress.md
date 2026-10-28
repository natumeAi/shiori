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
