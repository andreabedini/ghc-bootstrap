# MicroHs from Hugs. Generation 1 is MicroHs's compiler interpreted by Hugs,
# emitting C for itself (generated/hmhs.c -> bin/hmhs). Generation 2 is what
# hmhs emits for the same source, installed as bin/mhs; generation 3 is what
# bin/mhs emits, and the check phase requires it byte-identical. MicroHs's
# shipped generated/*.c are deleted first; mhs.c is kept aside, and the
# check phase also requires that bin/mhs, run as MicroHs's Makefile runs it
# (-z, the compressed form the release ships), reproduces it byte for byte:
# the shipped seed is exactly what the Hugs-derived compiler emits (D1).
# The output is the source tree with bin/ in it, so mhs runs "in place" (it
# finds lib/ and src/runtime/ next to bin/).
{ stdenv, fetchFromGitHub, hugs }:
stdenv.mkDerivation {
  pname = "mhs";
  version = "0.16.8.0";
  src = fetchFromGitHub {
    owner = "augustss";
    repo = "MicroHs";
    tag = "v0.16.8.0";
    hash = "sha256-SuZtxRL27EUnrqm5ly+3TexFoZPvuoqHvH+GHEWCkjQ=";
  };
  # The shipped seed goes before anything else runs; nothing below may use it.
  postUnpack = ''
    mkdir -p $NIX_BUILD_TOP/shipped
    mv "$sourceRoot"/generated/mhs.c $NIX_BUILD_TOP/shipped/
    rm -f "$sourceRoot"/generated/*.c
  '';
  patches = [ ./patches/0001-microhs-hugs-shim.patch ];
  nativeBuildInputs = [ hugs ];
  hardeningDisable = [ "all" ];
  # Hugs decodes source text with the locale; the sources have non-ASCII.
  env.LANG = "C.UTF-8";
  buildPhase = ''
    runHook preBuild
    make mhs.conf
    # MAX_EVAL_DEPTH guards C recursion in eval(); give it a matching stack.
    ulimit -s unlimited 2>/dev/null || ulimit -s 4000000
    make generated/hmhs.c bin/hmhs
    MHSDIR=$PWD bin/hmhs -i -imhs -isrc -ilib MicroHs.Main -ogenerated/mhs.c
    cc -w -O1 -Isrc/runtime -Isrc/runtime/unix \
       src/runtime/main.c src/runtime/eval.c generated/mhs.c -lm -o bin/mhs
    MHSDIR=$PWD bin/mhs -i -imhs -isrc -ilib MicroHs.Main -ogen3.c
    runHook postBuild
  '';
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    cmp generated/mhs.c gen3.c && echo "fixpoint: generation 2 == generation 3"
    MHSDIR=$PWD bin/mhs -z -i -imhs -isrc -ilib MicroHs.Main -ogen2z.c
    cmp gen2z.c $NIX_BUILD_TOP/shipped/mhs.c && echo "generation 2 with -z == MicroHs's shipped generated/mhs.c"
    rm gen2z.c
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    rm -f gen3.c
    cp -r . $out
    runHook postInstall
  '';
}
