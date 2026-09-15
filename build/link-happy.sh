#!/bin/sh
# Fast iteration: one mhs invocation that pulls in the whole import graph.
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
M="$R/MicroHs"; S="$R/build/happy-1.19.5/src"
export PATH="$M/bin:$PATH"
mkdir -p "$R/build/happy-mhs" && cd "$R/build/happy-mhs" || exit 1
"$M/bin/mhs" -C -XCPP -i"$R/phase2/happy-noglr" -i"$R/phase1/shims" -i"$R/phase1/happy-shim" -i"$S" \
  Main -o"$R/build/happy-mhs/happy.c" 2>&1 | sed 's|.*uncaught exception: ||' | head -6
ls -la "$R/build/happy-mhs/happy.c" 2>/dev/null || echo "  (no output produced)"
