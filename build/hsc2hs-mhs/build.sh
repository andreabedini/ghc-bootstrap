#!/bin/sh
# Build GHC 6.2.2's hsc2hs (ghc/utils/hsc2hs/Main.hs, "hsc2hs version 0.65") with mhs.
#
#   sh build/hsc2hs-mhs/build.sh          -> build/hsc2hs-mhs/hsc2hs-bin  (~1 min)
#
# Layout mirrors the tarball so Main.hs's `#include "../../includes/config.h"` resolves
# unchanged: ghc/utils/hsc2hs/{Main.hs,Config.hs,template-hsc.h,hsc2hs.sh} and
# ghc/includes -> build/ghc-6.2.2-run1/ghc/includes (our x86_64 config.h; hsc2hs only
# tests mingw32_HOST_OS in it).  Main.hs is a copy of the tarball's with the Parser
# instances split into Functor/Applicative/Monad/MonadFail/Alternative (edits marked
# `-- mhs`, see FINDINGS.md).  Config.hs is what the Makefile's $(CONFIG_HS) rule writes.
#
# -D__GLASGOW_HASKELL__=622 takes the `>= 504` import branch (System.Console.GetOpt,
# which MicroHs has) instead of the hslibs-era `GetOpt`.  shims/System.hs supplies H98
# System's `system`; ghc622/shims-h98 supplies Directory/Monad/Char/List/IO.
#
# The driver script `hsc2hs` (hsc2hs.sh with the Makefile's SCRIPT_SUBST_VARS filled in)
# adds --template, --cc/--ld=gcc, --cflag=-std=gnu89, --cflag=-D__GLASGOW_HASKELL__=622
# and -I<ghc/includes>; it is hand-written, not generated here.
set -eu
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
H="$R/build/hsc2hs-mhs"
export TMPDIR="$H/tmp"; mkdir -p "$TMPDIR"
export PATH="$R/MicroHs/bin:$PATH"          # mhs and its cpphs
# The tarball's sources with ghc622/hsc2hs/Main.hs.patch and the Makefile's
# Config.hs, from the configured tree ghc622/reproduce-6.2.2.sh leaves (TREE622).
sh "$R/ghc622/tools/hsc2hs-src.sh" "${TREE622:-$R/build/repro-622/src/ghc-6.2.2}" \
  "$R/ghc622/hsc2hs/Main.hs.patch" "$H/ghc/utils/hsc2hs"
cd "$H/ghc/utils/hsc2hs"
mhs -XCPP -D__GLASGOW_HASKELL__=622 -i. -i"$R/ghc622/hsc2hs/shims" -i"$R/ghc622/shims-h98" Main -o"$H/hsc2hs-bin"
cp template-hsc.h "$H/template-hsc.h"      # the wrapper's --template
"$H/hsc2hs-bin" --version
