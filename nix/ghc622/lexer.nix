# parser/Lexer.hs as shipped (alex -g output) with its Addr# tables decoded
# into boxed arrays (build/lexer622/FINDINGS.md). Output: the file itself.
{ runCommand, python3, ghc622-src }:
runCommand "ghc-6.2.2-Lexer.hs" { nativeBuildInputs = [ python3 ]; } ''
  tar xjf ${ghc622-src} --strip-components=4 ghc-6.2.2/ghc/compiler/parser/Lexer.hs
  python3 ${../../phase4/convert-lexer.py} Lexer.hs $out
''
