#!/bin/sh
# scan-hi.sh [base-dir] [iface-dump-dir]: for every .hi under base-dir, --show-iface it and list top-level
# signature names that appear more than once (FastString unique collisions).
set -u
R=/home/andrea/work/haskell/ghc-bootstrap
W="$R/build/ghc622-mhs"
export TMPDIR="$W/diag/tmp"
ulimit -s unlimited 2>/dev/null

BASE="${1:-$W/libraries/base}"; IFACES="${2:-$W/diag/ifaces}"
mkdir -p "$IFACES"
cd "$BASE" || exit 1
for hi in $(find . -name '*.hi' | sort); do
  m=$(printf '%s' "${hi#./}" | sed 's/\.hi$//; s,/,.,g')
  out="$IFACES/$m.iface"
  "$W/ghc" "-B$W/topdir" --show-iface "$hi" > "$out" 2>&1
  dups=$(sed -n 's/^[0-9][0-9]* \([^ ]*\) ::.*/\1/p' "$out" | sort | uniq -d | tr '\n' ' ')
  [ -n "$dups" ] && printf '%s\t%s\n' "$m" "$dups"
done
echo "scan done"
