# A0 text geometry: public SDK boundary and next probes

Date: 2026-10-27. Read-only implementation research; no production code, oracle,
reference expectation or tolerance changes. No duplicate pixel/test run was made.
The native-spike owner retains its actual raster evidence.

## Finding

The installed public `dart:ui` APIs can preserve an entire shaped paragraph and
its UTF-16/grapheme layout identity. They do not expose enough information to
replay each actual shaped glyph independently along a curved SVG textPath.
`GlyphInfo` is a grapheme layout record, not a glyph-ID/outline/shaping-cluster
record. No supported public glyph extraction/replay API was found in this SDK.

Thus there is a valid public path for ordinary positioned whole runs, a straight
path that is a single affine transform of the run, and public metrics useful
for source hit testing. There is currently no demonstrated general public-only
path for the required curved `fi`/combining/length-adjusted case at <=0.5 authored
CSS px. This is a missing implementation capability, not an optional capability
row or permission to relax the gate.

The foreignObject discrepancy is now identified by the native owner as horizontal
DOM Range enclosure: a space is 4.951171875px in the native range box versus 6px
in WebKit, while full-node shaped advances match. Native baseline70.000814 vs
browser70 and box top50.9969 vs51 are already close. The earlier suspicion of a
vertical cause is superseded by this measurement. `TextLeadingDistribution.even`
is still a useful CSS half-leading probe, but does not explain this horizontal
failure and is not a measured fix.

## Primary sources inspected

Paths below are installed SDK primary sources, read in place:

| Source | Relevant lines / content |
| --- | --- |
| `D:/DevTools/flutter/bin/cache/pkg/sky_engine/lib/ui/text.dart` | 1233-1275 GlyphInfo; 1431-1533 leading; 2738-2825 box styles; 3010-3177 Paragraph API; 3293-3303 native glyph bridge |
| `D:/DevTools/flutter/bin/cache/pkg/sky_engine/lib/ui/painting.dart` | 6869 Canvas interface; 7314-7336 picture/paragraph painting; 7393 vertices; 7526 atlas |
| `D:/DevTools/flutter/packages/flutter/lib/src/painting/text_painter.dart` | 1597-1635 caret logic; 1650-1709 selection and closest-glyph wrappers |
| `D:/DevTools/flutter/engine/src/flutter/lib/ui/text/paragraph.cc` | 117-171 glyphInfoFrom and native glyph APIs |
| `D:/DevTools/flutter/engine/src/flutter/txt/src/skia/paragraph_skia.cc` | 59-96 shaped text-blob painting; 297-308 Paragraph paint/rect delegation; 345-355 glyph delegation |
| `D:/DevTools/flutter/engine/src/flutter/impeller/typographer/backends/skia/text_frame_skia.cc` | 45-105 glyph IDs, positions, font and path access inside engine |

The SDK engine.version manifest reads
`deb287481e3ce9468f3434937ced4240a70539ca`. The source checkout HEAD could not
be independently read because local Git access to the SDK checkout was denied;
do not claim the C++ checkout is verified byte-for-byte identical to the running
engine. The bundled public Dart API is directly inspected. Official Flutter web
search/open verification was attempted but returned no usable content in this
run; online pages are not cited as fetched evidence. The installed API comments
and implementation signatures are the primary evidence for these conclusions.

Task inputs inspected: `tool/reader/fixed_layout_spike_scene.dart`,
`tool/oracle/src/fixed-layout-oracle.mjs` and
`tool/oracle/src/fixed-layout-corpus.mjs`. The oracle records DOM Range boxes and
SVG getStartPositionOfChar/getEndPositionOfChar/getExtentOfChar/rotation, plus
separate actual screenshots. These metrics and screenshots are different
evidence channels and must remain separate.

