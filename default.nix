# The bootstrap chain as Nix derivations, one per file in nix/.
#
#   nix-build -A hugs      Hugs 98 (Sep 2006), patched          (phase0/build-hugs.sh)
#   nix-build -A mhs       MicroHs, generation 1 run under Hugs (phase0/bootstrap-seed.sh)
#   nix-build -A cpphs     cpphs 1.20.9 from source, by mhs      (nix/cpphs.nix)
#   nix-build -A happy     happy 1.19.5 compiled by mhs         (build/fixpoint-happy.sh)
#   nix-build -A ghc622-tree  GHC 6.2.2's patched, configured tree (phase4/reproduce-6.2.2.sh)
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
  ghc622-tree = self.callPackage ./nix/ghc622-tree.nix { };
})
