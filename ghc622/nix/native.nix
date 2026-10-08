# Stages 3-5: GHC 6.2.2's compiler proper compiled from the pristine source
# by a native GHC 6.2.2 (build/Makefile's stage3/test3, stage4 and stage5).
#
#   stage 3  by stage 2 (compiled by stage 1, the mhs-built compiler)
#   stage 4  by stage 3
#   stage 5  by stage 4, .hi/.hc only: the fixed-point check compares them
#            with stage 4's (ghc622/nix/fixpoint.nix)
#
# The compile and link are stage 2's (ghc622/nix/stage2.nix hcChunk and
# linked) with STAGE3_ENV's settings: no fixups (they only stand in for what
# the MicroHs runtime cannot read), no flags.tsv seed (it records stage 1's
# needs), a 30-minute timeout. The topdir is stage 2's: base and haskell98
# stay the ones stage 1 compiled, as in the Makefile. A native compile is
# about 20 times faster than stage 1's, so one derivation holds all 220.
{ stage2
, compiler
, stage
, link ? true
}:

let
  name = "stage${toString stage}";
  hc = stage2.hcChunk {
    part = "";
    from = 1;
    to = 220;
    stage = name;
    ghc = "${compiler}/bin/ghc";
    fixups = false;
    flags = "/dev/null";
    modTimeout = 1800;
  };
in
if link then stage2.linked { stage = name; inherit hc; ref = compiler; } else hc
