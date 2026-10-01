# GHC 8.8.4 built by the chain's GHC 8.4.4 (nix/ghc84): configure and make,
# registerised with the native code generator (via C with `registerised =
# false`), no GHCi, static only. 8.8.4
# asks for an 8.4 or later as the bootstrapping compiler; 8.6 is skipped.
# The tarball ships Parser.hs, Lexer.hs, CmmParse.hs and CmmLex.hs.
#
# Non-PIE (nix-non-pie) through the cc wrapper. Output: an installed GHC
# 8.8.4, bin/ghc.
{ stdenv
, fetchurl
, perl
, gmp
, ncurses
, ghc84
, registerised ? true
}:

stdenv.mkDerivation {
  pname = "ghc" + (if registerised then "-registerised" else "");
  version = "8.8.4";
  src = fetchurl {
    url = "https://downloads.haskell.org/~ghc/8.8.4/ghc-8.8.4-src.tar.xz";
    hash = "sha256-8FBeOLIjX/nxCQtR9E1sjv03EGjlprtCoqbYtntf/C0=";
  };
  nativeBuildInputs = [ perl ghc84 ];
  buildInputs = [ gmp ncurses ];
  hardeningDisable = [ "all" ];
  dontStrip = true;
  env = ghc84.nonPie;
  passthru = { inherit (ghc84) nonPie; };

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
    ./configure --prefix=$out --with-ghc=${ghc84}/bin/ghc --with-gcc=gcc \
      CFLAGS="-std=gnu11 -w"
    grep -q 'with-ghc=${ghc84}/bin/ghc' config.log
  '';
  preBuild = "ulimit -s unlimited; ulimit -c unlimited";   # cores reach the host's coredumpctl
  enableParallelBuilding = true;

  # nix/test/T3.hs, compiled by the installed compiler with no extra flags.
  doInstallCheck = true;
  installCheckPhase = ''
    mkdir t; cp ${../test/T3.hs} t/T3.hs
    (cd t && $out/bin/ghc -v0 --make T3.hs -o t3 && ./t3 > out.txt)
    diff ${../test/T3.out} t/out.txt
    $out/bin/ghc --numeric-version | grep -qx 8.8.4
  '';
}
