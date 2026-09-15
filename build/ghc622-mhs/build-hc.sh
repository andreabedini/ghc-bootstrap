#!/bin/sh
# Compile every .hc that run-base.sh produced with gcc, the way
# build/rts622/build-rts.sh compiles the RTS's own .hc files:
# -x c -include Stg.h, -std=gnu89 -O, -DNO_REGS -DUSE_MINIINTERPRETER,
# -D__GLASGOW_HASKELL__=622 (DriverPipeline.hs:726), plus base's include dir
# for the "#include HsBase.h" the driver puts at the top of each .hc.
# Objects go to build/ghc622-mhs/hcobj (override with HCOBJ=dir).
#
# -fwrapv is mandatory (found at link time, FINDINGS-link.md): the generated
# code and base itself rely on two's-complement wrap of Int# arithmetic
# (GHC/Show.lhs itos: n'# = negateInt# n#; if n'# <# 0# -- minInt?), and
# gcc >= 4 folds such tests away under the C signed-overflow rule, so
# show (minBound::Int) printed "-0". Later GHCs pass -fwrapv to gcc for
# exactly this reason (SysTools/DriverPipeline, from 6.8 on).
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
W="$R/build/ghc622-mhs"
INC="$R/build/ghc-6.2.2-run1/ghc/includes"
CC=${CC:-gcc}
OBJ="${HCOBJ:-$W/hcobj}"
mkdir -p "$OBJ"
ok=0; fail=0; failed=""
cd "$W/libraries/base" || exit 1
for hc in $(find . -name '*.hc' | sort); do
  o="$OBJ/$(printf '%s' "${hc#./}" | tr / _ | sed 's/\.hc$/.o/')"
  if $CC -c -x c -std=gnu89 -O -fwrapv -w -fmax-errors=20 \
        -DNO_REGS -DUSE_MINIINTERPRETER -D__GLASGOW_HASKELL__=622 \
        -I"$INC" -Iinclude -I. -include "$INC/Stg.h" "$hc" -o "$o" 2> "$o.log"; then
    ok=$((ok+1))
  else
    fail=$((fail+1)); failed="$failed $hc"
    printf '%-34s %s\n' "$hc" "$(grep -m1 error "$o.log" | cut -c1-100)"
  fi
done
echo "hc -> o: $ok ok, $fail failed"
[ -n "$failed" ] && echo "failed:$failed"
exit 0
