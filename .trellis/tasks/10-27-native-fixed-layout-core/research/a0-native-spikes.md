# A0 native primitive experiments

Date: 2026-10-27. Scope: a bounded development harness on Windows, using real
Flutter `dart:ui` rendering. This is not the product scene renderer, an iPhone
run, a performance result, or closure of A-AC2/A-AC3/A-AC7. Canonical v1 and
production reader code are untouched.

## Reproduction and provenance

Run from the repository root:

```powershell
flutter test test/tool/reader/fixed_layout_spike_test.dart --no-pub --reporter expanded
```

On this host the SDK batch wrappers stalled before Dart started. They were
terminated. The equivalent installed-tool invocation worked:

```powershell
& 'D:/DevTools/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/DevTools/flutter/bin/cache/flutter_tools.snapshot' test test/tool/reader/fixed_layout_spike_test.dart --no-pub --reporter expanded
```

The Flutter invocation needed SDK lockfile access outside the workspace. The
same direct Dart executable runs `format` and `analyze` without that access.
SDK cache metadata identifies Flutter 3.47.7, Dart 3.13.5, framework
`abaf9c523780a608bd46686fd5e53740a07077f8`, engine
`deb287481e3ce9468f3434937ced4240a70539ca`.

The harness reads the owned-by-oracle-generator corpus, oracle and font
manifest. It verifies exact corpus bytes against the oracle hash and verifies
each font's bytes/hash before loading. No browser geometry is a renderer input.
`build/fixed-layout-native/report.json` contains the exact corpus, oracle,
harness, source and PNG digests; SDK compile-time metadata; raw source-linked
geometry; pixel comparisons; and resource counts. Re-run if those inputs change.
The report and all generated native/stage/reference PNGs are ignored build
artifacts. The original oracle is authoritative WebKit 27.2; its provenance and
Chromium differences remain in the generator-owned fixture files.

## What executes

There are eighteen actual raster experiments plus four explicitly unexecuted
outside-profile constructs:

* Positive/boundary/nested for filters, masks, SVG text and foreignObject: twelve.
* Three SVG text alternatives matching observed WebKit parent-textLength
  behavior, labeled `-webkit-parent-length`.
* Three additional native child-textPath probes: `none`, `spacing`, and
  `spacingAndGlyphs`, using `oracle.svgTextProbes[].source`.

The test checks execution, image bounds, exact ordered filter stages, expected
source-fragment counts, every original UTF-16 offset, every CFI round trip,
canonical exclusion, and required SFNT shaping. Its green exit does **not**
mean that the independently serialized fidelity gate passed. Outside-profile
rows do not have successful partial output.

## Native mechanisms and observations

### Ordered filters and finite regions

The native graph uses `PictureRecorder`/`Picture.toImage`, `ImageFilter.blur`
with decal edges, translated `drawImage`, `ColorFilter.matrix`, flood paint,
`srcIn`, `screen`, and ordered merge. Named result images are consumed in source
order, and each intermediate has a recorded pixel digest and PNG. The filter
region is clipped explicitly to the fixture's authored 320 by 240 user-space
region. Other regions/units or primitives throw instead of silently rendering.
Linear RGB variants use native sRGB-to-linear and linear-to-sRGB gamma filters.

All four sampled pixels match WebKit exactly in all three variants. In the
positive sRGB graph the full PNG differs at one pixel: WebKit has black alpha38
at (0,0), while native is transparent. At (132,100), both produce
`[0,200,100,143]`, which exercises blur, offset and the colored blend output
beyond the original red rectangle. No filter stage is replaced with the
unfiltered source. The full source rectangle CFI survives raster intermediates.

This demonstrates the proposed native graph for these exact finite fixtures.
It does not establish arbitrary filter primitive regions, all composite/blend
modes, wide-gamut or floating-point intermediates, general objectBoundingBox
mapping, or iPhone throughput. A2 must add those admitted contracts explicitly.

### Alpha and luminance masks

The native path uses a circular path clip, an isolated source layer, `dstIn`,
a luminance-to-alpha color matrix when requested, and outer group opacity.
The source rectangle retains its CFI, clip definition, analytic mask coverage,
and opacity separately from the picture.

All sampled pixels match exactly: the gray luminance mask and .5 group opacity
produce alpha64; the alpha mask with the same gray shape produces alpha128.
The positive PNG has six raw straight-RGBA changes: the WebKit (0,0) artifact
and five native alpha1 circle-edge pixels where WebKit is transparent. Those
pixels are retained, not silently treated as an accepted AA waiver. The mask
experiment's render target count excludes native temporary saveLayer storage.

