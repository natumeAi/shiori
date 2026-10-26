# S2 oracle observations

## Authority and environment

Reference commits: lan-reader
`a4bda23fd3e82e285a22566d88576e67d3e8756b`; foliate-js
`78914aef4466eb960965702401634c2cb348e9b1`. Source behavior wins over wording
in the design. Vendored canonical, protection, visible-anchor and shared
constant source payloads pass byte-for-byte `git show` drift checks; provenance
headers are excluded by their exact recorded byte length.

Validated on Windows using Node `v24.19.0`, npm `11.17.0`, Playwright `1.64.1`,
WebKit `27.2` (build `2370`), Chromium `156.0.8078.4` (build `1248`). WebKit is
authoritative for every vector and the Unicode table; Chromium is a
cross-check. Windows WebKit is not the iPhone's Safari build. No result here
establishes physical-device behavior or presentation.

## Cross-engine results

- Synthetic corpus: 13 fixture EPUBs, 39 sections, 4,807 sampled CFI
  points/ranges per engine. First complete extraction: zero differences in
  package/spine/TOC, parser selection, projected nodes, canonical results/maps,
  CFI parse/collapse/resolve/comparison and grammar vectors.
- Four local books: 60 spine sections, 168,677 sampled CFI points/ranges per
  engine. Both engines completed successfully in the same local command;
  zero differences in the extracted behavior. Digests, private vectors and
  per-book results stay in `build/oracle-local/`. No real book was copied into
  the repository or its assets.
- The generated full code-point exclusion range tables agree exactly. No
  public browser API exposes the Unicode database version, so `unicodeVersion`
  is null with an explicit explanation. The engine version and full table
  source in committed `unicode-table.json` pin the behavior used by Phase B.

Final regeneration and reproducibility evidence, including NCX-only/nested-TOC
coverage added during review, is recorded in `local-validation.md` and the
final generated summary/difference files. No differing engine case has been
relabelled as equivalent or discarded.

## Reference ambiguities resolved by actual source and vectors

1. **Fallback is not only a well-formedness check.** `epub.js:817–825` also
   changes an XHTML resource to HTML when its document element has no namespace.
   The five-section fallback fixture shows malformed XHTML and bare `&nbsp;`
   falling back after `parsererror`; a missing-namespace document falls back
   without a parser error; XHTML DOCTYPE plus `&nbsp;` stays XML; an explicitly
   HTML manifest resource uses HTML directly. Both engines agree.
2. **Projection is after the loader and a final reparse.** The reference first
   parses/falls back, rewrites resource links and serializes; its `data` event
   applies `protectBookDocument` using the possibly changed MIME type; the
   paginator navigates an iframe to the resulting Blob URL. The oracle follows
   that entire sequence. It does not sanitize the original malformed XML
   directly, which would incorrectly reject the reference's repaired HTML.
3. **Inert slots and CSP affect structure.** The protection function preserves
   blocked element positions/IDs with inert replacements, keeps form children,
   uses `g` for blocked SVG elements, strips processing instructions, and
   prepends a CSP meta element in the head. Canonical and CFI operate on the
   final document, including those slots. XML comments/CDATA are retained;
   canonical indexing walks Text only, whereas Foliate CFI merges Text/CDATA
   chunks. Their coordinates must remain distinct.
4. **Equivalent chunk boundary points can change node identity.** Six samples
   in `cfi-structure` resolve to a different input node/offset representation.
   Foliate's chunk resolver uses `sum + length >= offset`, so a boundary at
   the next text node's start can resolve to the preceding node's end. Vectors
   retain both the requested point and the actual resolved point. The native
   implementation must reproduce this behavior rather than require identical
   input and resolved node indices.
5. **Unknown assertion parameters are discarded by Foliate.** For
   `epubcfi(/6/2!/4/2[id;unknown=value])`, actual parse/collapse drops the unknown
   parameter and serializes `epubcfi(/6/2!/4/2[id])`. Recognized `;s=` is retained.
   This differs from design section 4's broad instruction to preserve unsupported
   assertions. The source and golden outputs are authoritative; original raw
   tokens can be retained separately without changing oracle-compatible
   parse/collapse results. Malformed-input permissiveness and error classes are
   captured rather than replaced with a stricter grammar.
6. **Spine bases are structural.** The OPF-variant fixture puts a guide before
   the spine; bases are `/8/...`, not `/6/...`. Its nonlinear item is retained,
   spaces and percent-encoded hrefs resolve to archive paths, and `../` resolves
   relative to the non-default OPF directory. Review added NCX-only nested
   navigation there and nested EPUB3 nav in `chapters`, exercising both paths.
7. **Blob URLs are nondeterministic implementation identities.** The extractor
   preserves the actual DOM and CFI offsets. Only serialized projected character
   data uses stable, length-neutral resource tokens, keyed by SHA-256 of actual
   Blob payloads and mapped back to sorted package-path alias sets. Identical
   resources at different hrefs retain all aliases. Only exact captured URLs
   are replaced; literal `blob:example` prose/comments/CDATA stay unchanged.
   Inline font CSS plus two byte-identical font aliases exercises the mapping.
   This avoids random UUIDs in
   committed vectors without altering DOM UTF-16 coordinates.
8. **ZIP dates require local-calendar construction.** fflate writes local DOS
   date/time fields. A fixed UTC instant varies by host timezone; the builder
   now constructs the fixed local calendar date. UTC and Asia/Hong_Kong runs
   produce identical asset bytes. Scoped Git attributes also preserve LF
   sources and the deliberate mixed newline bytes in the Unicode fixture.
   A post-staging check found that attributes normalize index blobs without
   rewriting already-existing CRLF worktree files. Seven ordinary source text
   files were canonicalized in the worktree, preserving the mixed Unicode
   fixture and binary fonts. All 86 tracked oracle files then matched HEAD
   blobs byte-for-byte, and vendored payload drift checks still passed. The
   reproducibility harness now refuses raw source bytes that differ from Git's
   path-filtered representation before either clean generation. Final asset
   digests were regenerated from the exact committed source bytes.
9. **Author ruby annotations are source text.** The canonical implementation
   excludes only script/style/noscript/template and SVG/MathML subtrees. Author
   `rt`/`rp` Text therefore has canonical coordinates in the styles fixture.
   Design section 5.1's synthetic-annotation wording must not remove those
   source coordinates. Only additional generated presentation/markers are
   synthetic; author ruby, annotation and fallback-parenthesis text remains
   mapped to its original source nodes and CFI/canonical positions.

## Dependency decisions

| Package | Exact pin | Licence | Reason |
| --- | --- | --- | --- |
| foliate-js | `78914aef4466eb960965702401634c2cb348e9b1` | MIT | Execute the actual reference EPUB and CFI implementations |
| fflate | `0.8.2` | MIT | Match UTF-8 decoding and ZIP behavior; create deterministic fixtures |
| esbuild | `0.28.2` | MIT | Bundle vendored TypeScript and browser ESM |
| playwright | `1.64.1` | Apache-2.0 | Pinned real WebKit/Chromium control |

These are oracle development dependencies only. Package metadata/licences and
the npm registry were checked locally. Runtime Dart parser/dependency choices
are deferred to Phase B. Roboto Regular is an attributed Apache-2.0 fixture
font; its digest, source pin, embedded licence and notice are recorded beside
the source fixture. No font installation or system setting was changed.
