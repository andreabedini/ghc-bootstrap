# GHC 6.2.2 built by its own build system (configure, make boot, make, make
# install) with the chain's 6.2.2 (boot.nix, stage 3) as the bootstrapping
# compiler. Everything stages 1-3 did by hand because no GHC existed yet,
# 6.2.2's Makefiles do here: Config.hs, the primop tables, the RTS, base,
# haskell98, the other libraries, hsc2hs, ghc-pkg, and the install layout.
# Unregisterised via C, no GHCi, no native code generator, no profiling.
#
# What a 2026 host still needs from the chain:
#  - the RTS patches of ghc622/rts/patches (modern gcc; DECISIONS.md D41, D50)
#  - the HTYPE_* block ghc622/tools/gen-htypes.c computes, appended to mk/config.h:
#    configure's K&R probes leave them undefined under gcc >= 14 (D47)
#  - C flags for 2004 C and for the generated C (-std=gnu89 -fpermissive -w
#    -fwrapv), through build.mk as for 6.6, and -D_GNU_SOURCE for hsc2hs and
#    the C bits: today's glibc declares struct ucred (network's Socket.hsc)
#    only under it; and libraries/unix's own execvpe removed, glibc has one;
#    the same C flags in the rts package's extra_cc_opts, so the installed
#    compiler passes them to gcc for every program it compiles
#  - GMP 6.1.2 (gmp612/default.nix), not the host's GMP 6.3: from 6.2 on, GMP
#    leaves a zero-valued mpz result at a static dummy limb, which 6.2.2's
#    J# turns into a pointer into libgmp that the GC then follows
#    (common/test/GmpZero.hs; DECISIONS.md D52)
#  - happy: the chain has happy 1.19.5, not 2004's 1.14. Its output is made
#    acceptable to 6.2.2 by ghc622/tools/fix-generated-parsers.sh, so the happy on
#    the path is a wrapper that runs both, and the -agc template is turned
#    off (the chain's parsers were made with the portable one). Shipped
#    generated files (Lexer.hs: there is no alex) are touched so make keeps
#    them.
# Non-PIE (nix-non-pie) through the cc wrapper. Output: an installed 6.2.2,
# bin/ghc, bin/ghc-pkg, lib/ghc-6.2.2.
{ stdenv
, perl
, gmp612
, happy
, tree
, boot
}:

