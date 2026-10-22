# Reader fidelity evidence and decision boundary

Inspected on 2026-10-22. The user subsequently accepted native line/page-break
differences while preserving app UI, settings, interactions, and content-based
cross-client resume. That decision does not reduce EPUB content support.

## Current web behavior

All reference anchors in this section are relative to
`D:/Projects/lan-reader`.

- `client/src/hooks/useReaderSettings.ts:22` defines the settings domain:
  default size 18, sizes 14–40 in steps of 2, line height 1.3–2.0 (default
  1.6), and letter spacing 0–0.12 em. Settings values can be reproduced as
  product behavior independently of the underlying layout engine.
- `client/src/hooks/useReaderSettings.ts:46` defines six font choices using
  CSS system-font fallback lists. For example, the Microsoft YaHei choice
  falls back through Microsoft JhengHei to PingFang SC. A UI label alone does
  not prove which actual font was rendered on the iPhone.
- `client/src/hooks/useReaderSettings.ts:249` creates reader CSS overrides
  for body font, size, line height, letter spacing and wrapping. Images/SVG
  retain their complete bounds. EPUB author styles still influence parts
  not overridden by these rules.
- `client/src/hooks/useReaderSettings.ts:313` omits typography/layout
  overrides for fixed-layout content, while retaining theme application.
- `client/src/reader/foliateEngine.ts:205` sets paginated, one-column
  rendering, width-dependent gap, vertical margin, and the reader styles.
  Foliate/browser layout supplies the resulting line and page boundaries.
- `.trellis/spec/frontend/reader-boundaries.md:98` requires content-based CFI
  restoration rather than guessing from a numeric percentage. Its existing
  migration/reflow contract already permits numeric percentage differences
  (`:129`); this does not itself grant permission for Flutter pagination
  differences under the user's new parity requirement.

The app chrome, settings semantics, gestures, and accepted-content location
must remain explicit acceptance targets regardless of the pagination decision.

## Available local regression books

A read-only ZIP/OPF/XHTML/CSS scan of the four top-level `docs/*.epub` files
found the following. No book prose was copied or uploaded.

| Sample | HTML/XHTML resources | Largest source resource, characters | Content features observed |
| --- | ---: | ---: | --- |
| `docs/[入间人间].电波女与青春男 外传 8月×日 今夜星光必将灿烂（网翻）.epub` | 3 | 8,225 | Two `img` tags; font, margin, indentation and alignment rules. |
| `docs/[入间人间].电波女与青春男~外传 请让我回家（网翻）.epub` | 3 | 12,903 | One `img` tag; comparable prose styling. |
| `docs/和非常可爱的我交往吧！_短篇.epub` | 33 | 8,307 | Text-oriented resources; no sampled special tags. |
| `docs/综上所述，我们证明了初恋 - 02.epub` | 22 | 50,191 | Fourteen `svg` tags; additional display/color/background styling. |

These counts are resource-source measurements, not reading-word counts or
spine/chapter counts. The scan found no explicit package layout/direction
declarations or CSS writing-mode values in these files, and no sampled
`ruby`, `rt`, `table`, `math`, `audio`, or `video` tags. This does not establish
absence of those features in the user's NAS library or their exclusion from
the target product.

Additional existing regression infrastructure includes
`docs/chapter-browser-data/books/chapter-regression.epub`,
`client/test/browser/p5-fixture.ts`, and reader tests for layout, restoration,
turn proof, input queue, animation isolation and pagination lifecycle. These
are starting evidence, not a complete compatibility corpus.

## Accepted fidelity boundary

The user accepted the following boundary after its implementation-cost
trade-off was explained:

- Match app chrome, reader controls, visual settings, gestures and behavior.
- Preserve the same content position across web/app through CFI-compatible
  anchors, even when that content falls on a different native page number.
- Permit native line/page-break differences under equivalent visual settings,
  without missing, duplicated, clipped or reordered content.

Exact browser line/page-break equivalence is therefore not an acceptance
requirement. Unsupported or silently omitted content is not covered by this
permission. The user separately accepted the ordinary horizontal reflowable
novel scope in `native-reader-options.md`; the parent design combines these
four local books with generated source/style/Unicode/image/stress fixtures.
