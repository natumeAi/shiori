import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createServer } from 'node:http';
import path from 'node:path';
import { build } from 'esbuild';
import { webkit, chromium } from 'playwright';
import { root, toolRoot, assetRoot, vectorRoot, chromiumRoot, referenceCommit, foliateCommit, sha256, stableJSON,
  compactJSON } from './common.mjs';

const [command, ...arguments_] = process.argv.slice(2);
if (!['vectors', 'vectors-local', 'resolve'].includes(command)) throw new Error('Unknown oracle command');
const metadata = JSON.parse(readFileSync(path.join(toolRoot, 'package.json'), 'utf8'));
const sharedSource = readFileSync(path.join(toolRoot, 'reference/lan-reader-a4bda23/readingStats.ts'), 'utf8');
const constant = sharedSource.match(/^export const READING_TEXT_NORMALIZATION_VERSION = \d+;/m)?.[0];
if (!constant) throw new Error('Pinned shared normalization constant not found');
const output = await build({
  entryPoints: [path.join(toolRoot, 'src/browser.ts')], bundle: true, write: false,
  format: 'iife', platform: 'browser', target: 'es2022',
  plugins: [{ name: 'pinned-shared-constant', setup(plugin) {
    plugin.onResolve({ filter: /^@lan-reader\/shared$/ }, () => ({ path: 'shared', namespace: 'oracle' }));
    plugin.onLoad({ filter: /.*/, namespace: 'oracle' }, () => ({ contents: constant, loader: 'ts' }));
  } }],
});
const bundle = output.outputFiles[0].contents;
const server = createServer((request, response) => {
  if (request.url === '/') { response.setHeader('Content-Type', 'text/html'); response.end('<!doctype html><meta charset="utf-8"><script src="/oracle.js"></script>'); }
  else if (request.url === '/oracle.js') { response.setHeader('Content-Type', 'text/javascript'); response.end(bundle); }
  else { response.statusCode = 404; response.end(); }
});
await new Promise((resolve, reject) => { server.once('error', reject); server.listen(41739, '127.0.0.1', resolve); });
const origin = 'http://127.0.0.1:41739';
const engines = {};
function summarize(value) {
  if (typeof value === 'string' && value.length > 160) return { length: value.length, sha256: sha256(value), prefix: value.slice(0, 80) };
  return value === undefined ? { absent: true } : value;
}
function differences(left, right, pointer = '') {
  if (stableJSON(left) === stableJSON(right)) return [];
  if (left !== null && right !== null && typeof left === 'object' && typeof right === 'object') {
    const keys = [...new Set([...Object.keys(left), ...Object.keys(right)])].sort();
    return keys.flatMap(key => differences(left[key], right[key], `${pointer}/${key}`));
  }
  return [{ path: pointer, webkit: summarize(left), chromium: summarize(right), authoritative: 'webkit' }];
}
const localRoot = path.join(root, 'build/oracle-local');
const provenance = (name, engine, bytes) => ({
  fixtureSHA256: sha256(bytes), engineName: name, engineVersion: engine.version(),
  referenceCommit, foliateCommit, nodeVersion: process.version,
  toolVersions: metadata.devDependencies,
});

