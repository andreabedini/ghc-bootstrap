# GHC 7.8.4 built by the chain's GHC 7.4.2 (nix/ghc74): configure and make,
# registerised with the native code generator (via C with `registerised =
# false`), no GHCi, static only (7.8 is
# the first release that builds dynamic libraries and a dynamically linked
# ghc by default; DYNAMIC_* = NO keeps the build like the earlier rungs').
# 7.8.4 asks for a 7.4 or later as the bootstrapping compiler; 7.6 is
# skipped. The tarball ships Parser.hs, Lexer.hs, CmmParse.hs and CmmLex.hs,
# and its own libffi 3.0.11.
#
# Non-PIE (nix-non-pie) through the cc wrapper. Output: an installed GHC
# 7.8.4, bin/ghc.
{ stdenv
, fetchurl
, perl
, gmp612
, ncurses
, ghc74
, registerised ? true
}:

stdenv.mkDerivation {
  pname = "ghc" + (if registerised then "-registerised" else "");
  version = "7.8.4";
  src = fetchurl {
    url = "https://downloads.haskell.org/~ghc/7.8.4/ghc-7.8.4-src.tar.xz";
    hash = "sha256-wxnNlK2yhBd+0ObSFUbtC5AK2EuGuHwGqZ6sNRUpgsQ=";
  };
  nativeBuildInputs = [ perl ghc74 ];
  buildInputs = [ gmp612 ncurses ];
  hardeningDisable = [ "all" ];
  dontStrip = true;
  env = ghc74.nonPie;
  passthru = { inherit (ghc74) nonPie; };

  postPatch = ''
    patchShebangs .
    cat > mk/build.mk <<'EOF'
    GhcUnregisterised = ${if registerised then "NO" else "YES"}
    GhcWithNativeCodeGen = ${if registerised then "YES" else "NO"}
    GhcWithInterpreter = NO
    GhcWithSMP = NO
    GhcLibWays = v
    GhcRTSWays =
    DYNAMIC_BY_DEFAULT = NO
    DYNAMIC_GHC_PROGRAMS = NO
    DYNAMIC_TOO = NO
    SplitObjs = NO
    HADDOCK_DOCS = NO
    HSCOLOUR_SRCS = NO
    BUILD_DOCBOOK_HTML = NO
    BUILD_DOCBOOK_PS = NO
    BUILD_DOCBOOK_PDF = NO
    LATEX_DOCS = NO
    GhcStage1HcOpts = -O
    GhcStage2HcOpts = -O${if registerised then " -fasm" else ""}
    GhcLibHcOpts = -O${if registerised then " -fasm" else ""}
    SRC_HC_OPTS = -H64m -O -optc-std=gnu89 -optc-fpermissive -optc-w -optc-fwrapv
    SRC_CC_OPTS += -std=gnu89 -fpermissive -w -fwrapv
    SRC_HSC2HS_OPTS += --cflag=-std=gnu89 --cflag=-fpermissive --cflag=-w
    EOF
  '';
  configurePhase = ''
    ./configure --prefix=$out --with-ghc=${ghc74}/bin/ghc --with-gcc=gcc \
      CFLAGS="-std=gnu89 -fpermissive -w"
    grep -q 'with-ghc=${ghc74}/bin/ghc' config.log
  '';
  preBuild = "ulimit -s unlimited; ulimit -c unlimited";   # cores reach the host's coredumpctl
  enableParallelBuilding = false;

  # nix/test/T3.hs, compiled by the installed compiler with no extra flags.
  doInstallCheck = true;
  installCheckPhase = ''
    mkdir t; cp ${../test/T3.hs} t/T3.hs
    (cd t && $out/bin/ghc -v0 --make T3.hs -o t3 && ./t3 > out.txt)
    diff ${../test/T3.out} t/out.txt
    # GMP >= 6.2 and pre-8.0 Integers (nix/gmp612.nix, D52): zeros across GCs
    cp ${../test/GmpZero.hs} t/GmpZero.hs
    (cd t && $out/bin/ghc -v0 -O --make GmpZero.hs -o gz && ./gz > gz.txt && printf "(2400000,0)\n" | diff - gz.txt)
    $out/bin/ghc --numeric-version | grep -qx 7.8.4
  '';
}
