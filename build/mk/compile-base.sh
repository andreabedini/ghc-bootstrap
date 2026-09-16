#!/bin/sh
# Compile one libraries/base module with the stage-1 compiler, for build/Makefile.
# run-base.sh's flags (libraries/base/Makefile SRC_HC_OPTS + -package-name base
# + GhcLibHcOpts -O, -C) and its one retry: -fno-strictness when the demand
# analyser exhausts the MicroHs stack or heap. The module's outputs are removed
# first (6.2.2's recompilation checker would open the old .hi), and the new .hi
# must decode (check-hi.sh). Appends a row to base-results.tsv.
#   sh build/mk/compile-base.sh <Module.Name>          exit 0 iff .hi and .hc exist
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
W="$R/build/ghc622-mhs"
mkdir -p "$W/base-logs"
ulimit -s unlimited 2>/dev/null || ulimit -s 65536
m=$1; path=$(printf '%s' "$m" | tr . /)
# GHC 6.2.2 names temp files ghc<pid>.<ext> and steps to pid+1 when the name
# is taken, so parallel compiles sharing one TMPDIR can read each other's
# preprocessed source (2026-09-16: GHC/Unicode.hi came out as GHC.STRef's).
# Each compile gets a directory of its own.
export TMPDIR="$W/tmp/$m.$$"; mkdir -p "$TMPDIR"; trap 'rm -rf "$TMPDIR"' EXIT
OPT="${OPT:--O}"; OUT="${OUT:-$W/base-results.tsv}"
cd "$W/libraries/base" || exit 1
if [ -f "$path.lhs" ]; then src="$path.lhs"; elif [ -f "$path.hs" ]; then src="$path.hs"; else
  echo "compile-base: no source for $m"; exit 1; fi
rm -f "$path.hi" "$path.hc"
log="$W/base-logs/$m.log"; start=$(date +%s)
compile() {
  timeout "${MODTIMEOUT:-1800}" "$W/ghc" ${MHSRTS:-+RTS -K5M -RTS} "-B$W/topdir" ${VERB:--v1} -C \
    -fglasgow-exts -cpp -Iinclude '-#include' HsBase.h -funbox-strict-fields \
    -package-name base $OPT ${EXTRA:-} "$@" "$src" > "$log" 2>&1
}
compile; rc=$?; note=""
case "$(cat "$log")" in
  *"ERR: stack overflow"*|*"ERR: heap exhausted"*|*"stack overflow: use +RTS"*)
    compile -fno-strictness; rc=$?; note=" [-fno-strictness]" ;;
esac
secs=$(( $(date +%s) - start ))
if [ $rc = 0 ] && [ -f "$path.hc" ] && [ -f "$path.hi" ] && sh "$R/build/mk/check-hi.sh" "$path.hi" "$m" >> "$log" 2>&1; then
  printf 'OK\t%s\t%ss %s lines hc%s\n' "$m" "$secs" "$(wc -l < "$path.hc")" "$note" >> "$OUT"
  echo "base $m: OK ${secs}s$note"
else
  msg=$(tr '\n' ' ' < "$log" | sed 's/  */ /g' | cut -c1-300)
  printf 'FAIL\t%s\trc=%s %ss %s\n' "$m" "$rc" "$secs" "$msg" >> "$OUT"
  rm -f "$path.hi" "$path.hc"; echo "base $m: FAIL rc=$rc, see $log"; exit 1
fi
