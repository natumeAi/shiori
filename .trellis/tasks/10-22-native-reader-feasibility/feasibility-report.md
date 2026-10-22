# S2 native reader feasibility report (draft after Phase C)

Status of each acceptance row is independent. Nothing here is device evidence:
all numbers come from the Windows development machine (`flutter test`, host
engine, Ahem test font) and from Windows WebKit/Chromium via Playwright.
GO / NO-GO for S4 is not given yet (NC9 pending).

## Rows

| Row | Status | Evidence |
| --- | --- | --- |
| NC1 oracle | Done (Phase A) | Two clean generations (UTC and Asia/Hong_Kong) byte-identical; WebKit 27.2 and Chromium 156 recorded; 13 fixtures, 39 sections, 4,807 sampled CFI points per engine and four local books (60 sections, 168,677 samples) with zero cross-engine differences; vendored reference files match `a4bda23` byte for byte. Details: `local-validation.md`, `research/oracle-notes.md`. |
| NC2 source, CFI, canonical | Done (Phase B, re-run in C) | Dart equals the WebKit vectors for every fixture and the four books (256 data tests, 0 mismatches; `xml` 7.0.1 re-verified). Native-exported CFIs resolve identically in WebKit and Chromium: 4,807/4,807 (Phase B tool) and again 2,413 page-anchor CFIs x 2 engines = 4,826/4,826 in Phase C. |
| NC3 conservation and matrix | Done locally (Phase C) | Tables below. Unsupported fixtures are refused by the detector, never opened empty. |
| NC4 anchors | Done locally (Phase C) | See "Anchors". |
| NC5 motion state machine | Pending Phase D | |
| NC6 harness and quality gate | Pending Phase D/E | Phase C full gate passes (see `local-validation.md`). |
| NC7 device scenarios | Pending device run | |
| NC8 presentation evidence | Pending device run | |
| NC9 GO / NO-GO | Pending | |

## NC3: conservation

Viewport 430x932 logical (content box 334x812 at the defaults), C1 `CssStyleResolver`.
Settings: D = defaults; L = font size 26 + line height 2.0; M = font size 14 +
letter spacing 0.12 em + horizontal margin 48. Every cell passed: page text in
order equals the eligible source text, paragraph maps reproduce text from source,
lines placed once in order, each image/SVG placed once or listed, nothing crosses
the content rectangle. Pages are summed over a fixture's sections.

| Fixture | Sections | D pages | L pages | M pages | Source characters |
| --- | ---: | ---: | ---: | ---: | ---: |
| cfi-structure | 1 | 1 | 1 | 1 | 70 |
| html-fallback | 5 | 5 | 5 | 5 | 29 |
| inert-content | 1 | 1 | 1 | 1 | 19 (SVG placed, math surfaced) |
| opf-variants | 4 | 4 | 4 | 4 | 45 |
| unicode | 1 | 1 | 1 | 1 | 57 |
| styles | 1 | 2 | 4 | 2 | 191 |
| images | 3 | 4 | 5 | 4 | 35 (6 images/SVG) |
| long-content | 3 | 546 | 1530 | 504 | 264,923 |
| chapters | 16 | 16 | 48 | 16 | 5,550 |
| one-page | 1 | 1 | 1 | 1 | 6 |

Four local books at all three settings D/L/M (digests only, no text; D pages shown): `6e4ed2a78ea6` 3
sections / 20 pages / 5,278 characters / 2 images; `aac482b2d33f` 3 / 36 / 9,622
/ 1; `a595d98d4400` 33 / 347 / 86,475 / 0; `9bfc26bc676d` 21 / 443 / 128,385 / 14
(SVG wrappers). All passed with zero unsupported items. A negative test shows the
check fails when expected text is withheld.

### Style matrix outcomes (resolver and layout merged)

| Area | Outcome |
| --- | --- |
| `p`, `div`, `h1`-`h6`, `blockquote`, `section`, `figure`, `hr` | Supported (UA margins, author margin/padding, backgrounds behind text lines, hairline rule). |
| `ul`/`ol`/`li` | Supported with difference: marker is generated text inside the item (not hanging). `list-style-type` (none, disc, circle, square, decimal, lower/upper alpha and roman; UA disc/circle/square nesting, decimal for `ol`), `ol start` and `li value` honored; markers are synthetic (no CFI or canonical slot). |
| `span`, `b`/`strong`, `i`/`em`, `a`, `br`, `small` | Supported. |
| `sup`/`sub` | Supported with difference: smaller size, no baseline shift. |
| `ruby`/`rt`/`rp` | Supported with difference: annotation text is author source text with its coordinates, set inline at half size; generated parentheses (synthetic) only when no `rp` exists. |
| margin, padding, text-indent (incl. `em`), text-align incl. justify, `display` | Supported. Negative margins are ignored. |
| font-size units and keywords, weight, style, family, line-height, letter-spacing, colors | Supported. Reader overrides follow `useReaderSettings.ts`. |
| `@font-face` (linked sheet and inline `<style>`) | Supported: real archive paths, loaded with `loadFontFromList`; both fixture faces load. Non-sfnt (WOFF) fonts and missing files are recorded, not fatal. |
| `white-space` normal / pre / pre-wrap / pre-line / nowrap | Supported for space and newline handling; `pre` and `nowrap` still wrap at the content width (difference `nowrap-wraps`). |
| `img` (width/height/max-width, taller than page) | Supported; contained to content width and page height; undecodable, missing and remote images become listed markers. |
| SVG wrapper around a full-size raster (guard `contentImage.ts:403`) | Supported; nine guard-refusal cases fall to vector; outer `svg` is the anchor. |
| Vector SVG | Supported through `flutter_svg` for shapes/paths (pixel-tested); `text`, `foreignObject`, filters and external images are not painted: listed as `svg-partial` with a corner badge. |
| Tables | Surfaced-unsupported with text flow: flattened to blocks, marker plus `table` entry. |
| `math`, `video`, `audio`, `canvas`, `object`, `embed`, `iframe` | Surfaced-unsupported: marker plus list entry. |
| Borders, `text-transform`, `::before`/`::after` content | Not rendered (see gaps). |

