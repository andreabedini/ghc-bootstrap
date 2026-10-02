# GHC 9.0.2 built by the chain's GHC 8.8.4 (nix/ghc88): configure and make
# (the last release with the make build system), registerised with the native
# code generator (via C with `registerised = false`), no GHCi, static only.
# 9.0.2 asks for an 8.8 or later as the bootstrapping compiler; 8.10 is
# skipped. The tarball ships
# GHC/Parser.hs, GHC/Parser/Lexer.hs, GHC/Cmm/Parser.hs and GHC/Cmm/Lexer.hs.
#
# Guix applies ghc-9-StgCRunAsm-only-when-needed.patch here; not applied
# until the build asks for it.
#
# Non-PIE (nix-non-pie) through the cc wrapper. Output: an installed GHC
# 9.0.2, bin/ghc.
{ stdenv
, fetchurl
, perl
, gmp
, ncurses
, ghc88
, registerised ? true
}:

stdenv.mkDerivation {
  pname = "ghc" + (if registerised then "-registerised" else "");
  version = "9.0.2";
  src = fetchurl {
    url = "https://downloads.haskell.org/~ghc/9.0.2/ghc-9.0.2-src.tar.xz";
    hash = "sha256-FA5CuWNGMi0aOesXYCvNx24pICitSmkoayMLqxiKkZc=";
  };
  nativeBuildInputs = [ perl ghc88 ];
  buildInputs = [ gmp ncurses ];
  hardeningDisable = [ "all" ];
  dontStrip = true;
  env = ghc88.nonPie;
  passthru = { inherit (ghc88) nonPie; };

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
    SplitSections = NO
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
    ./configure --prefix=$out GHC=${ghc88}/bin/ghc CC=gcc \
      CFLAGS="-std=gnu11 -w"
    grep -q 'GHC=${ghc88}/bin/ghc' config.log
  '';
  preBuild = "ulimit -s unlimited; ulimit -c unlimited";   # cores reach the host's coredumpctl
  enableParallelBuilding = true;

  # nix/test/T3.hs, compiled by the installed compiler with no extra flags.
  doInstallCheck = true;
  installCheckPhase = ''
    mkdir t; cp ${../test/T3.hs} t/T3.hs
    (cd t && $out/bin/ghc -v0 --make T3.hs -o t3 && ./t3 > out.txt)
    diff ${../test/T3.out} t/out.txt
    $out/bin/ghc --numeric-version | grep -qx 9.0.2
  '';
}
