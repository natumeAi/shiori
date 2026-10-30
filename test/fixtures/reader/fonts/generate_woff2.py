"""Offline vector generator: Python stdlib + installed Brotli 1.2.0 only.

python test/fixtures/reader/fonts/generate_woff2.py
Reads the pinned SFNT, implements the forward WOFF2 glyph/metric transforms,
then invokes brotli.exe -q 11 -w 22. Never runs during tests.
"""
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
FONT = Path('tool/oracle/fixtures/styles/EPUB/fonts/Roboto-Regular.ttf')
U16 = lambda b, p=0: struct.unpack_from('>H', b, p)[0]
I16 = lambda b, p=0: struct.unpack_from('>h', b, p)[0]
U32 = lambda b, p=0: struct.unpack_from('>I', b, p)[0]
P16 = lambda n: struct.pack('>H', n & 65535)
P32 = lambda n: struct.pack('>I', n)


def uint255(n):
    return bytes([n]) if n < 253 else bytes([253]) + P16(n)


def base128(n):
    out = [n & 127]
    while n >> 7:
        n >>= 7
        out.insert(0, (n & 127) | 128)
    return bytes(out)


def transform(tables):
    count = U16(tables[b'maxp'], 4)
    fmt = I16(tables[b'head'], 50)
    loc = tables[b'loca']
    offsets = [U16(loc, i * 2) * 2 if fmt == 0 else U32(loc, i * 4)
               for i in range(count + 1)]
    streams = [bytearray() for _ in range(7)]
    bboxmap = bytearray(((count + 31) // 32) * 4)
    overlap = bytearray((count + 7) // 8)
    xmins = []
    for gid in range(count):
        g = tables[b'glyf'][offsets[gid]:offsets[gid + 1]]
        contours = I16(g) if g else 0
        streams[0] += P16(contours)
        xmins.append(I16(g, 2) if g else 0)
        if contours == 0:
            continue
        bboxmap[gid >> 3] |= 128 >> (gid & 7)
        streams[5] += g[2:10]
        p = 10
        if contours < 0:
            start = p
            instructions = False
            while True:
                flags = U16(g, p)
                p += 4 + (4 if flags & 1 else 2)
                p += 2 if flags & 8 else 4 if flags & 64 else 8 if flags & 128 else 0
                instructions |= bool(flags & 256)
                if not flags & 32:
                    break
            streams[4] += g[start:p]
            if instructions:
                n = U16(g, p)
                streams[3] += uint255(n)
                streams[6] += g[p + 2:p + 2 + n]
            continue
        previous = -1
        for i in range(contours):
            end = U16(g, p)
            p += 2
            streams[1] += uint255(end - previous)
            previous = end
        n = U16(g, p)
        p += 2
        instructions = g[p:p + n]
        p += n
        flags = []
        while len(flags) <= previous:
            flag = g[p]
            p += 1
            repeat = 1
            if flag & 8:
                repeat += g[p]
                p += 1
            flags += [flag] * repeat
        axes = []
        for short, same in [(2, 16), (4, 32)]:
            values = []
            for flag in flags:
                if flag & short:
                    v = g[p] * (1 if flag & same else -1)
                    p += 1
                elif flag & same:
                    v = 0
                else:
                    v = I16(g, p)
                    p += 2
                values.append(v)
            axes.append(values)
        for i, (dx, dy) in enumerate(zip(*axes)):
            triplet = 124 | (1 if dx >= 0 else 0) | (2 if dy >= 0 else 0)
            streams[2].append(triplet | (0 if flags[i] & 1 else 128))
            streams[3] += P16(abs(dx)) + P16(abs(dy))
        if flags[0] & 64:
            overlap[gid >> 3] |= 1 << (gid & 7)
        streams[3] += uint255(n)
        streams[6] += instructions
    streams[5] = bboxmap + streams[5]
    glyf = P16(0) + P16(1) + P16(count) + P16(fmt)
    glyf += b''.join(P32(len(s)) for s in streams) + b''.join(streams) + overlap
    metrics = U16(tables[b'hhea'], 34)
    # Roboto's bearings do not all equal xMin; retain the proportional array.
    # Its nonproportional array is empty, and may legally be omitted.
    assert metrics == count
    hmtx = bytearray([2])
    for i in range(metrics):
        hmtx += tables[b'hmtx'][i * 4:i * 4 + 2]
    for i in range(metrics):
        hmtx += tables[b'hmtx'][i * 4 + 2:i * 4 + 4]
    hmtx += tables[b'hmtx'][metrics * 4:]
    return glyf, hmtx


def main():
    sfnt = FONT.read_bytes()
    tables = {}
    for i in range(U16(sfnt, 4)):
        p = 12 + 16 * i
        start, size = U32(sfnt, p + 8), U32(sfnt, p + 12)
        tables[sfnt[p:p + 4]] = sfnt[start:start + size]
    glyph, metric = transform(tables)
    directory, stream = bytearray(), bytearray()
    order = sorted(tables)  # glyf precedes loca; all tags explicitly encoded.
    for tag in order:
        data = tables[tag]
        version = 1 if tag == b'hmtx' else 0
        transformed = tag in [b'glyf', b'loca', b'hmtx']
        encoded = glyph if tag == b'glyf' else b'' if tag == b'loca' else metric if tag == b'hmtx' else data
        directory += bytes([63 | (version << 6)]) + tag + base128(len(data))
        if transformed:
            directory += base128(len(encoded))
        stream += encoded
    with tempfile.TemporaryDirectory() as tmp:
        raw, compressed = Path(tmp) / 'font.raw', Path(tmp) / 'font.br'
        raw.write_bytes(stream)
        subprocess.run([shutil.which('brotli'), '-q', '11', '-w', '22', '-o', str(compressed), str(raw)], check=True)
        payload = compressed.read_bytes()
    header = b'wOF2' + sfnt[:4] + P32(48 + len(directory) + len(payload))
    header += P16(len(tables)) + P16(0) + P32(len(sfnt)) + P32(len(payload))
    header += bytes(24)
    (ROOT / 'roboto-transformed.woff2').write_bytes(header + directory + payload)


if __name__ == '__main__':
    main()