### Contextual text, path placement and source geometry

The renderer shapes a whole native paragraph and retains its original UTF-16
mapping. It paints contextual paragraph slices using native canvas transforms
and a Skia `PathMetric` for the quadratic path. It does not use arbitrary
character reshaping to replace the paint paragraph. Extra single-grapheme
paragraphs measure *nominal metrics only*, under a separately named diagnostic
field. They never substitute for actual painted source geometry.

The first implementation incorrectly interpreted the combining-mark empty
one-codeunit selection as an empty base character; this is fixed. The first
unit now owns the actual shared grapheme slice, and the subsequent combining
unit has its source point at the end. Source offsets and CFIs remain exact.
SVG x/y/dx/dy/rotation/anchor source values drive painting. Upper-run baseline
start positions match the reference exactly; native ascent19.00390625 differs
from WebKit font ascent19 by .00390625 authored pixels.

WebKit ignores the fixture's `textLength=180` on the parent text around a
textPath: measured computed length is72.763671875. Applying that parent value
in the first native proposal produces a105.873133px maximum difference. The
explicit compatibility experiment records that difference rather than claiming
the requested adjustment was tested by an ignored browser attribute.

For that compatibility experiment:

* Actual painted-slice versus SVG DOM character metric maximum:1.384887px.
* Independent nominal-metric diagnostic maximum:.294022px.
* Whole upper-text alpha-support bounds match exactly: `[140,26,183,43]`.
* Whole path-text alpha-support bounds match exactly: `[30,51,99,92]`.
* Alpha128 bounds differ by one right-edge pixel in each crop.577 raw pixels
  differ by more than two straight-RGBA channels; zero are flat-interior
  mismatches;25 reference-visible pixels are absent and21 native-visible
  pixels are extra. No global pixel percentage is used as an acceptance rule.

The remaining metric difference is concentrated in `fi`: paragraph selection
subdivides a contextual ligature advance, whereas WebKit SVG character APIs
report nominal per-character extents. These APIs do not define the same
geometric object. `GlyphInfo` exposes Unicode grapheme layout bounds and ranges,
not glyph IDs, ink outlines, or shaping-run ligature clusters. Consequently the
current slice boxes cannot be presented as an exact general glyph/ink proof.
Nominal agreement and matching whole-text bounds do not close that gap.

The child-textPath probes make adjustment visible. Maximum actual-slice /
independent nominal diagnostic differences are:

| Adjustment | Actual slice metric delta | Nominal diagnostic delta |
| --- | ---: | ---: |
| none |1.366096px |.294022px |
| spacing |1.492119px |.410503px |
| spacingAndGlyphs |3.572766px |.861506px |

Spacing changes source positions even though WebKit's computedTextLength remains
72.763671875. SpacingAndGlyphs reports179.999969px. The native probe implements
both extra spacing and glyph scaling; it retains all source offsets. Skia path
measurement versus WebKit's path traversal and the ligature representation
still need refinement. These child probes currently supply geometry, not PNG
reference comparisons.

### Static XHTML foreignObject

The native experiment clips the authored foreignObject viewport, applies its
SVG parent translation, draws the CSS border/padding, and paints one contextual
paragraph with the relative span's vertical translation. Every XHTML text
offset retains its projected node/namespace ancestry and CFI. Canonical v1
remains zero under the SVG ancestor.

Unmodified native fractional range rectangles differ from unmodified WebKit
DOM Range rectangles by up to1.048828125px horizontally. Example: native space
advance4.951171875px versus a6px enclosing DOM range. Full-node canvas/native
advances have0.0px difference, and native baseline70.000814 is close to the
fixture font baseline70. Raw box differences remain in the primary comparison;
they are not removed by rounding expected values or widening the .5px gate.

The positive PNG has305 raw changed pixels, zero flat-interior mismatches,
57 reference-visible missing and74 extra native-visible pixels. The reference
paints the relative Z above its sibling despite its DOM rectangle recording
top+3; the native proposal paints the CSS-relative text below. This is a real
reference raster/geometry discrepancy, not evidence that the native source
geometry should be shifted by an arbitrary amount.

### Packaged fonts

SFNT uses the pinned171676-byte Roboto file. Native shaping width for
`Ab fi é Z` is72.763671875px, exactly WebKit's canvas width and distinct from
the absent-family control180px. This proves actual native use rather than just
a registration callback completing.

