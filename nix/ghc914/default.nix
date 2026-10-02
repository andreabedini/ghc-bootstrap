# GHC 9.14.1 built by the chain's GHC 9.12.4 (nix/ghc912) with Hadrian
# (nix/hadrian-ghc.nix). 9.14.1's configure.ac still says a 9.6 boot
# compiler will do (MinBootGhcVersion, the same as 9.12's), and with a
# 9.8.4 Hadrian bootstraps and configure passes, but the stage-0 build then
# fails configuring ghci: libraries/ghci/ghci.cabal.in wants `ghc-internal
# >= 9.1001.0` and `ghc-heap >= 9.10.1` from the boot compiler's packages
# (9.12 still built ghc-heap in stage 0 and did without ghc-internal; 9.14
# dropped ghcHeap from Hadrian's stage0Packages). ghc-internal exists from
# 9.10 on, so the real floor is 9.10, which is also what its bootstrap plans
# (9.10 and 9.12 boots only) say; 9.12.4 is the rung before it. The plan is
# the tarball's own plan-bootstrap-9_12_2.json, copied here verbatim; the
# derivation rewrites its boot-library versions to the 9.12.4's.
#
# Of the patches nixpkgs applies to 9.14.1 none is for x86-64 Linux with
# glibc (see nix/ghc912/default.nix).
{ callPackage, ghc912, ghc94 }:
(callPackage ../hadrian-ghc.nix { }) {
  version = "9.14.1";
  sha256 = "2a83779c9af86554a3289f2787a38d6aa83d00d136aa9f920361dd693c101e77";
  bootGhc = ghc912;
  happy = ghc94.happy120;
  alex = ghc94.alex327;
  plan = ./plan-bootstrap-9_12_2.json;
}
