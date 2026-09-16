#!/bin/sh
# Remove every interface file the pre-2026-09-16 stage-1 compiler wrote, and
# the .hc/.o derived alongside them, before rebuilding with the format-preserving
# patch 0004 (build/ghc622-stage2/LOG.md, "Patch 0004 made format-preserving").
# Necessary, not just tidy: GHC 6.2.2's recompilation checker opens an existing
# .hi before deciding to recompile, and the new reader misparses the old
# dictionary (the same 2^56-byte request stage 2 died of). .hi-boot files are
# sources and are kept. The result tsvs are kept under *-oldformat.tsv.
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
M="$R/build/ghc622-mhs"; S="$R/build/ghc622-stage2"
n() { printf '%s: %s files\n' "$1" "$2"; }
# stage-1-built base (libraries/base is a symlink to it from stage2/)
n "base .hi"  "$(find "$M/libraries/base" -name '*.hi' | wc -l)"
n "base .hc"  "$(find "$M/libraries/base" -name '*.hc' | wc -l)"
find "$M/libraries/base" \( -name '*.hi' -o -name '*.hc' \) -type f -delete
rm -f "$M/hcobj"/*.o "$M/hcobj"/*.o.log
[ -f "$M/base-results.tsv" ] && mv -f "$M/base-results.tsv" "$M/base-results-oldformat.tsv"
# haskell98
n "haskell98 .hi" "$(ls "$S/libraries/haskell98"/*.hi 2>/dev/null | wc -l)"
rm -f "$S/libraries/haskell98"/*.hi "$S/libraries/haskell98"/*.hc "$S/libraries/haskell98"/obj/*.o "$S/libraries/haskell98/libHShaskell98.a"
[ -f "$S/results-haskell98.tsv" ] && mv -f "$S/results-haskell98.tsv" "$S/results-haskell98-oldformat.tsv"
# stage 2 outputs (the .hi-boot symlinks stay)
n "stage2 .hi" "$(find "$S/stage2" -name '*.hi' -type f | wc -l)"
find "$S/stage2" \( -name '*.hi' -o -name '*.hc' \) -type f -delete
rm -f "$S/obj"/*.o
[ -f "$S/results.tsv" ] && mv -f "$S/results.tsv" "$S/results-oldformat.tsv"
[ -f "$S/ghc" ] && mv -f "$S/ghc" "$S/ghc.oldformat"
echo "clean-old-format: done"
