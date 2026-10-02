# GHC 9.0.2 built by the chain's GHC 8.8.4 (nix/ghc88): configure and make
# (the last release with the make build system), registerised with the native
# code generator (via C with `registerised = false`), GHCi, static only.
# 9.0.2 asks for an 8.8 or later as the bootstrapping compiler; 8.10 is
# skipped. The tarball ships
# GHC/Parser.hs, GHC/Parser/Lexer.hs, GHC/Cmm/Parser.hs and GHC/Cmm/Lexer.hs.
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
# ghc-bignum records a GMP library directory only when told one, and
# without it a program compiled by the installed GHC outside Nix fails to
# link (-lgmp not found); the 8.x rungs' integer-gmp configure recorded it
# from the build environment.
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
  patches = [ ./StgCRunAsm-only-when-needed.patch ];

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
    ./configure --prefix=$out GHC=${ghc88}/bin/ghc CC=gcc \
      --with-gmp-includes=${gmp.dev}/include --with-gmp-libraries=${gmp}/lib \
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
    # ghc-bignum must know where libgmp is, or nothing links outside Nix
    $out/bin/ghc-pkg field ghc-bignum library-dirs | grep -q '${gmp}/lib'
    # the StgCRunAsm patch: no StgCRunAsm.o in the RTS, no executable stack
    ar t $out/lib/*/rts/libHSrts.a | grep -q StgCRun.o
    ! ar t $out/lib/*/rts/libHSrts.a | grep -q StgCRunAsm.o
    readelf -lW t/t3 | grep -E 'GNU_STACK.* RW ' > /dev/null
    $out/bin/ghc --numeric-version | grep -qx 9.0.2
  '';
}
