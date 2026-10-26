# Native reader options and EPUB coverage

Originally researched on 2026-10-22. No dependency was installed, selected,
or tested by this research. The coverage section was revised on 2026-10-26
after the user added simple and complex static fixed layout to S4. Historical
package observations below are dated evidence, not a fresh package review.

## Required boundary

The user requires Dart/Flutter implementation of the client and reader, and
has accepted different native line/page boundaries. Browser JavaScript or a
WebView-backed EPUB renderer is therefore not an eligible implementation.
Content-based cross-client resume and canonical-text statistics still apply.

## Package evidence

| Candidate | Primary-source evidence | Implication |
| --- | --- | --- |
| `flutter_epub_viewer` 2.1.0 | Its publisher describes epub.js plus `flutter_inappwebview`. | Not eligible under the explicit rewrite constraint, regardless of its feature list. |
| `epub_view` 3.3.0 | Its publisher describes Flutter-widget rendering and exposes CFI generation/navigation; the dependencies include `epubx`, `flutter_html`, and `scrollable_positioned_list`. | Eligible for investigation as Flutter code, but the existence of a CFI API does not prove precise compatibility with saved Foliate anchors, page-turn semantics, or 120 Hz behavior. Do not adopt it as a drop-in reader without those proofs. |
| `epubx` 4.0.0 | Its publisher describes a Dart EPUB parser exposing metadata, chapters, HTML/CSS, images and fonts; the main example loads all content into memory. | A parsing candidate, not a complete native pagination/animation engine. Preserve raw source-document structure for CFI and benchmark memory behavior before selection. |

Sources:

- [flutter_epub_viewer](https://pub.dev/packages/flutter_epub_viewer)
- [epub_view](https://pub.dev/packages/epub_view)
- [epubx](https://pub.dev/packages/epubx)

These observations are not an exhaustive evaluation of all available
packages, and no performance claim is made for any candidate.

## Technical direction to validate

- Reuse suitable Dart archive/XML/resource parsing utilities where they meet
  the source-fidelity and resource-budget requirements.
- Keep original document nodes/text offsets and package/spine identity so
  CFI and canonical-text mappings can be generated independently of layout.
- Build or adapt native block/inline layout and pagination with explicit
  page-to-content mappings. Do not use flattened plain text as the sole book
  representation; it would discard images, styles, and structural anchors.
- Separate page preparation, gesture state, animation, accepted navigation,
  and persistence. Precompute reusable page content so steady animation
  frames need not parse or repaginate the book.
- Use a small representative corpus and exported on-device timings to decide
  whether a package adaptation or a dedicated layout implementation is
  appropriate. A package name and a demo are not acceptance evidence.

## Reference coverage exceeds the existing novel samples

Relative anchors below refer to `D:/Projects/lan-reader`.

- `client/src/reader/foliateEngine.ts:57` exposes RTL reading direction.
- `client/src/reader/foliateNavigation.ts:18` handles fixed-layout spreads and
  non-linear sections.
- `client/test/foliateFixedLayoutCompatibility.test.ts:66` exercises direction
  and portrait/spread combinations, and `foliateFixedLayoutVerification.test.ts:91`
  covers scaled content-CFI visibility/round-trip behavior.
- `client/test/browser/p5-fixture.ts` provides reflowable, long-chapter, and
  fixed-layout fixture variants, including SVG illustrations.
- `client/test/contentImage.test.ts:200` and image-viewer code cover SVG image
  handling. SVG illustration support must not be confused with support for
  arbitrary fixed-layout publications.
- The four existing top-level `docs/*.epub` samples have ordinary horizontal
  novel-style content, including illustrations/SVG, as recorded in
  `research/reader-fidelity.md`. They do not prove coverage of the whole NAS
  library or of every layout supported by the browser engine.

## Accepted first-release coverage

The first complete release includes ordinary horizontal, left-to-right,
reflowable novel/light-novel EPUBs with illustrations and normal text styling,
single-image fixed pages, complex static fixed-layout books and mixed
publications. The user approved the fixed-layout expansion on 2026-10-26;
`fixed-layout-expansion.md` records its evidence and required capability
matrix. Vertical/right-to-left reading remains deferred.

This is the user's revised first-release scope, not an inference that
special layouts are absent from the reference. It does not reduce the
home/bookshelf/statistics UI and interaction parity requirements.

Specify unsupported-content detection and a clear recoverable
message rather than silently omitting content. Exact allowed styles and edge
cases must be enumerated in design and fixtures, not left as the phrase
"supports EPUB".
