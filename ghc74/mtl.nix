# mtl 1.1.1.1 from GHC 7.4.2's own source tarball (libraries/mtl), compiled
# by the chain's 7.4.2 and registered in a package database of its own,
# lib/package.conf.d, for happy 1.19.5 (happy1195.nix), which wants an
# mtl >= 1.0. 7.4.2's build compiles this mtl (haskeline needs it) but
# never installs it: ghc.mk lists it under PKGS_THAT_ARE_INTREE_ONLY, so
# the installed 7.4.2 has no mtl at all. Nothing new is fetched: the
# source is the tree's, built with the Setup.hs the tree carries (Cabal
# 1.14's defaultMain). Consumers pass --package-db=${mtl}/lib/package.conf.d.
{ stdenv
, gmp612
, ghc
}:

stdenv.mkDerivation {
  pname = "mtl";
  version = "1.1.1.1";
  src = ghc.src;
  sourceRoot = "ghc-7.4.2/libraries/mtl";
  nativeBuildInputs = [ ghc ];
  buildInputs = [ gmp612 ];   # Setup, linked by 7.4.2, needs -lgmp
  hardeningDisable = [ "all" ];
  dontStrip = true;
  env = ghc.nonPie;

  buildPhase = ''
    runHook preBuild
    grep -q '^Version: *1\.1\.1\.1$' mtl.cabal
    mkdir -p $out/lib
    ghc-pkg init $out/lib/package.conf.d
    ghc --make -v0 Setup.hs -o Setup
    ./Setup configure -v0 --prefix=$out --with-compiler=ghc --with-hc-pkg=ghc-pkg \
      --package-db=$out/lib/package.conf.d
    ./Setup build -v0
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    ./Setup install -v0
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    ghc-pkg list --package-conf=$out/lib/package.conf.d --simple-output | grep -qx 'mtl-1.1.1.1'
  '';
}
