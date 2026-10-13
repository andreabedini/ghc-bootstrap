# GHC 6.12.3 built by the chain's GHC 6.10.4 (ghc610): its own configure
# and make (the first release of the ghc.mk build system), no GHCi, one
# library way. Registerised, with the x86-64 native code generator, although
# the 6.10.4 that boots it is unregisterised via C: GhcUnregisterised
# describes the compiler being built, stage 1 is whatever the boot compiler
# can produce, and everything stage 1 compiles is native code (D52). The
# first registerised rung; `registerised = false` gives the via-C variant,
# as 6.6 and 6.10 were built. 6.12.3 asks for a 6.8 or later as the
# bootstrapping compiler. The tarball's parsers and lexers are regenerated from their
# grammars (common/regen-parsers.sh) with 6.6's happy 1.16 and alex 2.1.0
# (6.12 asks for >= 1.16 and >= 2.1.0).
#
# build.mk as for 6.10 (ghc610), in the new system's names; -optc flags
# in SRC_HC_OPTS reach every compile, the boot compiler's included. GMP 6.1.2
# (gmp612/default.nix): integer-gmp 0.x dies on GMP >= 6.2's lazy mpz_init (D52).
# Non-PIE (nix-non-pie) through the cc wrapper.
# Output: an installed GHC 6.12.3, bin/ghc.
{ stdenv
, fetchurl
, perl
, gmp612
, ncurses
, ghc610
, ghc66            # for happy116 and alex210
, registerised ? true
  # true: GhcUnregisterised=NO with the x86-64 native code generator. Stage 1
  # is still compiled by the unregisterised 6.10.4 (via C, no -fasm); the
  # libraries and stage 2 it compiles are registerised NCG code with tables
  # next to code. The experiment that would make every later rung faster.
}:

stdenv.mkDerivation {
  pname = "ghc" + (if registerised then "-registerised" else "");
  version = "6.12.3";
  src = fetchurl {
    url = "https://downloads.haskell.org/~ghc/6.12.3/ghc-6.12.3-src.tar.bz2";
    hash = "sha256-bL2+QVAR8sfRXk2FB1jY05P3Bhe4jLMjfSxgK7YOXmg=";
  };
  nativeBuildInputs = [ perl ghc610 ghc66.happy116 ghc66.alex210 ];
  buildInputs = [ gmp612 ncurses ];
  hardeningDisable = [ "all" ];
  dontStrip = true;
  env = ghc610.nonPie;
  passthru = { inherit (ghc610) nonPie; };

  postPatch = ''
    patchShebangs .
    # The tarball's parsers and lexers are happy and alex output; put them
    # back under their grammars (shipped as .source files) so the build
    # regenerates them with the happy and alex above (common/regen-parsers.sh).
    SHIPPED=$NIX_BUILD_TOP/shipped sh ${../common/regen-parsers.sh}
    # includes/Rts.h has `#if __GNUC__ > 4` blocks for a gcc that did not exist
    # in 2010; one defines macros as `#pragma GCC visibility ...`, which no
    # cpp accepts. Take the branch every 2010 gcc took.
    sed -i 's/^#if __GNUC__ > 4$/#if 0 \/* was: __GNUC__ > 4; untested in 2010 (nix\/ghc612) *\//' includes/Rts.h
    grep -c 'was: __GNUC__ > 4' includes/Rts.h | grep -qx 2
    cat > mk/build.mk <<'EOF'
    GhcUnregisterised = ${if registerised then "NO" else "YES"}
    GhcWithNativeCodeGen = ${if registerised then "YES" else "NO"}
    GhcWithInterpreter = NO
    GhcWithSMP = NO
    GhcLibWays = v
    GhcRTSWays =
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
    ./configure --prefix=$out --with-ghc=${ghc610}/bin/ghc --with-gcc=gcc \
      CFLAGS="-std=gnu89 -fpermissive -w"
    grep -q 'with-ghc=${ghc610}/bin/ghc' config.log
  '';
  preBuild = "ulimit -s unlimited; ulimit -c unlimited";   # cores reach the host's coredumpctl
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    SHIPPED=$NIX_BUILD_TOP/shipped sh ${../common/cmp-regenerated.sh}
    runHook postCheck
  '';
  enableParallelBuilding = false;

  # common/test/T3.hs, compiled by the installed compiler with no extra flags.
  doInstallCheck = true;
  installCheckPhase = ''
    mkdir t; cp ${../common/test/T3.hs} t/T3.hs
    (cd t && $out/bin/ghc -v0 --make T3.hs -o t3 && ./t3 > out.txt)
    diff ${../common/test/T3.out} t/out.txt
    # GMP >= 6.2 and pre-8.0 Integers (gmp612/default.nix, D52): zeros across GCs
    cp ${../common/test/GmpZero.hs} t/GmpZero.hs
    (cd t && $out/bin/ghc -v0 -O --make GmpZero.hs -o gz && ./gz > gz.txt && printf "(2400000,0)\n" | diff - gz.txt)
    $out/bin/ghc --numeric-version | grep -qx 6.12.3
  '';
}
