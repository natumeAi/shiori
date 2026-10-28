# A0 closure report

## Part 1: corpus and oracle

Scope: oracle-side closure items 1-3 and oracle inputs for item 4. The native
harness and its tests, production code, specifications, other task documents,
and the reference checkout were not edited. The 13 rows, 52 cases,
`expectedCapability` values and 0.5 CSS px tolerance are preserved.

### Corpus corrections and browser evidence

- `dimensions-unsupported` now authors the outer SVG with `width="50%"` and
  `height="75%"`, retaining its `viewBox="0 0 320 240"`. These valid relative
  dimensions depend on a containing viewport and are outside the admitted
  absolute authored-page size profile. This changes the dimension source
  itself rather than relying on OPF spread metadata. WebKit resolves the
  layout box to `[0,0,160,180]`, computed size to `160px` / `180px`, and
  screen CTM to `[0.5,0,0,0.5,0,30]`, against a 320 x 240 containing box.
  `dimensions` records raw attributes, viewport, computed/client boxes,
  viewBox and CTM. `lengthAPI` separately labels `SVGLength.value` diagnostics
  (WebKit returns `[80,135]`); those API values are not the CSS layout size.
- `cascade-unsupported` now contains the unconditional top-level rule
  `#source[data-source="text"]{future-layout:active}`. Its selector matches
  `#source`, with one matching top-level CSSOM rule. `appliedDeclaration`
  records `elementMatches:true`, `matchingTopLevelRules:1`,
  `cssSupported:false`, empty retained declaration value and empty computed
  value. The browser drops the unknown property in a matching rule; there is
  no false `@supports` condition shielding it from application.

### Paint references

Both engines capture PNGs and the existing two-requestAnimationFrame byte
stability result for positive, boundary and nested variants of filters,
clip-mask, svg-text and foreign-object: 12 case references per engine.
All three SVG text probes also have independent PNGs/stability results.
All 15 references per engine are stable. No PNG or paint-stability field was
added to other corpus rows or unsupported variants. The pre-existing empty
document screenshot control remains.

### Text contract inputs

`corpus.cases[].textRuns` identifies each SVG run and foreignObject text node
by its body text-node index, plus SVG text index where applicable. The oracle
copies each declaration to `texts[].fixtureRun` and `svgTexts[].fixtureRun`.
The three probe sources and declarations now live in `corpus.svgTextProbes`,
which the oracle consumes directly.

Every declaration has `clusterSource:"fixture-declared"` and
`clusterConfirmation:"A0b must confirm shaped membership"`. `clusterMap`
contains half-open UTF-16 `[start,end)` pairs covering the text exactly once.
`Ab fi` uses `[0,1),[1,2),[2,3),[3,5)`; `Ab fi e\u0301 Z` additionally uses
`[5,6),[6,8),[8,9),[9,10)`. ` Z` has two single-unit clusters.

WebKit `ligatureControl` records normal and ligature-disabled computed text
lengths. The upper LTR SVG run remains ligated despite its dx/dy/rotate lists:
those lists affect A/b, and lengths are 40.29296875 versus 41.015625 with
ligatures disabled for positive, boundary and nested. Keep `fi` as `[3,5)`.
The unsupported vertical upper run measures 120 in both controls and declares
separate `[3,4)` / `[4,5)` clusters. Path runs retain `fi` / combining clusters;
normal versus disabled path lengths are 72.763671875 / 73.486328125.
These browser controls inform the provisional maps; they do not substitute
for A0b's shaped membership proof.

Each rendered foreignObject text node now has `baseline` with method
`zero-size-inline-block-baseline/getBoundingClientRect`, x/y and
`coordinateSpace:"viewport-css-px"`. A temporary empty inline-block with zero
width/height/margin/border/padding and `vertical-align:baseline` places its
bottom edge on the text baseline. The marker is removed in `finally` before
capture. This follows CSS2 section 10.8.1's empty inline-block baseline and
CSSOM View's Element bounding rectangle method:

- https://www.w3.org/TR/CSS22/visudet.html#leading
- https://www.w3.org/TR/cssom-view/#dom-element-getboundingclientrect

