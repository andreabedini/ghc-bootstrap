# alex 3.2.7.4 reached from the hand-written alex 2.1.0 scanner, every alex
# compiled by mhs. ghc74.alex327 starts from the src/Scan.hs its tarball
# ships and checks it by a fixed point; here that Scan.hs comes from the
# alex 2.1.0 of alex210ddc.nix (alexB there: built from the Scan.hs that
# the hand-written scanner's alex made, and checked against the 2.1.0
# tarball's), in one step, since 2.1.0 accepts 3.2.7.4's Scan.x as it is
# (its rules use nothing newer than a right context and start codes):
#
#   step 1  alex 2.1.0 on 3.2.7.4's Scan.x, plain Haskell (no -g)
#   alexA   alex 3.2.7.4 compiled by mhs with that Scan.hs
#   genA    alexA's `alex -g Scan.x`    -> run as src/Scan.x, must be the
#                                          tarball's src/Scan.hs byte for byte
#   alexB   alex 3.2.7.4 compiled by mhs with alexA's plain `alex Scan.x`
#   genB    alexB's `alex -g Scan.x`    -> must be genA's byte for byte,
#                                          and its plain output alexA's
#
# step 1 is not compared with anything: 2.1.0 writes different code from
# 3.2.7.4. mhs cannot compile -g output (unboxed Addr# tables), so each alex
# is built from the plain one and the -g one is what is compared. genA and
# genB are run on grammar/Scan.x, as alex327.nix runs it, so generated/Scan.hs
# is also comparable with ghc74.alex327's share/generated/Scan.hs.
#
# Parser.hs is made from Parser.y.boot by the chain's happy 1.19.5.
# alexchain/alex-3.2.7.4-mhs.patch is the one source change; alexchain/shims/
# has the containers and array functions alex 3 needs beyond common/shims'.
# MicroHs's evaluation stack (250,000 slots by default) is too small for
# alex 3's DFA construction; the runtime is compiled with STACK_SIZE raised.
# Output: bin/alex (alexB), share/alex-3.2.7.4/ (the templates),
# generated/Scan.hs (genB), step1/, genA/ and report.txt.
{ stdenv
, fetchurl
, mhs
, cpphs
, happy
, alex210ddc
}:
stdenv.mkDerivation {
  pname = "alex-chain";
  version = "3.2.7.4";
  src = fetchurl {   # the tarball of ghc74/alex327.nix
    url = "https://hackage.haskell.org/package/alex-3.2.7.4/alex-3.2.7.4.tar.gz";
    sha256 = "8a13fa01ea00883aa3d75d15ce848835b18631b8c9a4966961492d7c6095226f";
  };
  patches = [ ./alexchain/alex-3.2.7.4-mhs.patch ];
  nativeBuildInputs = [ mhs cpphs happy ];
  hardeningDisable = [ "all" ];
  buildPhase = ''
    runHook preBuild
    W=$PWD/work; mkdir -p $W/inc $W/shim $W/step1 $W/genA $W/genB $W/asrc/src
    link() {   # $1 = mhs C output, $2 = binary
      cc -w -O1 -fno-pie -no-pie -DSTACK_SIZE=100000000 \
         -I${mhs}/src/runtime -I${mhs}/src/runtime/unix \
         ${mhs}/src/runtime/main.c ${mhs}/src/runtime/eval.c "$1" -lm -o "$2"
    }
    build() {  # $1 = Scan.hs, $2 = binary
      rm -rf $W/src; cp -r src $W/src; cp $1 $W/src/Scan.hs
      (cd $W/src && mhs -XCPP -D__GLASGOW_HASKELL__=810 '-DMIN_VERSION_base(a,b,c)=1' \
         -I$W/inc -i$W/shim -i${./alexchain/shims} -i${../common/shims} -i. Main -o$2.c)
      link $2.c $2
    }
    touch $W/inc/ghcconfig.h
    cat > $W/shim/Paths_alex.hs <<EOF
    module Paths_alex (version, getDataDir) where
    import Data.Version
    version :: Version
    version = Version [3,2,7,4] []
    getDataDir :: IO FilePath
    getDataDir = return "$out/share/alex-3.2.7.4"
    EOF

    mkdir shipped grammar
    mv src/Parser.hs src/Scan.hs shipped/
    cp src/Parser.y.boot grammar/Parser.y
    cp src/Scan.x.boot grammar/Scan.x
    cp grammar/Scan.x $W/asrc/src/Scan.x
    happy grammar/Parser.y -o src/Parser.hs
    D=$PWD/data
    alex() {   # $1 = alex 3.2.7.4, then its arguments
      a=$1; shift; $a -t $D "$@"
    }

    echo "== step 1: alex 2.1.0 (alex210ddc) on 3.2.7.4's Scan.x =="
    ${alex210ddc}/bin/alex grammar/Scan.x -o $W/step1/Scan.hs

    echo "== alexA: alex 3.2.7.4 by mhs, with step 1's Scan.hs =="
    build $W/step1/Scan.hs $W/alexA
    alex $W/alexA -g grammar/Scan.x -o $W/genA/Scan.hs
    alex $W/alexA grammar/Scan.x -o $W/genA/Scan-plain.hs
    (cd $W/asrc && alex $W/alexA -g src/Scan.x -o $W/genA/Scan-as-src.hs)

    echo "== alexB: alex 3.2.7.4 by mhs, with alexA's plain Scan.hs =="
    build $W/genA/Scan-plain.hs $W/alexB
    alex $W/alexB -g grammar/Scan.x -o $W/genB/Scan.hs
    alex $W/alexB grammar/Scan.x -o $W/genB/Scan-plain.hs
    runHook postBuild
  '';
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    W=$PWD/work
    {
      echo "step1/Scan.hs: alex 2.1.0's, $(wc -l < $W/step1/Scan.hs) lines;" \
           "$(head -1 $W/step1/Scan.hs)"
      cmp $W/genA/Scan-as-src.hs shipped/Scan.hs
      echo "genA: run as src/Scan.x, identical to the tarball's src/Scan.hs ($(wc -l < shipped/Scan.hs) lines)"
      echo "genA: run as grammar/Scan.x, differs from it in $(diff shipped/Scan.hs $W/genA/Scan.hs | grep -c '^>') LINE pragmas"
      cmp $W/genA/Scan.hs $W/genB/Scan.hs
      cmp $W/genA/Scan-plain.hs $W/genB/Scan-plain.hs
      echo "genB: -g and plain Scan.hs identical to genA's"
      echo "alex 3.2.7.4 from the hand-written alex 2.1.0 scanner: its Scan.hs is the tarball's"
    } | tee report.txt
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 work/alexB $out/bin/alex
    mkdir -p $out/share/alex-3.2.7.4 $out/generated
    cp data/AlexTemplate.hs data/AlexWrappers.hs $out/share/alex-3.2.7.4/
    cp work/genB/Scan.hs $out/generated/
    cp -r work/step1 work/genA report.txt $out/
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = "$out/bin/alex --version | grep -q 'Alex version 3.2.7.4'";
}
