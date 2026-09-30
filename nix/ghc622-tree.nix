# GHC 6.2.2's source tree in the shape the chain compiles: patched,
# configured, with every generated file regenerated inside the chain.
# phase4/reproduce-6.2.2.sh steps 1-9, which say why each step is there;
# phase4/FINDINGS.md records the provenance of each input.
#
# The output is the whole source root ($out/ghc/compiler is what mhs compiles,
# $out/ghc/rts what the RTS build starts from).
{
  stdenv,
  fetchurl,
  perl,
  python3,
  mhs,
  cpphs,
  happy,
}:
stdenv.mkDerivation {
  pname = "ghc-6.2.2-tree";
  version = "6.2.2";
  src = fetchurl {
    url = "https://downloads.haskell.org/~ghc/6.2.2/ghc-6.2.2-src.tar.bz2";
    sha256 = "a0fe7eb8d447f25fbc616cdbce2bb4e03961a884c2c37969d1e23588b588a852";
  };
  nativeBuildInputs = [ perl python3 mhs cpphs happy ];
  hardeningDisable = [ "all" ];
  # The tree is data for later steps: no shebang patching, no stripping.
  dontFixup = true;

  # Exact application: no fuzz, no offset.
  patchPhase = ''
    runHook prePatch
    for p in ${../phase4/patches}/*.patch; do
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

  buildPhase = ''
    runHook preBuild
    C=ghc/compiler

    # DerivedConstants.h and NativeDefs.h, with the unregisterised flags.
    # -no-pie: nixpkgs' gcc defaults to PIE, and a PIE linked with unresolved
    # symbols ignored has text relocations its loader refuses.
    for h in DerivedConstants:mkDerivedConstants NativeDefs:mkNativeHdr; do
      gcc -O2 -w -no-pie -include stdio.h -DNO_REGS -DUSE_MINIINTERPRETER -Ighc/includes \
          -Wl,--unresolved-symbols=ignore-all ghc/includes/''${h#*:}.c -o ''${h#*:}
      ./''${h#*:} > ghc/includes/''${h%:*}.h
    done
    grep -Eq 'STD_ITBL_SIZE +3' ghc/includes/DerivedConstants.h
    grep -q OFFSET_R1 ghc/includes/NativeDefs.h

    # genprimopcode, compiled by mhs (phase4/regen-generated.sh).
    mkdir genprimopcode
    cp ghc/utils/genprimopcode/Main.hs genprimopcode/
    patch -s genprimopcode/Main.hs ${../phase4/genprimopcode-Main.hs.patch}
    cp ${../build/shims-6.2.2-run1/Parsec.hs} genprimopcode/Parsec.hs
    (cd genprimopcode && mhs -XCPP -i. -i${../phase1/shims-h98} Main -ogenprimopcode)

    # primops.txt and the ten tables.
    cpphs --noline --strip -Ighc/includes $C/prelude/primops.txt.pp > $C/prelude/primops.txt
    for pair in data-decl:data-decl primop-tag:tag primop-list:list \
                has-side-effects:has-side-effects out-of-line:out-of-line \
                commutable:commutable needs-wrapper:needs-wrapper can-fail:can-fail \
                strictness:strictness primop-primop-info:primop-info; do
      genprimopcode/genprimopcode --''${pair%%:*} < $C/prelude/primops.txt \
        > $C/prelude/primop-''${pair##*:}.hs-incl
    done
    rm -r genprimopcode

    # The three parsers, portable template, then 6.2.2's fix-ups.
    for y in main/ParsePkgConf parser/ParserCore parser/Parser; do
      happy $C/$y.y -o $C/$y.hs
      sh ${../phase4/fix-generated-parsers.sh} $C/$y.hs
    done

    # HTYPE_* appended inside config.h's include guard (DECISIONS.md D47).
    gcc -O -w -o gen-htypes ${../phase4/gen-htypes.c}
    tail -1 ghc/includes/config.h | grep -q '^#endif'
    { sed '$d' ghc/includes/config.h; ./gen-htypes
      printf '\n#endif /* __FPTOOLS_CONFIG_H__ */\n'; } > config.h.new
    mv config.h.new ghc/includes/config.h
    grep -q '^#define HTYPE_INT ' ghc/includes/config.h

    # The alex lexer's Addr# tables, decoded into boxed arrays.
    python3 ${../phase4/convert-lexer.py} $C/parser/Lexer.hs Lexer.hs.new
    mv Lexer.hs.new $C/parser/Lexer.hs

    ln -s ../../utils/ghc-pkg $C/utils/ghc-pkg
    rm -f mkDerivedConstants mkNativeHdr gen-htypes
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    cp -a . $out
    runHook postInstall
  '';
}
