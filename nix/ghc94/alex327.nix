# alex 3.2.7.4, the alex GHC 9.4 and 9.8 ask for (>= 3.2.6), compiled by the
# chain's GHC 9.0.2 with its own Setup.hs (Cabal 3.4), from its Hackage
# tarball. The tarball ships the generated src/Parser.hs and src/Scan.hs and,
# as .boot files, the sources they came from.
#
# src/Parser.hs is regenerated from Parser.y.boot by the chain's happy 1.19.5
# (plain backend) and the tarball's is not used. src/Scan.hs, alex's own
# lexer, can only come from an alex (the chain's alex 2.1.0 accepts Scan.x
# but its template no longer fits alex 3's code), so the tarball's is the
# seed, discharged by a fixed point:
#
#   gen 1  built with the tarball's Scan.hs; its `alex -g Scan.x` must equal
#          that Scan.hs modulo blank lines and LINE pragmas
#          (nix/ghc66/cmp-generated.sh)
#   gen 2  built with gen 1's Scan.hs; its `alex -g Scan.x` must be gen 1's,
#          byte for byte
#
# The .y and .x stay out of src/ so Cabal does not try to run happy and alex
# itself. Output: bin/alex (gen 2) and share/.../alex-3.2.7.4/ (the
# templates, through Paths_alex).
{ stdenv
, fetchurl
, gmp
, happy
, ghc90
}:

stdenv.mkDerivation {
  pname = "alex";
  version = "3.2.7.4";
  src = fetchurl {
    url = "https://hackage.haskell.org/package/alex-3.2.7.4/alex-3.2.7.4.tar.gz";
    sha256 = "8a13fa01ea00883aa3d75d15ce848835b18631b8c9a4966961492d7c6095226f";
  };
  nativeBuildInputs = [ ghc90 happy ];
  buildInputs = [ gmp ];   # programs linked by 9.0.2 need -lgmp
  hardeningDisable = [ "all" ];
  dontStrip = true;
  env = ghc90.nonPie;

  buildPhase = ''
    runHook preBuild
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
    sh ${../ghc66/cmp-generated.sh} gen1/Scan.hs shipped/Scan.hs
    cp gen1/Scan.hs src/Scan.hs
    build 2
    ./alex-2 -g grammar/Scan.x -o gen2/Scan.hs
    cmp gen1/Scan.hs gen2/Scan.hs
    echo "alex 3.2.7.4: fixed point, gen 2 regenerates gen 1's Scan.hs byte for byte"
    runHook postBuild
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
