#!/bin/sh
# Regression check for the .hi wire format (build/ghc622-stage2/LOG.md,
# 2026-09-16): compile a module that needs only GHC.Base with the stage-1
# compiler and decode its dictionary as the pristine reader would.
# Exit status: 0 iff every dictionary length is sane.
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
W="$R/build/ghc622-mhs"
cd "$W/test" || exit 1
rm -f FmtCheck.hi FmtCheck.hc
ulimit -s unlimited 2>/dev/null
timeout 600 "$W/ghc" +RTS -K5M -RTS "-B$W/topdir" -C -fglasgow-exts -package-name base FmtCheck.hs || exit 1
python3 "$W/test/hidict.py" FmtCheck.hi 8
