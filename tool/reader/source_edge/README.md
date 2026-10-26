# Source edge fixtures

`make_edge_epubs.py build` writes `edge-xhtml.epub` and `edge-html.epub` (hand-written
filler, no book text) into `test/fixtures/reader/source_edge/`. To refresh the WebKit
vectors, back up `build/oracle-local/{summary,unicode-table,cross-engine-differences}.json`
(`npm run vectors-local` overwrites them), run `npm run vectors-local -- <epub>` in
`tool/oracle/`, then `make_edge_epubs.py trim <build/oracle-local/<sha>.webkit.json> <name>`
and move the generated private-folder outputs away again.

Known limitations (HTML mode): head-level `<template>`, `<noscript>` content that closes an
open `<p>`, and attribute URLs inside script-enabled `<noscript>` raw text differ from WebKit.
