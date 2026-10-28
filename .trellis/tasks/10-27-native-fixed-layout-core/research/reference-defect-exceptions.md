# Reference raster defect exceptions (D3)

Date: 2026-10-28. Policy approved by the owner on 2026-10-27 (decision D3 in
`a0-measurement-review.md`). This file records the candidate exceptions and
their limits. The A0 closure harness applies them; it never extends them.

## Rules for every entry

- The defect reproduces in isolated browser controls that are independent of
  the corpus case (`test/fixtures/reader/fixed_layout/paint-controls.json`).
- The reference's raster contradicts CSS/SVG, its own DOM geometry, or both.
  Native follows CSS and the reference's DOM geometry.
- The exemption names exact pixels or one element's glyph region. Pixels
  outside it still pass the D4 edge rule. Exempt pixels are counted and listed
  in the report, never silently dropped.
- An exception never covers a native-only deviation. For device evidence, the
  defect must first reproduce on that device's own Safari (S4c C5).
- Each entry carries a reference-fix handoff. These are WebKit engine
  defects, not lan-reader code, so the handoff is an upstream report the
  owner may file; shiori does not modify the reference.

## RD-1: XHTML-hosted SVG top-left pixel

- Engine: WebKit 27.2 (Playwright 1.64.1), the authoritative host reference.
- Observation: a document served as `application/xhtml+xml` that contains an
  SVG paints black alpha 38 at (0,0). The native output is transparent there.
- Controls: `emptySVG` in `application/xhtml+xml` reproduces it with an empty
  SVG. `empty` XHTML without SVG, `emptySVG` as `text/html`, and every
  Chromium control stay transparent. Two-rAF screenshot repeats are identical.
- Exempt scope: pixel (0,0) only, and only for XHTML-hosted SVG cases whose
  same oracle run reproduces the control.
- Handoff: minimal repro is the empty XHTML SVG control above. Recommended
  upstream WebKit bug report. No lan-reader change is expected.

## RD-2: relatively positioned inline text inside foreignObject

- Engine: WebKit 27.2.
- Observation: in `foreign-object-*`, the span `Z` with `position:relative;
  top:3px` is painted above its sibling text. WebKit's own DOM Range for that
  span records top+3, as CSS requires. Native paints it at top+3.
- Controls: `foreignRelative` reproduces the misplaced paint in isolated
  `text/html` and `application/xhtml+xml` documents. `foreignStatic` (no
  relative offset) is the matching control without the defect.
- Exempt scope: pixels inside the span's glyph box at the native position and
  at the reference-painted position, each expanded by 1 px, in the
  foreign-object cases only. A native render of the `foreignStatic` control must
  pass D4 against its WebKit raster with no exemption, proving that the rest of
  the path matches.
- Handoff: minimal repro is the `foreignRelative` control. Recommended upstream
  WebKit bug report: relative positioning inside SVG foreignObject paints at a
  different offset than layout reports. Books relying on it look different in
  Safari; native intentionally follows CSS.

## Not covered

- Antialiasing differences: handled only by the D4 edge rule.
- WebKit ignoring the parent `textLength` around a `textPath`: its DOM geometry
  and raster agree, so this is consistent reference behavior, not a raster
  defect. Native matches it (the WebKit-compatible variant is the required
  target). The variant that applies the attribute is a retained counterexample.
- DOM Range integer snapping: a measurement-definition issue, handled by the
  channel table and, for coverage, by D6. It is not a raster defect.
