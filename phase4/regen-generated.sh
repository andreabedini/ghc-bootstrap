#!/bin/sh
# Regenerate GHC 6.2.2's happy- and genprimopcode-derived sources with the
# in-chain tools only (happy-mhs2, cpphs, an mhs-built genprimopcode), in
# portable form: no -agc, no GHC-specific template. Parameterised version of
# build/gen622/regen.sh (whose recipe was validated byte for byte against the
# 6.0 files, build/gen622/FINDINGS.md); writes into the tree in place.
#
#   sh phase4/regen-generated.sh <ghc-6.2.2 source root> <work dir>
#
# Writes, under <root>/ghc/compiler:
#   prelude/primops.txt          <- cpphs --noline --strip  prelude/primops.txt.pp
#   prelude/primop-*.hs-incl     <- genprimopcode (10 flags, as ghc/compiler/Makefile)
#   parser/Parser.hs parser/ParserCore.hs main/ParsePkgConf.hs  <- happy-mhs2 (no flags)
# Needs <root>/ghc/includes/config.h (MachDeps.h includes it; primops.txt.pp
# reads WORD_SIZE_IN_BITS from it), so run it after configure.
#
# genprimopcode is 6.2.2's own ghc/utils/genprimopcode/Main.hs compiled by mhs
# in <work>/genprimopcode with one edit (genprimopcode-Main.hs.patch: `not.dodgy`
# spaced), phase1/shims-h98 for Monad/Char/List/Maybe/System and the Parsec
# slice shim from build/shims-6.2.2-run1 (cpphs leaves __GLASGOW_HASKELL__
# undefined, so Main.hs takes its `import Parsec` branch).
set -eu
R=$(cd "$(dirname "$0")/.." && pwd)
P4=$R/phase4
SRC=$(cd "$1" && pwd)
WORK=$(mkdir -p "$2" && cd "$2" && pwd)
C=$SRC/ghc/compiler

export PATH="$R/MicroHs/bin:$PATH"                 # mhs, cpphs
export TMPDIR="$WORK/tmp"; mkdir -p "$TMPDIR"
export HAPPY_DATADIR="$R/build/happy-mhs/datadir"  # portable HappyTemplate (happy 1.19.5)
HAPPY=$R/build/happy-mhs/happy-mhs2                # the fixpoint-verified happy (phase2/FINDINGS.md)

# ---- genprimopcode ----------------------------------------------------------
G=$WORK/genprimopcode
if [ "${SKIP_GENPOC:-0}" != 1 ] || [ ! -x "$G/genprimopcode" ]; then
  mkdir -p "$G"
  cp "$SRC/ghc/utils/genprimopcode/Main.hs" "$G/Main.hs"
  patch -s "$G/Main.hs" "$P4/genprimopcode-Main.hs.patch"
  cp "$R/build/shims-6.2.2-run1/Parsec.hs" "$G/Parsec.hs"
  ( cd "$G" && mhs -XCPP -i. -i"$R/phase1/shims-h98" Main -ogenprimopcode )
fi

# ---- primops: cpphs (as the 6.0 run did), then the ten genprimopcode outputs --
# ghc/compiler/Makefile: `% : %.pp` runs $(CPP) -P -I$(GHC_INCLUDE_DIR); gcc's cpp
# does not reproduce the 6.0 file (tabs, comment bodies); cpphs --noline --strip does.
cpphs --noline --strip -I"$SRC/ghc/includes" "$C/prelude/primops.txt.pp" > "$C/prelude/primops.txt"
for pair in data-decl:data-decl primop-tag:tag primop-list:list \
            has-side-effects:has-side-effects out-of-line:out-of-line \
            commutable:commutable needs-wrapper:needs-wrapper can-fail:can-fail \
            strictness:strictness primop-primop-info:primop-info; do
  "$G/genprimopcode" "--${pair%%:*}" < "$C/prelude/primops.txt" > "$C/prelude/primop-${pair##*:}.hs-incl"
done

# ---- happy: no flags. GHC's build passes -agc (GHC_HAPPY_OPTS); we want the ---
# portable template. The .y files are NOT cpp'd first: the one `#include
# "HsVersions.h"` in each passes through into the .hs and is resolved when the
# .hs is compiled with CPP.
for y in main/ParsePkgConf parser/ParserCore parser/Parser; do
  printf '== happy %s.y\n' "$y"
  "$HAPPY" "$C/$y.y" -o "$C/$y.hs"
done
echo "== regenerated: primops.txt, 10 primop-*.hs-incl, 3 parsers"
