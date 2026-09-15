#!/bin/sh
# diag copy of run-base.sh: same flags, but BASE (default libraries/base-rebuild),
# TOPDIR (diag/topdir-rebuild), OUT (diag/base-rebuild-results.tsv) and LOGS
# (diag/base-rebuild-logs) are parameters, so a full rebuild lands beside the
# current tree instead of on top of it.
#
#   sh build/ghc622-mhs/run-base.sh [order-file]      (default base-order.txt)
#
# Flags are libraries/base/Makefile's SRC_HC_OPTS (-fglasgow-exts -cpp -Iinclude
# -#include HsBase.h -funbox-strict-fields), mk/package.mk's -package-name base,
# mk/config.mk's GhcLibHcOpts (-O; -Rghc-timing and -H16m dropped: their RTS
# hooks are no-ops under the MicroHs runtime), and -C to stop after the .hc.
# The driver itself adds unregFlags (-funregisterised -fvia-C ...) because
# Config.cGhcUnregisterised = "YES". -fno-implicit-prelude comes from each
# module's OPTIONS pragma. Runs in a copy of libraries/base (build/ghc622-mhs/
# libraries/base) so .hi/.hc land next to the sources; the topdir's
# package.conf points base's import_dirs at the same directory.
#
# Env: OPT (default -O), MODTIMEOUT (s, default 1800), FRESH=0 to skip modules
# whose .hc is newer than the source, STOP=1 to stop at the first failure,
# VERB (default -v1).
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
W="$R/build/ghc622-mhs"
export TMPDIR="$W/diag/tmp"
BASE="${BASE:-$W/libraries/base-rebuild}"; TOPDIR="${TOPDIR:-$W/diag/topdir-rebuild}"; LOGS="${LOGS:-$W/diag/base-rebuild-logs}"
mkdir -p "$TMPDIR" "$LOGS"
ulimit -s unlimited 2>/dev/null || ulimit -s 65536
ORDER="${1:-$W/base-order.txt}"
OPT="${OPT:--O}"
OUT="${OUT:-$W/diag/base-rebuild-results.tsv}"
[ "${FRESH:-1}" = 1 ] && : > "$OUT"
cd "$BASE" || exit 1
ok=0; fail=0
while read -r m; do
  [ -n "$m" ] || continue
  path=$(printf '%s' "$m" | tr . /)
  if [ -f "$path.lhs" ]; then src="$path.lhs"; elif [ -f "$path.hs" ]; then src="$path.hs"; else
    printf 'FAIL\t%s\tno source\n' "$m" >> "$OUT"; continue; fi
  if [ "${FRESH:-1}" = 0 ] && [ -f "$path.hc" ] && [ -f "$path.hi" ] && [ "$path.hc" -nt "$src" ]; then
    printf 'OK\t%s\t(cached)\n' "$m" >> "$OUT"; ok=$((ok+1)); continue; fi
  log="$LOGS/$m.log"
  start=$(date +%s)
  # +RTS -K5M -RTS is consumed by the MicroHs runtime (eval.c:7060-7090), not
  # by the driver: the default stack is 250000 slots (eval.c:495), which the
  # bigger modules overflow ("ERR: stack overflow").
  compile() {
    timeout "${MODTIMEOUT:-1800}" "$W/ghc" ${MHSRTS:-+RTS -K5M -RTS} "-B$TOPDIR" ${VERB:--v1} -C \
      -fglasgow-exts -cpp -Iinclude '-#include' HsBase.h -funbox-strict-fields \
      -package-name base $OPT ${EXTRA:-} "$@" "$src" > "$log" 2>&1
  }
  compile
  rc=$?
  note=""
  # The demand analyser exhausts stack and then heap on the bigger modules:
  # GHC's own strictness analysis kept DmdAnal's thunk chains short when GHC
  # compiled itself, and mhs preserves the laziness literally. -fno-strictness
  # switches off that one Core pass; the rest of -O still runs.
  case "$(cat "$log")" in
    *"ERR: stack overflow"*|*"ERR: heap exhausted"*|*"stack overflow: use +RTS"*)
      compile -fno-strictness; rc=$?; note=" [-fno-strictness]" ;;
  esac
  secs=$(( $(date +%s) - start ))
  if [ $rc = 0 ] && [ -f "$path.hc" ] && [ -f "$path.hi" ]; then
    printf 'OK\t%s\t%ss %s lines hc%s\n' "$m" "$secs" "$(wc -l < "$path.hc")" "$note" >> "$OUT"; ok=$((ok+1))
  else
    msg=$(tr '\n' ' ' < "$log" | sed 's/  */ /g' | cut -c1-300)
    printf 'FAIL\t%s\trc=%s %ss %s\n' "$m" "$rc" "$secs" "$msg" >> "$OUT"; fail=$((fail+1))
    [ "${STOP:-0}" = 1 ] && break
  fi
done < "$ORDER"
echo "base: $ok OK, $fail FAIL (see $OUT)"
