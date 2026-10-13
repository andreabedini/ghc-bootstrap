#!/bin/sh
# Compile the trunk modules of the 6.0 tree with mhs, with cpphs intercepted
# (notes/probes/ppwrap) so the preprocessed text is kept, then show the construct at
# each reported failure line. Usage: sh notes/probes/pp-trunk.sh <tree> <label> mod...
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
T=$(cd "$1" && pwd); LABEL=$2; shift 2
# HSBOOT / SHIMS / INCDIR override the defaults, so a second tree copy can be probed.
# build/shims-6.0{,-run2} keep only the files that differ from ghc622/shims
# (the identical ones were removed 2026-10-13); ghc622/shims after them supplies
# the rest, plus modules the old set did not have (CForeign, Foreign, ...).
INC="-i${HSBOOT:-$R/notes/phase2/hsboot-6.0b} -i${SHIMS:-$R/build/shims-6.0} -i$R/ghc622/shims -i$R/common/shims -i$R/ghc622/shims-ghc -i$R/ghc622/shims-h98 -i$R/notes/phase2/gen-6.0"
for d in "$T"/*/; do [ -d "$d" ] && INC="$INC -i${d%/}"; done
INC="$INC -i$T -I$T -I${INCDIR:-$R/build/ghc-6.0-slit/ghc/includes}"
HSCPP="-D__HASKELL__=98 -D__HASKELL1__=5 -D__GLASGOW_HASKELL__=408 -D__HASKELL98__ -D__CONCURRENT_HASKELL__ -DOMIT_NATIVE_CODEGEN -DHscIfaceFileVersion=6"
# FRESH=0 keeps the -C cache (mhs invalidates entries whose source changed).
W=$R/build/probe-$LABEL; [ "${FRESH:-1}" = 1 ] && rm -rf "$W"; mkdir -p "$W"; cd "$W" || exit 1
mkdir -p "$R/build/ppkeep"
export PATH="$R/notes/probes/ppwrap:$R/MicroHs/bin:$PATH" TMPDIR=.
for m in "$@"; do
  raw=$(timeout "${MODTIMEOUT:-120}" "$R/MicroHs/bin/mhs" ${MHSRTS:-+RTS -K20M -RTS} -C -c -XCPP $HSCPP $INC "$m" 2>&1); rc=$?
  msg=$(printf '%s' "$raw" | tr '\n' ' ' | sed 's|.*uncaught exception: ||' | cut -c1-220)
  [ $rc = 0 ] && { echo "== $m: OK"; continue; }
  echo "== $m: $msg"
  src=$(printf '%s' "$msg" | grep -oE '"[^"]+\.(lhs|hs)": line [0-9]+' | head -1 | sed 's/^"//; s/".*//')
  n=$(printf '%s' "$msg" | grep -oE 'line [0-9]+' | head -1 | grep -oE '[0-9]+')
  base=$(basename "${src:-x}"); base=${base%.*}; pp="$R/build/ppkeep/$base.pp.hs"
  if [ -f "$pp" ] && [ -n "$n" ]; then sed -n "$((n-2)),$((n+1))p" "$pp" | cut -c1-150 | sed 's/^/     | /'; fi
done
