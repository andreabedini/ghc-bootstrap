# GHC 9.8.4 built by the chain's GHC 9.4.8 (ghc94) with Hadrian
# (common/hadrian-ghc.nix). 9.8.4 asks for a 9.4 or later as the bootstrapping
# compiler; 9.6 is skipped. 9.8.4's newest bootstrap plan is for a 9.4.4 boot
# compiler (plan-bootstrap-9_4_4.json, copied here verbatim from the
# tarball's hadrian/bootstrap/); the derivation rewrites its boot-library
# versions to the chain's 9.4.8's (base 4.17.2.1 instead of 4.17.0.0, ...).
#
# gcc 15 defaults to C23, where `extern void *realloc();` declares a
# function of no arguments: utils/hp2ps/Utilities.c (K&R-era) fails to
# compile. Upstream's fix (GitLab !13863 for #25662, in 9.10 and later; the
# Fedora copy is the one nixpkgs applies to GHC < 9.10): include stdlib.h
# instead.
{ callPackage, ghc94, ghc74 }:
(callPackage ../common/hadrian-ghc.nix { }) {
  version = "9.8.4";
  sha256 = "17e8188f3c8a5c2f73fb4e35d01032e8dc258835ec876d52c8ad8ee3d24b2fc5";
  bootGhc = ghc94;
  happy = ghc94.happy120;
  alex = ghc74.alex327;
  plan = ./plan-bootstrap-9_4_4.json;
  patches = [ ./hp2ps-C-gnu17.patch ];
}