No Range box contributes to baseline measurement. A temporary 0.375 px marker
translation is measured and checked as 0.375 px, documenting fractional
precision. Positive/boundary/unsupported visible node baselines are 70 and
73; nested baselines are 79 and 82. The second node's x is 76.28125 (nested
83.28125). Existing canvas `advance.prefixWidths` and snapped Range diagnostics
are retained.

The unsupported foreignObject also contains the pre-existing non-rendered
script text. It has a declared per-unit cluster map and `rendered:false`;
its baseline explicitly records `available:false`, null x/y and
`reason:"no-generated-layout-box"`. There is no painted baseline to invent.
All eight visible foreignObject text nodes have available baselines.

### Provenance and hashes

Node v24.19.0; Playwright 1.64.1; WebKit 27.2 authoritative;
Chromium 156.0.8078.4 cross-check. Viewport 320 x 240, DPR 1; packaged fonts
unchanged. The generator verifies the clean pinned reference revision
`a4bda23fd3e82e285a22566d88576e67d3e8756b`; Foliate remains
`78914aef4466eb960965702401634c2cb348e9b1`.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| corpus.json | 154958 | aa61e4776195e20d49392c4af5e710db5ffdf5276d8b3d1440a7a5608d5f2dd7 |
| oracle.json (WebKit) | 450696 | 4eb18eb6aa389f648f0ee36b2b6ad740c1c985bd742a8f9154e6e3d7d8349917 |
| cross-engine-differences.json | 8654 | e36601ec450ab35ed93d03938113b8784749574d81468cfd782385c6c0303067 |
| ignored Chromium oracle.json | 481843 | 5ca95dfff35ce5b5e074276b636b69e90ad37bfd1b9e646976206a78f26a3eb4 |

The final generator ran twice consecutively. Saved first-run bytes in ignored
`build/fixed-layout-closure/first-*.json` were compared using `Buffer.equals`
against the second run: corpus, WebKit oracle, Chromium oracle and differences
are byte-identical. The summary records 42 cross-engine case differences;
full Chromium vectors remain under ignored `build/fixed-layout-chromium/`.
Sorted JSON has no capture timestamps, absolute machine paths or random URLs.

### Commands and results

Node commands ran from `tool/oracle/`; Dart commands ran from repository root.
In the table, `$dart` denotes the SDK's direct `dart.exe` and `$flutterTools`
the installed `flutter_tools.snapshot`; no SDK .bat wrappers were used.

| Command | Exit | Result |
| --- | ---: | --- |
| `node src/fixed-layout-corpus.mjs` | 0 | 13 rows / 52 cases; corpus hash above |
| `node src/fixed-layout-corpus.mjs --check` | 0 | No generator drift |
| `node src/fixed-layout-oracle.mjs` (final run 1) | 0 | 52 cases per engine; sfnt/woff/woff2 loaded |
| `node src/fixed-layout-oracle.mjs` (final run 2) | 0 | Same counts; byte-identical artifacts |
| Node `Buffer.equals` and SHA-256 verification | 0 | All four artifacts identical; 12+3 stable PNGs per engine |
| `& $dart format --set-exit-if-changed test/features/reader/data/epub/fixed_layout_corpus_test.dart` | 0 | Final run: 1 file / 0 changed |
| `& $dart analyze test/features/reader/data/epub/fixed_layout_corpus_test.dart` | 0 | No issues |
| `& $dart $flutterTools test test/features/reader/data/epub/fixed_layout_corpus_test.dart --no-pub` | 0 | 57 passed |
| `& $dart run tool/ci/check_reader_fixtures.dart` | 0 | Fixture manifests and EPUB privacy guard passed |
| `& $dart $flutterTools test test/tool/reader/fixed_layout_spike_test.dart --no-pub` | 0 | Executed once; 1 passed; 18 measured / 4 outside-spike-profile |

An earlier oracle run also exited 0 before the SVGLength diagnostic field was
renamed to distinguish it from CSS layout size. It is superseded by the two
identical final runs. The first corpus test run exited 1 because a new
`contains([3,5])` assertion compared inner Lists by identity. It was corrected
to `contains(equals([3,5]))`; generated data was not edited. Formatting passes
that applied formatting exited 1 as requested by `--set-exit-if-changed`;
the final no-change format check and analysis exited 0.

