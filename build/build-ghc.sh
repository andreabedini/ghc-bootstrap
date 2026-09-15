#!/bin/sh
# Compile GHC 4.08.2's compiler with mhs, in dependency order.
#
# Asking mhs for Main and letting it walk the graph does not work in a tree
# with 31 boot modules (DECISIONS.md D22): a module bound to its .hs-boot early
# is never promoted, so a later ordinary import of it sees an interface without
# data constructors. GHC has the same requirement and solves it the same way --
# mkdependHS computes an order and the Makefile follows it.
#
# Each module is compiled with -C, so mhs's cache carries the finished module
# forward to its dependents. -fno-code is deliberately NOT used: it suppresses
# cache writing, which is the whole point here.
#
#   build/build-ghc.sh [start-module]     resume from a module in the order
set -u
R=/home/andrea/work/haskell/ghc-bootstrap
M="$R/MicroHs"
T="$R/build/ghc-4.08.2/ghc/compiler"
ORDER="$R/phase2/build-order.txt"
export PATH="$M/bin:$PATH"

INC="-i$R/phase1/shims -i$R/phase1/shims-h98 -i$R/phase1/shims-ghc"
INC="$INC -i$R/build/ghc-parsers -i$R/phase2/hsboot -i$R/build/ghc-hsboot"
for d in "$T"/*/; do
  case "$d" in *nativeGen/) continue;; esac      # OMIT_NATIVE_CODEGEN
  [ -d "$d" ] && INC="$INC -i${d%/}"
done
INC="$INC -i$T"
CPP="-D__GLASGOW_HASKELL__=408 -D__HASKELL1__=5 -DHscIfaceFileVersion=5"
CPP="$CPP -DOMIT_NATIVE_CODEGEN -I$T -I$R/build/ghc-4.08.2/ghc/includes"

ulimit -s unlimited 2>/dev/null || ulimit -s 65536
mkdir -p "$R/build/ghc-mhs" && cd "$R/build/ghc-mhs" || exit 1

start="${1:-}"
started=0
[ -z "$start" ] && started=1
n=0
total=$(wc -l < "$ORDER")
while IFS= read -r m; do
  [ -z "$m" ] && continue
  n=$((n + 1))
  if [ "$started" = 0 ]; then
    [ "$m" = "$start" ] && started=1 || continue
  fi
  printf '%3d/%d  %-24s ' "$n" "$total" "$m"
  out=$("$M/bin/mhs" -C -c -XCPP $CPP $INC "$m" 2>&1 | rg -v '^Warning|^\s' | tr '\n' ' ')
  case "$out" in
    "") echo OK ;;
    *)  echo "FAIL"; echo "$out" | sed 's|.*uncaught exception: ||' | cut -c1-200; exit 1 ;;
  esac
done < "$ORDER"
echo "all $total modules compiled"
