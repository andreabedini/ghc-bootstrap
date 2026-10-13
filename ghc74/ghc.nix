# GHC 7.4.2 built by the chain's GHC 6.12.3 (ghc612): configure and make,
# registerised with the native code generator (via C with `registerised =
# false`), no GHCi, one library way. 7.4.2 asks for a 6.12 or later as the
# bootstrapping compiler, so 7.0 and 7.2 are skipped. The tarball's parsers and lexers are regenerated from their
# grammars (common/regen-parsers.sh) with 6.6's happy 1.16 and alex 2.1.0
# (7.4 asks for >= 1.16 and >= 2.1.0).
#
# build.mk as for 6.12 (ghc612); GMP 6.1.2 as every rung before 8.0
# (D52). Non-PIE (nix-non-pie) through the cc wrapper. Output: an installed
# GHC 7.4.2, bin/ghc.
{ stdenv
, lib
, fetchurl
, perl
, gmp612
, ncurses
, gdb
, ghc612
, ghc66            # for happy116 and alex210
, registerised ? true   # as ghc612: NCG and tables next to code
, gdbModule ? null
  # diagnostic (as ghc66): the in-place compiler runs under gdb for the
  # compile whose arguments contain this string; the backtrace goes to the log
}:

stdenv.mkDerivation {
  pname = "ghc" + (if registerised then "-registerised" else "");
  version = "7.4.2";
  src = fetchurl {
    url = "https://downloads.haskell.org/~ghc/7.4.2/ghc-7.4.2-src.tar.bz2";
    hash = "sha256-8u4SiaM8xwU5KHEphBrMfq8WESu2DFm1pu6RiHv9g20=";
  };
  nativeBuildInputs = [ perl ghc612 ghc66.happy116 ghc66.alex210 ] ++ lib.optional (gdbModule != null) gdb;
  buildInputs = [ gmp612 ncurses ];
  hardeningDisable = [ "all" ];
  dontStrip = true;
  env = ghc612.nonPie;
  passthru = { inherit (ghc612) nonPie; };

  # The sdist was made from a configured tree: utils/ghc-pwd/dist-boot holds
  # a ghc-pwd binary, Main.o and Main.hi built by the release's own GHC.
  # configure rebuilds it anyway (FP_INTREE_GHC_PWD in aclocal.m4 does
  # rm -rf dist-boot first); delete it before anything runs.
  postUnpack = ''
    rm -rf "$sourceRoot"/utils/ghc-pwd/dist-boot
  '';

  postPatch = lib.optionalString (gdbModule != null) ''
    mkdir -p $NIX_BUILD_TOP/bin
    cat > $NIX_BUILD_TOP/bin/gdbwrap <<'EOF'
    #!${stdenv.shell}
    case "$*" in
      *" -c "*${gdbModule}*) echo "== gdbwrap: running under gdb: $*"
                     exec gdb -batch -ex run -ex bt -ex 'info registers' -ex 'x/8i $pc-16' -ex 'x/8gx $rbx' -ex 'info symbol $rbx' -ex 'info proc mappings' -ex 'quit 0' --args "$@" ;;
      *) exec "$@" ;;
    esac
    EOF
    chmod +x $NIX_BUILD_TOP/bin/gdbwrap
    # ghc/ghc.wrapper is the tail of every inplace/bin/ghc-stage* script
    sed -i "s|^exec \"\$executablename\"|exec $NIX_BUILD_TOP/bin/gdbwrap \"\$executablename\"|" ghc/ghc.wrapper
    grep -q gdbwrap ghc/ghc.wrapper
  '' + ''
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
    ./configure --prefix=$out --with-ghc=${ghc612}/bin/ghc --with-gcc=gcc \
      CFLAGS="-std=gnu89 -fpermissive -w"
    grep -q 'with-ghc=${ghc612}/bin/ghc' config.log
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
    $out/bin/ghc --numeric-version | grep -qx 7.4.2
  '';
}
