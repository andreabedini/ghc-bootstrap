# Stage 1: GHC 6.2.2's compiler proper compiled by mhs (build/ghc622-mhs/
# build.sh comb, c, cc). mhs compiles Main to a combinator file with the five
# defines the perl driver passes to cpp and the ghc-on-mhs shims first on the
# path; comb2c.py writes it as the C array `mhs -o ghc.c` would; gcc links it
# with the MicroHs runtime, ffi.c (the four foreign imports the runtime's own
# table lacks) and stubs.c. No -C cache: this is the cold compile.
# Output: bin/ghc, and share/ghc.comb for comparison with build/ghc622-mhs.
{ stdenv
, python3
, mhs
, cpphs
, tree
}:

let
  W = ../../build/ghc622-mhs;
in
stdenv.mkDerivation {
  pname = "ghc-6.2.2-stage1";
  version = "6.2.2";
  dontUnpack = true;
  nativeBuildInputs = [ python3 mhs cpphs ];
  hardeningDisable = [ "all" ];
  dontStrip = true;

  buildPhase = ''
    runHook preBuild
    TREE=${tree}/ghc/compiler
    # __GLASGOW_HASKELL__=408: see build/probe-ordered-622.sh.
    hscpp="-D__HASKELL__=98 -D__HASKELL1__=5 -D__GLASGOW_HASKELL__=408 -D__HASKELL98__ -D__CONCURRENT_HASKELL__"
    inc="-i${../../phase2/hsboot-6.2.2-run1} -i${../../build/shims-6.2.2-run1} -i${../../phase1/shims}
         -i${../../phase1/shims-ghc} -i${../../phase1/shims-h98} -i${../../phase2/gen-6.2.2}"
    for d in $TREE/*/; do inc="$inc -i''${d%/}"; done
    inc="$inc -i$TREE -I$TREE -I${tree}/ghc/includes"

    ulimit -s unlimited 2>/dev/null || ulimit -s 4000000
    echo "stack: $(ulimit -s)"
    mhs +RTS -K32M -RTS -XCPP $hscpp -DOMIT_NATIVE_CODEGEN $inc Main -oghc.comb
    python3 ${W}/comb2c.py ghc.comb ghc-data.c

    # The MicroHs runtime with WANT_OVERFLOW 0: GHC's Haskell is written
    # against wrap-around Int (build.sh explains CoreUtils.hashExpr).
    mkdir rtconf
    sed 's/^#define WANT_OVERFLOW 1/#define WANT_OVERFLOW 0/' \
        ${mhs}/src/runtime/unix/config.h > rtconf/config.h
    grep -q '^#define WANT_OVERFLOW 0' rtconf/config.h
    # Non-PIE, as the chain was built and verified.
    gcc -w -O3 -fno-pie -no-pie -Irtconf -I${mhs}/src/runtime -I${mhs}/src/runtime/unix \
        -D__MHS__ -include ${W}/stubs.h \
        ${mhs}/src/runtime/main.c ${mhs}/src/runtime/eval.c ${W}/stubs.c \
        ghc-data.c ${W}/ffi.c -lm -o ghc
    runHook postBuild
  '';

  installPhase = ''
    install -Dm755 ghc $out/bin/ghc
    install -Dm644 ghc.comb $out/share/ghc.comb
  '';
}