`fixed-layout-paint-controls.mjs` was not rerun: its independent inline control
sources, data-URL font input, browser versions and script are unchanged.
Neither `paint-controls.json` nor font fixtures changed. No full suite ran.

### Remaining handoff

Part 1 supplies the corpus/oracle evidence. Part 2 still owns native cluster
and unsnapped baseline/advance comparisons, D4 edge gating, D3 narrow defect
exceptions and their reference-fix handoff. The once-run native spike still
reports `fidelityGate:false`; test execution success is not A0 acceptance.
A0b must confirm actual shaping clusters and resolve the curved
spacingAndGlyphs miss. No later phase was started and no commit was made.

## Part 2: native harness

Date: 2026-10-28. Implements A0 closure items 4-6 in the native harness,
its affected test, and the new reference-defect registry. Production code,
oracle/corpus generators, generated inputs, paint controls, other task/spec
documents and the reference checkout were not changed. No sub-agents,
full-suite run, commit or later phase activation.

### Contract and evidence

`build/fixed-layout-native/report.json` is schema 2: 18 measured cases,
four outside-profile cases, and one independently rendered `foreignStatic`
control. Fifteen cases are required targets. The three naive parent-textLength
cases remain measured `required:false`, `role:"counterexample"`; all three
WebKit-compatible alternatives and all three curved probes are required.
The 0.5 authored CSS px threshold is unchanged.

SVG geometry gates 2D cluster start/end distances and rotation-induced
displacement (absolute angle delta in radians times reference cluster advance).
Both painted boundary slices carry rotation measurements. Each cluster remains
fixture-declared and provisional. The original per-character start/end/extent,
nominal and snapped Range measurements are retained in `componentDiagnostics`.
foreignObject gates unsnapped baseline y and contextual Paragraph x positions
at every declared cluster boundary against baseline.x + canvas prefixWidths.
Nested SVG API coordinates stay in SVG user space; foreignObject viewport
coordinates add (7,9). No nominal geometry replaces painted geometry.

All probes now pass their own PNG/stability evidence to the comparator. Their
source has no body margin reset: the oracle's `setContent` retains its XHTML
host and default 8 px body margin. Native applies this capture-host (8,8)
translation for raster comparison, records it as `captureBodyMargin`, and keeps
SVG API geometry in user space. No reference raster is translated or edited.

D4 reports interior mismatches, partial-alpha 8-neighbourhood coverage,
alpha>0 support bounds, 8-connected component count/bounding-box pairing, and
exact sample checks separately. Component pairing uses a complete bipartite
match within 1 px per side, rather than greedy ordering. Raw changed pixels
(straight RGBA maximum delta >2), tile counts, examples, missing/extra pixels
and maximum deltas remain. Missing reference PNG means `unverified`, pass false.
There are no missing references in this run. Samples have zero delta throughout.

`reference-defects.json` mirrors RD-1/RD-2 with engine/version, enumerated case
scope, control IDs and upstream handoffs. The report pins its hash and the
unchanged controls hash. RD-1 requires the case's actual PNG (0,0), its recorded
topLeft and the matching WebKit XHTML emptySVG PNG to equal [0,0,0,38], with
transparent native output. Nested case PNGs have transparent (0,0), so receive
no RD-1 exemption. The probes retain the XHTML capture-host qualification.

RD-2 derives Z support from red ink introduced by the independent
foreignStatic/foreignRelative controls, confirms agreement between HTML and
XHTML relative controls and each case PNG, and verifies native support at the
CSS position. Unexpanded native/reference LTRB boxes are [82,59,93,73] and
[72,44,83,58]. The only expanded scopes are [81,58,94,74] and [71,43,84,59];
nested adds (7,9). Their union is 413 pixels, with 157 changed pixels exempted
per case. RD-1 adds at most one separately listed pixel. All exempt coordinates,
RGBA values and per-defect counts are reported. Support/component checks mask
only those recorded scopes on both rasters. Pixels outside remain subject to
D4. The WebKit text/html foreignStatic control passes every D4 rule with no
exemptions; its 201 raw edge differences remain reported. Upstream bug filing
and device-Safari reproduction remain owner handoffs, not claimed completed.

### Per-case results

