#!/bin/sh
# Feed the kept preprocessed files to mhs directly (no CPP) so the reported
# line/col refer exactly to build/ppkeep/<M>.pp.hs, then print that spot.
set -u
R=/home/andrea/work/haskell/ghc-bootstrap; T=${TREE:-$R/build/ghc-6.0-slit/ghc/compiler}
INC="-i$R/build/ppkeep -i${HSBOOT:-$R/phase2/hsboot-6.0b} -i${SHIMS:-$R/build/shims-6.0} -i$R/phase1/shims -i$R/phase1/shims-ghc -i$R/phase1/shims-h98 -i$R/phase2/gen-6.0"
for d in "$T"/*/; do INC="$INC -i${d%/}"; done
INC="$INC -i$T -I$T -I${INCDIR:-$R/build/ghc-6.0-slit/ghc/includes}"
HSCPP="-D__HASKELL__=98 -D__HASKELL1__=5 -D__GLASGOW_HASKELL__=408 -D__HASKELL98__ -D__CONCURRENT_HASKELL__ -DOMIT_NATIVE_CODEGEN -DHscIfaceFileVersion=6"
W=$R/build/probe-6.0-ppd; rm -rf "$W"; mkdir -p "$W"; cd "$W" || exit 1
mkdir -p src; for m in "$@"; do grep -v "^#" "$R/build/ppkeep/$m.pp.hs" > "src/$m.hs"; done
export TMPDIR=. PATH="$R/MicroHs/bin:$PATH"
for m in "$@"; do
  msg=$(timeout 300 mhs +RTS -K20M -RTS -C -c -XCPP $HSCPP -isrc $INC "$m" 2>&1 | tr '\n' ' ' | sed 's|.*uncaught exception: ||' | cut -c1-160)
  echo "== $m: $msg"
  case "$msg" in *"src/$m.hs"*) n=$(printf '%s' "$msg" | grep -oE 'line [0-9]+' | head -1 | grep -oE '[0-9]+'); sed -n "$((n-2)),$((n+1))p" "src/$m.hs" | cut -c1-140 | sed 's/^/     | /';; esac
done
