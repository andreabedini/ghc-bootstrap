#!/bin/sh
# diag/run-mods.sh <results-file> <module>...
# Compile the named base modules in place (libraries/base, .hi + .hc next to
# the source) with exactly run-base.sh's flags and its -fno-strictness retry,
# appending rows to <results-file> instead of the shared base-results.tsv.
# Env: OPT (-O), MODTIMEOUT (900), MEMKB (6000000), GHCBIN.
set -u
R=/home/andrea/work/haskell/ghc-bootstrap
W="$R/build/ghc622-mhs"
export TMPDIR="$W/diag/tmp"
mkdir -p "$TMPDIR" "$W/diag/logs"
ulimit -s unlimited 2>/dev/null || ulimit -s 65536
ulimit -v "${MEMKB:-6000000}"
OUT=$1; shift
OPT="${OPT:--O}"
cd "$W/libraries/base" || exit 1
for m in "$@"; do
  path=$(printf '%s' "$m" | tr . /)
  if [ -f "$path.lhs" ]; then src="$path.lhs"; else src="$path.hs"; fi
  log="$W/diag/logs/inplace-$m.log"
  start=$(date +%s)
  compile() {
    timeout "${MODTIMEOUT:-900}" "${GHCBIN:-$W/ghc}" ${MHSRTS:-+RTS -K5M -RTS} "-B$W/topdir" ${VERB:--v1} -C \
      -fglasgow-exts -cpp -Iinclude '-#include' HsBase.h -funbox-strict-fields \
      -package-name base $OPT ${EXTRA:-} "$@" "$src" > "$log" 2>&1
  }
  compile; rc=$?; note=""
  case "$(cat "$log")" in
    *"ERR: stack overflow"*|*"ERR: heap exhausted"*|*"stack overflow: use +RTS"*)
      compile -fno-strictness; rc=$?; note=" [-fno-strictness]" ;;
  esac
  secs=$(( $(date +%s) - start ))
  if [ $rc = 0 ] && [ -f "$path.hc" ] && [ -f "$path.hi" ]; then
    printf 'OK\t%s\t%ss %s lines hc%s\n' "$m" "$secs" "$(wc -l < "$path.hc")" "$note" | tee -a "$OUT"
  else
    printf 'FAIL\t%s\trc=%s %ss %s\n' "$m" "$rc" "$secs" "$(tr '\n' ' ' < "$log" | cut -c1-300)" | tee -a "$OUT"
  fi
done
