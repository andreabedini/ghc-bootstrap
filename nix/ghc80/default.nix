# GHC 8.0.2 built by the chain's GHC 7.8.4 (nix/ghc78): configure and make,
# registerised with the native code generator (via C with `registerised =
# false`), no GHCi, static only. 8.0.2
# asks for a 7.8 or later as the bootstrapping compiler; 7.10 is skipped.
# The tarball ships Parser.hs, Lexer.hs, CmmParse.hs and CmmLex.hs and its
# own libffi. Docs are Sphinx now (BUILD_SPHINX_*, BUILD_MAN). The C flags
# change here: -std=gnu11 -w instead of the -std=gnu89 -fpermissive -fwrapv
# the 2004-2012 sources and their generated C needed (integer-gmp's cbits
# are C99), and the host's GMP: 8.0's integer-gmp works on limbs and does
# not meet GMP 6.2's lazy mpz_init (D52).
#
# Guix patches 8.0.2's rts/posix/OSMem.c to fall back from MADV_FREE to
# MADV_DONTNEED at run time; 8.0.2 already tries MADV_FREE first and the
# fallback only matters on kernels before 4.5, so it is not applied here.
#
# Non-PIE (nix-non-pie) through the cc wrapper. Output: an installed GHC
# 8.0.2, bin/ghc.
{ stdenv
, fetchurl
, perl
, gmp
, ncurses
, ghc78
, registerised ? true
}:

stdenv.mkDerivation {
  pname = "ghc" + (if registerised then "-registerised" else "");
  version = "8.0.2";
  src = fetchurl {
    url = "https://downloads.haskell.org/~ghc/8.0.2/ghc-8.0.2-src.tar.xz";
    hash = "sha256-EWJUU+HQaGs/pnOZiPcOysg2ytwwufDItJ75CR1hGLE=";
  };
  nativeBuildInputs = [ perl ghc78 ];
  buildInputs = [ gmp ncurses ];
  hardeningDisable = [ "all" ];
  dontStrip = true;
  env = ghc78.nonPie;
  passthru = { inherit (ghc78) nonPie; };

  postPatch = ''
    patchShebangs .
    cat > mk/build.mk <<'EOF'
    GhcUnregisterised = ${if registerised then "NO" else "YES"}
    GhcWithNativeCodeGen = ${if registerised then "YES" else "NO"}
    GhcWithInterpreter = NO
    GhcWithSMP = NO
    GhcLibWays = v
    GhcRTSWays = thr
    DYNAMIC_BY_DEFAULT = NO
    DYNAMIC_GHC_PROGRAMS = NO
    DYNAMIC_TOO = NO
    BUILD_PROF_LIBS = NO
    SplitObjs = NO
    HADDOCK_DOCS = NO
    HSCOLOUR_SRCS = NO
    BUILD_SPHINX_HTML = NO
    BUILD_SPHINX_PDF = NO
    BUILD_MAN = NO
    GhcStage1HcOpts = -O
    GhcStage2HcOpts = -O${if registerised then " -fasm" else ""}
    GhcLibHcOpts = -O${if registerised then " -fasm" else ""}
    SRC_HC_OPTS = -H64m -O -optc-std=gnu11 -optc-w
    SRC_CC_OPTS += -std=gnu11 -w
    SRC_HSC2HS_OPTS += --cflag=-std=gnu11 --cflag=-w
    EOF
  '';
  configurePhase = ''
    ./configure --prefix=$out --with-ghc=${ghc78}/bin/ghc --with-gcc=gcc \
      CFLAGS="-std=gnu11 -w"
    grep -q 'with-ghc=${ghc78}/bin/ghc' config.log
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
    $out/bin/ghc --numeric-version | grep -qx 8.0.2
  '';
}
