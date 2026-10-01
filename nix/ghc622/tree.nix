# GHC 6.2.2's source tree in the shape the chain compiles: the configured
# tree with the generated files dropped in, the HTYPE block appended inside
# config.h's include guard, and the ghc-pkg link. phase4/reproduce-6.2.2.sh
# steps 6-8. The output is the whole source root ($out/ghc/compiler is what
# mhs compiles, $out/ghc/rts what the RTS build starts from).
{ stdenv
, runCommand
, fetchurl
, python3
, runCommandCC
, mhs
, cpphs
, happy
, perl
}:

let
  # The pristine GHC 6.2.2 source tarball (SOURCES.md).
  ghc622-src = fetchurl {
    url = "https://downloads.haskell.org/~ghc/6.2.2/ghc-6.2.2-src.tar.bz2";
    sha256 = "a0fe7eb8d447f25fbc616cdbce2bb4e03961a884c2c37969d1e23588b588a852";
  };

  # parser/Lexer.hs as shipped (alex -g output) with its Addr# tables decoded
  # into boxed arrays (build/lexer622/FINDINGS.md). Output: the file itself.
  ghc622-lexer = runCommand "ghc-6.2.2-Lexer.hs" { nativeBuildInputs = [ python3 ]; } ''
    tar xjf ${ghc622-src} --strip-components=4 ghc-6.2.2/ghc/compiler/parser/Lexer.hs
    python3 ${../../phase4/convert-lexer.py} Lexer.hs $out
  '';

  # The three happy grammars, with the portable template (no -agc), then the
  # 6.2.2 fix-ups of phase4/fix-generated-parsers.sh. Output: main/ and
  # parser/, relative to ghc/compiler.
  ghc622-parsers = runCommand "ghc-6.2.2-parsers" { nativeBuildInputs = [ happy ]; } ''
    ys="main/ParsePkgConf parser/ParserCore parser/Parser"
    tar xjf ${ghc622-src} --strip-components=3 $(for y in $ys; do echo ghc-6.2.2/ghc/compiler/$y.y; done)
    for y in $ys; do
      mkdir -p $out/$(dirname $y)
      happy $y.y -o $out/$y.hs
      sh ${../../phase4/fix-generated-parsers.sh} $out/$y.hs
    done
  '';

  # GHC 6.2.2's genprimopcode compiled by mhs, with one edit
  # (phase4/genprimopcode-Main.hs.patch) and the Parsec slice shim: cpphs
  # leaves __GLASGOW_HASKELL__ undefined, so Main.hs imports Parsec.
  ghc622-genprimopcode = runCommandCC "ghc-6.2.2-genprimopcode"
    {
      nativeBuildInputs = [ mhs cpphs ];
      hardeningDisable = [ "all" ];
    }
    ''
      tar xjf ${ghc622-src} --strip-components=4 ghc-6.2.2/ghc/utils/genprimopcode/Main.hs
      patch -s Main.hs ${../../phase4/genprimopcode-Main.hs.patch}
      cp ${../../build/shims-6.2.2-run1/Parsec.hs} Parsec.hs
      mhs -XCPP -i. -i${../../phase1/shims-h98} Main -ogenprimopcode
      install -Dm755 genprimopcode $out/bin/genprimopcode
    '';

  # The tarball with phase4/patches applied exactly (no fuzz, no offset),
  # configured for an unregisterised x86-64 build, with the three headers
  # GHC's ghc/includes/Makefile makes: config.h (without the HTYPE block, which
  # is appended last), DerivedConstants.h and NativeDefs.h.
  # phase4/reproduce-6.2.2.sh steps 1-5b.
  ghc622-configured = stdenv.mkDerivation {
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
  };

  # prelude/primops.txt and the ten tables ghc/compiler/Makefile makes from it.
  # cpphs, not gcc's cpp: only cpphs --noline --strip reproduces the file
  # (phase4/regen-generated.sh). It reads config.h through MachDeps.h, hence
  # the configured tree.
  ghc622-primops = runCommand "ghc-6.2.2-primops"
    { nativeBuildInputs = [ cpphs ghc622-genprimopcode ]; }
    ''
      T=${ghc622-configured}/ghc
      mkdir $out
      cpphs --noline --strip -I$T/includes $T/compiler/prelude/primops.txt.pp > $out/primops.txt
      for pair in data-decl:data-decl primop-tag:tag primop-list:list \
                  has-side-effects:has-side-effects out-of-line:out-of-line \
                  commutable:commutable needs-wrapper:needs-wrapper can-fail:can-fail \
                  strictness:strictness primop-primop-info:primop-info; do
        genprimopcode --''${pair%%:*} < $out/primops.txt > $out/primop-''${pair##*:}.hs-incl
      done
    '';

  # The HTYPE_* defines configure's K&R probes no longer produce under
  # gcc >= 14 (DECISIONS.md D47). Output: the block to append to config.h.
  ghc622-htypes = runCommandCC "ghc-6.2.2-htypes.h" { } ''
    gcc -O -w -o gen-htypes ${../../phase4/gen-htypes.c}
    ./gen-htypes > $out
  '';

in
# passthru: later stages reuse these (base: genprimopcode; stage 2: the
# pristine tarball with the same generated parsers and primop tables).
runCommand "ghc-6.2.2-tree"
  {
    passthru = {
      src = ghc622-src;
      genprimopcode = ghc622-genprimopcode;
      parsers = ghc622-parsers;
      primops = ghc622-primops;
    };
  }
  ''
  cp -a ${ghc622-configured} $out
  chmod -R u+w $out
  C=$out/ghc/compiler
  cp ${ghc622-primops}/* $C/prelude/
  cp -r --no-preserve=mode ${ghc622-parsers}/. $C/
  cp ${ghc622-lexer} $C/parser/Lexer.hs

  H=$out/ghc/includes/config.h
  tail -1 $H | grep -q '^#endif'
  { sed '$d' $H; cat ${ghc622-htypes}; printf '\n#endif /* __FPTOOLS_CONFIG_H__ */\n'; } > config.h
  mv config.h $H
  grep -q '^#define HTYPE_INT ' $H

  ln -s ../../utils/ghc-pkg $C/utils/ghc-pkg
''
