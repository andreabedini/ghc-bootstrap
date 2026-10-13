#!/bin/sh
# Compare the parsers and lexers a build regenerated with the ones its
# tarball shipped (set aside by regen-parsers.sh).
#
# For each file under $SHIPPED the regenerated one is looked for among the
# build's `*/build/*` outputs (make: compiler/stage1/build/Parser.hs,
# utils/hpc/dist-install/build/...; Hadrian: _build/stage0/compiler/build/
# GHC/Parser.hs; 6.10's Cabal: compiler/dist-stage1/build/...), by the
# longest tail of the shipped path that matches. The two are compared as
# ghc66/cmp-generated.sh does, ignoring blank lines, LINE pragmas and raw
# cpp line markers; the rule is repeated here rather than called, because
# a Nix caller copies this file into the store on its own.
#
# What the comparison means depends on versions. A happy output names the
# happy that wrote it ("parser produced by Happy Version X"); when X is the
# version of the happy on PATH the two must agree, and a difference fails
# the build. Otherwise, and for alex output, which carries no version, the
# difference is reported and counted but does not fail: the point of
# regenerating is that the build no longer depends on the shipped file,
# the agreement is evidence on top. ALEX_STRICT=1 makes alex output fail
# too (for a rung whose shipping alex is the one on PATH).
#
# Usage, from the top of the built tree:
#
#   SHIPPED=<dir> sh cmp-regenerated.sh
set -u
: "${SHIPPED:?SHIPPED: where regen-parsers.sh put the shipped modules}"
norm() { grep -v -E -e '^[[:space:]]*$' -e '^\{-# LINE [0-9]+ "[^"]*" #-\}$' -e '^# [0-9]+ "[^"]*"( [0-9]+)*$' "$1"; }
happy_version=$(happy --version 2>/dev/null | sed -n 's/^Happy Version \([0-9.]*\).*/\1/p')

agree=0; differ=0; missing=0; failed=0
for s in $(cd "$SHIPPED" && find . -type f | sed 's|^\./||' | sort); do
  # The regenerated file: the candidate under */build/* with the longest
  # matching tail of $s (GHC/Cmm/Parser.hs before Parser.hs). Of those, prefer the ones under the
  # shipped file's package directory (utils/genprimopcode/Parser.hs and
  # utils/hpc/.../Parser.hs both end in Parser.hs); Hadrian's
  # _build/stage0/libraries/Cabal-syntax/... has no such prefix, so fall
  # back to the tail alone. A module regenerated in place (Cabal's lexer,
  # regen-parsers.sh) is found at its own path.
  pkgdir=$(printf '%s' "$s" | cut -d/ -f1-2)
  gen=""
  tail=$s
  while [ -n "$tail" ]; do
    cands=$(find . -path '*/build/*' -path "*/$tail" -type f 2>/dev/null | grep -v "^./$s\$" | sort)
    if [ -n "$cands" ]; then
      gen=$(printf '%s\n' "$cands" | grep "/$pkgdir/" | head -1)
      [ -n "$gen" ] || gen=$(printf '%s\n' "$cands" | head -1)
      break
    fi
    case "$tail" in */*) tail=${tail#*/} ;; *) tail="" ;; esac
  done
  [ -n "$gen" ] || { [ -f "$s" ] && gen=$s; }
  if [ -z "$gen" ]; then
    echo "cmp-regenerated: $s: no regenerated file found under */build/*"
    missing=$((missing + 1)); continue
  fi
  shipped_by=$(sed -n 's/^-- parser produced by Happy Version \([0-9.]*\).*/\1/p' "$SHIPPED/$s" | head -1)
  strict=0
  if [ -n "$shipped_by" ]; then
    [ "$shipped_by" = "$happy_version" ] && strict=1
    by="happy $shipped_by"
  else
    [ "${ALEX_STRICT:-0}" = 1 ] && strict=1
    by="alex"
  fi
  norm "$SHIPPED/$s" > "$SHIPPED/.a.norm"; norm "$gen" > "$SHIPPED/.b.norm"
  if cmp -s "$SHIPPED/.a.norm" "$SHIPPED/.b.norm"; then
    echo "cmp-regenerated: $s: regenerated ($gen) agrees with the shipped one (by $by)"
    agree=$((agree + 1))
  else
    n=$(diff "$SHIPPED/.a.norm" "$SHIPPED/.b.norm" | grep -c '^[<>]')
    if [ "$strict" = 1 ]; then
      echo "cmp-regenerated: $s: DIFFERS from the shipped one (by $by, the happy on PATH is $happy_version): $n lines"
      diff "$SHIPPED/.a.norm" "$SHIPPED/.b.norm" | head -20
      failed=$((failed + 1))
    else
      echo "cmp-regenerated: $s: differs from the shipped one (by $by; happy on PATH ${happy_version:-?}): $n lines, not compared strictly"
      differ=$((differ + 1))
    fi
  fi
  rm -f "$SHIPPED/.a.norm" "$SHIPPED/.b.norm"
done
echo "cmp-regenerated: $agree agree, $differ differ (other generator version), $failed differ (same version), $missing not found"
[ "$failed" -eq 0 ] && [ "$missing" -eq 0 ]
