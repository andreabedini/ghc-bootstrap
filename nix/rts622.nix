# GHC 6.2.2's runtime system, unregisterised x86-64, compiled without a GHC:
# build/rts622/build-rts.sh. Every .c of ghc/rts, hooks/ and parallel/ except
# EXCLUDED_SRCS, the hand-written .hc files and the generated AutoApply.hc,
# with the flags ghc/rts/Makefile, mk/bootstrap.mk and the driver would pass
# (build/rts622/FINDINGS.md section 2). -std=gnu89: Stable.h's `extern
# inline' (DECISIONS.md D41). -fno-pie: nixpkgs' gcc defaults to PIE and the
# chain was built and verified non-PIE (Fedora's gcc has no
# --enable-default-pie); PIE moves the info tables from .rodata to
# .data.rel.ro and puts static data under ASLR. Output: lib/libHSrts.a.
{ stdenv
, runCommandCC
, mhs
, cpphs
, ghc622
}:

let
  # ghc/utils/genapply compiled by mhs (its Text.PrettyPrint is a shim), run
  # with the RTS's view of the registers (-DNO_REGS). The tarball does not
  # ship AutoApply.hc. Output: the file itself.
  autoApply = runCommandCC "ghc-6.2.2-AutoApply.hc"
    {
      nativeBuildInputs = [ mhs cpphs ];
      hardeningDisable = [ "all" ];
    }
    ''
      cp ${ghc622}/ghc/utils/genapply/GenApply.hs .
      mhs -XCPP -D__GLASGOW_HASKELL__=622 -DNO_REGS -I${ghc622}/ghc/utils/genapply \
          -i. -i${../build/rts622/genapply/shim} GenApply.hs -ogenapply
      ./genapply > $out
    '';
in
stdenv.mkDerivation {
  pname = "ghc-6.2.2-rts";
  version = "6.2.2";
  hardeningDisable = [ "all" ];
  dontUpdateAutotoolsGnuConfigScripts = true;
  dontConfigure = true;
  dontStrip = true;

  unpackPhase = ''
    mkdir ghc
    cp -r ${ghc622}/ghc/rts ${ghc622}/ghc/includes ghc/
    chmod -R u+w ghc
    cp ${autoApply} AutoApply.hc
  '';

  # build/rts622/patches, exactly: cast-as-lvalue, GC.c linkage, mblock map.
  patchPhase = ''
    for p in ${../build/rts622/patches}/*.patch; do
      msg=$(patch -p1 -N -i $p 2>&1) || { echo "$msg"; echo "FAILED: $p"; exit 1; }
      case $msg in *fuzz*|*offset*) echo "$msg"; echo "INEXACT: $p"; exit 1 ;; esac
    done
  '';

  buildPhase = ''
    flags="-std=gnu89 -O -w -fno-pie -DNO_REGS -DUSE_MINIINTERPRETER -DCOMPILING_RTS
           -D__GLASGOW_HASKELL__=622 -Ighc/includes -Ighc/rts -Ighc/rts/parallel"
    mkdir obj
    for src in ghc/rts/*.c ghc/rts/hooks/*.c ghc/rts/parallel/*.c; do
      base=$(basename $src .c)
      case $base in RtsDllMain|SysMan|Vis*) continue ;; esac
      gcc -c $flags $src -o obj/$base.o
    done
    for src in ghc/rts/*.hc ghc/rts/parallel/*.hc AutoApply.hc; do
      gcc -c -x c $flags -include ghc/includes/Stg.h $src -o obj/$(basename $src .hc).o
    done
    ls obj/*.o | wc -l | grep -qx 78
    ar rcs libHSrts.a obj/*.o
  '';

  installPhase = "install -Dm644 libHSrts.a $out/lib/libHSrts.a";
}
