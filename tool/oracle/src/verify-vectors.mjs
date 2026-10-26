import assert from 'node:assert/strict';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { unzipSync, strFromU8 } from 'fflate';
import { assetRoot, vectorRoot, chromiumRoot } from './common.mjs';

const read = (name, directory = vectorRoot) => JSON.parse(readFileSync(path.join(directory, name), 'utf8'));
assert.ok(!readdirSync(vectorRoot).some(name => name.endsWith('.chromium.json')),
  'Chromium vectors are a local cross-check and must not be committed');
// Full Chromium output exists only after `npm run vectors` in this checkout.
const engines = existsSync(chromiumRoot) ? ['webkit', 'chromium'] : ['webkit'];
const manifest = JSON.parse(readFileSync(path.join(assetRoot, 'manifest.json'), 'utf8'));
const expected = ['cfi-structure','chapters','duplicate-entries','html-fallback','images','inert-content','long-content',
  'one-page','opf-variants','styles','unicode','unsupported-fixed','unsupported-rtl','unsupported-vertical'];
assert.deepEqual(manifest.fixtures.map(item => item.id), expected);
let sections = 0, samples = 0;
for (const fixture of manifest.fixtures) {
  for (const engine of engines) {
    const vector = read(`${fixture.id}.${engine}.json`, engine === 'webkit' ? vectorRoot : chromiumRoot);
    assert.equal(vector.provenance.fixtureSHA256, fixture.sha256);
    assert.equal(vector.oracleSchemaVersion, 1);
    for (const section of vector.sections) {
      assert.ok(section.projection.length > 0);
      for (const sample of section.samples) {
        assert.equal(sample.resolvedSection, vector.package.spine.findIndex(item => item.href === section.href));
        for (const point of [sample.input.start, sample.input.end, sample.resolved.start, sample.resolved.end]) {
          const node = section.projection[point.node];
          assert.ok(node, 'CFI endpoint belongs to projected document');
          if (node.text !== null) assert.ok(point.offset <= node.text.length, 'UTF-16 offset fits normalized text');
        }
      }
      for (const entry of section.canonical.entries) {
        assert.equal(entry.canonicalToUtf16.length, entry.length);
        assert.ok(entry.canonicalToUtf16.every((offset,index,array) => index === 0 || offset > array[index-1]));
      }
      if (engine === 'webkit') { sections++; samples += section.samples.length; }
    }
    if (fixture.id === 'cfi-structure') {
      assert.ok(vector.sections[0].projection.some(node => node.text?.includes('blob:example')));
      assert.ok(vector.sections[0].projection.some(node => node.text?.includes('blob:cdata-example')));
      assert.ok(vector.sections[0].projection.some(node => node.text?.includes('blob:comment-example')));
      assert.ok(vector.sections[0].samples.some(sample => sample.input.start.node !== sample.resolved.start.node));
    }
    if (fixture.id === 'styles') {
      assert.ok(vector.resourceURLs.length > 0, 'Inline stylesheet exercises Blob normalization');
      assert.ok(vector.resourceURLs.some(item => item.hrefs.includes('EPUB/fonts/Roboto-Regular.ttf')
        && item.hrefs.includes('EPUB/fonts/Roboto-Copy.ttf')), 'Byte-identical href aliases are retained');
    }
    if (fixture.id === 'opf-variants' || fixture.id === 'chapters') {
      assert.ok(vector.package.toc[0].subitems?.length > 0, 'Nested navigation is retained');
    }
    if (fixture.id === 'opf-variants') {
      assert.ok(vector.package.spine.every(item => item.cfiBase.startsWith('epubcfi(/8/')));
      assert.equal(vector.package.spine[1].linear, 'no');
    }
  }
}
const opf = unzipSync(readFileSync(path.join(assetRoot, 'opf-variants.epub')));
assert.ok(!strFromU8(opf['OPS/Package/book.opf']).includes('properties="nav"'), 'NCX-only fixture bypasses nav path');
const cross = read('cross-engine-differences.json');
assert.ok(cross.fixtures.every(item => item.differences.length === 0));
assert.equal(cross.unicodeTableDifferences.length, 0);
console.log(`PASS ${manifest.fixtures.length} EPUBs; ${sections} sections; ${samples} CFI samples per engine; engines checked: ${engines.join(', ')}; nested nav/NCX, literal Blob prose and resource aliases verified.`);