try {
  for (const [name, type] of Object.entries({ webkit, chromium })) {
    const browser = await type.launch({ headless: true, timeout: 30000 });
    const context = await browser.newContext({ viewport: { width: 430, height: 932 } });
    await context.route('**/*', route => {
      const url = route.request().url();
      return url.startsWith(origin + '/') || url.startsWith('blob:') || url.startsWith('data:')
        ? route.continue() : route.abort('blockedbyclient');
    });
    const page = await context.newPage();
    page.setDefaultTimeout(90000);
    await page.goto(origin, { waitUntil: 'load' });
    await page.waitForFunction(() => !!window.oracle);
    engines[name] = { browser, context, page, version: browser.version() };
    console.log(`${name} ${browser.version()}`);
  }
  if (command === 'resolve') {
    if (!arguments_[0]) throw new Error('resolve requires a JSON list path');
    const requests = JSON.parse(readFileSync(arguments_[0], 'utf8'));
    if (!Array.isArray(requests)) throw new Error('resolve input must be an array of {fixtureId|epubPath, cfis}');
    const results = [];
    for (const request of requests) {
      const epub = request.fixtureId ? path.join(assetRoot, `${request.fixtureId}.epub`) : request.epubPath;
      if (!epub || !Array.isArray(request.cfis)) throw new Error('Invalid resolve request');
      const bytes = [...readFileSync(epub)];
      const resolved = {};
      for (const [name, engine] of Object.entries(engines)) {
        resolved[name] = await engine.page.evaluate(({ bytes, cfis }) => window.oracle.resolve(bytes, cfis), { bytes, cfis: request.cfis });
      }
      results.push({ fixtureId: request.fixtureId ?? null, epubSHA256: sha256(Buffer.from(bytes)), results: resolved });
    }
    mkdirSync(localRoot, { recursive: true });
    writeFileSync(path.join(localRoot, 'resolve-results.json'), stableJSON({ oracleSchemaVersion: 1, results }));
    console.log(`Resolved ${results.length} request groups into build/oracle-local/resolve-results.json`);
  } else {
    const local = command === 'vectors-local';
    if (local && !arguments_.length) throw new Error('vectors-local requires EPUB paths (read in place)');
    const fixtures = local ? arguments_.map(file => ({ file, id: sha256(readFileSync(file)) }))
      : JSON.parse(readFileSync(path.join(assetRoot, 'manifest.json'), 'utf8')).fixtures
        .map(item => ({ file: path.join(assetRoot, item.file), id: item.id }));
    const destination = local ? localRoot : vectorRoot;
    // Only the authoritative WebKit vectors are committed; the Chromium
    // cross-check is summarized in cross-engine-differences.json.
    const engineDestination = name => local || name === 'webkit' ? destination : chromiumRoot;
    mkdirSync(destination, { recursive: true });
    if (!local) mkdirSync(chromiumRoot, { recursive: true });
    const allDifferences = [];
    const summary = [];
    for (const fixture of fixtures) {
      const bytes = readFileSync(fixture.file), results = {};
      for (const [name, engine] of Object.entries(engines)) {
        const result = await engine.page.evaluate(bytes => window.oracle.vectors(bytes), [...bytes]);
        results[name] = result;
        const vector = { oracleSchemaVersion: 1, fixtureId: fixture.id,
          provenance: provenance(name, engine.browser, bytes), ...result };
        writeFileSync(path.join(engineDestination(name), `${fixture.id}.${name}.json`), compactJSON(vector));
        console.log(`${fixture.id} ${name}: ${result.sections.length} sections`);
      }
      const diff = differences(results.webkit, results.chromium);
      allDifferences.push({ fixtureId: fixture.id, differences: diff });
      summary.push({ id: fixture.id, sha256: sha256(bytes), sections: results.webkit.sections.length,
        samples: results.webkit.sections.reduce((sum, section) => sum + section.samples.length, 0), differences: diff.length });
    }
    const unicode = {};
    for (const [name, engine] of Object.entries(engines)) {
      unicode[name] = { oracleSchemaVersion: 1, engineName: name, engineVersion: engine.version,
        ...await engine.page.evaluate(() => window.oracle.unicodeTable()) };
    }
    writeFileSync(path.join(destination, 'unicode-table.json'), stableJSON(unicode));
    writeFileSync(path.join(destination, 'cross-engine-differences.json'), stableJSON({ oracleSchemaVersion: 1,
      authoritativeEngine: 'webkit', fixtures: allDifferences,
      unicodeTableDifferences: differences(unicode.webkit.excludedRanges, unicode.chromium.excludedRanges) }));
    writeFileSync(path.join(destination, 'summary.json'), stableJSON({ oracleSchemaVersion: 1,
      engines: Object.fromEntries(Object.entries(engines).map(([name, engine]) => [name, engine.version])), fixtures: summary }));
  }
} finally {
  for (const engine of Object.values(engines)) await engine.browser.close();
  await new Promise(resolve => server.close(resolve));
}
