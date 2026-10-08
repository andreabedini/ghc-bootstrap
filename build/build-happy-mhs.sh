#!/bin/sh
# Compile happy 1.19.5 with mhs + the ghc-on-mhs shims.
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
M="$R/MicroHs"
S="$R/build/happy-1.19.5/src"
# happy 1.19.5 from its release tarball (SOURCES.md), extracted if missing.
[ -d "$R/build/happy-1.19.5" ] || tar xzf "$R/happy-1.19.5.tar.gz" -C "$R/build"
export PATH="$M/bin:$PATH"
export HAPPY_DATADIR="$R/build/happy-1.19.5/templates"
INC="-i$R/happy/noglr -i$R/common/shims -i$R/happy/shim -i$S"
mkdir -p "$R/build/happy-mhs" && cd "$R/build/happy-mhs" || exit 1

echo "== per-module =="
for f in "$S"/*.lhs "$S"/*.hs; do
  m=$(basename "$f"); m="${m%.*}"
  printf "%-20s " "$m"
  out=$("$M/bin/mhs" -C -c -fno-code -XCPP $INC "$m" 2>&1 | tr '\n' ' ')
  case "$out" in
    *"No code generated"*) echo OK ;;
    *) echo "$out" | sed 's|.*uncaught exception: ||' | cut -c1-180 ;;
  esac
done

echo
echo "== link =="
"$M/bin/mhs" -C -XCPP $INC Main -o"$R/build/happy-mhs/happy.c" 2>&1 \
  | sed 's|.*uncaught exception: ||' | head -6
ls -la "$R/build/happy-mhs/happy.c" 2>/dev/null
