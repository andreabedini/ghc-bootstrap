# GHC 6.2.2's genprimopcode compiled by mhs, with one edit
# (phase4/genprimopcode-Main.hs.patch) and the Parsec slice shim: cpphs
# leaves __GLASGOW_HASKELL__ undefined, so Main.hs imports Parsec.
{ runCommandCC, mhs, cpphs, ghc622-src }:
runCommandCC "ghc-6.2.2-genprimopcode"
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
  ''
