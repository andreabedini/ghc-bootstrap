#!/bin/sh
# Diverse double compilation for happy's parsers (D7's open gap, issue #2).
# happy/happy-seed/ is a fixed point of a seed that a GHC-built happy wrote.
# This starts again from an unrelated seed, the Parser.hs that happy 1.14
# wrote and that happy's repository commits at the Happy_1_15 tag:
#
#   happy115  happy 1.15, compiled by mhs from that Parser.hs
#   genA      happy115 generates happy 1.19.5's two parsers
#   happyA    happy 1.19.5 compiled by mhs from genA
#   genB      happyA regenerates them -> must equal happy/happy-seed/
#
# genA is not compared with anything: 1.15 writes different code from 1.19.5.
# The patch is the source part of the one posted on issue #2.
# happy/ddc115.nix is the same check in Nix (nix-build -A happy.ddc115).
# Needs MHS and CPPHS: the store paths of `nix-build -A mhs -A cpphs`.
set -eu
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
M="${MHS:?store path of nix-build -A mhs}"
export PATH="$M/bin:${CPPHS:?store path of nix-build -A cpphs}/bin:$PATH"
W="$R/build/happy-ddc115"
rm -rf "$W/happy-Happy_1_15" "$W/happy-1.19.5" "$W/h115" "$W/h1195" "$W/genA" "$W/genB"
mkdir -p "$W/h115/data/templates" "$W/h1195/data" "$W/genA" "$W/genB"
tar xzf "$R/happy-Happy_1_15.tar.gz" -C "$W"
tar xzf "$R/happy-1.19.5.tar.gz" -C "$W"
S115="$W/happy-Happy_1_15/src"; S1195="$W/happy-1.19.5/src"

link() {   # $1 = mhs C output, $2 = binary
  ${CC:-gcc} -w -O1 -I"$M/src/runtime" -I"$M/src/runtime/unix" \
     "$M/src/runtime/main.c" "$M/src/runtime/eval.c" "$1" -lm -o "$2"
}

echo "== happy 1.15 by mhs =="
(cd "$W/happy-Happy_1_15" && patch -p1 < "$R/happy/ddc115/happy-1.15-mhs.patch")
head -6 "$S115/Parser.hs" | grep 'produced by'
cpphs --noline "$W/happy-Happy_1_15/templates/GenericTemplate.hs" > "$W/h115/data/templates/HappyTemplate"
(cd "$W/h115" && mhs -XCPP -i"$R/happy/ddc115" -i"$R/common/shims" -i"$S115" Main -ohappy.c)
link "$W/h115/happy.c" "$W/h115/happy"

echo "== happy 1.15 regenerates its own parser (report only) =="
(cd "$S115" && HAPPY_DATADIR="$W/h115/data" "$W/h115/happy" Parser.ly -o "$W/h115/Parser.hs")
diff "$S115/Parser.hs" "$W/h115/Parser.hs" > "$W/h115/Parser.diff" && echo "  identical to the shipped one" \
  || echo "  differs from the shipped one in $(grep -c '^[<>]' "$W/h115/Parser.diff") lines, see $W/h115/Parser.diff"

echo "== genA: happy 1.15 generates happy 1.19.5's parsers =="
for p in Parser AttrGrammarParser; do
  (cd "$S1195" && HAPPY_DATADIR="$W/h115/data" "$W/h115/happy" $p.ly -o "$W/genA/$p.hs")
  head -12 "$W/genA/$p.hs" | grep 'produced by'
done

echo "== happyA: happy 1.19.5 by mhs from genA =="
cpphs --noline "$W/happy-1.19.5/templates/GenericTemplate.hs" > "$W/h1195/data/HappyTemplate"
cp "$W/genA/Parser.hs" "$W/genA/AttrGrammarParser.hs" "$S1195/"
(cd "$W/h1195" && mhs -XCPP -i"$R/happy/noglr" -i"$R/common/shims" -i"$R/happy/shim" -i"$S1195" Main -ohappy.c)
link "$W/h1195/happy.c" "$W/h1195/happy"

echo "== genB: happyA regenerates them =="
for p in Parser AttrGrammarParser; do
  (cd "$S1195" && rm -f $p.hs && HAPPY_DATADIR="$W/h1195/data" "$W/h1195/happy" $p.ly -o "$W/genB/$p.hs")
done

echo
echo "== genB against happy/happy-seed =="
ok=yes
for p in Parser AttrGrammarParser; do
  if cmp -s "$W/genB/$p.hs" "$R/happy/happy-seed/$p.hs"; then
    echo "  IDENTICAL  $p.hs  ($(wc -l < "$W/genB/$p.hs") lines)"
  else
    echo "  DIFFERS    $p.hs"; ok=no
    diff "$R/happy/happy-seed/$p.hs" "$W/genB/$p.hs" | head -20
  fi
done
[ "$ok" = yes ] && echo "  => two unrelated seeds give the same parsers"
[ "$ok" = yes ]
