# The bootstrap chain as Nix derivations. One attribute per link, and one
# top-level directory per link holding its default.nix and every file it
# reads; a compiler that takes several steps exposes them as attributes of
# the finished compiler.
#
#   nix-build -A hugs      Hugs 98 (Sep 2006), patched            (hugs/build-hugs.sh)
#   nix-build -A mhs       MicroHs, generation 1 run under Hugs   (mhs/bootstrap-seed.sh)
#   nix-build -A cpphs     cpphs 1.20.9 from source, by mhs       (cpphs/default.nix)
#   nix-build -A happy     happy 1.19.5 compiled by mhs           (build/fixpoint-happy.sh)
#   nix-build -A ghc622    GHC 6.2.2, compiled by mhs, then by itself to a fixed point,
#                          installed (ghc622/: .tree .rts .stage1 .base .stage2 .stage3
#                          .stage4 .stage5 .fixpoint)
#   nix-build -A ghc66     GHC 6.6, configure and make with that 6.2.2
#                          (ghc66/: .happy116 .alex210)
#   nix-build -A ghc610    GHC 6.10.4, configure and make with that 6.6 (ghc610/)
#   nix-build -A ghc612    GHC 6.12.3, configure and make with that 6.10.4 (ghc612/)
#   nix-build -A ghc74     GHC 7.4.2, configure and make with that 6.12.3 (ghc74/: .happy1195 .alex327,
#                          the generators 7.8 on ask for: happy to 8.8, alex to 9.14)
#   nix-build -A ghc78     GHC 7.8.4, configure and make with that 7.4.2 (ghc78/)
#   nix-build -A ghc80     GHC 8.0.2, configure and make with that 7.8.4 (ghc80/)
#   nix-build -A ghc84     GHC 8.4.4, configure and make with that 8.0.2 (ghc84/)
#   nix-build -A ghc88     GHC 8.8.4, configure and make with that 8.4.4 (ghc88/: .happy11912, for 9.0)
#   nix-build -A ghc90     GHC 9.0.2, configure and make with that 8.8.4 (ghc90/)
#   nix-build -A ghc94     GHC 9.4.8, configure and make with that 9.0.2 (ghc94/: .happy120, for 9.4 on;
#                          9.4 keeps the make build system for a boot GHC < 9.1)
#   nix-build -A ghc98     GHC 9.8.4, Hadrian (bootstrapped by bootstrap.py from a plan
#                          with Nix-fetched sources, common/hadrian-ghc.nix) with that 9.4.8 (ghc98/)
#   nix-build -A ghc912    GHC 9.12.4, Hadrian with that 9.8.4 (ghc912/)
#   nix-build -A ghc914    GHC 9.14.1, Hadrian with that 9.12.4 (ghc914/; configure says
#                          a 9.6 would do, stage 0 needs 9.10's ghc-internal)
#                          Each rung is the newest release whose configure accepts the
#                          one before as the bootstrapping compiler.
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
  hugs = self.callPackage ./hugs { };
  mhs = self.callPackage ./mhs { };
  cpphs = self.callPackage ./cpphs { };
  happy = self.callPackage ./happy { };
  gmp612 = self.callPackage ./gmp612 { };
  ghc622 = self.callPackage ./ghc622 { };
  ghc66 = self.callPackage ./ghc66 { };
  ghc610 = self.callPackage ./ghc610 { };
  ghc612 = self.callPackage ./ghc612 { };
  ghc74 = self.callPackage ./ghc74 { };
  ghc78 = self.callPackage ./ghc78 { };
  ghc80 = self.callPackage ./ghc80 { };
  ghc84 = self.callPackage ./ghc84 { };
  ghc88 = self.callPackage ./ghc88 { };
  ghc90 = self.callPackage ./ghc90 { };
  ghc94 = self.callPackage ./ghc94 { };
  ghc98 = self.callPackage ./ghc98 { };
  ghc912 = self.callPackage ./ghc912 { };
  ghc914 = self.callPackage ./ghc914 { };
})
