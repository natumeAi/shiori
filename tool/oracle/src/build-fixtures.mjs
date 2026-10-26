import { readFileSync, writeFileSync, mkdirSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { zipSync, strToU8, zlibSync } from 'fflate';
import { assetRoot, fixtureRoot, sha256, stableJSON } from './common.mjs';

const esc = value => value.replaceAll('&', '&amp;').replaceAll('"', '&quot;').replaceAll('<', '&lt;');
const crc32 = data => {
  let crc = 0xffffffff;
  for (const byte of data) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
};
const chunk = (type, data) => {
  const bytes = Buffer.concat([Buffer.from(type), data]);
  const length = Buffer.alloc(4), crc = Buffer.alloc(4);
  length.writeUInt32BE(data.length); crc.writeUInt32BE(crc32(bytes));
  return Buffer.concat([length, bytes, crc]);
};
function raster() {
  const width = 64, height = 96, ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0); ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; ihdr[9] = 6;
  const rows = [];
  for (let y = 0; y < height; y++) {
    const row = Buffer.alloc(1 + width * 4);
    for (let x = 0; x < width; x++) row.set([x * 4, y * 2, 160, 255], 1 + 4 * x);
    rows.push(row);
  }
  return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]), chunk('IHDR', ihdr),
    chunk('IDAT', Buffer.from(zlibSync(Buffer.concat(rows)))), chunk('IEND', Buffer.alloc(0))]);
}
const fillers = {
  '{{LONG_CHAPTER}}': Array.from({ length: 360 }, (_, i) =>
    `<p id="paragraph-${i}">第${String(i).padStart(5, '0')}段。${'原生阅读测试，逐字守恒，翻页仍在同一内容位置。'.repeat(18)}</p>`).join('\n'),
  '{{LONG_CJK}}': '原生阅读逐字映射'.repeat(12500),
  '{{LONG_LATIN}}': 'abcdefghijklmnopqrstuvwxyz'.repeat(500),
};
function expand(text) {
  for (const [token, value] of Object.entries(fillers)) text = text.replaceAll(token, value);
  return text;
}
function sourceFiles(directory, prefix = '') {
  const output = {};
  for (const entry of readdirSync(directory, { withFileTypes: true }).sort((a,b) => a.name.localeCompare(b.name, 'en'))) {
    const name = prefix + entry.name;
    if (entry.isDirectory()) Object.assign(output, sourceFiles(path.join(directory, entry.name), name + '/'));
    else if (name !== 'fixture.json' && !name.endsWith('.md') && !name.endsWith('.txt')) {
      const raw = readFileSync(path.join(directory, entry.name));
      output[name] = /\.(xhtml|html|xml|css|svg|opf|ncx)$/.test(name) ? strToU8(expand(raw.toString('utf8'))) : raw;
    }
  }
  return output;
}
// zipSync's object input coalesces names. Assemble its single-entry records
// instead, preserving its normal headers (including the first stored mimetype).
// Existing fixtures still use the original zipSync call below, byte for byte.
function zipWithRawEntries(entries, rawEntries) {
  for (const entry of rawEntries) {
    if (entry.name === 'mimetype' || !Object.hasOwn(entries, entry.name) || typeof entry.text !== 'string') {
      throw new Error('Raw entries must repeat an existing non-mimetype name with UTF-8 text');
    }
  }
  const local = [], central = [];
  let offset = 0, count = 0;
  for (const [name, [data, options]] of Object.entries(entries)) {
    const copies = [...rawEntries.filter(entry => entry.name === name).map(entry => strToU8(entry.text)), data];
    for (const copy of copies) {
      const single = Buffer.from(zipSync({ [name]: [copy, options] }));
      const start = single.readUInt32LE(single.length - 6);
      const header = Buffer.from(single.subarray(start, single.length - 22));
      header.writeUInt32LE(offset, 42);
      local.push(single.subarray(0, start));
      central.push(header);
      offset += start;
      count++;
    }
  }
  const directory = Buffer.concat(central);
  const end = Buffer.from(zipSync({}));
  end.writeUInt16LE(count, 8);
  end.writeUInt16LE(count, 10);
  end.writeUInt32LE(directory.length, 12);
  end.writeUInt32LE(offset, 16);
  return Buffer.concat([...local, directory, end]);
}
mkdirSync(assetRoot, { recursive: true });
const manifest = [];
for (const id of readdirSync(fixtureRoot).sort()) {
  const directory = path.join(fixtureRoot, id);
  const spec = JSON.parse(readFileSync(path.join(directory, 'fixture.json'), 'utf8'));
  const opfPath = spec.opfPath ?? 'EPUB/package.opf';
  const base = path.posix.dirname(opfPath);
  const files = sourceFiles(directory);
  if (spec.raster) files[`${base}/images/generated.png`] = raster();
  const sections = spec.sections;
  const resources = [...sections, ...(spec.resources ?? [])];
  if (!spec.ncxOnly) resources.push({ id: 'navigation', href: 'nav.xhtml', mediaType: 'application/xhtml+xml', properties: 'nav' });
  resources.push({ id: 'ncx', href: 'toc.ncx', mediaType: 'application/x-dtbncx+xml' });
  const items = resources.map(item => `<item id="${esc(item.id)}" href="${esc(item.href)}" media-type="${item.mediaType ?? 'application/xhtml+xml'}"${item.properties ? ` properties="${item.properties}"` : ''}/>`).join('');
  const spine = `<spine toc="ncx"${spec.direction ? ` page-progression-direction="${spec.direction}"` : ''}>${sections.map(item => `<itemref id="ref-${item.id}" idref="${item.id}"${item.linear ? ` linear="${item.linear}"` : ''}/>`).join('')}</spine>`;
  files[opfPath] = strToU8(`<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="uid">urn:shiori:fixture:${id}:1</dc:identifier><dc:title>Shiori synthetic ${id}</dc:title><dc:language>zh</dc:language>${spec.fixed ? '<meta property="rendition:layout">pre-paginated</meta>' : ''}</metadata><manifest>${items}</manifest>${spec.spineAtEight ? '<guide/>' : ''}${spine}</package>`);
  const tocTree = sections.map((item, index) => ({ item, index, children: [] }));
  if (spec.nestedToc && tocTree.length > 1) tocTree[0].children.push(tocTree.splice(1, 1)[0]);
  const navList = nodes => nodes.map(({ item, children }) => `<li><a href="${esc(item.href)}">${esc(item.id)}</a>${children.length ? `<ol>${navList(children)}</ol>` : ''}</li>`).join('');
  const ncxList = nodes => nodes.map(({ item, index, children }) => `<navPoint id="n${index}" playOrder="${index+1}"><navLabel><text>${esc(item.id)}</text></navLabel><content src="${esc(item.href)}"/>${ncxList(children)}</navPoint>`).join('');
  if (!spec.ncxOnly) files[`${base}/nav.xhtml`] = strToU8(`<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>Navigation</title></head><body><nav epub:type="toc"><ol>${navList(tocTree)}</ol></nav></body></html>`);
  files[`${base}/toc.ncx`] = strToU8(`<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><head/><docTitle><text>Synthetic</text></docTitle><navMap>${ncxList(tocTree)}</navMap></ncx>`);
  files['META-INF/container.xml'] = strToU8(`<?xml version="1.0"?><container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0"><rootfiles><rootfile full-path="${opfPath}" media-type="application/oebps-package+xml"/></rootfiles></container>`);
  // ZIP DOS fields use local-time getters in fflate. A fixed local calendar
  // date keeps archive bytes identical across host timezones.
  const entries = { mimetype: [strToU8('application/epub+zip'), { level: 0, mtime: new Date(2000, 0, 1, 0, 0, 0) }] };
  for (const name of Object.keys(files).sort()) entries[name] = [files[name], { level: 0, mtime: new Date(2000, 0, 1, 0, 0, 0) }];
  const bytes = spec.rawEntries?.length ? zipWithRawEntries(entries, spec.rawEntries) : zipSync(entries);
  writeFileSync(path.join(assetRoot, `${id}.epub`), bytes);
  manifest.push({ id, file: `${id}.epub`, sha256: sha256(bytes), bytes: bytes.length, source: `tool/oracle/fixtures/${id}` });
  console.log(`${id}: ${bytes.length} bytes`);
}
writeFileSync(path.join(assetRoot, 'manifest.json'), stableJSON({ fixtureSchemaVersion: 1, fixtures: manifest }));
