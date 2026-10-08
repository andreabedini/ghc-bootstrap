#!/bin/sh
# Link GHC 6.2.2's compiler proper (build/ghc-6.2.2-run1) into a binary with mhs.
#
#   sh build/ghc622-mhs/build.sh [comb|c|cc|hs|all]     (default: all = comb + c + cc)
#
#  hs  : mhs -o ghc.c   whole-program C emission of Main, reusing the probe's
#        -C cache (copied to build/ghc622-mhs/.mhscache; a cold cache costs ~1h).
#        Same cpp defines, -i and -I flags as build/probe-ordered-622.sh.
#  comb: mhs -o ghc.comb  (same compile, a quarter of the output text; the
#        .c route needs ~13 min in one process and the sandbox kills a
#        foreground command at 10, so this is the route that is used)
#  c   : comb2c.py ghc.comb -> ghc-data.c  (byte-identical to mhs -o ghc.c)
#  cc  : gcc ghc-data.c ffi.c + MicroHs runtime (main.c, eval.c) + stubs.c -> ghc
#        (as build/compile-ghc.sh / D41 did for 4.08.2's hsc).
#
# Run under sh (word-splitting of $INC), with ulimit -s unlimited.
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
M="$R/MicroHs"
W="$R/build/ghc622-mhs"
TREE="$R/build/ghc-6.2.2-run1/ghc/compiler"
INCDIR="$R/build/ghc-6.2.2-run1/ghc/includes"
HSBOOT="$R/ghc622/hsboot"
EXTRA_SHIMS="$R/ghc622/shims"
GEN="$W/gen"   # main/Config.hs, from the configured tree reproduce-6.2.2.sh leaves (TREE622)
export PATH="$M/bin:$PATH"
export TMPDIR="$W/tmp"
mkdir -p "$TMPDIR"
sh "$R/ghc622/tools/config-hs.sh" "${TREE622:-$R/build/repro-622/src/ghc-6.2.2}" \
  "$R/ghc622/gen/config-hs.mk" "$GEN"
ulimit -s unlimited 2>/dev/null || ulimit -s 65536

# The five defines the perl driver passes to cpp for every Haskell source
# (see probe-ordered-622.sh header for why __GLASGOW_HASKELL__=408 is kept).
HSCPP="-D__HASKELL__=98 -D__HASKELL1__=5 -D__GLASGOW_HASKELL__=408 -D__HASKELL98__ -D__CONCURRENT_HASKELL__"
INC="-i$HSBOOT -i$EXTRA_SHIMS -i$R/common/shims -i$R/ghc622/shims-ghc -i$R/ghc622/shims-h98 -i$GEN"
for d in "$TREE"/*/; do
  [ -d "$d" ] && INC="$INC -i${d%/}"
done
INC="$INC -i$TREE -I$TREE -I$INCDIR"

step=${1:-all}
cd "$W" || exit 1

if [ "$step" = comb ] || [ "$step" = all ]; then
  # Combinator file instead of C: same compile, a quarter of the output text.
  # The MicroHs runtime can load it at startup (+RTS -r<file> -RTS), see the
  # `eval` step; this is the fallback when the C emission does not fit the
  # sandbox's 10-minute foreground limit.
  echo "== mhs -o ghc.comb  ($(date))"
  "$M/bin/mhs" ${MHSRTS:-+RTS -K32M -RTS} -C -XCPP $HSCPP -DOMIT_NATIVE_CODEGEN $INC Main -o"$W/ghc.comb" || exit 1
  echo "== ghc.comb: $(wc -c < "$W/ghc.comb") bytes  ($(date))"
fi

if [ "$step" = hs ]; then
  echo "== mhs -o ghc.c  ($(date))"
  "$M/bin/mhs" ${MHSRTS:-+RTS -K64M -RTS} -C -XCPP $HSCPP -DOMIT_NATIVE_CODEGEN $INC Main -o"$W/ghc.c" || exit 1
  echo "== ghc.c: $(wc -c < "$W/ghc.c") bytes  ($(date))"
  # Note: this ghc.c embeds mhs's own ffi table and is NOT what the cc step
  # links (ghc-data.c + ffi.c, the comb route). `all` used to run hs + cc and
  # so relinked a stale ghc-data.c (found 2026-09-16, build/ghc622-stage2/LOG.md).
fi

if [ "$step" = c ] || [ "$step" = all ]; then
  # .comb -> the same C array `mhs -o ghc.c` would emit (see comb2c.py).
  echo "== comb2c  ($(date))"
  python3 "$R/ghc622/stage1/comb2c.py" "$W/ghc.comb" "$W/ghc-data.c" || exit 1
  echo "== ghc-data.c: $(wc -c < "$W/ghc-data.c") bytes"
fi

if [ "$step" = cc ] || [ "$step" = all ]; then
  echo "== gcc  ($(date))"
  # Flags as mhs's own mainCompileC (mhs.conf [unix]: -w -Wall -O3, -lm),
  # plus -include stubs.h: the FFI wrappers mhs emits call rawSystem,
  # setHeapSize, enableTimingStats, getpid, time by name with no prototype,
  # which gcc >= 14 rejects; stubs.c provides the first three (rawSystem is
  # libraries/base/cbits/rawSystem.c).
  # rtconf/config.h: MicroHs's unix config with WANT_OVERFLOW 0. MicroHs
  # traps Int +/-/* overflow (unix/config.h:85 -> eval.c:300-307
  # __builtin_*_overflow -> raise_rts(exn_overflow)); GHC's Haskell is written
  # against wrap-around Int, and CoreUtils.hashExpr multiplies hashes until it
  # wraps on purpose ("Just in case we hit -maxInt"), so with overflow trapping
  # `-O` died in CSE with "arithmetic overflow". Generated from MicroHs's file
  # rather than edited in place, and searched before it.
  mkdir -p "$W/rtconf"
  sed 's/^#define WANT_OVERFLOW 1/#define WANT_OVERFLOW 0  \/* mhs: GHC needs wrap-around Int *\//' \
      "$M/src/runtime/unix/config.h" > "$W/rtconf/config.h"
  cc -w -O3 -I"$W/rtconf" -I"$M/src/runtime" -I"$M/src/runtime/unix" -D__MHS__ \
     -include "$R/ghc622/stage1/stubs.h" \
     "$M/src/runtime/main.c" "$M/src/runtime/eval.c" "$R/ghc622/stage1/stubs.c" \
     "$W/ghc-data.c" "$R/ghc622/stage1/ffi.c" \
     -lm -o "$W/ghc" || exit 1
  ls -la "$W/ghc"
fi
