# Phase B source/package implementation resume notes

User explicitly paused implementation on 2026-10-22. This is a handoff, not a
passed gate. Do not commit the partial Phase B changes before resuming checks.

## Written drafts

- `lib/features/reader/data/source/source_attribute.dart`
- `lib/features/reader/data/source/source_node.dart`
- `lib/features/reader/data/source/source_document.dart`
- `lib/features/reader/data/source/source_position.dart`
- `lib/features/reader/data/source/source_parser.dart`
- `pubspec.yaml` and `pubspec.lock`: successful `flutter pub add archive xml
  html csslib` (exit 0, 180-second timeout, 2.806 seconds), evidence in
  `reader-dependency-install.json` (now `evidence/reader-dependency-install.json`).

Resolved candidates: archive 4.5.2 (MIT, Dart >=3), xml 7.1.0 (MIT, Dart
^3.13), html 0.15.7 (MIT, Dart ^3.6), csslib 1.0.2 (BSD-3-Clause, Dart ^3.1).
Transitives add petitparser 7.1.0 and posix 6.5.2 (MIT); meta changed from
1.18.3 to 1.19.0 because xml requires it. Existing go_router/build_runner
pins remain. PRD and quality-guideline dependency rows are NOT yet updated.

No EPUB/package, canonical implementation, or source/package golden tests
have been written. No Phase B formatter, analyzer, codegen or test has run.
The parser is an unformatted, uncompiled draft; do not call it complete.
No subprocess from this implementer remains running at the pause boundary.

## Shared source API already sent to the CFI worker

`SourceNodeKind`: element, text, cdata, comment, processingInstruction.
`SourceNode` has immutable index/kind/namespaceUri/localName/id/parentIndex/
childSlot/children/attributes/text. `SourceAttribute` preserves qualified and
local names, namespace and value. `SourceDocument` has nodes,
documentElementIndex, bodyIndex, parserMode, parserErrorClass; node lookup,
attribute lookup, getElementById, and oracle-shaped projection JSON.
`SourcePosition(nodeIndex:, offset:)` uses UTF-16 for character data and child
offsets for elements, with equality/hashCode. CFI owns its own files/tests.

## Parser draft and fidelity work still needed

The draft selects XML/HTML, normalizes raw CRLF/CR, detects missing root
namespace, adds the reference inert projection/CSP, serializes and reparses,
and flattens stable depth-first identities. It keeps Text versus CDATA,
comments, top-level doctype slots, and suppresses template content from the
projected child-node list. It has a CSS-text rewrite callback for the EPUB
loader projection. None of this has been checked against a vector yet.

First run targeted static analysis: constructor/API details may need repair
(especially the `_StrictEntities` const initializer using mapping-instance
fields and the exact xml/html package APIs). Then write source/package
goldens and fix measured mismatches; do not treat the draft as a working
browser-compatible parser.

Important package findings:

- xml's default entity decoder leaves unknown entities intact; the draft
  strict wrapper rejects unknown/unterminated entity references so XHTML can
  follow browser HTML fallback. XHTML recognized DOCTYPE uses the package's
  HTML entity mapping. Exact external-DTD recognition remains to validate.
- xml's grammar accepts unquoted/missing attribute assignments. The draft
  DOES NOT YET repair this permissiveness. A lexical well-formedness wrapper
  must select fallback as the reference does, without modifying valid source.
- XML attribute raw newline/tab normalization versus numeric character
  references also needs validation; preserve referenced LF/CR while literal
  attribute whitespace follows XML rules.
- html's DOM/parser has no explicit template-content representation. The
  draft hides template children in final projection, but HTML insertion-mode
  fidelity and XMLSerializer/reparse behavior require vectors/tests.
- Removing a PI can expose adjacent Text nodes. The final serialization and
  reparse must merge those nodes while retaining CDATA boundaries.
- Do not leak library parse exception source excerpts for private books.
  Private golden failures must report digest/section/node/coordinate and
  hashed differences, never expected/actual copyrighted prose.

## Planned EPUB/resource projection

Use a pure-Dart ZIP reader with declared compressed/entry/total expansion
limits, validate uncompressed headers before accessing lazy content, and
decode text with UTF-8 replacement as fflate does. Preserve actual OPF
itemrefs, nonlinear sections, namespace identities, nested nav/NCX and href
resolution; do not assume a /6 spine. Retain original resource strings for
layout/style processing independently of the projected source document.

The inline-style Blob normalization cannot be manufactured by importing
golden vectors into production. Build a deterministic reference-loader
resource graph from actual package references/aliases. Reference URLs are
rewritten before protection and final iframe parse. Character-data tokens
are length-neutral (63 UTF-16 units for the pinned oracle origin/UUID), and
their ordinal follows sorted logical alias groups across resources actually
loaded by the oracle. The styles fixture uses byte-identical Roboto Copy and
Regular aliases; both must survive. Raw transformed CSS hashes may contain
random child URLs, so serialized identities must derive from logical aliases.
Head-style CFI portability is origin-length dependent; body positions are
unaffected. Record this limitation, do not hide head samples.

## Canonical layer not started

No delegate was started and no canonical files exist from this implementer.
Suggested API: `CanonicalIndex.build(SourceDocument)` with version, length,
signature and immutable entries containing nodeIndex/start/length/
utf16Length/canonicalToUtf16. Generate the exclusion ranges from committed
WebKit `unicode-table.json`; never use a different Unicode database silently.
Walk only Text (not CDATA), excluding script/style/noscript/template and
SVG/MathML ancestry. Author rt/rp text DOES have coordinates. Use safe
16-bit-limb FNV-1a64 like the exact reference, checked by oracle signatures.

## Exact next steps after the user resumes

1. Inspect current git state and coordinate ownership with the parent/CFI
   worker; do not discard any partial edits.
2. Analyze/format the source drafts, implement package parsing/resource
   projection, and add synthetic source/package golden comparisons.
3. Implement canonical/table generation or explicitly assign that ownership.
4. Compare all synthetic and private local-book vectors, preserving private
   text only under ignored local directories. Coordinate native CFI export
   and resolve CLI interoperability with the CFI worker.
5. Update dependency justification/approved table, run the full Phase B
   gate, record evidence, then request parent checker/commit coordination.

No Phase C work, extra commit, push, remote action or device run is authorized
by this paused handoff.
