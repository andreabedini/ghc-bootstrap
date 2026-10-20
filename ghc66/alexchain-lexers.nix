# The check on alexchain.nix's alex 3.2.7.4 that matters to the chain: on
# every alex grammar of GHC 7.8.4 and 9.14.1 (their *.x.source), its `alex -g`
# output must be ghc74.alex327's, byte for byte. ghc74.alex327 is the alex
# that 7.8.4 to 9.14.1 are built with (GHC 7.4.2-compiled, from its
# tarball's Scan.hs); this one is mhs-compiled and traced back to the
# hand-written 2.1.0 scanner. A separate derivation, so that alexChain does
# not depend on the GHC chain up to 7.4.2. Output: ref/, ours/, report.txt.
{ stdenv
, alexChain
, ghc74
, ghc78
, ghc914
}:
let
  grammars = {
    "7.8.4" = {
      src = ghc78.src;
      xs = [ "compiler/cmm/CmmLex.x" "compiler/parser/Lexer.x" "utils/genprimopcode/Lexer.x" ];
    };
    "9.14.1" = {
      src = ghc914.src;
      xs = [
        "compiler/GHC/Cmm/Lexer.x"
        "compiler/GHC/Parser/Lexer/String.x"
        "compiler/GHC/Parser/Lexer.x"
        "compiler/GHC/Parser/HaddockLex.x"
        "utils/genprimopcode/Lexer.x"
        "libraries/Cabal/Cabal-syntax/src/Distribution/Fields/Lexer.x"
      ];
    };
  };
  one = v: g: ''
    mkdir -p src/${v}
    tar xJf ${g.src} -C src/${v} --strip-components=1 \
      ${builtins.concatStringsSep " " (map (x: "ghc-${v}/${x}.source") g.xs)}
    for x in ${builtins.concatStringsSep " " g.xs}; do
      mv src/${v}/$x.source src/${v}/$x
      o=${v}_$(echo $x | tr / _).hs
      (cd src/${v} && ${ghc74.alex327}/bin/alex -g $x -o $NIX_BUILD_TOP/ref/$o)
      (cd src/${v} && ${alexChain}/bin/alex -g $x -o $NIX_BUILD_TOP/ours/$o)
    done
  '';
in
stdenv.mkDerivation {
  name = "alex-chain-ghc-lexers";
  dontUnpack = true;
  buildPhase = ''
    runHook preBuild
    cd $NIX_BUILD_TOP; mkdir ref ours
    ${builtins.concatStringsSep "\n" (builtins.attrValues (builtins.mapAttrs one grammars))}
    runHook postBuild
  '';
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    cd $NIX_BUILD_TOP
    {
      for o in $(ls ref); do
        cmp ref/$o ours/$o
        echo "$o: identical to ghc74.alex327's ($(wc -l < ref/$o) lines)"
      done
    } | tee report.txt
    runHook postCheck
  '';
  installPhase = ''
    mkdir -p $out; cp -r $NIX_BUILD_TOP/ref $NIX_BUILD_TOP/ours $NIX_BUILD_TOP/report.txt $out/
  '';
}
