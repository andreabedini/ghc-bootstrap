# happy 1.19.12, the happy GHC 9.0.2 asks for (>= 1.19.10 and < 1.20),
# compiled by the chain's GHC 8.8.4 with its own Setup.hs (Cabal 3.0), from
# its Hackage tarball, and with none of the generated files that tarball
# ships. It is also the happy that made the parsers 8.8.4 and 9.0.2 ship.
#
# The tarball ships three kinds of generated file and none of their sources:
#
#   src/Parser.hs, src/AttrGrammarParser.hs   happy output, by a happy 1.19.10
#          (the header); the grammars Parser.ly and AttrGrammarParser.ly
#          come from the 1.19.12 tag of github.com/haskell/happy, as for
#          1.20.1.1 (ghc94/happy120.nix)
#   data/HappyTemplate*, data/GLR_*            templates/GenericTemplate.hs,
#          GLR_Base.hs and GLR_Lib.hs (from the same tag) preprocessed, one
#          file per flag set. Upstream's Makefile makes them at sdist time
#          with gen-happy-sdist/Main.hs (the tag; sha256 2d1b93d6...), a
#          wrapper over the cpphs library (1.20.8): runCpphs with each flag
#          defined as 1, hashline off (LINE pragmas), locations and macros
#          on, ansi off, and the file named `templates/<src>`. The chain's
#          cpphs 1.20.9 (cpphs/default.nix) run the same way from the
#          package root, `cpphs --linepragma -D<flag>... templates/<src>`,
#          reproduces all thirteen byte for byte (tried by hand 2026-10-12),
#          and the build fails if any differs.
#
#   gen 1  the parsers from the grammars by the chain's happy 1.19.5
#          (happy/happy.nix, plain backend); the happy built from them
#          regenerates both with -agc, as the release's were. The happy
#          1.19.10 that wrote the shipped ones had its template cpp'd by gcc
#          through Setup.lhs (`ghc -E -cpp` and a perl pass,
#          ghc66/cpp-template.sh), not by cpphs: its template text has
#          `Id:` for `$Id:...$`, `0#` for ERROR_TOK in a comment and
#          `+#  i` for `+# i`. So gen 1 also regenerates them with
#          --template pointing at HappyTemplate-arrays-coerce made that way
#          (by the GHC building this, as 1.19.10's was by its), and that
#          must equal what the tarball shipped modulo blank lines, LINE
#          pragmas and the version line (ghc66/cmp-generated.sh; tried by
#          hand on Parser.hs 2026-10-13). The shipped parsers also carry two
#          raw cpp markers (`# 1 ".../stdc-predef.h" 1 3 4`), from the same
#          Setup.lhs's line-marker bug; the comparison drops raw markers as
#          it drops LINE pragmas.
#   gen 2  built from gen 1's parsers; regenerates them byte for byte (the
#          fixed point)
#
# The grammars stay out of src/: Cabal runs happy -agc on any .ly it finds
# beside a module, and the mhs-built 1.19.5 has no -agc template. Output:
# bin/happy (gen 2) and share/.../happy-1.19.12/ (the templates, through
# Paths_happy).
{ stdenv
, fetchurl
, gmp
, perl
, cpphs
, happy
, ghc
}:

let
  fromTag = path: sha256: fetchurl {
    url = "https://raw.githubusercontent.com/haskell/happy/1.19.12/${path}";
    name = baseNameOf path;
    inherit sha256;
  };
  parserLy = fromTag "src/Parser.ly" "750ae802355732212c066d7b3658724496c08a940fa4b9955ba105a17890f94b";
  attrLy = fromTag "src/AttrGrammarParser.ly" "e822c731409a662baa44ae2310e3f1f5f22e6a869b81781ac86968e7af3a1a0e";
  genericTemplate = fromTag "templates/GenericTemplate.hs" "7f2b9e5c862131f65df5ec1d9613ddbcdd4d04b3deb1490cefc90ebdf2e8b46c";
  glrBase = fromTag "templates/GLR_Base.hs" "b214ac213f2258bbbb27f346da7ed842f2a89000199d22eaee784985c87e6802";
  glrLib = fromTag "templates/GLR_Lib.hs" "05f1840f1b9104ee2a0a4023a18ea4ee988538fc4857c267045c46e195cfbc6d";
