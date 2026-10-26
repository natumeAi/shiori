# CFI implementation resume notes

User explicitly paused work during Phase B. This is handoff documentation only.
No CFI implementation tests or format/analyze commands have run yet. No process
or tool session is running from this sub-agent, and no commit was made.

## Files already written

- `lib/features/reader/data/cfi/cfi_exception.dart`: `CfiException` with
  `referenceErrorName`, preserving the browser error class for vector comparison.
- `lib/features/reader/data/cfi/cfi_step.dart`: immutable `CfiStep` with `num index`,
  optional `id`, `offset`, `temporal`, `spatial`, `text`, `side`. `toJson()` turns
  non-finite numbers into null as JavaScript JSON serialization does.
- `lib/features/reader/data/cfi/cfi_expression.dart`: immutable path/range AST,
  `groups`, optional `parent/start/end`, original raw spelling, `toJson()`.
- `lib/features/reader/data/cfi/cfi_range.dart`: immutable `start/end`
  `SourcePosition`, plus `collapsed` getter.

These files are drafts, not yet formatted or compiled. `cfi.dart` does not exist.
A larger facade/resolver draft was prepared in conversation but its write was
blocked by the first Trellis spec injection and never reached disk. The four
small model files were written successfully on the retry before the pause.

## Agreed public API for the missing facade

Entry point: `lib/features/reader/data/cfi/cfi.dart`, `abstract final class Cfi`.

- `parse(String) -> CfiExpression`
- `serialize(CfiExpression) -> String`
- `collapse(String, {bool toEnd = false}) -> String`
- `compare(String, String) -> int`
- `sort(Iterable<String>) -> List<String>`: stable sort with original input index
  as tie breaker, because JavaScript array sorting is stable and Dart sort is
  not guaranteed stable.
- `joinIndirection(List<String>) -> String`
- `export(SourceDocument, SourcePosition start,
  {SourcePosition? end, String? sectionBase}) -> String`
- `resolve(SourceDocument, String) -> CfiRange`: resolve the final local
  indirection group after collapsing each endpoint.
- `resolvePackageNode(SourceDocument package, String) -> int`: resolve the first
  package path to the actual OPF itemref; caller obtains `idref` via attributes.
  Never infer section identity from a fixed `/6` or numeric arithmetic.

This API was approved by the parent and sent to the source/EPUB implementer.

## Shared source model coordination

Peer owns the existing `data/source/**` files. Do not overwrite them.

- `SourceNodeKind`: element, text, cdata, comment, processingInstruction.
- `SourceNode`: index, kind, namespaceUri, localName, id, parentIndex, childSlot,
  children (`List<int>`), attributes (`List<SourceAttribute>`), text.
  `isCharacterData` means Text or CDATA; `attribute(qualifiedName)` is available.
- `SourceDocument`: nodes, documentElementIndex, bodyIndex, parserMode
  (`SourceParserMode.xhtml/html`), parserErrorClass. Methods `node(index)`,
  `attribute(nodeIndex,name)`, `getElementById(id)`, `toProjectionJson()` exist.
- `SourcePosition`: named `nodeIndex` and `offset`, equality/hashCode implemented.
  Offset is UTF-16 in character data, child offset in elements.

The source parser was not ready at this sub-agent's last coordination message.
CFI tests can initially reconstruct SourceDocument from committed projections,
then integration tests must also exercise actual native source documents.

## Exact algorithm to port

Authority is the complete installed pinned file
`tool/oracle/node_modules/foliate-js/epubcfi.js`, commit
`78914aef4466eb960965702401634c2cb348e9b1`. Read it before continuing.
Task `research/oracle-notes.md` captures observed ambiguities.

1. Port the tokenizer state machine, not a strict CFI grammar. Iterate Unicode
   code points like `Array.from`, with a final empty sentinel; handle `^` escape,
   `/`, `:`, `~`, `@`, assertions and `;` parameters exactly. Unknown parameter
   tokens change parser state but are otherwise discarded. `;s` is recognized.
   Assertion text continuation deliberately does not update the previous state.
