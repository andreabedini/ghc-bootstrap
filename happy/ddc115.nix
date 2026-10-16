# Diverse double compilation for happy's parsers (build/ddc-happy115.sh).
# happy-seed/ is a fixed point of a seed a GHC-built happy wrote; this starts
# again from an unrelated one, the Parser.hs that happy 1.14 wrote and that
# happy's repository commits at the Happy_1_15 tag:
#
#   happy 1.15  compiled by mhs from that Parser.hs (ddc115/: the source part
#               of the patch posted on issue #2, and Paths_happy)
#   genA        happy 1.15 generates happy 1.19.5's two parsers
#   happyA      happy 1.19.5 compiled by mhs from genA
#   genB        happyA regenerates them
#
# and the check phase fails unless genB is happy-seed/ byte for byte. genA is
# not compared with anything: 1.15 writes different code from 1.19.5.
# Output: genA/, genB/ and report.txt.
{ stdenv, fetchFromGitHub, mhs, cpphs, happy }:
stdenv.mkDerivation {
  pname = "happy-ddc115";
  version = "1.15";
  src = fetchFromGitHub {
    owner = "haskell";
    repo = "happy";
    rev = "refs/tags/Happy_1_15";
    hash = "sha256-aWxvW8opd7bJAaj/3huQqB+hH/S+LRwbq+qWpOrK5Us=";
  };
  patches = [ ./ddc115/happy-1.15-mhs.patch ];
  nativeBuildInputs = [ mhs cpphs ];
  hardeningDisable = [ "all" ];
  buildPhase = ''
    runHook preBuild
    link() {   # $1 = mhs C output, $2 = binary
      cc -w -O1 -I${mhs}/src/runtime -I${mhs}/src/runtime/unix \
         ${mhs}/src/runtime/main.c ${mhs}/src/runtime/eval.c "$1" -lm -o "$2"
    }
    W=$PWD/work; mkdir -p $W/h115/data/templates $W/h1195/data $W/genA $W/genB

    echo "== happy 1.15 by mhs =="
    head -6 src/Parser.hs | grep 'produced by Happy Version 1.14'
    cpphs --noline templates/GenericTemplate.hs > $W/h115/data/templates/HappyTemplate
    mhs -XCPP -i${./ddc115} -i${../common/shims} -isrc Main -o$W/h115/happy.c
    link $W/h115/happy.c $W/h115/happy

    echo "== genA: happy 1.15 generates happy 1.19.5's parsers =="
    tar xzf ${happy.src} -C $W
    S=$W/happy-1.19.5/src
    for p in Parser AttrGrammarParser; do
      (cd $S && HAPPY_DATADIR=$W/h115/data $W/h115/happy $p.ly -o $W/genA/$p.hs)
    done

    echo "== happyA: happy 1.19.5 by mhs from genA =="
    cpphs --noline $W/happy-1.19.5/templates/GenericTemplate.hs > $W/h1195/data/HappyTemplate
    cp $W/genA/*.hs $S/
    mhs -XCPP -i${./noglr} -i${../common/shims} -i${./shim} -i$S Main -o$W/h1195/happy.c
    link $W/h1195/happy.c $W/h1195/happy

    echo "== genB: happyA regenerates them =="
    for p in Parser AttrGrammarParser; do
      (cd $S && HAPPY_DATADIR=$W/h1195/data $W/h1195/happy $p.ly -o $W/genB/$p.hs)
    done
    runHook postBuild
  '';
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    {
      for p in Parser AttrGrammarParser; do
        echo "genA $p.hs: $(head -12 work/genA/$p.hs | grep 'produced by')," \
             "$(diff ${./happy-seed}/$p.hs work/genA/$p.hs | grep -c '^[<>]') lines differ from happy-seed"
      done
      for p in Parser AttrGrammarParser; do
        cmp work/genB/$p.hs ${./happy-seed}/$p.hs
        echo "genB $p.hs: identical to happy-seed ($(wc -l < work/genB/$p.hs) lines)"
      done
      echo "diverse double compilation: two unrelated seeds give the same parsers"
    } | tee report.txt
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r work/genA work/genB report.txt $out/
    runHook postInstall
  '';
}
