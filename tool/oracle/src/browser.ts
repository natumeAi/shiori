import { unzipSync, strFromU8 } from 'fflate';
import { EPUB } from 'foliate-js/epub.js';
import * as CFI from 'foliate-js/epubcfi.js';
import { protectBookDocument } from '../reference/lan-reader-a4bda23/contentSecurity';
import { buildCanonicalTextIndex, canonicalToUtf16, isCanonicalCodePoint }
  from '../reference/lan-reader-a4bda23/canonicalText';

const kind = { 1: 'element', 3: 'text', 4: 'cdata', 7: 'pi', 8: 'comment' };
const digest = async (bytes: BufferSource) => [...new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))]
  .map(x => x.toString(16).padStart(2, '0')).join('');
const dataBytes = async (data: string | Blob) => typeof data === 'string'
  ? new TextEncoder().encode(data) : new Uint8Array(await data.arrayBuffer());

async function openBook(bytes: number[]) {
  const files = unzipSync(Uint8Array.from(bytes));
  // Exact createBook loader contract in foliateEngine.ts:459–478.
  const book = await new EPUB({
    loadText: (name: string) => files[name] ? strFromU8(files[name]) : null,
    loadBlob: (name: string) => files[name] ? new Blob([files[name].slice().buffer]) : null,
    getSize: (name: string) => files[name]?.length ?? 0,
  }).init();
  const records: Promise<{ name: string; hash: string }>[] = [];
  book.transformTarget.addEventListener('load', (event: CustomEvent) => {
    if (event.detail.isScript) event.detail.allow = false;
  });
  book.transformTarget.addEventListener('data', (event: CustomEvent) => {
    const detail = event.detail;
    if (['application/xhtml+xml', 'text/html', 'image/svg+xml'].includes(detail.type)) {
      detail.data = Promise.resolve(detail.data).then(source => protectBookDocument(source, detail.type));
    }
    records.push(Promise.resolve(detail.data).then(async data => ({
      name: detail.name, hash: await digest(await dataBytes(data)),
    })));
  });
  return { files, book, records };
}

async function loadSection(book: any, section: any) {
  const src = await section.load();
  const frame = document.createElement('iframe');
  // Same sandbox and navigation reparse as paginator.js:244–282.
  frame.setAttribute('sandbox', 'allow-same-origin allow-scripts');
  frame.setAttribute('scrolling', 'no');
  document.body.append(frame);
  await new Promise<void>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`iframe load timeout: ${section.id}`)), 20000);
    frame.onload = () => { clearTimeout(timer); resolve(); };
    frame.onerror = () => { clearTimeout(timer); reject(new Error(`iframe load failed: ${section.id}`)); };
    frame.src = src;
  });
  if (!frame.contentDocument?.documentElement || frame.contentDocument.querySelector('parsererror')) {
    throw new Error(`Final protected document could not be reparsed: ${section.id}`);
  }
  return { frame, doc: frame.contentDocument };
}

function project(doc: Document) {
  const nodes: Node[] = [];
  const projection: any[] = [];
  function visit(node: Node, parent: number | null, slot: number) {
    if (!(node.nodeType in kind)) return;
    const index = nodes.length;
    nodes.push(node);
    const element = node.nodeType === 1 ? node as Element : null;
    projection.push({ index, kind: kind[node.nodeType], namespaceURI: element?.namespaceURI ?? null,
      localName: element?.localName ?? null, id: element?.id ?? null,
      parent, slot, text: element ? null : node.nodeValue });
    [...node.childNodes].forEach((child, childSlot) => visit(child, index, childSlot));
  }
  [...doc.childNodes].forEach((node, slot) => visit(node, null, slot));
  return { nodes, projection };
}

function offsets(node: Node) {
  const text = node.nodeValue ?? '';
  const positions = new Set([0, text.length]);
  if (text.length <= 32) for (let i = 0; i <= text.length; i++) positions.add(i);
  else for (const i of [1, Math.floor(text.length / 2), text.length - 1]) positions.add(i);
  for (let i = 0; i < text.length; i++) {
    const code = text.charCodeAt(i);
    if (code >= 0xd800 && code <= 0xdbff && text.charCodeAt(i + 1) >= 0xdc00
      && text.charCodeAt(i + 1) <= 0xdfff) { positions.add(i); positions.add(i + 1); positions.add(i + 2); }
  }
  return [...positions].sort((a,b) => a-b);
}

