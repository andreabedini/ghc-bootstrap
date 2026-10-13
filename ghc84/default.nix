# GHC 8.4.4 built by the chain's GHC 8.0.2 (ghc80): configure and make,
# registerised with the native code generator (via C with `registerised =
# false`), no GHCi, static only. 8.4.4
# asks for an 8.0 or later as the bootstrapping compiler; 8.2 is skipped.
# The tarball's parsers and lexers are regenerated from their
# grammars (common/regen-parsers.sh) with 7.4.2's happy 1.19.5 and alex 3.2.7.4
# (8.4 asks for >= 1.19.4 and >= 3.1.0); so is Cabal's lexer (boot/Lexer.x).
#
# Non-PIE (nix-non-pie) through the cc wrapper. Output: an installed GHC
# 8.4.4, bin/ghc.
{ stdenv
, fetchurl
, perl
, gmp
, ncurses
, ghc80
, ghc74            # for happy1195 and alex327
, registerised ? true
}:

stdenv.mkDerivation {
  pname = "ghc" + (if registerised then "-registerised" else "");
  version = "8.4.4";
  src = fetchurl {
    url = "https://downloads.haskell.org/~ghc/8.4.4/ghc-8.4.4-src.tar.xz";
    hash = "sha256-ERF3NaWOUHxIHAnz85rloxTp+/SfwxCVKPmep5WQBLI=";
  };
  nativeBuildInputs = [ perl ghc80 ghc74.happy1195 ghc74.alex327 ];
  buildInputs = [ gmp ncurses ];
  hardeningDisable = [ "all" ];
  dontStrip = true;
  env = ghc80.nonPie;
  passthru = { inherit (ghc80) nonPie; };

  postPatch = ''
    patchShebangs .
    # The tarball's parsers and lexers are happy and alex output; put them
    # back under their grammars (shipped as .source files) so the build
    # regenerates them with the happy and alex above (common/regen-parsers.sh).
    SHIPPED=$NIX_BUILD_TOP/shipped sh ${../common/regen-parsers.sh}
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
    ./configure --prefix=$out --with-ghc=${ghc80}/bin/ghc CC=gcc \
      CFLAGS="-std=gnu11 -w"
    grep -q 'with-ghc=${ghc80}/bin/ghc' config.log
  '';
  preBuild = "ulimit -s unlimited; ulimit -c unlimited";   # cores reach the host's coredumpctl
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    SHIPPED=$NIX_BUILD_TOP/shipped sh ${../common/cmp-regenerated.sh}
    runHook postCheck
  '';
  enableParallelBuilding = true;

  # common/test/T3.hs, compiled by the installed compiler with no extra flags.
  doInstallCheck = true;
  installCheckPhase = ''
    mkdir t; cp ${../common/test/T3.hs} t/T3.hs
    (cd t && $out/bin/ghc -v0 --make T3.hs -o t3 && ./t3 > out.txt)
    diff ${../common/test/T3.out} t/out.txt
    $out/bin/ghc --numeric-version | grep -qx 8.4.4
  '';
}