Geometry is the gated maximum in CSS px; `-` means no text-channel comparison
for that scene/control (not an invented zero). D4 columns are interior / edge
neighbourhood / support bounds / components / samples. P = pass, F = fail.
Exempt counts are RD-1 / RD-2. Raw and remaining are changed-pixel counts before
and after D3. The case gate still includes source conservation and geometry.

| Case | Geometry max | D4 I/E/B/C/S | Exempt RD-1/RD-2 | Raw/remaining | Gate |
| --- | ---: | --- | ---: | ---: | --- |
| clip-mask-positive | - | P/P/P/P/P | 1/0 | 6/5 | pass |
| clip-mask-boundary | - | P/P/P/P/P | 1/0 | 4/3 | pass |
| clip-mask-nested | - | P/P/P/P/P | 0/0 | 19/19 | pass |
| svg-text-positive (counterexample) | 105.975437 | F/F/F/F/P | 1/0 | 1469/1468 | fail |
| svg-text-positive-webkit-parent-length | 0.768233 | P/P/P/F/P | 1/0 | 577/576 | fail |
| svg-text-boundary (counterexample) | 105.975437 | F/F/F/F/P | 1/0 | 1469/1468 | fail |
| svg-text-boundary-webkit-parent-length | 0.768233 | P/P/P/F/P | 1/0 | 577/576 | fail |
| svg-text-nested (counterexample) | 105.975437 | F/P/F/F/P | 0/0 | 1467/1467 | fail |
| svg-text-nested-webkit-parent-length | 0.768233 | P/P/P/P/P | 0/0 | 574/574 | fail |
| foreign-object-positive | 0.011719 | P/P/P/P/P | 1/157 | 305/147 | pass |
| foreign-object-boundary | 0.011719 | P/P/P/P/P | 1/157 | 305/147 | pass |
| foreign-object-nested | 0.011719 | P/P/P/P/P | 0/157 | 304/147 | pass |
| filters-positive | - | P/P/P/P/P | 1/0 | 1/0 | pass |
| filters-boundary | - | P/P/P/P/P | 1/0 | 1/0 | pass |
| filters-nested | - | P/P/P/P/P | 0/0 | 0/0 | pass |
| svg-text-path-none | 0.768233 | P/P/P/P/P | 1/0 | 358/357 | fail |
| svg-text-path-spacing | 0.736995 | P/P/P/F/P | 1/0 | 395/394 | fail |
| svg-text-path-spacingAndGlyphs | 1.745388 | P/P/P/F/P | 1/0 | 648/647 | fail |
| foreignStatic (control) | - | P/P/P/P/P | 0/0 | 201/201 | pass |

### Row verdicts and provenance

| Native row | Verdict | Reason |
| --- | --- | --- |
| filters | pass | All three required variants pass D4 and source checks. |
| clip-mask | pass | All three variants pass D4, including retained edge differences. |
| svg-text | fail (geometry provisional) | Required geometry misses remain and four required variants fail component matching. |
| foreign-object | pass | All three variants pass baseline/boundary geometry and D4 under exact D3 scopes; unexempted static control passes. |

`open-a0b` is available only for SVG rows whose remaining acceptance depends
solely on fixture-declared cluster geometry. Observed raster component failures
make this SVG row `fail`, not `open-a0b` or `pass`. Top-level fidelityGate is
**false**; successful test execution is not fidelity acceptance.

Harness SHA-256 (concatenation in report order: fixed_layout_spike.dart,
filters, fonts, scene, defects, geometry, pixels; each companion has prefix
fixed_layout_spike_ and suffix .dart):
`593296e1febc2b292efaf6f9f0f364c1895844acce33cfe17787be58062b7fde`.
Registry SHA-256:
`4e84b5abb96979b5d04c520a2fa28d2e25eaf1381d769199b393f821d3cdbb31`.
Paint-controls SHA-256:
`f1539007368afb52d6fb2fe5dcb1c316f722d39fadd7a5cd850ef49f0f3c7a55`.
The exact corpus/oracle hashes still match Part 1 and the user-provided values.

### Commands and results