function extractSection(book: any, section: any, doc: Document, parser: any) {
  const { nodes, projection } = project(doc);
  const nodeIds = new Map(nodes.map((node, index) => [node, index]));
  const index = buildCanonicalTextIndex(doc);
  const canonical = { version: index.version, length: index.length, signature: index.signature,
    entries: index.entries.map(entry => ({ node: nodeIds.get(entry.node), start: entry.start,
      length: entry.length, utf16Length: entry.utf16Length, canonicalToUtf16: [...canonicalToUtf16(entry.node)] })) };
  const point = (range: Range) => ({
    start: { node: nodeIds.get(range.startContainer), offset: range.startOffset },
    end: { node: nodeIds.get(range.endContainer), offset: range.endOffset },
    collapsed: range.collapsed,
  });
  const samples: any[] = [];
  const add = (range: Range, sampleKind: string) => {
    const local = CFI.fromRange(range), cfi = CFI.joinIndir(section.cfi, local);
    const resolved = book.resolveCFI(cfi);
    const roundTrip = resolved.anchor(doc);
    samples.push({ kind: sampleKind, input: point(range), cfi, parsed: CFI.parse(cfi),
      collapsedStart: CFI.collapse(cfi), collapsedEnd: CFI.collapse(cfi, true),
      resolvedSection: resolved.index, resolved: point(roundTrip) });
  };
  for (const node of nodes) {
    if (node.nodeType === 3 || node.nodeType === 4) {
      for (const offset of offsets(node)) {
        const range = doc.createRange(); range.setStart(node, offset); range.collapse(true); add(range, 'point');
      }
      if (node.nodeValue?.length) {
        const range = doc.createRange(); range.setStart(node, 0); range.setEnd(node, node.nodeValue.length);
        add(range, 'node-range');
      }
    } else if (node.nodeType === 1 && (node as Element).matches('img, svg, image, h1, h2, h3, h4, h5, h6')) {
      const range = doc.createRange(); range.selectNodeContents(node); range.collapse(true); add(range, 'element');
    }
  }
  const texts = nodes.filter(node => node.nodeType === 3 && node.nodeValue?.length && doc.body?.contains(node));
  if (texts.length > 1) {
    const range = doc.createRange(); range.setStart(texts[0], 0);
    range.setEnd(texts.at(-1)!, texts.at(-1)!.nodeValue!.length); add(range, 'cross-node-range');
  }
  const comparisons = samples.map(sample => sample.cfi).reverse();
  return { href: section.id, cfiBase: section.cfi, parser, projection, canonical, samples,
    comparison: { input: comparisons, sorted: [...comparisons].sort(CFI.compare) } };
}

const grammarInputs = [
  'epubcfi(/6/2[ref^,one]!/4/2[a^]b^^c]/1:1)',
  'epubcfi(/8/4!/4/2,/1:0,/1:8)',
  'epubcfi(/6/2!/4/2/1:0[before,after;s=b])',
  'epubcfi(/6/2!/4/2~1.25@2.5:3.5)',
  'epubcfi(/6/2!/4/2[id;unknown=value])',
  'epubcfi(/6/2!/4/2[id;s=a])',
  'epubcfi(/6/2!/4/0)', 'epubcfi(/6/2!/4/1:0)',
  '', 'not-a-cfi', 'epubcfi()', 'epubcfi(/)', 'epubcfi(:2)',
  'epubcfi(/6/2,/4/2)', 'epubcfi(/6/2!/4/2[unterminated)',
];

