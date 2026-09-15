#!/bin/sh
# diag/run1.sh <log-name> <timeout-s> <ghc flags...> -- runs in libraries/base copy, outputs to diag/out
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
W="$R/build/ghc622-mhs"
export TMPDIR="$W/diag/tmp"
mkdir -p "$TMPDIR" "$W/diag/out" "$W/diag/logs"
ulimit -s unlimited 2>/dev/null || ulimit -s 65536
ulimit -v "${MEMKB:-6000000}"
name=$1; to=$2; shift 2
cd "$W/libraries/base" || exit 1
start=$(date +%s)
timeout "$to" "${GHCBIN:-$W/ghc}" ${MHSRTS:-+RTS -K5M -RTS} "-B$W/topdir" -C \
  -fglasgow-exts -cpp -Iinclude '-#include' HsBase.h -funbox-strict-fields \
  -package-name base -odir "$W/diag/out" -ohi "$W/diag/out/$name.hi" -o "$W/diag/out/$name.hc" "$@" > "$W/diag/logs/$name.log" 2>&1
rc=$?
echo "rc=$rc secs=$(( $(date +%s) - start ))" >> "$W/diag/logs/$name.log"
tail -c 2000 "$W/diag/logs/$name.log"