All SDK commands use direct executables, never .bat wrappers. `$dart` means
`D:/DevTools/flutter/bin/cache/dart-sdk/bin/dart.exe`; `$flutterTools` means
`D:/DevTools/flutter/bin/cache/flutter_tools.snapshot`. `$changedDart` is
tool/reader/fixed_layout_spike.dart, fixed_layout_spike_scene.dart,
fixed_layout_spike_defects.dart, fixed_layout_spike_geometry.dart,
fixed_layout_spike_pixels.dart and test/tool/reader/fixed_layout_spike_test.dart.

| Command | Final exit | Result |
| --- | ---: | --- |
| `& $dart format --set-exit-if-changed $changedDart` | 0 | Six files, zero changed. Earlier formatting passes exited 1 when applying formatting. |
| `& $dart analyze $changedDart` | 0 | No issues. Earlier passes found brace-style info diagnostics, now fixed. |
| `& $dart $flutterTools test test/tool/reader/fixed_layout_spike_test.dart --no-pub --reporter expanded` | 0 | Four tests passed; report regenerated. Includes D3 eligibility/scope checks, D4 negative vectors, 2D/rotation vectors and real native renders. |
| `& $dart run tool/ci/check_reader_fixtures.dart` | 0 | Reader fixture manifests and EPUB privacy guard passed. |
| PowerShell Get-FileHash / Python hashlib input verification | 0 | Corpus/oracle exact hashes verified before edits and after checks. |

The first new D4 negative-vector run exited 1: changing only the centre pixel
does not make its 3x3 neighbourhood flat. The vector now recolours the full 5x5
patch, correctly exercising flat interior rejection. No oracle or expected
render data was changed. The original spike test also passed before expansion.

### A0b handoff and limits

Confirm shaped cluster membership through the approved time-boxed HarfBuzz
probe, then resolve painted cluster endpoints, rotations, overhang slicing and
component conservation. Required geometry maxima remain 0.768233 px for the
WebKit-compatible/none cases, 0.736995 for spacing and 1.745388 for
spacingAndGlyphs. For combining cluster [6,8), spacingAndGlyphs still measures
0.339569 px start, **0.541114 px end** and **0.877365 px rotation displacement**:
it fails; this is not reclassified. Positive/boundary SVG targets have 8 native
versus 7 reference components; spacing has 12 versus 8; spacingAndGlyphs has
7 versus 8. Nested/none D4 passes do not cancel geometry failures.

No tolerance, required row, D4 rule or D3 scope was widened. The capture-host
margin handling is an explicit coordinate correction discovered while applying
the newly supplied PNGs. No additional scope deviation or phase start.

## Closure verdict (main session, 2026-10-28)

The main session re-read `build/fixed-layout-native/report.json` and the
fixtures independently before accepting this closure.

Row status against the A0 closure rule (an executable oracle case, a failure
criterion and a verdict for every row):

| Rows | Status |
| --- | --- |
| filters, clip-mask, foreign-object | Native verdict **pass** under the channel contract, D4 and recorded D3 scopes. |
| svg-text | Native verdict **fail (provisional cluster map)**, owned by A0b. |
| metadata, dimensions, cascade, box, text, paint, stacking, svg-graphics, mixed-navigation | Oracle case and failure criterion exist for all four variants; there is no native experiment yet. Native verdict is pending A1/A2 by design, not a pass. |

Independent findings:

- The svg-text geometry failures are all at the end of the `fi` cluster
  (0.68-0.77 px; 1.75 px under `spacingAndGlyphs`), plus the combining cluster
  under `spacingAndGlyphs` (0.54 px end, 0.88 px rotation displacement). The
  harness paints per-grapheme Paragraph slices, each rigidly rotated at its own
  path position. WebKit places the ligature as one rigid glyph. This is the
  slicing limit recorded in `a0-text-geometry-options.md`, so A0b owns it.
- The only component mismatch in the upper run is an isolated native pixel at
  (154,40) with alpha 6, at the `A`/`b` slice boundary. This is a slicing
  artifact, not a D4 false positive. The paired path-text components match
  within 1 px.
- RD-2 exempts 157 of 413 in-scope pixels (the two expanded `Z` glyph boxes).
  The 147 changed pixels outside the scope pass D4. `foreignStatic` passes D4
  without exemption. RD-1 exempts only (0,0).
- The required flags are corrected: the WebKit-compatible variants are
  required, and the parent-`textLength` variants are retained as
  `role: counterexample`.