in
stdenv.mkDerivation {
  pname = "happy";
  version = "1.19.12";
  src = fetchurl {
    url = "https://hackage.haskell.org/package/happy-1.19.12/happy-1.19.12.tar.gz";
    sha256 = "fb9a23e41401711a3b288f93cf0a66db9f97da1ce32ec4fffea4b78a0daeb40f";
  };
  nativeBuildInputs = [ ghc happy cpphs perl ];
  buildInputs = [ gmp ];   # programs linked by 8.8.4 need -lgmp
  hardeningDisable = [ "all" ];
  dontStrip = true;
  env = ghc.nonPie;

  buildPhase = ''
    runHook preBuild
    ulimit -s unlimited
    mkdir shipped shipped/data grammar templates
    mv src/Parser.hs src/AttrGrammarParser.hs shipped/
    mv data/* shipped/data/
    cp ${parserLy} grammar/Parser.ly
    cp ${attrLy} grammar/AttrGrammarParser.ly
    cp ${genericTemplate} templates/GenericTemplate.hs
    cp ${glrBase} templates/GLR_Base.hs
    cp ${glrLib} templates/GLR_Lib.hs

    # The templates, as gen-happy-sdist makes them (its three tables).
    t() { src=$1 dst=$2; shift 2; cpphs --linepragma "$@" templates/$src -Odata/$dst; }
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
    test $(ls data | wc -l) = 13

    ghc --make -v0 Setup.hs -o Setup
    build() {   # $1 = generation: src/ -> ./happy-$1 (and a Cabal install tree inst-$1)
      rm -rf dist
      ./Setup configure -v0 --prefix=$PWD/inst-$1 --with-compiler=ghc --with-hc-pkg=ghc-pkg
      ./Setup build -v0
      ./Setup install -v0
      cp inst-$1/bin/happy happy-$1
    }
    regen() {   # $1 = generation: its -agc parsers of the grammars -> gen$1/
      mkdir gen$1
      for p in Parser AttrGrammarParser; do ./happy-$1 -agc grammar/$p.ly -o gen$1/$p.hs; done
    }
    for p in Parser AttrGrammarParser; do happy grammar/$p.ly -o src/$p.hs; done
    build 1; regen 1
    # gen 1 again, with the template as 1.19.10's Setup.lhs made it: what
    # the shipped parsers are compared with
    mkdir tmpl-gcc gen1-gcc
    sh ${../ghc66/cpp-template.sh} ghc templates/GenericTemplate.hs tmpl-gcc/HappyTemplate-arrays-coerce \
      -DHAPPY_ARRAY -DHAPPY_GHC -DHAPPY_COERCE
    for p in Parser AttrGrammarParser; do ./happy-1 -agc --template=tmpl-gcc grammar/$p.ly -o gen1-gcc/$p.hs; done
    cp gen1/Parser.hs gen1/AttrGrammarParser.hs src/
    build 2; regen 2
    runHook postBuild
  '';
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    for f in data/*; do cmp $f shipped/data/$(basename $f); done
    echo "happy 1.19.12: the thirteen templates are byte for byte the tarball's"
    for p in Parser AttrGrammarParser; do
      # the shipped parsers name the happy that wrote them (1.19.10)
      sed 's/^-- parser produced by Happy Version [0-9.]*$/-- parser produced by Happy Version 1.19.12/' shipped/$p.hs > shipped/$p.hs.v
      sh ${../ghc66/cmp-generated.sh} gen1-gcc/$p.hs shipped/$p.hs.v
    done
    cmp gen1/Parser.hs gen2/Parser.hs
    cmp gen1/AttrGrammarParser.hs gen2/AttrGrammarParser.hs
    echo "happy 1.19.12: fixed point, gen 2 regenerates gen 1's parsers byte for byte"
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    rm -rf dist
    ./Setup configure -v0 --prefix=$out --with-compiler=ghc --with-hc-pkg=ghc-pkg
    ./Setup build -v0
    ./Setup install -v0
    mkdir -p $out/share/generated; cp gen2/*.hs $out/share/generated/
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/happy --version | grep -q 'Happy Version 1.19.12'
    cmp <($out/bin/happy -agc grammar/Parser.ly -o /dev/stdout) gen2/Parser.hs
  '';
}
