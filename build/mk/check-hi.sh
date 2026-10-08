#!/bin/sh
# Fail unless the interface file's FastString dictionary decodes in the
# pristine GHC 6.2.2 format (build/ghc622-stage2/LOG.md, 2026-09-16: the
# stage-1 compiler once wrote a String encoding a pristine stage 2 could not
# read). Prints a three-line summary. Used after every compile in build/mk.
#   sh build/mk/check-hi.sh <file.hi> [Module.Name]   (entry 0 must be the module)
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
exec python3 "$R/ghc622/tools/hidict.py" "$1" 0 ${2:+"$2"}
