#!/bin/sh
# After the relink: version banner, compile GHC.List into diag/out with
# run-base.sh's flags, --show-iface it, and look for duplicated names.
set -u
R=/home/andrea/work/haskell/ghc-bootstrap
W="$R/build/ghc622-mhs"
export TMPDIR="$W/diag/tmp"
ulimit -s unlimited 2>/dev/null
ulimit -v 6000000
"$W/ghc" "-B$W/topdir" --version || exit 1
cd "$W/libraries/base" || exit 1
mkdir -p "$W/diag/out/GHC"
timeout 300 "$W/ghc" +RTS -K5M -RTS "-B$W/topdir" -v1 -C -fglasgow-exts -cpp -Iinclude '-#include' HsBase.h \
  -funbox-strict-fields -package-name base -O -ohi "$W/diag/out/GHC/List.hi" -o "$W/diag/out/GHC/List.hc" GHC/List.lhs
echo "GHC.List rc=$?"
"$W/ghc" "-B$W/topdir" --show-iface "$W/diag/out/GHC/List.hi" > "$W/diag/out/GHC/List.iface" 2>&1
echo "maximum-related signatures:"; rg -n 'maximum' "$W/diag/out/GHC/List.iface" | cut -c1-120
echo "duplicated names: $(sed -n 's/^[0-9][0-9]* \([^ ]*\) ::.*/\1/p' "$W/diag/out/GHC/List.iface" | sort | uniq -d | tr '\n' ' ')"
