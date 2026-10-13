#!/bin/sh
# Regenerate GHC 6.2.2's happy- and genprimopcode-derived sources with the
# in-chain tools only (happy-mhs2, cpphs, an mhs-built genprimopcode), in
# portable form: no -agc, no GHC-specific template.
#
#   parser/Parser.hs, parser/ParserCore.hs, main/ParsePkgConf.hs   <- happy-mhs2 (no flags)
#   prelude/primops.txt          <- cpphs --noline --strip  primops.txt.pp
#   prelude/primop-*.hs-incl     <- genprimopcode (10 flags, as ghc/compiler/Makefile)
#
# Recipe validated on 6.0 (byte-identical to build/ghc-6.0-run2): VALIDATE60=1 sh regen.sh
# SKIP_GENPOC=1 reuses an already built genprimopcode/genprimopcode.
set -eu
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
B=$R/build
G=$B/gen622                                   # this directory: all output lands here
SRC=$B/rebase622/ghc-6.2.2/ghc/compiler       # pristine 6.2.2 inputs (read-only)
INC=$B/rebase622/ghc-6.2.2/ghc/includes       # MachDeps.h (pristine)
GENPOC_SRC=$B/ghc-6.2.2/ghc/utils/genprimopcode/Main.hs   # pristine 6.2.2 tarball
CONFIG_INC=${TREE622:-$B/repro-622/src/ghc-6.2.2}/ghc/includes   # configure's config.h (ghc622/reproduce-6.2.2.sh)

export PATH="$R/MicroHs/bin:$PATH"
export TMPDIR="$G/tmp"; mkdir -p "$TMPDIR"
export HAPPY_DATADIR="$B/happy-mhs/datadir"   # portable HappyTemplate (happy 1.19.5)
HAPPY=$B/happy-mhs/happy-mhs2                 # the fixpoint-verified happy (notes/phase2/FINDINGS.md)

# ---- genprimopcode: 6.2.2's own utils/genprimopcode/Main.hs, compiled by mhs -------
# Main.hs imports the H98 modules Monad/Char/List/Maybe/System (ghc622/shims-h98)
# and, with __GLASGOW_HASKELL__ undefined under cpphs, the old `Parsec` module
# (ghc622/shims/Parsec.hs: the slice-of-Parsec shim written for 6.0's run2).
if [ "${SKIP_GENPOC:-0}" != 1 ] && [ "${VALIDATE60:-0}" != 1 ]; then
  mkdir -p "$G/genprimopcode"
  cp "$GENPOC_SRC" "$G/genprimopcode/Main.hs"
  patch -s "$G/genprimopcode/Main.hs" "$R/ghc622/tools/genprimopcode-Main.hs.patch"
  cp "$R/ghc622/shims/Parsec.hs" "$G/genprimopcode/Parsec.hs"
  ( cd "$G/genprimopcode" && mhs -XCPP -i. -i"$R/ghc622/shims-h98" Main -ogenprimopcode )
fi
GENPOC=$G/genprimopcode/genprimopcode

# ---- primops: cpphs (as the 6.0 run did), then the ten genprimopcode outputs ---------
# ghc/compiler/Makefile: `% : %.pp` runs $(CPP) -P -I$(GHC_INCLUDE_DIR); MachDeps.h
# pulls in config.h, which configure writes: $CONFIG_INC/config.h, 6.2.2's x86_64
# configure output (SIZEOF_VOID_P 8 -> WORD_SIZE_IN_BITS 64). A hand-transcribed
# copy used to sit in gen622/includes; it differed only in whitespace and
# CONST_EFTYPE, neither of which reaches primops.txt. The reproduced tree's
# config.h also carries the HTYPE block (D47), which adds trailing blank lines
# to primops.txt; genprimopcode ignores them.
gen_primops() {   # $1 = compiler src dir, $2 = includes dir, $3 = output dir, $4 = genprimopcode
  mkdir -p "$3/prelude"
  cpphs --noline --strip -I"$CONFIG_INC" -I"$2" "$1/prelude/primops.txt.pp" > "$3/prelude/primops.txt"
  for pair in data-decl:data-decl primop-tag:tag primop-list:list \
              has-side-effects:has-side-effects out-of-line:out-of-line \
              commutable:commutable needs-wrapper:needs-wrapper can-fail:can-fail \
              strictness:strictness primop-primop-info:primop-info; do
    "$4" "--${pair%%:*}" < "$3/prelude/primops.txt" > "$3/prelude/primop-${pair##*:}.hs-incl"
  done
}

# ---- happy: no flags. GHC's build passes -agc (GHC_HAPPY_OPTS); we want the ----------
# portable template. The .y files are NOT cpp'd first: the one `#include "HsVersions.h"`
# in each passes through into the .hs and is resolved when the .hs is compiled with CPP.
gen_parsers() {   # $1 = compiler src dir, $2 = output dir
  mkdir -p "$2/parser" "$2/main"
  for y in main/ParsePkgConf parser/ParserCore parser/Parser; do
    printf '== happy %s.y\n' "$y"
    "$HAPPY" "$1/$y.y" -o "$2/$y.hs"
    sh "$R/ghc622/tools/fix-generated-parsers.sh" "$2/$y.hs"
  done
}

if [ "${VALIDATE60:-0}" = 1 ]; then
  V=$TMPDIR/val60; rm -rf "$V"; mkdir -p "$V"
  SRC60=$B/rebase622/ghc-6.0/ghc/compiler; REF60=$B/ghc-6.0-run2/ghc/compiler
  # 6.0's genprimopcode (build/genprimopcode) predates maxPrimOpTag; its outputs are
  # the reference. The 6.2.2 build adds one line to primop-tag.hs-incl, nothing else.
  gen_primops "$SRC60" "$B/ghc-6.0-run2/ghc/includes" "$V" "$B/genprimopcode/genprimopcode"
  gen_parsers "$SRC60" "$V"
  echo "== 6.0 validation against $REF60"
  ok=yes
  for f in prelude/primops.txt "$V"/prelude/primop-*.hs-incl main/ParsePkgConf.hs parser/ParserCore.hs parser/Parser.hs; do
    f=${f#"$V"/}
    if cmp -s "$V/$f" "$REF60/$f"; then printf '  IDENTICAL %s\n' "$f"; else printf '  DIFFERS   %s\n' "$f"; ok=no; fi
  done
  [ "$ok" = yes ] && echo "  => recipe reproduces the 6.0 generated files byte for byte"
  exit 0
fi

gen_primops "$SRC" "$INC" "$G" "$GENPOC"
gen_parsers "$SRC" "$G"
echo "== done"; wc -c "$G"/prelude/primops.txt "$G"/prelude/primop-*.hs-incl "$G"/main/ParsePkgConf.hs "$G"/parser/*.hs