Current dependencies were checked in pubspec/package_config and installed
package primary sources. `flutter_svg`2.3.0 uses `vector_graphics`1.2.4 and
`vector_graphics_compiler`1.3.2. The compiler serializes text/font/style and
position commands (`lib/vector_graphics_compiler.dart:240-266`), not glyph
outlines. The renderer constructs ParagraphBuilder, styles and text, then calls
Canvas.drawParagraph (`vector_graphics/lib/src/listener.dart:691-741`). The
compiler SVG element dispatch includes text/tspan but no textPath entry; its
README explicitly excludes some text processing attributes. This dependency
chain supplies no hidden whole-run glyph extraction/replay interface. No
HarfBuzz/FreeType/font-outline parser package is present in the resolved package
configuration. These are installed-version findings, not claims about newer
releases or every package in the ecosystem.

## Exactly what the public API provides

```dart
GlyphInfo? Paragraph.getGlyphInfoAt(int codeUnitOffset);
GlyphInfo? Paragraph.getClosestGlyphInfoForOffset(Offset offset);
List<TextBox> Paragraph.getBoxesForRange(int start, int end, {
  BoxHeightStyle boxHeightStyle = BoxHeightStyle.tight,
  BoxWidthStyle boxWidthStyle = BoxWidthStyle.tight,
});
List<LineMetrics> Paragraph.computeLineMetrics();
void Canvas.drawParagraph(Paragraph paragraph, Offset offset);
```

`GlyphInfo` contains only `graphemeClusterLayoutBounds`,
`graphemeClusterCodeUnitRange` and `writingDirection`. Its documentation expressly
says that bounds are not a tight character-outline box: the vertical extent
comes from font metrics and the horizontal extent from the character advance.
The native Dart bridge serializes only those rectangle/range/direction fields.
It does not return font selection, glyph IDs, glyph positions, outline bounds,
GSUB ligature membership, GPOS offsets or a drawable glyph handle.

The two glyph lookup methods return the same kind of record. Closest-glyph
lookup first chooses the nearest line and glyph; it is a hit-testing operation,
not a way to discover more precise ink bounds. TextPainter wraps the same calls
and adds its paragraph paint offset; it provides no hidden glyph replay API.

`getBoxesForRange` returns selection/layout rectangles. `tight` means tight to
the run geometry described by that API, not a promise to bound glyph outlines.
The TextPainter selection wrapper also documents that partially selected
multi-code-unit glyphs may be excluded. A zero-width/empty selection for a
combining unit is not permission to remove its source identity or painted mark.

Unicode graphemes and shaping clusters are different identities. `fi` can be
two graphemes represented by one contextual glyph; a combining sequence can be
one grapheme represented by several positioned glyphs. The exposed grapheme
range is therefore insufficient to decide which independently transformed
piece of the shaped run must be replayed.

The public Canvas text entry point paints an entire Paragraph. There is no
public drawGlyphs/drawTextBlob/Paragraph.getPath/subrange-paint method in the
inspected Canvas/Paragraph interfaces. Atlas/vertices can transform an image
that has already been produced; they cannot recover missing shaped-glyph/source
identity from a paragraph.

## Public-only implementation that remains valid within its limits

1. Build an immutable mapping from concatenated shaping-input UTF-16 intervals
   to original source-node/local UTF-16 intervals. Normalize SVG whitespace and
   positioning according to authored rules while preserving that mapping.
   Source-node boundaries alone must not force separately shaped paragraphs.
2. Shape the actual complete style/positioning chunk with ParagraphBuilder,
   preserving resolved font, features, language, variations and spacing; layout
   once at the intended constraint. Verify the requested face is usable rather
   than trusting the font-load future alone.
3. Paint that same paragraph with `drawParagraph`, applying its authored affine
   transform and baseline origin to the entire run. Query that same paragraph's
   layout boxes/ranges and transform them with the identical transform/clip
   stack. Label these records as layout geometry, not exact ink outlines.
4. For a single straight baseline, rotate/translate the whole paragraph once.
   A uniform horizontal `spacingAndGlyphs` scale can also be applied to that
   painted paragraph and its geometry. This does not implement arbitrary
   per-character dx/dy/rotate or `lengthAdjust=spacing`, which can require
   independent repositioning while retaining contextual shaping.
5. Retain paragraph/source lifetime through paint and geometry use; reserve
   source, shaping and surface resources before allocation. Reject clipped/
   ellipsized/incomplete results rather than assigning missing source content
   a successful geometry record.

