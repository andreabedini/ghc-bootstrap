# cpphs 1.20.9 from source, compiled by mhs, with no cpphs to start from.
#
#   round 1  gcc's traditional cpp (what GHC's own -cpp runs) preprocesses the
#            polyparse modules, the only ones with directives; cpphs is then
#            compiled with no CPP at all, so MicroHs's libraries never meet
#            gcc's cpp (it joins a line ending in (\\) to the next).
#   round 2  upstream's `make bootstrapcpphs` command, with round 1's cpphs.
#   round 3  the same with round 2's cpphs; the check phase requires its C
#            equal to round 2's.
#
# Round 2 is installed. It replaces MicroHs's shipped generated/cpphs.c, and
# behaves the same: both preprocess every .hs/.lhs/.pp file of GHC 6.2.2 with
# the chain's three flag sets to identical output (1,458 runs, 2026-09-30),
# except for the source path in cpphs's own #error message.
{ stdenv, fetchurl, mhs }:
stdenv.mkDerivation {
  pname = "cpphs";
  version = "1.20.9";
  # The Hackage releases of cpphs and of polyparse, the parser library it
  # needs, with the edits MicroHs's cpphs submodule makes to their sources
  # (hackage-trustees/malcolm-wallace-universe 3ec065411afb), as patches.
  srcs = [
    (fetchurl {
      url = "https://hackage.haskell.org/package/cpphs-1.20.9/cpphs-1.20.9.tar.gz";
      sha256 = "978df2ae7143f2ddf9b1354370373ed104357845401b50001dca1c1cd30c0b1f";
    })
    (fetchurl {
      url = "https://hackage.haskell.org/package/polyparse-1.12/polyparse-1.12.tar.gz";
      sha256 = "f54c63584ace968381de4a06bd7328b6adc3e1a74fd336e18449e0dd7650be15";
    })
  ];
  sourceRoot = ".";
  patches = [ ./cpphs-1.20.9-mhs.patch ./polyparse-1.12-mhs.patch ];
  nativeBuildInputs = [ mhs ];
  hardeningDisable = [ "all" ];
  buildPhase = ''
    runHook preBuild
    minver='-DMIN_VERSION_base(x,y,z)=((x)<4||(x)==4&&(y)<19||(x)==4&&(y)==19&&(z)<=1)'
    link() {
      cc -w -O1 -I${mhs}/src/runtime -I${mhs}/src/runtime/unix \
         ${mhs}/src/runtime/main.c ${mhs}/src/runtime/eval.c $1.c -lm -o $1
    }

    cp -r polyparse-1.12/src pp
    if grep -rn '\\$' pp; then echo "trailing backslash: gcc's cpp would join lines"; exit 1; fi
    for f in $(grep -rl '^#' pp); do
      gcc -E -P -traditional -undef -x c "$minver" $f -o $f.cpp && mv $f.cpp $f
    done
    mhs -z -i${mhs}/cpphscompat -ipp -icpphs-1.20.9 cpphs-1.20.9/cpphs.hs -ocpphs1.c
    link cpphs1

    for r in 1 2; do
      MHSCPPHS=$PWD/cpphs$r mhs -z -XCPP "$minver" -i${mhs}/cpphscompat \
        -ipolyparse-1.12/src -icpphs-1.20.9 cpphs-1.20.9/cpphs.hs -ocpphs$((r+1)).c
      link cpphs$((r+1))
    done
    runHook postBuild
  '';
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    cmp cpphs2.c cpphs3.c && echo "fixpoint: round 2 == round 3"
    runHook postCheck
  '';
  installPhase = "install -Dm755 cpphs2 $out/bin/cpphs";
}
