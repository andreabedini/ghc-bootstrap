#!/bin/sh
# Reproduce the whole seed chain: C compiler + Hugs source -> MicroHs,
# then verify it against MicroHs's own shipped pre-generated C.
#
# Verified 2026-09-02, Fedora 44, GCC 16.2.1, x86_64.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
MHS=${1:-$HERE/../MicroHs}
OUT=${TMPDIR:-/tmp}

# 1. Hugs from source (patches 0002 pattern guards, 0003 stack limits).
"$HERE/build-hugs.sh"
PATH=$HERE/prefix/bin:$PATH
export PATH

cd "$MHS"
git apply "$HERE/patches/0001-microhs-hugs-shim.patch" 2>/dev/null || true
make mhs.conf

# 2. Generation 1: run the MicroHs compiler *interpreted under Hugs* to emit C
#    for itself.  MAX_EVAL_DEPTH is a guard on C recursion in eval(), so the
#    process needs a matching C stack.
ulimit -s unlimited 2>/dev/null || ulimit -s 4000000
make generated/hmhs.c
make bin/hmhs                     # -> a native mhs built from Hugs alone

# 3. Generation 2 and 3: the fixpoint.
MHSDIR=$PWD ./bin/hmhs -i -imhs -isrc -ilib MicroHs.Main -o"$OUT/mhs2.c"
cc -w -O1 -Isrc/runtime -Isrc/runtime/unix \
   src/runtime/main.c src/runtime/eval.c "$OUT/mhs2.c" -lm -o "$OUT/mhs2"
MHSDIR=$PWD "$OUT/mhs2" -i -imhs -isrc -ilib MicroHs.Main -o"$OUT/mhs3.c"
cmp "$OUT/mhs2.c" "$OUT/mhs3.c" && echo "OK: fixpoint, gen2 == gen3"

# 4. Diverse double compilation: does the seed-derived compiler agree with the
#    one built from the shipped generated/mhs.c?
make bin/mhs
MHSDIR=$PWD ./bin/mhs -i -imhs -isrc -ilib MicroHs.Main -o"$OUT/mhsShipped.c"
cmp "$OUT/mhsShipped.c" "$OUT/mhs2.c" \
  && echo "OK: Hugs-derived and shipped-derived compilers agree byte for byte"
