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
# GHC plays no part: alex is compiled by mhs, its Parser.hs is made by the
# chain's happy 1.19.5 (portable template, no -agc), and the templates are
# Setup.lhs's cpp step done with gcc's cpp, as GHC's -E runs it
# (`-undef -traditional`), and cpp-template.sh's perl.
# alex210ddc/alex-2.1.0-mhs.patch has the source changes mhs needs.
# Output: genA/, genB/, ghc66/ and report.txt.
{ stdenv
, perl
, mhs
, cpphs
, happy
, alex210
, ghc66src
}:
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
    getDataDir = return "$W/tpl"
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
      echo "diverse double compilation: a hand-written scanner gives alex's own Scan.hs"
    } | tee report.txt
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r work/genA work/genB work/ghc66 report.txt $out/
    runHook postInstall
  '';
}
