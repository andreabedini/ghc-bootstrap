# The bootstrap chain as Nix derivations. One attribute per link; a compiler
# that takes several steps is a directory under nix/ with a default.nix that
# exposes the steps as attributes of the finished compiler.
#
#   nix-build -A hugs      Hugs 98 (Sep 2006), patched            (phase0/build-hugs.sh)
#   nix-build -A mhs       MicroHs, generation 1 run under Hugs   (phase0/bootstrap-seed.sh)
#   nix-build -A cpphs     cpphs 1.20.9 from source, by mhs       (nix/cpphs.nix)
#   nix-build -A happy     happy 1.19.5 compiled by mhs           (build/fixpoint-happy.sh)
#   nix-build -A ghc622    GHC 6.2.2, compiled by mhs, then by itself to a fixed point,
#                          installed (nix/ghc622/: .tree .rts .stage1 .base .stage2 .stage3
#                          .stage4 .stage5 .fixpoint)
#   nix-build -A ghc66     GHC 6.6, configure and make with that 6.2.2
#                          (nix/ghc66/: .happy116 .alex210)
#   nix-build -A ghc610    GHC 6.10.4, configure and make with that 6.6 (nix/ghc610/)
#   nix-build -A ghc612    GHC 6.12.3, configure and make with that 6.10.4 (nix/ghc612/)
#   nix-build -A ghc74     GHC 7.4.2, configure and make with that 6.12.3 (nix/ghc74/)
#   nix-build -A ghc78     GHC 7.8.4, configure and make with that 7.4.2 (nix/ghc78/)
#   nix-build -A ghc80     GHC 8.0.2, configure and make with that 7.8.4 (nix/ghc80/)
#   nix-build -A ghc84     GHC 8.4.4, configure and make with that 8.0.2 (nix/ghc84/)
#   nix-build -A ghc88     GHC 8.8.4, configure and make with that 8.4.4 (nix/ghc88/)
#   nix-build -A ghc90     GHC 9.0.2, configure and make with that 8.8.4 (nix/ghc90/)
#   nix-build -A ghc94     GHC 9.4.8, configure and make with that 9.0.2 (nix/ghc94/;
#                          9.4 keeps the make build system for a boot GHC < 9.1)
#   nix-build -A ghc98     GHC 9.8.4, Hadrian (bootstrapped by bootstrap.py from a plan
#                          with Nix-fetched sources) with that 9.4.8 (nix/ghc98/)
#                          Each rung is the newest release whose configure accepts the
#                          one before as the bootstrapping compiler. Drafts until built.
#
# The packages live in their own scope (lib.makeScope): inside it, callPackage
# resolves hugs, mhs, cpphs, happy and ghc622 to these, not to nixpkgs'
# packages of the same names. Inputs are the tarballs and commits listed in
# SOURCES.md and the patches in this repository.
{
  pkgs ? import (builtins.fetchTarball {
    # nixos-26.05, 2026-09-30
    url = "https://github.com/NixOS/nixpkgs/archive/7fc6f2c20af09cdcaf48b92ec3121860139ec668.tar.gz";
    sha256 = "0g2rpvgr8kv1c7m6ql8is57fkh92hsjmiac0rvjyw2lfijhazp3c";
  }) { config = { }; overlays = [ ]; },
}:
pkgs.lib.makeScope pkgs.newScope (self: {
  hugs = self.callPackage ./nix/hugs.nix { };
  mhs = self.callPackage ./nix/mhs.nix { };
  cpphs = self.callPackage ./nix/cpphs.nix { };
  happy = self.callPackage ./nix/happy.nix { };
  gmp612 = self.callPackage ./nix/gmp612.nix { };
  ghc622 = self.callPackage ./nix/ghc622 { };
  ghc66 = self.callPackage ./nix/ghc66 { };
  ghc610 = self.callPackage ./nix/ghc610 { };
  ghc612 = self.callPackage ./nix/ghc612 { };
  ghc74 = self.callPackage ./nix/ghc74 { };
  ghc78 = self.callPackage ./nix/ghc78 { };
  ghc80 = self.callPackage ./nix/ghc80 { };
  ghc84 = self.callPackage ./nix/ghc84 { };
  ghc88 = self.callPackage ./nix/ghc88 { };
  ghc90 = self.callPackage ./nix/ghc90 { };
  ghc94 = self.callPackage ./nix/ghc94 { };
  ghc98 = self.callPackage ./nix/ghc98 { };
})
