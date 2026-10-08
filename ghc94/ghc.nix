# GHC 9.4.8 built by the chain's GHC 9.0.2 (ghc90): configure and make.
# 9.4 is the last release that carries the make build system, and it keeps
# it only for a boot compiler older than 9.1 (configure.ac's
# MaxBootWithMakeGhcVersion, "Note [Support for building ghc 9.4 with the
# make build system]"), which a 9.0.2 is; nixpkgs 23.11 and Guix both build
# 9.4 this way. Registerised with the native code generator (via C with
# `registerised = false`), GHCi, static only. 9.4.8 asks for a 9.0 or
# later as the bootstrapping compiler; 9.2 is skipped. The tarball ships
# GHC/Parser.hs, GHC/Parser/Lexer.hs, GHC/Cmm/Parser.hs and GHC/Cmm/Lexer.hs,
# so neither happy nor alex is run, but the compiler, genprimopcode and hpc
# declare `build-tool-depends: alex >= 3.2.6, happy >= 1.20.0` and ghc-cabal
# refuses to configure them without the programs: happy 1.20.1.1 and alex
# 3.2.7.4, compiled by the chain's 9.0.2 (happy120.nix, alex327.nix).
#
# GhcWithInterpreter = YES and GhcWithSMP = YES from 8.8 on, the standard
# configuration (nixpkgs, Guix), after two upstream facts: 8.8.4's
# compiler/main/DynFlags.hs imports Foreign (Ptr) only `#if defined(GHCI)`
# but its stage-2 SHARED_GLOBAL_VAR needs Ptr whatever GHCI is, so a
# GHCi-less 8.8.4 does not compile ("Not in scope: type constructor or
# class `Ptr'", any boot compiler); and a NOSMP threaded RTS rejects -N and
# -qg as unknown options, while 9.8's Hadrian is linked with
# `-with-rtsopts=-I0 -qg`, so an SMP-less 9.4 cannot build 9.8. The 6.x-8.4
# rungs keep NO: they only ever compile the next rung.
#
# --with-gmp-includes/--with-gmp-libraries as nixpkgs passes them: from 9.0
# ghc-bignum records a GMP library directory only when told one. Without it
# the 9.4.8 could not link a program outside Nix (-lgmp not found): 9.4's
# settings name the Nix gcc wrapper by its store path, and that linker
# searches no /lib64. The rungs up to 9.0 record "gcc" and resolve it on
# PATH, so outside Nix they linked the host's libgmp by accident.
#
# Non-PIE (nix-non-pie) through the cc wrapper. Output: an installed GHC
# 9.4.8, bin/ghc.
{ stdenv
, fetchurl
, perl
, python3   # rts/gen_event_types.py
, gmp
, ncurses
, ghc90
, happy120
, alex327
, registerised ? true
}:

stdenv.mkDerivation {
  pname = "ghc" + (if registerised then "-registerised" else "");
  version = "9.4.8";
  src = fetchurl {
    url = "https://downloads.haskell.org/~ghc/9.4.8/ghc-9.4.8-src.tar.xz";
    sha256 = "0bf407eb67fe3e3c24b0f4c8dea8cb63e07f63ca0f76cf2058565143507ab85e";
  };
  nativeBuildInputs = [ perl python3 ghc90 happy120 alex327 ];
  buildInputs = [ gmp ncurses ];
  hardeningDisable = [ "all" ];
  dontStrip = true;
  env = ghc90.nonPie;
  passthru = { inherit (ghc90) nonPie; };

  # Upstream d61f7428 (#21478) as Guix carries it for 9.0-9.4: the make
  # build system linked rts/StgCRunAsm.S into the RTS on every architecture,
  # and on x86-64 that object is empty and carries no .note.GNU-stack, so
  # with a binutils before 2.44 every program linked against the RTS was
  # marked as needing an executable stack. Hadrian never had the problem;
  # make never got the fix. The commit as it is on GitLab is a no-op: its
  # ifneq joins the four $(findstring ...) with spaces, so the compared
  # string is never empty; Guix's copy removes the spaces, and so does this
  # one (checked with a two-line Makefile and by finding StgCRunAsm.o in
  # the libHSrts.a of a 9.0.2 built with the GitLab text).
  patches = [ ../ghc90/StgCRunAsm-only-when-needed.patch ];

  postPatch = ''
    patchShebangs .
    cat > mk/build.mk <<'EOF'
    GhcUnregisterised = ${if registerised then "NO" else "YES"}
    GhcWithNativeCodeGen = ${if registerised then "YES" else "NO"}
    GhcWithInterpreter = YES
    GhcWithSMP = YES
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
      --with-gmp-includes=${gmp.dev}/include --with-gmp-libraries=${gmp}/lib \
      CFLAGS="-std=gnu11 -w"
    grep -q 'GHC=${ghc90}/bin/ghc' config.log
    grep -Eq '^HAPPY[[:space:]]*=[[:space:]]*${happy120}/bin/happy$' mk/config.mk
    grep -Eq '^ALEX[[:space:]]*=[[:space:]]*${alex327}/bin/alex$' mk/config.mk
  '';
  preBuild = "ulimit -s unlimited; ulimit -c unlimited";   # cores reach the host's coredumpctl
  enableParallelBuilding = true;

  # common/test/T3.hs, compiled by the installed compiler with no extra flags.
  doInstallCheck = true;
  installCheckPhase = ''
    mkdir t; cp ${../common/test/T3.hs} t/T3.hs
    (cd t && $out/bin/ghc -v0 --make T3.hs -o t3 && ./t3 > out.txt)
    diff ${../common/test/T3.out} t/out.txt
    # ghc-bignum must know where libgmp is, or nothing links outside Nix
    $out/bin/ghc-pkg field ghc-bignum library-dirs | grep -q '${gmp}/lib'
    # the StgCRunAsm patch: no StgCRunAsm.o in the RTS, no executable stack
    ar t $out/lib/*/rts/libHSrts.a | grep -q StgCRun.o
    ! ar t $out/lib/*/rts/libHSrts.a | grep -q StgCRunAsm.o
    readelf -lW t/t3 | grep -E 'GNU_STACK.* RW ' > /dev/null
    $out/bin/ghc --numeric-version | grep -qx 9.4.8
  '';
}
