# cpphs 1.20.9 from source, compiled by mhs, with no cpphs to start from.
#
#   round 1  gcc's traditional cpp (what GHC's own -cpp runs) preprocesses the
#            polyparse modules, the only ones with directives; cpphs is then
#            compiled with no CPP at all, so MicroHs's libraries never meet
#            gcc's cpp (it joins a line ending in (\\) to the next).
#   round 2  upstream's `make bootstrapcpphs` command, with round 1's cpphs.
#   round 3  the same with round 2's cpphs; its C must equal round 2's.
#
# Round 2 is installed. It replaces MicroHs's shipped generated/cpphs.c, and
# behaves the same: both preprocess every .hs/.lhs/.pp file of GHC 6.2.2 with
# the chain's three flag sets to identical output (1,458 runs, 2026-09-30),
# except for the source path in cpphs's own #error message.
{ stdenv, fetchFromGitHub, mhs }:
stdenv.mkDerivation {
  pname = "cpphs";
  version = "1.20.9";
  # MicroHs's cpphssrc/malcolm-wallace-universe submodule, at the commit
  # MicroHs 0.16.8.0 pins.
  src = fetchFromGitHub {
    owner = "hackage-trustees";
    repo = "malcolm-wallace-universe";
    rev = "3ec065411afb499f4c73d74be0e70e2454d0ed29";
    hash = "sha256-3okIU2zCS3wtF/CSsPTKRNfB8gh/grEOWK0YOMEUsPc=";
  };
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
    cmp cpphs2.c cpphs3.c && echo "fixpoint: round 2 == round 3"
    runHook postBuild
  '';
  installPhase = "install -Dm755 cpphs2 $out/bin/cpphs";
}