A0 is closed. The overall native `fidelityGate` stays false because the
svg-text row fails. Per D2 that row remains required and open for A0b. Under
the owner's 2026-10-28 standing instruction, A1 shared contracts start next.

## A2 oracle extension (2026-10-28)

Added evidence only for cascade/box/paint/stacking: 16 computed-style property
lists and element snapshots, declared XHTML text runs/cluster maps, baseline
records, and 12 positive/boundary/nested PNGs with two-rAF stability. All 12
rasters are stable. Baselines use the documented zero-size inline-block method;
under 2D ancestors the probe's translation is inverse-transformed so the check
still measures exactly 0.375 viewport CSS px. Hidden/non-layout text and
singular/3D transforms record explicit unavailable reasons. ForeignObject's
existing method and records are unchanged. Cluster maps remain provisional.

An additive-only audit stripped precisely these new fields and compared every
case with saved pre-extension records for both browsers and the corpus. Every
existing field is identical; unrelated cases, probes and controls are unchanged.
Two successful generator runs produced byte-identical corpus, WebKit oracle,
Chromium oracle and cross-engine differences. One intervening run failed opening
oracle.json with Windows UNKNOWN (-4094); the retry succeeded.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| corpus.json | 178002 | eb8379f5745d57a42c4bd2b10ed9587fee0260054af3a2747b799f8f6813af44 |
| oracle.json | 608844 | 33708a0fce1c0b7b523069b7e4e901923a53d4237bb51697de5a822cd1b857af |
| ignored Chromium oracle | 654443 | 0a40410646a0a55fef518104b6ab3a4e4980d5e1f50c7d536614b36c8e193fc3 |
| cross-engine-differences.json | 9101 | 1385496f40afc8195a7aa939a5cb691aa7b690f85d726d485a2a512387cbd14b |

`node src/fixed-layout-corpus.mjs --check` and
`dart run tool/ci/check_reader_fixtures.dart` exit 0. The corpus test exits 1
(56 pass, one failure): its pre-extension paintRows assertion expects no PNG
for cascade-positive. That existing test file is outside A2's granted ownership;
its assertion update was requested from the main session. No expected data was
hand-edited and no fidelity verdict is implied by this oracle extension.

## A2 slice 2a fixture correction (2026-10-28)

The corpus remains 13 rows x four variants / 52 cases. Removed U+1F600 from
the shared XHTML text and isolated it in the existing `text-boundary` case.
Its `fallbackCharacters` entry identifies U+1F600, text node 0, UTF-16 [0,2).
That fixture contains only the glyph and has no background/decoration, so
nonzero alpha cannot be satisfied by unrelated content. Native/WebKit paint
68/343 alpha-positive pixels and both retain the source map/CFIs. The host
conservation check passes; geometry and pixels explicitly remain
`device-gated (A5)` with pass=false and fidelityGate=false. The scene report
separates its four-row pass from its overall gate including fallback=false.

Replaced every hand-declared map with WebKit measurements: 67 body text nodes
and three SVG probe nodes. `clusterSource=webkit-measured-ligature-control`;
`clusterEvidence` retains normal/disabled per-UTF-16-boundary advances and
minimal differing substring spans. The control uses straight SVG replicas
with the node's computed typography/writing mode, removing authored position,
transform and textLength; normal typography is compared with
`font-variant-ligatures:none` using getSubStringLength/getComputedTextLength.
Grapheme segmentation preserves combining sequences and surrogate pairs;
measured minimal ligature spans merge the corresponding graphemes. This is
measured membership evidence, not a recovered shaper glyph buffer.

`nested flow` now includes fl [7,9): isolated normal/disabled advances
11.357421875/11.796875 px; full-run advances 103.095703125/103.53515625 px.
Existing SVG fi and combining maps are identical. An exact recursive audit
removes only fixtureRun/clusterSource/clusterConfirmation/clusterEvidence;
all 16 A0 case records and all three SVG probe records are otherwise identical
to the saved pre-slice oracle, including PNGs, character metrics and baselines.
All body text nodes have matching corpus/oracle measurement records.