2. Preserve permissive behavior: empty and `not-a-cfi` parse to `[[]]` and collapse
   to `epubcfi()`. `/` parses an index NaN (JSON null), serialized as `/NaN`.
   `epubcfi(:2)` and incomplete two-part ranges fail with reference `TypeError`.
   Unterminated assertions can be dropped without throwing. Original spelling
   can be retained separately; oracle AST/collapse must still discard unknown
   parameters as the pin does.
3. Numeric formatting follows JavaScript: omit zero/NaN temporal values, emit an
   offset only on odd indices, retain spatial/text arrays even when empty,
   escape only `^[](),;=`. `parseFloat` accepts a valid numeric prefix, unlike
   Dart `num.tryParse` on a whole malformed dotted string. JavaScript trim has
   an explicit whitespace set, excluding NEL U+0085.
4. Split tokens on unescaped comma, then on indirection; range uses the first
   three pieces as parent/start/end. Collapse concatenates parent's last group
   with endpoint's first group and keeps other groups. Range construction shares
   steps while numeric indices match and both offsets are falsy (zero counts as
   falsy); IDs do not decide common ancestry.
5. Compare collapsed range starts, then ends. For ordinary paths compare groups,
   steps, indices and only the final compared step's offsets. Missing offsets
   compare like JS undefined (neither greater nor less), not numerical zero.
   Ignore assertion spellings and temporal/spatial values as the reference does.
6. Index source children after filtering to elements/Text/CDATA. Ignore comments
   and PIs. Merge adjacent Text/CDATA into chunks, insert absent text chunks
   between adjacent elements, then add first/last text-slot sentinels and virtual
   before/after element sentinels. Empty filtered children cause reference
   `TypeError` because the pinned function destructures an absent first child;
   do not silently invent standard-compliant behavior.
7. Export by walking parent links to documentElement. Element step is its indexed
   child slot plus ID; Text/CDATA chunk offsets add lengths of preceding chunk
   nodes in UTF-16. Ancestor element offsets are null/zero but serialize without
   offsets on even steps. Point range collapses when start/end positions equal.
   Join the caller-supplied real section base to the exported local CFI.
8. Resolver checks the LAST step's ID globally first and immediately returns
   the matching element at offset zero. Otherwise walk indexed children.
   First/last sentinel returns the parent's raw first/last child at offset zero,
   not the end of its text. Before/after yields parent boundary offsets.
   A boundary outside the documentElement can use synthetic document index -1
   internally; ordinary vectors do not sample document boundaries.
9. For merged chunks use `sum + length >= offset`, intentionally choosing the
   preceding text node's end at a shared boundary. Preserve input versus actual
   resolved coordinates in tests. Direct text offsets beyond length produce
   `IndexSizeError`; missing chunk offset or unresolved paths produce TypeError.
10. Browser Range.setEnd collapses start to end if endpoints reverse. Implement
    DOM boundary comparison using ancestor/childSlot relationships (not node
    index alone when one node contains another), then normalize reversed ranges.

## Validation to add on resume

- Grammar AST, serialization/collapse and reference error classes for all
  committed grammar vectors.
- All 4,807 synthetic sampled CFIs: parse AST, both collapsed endpoints, native
  export string, native resolve endpoints/collapsed status, stable comparison
  ordering. Reconstruct projections initially to isolate CFI from parser bugs.
- Explicit virtual edge/empty-child/ID shortcut/reversed-range tests, comparing
  any newly needed reference case with the actual pinned implementation.
- Actual OPF itemref resolution, including `/8` and nonlinear spine items.
- Integration through native source documents, plus native exports fed back to
  `npm run resolve`. Peer owns full source/canonical/package golden integration.
- Private book vectors stay under `build/oracle-local/`. Do not print book text
  or title-bearing node values on failed private comparisons. Use safe digests,
  structural indices and lengths in public task logs.

Use package imports, no dynamic, no widgets/Riverpod/dart:ui in this module.
Read Trellis guidelines before editing. SDK commands require escalated SDK
cache/process access in this environment; otherwise they can stall. All long
commands need explicit timeouts. No Phase C, commit, or push is authorized by
this subtask; the parent coordinates the full Phase B gate and commit.