For a curved path, each actual glyph/positioned glyph group must follow its
authored rigid transform at the path position. Rotating the entire paragraph
cannot do that. Clipping the original paragraph at grapheme advance cells keeps
the original shaping call, but can split a ligature's actual outline, crop
overhangs/marks and transform two portions differently. Enlarging those clips
can duplicate neighboring ink. Public records do not prove a safe boundary.

Raster-warping the whole run with vertices bends glyph outlines instead of
implementing SVG's positioned glyph behavior; independent substring paragraphs
lose contextual shaping. Parsing alpha connected components does not generally
recover source identity (marks, connected ligatures and overlapping glyphs).
Color/opacity tricks on substring styles have no inspected contract that they
isolate entire contextual glyphs without shaping/paint splitting. None closes
the required gate by itself.

Independent nominal-character paragraphs can remain explicitly named diagnostic
measurements. They cannot supply the accepted geometry while a different shaped
glyph/slice is painted. Likewise a rectangle inferred from selection metrics is
not a measured alpha/outline box merely because the paragraph was actually drawn.
Compare each geometry channel with its corresponding oracle semantics, and
also require paint/source conservation; a low diagnostic error is not a pass.

## Current-scope engineering probes that remain useful

Lack of a public glyph replay method is not a mathematical impossibility result.
The following bounded experiments remain inside the existing Dart/Flutter scope;
none is reported as supported before actual evidence:

| Probe | Minimum concrete input and actual paint | What success can establish |
| --- | --- | --- |
| Whole-run affine control | Pinned font `AV fi e\u0301 Z`; shape once, paint once, apply one rotation/scale to the entire run | Whole-run UTF-16 mapping and geometry transforms without substring reshaping |
| Grapheme vs shape diagnostic | Same run; enumerate every getGlyphInfoAt(i), per-unit boxes, complete `fi` boxes and complete combining-range boxes | Exactly what this engine exposes; it cannot by itself certify actual ligature glyph membership |
| Bounded grouped-slice experiment | Retain the original shaped paragraph; replay a whole known `fi` group once, with source range `[3,5)`, and the full combining group once; measure actual paint under curve transforms and overhangs | Whether this explicit fixture/grouping preserves paint and <=0.5px geometry. It does not provide a general grouping algorithm or justify hardcoded fixture text in production |
| Range-enclosure semantics | Use actual same-paragraph range endpoints for the foreignObject space and ` Z`; record fractional coordinates and full-node advances | Whether the mismatch is browser rectangle enclosure/snap semantics rather than shaping advance. Any enclosure rule needs primary implementation evidence and cross-case validation, not a fixture-tuned ceil(width) |
| CSS line boxes | Explicit24px, normal, and constrained two-line pinned-font foreignObject cases | Correct leading/baseline/wrapping of the actual paragraph; independent of the current horizontal space discrepancy |

For grouped slices, safe complete shaping-cluster membership and absence of
cropped/duplicated overhangs remain explicit requirements. A pass for one known
group is a feasibility observation, not full textPath acceptance. If there is
no justified grouping/paint-boundary rule, keep geometry completeness false.
Do not expand independent grapheme slices into a supported general path merely
because nominal metrics fit the expected values.

No new library/bridge is needed to run these probes. A new general font parser,
shaper or native glyph interface belongs to the reviewed alternatives below;
main/user design review must precede that material implementation expansion.

## Concrete foreignObject line-box probe for the existing owner

The current `_paragraph` sets height on ParagraphStyle and TextStyle, uses a
10000px constraint, and leaves leading distribution at the SDK default.
For the XHTML case, resolve actual computed line-height and content-box width
instead of treating 1.2 and 10000 as a general CSS layout implementation.
The current single-line example may fit, but that does not prove wrapping.

Use the same complete paragraph and actual paint path; vary only the resolved
CSS-to-native line-box policy:

```dart
ParagraphStyle(
  // Existing resolved font/direction/size/height ...
  textHeightBehavior: const TextHeightBehavior(
    leadingDistribution: TextLeadingDistribution.even,
  ),
)
```

