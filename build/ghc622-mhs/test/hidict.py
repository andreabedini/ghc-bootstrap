#!/usr/bin/env python3
"""Decode the FastString dictionary of a GHC 6.2.2 .hi (64-bit Int) in the
pristine format: magic, dict ptr (Int), at dict: count (Int), then per entry
Int length + Latin-1 bytes. Prints the first N entries or the first error.
    hidict.py FILE.hi [N] [Module.Name]   -- with a name, entry 0 must be its z-encoding"""
import struct, sys
p = sys.argv[1]; n = int(sys.argv[2]) if len(sys.argv) > 2 else 8
want = sys.argv[3] if len(sys.argv) > 3 else None   # module name the file must be for
def zenc(m):
    return "".join({".": "zi", "z": "zz", "Z": "ZZ", "_": "zu"}.get(c, c) for c in m)
b = open(p, 'rb').read()
magic, = struct.unpack('>I', b[:4]); dp, = struct.unpack('>q', b[4:12])
print(f"{p}: {len(b)} bytes, magic 0x{magic:x}, dict at 0x{dp:x}")
if dp <= 0 or dp >= len(b): sys.exit("bad dict pointer")
cnt, = struct.unpack('>q', b[dp:dp+8]); off = dp + 8
print(f"  {cnt} entries")
for i in range(cnt):
    if off + 8 > len(b): sys.exit(f"  entry {i}: truncated at 0x{off:x}")
    l, = struct.unpack('>q', b[off:off+8]); off += 8
    if l < 0 or off + l > len(b): sys.exit(f"  entry {i}: bad length {l} at 0x{off-8:x}")
    s = b[off:off+l].decode('latin-1'); off += l
    if i < n: print(f"  [{i}] {l:3d} {s!r}")
    if i == 0 and want is not None and s != zenc(want):
        sys.exit(f"  entry 0 is {s!r}: this is not {want}'s interface (parallel compiles shared a temp file?)")
print(f"  dictionary ends at 0x{off:x} of 0x{len(b):x}; all {cnt} lengths sane")
