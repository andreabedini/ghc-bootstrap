# Diverse double compilation for alex 2.1.0's own lexer. alex210.nix starts
# from the src/Scan.hs that the tarball ships, alex's output on src/Scan.x,
# and checks it only by a fixed point. This starts again from a scanner that
# no alex made, alex210ddc/Scan.hs, written by hand from Scan.x's rules:
#
#   alexA  alex 2.1.0 compiled by mhs with the hand-written Scan.hs
#   genA   alexA's `alex Scan.x`        -> must equal the shipped Scan.hs,
#                                          modulo blank lines and LINE pragmas
#   alexB  alex 2.1.0 compiled by mhs with genA's Scan.hs
#   genB   alexB's `alex Scan.x`        -> must be genA byte for byte
#
# and, as a check on the hand-written scanner over larger inputs, alexA and
# alexB must give the same `alex -g` output on GHC 6.6's parser/Lexer.x and
# cmm/CmmLex.x, which must equal the 6.6 tarball's Lexer.hs and CmmLex.hs
# as cmp-generated.sh compares them (ghc.nix makes those with alex210).
#
# They must also agree on GHC 6.2.2's parser/Lexer.x. 6.2.2 is built from
# the Lexer.hs its tarball ships, which alex 2.0 wrote, since no alex exists
# before it. alex 2.1.0's output must have the same DFA (cmp-tables.pl: the
# four tables as integers, alex 2.0's 16-bit alex_base against 2.1.0's
# 32-bit one, and alex_accept) and the same Haskell up to alex's template
# (the actions and Lexer.x's code), modulo LINE pragmas, blank lines and
# the ghcconfig.h include that 2.1.0 adds. The template is alex's, and the
# two versions' differ.
#
# GHC plays no part: alex is compiled by mhs, its Parser.hs is made by the
# chain's happy 1.19.5 (portable template, no -agc), and the templates are
# Setup.lhs's cpp step done with gcc's cpp, as GHC's -E runs it
# (`-undef -traditional`), and cpp-template.sh's perl.
# alex210ddc/alex-2.1.0-mhs.patch has the source changes mhs needs.
# Output: bin/alex (alexB, which alexchain.nix runs), share/alex-2.1.0/ (its
# templates), genA/, genB/, ghc66/ and report.txt.
{ stdenv
, fetchurl
, perl
, mhs
, cpphs
, happy
, alex210
, ghc66src
}:
let
  # the pristine GHC 6.2.2 tarball, as ghc622/nix/tree.nix fetches it
  ghc622src = fetchurl {
    url = "https://downloads.haskell.org/~ghc/6.2.2/ghc-6.2.2-src.tar.bz2";
    sha256 = "a0fe7eb8d447f25fbc616cdbce2bb4e03961a884c2c37969d1e23588b588a852";
  };
