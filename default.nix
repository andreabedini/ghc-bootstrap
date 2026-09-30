# The bootstrap chain as Nix derivations, one per file in nix/.
#
#   nix-build -A hugs      Hugs 98 (Sep 2006), patched          (phase0/build-hugs.sh)
#   nix-build -A mhs       MicroHs, generation 1 run under Hugs (phase0/bootstrap-seed.sh)
#   nix-build -A cpphs     cpphs 1.20.9 from source, by mhs      (nix/cpphs.nix)
#   nix-build -A happy     happy 1.19.5 compiled by mhs         (build/fixpoint-happy.sh)
#   nix-build -A ghc622    GHC 6.2.2's tree, generated files regenerated (nix/ghc622.nix)
#   nix-build -A rts622    its runtime system, libHSrts.a           (build/rts622/build-rts.sh)
#   nix-build -A ghc622-stage1  its compiler proper, compiled by mhs  (build/ghc622-mhs/build.sh)
#   nix-build -A ghc622-base    libraries/base, compiled by stage 1   (build/Makefile base)
#   nix-build -A ghc622-stage2  the native compiler, by stage 1      (build/Makefile stage2, test)
#
# The packages live in their own scope (lib.makeScope): inside it, callPackage
# resolves hugs, mhs, cpphs and happy to these, not to nixpkgs' packages of the
# same names. Inputs are the tarballs and commits listed in SOURCES.md and the
# patches in this repository.
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
  ghc622 = self.callPackage ./nix/ghc622.nix { };
  rts622 = self.callPackage ./nix/rts622.nix { };
  ghc622-stage1 = self.callPackage ./nix/ghc622-stage1.nix { };
  ghc622-base = self.callPackage ./nix/ghc622-base.nix { };
  ghc622-stage2 = self.callPackage ./nix/ghc622-stage2.nix { };
})
