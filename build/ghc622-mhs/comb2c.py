#!/usr/bin/env python3
"""Turn a mhs .comb file into the C file `mhs -o x.c` would have written.

`mhs -o out.c` = "#include \"mhsffi.h\"" ++ makeCArray outData ++ makeFFI ...,
and `mhs -o out.comb` writes exactly the same outData (MicroHs/src/MicroHs/
Main.hs:391 vs 404-410, MakeCArray.hs). So the byte array below is identical to
what the .c route emits; only the FFI table has to be supplied, and for this
program it is four entries (ffi.c) -- every other name the closure imports is
already in the runtime's own ffi_table (eval.c:7861).

Why not just run `mhs -o ghc.c`: it needs ~13 min in one process and the
sandbox kills a foreground command at 10. The .comb comes out at 9 min.

  python3 comb2c.py ghc.comb ghc-data.c
"""
import sys
src, dst = sys.argv[1], sys.argv[2]
data = open(src, "rb").read()
with open(dst, "w") as f:
    f.write('#include "mhsffi.h"\n')
    f.write("static const unsigned char data[] = {\n")
    for i in range(0, len(data), 20):
        f.write(",".join(str(b) for b in data[i:i+20]) + ",\n")
    f.write("};\n")
    f.write("const unsigned char *combexpr = data;\n")
    f.write("const int combexprlen = %d;\n" % len(data))
