# The chain's GHC 6.2.2 (stage 3) presented as an installed compiler, as
# build/ghc66-by-622/ghc622-inst/ does: bin/ghc wraps stage 3 with -B its
# topdir and a side package.conf; bin/ghc-pkg is 6.2.2's own ghc-pkg compiled
# by stage 3; the side package.conf holds parsec (6.2.2's libraries/parsec,
# compiled by stage 3) and the empty packages unix, lang, util, text and data,
# which 6.6's stage 1 and utils name (build/ghc66-by-622/NOTES.md run 1).
# Used to build GHC 6.6 (nix/ghc66/ghc.nix) and the happy and alex that
# regenerate its parsers (nix/ghc66/happy116.nix, nix/ghc66/alex210.nix).
#
# Non-PIE (nix-non-pie): the wrapped ghc calls gcc itself for .hc files and
# links, so -fno-pie/-no-pie go through the cc wrapper.
{ stdenv
, gmp
, tree
, stage3
}:

let
  nonPie = { NIX_CFLAGS_COMPILE = "-fno-pie"; NIX_CFLAGS_LINK = "-no-pie"; };
  s3 = stage3;
in
stdenv.mkDerivation {
  pname = "ghc-6.2.2-inst";
  version = "6.2.2";
  dontUnpack = true;
  buildInputs = [ gmp ];
  hardeningDisable = [ "all" ];
  dontStrip = true;
  env = nonPie;
  passthru = { inherit nonPie; };
  buildPhase = ''
    ulimit -s unlimited
    mkdir -p $out/bin $out/libraries/parsec
    sed "s|/home/andrea/code/haskell/ghc-bootstrap/build/ghc66-by-622/ghc622-inst|$out|" \
      ${../../build/ghc66-by-622/ghc622-inst/package.conf} > $out/package.conf
    grep -q "$out/libraries/parsec" $out/package.conf
    cat > $out/bin/ghc <<EOF
    #!${stdenv.shell}
    ulimit -s unlimited 2>/dev/null
    exec ${s3}/bin/ghc -B${s3}/topdir -package-conf $out/package.conf "\$@"
    EOF
    chmod +x $out/bin/ghc; ln -s ghc $out/bin/ghc-6.2.2
    $out/bin/ghc --numeric-version | grep -qx 6.2.2

    # ghc-pkg from the configured tree (its Main.hs includes ghc/includes/config.h),
    # as the checkout's from build/ghc-6.2.2-run1; its sources are the tarball's.
    tar xjf ${tree.src} ghc-6.2.2/libraries/parsec
    export TMPDIR=$NIX_BUILD_TOP/tmp; mkdir -p $TMPDIR
    P=${tree}/ghc/utils/ghc-pkg
    mkdir ghc-pkg-obj
    (ulimit -v 8000000; $out/bin/ghc -v1 --make -cpp -DPKG_TOOL -DWANT_PRETTY -O -I$P -i$P \
       -odir ghc-pkg-obj -hidir ghc-pkg-obj -o $out/bin/ghc-pkg.bin $P/Main.hs)
    cat > $out/bin/ghc-pkg <<EOF
    #!${stdenv.shell}
    exec $out/bin/ghc-pkg.bin -f ${s3}/topdir/package.conf -f $out/package.conf \''${1+"\$@"}
    EOF
    chmod +x $out/bin/ghc-pkg; ln -s ghc-pkg $out/bin/ghc-pkg-6.2.2

    O=$out/libraries/parsec
    (cd ghc-6.2.2/libraries/parsec && ulimit -v 8000000 && \
     $out/bin/ghc -v1 --make -O -fglasgow-exts -package-name parsec -odir $O -hidir $O \
       Text/ParserCombinators/Parsec.hs Text/ParserCombinators/Parsec/*.hs)
    (cd $O && find . -name '*.o' | sort | xargs ar rcs libHSparsec.a && find . -name '*.o' -delete)
    test $(find $O -name '*.hi' | wc -l) = 10
  '';
  installPhase = "true";
}
