#!/bin/sh
# Fast iteration: one mhs invocation that pulls in the whole import graph.
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
M="$R/MicroHs"; S="$R/build/happy-1.19.5/src"
# happy 1.19.5 from its release tarball (SOURCES.md), extracted if missing.
[ -d "$R/build/happy-1.19.5" ] || tar xzf "$R/happy-1.19.5.tar.gz" -C "$R/build"
export PATH="$M/bin:$PATH"
mkdir -p "$R/build/happy-mhs" && cd "$R/build/happy-mhs" || exit 1
"$M/bin/mhs" -C -XCPP -i"$R/happy/noglr" -i"$R/common/shims" -i"$R/happy/shim" -i"$S" \
  Main -o"$R/build/happy-mhs/happy.c" 2>&1 | sed 's|.*uncaught exception: ||' | head -6
ls -la "$R/build/happy-mhs/happy.c" 2>/dev/null || echo "  (no output produced)"