### Unsupported-layout detection (C1, `engine/support`)

| Cue | Result |
| --- | --- |
| `rendition:layout` pre-paginated (package, itemref property, display-options file) | fixed layout, refused |
| spine `page-progression-direction="rtl"` | refused |
| vertical `writing-mode` on root or any rendered element (vendor aliases included, undisplayed ones ignored) | refused, section named |
| `dir="rtl"` / computed `direction: rtl` on root or body; RTL publication language without explicit direction | refused |
| isolated RTL run inside an LTR section | supported, counted informationally |
| fixtures `unsupported-fixed`, `unsupported-vertical`, `unsupported-rtl` | refused with their reasons; the ten supported fixtures and the four books are supported |

`requireSupported()` throws `UnsupportedLayoutException`; the accepted in-memory
anchor is not touched by detection.

## NC4: anchors

- Round trip: for every page of every supported fixture at all three settings the
  exported anchor (reference midpoint policy, image-element fallback) proves and
  resolves back to the same page with its glyph or image box inside the content
  rectangle (2,580 anchors for `long-content` alone; four books: 20 + 36 + 347 +
  443 anchors, every page).
- Oracle landing: 2,980 WebKit vector CFIs whose resolved start is laid out all
  prove, and the page's source spans contain the node/offset; 1,693 samples are in
  the head or hidden text and are not rendered.
- Interop loop: 2,413 native page-anchor CFIs fed to `npm run resolve`; WebKit and
  Chromium resolve to the native node/offset 4,826/4,826.
- Reflow: the accepted anchor remains provable and visible after font size 22,
  size 22 with line height 2.0, size 14 with line height 1.3 and letter spacing
  0.08, and margins 36/24; `reflow` never rewrites the accepted CFI.
- Injected proof failure: `accept`, `acceptPage` and `reflow` keep the previous
  CFI. No page-one, nearest-paragraph or percentage fallback exists.
- Not covered: `notVisible` and `roundTrip` rejections have no natural trigger
  with whole-line packing; only the injected path exercises rejection. Turn-target
  proof belongs to Phase D.

## Fonts

Reader font options map to iOS families (`font_mapping.dart`): system stack to the
platform default; PingFang SC/TC/HK as is; Microsoft YaHei, Heiti SC and Noto Sans
CJK to PingFang SC; SimSun and Noto Serif CJK to Songti SC; KaiTi to Kaiti SC;
`serif` to Times New Roman. The chain is recorded per section
(`PreparedSection.fontChains`); Flutter cannot report which family actually
rendered. The four local books reference fonts missing from their archives
(diagnosed as `stylesheetNotFound:@font-face`, 57 occurrences in three books; the fourth only has 42 ignored `border-radius` declarations) and so use the
mapped families.

## Host timing (indicative, host-only)

The 100,000-code-unit CJK paragraph: 5,556 lines, 199 pages at the defaults;
`Paragraph.layout` median about 5.5-10.6 ms over repeated runs (cold first call
30-60 ms); whole-section preparation (layout, line table, paging) about 25-52 ms.
Font was Flutter's test font Ahem (every glyph a square), so shaping cost is far
below a real CJK font. These numbers say nothing about iPhone cost; the device run
owns that.

## Known differences and gaps

- `sup`/`sub`: no baseline shift.
- Borders (and `border-radius`) and `text-transform` are not rendered.
- `::before` / `::after` generated content is not rendered.
- Tables are flattened to blocks with a visible marker.
- `white-space: pre`/`nowrap` wrap at the content width.
- List markers are inline generated text, not hanging.
- Block backgrounds are painted behind text lines only (no padding/margin boxes).
- Inline images split their paragraph into text, image block, text.
- SVG `text`, `foreignObject`, filters and external images are not painted.
- Songti SC, Kaiti SC and Heiti SC availability on iOS is unverified; the family
  mapping and fallback chain need the device run.
- `Paragraph.getLineBoundary` costs time linear in the paragraph per call (about
  2 ms at 100,000 units on the host); the line table uses `getLineNumberAt` with
  galloping and bisection instead. Whether device cost behaves the same is unknown.
- CJK newline segment-break rules are not applied (newlines collapse to spaces).
- No locale is set on paragraphs (Han glyph variants follow the system).
- Windows WebKit is not the iPhone's Safari; iPhone parsing behaviour is unverified.
- `xml` is held at 7.0.1 because every `flutter_svg` release requires `xml <=7.0.1`.
