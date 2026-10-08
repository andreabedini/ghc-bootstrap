#!/bin/sh
# Compile GHC 4.08.2's runtime system.
#
# The RTS is plain C, so it needs no bootstrapped compiler -- but it does need
# the same view of the world as the .hc files the Prelude produced, which means
# the same NO_REGS / USE_MINIINTERPRETER unregisterised settings and the same
# generated config.h.
#
# Sources: ghc/rts/*.c plus hooks/*.c, per ghc/rts/Makefile's SRCS_RTS_C.
# parallel/ is for the "mp" way and is skipped; RtsDllMain.c is Windows-only
# and Main.c is filtered out only in the dll way, so it stays.
#
# GMP: ghc/rts/Makefile builds its bundled 1999 copy only when HaveLibGmp is not
# YES. configure decided "No", but only because AC_CHECK_LIB declares
# `char mpz_fdiv_qr();' and links against it, while in modern GMP that name is a
# macro for __gmpz_fdiv_qr -- so the probe cannot succeed on any current
# library. The system GMP is fine (verified by compiling a real mpz_fdiv_qr
# call), so this takes the HaveLibGmp=YES path and links -lgmp.
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
G="$R/build/ghc-4.08.2"
OUT="$R/build/ghc-mhs/rts"

mkdir -p "$OUT"
ok=0; fail=0; failed=""
for src in "$G"/ghc/rts/*.c "$G"/ghc/rts/hooks/*.c; do
  base=$(basename "$src" .c)
  case "$base" in
    RtsDllMain) continue ;;          # Windows DLL entry point
  esac
  if cc -c -w -std=gnu89 -O -DNO_REGS -DUSE_MINIINTERPRETER \
        -I"$G/ghc/includes" -I"$G/ghc/rts" \
        "$src" -o "$OUT/$base.o" 2> "$OUT/$base.log"; then
    ok=$((ok + 1))
  else
    fail=$((fail + 1)); failed="$failed $base"
    printf '%-20s FAILED: %s\n' "$base" \
      "$(rg 'error' "$OUT/$base.log" 2>/dev/null | head -1 | cut -c1-100)"
  fi
done
# ghc/rts/Makefile also lists SRCS_RTS_HC: seven hand-written Abstract C files
# holding the STG machinery itself -- the info tables and entry code for
# thunks, updates, blackholes, stack checks and the primops that are too
# involved to inline. They are compiled exactly like the .hc that hsc emits.
for src in "$G"/ghc/rts/*.hc; do
  base=$(basename "$src" .hc)
  if cc -c -x c -w -std=gnu89 -O -DNO_REGS -DUSE_MINIINTERPRETER \
        -I"$G/ghc/includes" -I"$G/ghc/rts" \
        -include "$G/ghc/includes/Stg.h" \
        "$src" -o "$OUT/$base.o" 2> "$OUT/$base.log"; then
    ok=$((ok + 1))
  else
    fail=$((fail + 1)); failed="$failed $base"
    printf '%-20s FAILED: %s\n' "$base" \
      "$(rg 'error' "$OUT/$base.log" 2>/dev/null | head -1 | cut -c1-100)"
  fi
done

# universal_call_c.S is i386 assembly for the bytecode interpreter's foreign
# calls; ForeignCall.c is its only user and this build has no interpreter.

echo "rts: compiled $ok, failed $fail"
[ -n "$failed" ] && echo "failed:$failed"
exit 0
