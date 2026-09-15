#!/bin/sh
# Compile one module (default: Lexer) with mhs against the 6.2.2 tree at
# build/rebase622/try622, mirroring the INC/HSCPP recipe of
# build/probe-ordered-slit.sh but with this directory's shims and overlay first.
#
#   sh build/lexer622/compile.sh [Module] [extra mhs args...]
#
#   OUT=<exe>     link an executable instead of -c (used for the token driver)
#   PREINC=<dir>  an -i directory searched before everything else (tests)
#
# Run under sh (the script word-splits $INC).  Uses its own -C cache in
# build/lexer622/work so it never touches another run's cache.
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
M="$R/MicroHs"
L="$R/build/lexer622"
TREE="$R/build/rebase622/try622"
MOD="${1:-Lexer}"; [ $# -gt 0 ] && shift

export TMPDIR="$L/tmp"
mkdir -p "$TMPDIR" "$L/work"

HSCPP="-D__HASKELL__=98 -D__HASKELL1__=5 -D__GLASGOW_HASKELL__=408 -D__HASKELL98__ -D__CONCURRENT_HASKELL__"
export PATH="$M/bin:$PATH"

INC="${PREINC:+-i$PREINC} -i$L -i$L/shims -i$L/overlay"
INC="$INC -i$R/phase2/hsboot-6.0-run2 -i$R/build/shims-6.0-run2"
INC="$INC -i$R/phase1/shims -i$R/phase1/shims-ghc -i$R/phase1/shims-h98"
INC="$INC -i$R/phase2/gen-6.0"
for d in "$TREE"/*/; do
  [ -d "$d" ] && INC="$INC -i${d%/}"
done
INC="$INC -i$TREE -I$TREE -I$L/includes"

if [ -n "${OUT:-}" ]; then MODE="-o $OUT"; else MODE="-c"; fi

cd "$L/work" || exit 1
exec "$M/bin/mhs" ${MHSRTS:-+RTS -K20M -RTS} -C $MODE -XCPP $HSCPP -DOMIT_NATIVE_CODEGEN ${DEFS:-} $INC "$@" "$MOD"
