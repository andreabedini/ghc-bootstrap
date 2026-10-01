# GHC 6.2.2 built by the chain, as one derivation: the installed compiler
# (inst.nix), with the stages that lead to it reachable as attributes.
#
#   nix-build -A ghc622           stage 3 as an installed 6.2.2 (inst.nix)
#   nix-build -A ghc622.tree      the source tree with its generated files regenerated (tree.nix)
#   nix-build -A ghc622.rts       the runtime system, libHSrts.a, compiled without a GHC (rts.nix)
#   nix-build -A ghc622.stage1    the compiler proper compiled by mhs (stage1.nix)
#   nix-build -A ghc622.base      libraries/base, compiled by stage 1 (base.nix)
#   nix-build -A ghc622.stage2    the native compiler, compiled by stage 1 (stage2.nix)
#   nix-build -A ghc622.stage3    the compiler again, compiled by stage 2 (native.nix)
#   nix-build -A ghc622.stage4    and by stage 3
#   nix-build -A ghc622.stage5    its .hi/.hc by stage 4, not linked
#   nix-build -A ghc622.fixpoint  stage 5's .hc = stage 4's, module by module (fixpoint.nix)
#
# Why this many steps where GHC 6.6 (nix/ghc66) is one configure-and-make:
# 6.2.2's own build system needs a working GHC to drive it, and the chain has
# none yet. Stage 1 is GHC's source run on the MicroHs runtime, about twenty
# times slower than a native compile, and it dies on some modules at -O
# (retried with -fno-strictness, then -O0: build/mk/compile-stage2.sh), so the
# 220 modules of stage 2 are compiled one by one, in chunks a derivation can
# finish. The RTS and base are compiled by hand for the same reason: the
# Makefiles that build them call the compiler being built. From stage 3 on
# the compiler is native and the steps are kept only to show the fixed point.
#
# The stages are a scope of their own (lib.makeScope): inside it, tree, rts,
# stage1 ... resolve to these; mhs, cpphs and happy to the outer scope's.
{ lib
, newScope
}:

let
  stages = lib.makeScope newScope (self: {
    tree = self.callPackage ./tree.nix { };
    rts = self.callPackage ./rts.nix { };
    stage1 = self.callPackage ./stage1.nix { };
    base = self.callPackage ./base.nix { };
    stage2 = self.callPackage ./stage2.nix { };
    stage3 = self.callPackage ./native.nix { stage = 3; compiler = self.stage2; };
    stage4 = self.callPackage ./native.nix { stage = 4; compiler = self.stage3; };
    stage5 = self.callPackage ./native.nix { stage = 5; compiler = self.stage4; link = false; };
    fixpoint = self.callPackage ./fixpoint.nix { };
    inst = self.callPackage ./inst.nix { };
  });
in
stages.inst // {
  inherit (stages) tree rts stage1 base stage2 stage3 stage4 stage5 fixpoint;
}
