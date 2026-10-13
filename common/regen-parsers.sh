#!/bin/sh
# Put the tarball's generated parsers and lexers back under their grammars.
#
# GHC's source distributions ship every happy and alex output the build
# needs (the compiler's Parser.hs and Lexer.hs, the Cmm parser and lexer,
# ParserCore, genprimopcode's, hpc's, from 9.4 HaddockLex) and, since 6.10,
# the grammar each came from renamed `<name>.source`, so that a build never
# runs happy or alex (ghc.mk's sdist rule up to 9.4, Hadrian's
# Rules/SourceDist.hs after). That is generated code standing in for source.
# This script undoes it: every shipped generated module is moved to
# $SHIPPED/<its path> and its grammar gets its name back, so the tree's own
# rules (mk/suffix.mk on 6.10, rules/hs-suffix-rules-srcdir.mk on 6.12-9.4,
# Hadrian's generators after) regenerate the module with the happy and alex
# the build was configured with. A cpp'd grammar (Parser.y.pp, 6.10-7.8)
# is restored the same way; the Parser.y the build derives from it is
# generated too and is removed if shipped.
#
# Cabal's lexer (libraries/Cabal, 8.4 to 9.8) is the one generated module
# no GHC build rule makes: it is alex output committed in Cabal's own tree,
# and its Makefile's rule is `alex --latin1 --ghc` then `cat -s`. When that
# Makefile names it (LEXER_HS) and the grammar is there, it is regenerated
# here, with the alex on PATH. From 9.12 it ships as a .source like the rest.
#
# Usage, from the top of the unpacked tree, after patching and before
# configure:
#
#   SHIPPED=<dir> sh regen-parsers.sh      one line per module; exit 1 if a
#                                          .source has no shipped module
#
# cmp-regenerated.sh compares what the build then produced with $SHIPPED.
set -eu
: "${SHIPPED:?SHIPPED: where the shipped generated modules go}"

keep() {   # $1 = a shipped generated module: moved to $SHIPPED/$1
  mkdir -p "$SHIPPED/$(dirname "$1")"
  mv "$1" "$SHIPPED/$1"
}

dirs="compiler utils/genprimopcode utils/hpc libraries/Cabal"
n=0
for src in $(find $dirs -name '*.source' 2>/dev/null | sort); do
  case "$src" in */testsuite/*|*/tests/*) continue ;; esac
  grammar=${src%.source}
  case "$grammar" in
    *.y.pp) hs=${grammar%.y.pp}.hs; rm -f "${grammar%.pp}" ;;
    *.y|*.ly|*.x) hs=${grammar%.*}.hs ;;
    *) echo "regen-parsers: $src: not a grammar"; exit 1 ;;
  esac
  [ -f "$hs" ] || { echo "regen-parsers: $src: no shipped $hs"; exit 1; }
  keep "$hs"
  mv "$src" "$grammar"
  echo "regen-parsers: $hs: shipped; to be regenerated from $grammar"
  n=$((n + 1))
done

# A grammar shipped under its own name next to its output (6.10.4's
# genprimopcode): the suffix rule would keep the newer shipped module.
for grammar in $(find $dirs -name '*.y' -o -name '*.ly' -o -name '*.x' 2>/dev/null | sort); do
  case "$grammar" in */testsuite/*|*/tests/*|*/examples/*) continue ;; esac
  hs=${grammar%.*}.hs
  [ -f "$hs" ] || continue
  keep "$hs"
  echo "regen-parsers: $hs: shipped beside $grammar; to be regenerated from it"
  n=$((n + 1))
done

if [ -f libraries/Cabal/Makefile ]; then
  lexer_hs=$(sed -n 's/^LEXER_HS:=//p' libraries/Cabal/Makefile)
  lexer_x=$(sed -n 's/^\$(LEXER_HS) : //p' libraries/Cabal/Makefile)
  if [ -n "$lexer_hs" ] && [ -f "libraries/Cabal/$lexer_hs" ] && [ -f "libraries/Cabal/$lexer_x" ]; then
    keep "libraries/Cabal/$lexer_hs"
    (cd libraries/Cabal \
     && alex --latin1 --ghc -o "$lexer_hs" "$lexer_x" \
     && cat -s "$lexer_hs" > Lexer.tmp && mv Lexer.tmp "$lexer_hs")
    echo "regen-parsers: libraries/Cabal/$lexer_hs: shipped; regenerated now by alex --latin1 --ghc $lexer_x"
    n=$((n + 1))
  fi
fi

[ "$n" -gt 0 ] || { echo "regen-parsers: nothing shipped generated found"; exit 1; }
echo "regen-parsers: $n generated modules set aside under $SHIPPED"