stdenv.mkDerivation {
  pname = "ghc-6.2.2";
  version = "6.2.2";
  src = tree.src;
  nativeBuildInputs = [ perl boot ];
  buildInputs = [ gmp612 ];
  hardeningDisable = [ "all" ];
  dontStrip = true;
  env = boot.nonPie;
  passthru = { inherit (boot) nonPie; };

  postPatch = ''
    patchShebangs .
    for p in ${../rts/patches}/*.patch; do
      msg=$(patch -p1 -N -i $p 2>&1) || { echo "$msg"; echo "FAILED: $p"; exit 1; }
      case $msg in *fuzz*|*offset*) echo "$msg"; echo "INEXACT: $p"; exit 1 ;; esac
    done

    # libraries/unix carries its own execvpe for libcs without one; glibc has
    # had it since 2.11, with const parameters, and the two declarations
    # clash. Drop the package's: the foreign import binds to glibc's.
    sed -i '/^extern int execvpe(char \*name, char \*\*argv, char \*\*envp);$/d' libraries/unix/include/HsUnix.h
    ! grep -q execvpe libraries/unix/include/HsUnix.h
    echo '/* execvpe: glibc provides it (ghc622/nix/inst.nix) */' > libraries/unix/cbits/execvpe.c
    # hslibs/posix declares it too (its cbits/env.c fails to compile, and the
    # fptools make loop carries on past it, leaving libHSposix_cbits short)
    sed -i '/^extern int  execvpe(char \*, char \*\*, char \*\*);$/d' hslibs/posix/cbits/HsPosix.h
    ! grep -q execvpe hslibs/posix/cbits/HsPosix.h

    # Every .hc the installed compiler compiles includes base's HsBase.h (K&R
    # definitions) through the package's c_includes; the rts package's
    # extra_cc_opts reach every compile, so the C flags go there, as the
    # checkout's topdir/package.conf and 6.6's cc-options patch do.
    sed -i 's/^        extra_cc_opts  = \[\],$/        extra_cc_opts  = [ "-std=gnu89", "-fpermissive", "-w", "-fwrapv" ],/' ghc/rts/package.conf.in
    grep -q '"-std=gnu89", "-fpermissive"' ghc/rts/package.conf.in

    # shipped generated sources stay; the rest happy makes
    for g in $(find . -name '*.y' -o -name '*.ly' -o -name '*.x'); do
      hs=''${g%.*}.hs; [ -f $hs ] && { touch $hs; echo "keeping shipped $hs"; }
    done
    mkdir -p $NIX_BUILD_TOP/bin
    cat > $NIX_BUILD_TOP/bin/happy <<'EOF'
    #!${stdenv.shell}
    # happy 1.19.5, then the 6.2.2 fix-ups on the .hs it wrote next to the grammar
    set -e
    ${happy}/bin/happy "$@"
    for a in "$@"; do
      case $a in
        *.y|*.ly) out=''${a%.*}.hs; [ -f "$out" ] && sh ${../tools/fix-generated-parsers.sh} "$out" ;;
      esac
    done
    EOF
    chmod +x $NIX_BUILD_TOP/bin/happy
    export PATH=$NIX_BUILD_TOP/bin:$PATH

    cat > mk/build.mk <<'EOF'
    GhcUnregisterised = YES
    GhcWithNativeCodeGen = NO
    GhcWithInterpreter = NO
    GhcLibWays =
    GhcRTSWays =
    SplitObjs = NO
    GhcLibsWithReadline = NO
    SGMLDocWays =
    XMLDocWays =
    GHC_HAPPY_OPTS =
    SRC_HAPPY_OPTS =
    SRC_CC_OPTS += -std=gnu89 -fpermissive -w -fwrapv -D_GNU_SOURCE
    SRC_HC_OPTS += -optc-std=gnu89 -optc-fpermissive -optc-w -optc-fwrapv
    SRC_HSC2HS_OPTS += --cflag=-std=gnu89 --cflag=-fpermissive --cflag=-w --cflag=-D_GNU_SOURCE
    EOF
  '';

  configurePhase = ''
    ./configure --prefix=$out --with-ghc=${boot}/bin/ghc --with-gcc=gcc \
      --host=x86_64-unknown-linux --build=x86_64-unknown-linux --target=x86_64-unknown-linux
    grep -q 'with-ghc=${boot}/bin/ghc' config.log
    grep -q '^HostArch_CPP[[:space:]]*=[[:space:]]*x86_64' mk/config.mk
    grep -Eq '^HAPPY[[:space:]]*=[[:space:]]*'$NIX_BUILD_TOP'/bin/happy$' mk/config.mk
    gcc -O -w -o gen-htypes ${../tools/gen-htypes.c}
    ./gen-htypes >> mk/config.h
    grep -q '^#define HTYPE_INT ' mk/config.h
  '';
  # fptools' make loops carry on past a failing subdirectory (hslibs/posix's
  # cbits did fail once and the build still exited 0), so every make's output
  # is kept and searched for `*** [target] Error` afterwards.
  buildPhase = ''
    ulimit -s unlimited
    export PATH=$NIX_BUILD_TOP/bin:$PATH
    checked() { "$@" 2>&1 | tee -a make.log; test ''${PIPESTATUS[0]} = 0; }
    checked make boot
    checked make
    ! grep -n '\*\*\* \[' make.log || { echo "a make step failed above"; exit 1; }
  '';
  installPhase = ''
    export PATH=$NIX_BUILD_TOP/bin:$PATH
    make install 2>&1 | tee install.log; test ''${PIPESTATUS[0]} = 0
    ! grep -n '\*\*\* \[' install.log || { echo "a make install step failed above"; exit 1; }
  '';
  enableParallelBuilding = false;

  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/ghc --numeric-version | grep -qx 6.2.2
    $out/bin/ghc-pkg -l
    mkdir t; cp ${../test/Hello.hs} t/Hello.hs
    (cd t && $out/bin/ghc -v0 --make Hello.hs -o hello && ./hello)
    # GMP >= 6.2 and 6.2.2's J# (gmp612/default.nix, D52): zeros kept live across GCs
    cp ${../../common/test/GmpZero.hs} t/GmpZero.hs
    (cd t && $out/bin/ghc -v0 -O --make GmpZero.hs -o gz && ./gz > gz.txt && printf "(2400000,0)\n" | diff - gz.txt)
  '';
}
