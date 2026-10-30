"""Generate bit-level RFC 7932 dictionary references; native Brotli is oracle.

python test/fixtures/reader/fonts/generate_dictionary_vectors.py
The decoder's transform triples are used only to predict stream output length.
Expected bytes come exclusively from brotli.exe --decompress (Brotli 1.2.0).
Every transform 0..120 is explicitly referenced at dictionary length 24.
"""
from pathlib import Path
import json
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent


class Bits:
    def __init__(self):
        self.values = []

    def add(self, value, count):
        self.values += [(value >> i) & 1 for i in range(count)]

    def finish(self):
        self.values += [0] * ((-len(self.values)) % 8)
        return bytes(sum(self.values[i + j] << j for j in range(8))
                     for i in range(0, len(self.values), 8))


def stream(transform, length):
    b = Bits()
    b.add(0, 1)  # WBITS=16
    b.add(1, 1)  # ISLAST
    b.add(0, 1)  # not empty
    b.add(0, 2)  # MNIBBLES=4
    b.add(length - 1, 16)
    for _ in range(3):
        b.add(0, 1)  # one block type
    b.add(0, 2)  # NPOSTFIX
    b.add(0, 4)  # NDIRECT
    b.add(0, 2)  # literal context LSB6
    b.add(0, 1)  # literal tree count=1
    b.add(0, 1)  # distance tree count=1
    b.add(1, 2); b.add(0, 2); b.add(0, 8)  # single unused literal
    # Command code 196: insert 0, copy base 22 + 2 = 24.
    b.add(1, 2); b.add(0, 2); b.add(196, 10)
    distance = (transform << 5) + 1  # 32 length-24 dictionary words
    for code in range(16, 64):
        c = code - 16
        n = 1 + (c >> 1)
        base = ((2 + (c & 1)) << n) - 4 + 1
        if base <= distance < base + (1 << n):
            extra = distance - base
            break
    else:
        raise ValueError(distance)
    b.add(1, 2); b.add(0, 2); b.add(code, 6)  # distance alphabet=64
    b.add(2, 3)  # copy length extra (copy code 12)
    b.add(extra, n)
    return b.finish()


def main():
    text = Path('lib/features/reader/engine/layout/brotli_dictionary.dart').read_text()
    triples = list(map(int, re.findall(r'\d+', text.split('const _transformData = <int>[')[1].split('];')[0])))
    # Lengths of the RFC 7932 affixes (UTF-8, including the two-byte NBSP).
    affixes = [' ', ', ', ' of the ', ' of ', 's ', '.', ' and ', ' in ', '"', ' to ',
               '">', '\n', '. ', ']', ' for ', ' a ', ' that ', "'", ' with ', ' from ',
               ' by ', '(', '. The ', ' on ', ' as ', ' is ', 'ing ', '\n\t', ':', 'ed ',
               '="', ' at ', 'ly ', ',', "='", '.com/', '. This ', ' not ', 'er ',
               'al ', 'ful ', 'ive ', 'less ', 'est ', 'ize ', '\u00a0', 'ous ', ' the ', 'e ', '']
    vectors = []
    with tempfile.TemporaryDirectory() as tmp:
        encoded, raw = Path(tmp) / 'word.br', Path(tmp) / 'word.raw'
        for transform in range(121):
            prefix, kind, suffix = triples[transform * 3:transform * 3 + 3]
            omit = kind - 2 if 3 <= kind <= 11 else kind - 11 if kind >= 12 else 0
            size = 24 - omit + len(affixes[prefix].encode()) + len(affixes[suffix].encode())
            compressed = stream(transform, size)
            encoded.write_bytes(compressed)
            subprocess.run([shutil.which('brotli'), '-d', '-f', '-o', str(raw), str(encoded)], check=True)
            vectors.append({'transform': transform, 'br': compressed.hex(), 'output': raw.read_bytes().hex()})
    (ROOT / 'dictionary-transforms.json').write_text(json.dumps(vectors, indent=2) + '\n')


if __name__ == '__main__':
    main()
