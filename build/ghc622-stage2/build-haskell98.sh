#!/bin/sh
# Compile 6.2.2's libraries/haskell98 (32 re-export modules) with the stage-1
# (mhs-built) compiler and archive libHShaskell98.a.  The compiler proper
# imports Array/Char/Directory/IO/List/Maybe/Monad/Ratio/System/Time/CForeign,
# which are haskell98 modules, so the package must exist before stage 2 starts.
# Flags: mk/package.mk (-package-name haskell98, -package base) + GhcLibHcOpts
# (-O; -Rghc-timing dropped, its RTS hook is a no-op under the MicroHs runtime).
# .hc -> .o: build/ghc622-mhs/build-hc.sh's recipe (-fwrapv mandatory).
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
S="$R/build/ghc622-stage2"
GHC="${GHC:-$R/build/ghc622-mhs/ghc}"
TOPDIR="$S/topdir"
INC="$S/src/ghc-6.2.2/ghc/includes"
export TMPDIR="$S/tmp"; mkdir -p "$TMPDIR" "$S/logs/haskell98"
ulimit -s unlimited 2>/dev/null
OUT="$S/results-haskell98.tsv"; : > "$OUT"
cd "$S/libraries/haskell98" || exit 1
ok=0; fail=0
# Array imports Ix, and the alphabetical order would compile it first (the
# first run had to redo Array by hand); everything else is order-independent.
for src in Ix.hs $(ls *.hs | grep -v '^Ix\.hs$'); do
  m=${src%.hs}
  start=$(date +%s)
  (ulimit -v 8000000; timeout 1800 "$GHC" ${MHSRTS:-+RTS -K20M -RTS} "-B$TOPDIR" -v1 -C -O \
     -package-name haskell98 -package base "$src" > "$S/logs/haskell98/$m.log" 2>&1)
  rc=$?; secs=$(( $(date +%s) - start ))
  if [ $rc = 0 ] && [ -f "$m.hc" ] && [ -f "$m.hi" ]; then
    printf 'OK\t%s\t%ss\n' "$m" "$secs" >> "$OUT"; ok=$((ok+1))
  else
    printf 'FAIL\t%s\trc=%s %ss %s\n' "$m" "$rc" "$secs" "$(tr '\n' ' ' < "$S/logs/haskell98/$m.log" | cut -c1-300)" >> "$OUT"; fail=$((fail+1))
  fi
done
echo "haskell98 hs->hc: $ok OK, $fail FAIL"
mkdir -p obj; oc=0; of=0
for hc in *.hc; do
  o="obj/${hc%.hc}.o"
  if gcc -c -x c -std=gnu89 -O -fwrapv -w -DNO_REGS -DUSE_MINIINTERPRETER -D__GLASGOW_HASKELL__=602 \
        -I"$INC" -I"$S/libraries/base/include" -include "$INC/Stg.h" "$hc" -o "$o" 2> "$o.log"; then oc=$((oc+1)); else of=$((of+1)); echo "FAILED: $hc"; fi
done
echo "haskell98 hc->o: $oc ok, $of failed"
rm -f libHShaskell98.a; ar rcs libHShaskell98.a obj/*.o && echo "libHShaskell98.a: $(ar t libHShaskell98.a | wc -l) objects"
