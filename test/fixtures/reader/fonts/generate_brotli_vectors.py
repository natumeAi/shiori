"""Offline synthetic Brotli vectors, stdlib plus brotli.exe 1.2.0.

python test/fixtures/reader/fonts/generate_brotli_vectors.py
Tests read committed vectors and never invoke the executable.
"""
from pathlib import Path
import hashlib
import json
import random
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
from generate_dictionary_vectors import Bits

ROOT = Path(__file__).resolve().parent
DICTIONARY = (
    'time down life left back code data show only site city open just like '
    'free work text year over body love form book play live line help home '
    'side more word long them view find page days full head term each area '
    'from true mark able upon high date land news even next case both post '
    'used made hand here what name. The quick brown fox jumps over the lazy '
    'dog. THE QUICK BROWN FOX. Compression and transformation of the information. ')
MIXED = 'Hello, world! \u039a\u03b1\u03bb\u03b7\u03bc\u03ad\u03c1\u03b1 \u4e16\u754c caf\u00e9 \u2014 Brotli dictionary and context models.\n'


def align(b):
    b.add(0, (-len(b.values)) % 8)


def single(b, symbol, width):
    b.add(1, 2); b.add(0, 2); b.add(symbol, width)


def prefix_regression(single_code):
    b = Bits()
    b.add(0, 1); b.add(1, 1); b.add(0, 1)
    b.add(0, 2); b.add(0, 16)  # one output byte
    for _ in range(3):
        b.add(0, 1)
    b.add(0, 2); b.add(0, 4); b.add(0, 2); b.add(0, 1); b.add(0, 1)
    single(b, 65, 8)  # literal A
    single(b, 136, 10)  # insert 1, copy 2; copy unused at meta-block end
    b.add(3, 2)  # HSKIP=3
    b.add(7, 4)  # CL symbol 4 has length 1
    if single_code:
        for _ in range(14):
            b.add(0, 2)  # remaining CL symbols all zero; no early stop
    else:
        b.add(7, 4)  # CL symbol 0 has length 1; space reaches 0 here
        b.add(65535, 16)  # sixteen code lengths 4; unused symbols implicit 0
    return b.finish()


def metadata():
    b = Bits()
    b.add(0, 1)  # window16
    b.add(0, 1); b.add(3, 2); b.add(0, 1)
    b.add(1, 2); b.add(3, 8)  # 4 metadata bytes
    align(b)
    for c in b'meta':
        b.add(c, 8)
    b.add(0, 1); b.add(0, 2); b.add(2, 16); b.add(1, 1)
    align(b)
    for c in b'raw':
        b.add(c, 8)
    b.add(1, 1); b.add(1, 1)  # final empty block
    return b.finish()


def main():
    inputs = {'dictionary': DICTIONARY.encode(), 'repeat': bytes(range(256)) * 64,
              'mixed': (MIXED * 600).encode(), 'random': random.Random(7932).randbytes(8192)}
    vectors, structural = [], []
    exe = shutil.which('brotli')
    with tempfile.TemporaryDirectory() as tmp:
        raw, compressed = Path(tmp) / 'input', Path(tmp) / 'input.br'
        for kind, data in inputs.items():
            raw.write_bytes(data)
            settings = [(0, 10), (1, 16), (4, 18), (6, 20), (9, 22), (11, 24)]
            if kind == 'repeat':
                settings += [(5, w) for w in range(10, 25)]
            for q, w in settings:
                name = f'{kind}-q{q}-w{w}.br'
                subprocess.run([exe, '-f', '-q', str(q), '-w', str(w), '-o', str(ROOT / name), str(raw)], check=True)
                vectors.append({'file': name, 'kind': kind, 'size': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
        for name, data in [('hskip3-space', prefix_regression(False)),
                           ('hskip3-single', prefix_regression(True)),
                           ('metadata-uncompressed', metadata())]:
            compressed.write_bytes(data)
            subprocess.run([exe, '-d', '-f', '-o', str(raw), str(compressed)], check=True)
            structural.append({'name': name, 'br': data.hex(), 'output': raw.read_bytes().hex()})
    (ROOT / 'random.bin').write_bytes(inputs['random'])
    (ROOT / 'brotli-vectors.json').write_text(json.dumps(vectors, indent=2) + '\n')
    (ROOT / 'brotli-structure.json').write_text(json.dumps(structural, indent=2) + '\n')


if __name__ == '__main__':
    main()
