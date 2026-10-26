# Duplicate ZIP entry names

All content is hand-authored and synthetic. `fixture.json` uses `rawEntries`
to insert earlier UTF-8 copies of existing archive names. Each entry declares
`name` and `text`; copies appear in declaration order immediately before that
name's normal generated/source entry. The final normal entry wins. `mimetype`
cannot be repeated and stays first, uncompressed, with its ordinary ZIP header.
Names otherwise retain the builder's lexical order and fixed DOS timestamps.

`EPUB/chapter.xhtml` first contains a short discarded paragraph, then the
published section with a heading and two different paragraphs. First-wins
changes projected nodes, sampled CFI endpoints and canonical length/signature.
`EPUB/package.opf` first contains a `/6` spine with `ref-stale`, then the
generated `/8` spine with `ref-chapter` (an intervening guide element). This
also catches first-wins package loading independently of chapter loading.

The committed WebKit vectors and the local Chromium cross-check come from the
ordinary oracle commands. The Dart oracle tests must match the final copies.
