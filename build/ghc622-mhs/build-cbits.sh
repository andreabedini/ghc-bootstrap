#!/bin/sh
# Compile libraries/base/cbits for GHC 6.2.2, the way libraries/base/cbits/
# Makefile would: every cbits/*.c except EXCLUDED_SRCS (ilxstubs.c always,
# consUtils.c off mingw32, regex/ when HavePosixRegex=YES -- which configure
# set on this machine, mk/config.mk:757), with SRC_CC_OPTS -DCOMPILING_STDLIB
# -I<ghc/includes> -I<ghc/rts> -I../include, plus the RTS's own flags
# (build/rts622/build-rts.sh: -std=gnu89 -O -DNO_REGS -DUSE_MINIINTERPRETER
# -D__GLASGOW_HASKELL__=622). Also compiles Control/Concurrent_stub.c, the
# foreign-export stub the driver emitted while compiling Control.Concurrent
# (libraries/base/Makefile lists it in STUBOBJS).
# Objects go to build/ghc622-mhs/cbitsobj; build-libbase.sh archives them.
set -u
R=/home/andrea/work/haskell/ghc-bootstrap
W="$R/build/ghc622-mhs"
INC="$R/build/ghc-6.2.2-run1/ghc/includes"
RTS="$R/build/rts622/ghc-6.2.2/ghc/rts"
CC=${CC:-gcc}
OUT="$W/cbitsobj"
mkdir -p "$OUT"
COMMON="-std=gnu89 -O -w -fmax-errors=100 -DNO_REGS -DUSE_MINIINTERPRETER -DCOMPILING_STDLIB -D__GLASGOW_HASKELL__=622 -I$INC -I$RTS"
ok=0; fail=0; failed=""
cd "$W/libraries/base/cbits" || exit 1
for src in *.c; do
  base=$(basename "$src" .c)
  case "$base" in ilxstubs|consUtils) continue ;; esac
  if $CC -c $COMMON -I../include "$src" -o "$OUT/$base.o" 2> "$OUT/$base.log"; then
    ok=$((ok+1))
  else
    fail=$((fail+1)); failed="$failed $base"
    printf '%-20s FAILED: %s\n' "$base" "$(grep error "$OUT/$base.log" | head -1 | cut -c1-110)"
  fi
done
cd "$W/libraries/base" || exit 1
if $CC -c $COMMON -Iinclude -I. Control/Concurrent_stub.c -o "$OUT/Control_Concurrent_stub.o" 2> "$OUT/Control_Concurrent_stub.log"; then
  ok=$((ok+1))
else
  fail=$((fail+1)); failed="$failed Control_Concurrent_stub"
fi
echo "cbits: compiled $ok, failed $fail"
[ -n "$failed" ] && echo "failed:$failed"
exit 0
