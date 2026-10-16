# happy 1.19.5, compiled by the chain's GHC 7.4.2 with its own Setup.lhs
# (Cabal 1.14), from its Hackage tarball, and with none of the parsers that
# tarball ships. It serves the rungs 7.8.4 to 8.8.4, which ask for a happy
# >= 1.19 or >= 1.19.4; it is the newest happy 7.4.2 can build (1.19.6 on
# want mtl's Control.Monad.Except), and the happy that made the parsers
# 8.0.2 ships, so 8.0.2's regeneration is compared strictly. It wants an
# mtl >= 1.0, and the installed 7.4.2 has none (its build keeps mtl
# in-tree): mtl.nix builds the 7.4.2 tarball's mtl 1.1.1.1 into a package
# database of its own, passed here as --package-db.
#
# The tarball ships the grammars (src/Parser.ly, src/AttrGrammarParser.ly)
# and, under dist/, the parsers made from them, by a happy 1.19.4 (their
# header says so: the release's dist/ predates its own happy):
#
#   gen 1  src/Parser.hs and src/AttrGrammarParser.hs from the grammars by
#          the chain's happy 1.19.5 (happy/happy.nix, the mhs-built one,
#          plain backend); the happy built from them regenerates both with
#          -agc, as the release's were, and that must equal what dist/
#          shipped modulo blank lines, LINE pragmas (ghc66/cmp-generated.sh)
#          and the two lines 1.19.5 changed: the version in the header and
#          an `import Control.Monad (ap)` it adds ("fixes for GHC 7.10")
#   gen 2  built from gen 1's parsers; regenerates them byte for byte (the
#          fixed point)
#
# The grammars stay out of src/: Cabal runs happy on any .ly it finds beside
# a module, and the mhs-built 1.19.5 has no -agc template. The templates
# are cpp'd by Setup.lhs's postBuild (ghc -E -cpp over templates/), whose
# line-marker regex has 1.16's bug (ghc66/cpp-template.sh): a marker with
# flags after the file name, `# 1 ".../stdc-predef.h" 1 3`, is left as it
# is and would ride into every parser this happy writes. So after
# `Setup build` the same table (Setup.lhs's templates, glr_base_templates,
# glr_templates) is redone over the same sources with the fixed step, and
# `Setup install` installs those. Output: bin/happy (gen 2) and
# share/happy-1.19.5/ (the templates, through Paths_happy).
{ stdenv
, fetchurl
, perl
, gmp612
, happy
, ghc
, mtl
}:

stdenv.mkDerivation {
  pname = "happy";
  version = "1.19.5";
  src = fetchurl {
    url = "https://hackage.haskell.org/package/happy-1.19.5/happy-1.19.5.tar.gz";
    sha256 = "62f03ac11d7b4b9913f212f5aa2eee1087f3b46dc07d799d41e1854ff02843da";
  };
  nativeBuildInputs = [ ghc happy perl ];
  buildInputs = [ gmp612 ];   # programs linked by 7.4.2 need -lgmp
  hardeningDisable = [ "all" ];
  dontStrip = true;
  env = ghc.nonPie;

  buildPhase = ''
    runHook preBuild
    ulimit -s unlimited
    mkdir shipped grammar
    mv dist/build/happy/happy-tmp/Parser.hs dist/build/happy/happy-tmp/AttrGrammarParser.hs shipped/
    rm -rf dist
    mv src/Parser.ly src/AttrGrammarParser.ly grammar/
    grep -q '^-- parser produced by Happy Version 1\.19\.4$' shipped/Parser.hs

    ghc --make -v0 Setup.lhs -o Setup
    t() { sh ${../ghc66/cpp-template.sh} ghc templates/$1 $2 "''${@:3}"; }
    templates() {   # Setup.lhs's table, into the package root where its postBuild put them
      t GenericTemplate.hs HappyTemplate
      t GenericTemplate.hs HappyTemplate-ghc -DHAPPY_GHC
      t GenericTemplate.hs HappyTemplate-coerce -DHAPPY_GHC -DHAPPY_COERCE
      t GenericTemplate.hs HappyTemplate-arrays -DHAPPY_ARRAY
      t GenericTemplate.hs HappyTemplate-arrays-ghc -DHAPPY_ARRAY -DHAPPY_GHC
      t GenericTemplate.hs HappyTemplate-arrays-coerce -DHAPPY_ARRAY -DHAPPY_GHC -DHAPPY_COERCE
      t GenericTemplate.hs HappyTemplate-arrays-debug -DHAPPY_ARRAY -DHAPPY_DEBUG
      t GenericTemplate.hs HappyTemplate-arrays-ghc-debug -DHAPPY_ARRAY -DHAPPY_GHC -DHAPPY_DEBUG
      t GenericTemplate.hs HappyTemplate-arrays-coerce-debug -DHAPPY_ARRAY -DHAPPY_GHC -DHAPPY_COERCE -DHAPPY_DEBUG
      t GLR_Base.hs GLR_Base
      t GLR_Lib.hs GLR_Lib
      t GLR_Lib.hs GLR_Lib-ghc -DHAPPY_GHC
      t GLR_Lib.hs GLR_Lib-ghc-debug -DHAPPY_GHC -DHAPPY_DEBUG
      ! grep -l '^# ' HappyTemplate* GLR_*
    }
    build() {   # $1 = generation: src/ -> ./happy-$1 (and a Cabal install tree inst-$1)
      rm -rf dist
      ./Setup configure -v0 --prefix=$PWD/inst-$1 --with-compiler=ghc --with-hc-pkg=ghc-pkg \
        --package-db=${mtl}/lib/package.conf.d
      ./Setup build -v0
      templates
      ./Setup install -v0
      cp inst-$1/bin/happy happy-$1
    }
    regen() {   # $1 = generation: its -agc parsers of the grammars -> gen$1/
      mkdir gen$1
      for p in Parser AttrGrammarParser; do ./happy-$1 -agc grammar/$p.ly -o gen$1/$p.hs; done
    }
    for p in Parser AttrGrammarParser; do happy grammar/$p.ly -o src/$p.hs; done
    build 1; regen 1
    cp gen1/Parser.hs gen1/AttrGrammarParser.hs src/
    build 2; regen 2
    runHook postBuild
  '';
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    for p in Parser AttrGrammarParser; do
      sed 's/^-- parser produced by Happy Version 1\.19\.4$/-- parser produced by Happy Version 1.19.5/' shipped/$p.hs > shipped/$p.hs.v
      grep -v '^import Control.Monad (ap)$' gen1/$p.hs > gen1/$p.hs.v
      sh ${../ghc66/cmp-generated.sh} gen1/$p.hs.v shipped/$p.hs.v
    done
    cmp gen1/Parser.hs gen2/Parser.hs
    cmp gen1/AttrGrammarParser.hs gen2/AttrGrammarParser.hs
    echo "happy 1.19.5: fixed point, gen 2 regenerates gen 1's parsers byte for byte"
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    rm -rf dist
    ./Setup configure -v0 --prefix=$out --with-compiler=ghc --with-hc-pkg=ghc-pkg \
      --package-db=${mtl}/lib/package.conf.d
    ./Setup build -v0
    templates
    ./Setup install -v0
    mkdir -p $out/share/generated; cp gen2/*.hs $out/share/generated/
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/happy --version | grep -q 'Happy Version 1.19.5'
    test $(ls $out/share/happy-1.19.5 | wc -l) = 13
    cmp <($out/bin/happy -agc grammar/Parser.ly -o /dev/stdout) gen2/Parser.hs
  '';
}
