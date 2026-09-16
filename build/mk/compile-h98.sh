#!/bin/sh
# Compile one libraries/haskell98 module with the stage-1 compiler, for
# build/Makefile (build-haskell98.sh's flags: -C -O -package-name haskell98
# -package base). Outputs removed first; the .hi must decode (check-hi.sh).
#   sh build/mk/compile-h98.sh <Module>          exit 0 iff .hi and .hc exist
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
S="$R/build/ghc622-stage2"; GHC="${GHC:-$R/build/ghc622-mhs/ghc}"
mkdir -p "$S/logs/haskell98"
ulimit -s unlimited 2>/dev/null
m=$1; OUT="${OUT:-$S/results-haskell98.tsv}"
# GHC 6.2.2 names temp files ghc<pid>.<ext> and steps to pid+1 when the name
# is taken, so parallel compiles sharing one TMPDIR can read each other's
# preprocessed source (2026-09-16: GHC/Unicode.hi came out as GHC.STRef's).
# Each compile gets a directory of its own.
export TMPDIR="$S/tmp/$m.$$"; mkdir -p "$TMPDIR"; trap 'rm -rf "$TMPDIR"' EXIT
cd "$S/libraries/haskell98" || exit 1
rm -f "$m.hi" "$m.hc"
log="$S/logs/haskell98/$m.log"; start=$(date +%s)
(ulimit -v 8000000; timeout 1800 "$GHC" ${MHSRTS:-+RTS -K20M -RTS} "-B$S/topdir" -v1 -C -O \
   -package-name haskell98 -package base "$m.hs" > "$log" 2>&1)
rc=$?; secs=$(( $(date +%s) - start ))
if [ $rc = 0 ] && [ -f "$m.hc" ] && [ -f "$m.hi" ] && sh "$R/build/mk/check-hi.sh" "$m.hi" "$m" >> "$log" 2>&1; then
  printf 'OK\t%s\t%ss\n' "$m" "$secs" >> "$OUT"; echo "haskell98 $m: OK ${secs}s"
else
  printf 'FAIL\t%s\trc=%s %ss %s\n' "$m" "$rc" "$secs" "$(tr '\n' ' ' < "$log" | cut -c1-300)" >> "$OUT"
  rm -f "$m.hi" "$m.hc"; echo "haskell98 $m: FAIL rc=$rc, see $log"; exit 1
fi
