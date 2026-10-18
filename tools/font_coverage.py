import struct

def cmap_characters(data):
    count = struct.unpack_from('>H', data, 4)[0]
    tables = {}
    for i in range(count):
        tag, _, offset, length = struct.unpack_from('>4sIII', data, 12 + i * 16)
        if offset + length > len(data):
            raise ValueError('Invalid sfnt table bounds')
        tables[tag] = (offset, length)
    offset, length = tables[b'cmap']
    version, num = struct.unpack_from('>HH', data, offset)
    result = set()
    for i in range(num):
        platform, encoding, relative = struct.unpack_from('>HHI', data, offset + 4 + i * 8)
        p = offset + relative
        fmt = struct.unpack_from('>H', data, p)[0]
        if platform not in (0, 3):
            continue
        if fmt == 12:
            groups = struct.unpack_from('>I', data, p + 12)[0]
            for j in range(groups):
                start, end, glyph = struct.unpack_from('>III', data, p + 16 + j * 12)
                result.update(range(start + (glyph == 0), end + 1))
        elif fmt == 4:
            segs = struct.unpack_from('>H', data, p + 6)[0] // 2
            ends = p + 14
            starts = ends + 2 * segs + 2
            deltas = starts + 2 * segs
            ranges = deltas + 2 * segs
            for j in range(segs):
                start = struct.unpack_from('>H', data, starts + 2 * j)[0]
                end = struct.unpack_from('>H', data, ends + 2 * j)[0]
                delta = struct.unpack_from('>h', data, deltas + 2 * j)[0]
                relative_range = struct.unpack_from('>H', data, ranges + 2 * j)[0]
                for char in range(start, min(end, 0xfffe) + 1):
                    if relative_range:
                        glyph_p = ranges + 2 * j + relative_range + 2 * (char - start)
                        glyph = struct.unpack_from('>H', data, glyph_p)[0]
                        if glyph:
                            glyph = (glyph + delta) & 0xffff
                    else:
                        glyph = (char + delta) & 0xffff
                    if glyph:
                        result.add(char)
    return result