async function vectors(bytes: number[]) {
  const urls: { url: string; blob: Blob }[] = [];
  const nativeCreate = URL.createObjectURL.bind(URL);
  URL.createObjectURL = blob => {
    const url = nativeCreate(blob); urls.push({ url, blob }); return url;
  };
  const frames: HTMLIFrameElement[] = [];
  let book: any;
  try {
    const opened = await openBook(bytes); book = opened.book;
    const { files, records } = opened;
    const opfPath = Object.keys(files).find(name => name === 'META-INF/container.xml')
      ? new DOMParser().parseFromString(strFromU8(files['META-INF/container.xml']), 'application/xml')
        .getElementsByTagNameNS('*', 'rootfile')[0].getAttribute('full-path') : null;
    const sections = [];
    for (const section of book.sections) {
      const item = book.resources.getItemByHref(section.id);
      const originalType = item.mediaType;
      const initial = new DOMParser().parseFromString(strFromU8(files[section.id]), originalType);
      const initialError = initial.querySelector('parsererror');
      const parser = { originalType, used: originalType === 'application/xhtml+xml'
        && (initialError || !initial.documentElement?.namespaceURI) ? 'html-fallback'
        : originalType === 'text/html' ? 'html' : 'xhtml',
        errorClass: initialError ? 'xml_parsererror' : !initial.documentElement?.namespaceURI ? 'missing_namespace' : null };
      const loaded = await loadSection(book, section); frames.push(loaded.frame);
      sections.push(extractSection(book, section, loaded.doc, parser));
    }
    // Preserve the real resource rewrite/reparse path. Replace only nondeterministic
    // blob identities in projected character data, using hashes of actual blobs.
    const names = new Map<string, string[]>();
    for (const record of await Promise.all(records)) {
      const aliases = names.get(record.hash) ?? [];
      if (!aliases.includes(record.name)) aliases.push(record.name);
      names.set(record.hash, aliases.sort());
    }
    // Blob payload hashes can include rewritten child UUIDs. Alias sets provide
    // stable logical identities while preserving every byte-identical resource.
    const orderedAliases = [...new Set([...names.values()].map(aliases => JSON.stringify(aliases)))].sort();
    const urlMap = new Map(await Promise.all(urls.map(async ({ url, blob }) =>
      [url, names.get(await digest(await blob.arrayBuffer()))])));
    const resourceURLs: { token: string; hrefs: string[] }[] = [];
    for (const section of sections) for (const node of section.projection) {
      if (node.text === null) continue;
      for (const [url, aliases] of urlMap) {
        // Only rewrite a URL actually returned by this capture's createObjectURL.
        // Literal prose such as blob:example is source content and stays intact.
        if (!node.text.includes(url)) continue;
        if (!aliases) throw new Error('Captured resource URL lacks a provenance mapping');
        // Length-neutral tokens retain DOM UTF-16 offsets in stylesheet Text.
        const token = `oracle-resource:${String(orderedAliases.indexOf(JSON.stringify(aliases))).padStart(4, '0')}`.padEnd(url.length, '_');
        if (token.length !== url.length) throw new Error('Resource token must preserve UTF-16 length');
        if (!resourceURLs.some(item => item.token === token)) resourceURLs.push({ token, hrefs: aliases });
        node.text = node.text.split(url).join(token);
      }
    }
    const grammar = grammarInputs.map(input => {
      try { return { input, parsed: CFI.parse(input), collapsedStart: CFI.collapse(input),
        collapsedEnd: CFI.collapse(input, true) }; }
      catch (error) { return { input, error: { name: error.name } }; }
    });
    return { resourceURLs: resourceURLs.sort((a,b) => a.token.localeCompare(b.token, 'en')),
      package: { opfPath, spine: book.resources.spine.map((spine: any, sectionIndex: number) => ({
      ...spine, sectionIndex, href: book.resources.getItemByID(spine.idref)?.href,
      cfiBase: book.resources.cfis[sectionIndex],
    })), toc: book.toc ?? [], direction: book.dir, rendition: book.rendition }, sections, grammar };
  } finally {
    frames.forEach(frame => frame.remove()); book?.destroy(); URL.createObjectURL = nativeCreate;
  }
}

function unicodeTable() {
  const ranges: number[][] = [];
  let start = -1;
  for (let cp = 0; cp <= 0x110000; cp++) {
    const excluded = cp < 0x110000 && !isCanonicalCodePoint(cp);
    if (excluded && start === -1) start = cp;
    if (!excluded && start !== -1) { ranges.push([start, cp - 1]); start = -1; }
  }
  return { normalizationVersion: 1, unicodeVersion: null,
    unicodeVersionNote: 'Browser exposes no Unicode database version; engine version and full generated table pin behavior.',
    excludedRanges: ranges };
}

async function resolve(bytes: number[], cfis: string[]) {
  const { book } = await openBook(bytes);
  const frames: HTMLIFrameElement[] = [], loaded = new Map();
  try {
    const results = [];
    for (const cfi of cfis) {
      try {
        const target = book.resolveCFI(cfi);
        if (!loaded.has(target.index)) {
          const value = await loadSection(book, book.sections[target.index]);
          frames.push(value.frame); loaded.set(target.index, value.doc);
        }
        const doc = loaded.get(target.index), range = target.anchor(doc), { nodes } = project(doc);
        results.push({ cfi, sectionIndex: target.index, start: { node: nodes.indexOf(range.startContainer),
          offset: range.startOffset }, end: { node: nodes.indexOf(range.endContainer), offset: range.endOffset } });
      } catch (error) { results.push({ cfi, error: { name: error.name } }); }
    }
    return results;
  } finally { frames.forEach(frame => frame.remove()); book.destroy(); }
}

Object.assign(window, { oracle: { vectors, unicodeTable, resolve } });
