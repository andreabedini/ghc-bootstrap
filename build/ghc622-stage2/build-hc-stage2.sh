#!/bin/sh
# Compile every .hc the stage-2 loop produced (stage2/<dir>/M.hc) to
# obj/<dir>_M.o with gcc, with build/ghc622-mhs/build-hc.sh's recipe
# (-x c -std=gnu89 -O -fwrapv -DNO_REGS -DUSE_MINIINTERPRETER, Stg.h
# pre-included; -fwrapv is mandatory, FINDINGS-link.md), plus -I<compiler>/parser
# for the '-#include "hschooks.h"' every module carries and base's include
# dir for HsBase.h.  Also compiles the compiler's two C files (Makefile
# C_SRCS: parser/hschooks.c, cbits/rawSystem.c) the way UseGhcForCc would:
# -D__GLASGOW_HASKELL__=602 -I<includes> (-Iparser -I. -O per SRC_CC_OPTS).
#   OUTDIR=stage3 sh build-hc-stage2.sh   -> obj-stage3/   (for stage 3)
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
S="$R/build/ghc622-stage2"
SRC="$S/src/ghc-6.2.2/ghc/compiler"
INC="$S/src/ghc-6.2.2/ghc/includes"
ODIR="${OUTDIR:-stage2}"
OBJ="$S/obj${ODIR#stage2}"; [ "$ODIR" = stage2 ] && OBJ="$S/obj"
CC=${CC:-gcc}
mkdir -p "$OBJ"
ok=0; fail=0; failed=""
cd "$S/$ODIR" || exit 1
for hc in $(find . -name '*.hc' | sort); do
  o="$OBJ/$(printf '%s' "${hc#./}" | tr / _ | sed 's/\.hc$/.o/')"
  [ "${FRESH:-1}" = 0 ] && [ -f "$o" ] && [ "$o" -nt "$hc" ] && { ok=$((ok+1)); continue; }
  if $CC -c -x c -std=gnu89 -O -fwrapv -w -fmax-errors=20 \
        -DNO_REGS -DUSE_MINIINTERPRETER -D__GLASGOW_HASKELL__=602 \
        -I"$INC" -I"$SRC/parser" -I"$SRC" -I"$S/libraries/base/include" \
        -include "$INC/Stg.h" "$hc" -o "$o" 2> "$o.log"; then
    ok=$((ok+1))
  else
    fail=$((fail+1)); failed="$failed $hc"
    printf '%-34s %s\n' "$hc" "$(grep -m1 error "$o.log" | cut -c1-120)"
  fi
done
echo "hc -> o: $ok ok, $fail failed"
[ -n "$failed" ] && echo "failed:$failed"
for c in parser/hschooks.c cbits/rawSystem.c; do
  o="$OBJ/c_$(basename "$c" .c).o"
  if $CC -c -std=gnu89 -O -w -DNO_REGS -DUSE_MINIINTERPRETER -D__GLASGOW_HASKELL__=602 \
        -I"$INC" -I"$SRC/parser" -I"$SRC" -I"$S/libraries/base/include" "$SRC/$c" -o "$o" 2> "$o.log"; then
    echo "C: $c ok"
  else
    echo "C: $c FAILED: $(grep -m1 error "$o.log")"
  fi
done
exit 0
