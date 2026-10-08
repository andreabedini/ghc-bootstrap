#!/bin/sh
# Compile ghc/lib/std/cbits -- the C support for the Prelude's foreign calls
# (file and directory I/O, time, signals, errno). This becomes libHSstd_cbits,
# which ghc.lprl:1161 links alongside libHSstd.
#
# Flags from ghc/lib/std/cbits/Makefile:
#     SRC_CC_OPTS += -O -I$(GHC_INCLUDE_DIR) -I$(GHC_RUNTIME_DIR) -Wall
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
G="$R/build/ghc-4.08.2"
OUT="$R/build/ghc-mhs/cbits"

mkdir -p "$OUT"
ok=0; fail=0; failed=""
# hslibs/lang has one cbits file of its own, PackedString.c, holding
# byteArrayHasNUL__ and friends -- referenced by PackedString.hc and defined
# nowhere else.
for src in "$G"/ghc/lib/std/cbits/*.c "$G"/hslibs/lang/cbits/*.c; do
  base=$(basename "$src" .c)
  if cc -c -w -std=gnu89 -O -DNO_REGS -DUSE_MINIINTERPRETER \
        -I"$G/ghc/includes" -I"$G/ghc/rts" -I"$G/ghc/lib/std/cbits" \
        -I"$G/hslibs/lang/cbits" \
        "$src" -o "$OUT/$base.o" 2> "$OUT/$base.log"; then
    ok=$((ok + 1))
  else
    fail=$((fail + 1)); failed="$failed $base"
    printf '%-20s FAILED: %s\n' "$base" \
      "$(rg 'error' "$OUT/$base.log" 2>/dev/null | head -1 | cut -c1-100)"
  fi
done
echo "cbits: compiled $ok, failed $fail"
[ -n "$failed" ] && echo "failed:$failed"
exit 0
