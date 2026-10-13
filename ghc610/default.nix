# GHC 6.10.4 built by the chain's GHC 6.6 (ghc66): its own configure and
# make, unregisterised via C, no GHCi, no native code generator, no profiling,
# as 6.6 was built. 6.10.4 is the newest release whose configure accepts a
# 6.6 as the bootstrapping compiler (it asks for 6.4 or later; 6.12 asks for
# 6.8). The tarball's parsers and lexers are regenerated from their
# grammars (common/regen-parsers.sh) with 6.6's happy 1.16 and alex 2.1.0
# (6.10 asks for >= 1.15 and >= 2.1.0).
#
# The build.mk is what 6.6's patch added to its tree, written here instead:
# the ways and the interpreter off, and the C flags a 2026 gcc needs for 2009
# C (-std=gnu89 -fpermissive -w) plus -fwrapv for the generated C, passed to
# every compile the build makes (SRC_HC_OPTS -optc, SRC_CC_OPTS, hsc2hs).
# Non-PIE (nix-non-pie) through the cc wrapper, as for 6.6.
# Output: an installed GHC 6.10.4, bin/ghc.
{ stdenv
, fetchurl
, perl
, gmp612
, ncurses
, ghc66
}:

stdenv.mkDerivation {
  pname = "ghc";
  version = "6.10.4";
  src = fetchurl {
    url = "https://downloads.haskell.org/~ghc/6.10.4/ghc-6.10.4-src.tar.bz2";
    sha256 = "d66a8e52572f4ff819fe5c4e34c6dd1e84a7763e25c3fadcc222453c0bd8534d";
  };
  nativeBuildInputs = [ perl ghc66 ghc66.happy116 ghc66.alex210 ];
  buildInputs = [ gmp612 ncurses ];
  hardeningDisable = [ "all" ];
  dontStrip = true;
  env = ghc66.nonPie;
  passthru = { inherit (ghc66) nonPie; };

  postPatch = ''
    patchShebangs .
    # The tarball's parsers and lexers are happy and alex output; put them
    # back under their grammars (shipped as .source files) so the build
    # regenerates them with the happy and alex above (common/regen-parsers.sh).
    SHIPPED=$NIX_BUILD_TOP/shipped sh ${../common/regen-parsers.sh}
    # configure's FP_PROG_AR_ARGS makes AR "ar q", and make exports it to
    # libffi's configure, whose libtool then runs `ar q cru`. Give libffi a
    # plain ar.
    sed -i 's|CC=$(WhatGccIsCalled) $(SHELL) configure|CC=$(WhatGccIsCalled) AR=ar RANLIB=ranlib $(SHELL) configure|' libffi/Makefile
    grep -q 'AR=ar RANLIB=ranlib' libffi/Makefile
    cat > mk/build.mk <<'EOF'
    GhcUnregisterised = YES
    GhcWithNativeCodeGen = NO
    GhcWithInterpreter = NO
    GhcWithSMP = NO
    GhcLibWays =
    GhcRTSWays =
    SplitObjs = NO
    HADDOCK_DOCS = NO
    BUILD_DOCBOOK_HTML = NO
    BUILD_DOCBOOK_PS = NO
    BUILD_DOCBOOK_PDF = NO
    XMLDocWays =
    SRC_CC_OPTS += -std=gnu89 -fpermissive -w -fwrapv
    SRC_HC_OPTS += -optc-std=gnu89 -optc-fpermissive -optc-w -optc-fwrapv
    SRC_HSC2HS_OPTS += --cflag=-std=gnu89 --cflag=-fpermissive --cflag=-w
    EOF
  '';
  configurePhase = ''
    ./configure --prefix=$out --with-ghc=${ghc66}/bin/ghc --with-gcc=gcc \
      CFLAGS="-std=gnu89 -fpermissive -w"
    grep -q 'with-ghc=${ghc66}/bin/ghc' config.log
    grep -Eq '^GhcUnregisterised[[:space:]]*=[[:space:]]*YES' mk/build.mk
  '';
  preBuild = "ulimit -s unlimited; ulimit -c unlimited";   # cores reach the host's coredumpctl
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    SHIPPED=$NIX_BUILD_TOP/shipped sh ${../common/cmp-regenerated.sh}
    runHook postCheck
  '';
  enableParallelBuilding = false;

  # common/test/T3.hs (6.6's T2.hs with 6.10's extensible exceptions), compiled
  # by the installed compiler with no extra flags.
  doInstallCheck = true;
  installCheckPhase = ''
    mkdir t; cp ${../common/test/T3.hs} t/T3.hs
    (cd t && $out/bin/ghc -v0 --make T3.hs -o t3 && ./t3 > out.txt)
    diff ${../common/test/T3.out} t/out.txt
    # GMP >= 6.2 and pre-8.0 Integers (gmp612/default.nix, D52): zeros across GCs
    cp ${../common/test/GmpZero.hs} t/GmpZero.hs
    (cd t && $out/bin/ghc -v0 -O --make GmpZero.hs -o gz && ./gz > gz.txt && printf "(2400000,0)\n" | diff - gz.txt)
    $out/bin/ghc --numeric-version | grep -qx 6.10.4
  '';
}
