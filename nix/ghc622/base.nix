# libraries/base compiled by stage 1, the way build/Makefile's `base` target
# does it: build/mk/compile-base.sh for each of the 147 modules in
# build/ghc622-mhs/diag/base-rebuild-order.txt (retrying with -fno-strictness
# when the MicroHs stack or heap runs out, and checking every .hi decodes),
# the Makefile's HC2O_BASE for .hc -> .o, build/ghc622-mhs/build-cbits.sh
# and build-libbase.sh. Before that, the five generated modules the tarball
# lacks: GHC/PrimopWrappers.hs (genprimopcode) and four .hsc files (hsc2hs).
# -fno-pie throughout, as the chain was verified.
# Output: libraries/base (sources, .hi, .hc) and lib/libHSbase{,_cbits}.a.
{ stdenv
, runCommandCC
, python3
, mhs
, cpphs
, tree
, rts
, stage1
}:

let
  inc = "${tree}/ghc/includes";

  # ghc/utils/unlit, which the driver runs on .lhs sources. K&R C.
  unlit = runCommandCC "ghc-6.2.2-unlit" { hardeningDisable = [ "all" ]; } ''
    gcc -std=gnu89 -Wno-implicit-int -Wno-implicit-function-declaration \
        -include string.h ${tree}/ghc/utils/unlit/unlit.c -o $out
  '';

  # GHC 6.2.2's hsc2hs compiled by mhs, from build/hsc2hs-mhs's copy (Parser
  # instances split for the post-AMP Prelude, build/hsc2hs-mhs/FINDINGS.md).
  # Main.hs includes ../../includes/config.h, hence the tarball layout.
  hsc2hs = runCommandCC "ghc-6.2.2-hsc2hs"
    {
      nativeBuildInputs = [ mhs cpphs ];
      hardeningDisable = [ "all" ];
    }
    ''
      mkdir -p ghc/utils
      cp -r ${../../build/hsc2hs-mhs/ghc/utils/hsc2hs} ghc/utils/hsc2hs
      chmod -R u+w ghc
      ln -s ${inc} ghc/includes
      cd ghc/utils/hsc2hs
      mhs -XCPP -D__GLASGOW_HASKELL__=622 -i. -i${../../build/hsc2hs-mhs/shims} \
          -i${../../phase1/shims-h98} Main -ohsc2hs
      install -Dm755 hsc2hs $out/bin/hsc2hs
      install -Dm644 template-hsc.h $out/share/template-hsc.h
    '';
in
stdenv.mkDerivation {
  pname = "ghc-6.2.2-base";
  version = "6.2.2";
  dontUnpack = true;
  nativeBuildInputs = [ python3 ];
  hardeningDisable = [ "all" ];
  dontFixup = true;
  passthru = { inherit unlit; };  # stage 2's topdir has the same unlit

  buildPhase = ''
    runHook preBuild
    ulimit -s unlimited

    # topdir: build/ghc622-mhs/topdir, with the same links.
    top=$PWD/topdir
    mkdir -p libraries $top
    cp -r ${tree}/libraries/base libraries/base
    chmod -R u+w libraries
    cp ${../../build/ghc622-mhs/topdir/package.conf} $top/package.conf
    cp ${../../build/ghc622-mhs/topdir/ghc-usage.txt} $top/ghc-usage.txt
    cp ${unlit} $top/unlit
    ln -s ${inc} $top/includes
    ln -s ${rts}/lib $top/rts
    ln -s ../libraries $top/libraries
    cd libraries/base

    ${tree.genprimopcode}/bin/genprimopcode --make-haskell-wrappers \
      < ${tree}/ghc/compiler/prelude/primops.txt > GHC/PrimopWrappers.hs
    # mk/suffix.mk's %.hs: %.hsc with base's HSC2HS_OPTS, and the driver
    # script's --cflag=-std=gnu89 (HsBase.h has K&R definitions).
    for h in System/CPUTime System/Time System/Posix/Signals Text/Regex/Posix; do
      ${hsc2hs}/bin/hsc2hs --template=${hsc2hs}/share/template-hsc.h --cc=gcc --ld=gcc \
        --cflag=-std=gnu89 --cflag=-D__GLASGOW_HASKELL__=622 -I${inc} \
        -Iinclude -I${inc} -I. $h.hsc
    done

    # build/mk/compile-base.sh, one module at a time in dependency order.
    compile() {
      timeout 1800 ${stage1}/bin/ghc +RTS -K5M -RTS -B$top -v1 -C \
        -fglasgow-exts -cpp -Iinclude '-#include' HsBase.h -funbox-strict-fields \
        -package-name base -O "$@" $src > $log 2>&1
    }
    mkdir -p ../../logs ../../obj
    for m in $(cat ${../../build/ghc622-mhs/diag/base-rebuild-order.txt}); do
      p=$(echo $m | tr . /); log=../../logs/$m.log
      if [ -f $p.lhs ]; then src=$p.lhs; else src=$p.hs; fi
      export TMPDIR=$NIX_BUILD_TOP/tmp/$m; mkdir -p $TMPDIR
      rc=0; compile || rc=$?; note=
      if grep -qE 'ERR: stack overflow|ERR: heap exhausted|stack overflow: use \+RTS' $log; then
        rc=0; compile -fno-strictness || rc=$?; note=" [-fno-strictness]"
      fi
      if [ $rc != 0 ] || [ ! -f $p.hc ] || [ ! -f $p.hi ]; then cat $log; echo "FAILED: $m"; exit 1; fi
      python3 ${../../build/ghc622-mhs/test/hidict.py} $p.hi 0 $m >> $log
      echo "base $m: OK$note"

      # build/Makefile HC2O_BASE; -fwrapv is mandatory.
      gcc -c -x c -std=gnu89 -O -fwrapv -w -fno-pie -DNO_REGS -DUSE_MINIINTERPRETER \
          -D__GLASGOW_HASKELL__=622 -I${inc} -Iinclude -I. -include ${inc}/Stg.h \
          $p.hc -o ../../obj/$(echo $m | tr . _).o
    done
    test $(ls ../../obj/*.o | wc -l) = 147

    # build-cbits.sh: cbits/*.c minus ilxstubs and consUtils (regex/ is
    # excluded: HavePosixRegex = YES), and the Control.Concurrent stub.
    cflags="-std=gnu89 -O -w -fno-pie -DNO_REGS -DUSE_MINIINTERPRETER -DCOMPILING_STDLIB
            -D__GLASGOW_HASKELL__=622 -I${inc} -I${tree}/ghc/rts"
    mkdir ../../cbits
    for c in cbits/*.c; do
      b=$(basename $c .c)
      case $b in ilxstubs|consUtils) continue ;; esac
      gcc -c $cflags -Iinclude $c -o ../../cbits/$b.o
    done
    gcc -c $cflags -Iinclude -I. Control/Concurrent_stub.c -o ../../Control_Concurrent_stub.o

    # build-libbase.sh
    ar rcs ../../libHSbase.a ../../obj/*.o ../../Control_Concurrent_stub.o
    ar rcs ../../libHSbase_cbits.a ../../cbits/*.o
    cd ../..
    runHook postBuild
  '';

  installPhase = ''
    mkdir -p $out/libraries $out/lib
    cp -r libraries/base $out/libraries/base
    cp libHSbase.a libHSbase_cbits.a $out/lib/
  '';
}
