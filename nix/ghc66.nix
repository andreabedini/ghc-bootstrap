# GHC 6.6 built by the chain's GHC 6.2.2 (build/ghc66-by-622, NOTES.md):
# unregisterised via C, no GHCi, no native code generator, no profiling, with
# the four tree edits of ghc-6.6-by-622.patch. The tarball's pre-generated
# Parser.hs, Lexer.hs and ParserCore.hs are used (there is no alex).
#
# Two derivations: `inst`, the 6.2.2 presented as an installed compiler, and
# the 6.6 build itself (configure, make, make install, and test/T2.hs through
# the installed compiler). Output: an installed GHC 6.6, bin/ghc.
#
# Non-PIE (nix-non-pie): every gcc call, including the ones both GHCs make
# for .hc files and links, goes through the cc wrapper, so -fno-pie/-no-pie
# are given there rather than in each Makefile.
{ stdenv
, fetchurl
, perl
, gmp
, readline
, ncurses
, happy
, ghc622
, ghc622-stage3
}:

let
  nonPie = { NIX_CFLAGS_COMPILE = "-fno-pie"; NIX_CFLAGS_LINK = "-no-pie"; };
  s3 = ghc622-stage3;

  # ghc622-inst/: bin/ghc wraps stage 3 with -B its topdir and a side
  # package.conf; bin/ghc-pkg is 6.2.2's own ghc-pkg compiled by stage 3; the
  # side package.conf holds parsec (6.2.2's libraries/parsec, compiled by
  # stage 3) and the empty packages unix, lang, util, text and data, which
  # 6.6's stage 1 and utils name (NOTES.md run 1).
  inst = stdenv.mkDerivation {
    pname = "ghc-6.2.2-inst";
    version = "6.2.2";
    dontUnpack = true;
    buildInputs = [ gmp ];
    hardeningDisable = [ "all" ];
    dontStrip = true;
    env = nonPie;
    buildPhase = ''
      ulimit -s unlimited
      mkdir -p $out/bin $out/libraries/parsec
      sed "s|/home/andrea/code/haskell/ghc-bootstrap/build/ghc66-by-622/ghc622-inst|$out|" \
        ${../build/ghc66-by-622/ghc622-inst/package.conf} > $out/package.conf
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
      tar xjf ${ghc622.src} ghc-6.2.2/libraries/parsec
      export TMPDIR=$NIX_BUILD_TOP/tmp; mkdir -p $TMPDIR
      P=${ghc622}/ghc/utils/ghc-pkg
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
  };
in
stdenv.mkDerivation {
  pname = "ghc";
  version = "6.6";
  src = fetchurl {
    url = "https://downloads.haskell.org/~ghc/6.6/ghc-6.6-src.tar.bz2";
    sha256 = "79b2a29136d56c8120a526188297603304dc80d3093cda76fde939df7d4dcc7e";
  };
  patches = [ ../build/ghc66-by-622/ghc-6.6-by-622.patch ];
  patchFlags = [ "-p1" ];
  nativeBuildInputs = [ perl happy ];
  buildInputs = [ gmp readline ncurses ];
  hardeningDisable = [ "all" ];
  dontStrip = true;
  env = nonPie;
  passthru = { inherit inst; };

  postPatch = "patchShebangs .";
  # build-66.sh's configure line
  configurePhase = ''
    ./configure --prefix=$out --with-ghc=${inst}/bin/ghc --with-gcc=gcc \
      CFLAGS="-std=gnu89 -fpermissive -w"
    grep -q 'with-ghc=${inst}/bin/ghc' config.log
  '';
  preBuild = "ulimit -s unlimited";
  enableParallelBuilding = false;

  # test/T2.hs by the installed compiler, with no extra flags (NOTES.md,
  # "Verification"); the expected output is T2's by construction.
  doInstallCheck = true;
  installCheckPhase = ''
    mkdir t2; cp ${../build/ghc66-by-622/test/T2.hs} t2/T2.hs
    (cd t2 && $out/bin/ghc -v0 --make T2.hs -o t2 && ./t2 > out.txt)
    cat > t2/expected.txt <<'EOF'
    hello from ghc 6.6 built by 6.2.2
    ([1,2,3],[(1,"a"),(2,"b")])
    (1606938044258990275541962092341162602522202993782792835301376,-9223372036854775808,9223372036854775807)
    ("1.5",2.25,2)
    Left divide by zero
    2568
    EOF
    diff t2/expected.txt t2/out.txt
    $out/bin/ghc --numeric-version | grep -qx 6.6
  '';
}