Singular authored transforms now suppress subtree paint and all source/paint
proof without making the section malformed or incomplete. Layout boxes remain
diagnostic/flow inputs. Descendants inherit suppression; numeric-range failures
still reject. The regression verifies invisible text/background descendants,
no proof and exact remaining sibling pixels. stacking-boundary is complete,
has no source text fragment from the singular element, and passes WebKit D4.

Two final corpus/oracle generations were byte-identical, including Chromium
and cross-engine differences. Paint-control inputs did not change, so those
controls were retained and their prior hash verified instead of regenerated.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| corpus.json | 266141 | 2b4881df40befcb77170223865f4c26c9a468c395e87cc5f7ff824c96d836d37 |
| oracle.json | 669252 | b6d2758414737f56712762501b13ab542a2e1ae11b22243ccdb5bb37514bdf8f |
| ignored Chromium oracle | 715208 | ea6e0e61cfee59249878794e213ce687120cd073f2c2e8029aa9935bfe479e73 |
| cross-engine-differences.json | 9135 | 960cdcc0803f1d6d48c9031d07aae2cb883952f75b41d54a3aa1e72e74875337 |
| paint-controls.json (unchanged) | 36269 | f1539007368afb52d6fb2fe5dcb1c316f722d39fadd7a5cd850ef49f0f3c7a55 |

Native row verdicts (unchanged 0.5 CSS px and D4):

| Row | Verdict | Largest gated CSS px delta | D4 |
| --- | --- | ---: | --- |
| cascade | pass | 0 | positive/boundary/nested pass |
| box | pass | 0.013671875 | positive/boundary/nested pass |
| paint | pass | 0.01171875 | positive/boundary/nested pass |
| stacking | pass | 0.146484375 | positive/boundary/nested pass |
| filters | pass | N/A: no geometry comparisons in A0 spike | all three pass under existing D3 scopes |
| clip-mask | pass | N/A: no geometry comparisons in A0 spike | all three pass under existing D3 scopes |
| foreign-object | pass | 0.01171875 | all three pass under existing D3 scopes |
| svg-text (existing A0 adapter) | fail | 1.7453875483049597 | upper positive/boundary fail, nested pass; path none pass, spacing/spacingAndGlyphs fail |

The A0 spike still uses its original native Paragraph-slice route and labels
SVG evidence provisional; this slice does not adopt A0b or change its A/B
decision. test/tool/reader also executes A0b and retains its svg-text failure.
SVG fidelity, A5 fallback/device evidence and later integration remain open.

Commands use direct dart.exe/flutter_tools.snapshot, no .bat/pub download:
- `node tool/oracle/src/fixed-layout-{corpus,oracle}.mjs`: both final passes exit 0.
- Both generator `--check` commands: exit 0, including full oracle byte checks.
- Python byte-identity/provenance/source audit: exit 0; summary in
  `build/a2-slice2a/validation-summary.json`.
- Scoped format of nine changed Dart files: final exit 0, zero changed;
  scoped analyze: exit 0, no issues. An earlier formatting pass applied one
  final harness layout change and returned 1; the unchanged recheck passes.
- `dart run tool/ci/check_reader_fixtures.dart`: exit 0.
- Requested style/layout/pagination/fixed, test/tool/reader and corpus tests:
  exit 1; 423 passed, two optional skips, one A3 image-cache failure.
- After a short audit interval, reran only `pagination_test.dart --plain-name
  'the image cache stays within its byte bound and keeps leased images'`:
  exit 1, same ImageAdmissionException at image_cache.dart:129.
- Final corpus + reading_unit_composer_test + reading_unit_navigator_test +
  scene harness run: exit 0, 76 passed. A1 composition remains 48/52 exact,
  49 materialized, with its existing typed metadata rejection and centered
  reflow differences; no A1 file was edited.

Request to A3: reconcile the image-cache test's expectation that three leased
64x64 images exceed its two-image budget with the new pre-decode admission
contract (it now fails on intrinsic+output reservation). No A3 file/test was
modified. Logs are under build/a2-slice2a/. One initial cluster-measurement
attempt failed because setContent cannot rewrite an XHTML document; moving
the separate probe page to about:blank fixed it before the final generations.
No source/CFI/canonical v1 or reflow fixture vectors changed; no hand-edited
expected fixtures, dependency/network/download, sub-agent, build_runner,
repository-wide check, commit or other git mutation occurred. Stop this slice.
