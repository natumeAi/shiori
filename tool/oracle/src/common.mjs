import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

export const root = path.resolve(fileURLToPath(new URL('../../../', import.meta.url)));
export const toolRoot = path.join(root, 'tool/oracle');
export const fixtureRoot = path.join(toolRoot, 'fixtures');
export const assetRoot = path.join(root, 'assets/reader_fixtures');
export const vectorRoot = path.join(root, 'test/fixtures/reader/oracle');
// Cross-check engine output is compared, not committed; build/ is gitignored.
export const chromiumRoot = path.join(root, 'build/oracle-chromium');
export const referenceCommit = 'a4bda23fd3e82e285a22566d88576e67d3e8756b';
export const foliateCommit = '78914aef4466eb960965702401634c2cb348e9b1';
export const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
export const sorted = value => Array.isArray(value) ? value.map(sorted)
  : value !== null && typeof value === 'object'
    ? Object.fromEntries(Object.keys(value).sort().map(key => [key, sorted(value[key])]))
    : value;
export const stableJSON = value => JSON.stringify(sorted(value), null, 2) + '\n';

// Same sorted JSON as stableJSON, laid out for size: a value whose one-line
// form fits in `width` stays on one line, and longer arrays of primitives wrap
// several items per line instead of one item per line.
const width = 120;
const primitive = value => value === null || typeof value !== 'object';
const layout = (value, indent, prefix) => {
  const flat = JSON.stringify(value);
  if (primitive(value) || indent.length + prefix + flat.length <= width) return flat;
  const inner = indent + '  ';
  if (Array.isArray(value) && value.length && value.every(primitive)) {
    const lines = [];
    let line = [];
    for (const token of value.map(item => JSON.stringify(item))) {
      if (line.length && inner.length + [...line, token].join(', ').length + 1 > width) {
        lines.push(line.join(', '));
        line = [];
      }
      line.push(token);
    }
    lines.push(line.join(', '));
    return `[\n${inner}${lines.join(`,\n${inner}`)}\n${indent}]`;
  }
  if (Array.isArray(value)) return `[\n${value.map(item => inner + layout(item, inner, 0)).join(',\n')}\n${indent}]`;
  return `{\n${Object.keys(value).map(key => {
    const label = `${JSON.stringify(key)}: `;
    return inner + label + layout(value[key], inner, label.length);
  }).join(',\n')}\n${indent}}`;
};
// The round trip applies JSON.stringify's own rules first (undefined members
// dropped, NaN to null, toJSON), so the content always equals stableJSON's.
export const compactJSON = value => layout(JSON.parse(JSON.stringify(sorted(value))), '', 0) + '\n';
