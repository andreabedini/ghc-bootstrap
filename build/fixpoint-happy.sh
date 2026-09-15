#!/bin/sh
# D7 discharge, done generationally (the MicroHs pattern), because the
# GHC-built happy is 1.19.12 and the source we bootstrap is 1.19.5: their
# outputs differ by happy's happyExpList feature, so equality with happy-ghc is
# the wrong test. The right test is that the chain reproduces *itself*.
#
#   gen1  parsers from happy-ghc      -> happy-mhs1   (already built)
#   gen2  happy-mhs1 regenerates them -> happy-mhs2
#   gen3  happy-mhs2 regenerates them -> compare with gen2
#
# gen2 == gen3 means the parsers are reproducible from happy's own .ly grammars
# by a compiler derived from the Hugs seed, and happy-ghc leaves the trusted base.
set -eu
R=/home/andrea/work/haskell/ghc-bootstrap
M="$R/MicroHs"; B="$R/build/happy-mhs"; S="$R/build/happy-1.19.5/src"
export PATH="$M/bin:$PATH"
export HAPPY_DATADIR="$B/datadir"

link() {   # $1 = output binary name
  cc -w -O1 -I"$M/src/runtime" -I"$M/src/runtime/unix" \
     "$M/src/runtime/main.c" "$M/src/runtime/eval.c" "$B/happy.c" -lm -o "$B/$1"
}
regen() {  # $1 = happy binary, $2 = destination dir
  mkdir -p "$2"
  (cd "$S" && "$B/$1" Parser.ly            -o "$2/Parser.hs")
  (cd "$S" && "$B/$1" AttrGrammarParser.ly -o "$2/AttrGrammarParser.hs")
}

echo "== gen2: happy-mhs1 regenerates happy's own parsers =="
regen happy-mhs "$B/gen2"
cp "$B/gen2/Parser.hs" "$B/gen2/AttrGrammarParser.hs" "$S/"

echo "== rebuild happy from its own output -> happy-mhs2 =="
"$R/build/link-happy.sh" >/dev/null
link happy-mhs2

echo "== gen3: happy-mhs2 regenerates them again =="
regen happy-mhs2 "$B/gen3"

echo
echo "== fixpoint =="
ok=yes
for n in Parser AttrGrammarParser; do
  if cmp -s "$B/gen2/$n.hs" "$B/gen3/$n.hs"; then
    echo "  IDENTICAL  $n.hs  ($(wc -l < "$B/gen2/$n.hs") lines)"
  else
    echo "  DIFFERS    $n.hs"; ok=no
    diff "$B/gen2/$n.hs" "$B/gen3/$n.hs" | head -10
  fi
done
[ "$ok" = yes ] && echo "  => happy is reproducible inside the chain (D7 discharged)"

echo
echo "== regenerate GHC 4.08.2's parsers with the in-chain happy =="
cd "$R/build/ghc-4.08.2/ghc/compiler"
"$B/happy-mhs2" parser/Parser.y     -o "$R/build/ghc-parsers/Parser.hs"
"$B/happy-mhs2" rename/ParseIface.y -o "$R/build/ghc-parsers/ParseIface.hs"
wc -l "$R/build/ghc-parsers"/*.hs
