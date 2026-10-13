# alex 3.2.7.4, compiled by the chain's GHC 7.4.2 with its own Setup.hs
# (Cabal 1.14), from its Hackage tarball. One alex serves every rung from
# 7.8.4 on: 7.8.4 asks for an alex >= 3.1, 8.0.2 to 8.4.4 for >= 3.1.0,
# 8.8.4 and 9.0.2 for >= 3.1.7, 9.4.8 to 9.14.1 for >= 3.2.6 (< 4). The
# chain's alex 2.1.0 is too old for all of them, and no 3.1.x release can
# stand in: their executable imports Test.QuickCheck (the Data.Ranged
# modules they carry), and 7.4.2 has no QuickCheck. 3.2.4 dropped that
# dependency; 3.2.7.4 builds with 7.4.2 as released (base >= 2.1, array,
# containers, directory), its -g output compiles with 7.4.2 (the boot
# compiler of 7.8.4, which compiles the Lexer.hs regenerated there), and
# its templates (data/AlexTemplate.hs, data/AlexWrappers.hs) are plain
# source, not cpp output: from 3.2.6 the generated lexer defines the
# ALEX_* macros and the compiler's cpp does the rest.
#
# The tarball ships the generated src/Parser.hs and src/Scan.hs and, as
# .boot files, the sources they came from. src/Parser.hs is regenerated
# from Parser.y.boot by the chain's happy 1.19.5 (happy/default.nix, the
# mhs-built one, plain backend) and the tarball's is not used. src/Scan.hs,
# alex's own lexer, can only come from an alex (alex 2.1.0 accepts Scan.x
# but its template no longer fits alex 3's code), so the tarball's is the
# seed, discharged by a fixed point:
#
#   gen 1  built with the tarball's Scan.hs; its `alex -g Scan.x` must equal
#          that Scan.hs modulo blank lines and LINE pragmas
#          (ghc66/cmp-generated.sh)
#   gen 2  built with gen 1's Scan.hs; its `alex -g Scan.x` must be gen 1's,
#          byte for byte
#
# The .y and .x stay out of src/ so Cabal does not try to run happy and alex
# itself. Output: bin/alex (gen 2) and share/.../alex-3.2.7.4/ (the
# templates, through Paths_alex).
{ stdenv
, fetchurl
, gmp612
, happy
, ghc
}:

stdenv.mkDerivation {
  pname = "alex";
  version = "3.2.7.4";
  src = fetchurl {
    url = "https://hackage.haskell.org/package/alex-3.2.7.4/alex-3.2.7.4.tar.gz";
    sha256 = "8a13fa01ea00883aa3d75d15ce848835b18631b8c9a4966961492d7c6095226f";
  };
  nativeBuildInputs = [ ghc happy ];
  buildInputs = [ gmp612 ];   # programs linked by 7.4.2 need -lgmp
  hardeningDisable = [ "all" ];
  dontStrip = true;
  env = ghc.nonPie;

  buildPhase = ''
    runHook preBuild
    ulimit -s unlimited
    mkdir shipped grammar
    mv src/Parser.hs src/Scan.hs shipped/
    cp src/Parser.y.boot grammar/Parser.y
    cp src/Scan.x.boot grammar/Scan.x

    ghc --make -v0 Setup.hs -o Setup
    build() {   # $1 = generation: src/ -> ./alex-$1
      rm -rf dist
      ./Setup configure -v0 --prefix=$PWD/inst-$1 --with-compiler=ghc --with-hc-pkg=ghc-pkg
      ./Setup build -v0
      ./Setup install -v0
      cp inst-$1/bin/alex alex-$1
    }
    happy grammar/Parser.y -o src/Parser.hs
    cp shipped/Scan.hs src/Scan.hs
    build 1
    mkdir gen1 gen2
    ./alex-1 -g grammar/Scan.x -o gen1/Scan.hs
    cp gen1/Scan.hs src/Scan.hs
    build 2
    ./alex-2 -g grammar/Scan.x -o gen2/Scan.hs
    runHook postBuild
  '';
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    sh ${../ghc66/cmp-generated.sh} gen1/Scan.hs shipped/Scan.hs
    cmp gen1/Scan.hs gen2/Scan.hs
    echo "alex 3.2.7.4: fixed point, gen 2 regenerates gen 1's Scan.hs byte for byte"
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    rm -rf dist
    ./Setup configure -v0 --prefix=$out --with-compiler=ghc --with-hc-pkg=ghc-pkg
    ./Setup build -v0
    ./Setup install -v0
    mkdir -p $out/share/generated; cp gen2/Scan.hs src/Parser.hs $out/share/generated/
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/alex --version | grep -q 'Alex version 3.2.7.4'
    cmp <($out/bin/alex -g grammar/Scan.x -o /dev/stdout) gen2/Scan.hs
  '';
}
