#!/bin/sh
# build/ghc622-mhs/diag/scan-hi.sh parameterised: for every .hi under a dir,
# --show-iface it with a compiler and list top-level signature names that
# appear more than once (FastString unique collisions, diag/FINDINGS.md).
#   GHC=<compiler> sh scan-hi-stage2.sh <dir-with-.hi> <dump-dir>
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
S="$R/build/ghc622-stage2"
GHC="${GHC:-$S/ghc}"
export TMPDIR="$S/tmp"
ulimit -s unlimited 2>/dev/null
DIR="$1"; IFACES="$2"; mkdir -p "$IFACES"
cd "$DIR" || exit 1
n=0; bad=0
for hi in $(find . -name '*.hi' | sort); do
  m=$(printf '%s' "${hi#./}" | sed 's/\.hi$//; s,/,.,g')
  out="$IFACES/$m.iface"
  "$GHC" ${MHSRTS:-} "-B$S/topdir" --show-iface "$hi" > "$out" 2>&1 || { echo "show-iface FAILED: $m"; bad=$((bad+1)); }
  n=$((n+1))
  dups=$(sed -n 's/^[0-9][0-9]* \([^ ]*\) ::.*/\1/p' "$out" | sort | uniq -d | tr '\n' ' ')
  [ -n "$dups" ] && printf 'DUP\t%s\t%s\n' "$m" "$dups"
done
echo "scan done: $n interfaces, $bad show-iface failures"
