#!/bin/sh
# Acceptance test 3: compile libraries/base/GHC/Base.lhs with a compiler
# (default: the stage-2 ghc) using exactly run-base.sh's flags, into
# cmp-base/<tag>/, and diff the .hc against stage 1's
# build/ghc622-mhs/libraries/base/GHC/Base.hc.  Unique numbering differs
# between compilers; the structural comparison normalises local names
# (r<uniq>, s<uniq>, a<uniq>, ...) before diffing.
#   GHC=<compiler> TAG=<name> sh compare-base.sh
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
S="$R/build/ghc622-stage2"
GHC="${GHC:-$S/ghc}"; TAG="${TAG:-stage2}"
BASE="$R/build/ghc622-mhs/libraries/base"
OUT="$S/cmp-base/$TAG"; mkdir -p "$OUT/GHC"
export TMPDIR="$S/tmp"
ulimit -s unlimited 2>/dev/null
cd "$BASE" || exit 1
start=$(date +%s.%N)
( ulimit -v 8000000; "$GHC" ${MHSRTS:-} "-B$S/topdir" -v1 -C \
    -fglasgow-exts -cpp -Iinclude '-#include' HsBase.h -funbox-strict-fields \
    -package-name base ${OPT:--O} -i"$BASE" -o "$OUT/GHC/Base.hc" -ohi "$OUT/GHC/Base.hi" GHC/Base.lhs ) > "$OUT/Base.log" 2>&1
rc=$?
printf 'compile GHC/Base.lhs with %s: rc=%s, %.1f s\n' "$GHC" "$rc" "$(echo "$(date +%s.%N) - $start" | bc)"
[ $rc = 0 ] || { tail -5 "$OUT/Base.log"; exit 1; }
wc -l "$BASE/GHC/Base.hc" "$OUT/GHC/Base.hc"
norm() { sed -E 's/\b([rsaxdwtv])[0-9A-Za-z]{2,5}\b/\1_/g; s/\b(_?[a-z]+[A-Z]?[a-z]*)[0-9]{2,}\b/\1_/g' "$1"; }
diff "$BASE/GHC/Base.hc" "$OUT/GHC/Base.hc" > "$OUT/raw.diff"; echo "raw diff: $(grep -c '^[<>]' "$OUT/raw.diff") changed lines"
norm "$BASE/GHC/Base.hc" > "$OUT/stage1.norm"; norm "$OUT/GHC/Base.hc" > "$OUT/stage2.norm"
diff "$OUT/stage1.norm" "$OUT/stage2.norm" > "$OUT/norm.diff"; echo "normalised diff: $(grep -c '^[<>]' "$OUT/norm.diff") changed lines (see $OUT/norm.diff)"
# symbol-level comparison: the set of defined C-level closures/info tables
for t in stage1:"$BASE/GHC/Base.hc" "$TAG":"$OUT/GHC/Base.hc"; do
  n=${t%%:*}; f=${t#*:}
  grep -oE '^(FN_|IF_|EF_|II_|ED_|SRT|C_HDR|II_|I_|IFN_|INFO_TABLE[A-Z_]*)\(?[A-Za-z0-9_]+' "$f" | sort -u > "$OUT/$n.syms"
done
echo "defined symbols: stage1 $(wc -l < "$OUT/stage1.syms"), $TAG $(wc -l < "$OUT/$TAG.syms"); only-in-stage1 $(comm -23 "$OUT/stage1.syms" "$OUT/$TAG.syms" | wc -l), only-in-$TAG $(comm -13 "$OUT/stage1.syms" "$OUT/$TAG.syms" | wc -l)"
