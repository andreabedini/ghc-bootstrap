# GHC 7.4.2 built by the chain's GHC 6.12.3 (nix/ghc612): configure and make,
# registerised with the native code generator (via C with `registerised =
# false`), no GHCi, one library way. 7.4.2 asks for a 6.12 or later as the
# bootstrapping compiler, so 7.0 and 7.2 are skipped. The tarball ships
# Parser.hs, Lexer.hs, CmmParse.hs and CmmLex.hs, used as shipped for now.
#
# build.mk as for 6.12 (nix/ghc612); GMP 6.1.2 as every rung before 8.0
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
, registerised ? true   # as nix/ghc612: NCG and tables next to code
, gdbModule ? null
  # diagnostic (as nix/ghc66): the in-place compiler runs under gdb for the
  # compile whose arguments contain this string; the backtrace goes to the log
}:

stdenv.mkDerivation {
  pname = "ghc" + (if registerised then "-registerised" else "");
  version = "7.4.2";
  src = fetchurl {
    url = "https://downloads.haskell.org/~ghc/7.4.2/ghc-7.4.2-src.tar.bz2";
    hash = "sha256-8u4SiaM8xwU5KHEphBrMfq8WESu2DFm1pu6RiHv9g20=";
  };
  nativeBuildInputs = [ perl ghc612 ] ++ lib.optional (gdbModule != null) gdb;
  buildInputs = [ gmp612 ncurses ];
  hardeningDisable = [ "all" ];
  dontStrip = true;
  env = ghc612.nonPie;
  passthru = { inherit (ghc612) nonPie; };

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
    $out/bin/ghc --numeric-version | grep -qx 7.4.2
  '';
}
