import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { referenceCommit, sha256, toolRoot } from './common.mjs';

const reference = process.env.LAN_READER_DIR ?? 'D:/Projects/lan-reader';
const directory = path.join(toolRoot, 'reference/lan-reader-a4bda23');
const manifest = JSON.parse(readFileSync(path.join(directory, 'provenance.json'), 'utf8'));
for (const item of manifest) {
  const original = execFileSync('git', ['-C', reference, 'show', `${referenceCommit}:${item.source}`],
    { timeout: 30000 });
  const vendored = readFileSync(path.join(directory, item.file)).subarray(item.headerBytes);
  if (item.commit !== referenceCommit || !original.equals(vendored)
      || sha256(original) !== item.sha256) throw new Error(`Reference drift: ${item.source}`);
  console.log(`PASS ${item.source} ${item.sha256}`);
}
