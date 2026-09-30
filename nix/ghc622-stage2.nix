# Stage 2: GHC 6.2.2's compiler proper compiled by stage 1 into a native
# compiler (build/Makefile's haskell98, stage2 and test targets;
# build/ghc622-stage2/LOG.md "Setup" for the source and topdir).
#
# The source is the pristine tarball, not the patched ghc622 tree: stage 2
# compiles GHC the way a GHC would. Added, as LOG.md lists: the parsers and
# primop tables the ghc622 tree regenerated (the tables in the compiler root,
# where the Makefile writes them), main/Config.hs, and the tree's
# ghc/includes (config.h, DerivedConstants.h, NativeDefs.h). Lexer.hs stays
# the shipped alex -g output: a native GHC reads its Addr# tables.
#
# Three derivations, so a late failure does not redo the long one:
# haskell98 (30 modules), hc (the 220 modules to .hi/.hc, ~4 hours), and the
# result (.hc -> .o, link, and the Hello.hs acceptance test).
# Output: bin/ghc and topdir/ (use as `ghc -B$out/topdir`).
{ lib
, stdenv
, runCommand
, python3
, gmp
, ghc622
, rts622
, ghc622-stage1
, ghc622-base
}:

let
  hidict = ../build/ghc622-mhs/test/hidict.py;
  stage1 = "${ghc622-stage1}/bin/ghc";

  # Config.hs is phase2/gen-6.2.2's with the booter's version (LOG.md).
  src = runCommand "ghc-6.2.2-stage2-src" { } ''
    mkdir $out
    tar xjf ${ghc622.src} -C $out --strip-components=1 \
      ghc-6.2.2/ghc ghc-6.2.2/mk ghc-6.2.2/libraries/base ghc-6.2.2/libraries/haskell98
    chmod -R u+w $out
    C=$out/ghc/compiler
    cp -r --no-preserve=mode ${ghc622.parsers}/. $C/
    cp ${ghc622.primops}/primops.txt $C/prelude/
    cp ${ghc622.primops}/primop-*.hs-incl $C/
    sed 's/^cBooterVersion        = "4.08.2"$/cBooterVersion        = "6.2.2"/' \
      ${../phase2/gen-6.2.2/Config.hs} > $C/main/Config.hs
    grep -q '"6.2.2"' $C/main/Config.hs
    rm -r $out/ghc/includes
    cp -r --no-preserve=mode ${ghc622}/ghc/includes $out/ghc/includes
  '';

  # build/ghc622-stage2/topdir: an "installed" layout. $1 = the directory
  # holding haskell98's .hi files and libHShaskell98.a.
  mkTopdir = h98: ''
    mkdir -p topdir/libraries
    cp ${../build/ghc622-stage2/topdir/package.conf} topdir/package.conf
    cp ${../build/ghc622-stage2/topdir/ghc-usage.txt} topdir/ghc-usage.txt
    cp ${ghc622-base.unlit} topdir/unlit
    ln -s ${src}/ghc/includes topdir/includes
    ln -s ${rts622}/lib topdir/rts
    ln -s ${ghc622-base}/libraries/base topdir/libraries/base
    ln -s ${ghc622-base}/lib topdir/libraries/base-lib
    ln -s ${h98} topdir/libraries/haskell98
  '';

  # libraries/haskell98, build/mk/compile-h98.sh per module, in the
  # dependency order of build/mk/deps.mk; then build/Makefile's HC2O_H98.
  haskell98 = stdenv.mkDerivation {
    pname = "ghc-6.2.2-haskell98";
    version = "6.2.2";
    dontUnpack = true;
    nativeBuildInputs = [ python3 ];
    hardeningDisable = [ "all" ];
    dontFixup = true;
    buildPhase = ''
      ulimit -s unlimited
      cp -r --no-preserve=mode ${src}/libraries/haskell98 h98
      ${mkTopdir "$PWD/h98"}
      cd h98
      for m in Ix Array Bits CError CForeign CPUTime CString CTypes Char Complex \
               Directory ForeignPtr IO Int List Locale MarshalAlloc MarshalArray \
               MarshalError MarshalUtils Maybe Monad Ptr Random Ratio StablePtr \
               Storable System Time Word; do
        export TMPDIR=$NIX_BUILD_TOP/tmp/$m; mkdir -p $TMPDIR
        (ulimit -v 8000000; timeout 1800 ${stage1} +RTS -K20M -RTS -B$NIX_BUILD_TOP/topdir \
           -v1 -C -O -package-name haskell98 -package base $m.hs) > $m.log 2>&1 \
          || { cat $m.log; echo "FAILED: $m"; exit 1; }
        python3 ${hidict} $m.hi 0 $m >> $m.log
        gcc -c -x c -std=gnu89 -O -fwrapv -w -fno-pie -DNO_REGS -DUSE_MINIINTERPRETER \
            -D__GLASGOW_HASKELL__=602 -I${src}/ghc/includes -I${src}/libraries/base/include \
            -include ${src}/ghc/includes/Stg.h $m.hc -o $m.o
        echo "haskell98 $m: OK"
      done
      ar rcs libHShaskell98.a *.o
    '';
    installPhase = "mkdir $out; cp *.hi *.hc libHShaskell98.a $out/";
  };

  # The 220 modules of build/ghc622-stage2/order.txt, build/mk/compile-stage2.sh
  # per module: the Makefile's flags and per-file extras, the flags.tsv seed,
  # the -O -> -O -fno-strictness -> -O0 ladder on a runtime death, panic or
  # timeout, fixups/ (Ctype.lhs, which the stage-1 compiler cannot read),
  # and hidict.py on every .hi.
  #
  # In three chunks of about 45 minutes (by the 2026-09-15 run's times), each
  # starting from the previous one's output: the whole compile is over two
  # hours, and a derivation cannot resume. Parser (18 min) ends chunk 2.
  #
  # The defaults are stage 2's; stages 3-5 (nix/ghc622-native.nix) pass a
  # native compiler as build/Makefile's STAGE3_ENV does: no fixups, no
  # flags.tsv seed, a 30-minute timeout, and their own output directory.
  hcChunk = { part, from, to, prev ? null, stage ? "stage2", ghc ? stage1
            , fixups ? true, flags ? ../build/ghc622-stage2/flags.tsv, modTimeout ? 3600 }:
  stdenv.mkDerivation {
    pname = "ghc-6.2.2-${stage}-hc${toString part}";
    version = "6.2.2";
    dontUnpack = true;
    nativeBuildInputs = [ python3 ];
    hardeningDisable = [ "all" ];
    dontFixup = true;
    buildPhase = ''
      ulimit -s unlimited
      ${mkTopdir haskell98}
      top=$PWD/topdir; odir=$PWD/${stage}
      mkdir -p ${stage} logs
      ${if prev == null then "" else "cp -r --no-preserve=mode ${prev}/${stage}/. ${stage}/; cp ${prev}/logs/* logs/"}
      cp -r --no-preserve=mode ${src}/ghc src
      SRC=$PWD/src/compiler
      idirs=
      for d in utils basicTypes types hsSyn prelude rename typecheck deSugar coreSyn \
               specialise simplCore stranal stgSyn simplStg codeGen absCSyn main \
               profiling parser cprAnalysis compMan ndpFlatten; do
        mkdir -p $odir/$d; idirs="$idirs -i$odir/$d"
        for b in $SRC/$d/*.hi-boot*; do [ -f $b ] && ln -s $b $odir/$d/; done
      done
      extra_flags() {
        case $1 in
          utils/Binary.hs) echo "-funbox-strict-fields -O" ;;
          main/ParsePkgConf.hs|parser/Parser.hs) echo "-fno-warn-incomplete-patterns" ;;
          parser/Lexer.hs) echo "-funbox-strict-fields" ;;
          main/BinIface.hs|utils/FastMutInt.lhs) echo "-O" ;;
          compMan/CompManager.lhs|main/CmdLineOpts.lhs|main/DriverFlags.hs|main/DriverMkDepend.hs|main/DriverPipeline.hs|main/DriverState.hs|main/DriverUtil.hs|main/Finder.lhs|main/SysTools.lhs) echo "-fno-cse" ;;
          prelude/PrimOp.lhs) echo "-no-recomp" ;;
        esac
      }
      attempt() {
        rm -f $hc $hi
        ( cd $SRC; ulimit -v 8000000
          timeout ${toString modTimeout} ${ghc} +RTS -K50M -RTS -B$top -v1 -C \
            -cpp -fglasgow-exts -I. -IcodeGen -InativeGen -Iparser -DOMIT_NATIVE_CODEGEN \
            '-#include' '"hschooks.h"' -recomp $idirs $1 $extra -o $hc -ohi $hi $srcf ) < /dev/null > $log 2>&1
      }
      retryable() {
        [ $1 = 124 ] || [ $1 = 137 ] || [ $1 = 134 ] || [ $1 = 139 ] || \
          grep -q -e 'ERR:' -e panic -e impossible -e exhausted -e 'stack overflow' \
                  -e Killed -e Segmentation -e 'out of memory' $log
      }
      sed -n '${toString from},${toString to}p' ${../build/ghc622-stage2/order.txt} > chunk.txt
      test $(wc -l < chunk.txt) = ${toString (to - from + 1)}
      while read -r m path; do
        dir=$(dirname $path); hc=$odir/$dir/$m.hc; hi=$odir/$dir/$m.hi; log=$PWD/logs/$m.log
        export TMPDIR=$NIX_BUILD_TOP/tmp/$m; mkdir -p $TMPDIR
        extra=$(extra_flags $path)
        srcf=$path${lib.optionalString fixups "; [ -f ${../build/ghc622-stage2/fixups}/$path ] && srcf=${../build/ghc622-stage2/fixups}/$path"}
        case $path in parser/Parser.hs) opt=-Onot ;; *) opt=-O ;; esac
        seed=$(awk -F'\t' -v m=$m '$1==m {print $2}' ${flags} | tail -1)
        case $seed in *-fno-strictness*) opt="-O -fno-strictness" ;; -O0) opt=-O0 ;; esac
        rc=0; attempt "$opt" || rc=$?
        if [ $rc != 0 ] && retryable $rc; then
          case $opt in -O0|-Onot) ;; *)
            case $opt in *-fno-strictness*) ;; *) opt="$opt -fno-strictness"; rc=0; attempt "$opt" || rc=$? ;; esac
            if [ $rc != 0 ] && retryable $rc; then opt=-O0; rc=0; attempt "$opt" || rc=$?; fi ;;
          esac
        fi
        if [ $rc != 0 ] || [ ! -f $hc ] || [ ! -f $hi ]; then cat $log; echo "FAILED: $m"; exit 1; fi
        python3 ${hidict} $hi 0 $m >> $log
        echo "${stage} $m: OK ($opt)"
      done < chunk.txt
    '';
    # the .hi-boot links point into the build directory
    installPhase = "find ${stage} -type l -delete; mkdir $out; cp -r ${stage} logs $out/";
  };
  hc1 = hcChunk { part = 1; from = 1; to = 111; };
  hc2 = hcChunk { part = 2; from = 112; to = 156; prev = hc1; };
  hc = hcChunk { part = 3; from = 157; to = 220; prev = hc2; };

  # .hc -> .o, the link, and the Hello.hs test, for the modules of `hc` (whose
  # output holds them under `stage`/). With `ref`, a compiler whose test/Hello.hc
  # this one's is compared with (build/Makefile test3: reported, not a failure).
  linked = { stage, hc, ref ? null, passthru ? { } }: stdenv.mkDerivation {
    pname = "ghc-6.2.2-${stage}";
    version = "6.2.2";
    dontUnpack = true;
    nativeBuildInputs = [ python3 ];
    buildInputs = [ gmp ];
    hardeningDisable = [ "all" ];
    dontStrip = true;
    passthru = passthru // { inherit hc; };

    buildPhase = ''
      ulimit -s unlimited
      C=${src}/ghc/compiler
      ccflags="-std=gnu89 -O -w -fno-pie -DNO_REGS -DUSE_MINIINTERPRETER -D__GLASGOW_HASKELL__=602
               -I${src}/ghc/includes -I$C/parser -I$C -I${src}/libraries/base/include"
      mkdir obj
      # build/Makefile HC2O_STAGE2, and CC_COMPILER_C for the two C files.
      for hc in $(cd ${hc}/${stage} && find . -name '*.hc' | sort); do
        gcc -c -x c $ccflags -fwrapv -include ${src}/ghc/includes/Stg.h \
            ${hc}/${stage}/$hc -o obj/$(echo ''${hc#./} | tr / _ | sed 's/\.hc$//').o
      done
      test $(ls obj/*.o | wc -l) = 220
      gcc -c $ccflags $C/parser/hschooks.c -o obj/c_hschooks.o
      gcc -c $ccflags $C/cbits/rawSystem.c -o obj/c_rawSystem.o

      # build/ghc622-stage2/link-stage2.sh: haskell98, base, rts, and rts's
      # extra_ld_opts (the 32 -u symbols), taken from the package.conf.
      u=$(grep -o '"-u", "[A-Za-z_0-9]*"' ${../build/ghc622-stage2/topdir/package.conf} | sed 's/"-u", "\(.*\)"/-u \1/')
      test $(echo "$u" | wc -l) = 32
      gcc -no-pie -o ghc obj/*.o -L${haskell98} -L${ghc622-base}/lib -L${rts622}/lib \
          -lHShaskell98 -lHSbase -lHSbase_cbits -lHSrts -lm -lgmp -ldl $u

      # The acceptance test (build/Makefile test): stage 2 compiles Hello.hs.
      ${mkTopdir haskell98}
      mkdir test; cp ${../build/ghc622-stage2/test/Hello.hs} test/Hello.hs
      (cd test && TMPDIR=$NIX_BUILD_TOP ../ghc -B../topdir -v1 -C -O Hello.hs)
      python3 ${hidict} test/Hello.hi 0 Main${lib.optionalString (ref != null) ''

      if cmp -s test/Hello.hc ${ref}/test/Hello.hc; then echo "${ref.pname} and ${stage} agree on test/Hello.hc"
      else echo "${ref.pname} and ${stage} DIFFER on test/Hello.hc: $(diff test/Hello.hc ${ref}/test/Hello.hc | grep -c '^[<>]') lines"; fi''}
    '';

    installPhase = ''
      install -Dm755 ghc $out/bin/ghc
      cp -r topdir $out/topdir
      mkdir $out/test; cp test/Hello.hc test/Hello.hi $out/test/
    '';
  };
in
linked {
  stage = "stage2";
  inherit hc;
  passthru = { inherit src haskell98 hc1 hc2 hcChunk linked; };
}
