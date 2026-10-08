#!/bin/sh
# Compile a GHC compiler tree with mhs in dependency order, sharing the -C cache.
# This is the shape that D22 says is the only one that works: module-at-a-time
# standalone compilation mis-binds boot modules, so it under-reports badly.
#
#   notes/phase2/probe-ordered.sh <label> <tree> <includes> <order-file> <hsboot-dir> [extra-i ...]
#
# Writes build/probe-<label>.tsv  (STATUS \t module \t message)
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
M="$R/MicroHs"
LABEL="$1"
TREE=$(cd "$2" && pwd)   || exit 1
INCDIR=$(cd "$3" && pwd) || exit 1
ORDER=$(cd "$(dirname "$4")" && pwd)/$(basename "$4")
HSBOOT=$(cd "$5" && pwd) || exit 1
shift 5
DEFS="${DEFS:-}"
# The five defines the perl driver passes to cpp for every Haskell source
# (ghc.lprl @HsSourceCppOpts). They are not optional: HsVersions.h keys
# FMAP/ISALPHANUM/IOERROR/PSEQ off __HASKELL1__, so without them FMAP
# expands to map instead of fmap and 60+ modules fail to typecheck.
HSCPP="-D__HASKELL__=98 -D__HASKELL1__=5 -D__GLASGOW_HASKELL__=408 -D__HASKELL98__ -D__CONCURRENT_HASKELL__"
export PATH="$M/bin:$PATH"

INC="-i$HSBOOT -i$R/common/shims -i$R/ghc622/shims-ghc -i$R/ghc622/shims-h98"
for d in "$@"; do INC="$INC -i$(cd "$d" && pwd)"; done
for d in "$TREE"/*/; do
  [ -d "$d" ] && INC="$INC -i${d%/}"
done
INC="$INC -i$TREE -I$TREE -I$INCDIR"

W="$R/build/probe-$LABEL"
[ "${FRESH:-1}" = 1 ] && rm -rf "$W"
mkdir -p "$W" && cd "$W" || exit 1
OUT="$R/build/probe-$LABEL.tsv"
: > "$OUT"

while read -r m; do
  [ -n "$m" ] || continue
  out=$(timeout "${MODTIMEOUT:-180}" "$M/bin/mhs" -C -c -fno-code -XCPP $HSCPP -DOMIT_NATIVE_CODEGEN $DEFS $INC "$m" 2>&1 | tr '\n' ' ')
  case "$out" in
    *"No code generated"*) printf 'OK\t%s\t\n' "$m" >> "$OUT" ;;
    "") printf 'TIMEOUT\t%s\tno output within ${MODTIMEOUT:-180}s\n' "$m" >> "$OUT" ;;
    *) printf 'FAIL\t%s\t%s\n' "$m" \
         "$(printf '%s' "$out" | sed 's|.*uncaught exception: ||' | cut -c1-240)" >> "$OUT" ;;
  esac
done < "$ORDER"
echo "done $LABEL: $(grep -c '^OK' "$OUT") OK / $(wc -l < "$OUT") total"
