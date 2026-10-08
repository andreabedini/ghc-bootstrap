#!/bin/sh
# First contact: ask mhs to compile GHC 4.08.2's compiler, top module first.
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
M="$R/MicroHs"
T="$R/build/ghc-4.08.2/ghc/compiler"
export PATH="$M/bin:$PATH"

INC="-i$R/build/probe -i$R/common/shims -i$R/ghc622/shims-h98 -i$R/ghc622/shims-ghc -i$R/build/ghc-parsers -i$R/phase2/hsboot -i$R/build/ghc-hsboot"
for d in "$T"/*/; do
  case "$d" in *nativeGen/) continue;; esac   # OMIT_NATIVE_CODEGEN
  [ -d "$d" ] && INC="$INC -i${d%/}"
done
INC="$INC -i$T"
CPP="-D__GLASGOW_HASKELL__=408 -D__HASKELL1__=5 -DHscIfaceFileVersion=5 -DOMIT_NATIVE_CODEGEN -I$T -I$R/build/ghc-4.08.2/ghc/includes"

ulimit -s unlimited 2>/dev/null || ulimit -s 65536
mkdir -p "$R/build/ghc-mhs" && cd "$R/build/ghc-mhs" || exit 1
"$M/bin/mhs" -l -C -c -fno-code -XCPP $CPP $INC "${1:-Main}" 2>&1 \
  | sed 's|.*uncaught exception: ||' | cat
