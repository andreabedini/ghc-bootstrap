# The tarball with phase4/patches applied exactly (no fuzz, no offset),
# configured for an unregisterised x86-64 build, with the three headers
# GHC's ghc/includes/Makefile makes: config.h (without the HTYPE block, see
# ghc622/tree.nix), DerivedConstants.h and NativeDefs.h.
# phase4/reproduce-6.2.2.sh steps 1-5b.
{ stdenv, perl, ghc622-src }:
stdenv.mkDerivation {
  pname = "ghc-6.2.2-configured";
  version = "6.2.2";
  src = ghc622-src;
  nativeBuildInputs = [ perl ];
  hardeningDisable = [ "all" ];
  dontFixup = true;

  patchPhase = ''
    runHook prePatch
    for p in ${../../phase4/patches}/*.patch; do
      msg=$(patch -p1 -N -i $p 2>&1) || { echo "$msg"; echo "FAILED: $p"; exit 1; }
      case $msg in *fuzz*|*offset*) echo "$msg"; echo "INEXACT: $p"; exit 1 ;; esac
    done
    runHook postPatch
  '';

  configurePhase = ''
    runHook preConfigure
    sh ./configure --enable-hc-boot --enable-hc-boot-unregisterised \
      --host=x86_64-unknown-linux --build=x86_64-unknown-linux --target=x86_64-unknown-linux
    grep -q '^HostArch_CPP[[:space:]]*=[[:space:]]*x86_64' mk/config.mk
    make -C ghc/includes config.h
    grep -q '^#define x86_64_TARGET_ARCH' ghc/includes/config.h
    runHook postConfigure
  '';

  # -no-pie: nixpkgs' gcc defaults to PIE, and a PIE linked with unresolved
  # symbols ignored has text relocations its loader refuses.
  buildPhase = ''
    runHook preBuild
    for h in DerivedConstants:mkDerivedConstants NativeDefs:mkNativeHdr; do
      gcc -O2 -w -no-pie -include stdio.h -DNO_REGS -DUSE_MINIINTERPRETER -Ighc/includes \
          -Wl,--unresolved-symbols=ignore-all ghc/includes/''${h#*:}.c -o ''${h#*:}
      ./''${h#*:} > ghc/includes/''${h%:*}.h
      rm ''${h#*:}
    done
    grep -Eq 'STD_ITBL_SIZE +3' ghc/includes/DerivedConstants.h
    grep -q OFFSET_R1 ghc/includes/NativeDefs.h
    runHook postBuild
  '';

  installPhase = "cp -a . $out";
}
