# GHC 9.14.1 built by the chain's GHC 9.8.4 (nix/ghc98) with Hadrian
# (nix/hadrian-ghc.nix). 9.14.1's configure.ac asks for a 9.6 or later as the
# bootstrapping compiler, the same floor as 9.12's, so 9.10 and 9.12 are
# skipped. Its own hadrian/bootstrap/ only carries plans for 9.10 and 9.12
# boot compilers, whose builtin lists name os-string, a package a 9.8 has
# not got; the plan used is 9.12.4's plan-bootstrap-9_8_4.json
# (nix/ghc912/), the same dependency versions (Cabal 3.14.1.1, shake 0.19.8,
# directory 1.3.9.0, ...) with os-string, file-io and directory from Hackage,
# all within 9.14.1's hadrian.cabal bounds. ghc-platform and ghc-toolchain
# are "local" dependencies that bootstrap.py takes from the 9.14.1 tree.
#
# Of the patches nixpkgs applies to 9.14.1 none is for x86-64 Linux with
# glibc (see nix/ghc912/default.nix).
{ callPackage, ghc98, ghc94 }:
(callPackage ../hadrian-ghc.nix { }) {
  version = "9.14.1";
  sha256 = "2a83779c9af86554a3289f2787a38d6aa83d00d136aa9f920361dd693c101e77";
  bootGhc = ghc98;
  happy = ghc94.happy120;
  alex = ghc94.alex327;
  plan = ../ghc912/plan-bootstrap-9_8_4.json;
}
