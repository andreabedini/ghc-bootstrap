#!/bin/sh
# Build ghc/utils/genapply with MicroHs and generate AutoApply.hc.
#
# ghc/rts/Makefile generates AutoApply.hc with $(GHC_GENAPPLY) unless
# BootingFromHc; the tarball does not ship it, and genapply is a Haskell
# program (GenApply.hs, 599 lines, Haskell 98 + CPP + Text.PrettyPrint).
# MicroHs 0.16 has no Text.PrettyPrint, so shim/ carries a 50-line one.
# genapply's Makefile adds -DNO_REGS when GhcUnregisterised=YES, which makes
# MachRegs.h report MAX_REAL_VANILLA_REG 0 -- the same view the RTS gets.
# mhs shells out to cpphs (in MicroHs/bin) and needs a writable TMPDIR.
set -eu
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
M="$R/MicroHs"
G="$R/build/rts622/ghc-6.2.2"
D="$R/build/rts622/genapply"

cd "$D"
mkdir -p tmp
cp "$G/ghc/utils/genapply/GenApply.hs" .
PATH="$M/bin:$PATH" TMPDIR="$D/tmp" \
  "$M/bin/mhs" -XCPP -D__GLASGOW_HASKELL__=622 -DNO_REGS \
     -I"$G/ghc/utils/genapply" -i. -ishim GenApply.hs -ogenapply
./genapply > AutoApply.hc
echo "genapply: wrote $D/AutoApply.hc ($(wc -l < AutoApply.hc) lines)"
