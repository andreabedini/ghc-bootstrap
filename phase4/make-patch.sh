#!/bin/sh
# Regenerate phase4/patches/ from a working GHC 6.2.2 compiler tree.
#
#   sh phase4/make-patch.sh [tree]      default tree: build/ghc-6.2.2-run1
#
# The tree is read only. The pristine reference is a fresh extraction of
# ghc-6.2.2-src.tar.bz2 (made under $WORK, default build/repro-622/make-patch),
# never an old extraction lying around in build/.
#
# What is NOT in the patches, because the reproduction script generates it
# (the same exclusion list build/6.2.2-run1.patch used, see
# build/ghc-6.2.2-run1/FINDINGS.md "Patch"):
#   prelude/primops.txt, prelude/primop-*.hs-incl   genprimopcode (regen-generated.sh)
#   parser/Parser.hs parser/ParserCore.hs main/ParsePkgConf.hs   happy (regen-generated.sh)
#   parser/Lexer.hs                                  convert-lexer.py
#   utils/ghc-pkg                                    symlink to ../../utils/ghc-pkg
#   tmp                                              mhs scratch
# Anything else that differs from the pristine tree must be claimed by a class
# in series.conf, or split-patch.py stops and names the hunk.
#
# After writing the series it applies it to a second pristine copy and diffs
# the result against the tree (with the same exclusions): the patches must
# apply with no fuzz and no offset and reproduce the tree byte for byte.
set -eu
R=$(cd "$(dirname "$0")/.." && pwd)
P4=$R/phase4
TREE=$(cd "${1:-$R/build/ghc-6.2.2-run1}" && pwd)
WORK=${WORK:-$R/build/repro-622/make-patch}
TARBALL=$R/ghc-6.2.2-src.tar.bz2

rm -rf "$WORK"; mkdir -p "$WORK/tmp" "$WORK/pristine" "$WORK/check"
export TMPDIR="$WORK/tmp"           # patch(1) needs a writable one
tar xjf "$TARBALL" -C "$WORK/pristine"
PRISTINE=$WORK/pristine/ghc-6.2.2

set -- --exclude 'primop-*.hs-incl' --exclude primops.txt \
       --exclude Parser.hs --exclude ParserCore.hs --exclude ParsePkgConf.hs \
       --exclude Lexer.hs --exclude tmp --exclude ghc-pkg --exclude .claude

python3 "$P4/split-patch.py" --pristine "$PRISTINE" --tree "$TREE" \
        --conf "$P4/series.conf" --out "$P4/patches" "$@"

# ---- self-check: apply the series to a clean copy and compare ---------------
mkdir -p "$WORK/check/ghc"
cp -a "$PRISTINE/ghc/compiler" "$WORK/check/ghc/compiler"
cd "$WORK/check"
for p in "$P4"/patches/*.patch; do
  out=$(patch -p1 -N -i "$p" 2>&1) || { printf '%s\n' "$out"; echo "FAILED: $p"; exit 1; }
  case "$out" in *fuzz*|*offset*) printf '%s\n' "$out"; echo "INEXACT: $p"; exit 1 ;; esac
done
diff -r -x 'primop-*.hs-incl' -x primops.txt -x Parser.hs -x ParserCore.hs \
        -x ParsePkgConf.hs -x Lexer.hs -x tmp -x ghc-pkg -x .claude \
        "$WORK/check/ghc/compiler" "$TREE/ghc/compiler"
echo "series applies exactly and reproduces $TREE/ghc/compiler"
ls "$P4"/patches/*.patch | wc -l | sed 's/^/patches: /'