The generator also supplies valid same-table WOFF and WOFF2 wrappers. Both
browsers load them successfully. On this Windows Flutter test engine both
`loadFontFromList` futures complete, but shaping width remains180px, equal to
the absent-family control. These direct native formats are **not admitted**.
Only required SFNT fidelity is proven here. WOFF/WOFF2 require an explicit
bounded conversion/validation path or platform-specific proof before admission;
this optional format probe does not automatically fail the required SFNT row.

Attempted registration input bytes total418144; usable SFNT bytes171676;
unusable/engine-retention-uncertain attempted bytes246468. Callback completion
must not be labeled a usable font registration or successful format support.

## Independent reference controls

The oracle owner's `paint-controls.json` retains original PNGs and twenty
fresh-context controls. Empty SVG in `application/xhtml+xml` is sufficient for
the WebKit black alpha38 top-left pixel. Empty HTML SVG, XHTML without SVG, and
Chromium controls remain transparent. Two-rAF screenshot repeats are identical.
The foreign relative-span raster anomaly also reproduces in isolated HTML and
XHTML. The native report retains every raw difference and does not mask either
counterexample.

## Ownership and provisional resource observations

One RGBA8 authored image is307200 bytes. The sRGB graph retains nine owned images
including the final surface:2764800 lower-bound bytes. The linear graph retains
eleven:3379200 bytes. The harness refuses a graph once32 images are owned, before
its next allocation, and rejects non-pinned regions before allocating anything.
The positive luminance mask nests up to four saveLayers; nested fixture wrappers
add another group. Font metric paragraphs and paint paragraphs are counted in
each case. All pictures/images/paragraphs have explicit disposal owners.

These counts exclude native filter/saveLayer scratch, image upload duplication,
font engine retention, paragraph native storage, and process RSS. They support
the provisional resource agent's cap rationale, not a total memory bound. Device
peak/RSS, frame time and lifetime churn remain A3/A5 work.

## Gate recommendation and next work

The concrete graph, mask and SFNT mechanisms are feasible for the tested inputs.
The overall report's fidelityGate deliberately stays false: edge/reference
artifacts have not been approved as exclusions, non-positive PNG evidence is
absent, and text geometry/paint correspondence is not fully proven. A green
experiment test must never be substituted for this verdict.

Before broad A2 text implementation, define and test a same-object geometry
contract: actual native painted clusters/coverage plus original UTF-16 ranges,
author baselines/transforms/clips, compared with corresponding browser painted
objects. Keep per-character DOM metrics as independent diagnostics. A bounded
native alpha-mask experiment per retained shaping group could measure true
paint/overhang coverage, but it must preserve per-character author transforms
and cannot coalesce an arbitrarily rotated ligature by assumption. If a public
native shaping API cannot supply required runs, evaluate a source-backed native
shaping seam; do not replace glyph proof with independent nominal paragraphs.

For foreignObject, retain the horizontal range-definition discrepancy and
reference raster counterexample while testing additional positioned inline
cases. For filters, extend explicit primitive/region admission and measure
transient native scratch before product integration. Main owns review of any
measurement-contract decision. No complex-static requirement, geometry
tolerance, or120Hz performance target is reduced by these experiments.

## Final focused validation

All five owned Dart files passed `dart format --set-exit-if-changed` with zero
changes and focused `dart analyze` with no issues. The final focused Flutter
test passed: one test executes all eighteen raster experiments, three native
font usability probes, source-count/UTF-16 coverage assertions and CFI/canonical
checks. The final `git diff --check` for owned paths returned zero.

Final native report fingerprints:

* Corpus: `e2feb591f8f9c7a9e6062a3e16dda2aaa0b154325f4434e674f2cd50b452844a`.
* Oracle: `5cd38ddb11970e200c58f1ec1825d6d8cc2d06ea99b54327dfcdc79c58352954`.
* Harness: `42ddd6706e7a3e6e9c96f805425297a9222387f27c24ebf74e9205c0349ec4fe`.

Runtime Flutter metadata identifies3.47.7/framework`abaf9c5237`/engine`deb287481e`;
the full revisions above come from the installed SDK cache metadata. There are
nine paragraphs in each original SVG experiment (two paint runs plus nominal
diagnostic measurements), eight in each child textPath experiment, and one in
each foreignObject experiment. These paragraph counts are now explicit in the
report and supersede the initial two-paragraph estimate shared before nominal
diagnostics were added.

The shared full codegen/format/analyze/test gate belongs to the main/diagnostics
owner and runs after this focused CLI window. No A1/A2 work starts here. User
steering explicitly requests stopping after A0; this handoff completes the
owned experiments while preserving every failed/unavailable acceptance result.