in
stdenv.mkDerivation {
  pname = "alex-ddc";
  version = "2.1.0";
  inherit (alex210) src;
  patches = [ ./alex210ddc/alex-2.1.0-mhs.patch ];
  nativeBuildInputs = [ perl mhs cpphs happy ];
  hardeningDisable = [ "all" ];
  buildPhase = ''
    runHook preBuild
    W=$PWD/work; mkdir -p $W/tpl $W/inc $W/shim $W/genA $W/genB $W/ghc66
    link() {   # $1 = mhs C output, $2 = binary
      cc -w -O1 -fno-pie -no-pie -I${mhs}/src/runtime -I${mhs}/src/runtime/unix \
         ${mhs}/src/runtime/main.c ${mhs}/src/runtime/eval.c "$1" -lm -o "$2"
    }
    build() {  # $1 = source tree, $2 = binary
      (cd $1 && mhs -XCPP -D__GLASGOW_HASKELL__=604 -I$W/inc \
         -i$W/shim -i${../common/shims} -i. Main -o$2.c)
      link $2.c $2
    }
    scan() {   # $1 = alex, $2 = output: its Scan.hs of src/Scan.x, run in src/
               # as the release's was (the LINE pragmas name "Scan.x")
      (cd src && $1 -t $W/tpl Scan.x -o $2)
    }

    echo "== templates: Setup.lhs's cpp step =="
    t() {      # $1 = source, $2 = template, cpp flags...
      s=$1 d=$2; shift 2
      (cd templates && cc -E -undef -traditional -x c "$@" $s -o $W/tpl/$d.hspp)
      perl -pe 's/^#\s+(\d+)\s+("[^"]*")(\s+\d+)*/{-# LINE \1 \2 #-}/g;s/\$(Id:.*)\$/\1/g' \
        $W/tpl/$d.hspp > $W/tpl/$d
      rm $W/tpl/$d.hspp
    }
    t GenericTemplate.hs AlexTemplate
    t GenericTemplate.hs AlexTemplate-ghc -DALEX_GHC
    t GenericTemplate.hs AlexTemplate-ghc-debug -DALEX_GHC -DALEX_DEBUG
    t GenericTemplate.hs AlexTemplate-debug -DALEX_DEBUG
    t wrappers.hs AlexWrapper-basic -DALEX_BASIC
    t wrappers.hs AlexWrapper-posn -DALEX_POSN
    t wrappers.hs AlexWrapper-monad -DALEX_MONAD
    t wrappers.hs AlexWrapper-gscan -DALEX_GSCAN
    touch $W/inc/ghcconfig.h
    cat > $W/shim/Paths_alex.hs <<EOF
    module Paths_alex (version, getDataDir) where
    import Data.Version
    version :: Version
    version = Version [2,1,0] []
    getDataDir :: IO FilePath
    getDataDir = return "$out/share/alex-2.1.0"
    EOF

    mkdir shipped; mv src/Parser.hs src/Scan.hs shipped/
    happy src/Parser.y -o src/Parser.hs
    cp -r src $W/srcA; cp -r src $W/srcB

    echo "== alexA: alex 2.1.0 by mhs, with the hand-written Scan.hs =="
    cp ${./alex210ddc/Scan.hs} $W/srcA/Scan.hs
    build $W/srcA $W/alexA
    scan $W/alexA $W/genA/Scan.hs

    echo "== alexB: alex 2.1.0 by mhs, with genA's Scan.hs =="
    # the one edit mhs needs, as in the hand-written Scan.hs: MicroHs reads
    # Scan.x's `not.isSpace` as a record field selection
    sed 's/(not\.isSpace)/(not . isSpace)/' $W/genA/Scan.hs > $W/srcB/Scan.hs
    [ "$(diff $W/genA/Scan.hs $W/srcB/Scan.hs | grep -c '^>')" = 1 ]
    build $W/srcB $W/alexB
    scan $W/alexB $W/genB/Scan.hs

    echo "== GHC 6.6's lexers by alexA and alexB =="
    tar xjf ${ghc66src} ghc-6.6/compiler/parser/Lexer.x ghc-6.6/compiler/parser/Lexer.hs \
      ghc-6.6/compiler/cmm/CmmLex.x ghc-6.6/compiler/cmm/CmmLex.hs
    for g in A B; do
      for x in parser/Lexer cmm/CmmLex; do
        (cd ghc-6.6/compiler && $W/alex$g -t $W/tpl -g $x.x -o $W/ghc66/$(basename $x).$g.hs)
      done
    done

    echo "== GHC 6.2.2's Lexer.x by alexA and alexB =="
    mkdir -p $W/ghc622
    tar xjf ${ghc622src} ghc-6.2.2/ghc/compiler/parser/Lexer.x ghc-6.2.2/ghc/compiler/parser/Lexer.hs
    for g in A B; do
      (cd ghc-6.2.2/ghc/compiler && $W/alex$g -t $W/tpl -g parser/Lexer.x -o $W/ghc622/Lexer.$g.hs)
    done
    runHook postBuild
  '';
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    W=$PWD/work
    {
      sh ${./cmp-generated.sh} $W/genA/Scan.hs shipped/Scan.hs | sed "s|$W/||"
      echo "  genA Scan.hs: $(diff shipped/Scan.hs $W/genA/Scan.hs | grep -c '^[<>]') raw diff lines against the shipped one"
      cmp $W/genA/Scan.hs $W/genB/Scan.hs
      echo "genB/Scan.hs: identical to genA's ($(wc -l < $W/genB/Scan.hs) lines)"
      for x in Lexer CmmLex; do
        cmp $W/ghc66/$x.A.hs $W/ghc66/$x.B.hs
        echo "ghc66/$x: alexA and alexB agree ($(wc -l < $W/ghc66/$x.A.hs) lines)"
      done
      sh ${./cmp-generated.sh} $W/ghc66/Lexer.B.hs ghc-6.6/compiler/parser/Lexer.hs | sed "s|$W/||"
      sh ${./cmp-generated.sh} $W/ghc66/CmmLex.B.hs ghc-6.6/compiler/cmm/CmmLex.hs | sed "s|$W/||"
      cmp $W/ghc622/Lexer.A.hs $W/ghc622/Lexer.B.hs
      echo "ghc622/Lexer: alexA and alexB agree ($(wc -l < $W/ghc622/Lexer.A.hs) lines)"
      shipped622=ghc-6.2.2/ghc/compiler/parser/Lexer.hs
      echo "ghc622/Lexer.B.hs against the Lexer.hs 6.2.2 ships (alex 2.0's):"
      perl ${./alex210ddc/cmp-tables.pl} $shipped622 $W/ghc622/Lexer.B.hs | sed 's/^/  /'
      code() {   # the Haskell before alex's template, but for the tables
        perl -0pe 's/#if __GLASGOW_HASKELL__ >= 603\n#include "ghcconfig.h"\n#else\n#include "config.h"\n#endif\n//' "$1" \
          | sed '/^-- ALEX TEMPLATE/,$d' \
          | grep -Ev '^\{-# LINE |^alex_(base|table|check|deflt|accept) = |^[[:space:]]*$'
      }
      code $shipped622 > code-shipped; code $W/ghc622/Lexer.B.hs > code-B
      cmp code-shipped code-B
      echo "  the code up to alex's template: the same ($(wc -l < code-B) lines)"
      echo "diverse double compilation: a hand-written scanner gives alex's own Scan.hs"
    } | tee report.txt
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r work/genA work/genB work/ghc66 work/ghc622 report.txt $out/
    install -Dm755 work/alexB $out/bin/alex
    mkdir -p $out/share/alex-2.1.0; cp work/tpl/* $out/share/alex-2.1.0/
    runHook postInstall
  '';
}
