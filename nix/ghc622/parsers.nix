# The three happy grammars, with the portable template (no -agc), then the
# 6.2.2 fix-ups of phase4/fix-generated-parsers.sh. Output: main/ and parser/,
# relative to ghc/compiler.
{ runCommand, happy, ghc622-src }:
runCommand "ghc-6.2.2-parsers" { nativeBuildInputs = [ happy ]; } ''
  ys="main/ParsePkgConf parser/ParserCore parser/Parser"
  tar xjf ${ghc622-src} --strip-components=3 $(for y in $ys; do echo ghc-6.2.2/ghc/compiler/$y.y; done)
  for y in $ys; do
    mkdir -p $out/$(dirname $y)
    happy $y.y -o $out/$y.hs
    sh ${../../phase4/fix-generated-parsers.sh} $out/$y.hs
  done
''