If a TextStyle supplies its own leadingDistribution, set it consistently to
even. Keep first/last height application true when the intended CSS line box
includes leading; separately test the explicit no-height/normal case instead
of blindly disabling first-ascent/last-descent behavior. Inspect computed
line-height first. Query LineMetrics/alphabeticBaseline from this actual
paragraph and apply the same baseline-origin transform used for paint.

Minimal cases: the existing 20px pinned-font `Ab fi` plus relatively positioned
` Z`, an explicit 24px line-height variant, a normal line-height variant, and
a two-line constrained-width variant. Check baseline/paint and DOM Range box
top/bottom independently at <=0.5px, including the +3px relative span shift,
border/padding and foreignObject clipping. No hardcoded 1.049px correction and
no expected-data rewrite is justified by this source review. This suggestion
was sent directly to the native-spike owner; no new run is claimed here.
The latest measured 1.048828px issue is horizontal; this line-box probe should
not be presented as resolving it. The owner also reports a WebKit paint-order
observation for the relatively positioned Z that needs its own oracle evidence.

## Missing capability and optional technical paths

The engine internally has font-backed shaped glyph IDs/positions and can obtain
paths from shaped text blobs. The Impeller bridge explicitly consumes glyph IDs
and positions. Those objects are not surfaced through the stock Dart interface.
A future native extraction/replay interface must also preserve the original
UTF-16-to-shaping-cluster map at the shaping stage; capturing a paint blob alone
does not establish that source map.

Possible reviewed next paths, none implemented/approved by this research:

- **Engine bridge:** expose an immutable shaped-run snapshot with selected font,
  glyph IDs, positions/advances, UTF-16 cluster membership and actual outlines
  or drawable glyph handles; replay the same shaped glyphs under path transforms.
  This preserves Flutter's actual shaping, but requires engine/API, iOS packaging,
  lifetime/resource and source-map work beyond stock public Dart calls.
- **Platform shaping/outlines adapter:** shape complete runs in an explicit
  native text stack and export its positioned outlines plus source clusters for
  Flutter Path painting. This changes the shaping authority, so its output must
  be proved against the pinned oracle and device font behavior. It is not a
  claim that platform glyphs reproduce Paragraph shaping. Native APIs/dependencies
  and cross-platform fallback would need their own primary-source/licence audit.
- **Dedicated shaping/font-outline implementation:** retain whole-run GSUB/GPOS,
  glyph IDs, Unicode cluster mapping and outlines in a reviewed Dart or native
  renderer, then use source-linked Path painting. Existing public Paragraph
  calls cannot supply those missing results. No approved reusable implementation
  was identified here; implementing a general OpenType shaper/parser is material
  new work, not a small metric conversion.

These paths preserve the required static text scope as work still to prove.
They do not authorize a WebView, flattening away source geometry, disabling
authored ligatures, changing reference expectations or weakening the tolerance.

Minimum proof for any chosen path: pinned-font `Ab fi e\u0301 Z`, whole-run
ligature and combining shaping, an overhang/mark crossing an advance boundary,
straight and quadratic baselines, startOffset, spacing/spacingAndGlyphs length
adjustment, and an authored positioning boundary. Assert exact original UTF-16
coverage, every painted glyph emitted once, preserved cluster glyph membership,
actual paint/geometry consistency, independent nominal-metric diagnostics,
and unchanged <=0.5px oracle geometry criteria. Reserve/teardown glyph, font,
outline and temporary image resources under the process/scene lifetime policy.

## Evidence attribution

Native-spike owner reported actual whole-paragraph-slice geometry still has
about 1.384887px maximum `fi` deviation, while separate nominal diagnostic
geometry is about 0.294022px; combining handling was repaired. The latter must
not be substituted for the former gate. It also reported font-load futures can
complete for valid WOFF/WOFF2 while rendering follows the absent-family control.
These are peer observations, not measurements repeated by this research.
The process-font policy already keeps attempted registration bytes charged and
does not assert that byte admission or Future completion proves format fidelity.

No code/test/codegen/commit or reference edit was performed. The only new file
from this follow-up is this research document.
