# The check that ties the alexes from the hand-written scanner to the ones
# the chain builds GHC with. On every alex grammar each chain alex is run
# on, the mhs-built alex traced back to the hand-written 2.1.0 scanner must
# give the same output, byte for byte:
#
#   ghc66.alex210 (6.2.2-compiled, from its tarball's Scan.hs), which makes
#   the lexers of GHC 6.6 to 7.4.2, against alex210ddc's alex 2.1.0
#
#   ghc74.alex327 (7.4.2-compiled, from its tarball's Scan.hs), which makes
#   those of GHC 7.8.4 to 9.14.1, against alexChain's alex 3.2.7.4; also on
#   alex's own Scan.x (each one's generated/Scan.hs)
#
# The GHC grammars are the *.x.source files (6.6 and 6.10's genprimopcode
# ship plain .x), run with `alex -g` as the GHC builds run them, and Cabal's
# lexer where it is a plain .x (8.4.4 to 9.8.4), run with `alex --latin1
# --ghc` as common/regen-parsers.sh runs it. A separate derivation, so that
# alex210ddc and alexChain do not depend on the GHC chain.
# Output: ref/ (the chain's alexes), ours/, report.txt.
{ lib
, stdenv
, alex210
, alex210ddc
, alexChain
, ghc
, ghc610
, ghc612
, ghc74
, ghc78
, ghc80
, ghc84
, ghc88
, ghc90
, ghc94
, ghc98
, ghc912
, ghc914
}:
let
  alex2 = { ref = alex210; ours = alex210ddc; };
  alex3 = { ref = ghc74.alex327; ours = alexChain; };
  ghcLexers = [ "compiler/cmm/CmmLex.x" "compiler/parser/Lexer.x" "utils/genprimopcode/Lexer.x" ];
  ghcLexers9 = [ "compiler/GHC/Cmm/Lexer.x" "compiler/GHC/Parser/Lexer.x" "utils/genprimopcode/Lexer.x" ];
  haddockLex = "compiler/GHC/Parser/HaddockLex.x";
  stringLex = "compiler/GHC/Parser/Lexer/String.x";
  cabalLex = "libraries/Cabal/Cabal-syntax/src/Distribution/Fields/Lexer.x";
  # per release: the alexes, the tarball, its *.x.source files (named
  # without .source), and its grammars that ship as a plain .x
  grammars = [
    { a = alex2; v = "6.6";    src = ghc.src;    tar = "j"; xs = [ ];
      plain = [ "compiler/cmm/CmmLex.x" "compiler/parser/Lexer.x" ]; }
    { a = alex2; v = "6.10.4"; src = ghc610.src; tar = "j";
      xs = [ "compiler/cmm/CmmLex.x" "compiler/parser/Lexer.x" "compiler/parser/HaddockLex.x" ];
      plain = [ "utils/genprimopcode/Lexer.x" ]; }
    { a = alex2; v = "6.12.3"; src = ghc612.src; tar = "j";
      xs = ghcLexers ++ [ "utils/haddock/src/Haddock/Interface/Lex.x" ]; }
    { a = alex2; v = "7.4.2";  src = ghc74.src;  tar = "j";
      xs = ghcLexers ++ [ "utils/haddock/src/Haddock/Lex.x" ]; }
    { a = alex3; v = "7.8.4";  src = ghc78.src;  xs = ghcLexers; }
    { a = alex3; v = "8.0.2";  src = ghc80.src;  xs = ghcLexers; }
    { a = alex3; v = "8.4.4";  src = ghc84.src;  xs = ghcLexers; cabal = "libraries/Cabal/boot/Lexer.x"; }
    { a = alex3; v = "8.8.4";  src = ghc88.src;  xs = ghcLexers; cabal = "libraries/Cabal/boot/Lexer.x"; }
    { a = alex3; v = "9.0.2";  src = ghc90.src;  xs = ghcLexers9; cabal = "libraries/Cabal/boot/Lexer.x"; }
    { a = alex3; v = "9.4.8";  src = ghc94.src;  xs = ghcLexers9 ++ [ haddockLex ]; cabal = "libraries/Cabal/templates/Lexer.x"; }
    { a = alex3; v = "9.8.4";  src = ghc98.src;  xs = ghcLexers9 ++ [ haddockLex ]; cabal = "libraries/Cabal/templates/Lexer.x"; }
    { a = alex3; v = "9.12.4"; src = ghc912.src; xs = ghcLexers9 ++ [ haddockLex stringLex cabalLex ]; }
    { a = alex3; v = "9.14.1"; src = ghc914.src; xs = ghcLexers9 ++ [ haddockLex stringLex cabalLex ]; }
  ];
  both = g: flags: x: ''
    o=${g.v}_$(echo ${x} | tr / _).hs
    (cd src/${g.v} && ${g.a.ref}/bin/alex ${flags} ${x} -o $NIX_BUILD_TOP/ref/$o)
    (cd src/${g.v} && ${g.a.ours}/bin/alex ${flags} ${x} -o $NIX_BUILD_TOP/ours/$o)
  '';
  one = g: let plain = g.plain or [ ]; in ''
    mkdir -p src/${g.v}
    tar x${g.tar or "J"}f ${g.src} -C src/${g.v} --strip-components=1 \
      ${lib.concatMapStringsSep " " (x: "ghc-${g.v}/${x}.source") g.xs} \
      ${lib.concatMapStringsSep " " (x: "ghc-${g.v}/${x}") plain} \
      ${lib.optionalString (g ? cabal) "ghc-${g.v}/${g.cabal}"}
    for x in ${lib.concatStringsSep " " g.xs}; do mv src/${g.v}/$x.source src/${g.v}/$x; done
    ${lib.concatMapStrings (both g "-g") (g.xs ++ plain)}
    ${lib.optionalString (g ? cabal) (both g "--latin1 --ghc" g.cabal)}
  '';
in
stdenv.mkDerivation {
  name = "alex-chain-ghc-lexers";
  dontUnpack = true;
  buildPhase = ''
    runHook preBuild
    cd $NIX_BUILD_TOP; mkdir ref ours
    ${lib.concatMapStrings one grammars}
    runHook postBuild
  '';
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    cd $NIX_BUILD_TOP
    {
      for o in $(ls ref); do
        cmp ref/$o ours/$o
        echo "$o: identical ($(wc -l < ref/$o) lines)"
      done
      echo "$(ls ref | wc -l) grammars: alex210ddc agrees with ghc66.alex210 (6.6 to 7.4.2)," \
           "alexChain with ghc74.alex327 (7.8.4 to 9.14.1)"
      cmp ${ghc74.alex327}/share/generated/Scan.hs ${alexChain}/generated/Scan.hs
      echo "alex 3.2.7.4's own Scan.hs (-g, grammar/Scan.x): alexChain's is ghc74.alex327's"
    } | tee report.txt
    runHook postCheck
  '';
  installPhase = ''
    mkdir -p $out; cp -r $NIX_BUILD_TOP/ref $NIX_BUILD_TOP/ours $NIX_BUILD_TOP/report.txt $out/
  '';
}
