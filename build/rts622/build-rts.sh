#!/bin/sh
# Compile GHC 6.2.2's runtime system unregisterised on x86-64, without a GHC.
#
# Mirrors ghc/rts/Makefile: SRCS = *.c in ., hooks/, parallel/ (ALL_DIRS),
# minus EXCLUDED_SRCS (RtsDllMain.c, parallel/SysMan.c, Vis*.c when there is
# no GTK front panel), plus the hand-written .hc files (HC_SRCS).
# Flags: STANDARD_OPTS (-I../includes -I. -Iparallel -DCOMPILING_RTS),
# mk/bootstrap.mk's BootingFromUnregisterisedHc adds -DNO_REGS
# -DUSE_MINIINTERPRETER, the driver adds -D__GLASGOW_HASKELL__=622.
# -std=gnu89 -O: Stable.h uses GNU89 `extern inline' (see DECISIONS.md D41).
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"/build/rts622
G="$R/ghc-6.2.2"
OUT="$R/obj"
CC=${CC:-gcc}
COMMON="-std=gnu89 -O -w -fmax-errors=100 -DNO_REGS -DUSE_MINIINTERPRETER -DCOMPILING_RTS -D__GLASGOW_HASKELL__=622 -I$G/ghc/includes -I$G/ghc/rts -I$G/ghc/rts/parallel"

mkdir -p "$OUT"
rm -f "$OUT"/*.o "$OUT"/*.log
ok=0; fail=0; failed=""
for src in "$G"/ghc/rts/*.c "$G"/ghc/rts/hooks/*.c "$G"/ghc/rts/parallel/*.c; do
  base=$(basename "$src" .c)
  case "$base" in
    RtsDllMain|SysMan|Vis*) continue ;;
  esac
  if $CC -c $COMMON "$src" -o "$OUT/$base.o" 2> "$OUT/$base.log"; then
    ok=$((ok + 1))
  else
    fail=$((fail + 1)); failed="$failed $base"
    printf '%-20s FAILED: %s\n' "$base" \
      "$(grep 'error' "$OUT/$base.log" | head -1 | cut -c1-110)"
  fi
done
# AutoApply.hc is generated (see genapply/build-genapply.sh), not shipped.
[ -f "$R/genapply/AutoApply.hc" ] || "$R/genapply/build-genapply.sh"
for src in "$G"/ghc/rts/*.hc "$G"/ghc/rts/parallel/*.hc "$R"/genapply/AutoApply.hc; do
  base=$(basename "$src" .hc)
  if $CC -c -x c $COMMON -include "$G/ghc/includes/Stg.h" \
        "$src" -o "$OUT/$base.o" 2> "$OUT/$base.log"; then
    ok=$((ok + 1))
  else
    fail=$((fail + 1)); failed="$failed $base"
    printf '%-20s FAILED: %s\n' "$base" \
      "$(grep 'error' "$OUT/$base.log" | head -1 | cut -c1-110)"
  fi
done
echo "rts: compiled $ok, failed $fail"
rm -f "$R/libHSrts.a" && ar rcs "$R/libHSrts.a" "$OUT"/*.o && echo "archived $R/libHSrts.a"
[ -n "$failed" ] && echo "failed:$failed"
exit 0
