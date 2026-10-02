# GHC 9.4.8 built by the chain's GHC 9.0.2 (nix/ghc90): configure and make.
# 9.4 is the last release that carries the make build system, and it keeps
# it only for a boot compiler older than 9.1 (configure.ac's
# MaxBootWithMakeGhcVersion, "Note [Support for building ghc 9.4 with the
# make build system]"), which a 9.0.2 is; nixpkgs 23.11 and Guix both build
# 9.4 this way. Registerised with the native code generator (via C with
# `registerised = false`), no GHCi, static only. 9.4.8 asks for a 9.0 or
# later as the bootstrapping compiler; 9.2 is skipped. The tarball ships
# GHC/Parser.hs, GHC/Parser/Lexer.hs, GHC/Cmm/Parser.hs and GHC/Cmm/Lexer.hs,
# so neither happy nor alex is needed.
#
# Guix applies ghc-9-StgCRunAsm-only-when-needed.patch to 9.0-9.4 (the make
# build links rts/StgCRunAsm.S on every architecture, which marks the RTS as
# needing an executable stack); not applied until the build asks for it.
#
# Non-PIE (nix-non-pie) through the cc wrapper. Output: an installed GHC
# 9.4.8, bin/ghc.
{ stdenv
, fetchurl
, perl
, gmp
, ncurses
, ghc90
, registerised ? true
}:

stdenv.mkDerivation {
  pname = "ghc" + (if registerised then "-registerised" else "");
  version = "9.4.8";
  src = fetchurl {
    url = "https://downloads.haskell.org/~ghc/9.4.8/ghc-9.4.8-src.tar.xz";
    sha256 = "0bf407eb67fe3e3c24b0f4c8dea8cb63e07f63ca0f76cf2058565143507ab85e";
  };
  nativeBuildInputs = [ perl ghc90 ];
  buildInputs = [ gmp ncurses ];
  hardeningDisable = [ "all" ];
  dontStrip = true;
  env = ghc90.nonPie;
  passthru = { inherit (ghc90) nonPie; };

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
    ./configure --prefix=$out GHC=${ghc90}/bin/ghc CC=gcc \
      CFLAGS="-std=gnu11 -w"
    grep -q 'GHC=${ghc90}/bin/ghc' config.log
  '';
  preBuild = "ulimit -s unlimited; ulimit -c unlimited";   # cores reach the host's coredumpctl
  enableParallelBuilding = true;

  # nix/test/T3.hs, compiled by the installed compiler with no extra flags.
  doInstallCheck = true;
  installCheckPhase = ''
    mkdir t; cp ${../test/T3.hs} t/T3.hs
    (cd t && $out/bin/ghc -v0 --make T3.hs -o t3 && ./t3 > out.txt)
    diff ${../test/T3.out} t/out.txt
    $out/bin/ghc --numeric-version | grep -qx 9.4.8
  '';
}
