#!/bin/sh
# Compile one module by hand with run-compiler.sh's flags (sh, so $IDIRS splits).
#   sh compile-one.sh <source path (abs or rel to compiler root)> <module> <dir> [extra flags...]
# Output: $OUTDIR/<dir>/<module>.{hc,hi}; log on stdout/stderr.
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
S="$R/build/ghc622-stage2"
GHC="${GHC:-$R/build/ghc622-mhs/ghc}"
SRC="$S/src/ghc-6.2.2/ghc/compiler"
ODIR="${OUTDIR:-$S/stage2}"
export TMPDIR="$S/tmp"
ulimit -s unlimited 2>/dev/null
src=$1; m=$2; dir=$3; shift 3
IDIRS=""
for d in utils basicTypes types hsSyn prelude rename typecheck deSugar coreSyn specialise simplCore stranal stgSyn simplStg codeGen absCSyn main profiling parser cprAnalysis compMan ndpFlatten; do IDIRS="$IDIRS -i$ODIR/$d"; done
cd "$SRC" || exit 1
exec "$GHC" ${MHSRTS:-+RTS -K50M -RTS} "-B$S/topdir" ${VERB:--v1} -C \
  -cpp -fglasgow-exts -I. -IcodeGen -InativeGen -Iparser -DOMIT_NATIVE_CODEGEN \
  '-#include' '"hschooks.h"' -recomp $IDIRS "$@" -o "$ODIR/$dir/$m.hc" -ohi "$ODIR/$dir/$m.hi" "$src"
