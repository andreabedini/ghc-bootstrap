# GHC 9.12.4 built by the chain's GHC 9.8.4 (nix/ghc98) with Hadrian
# (nix/hadrian-ghc.nix). 9.12.4 asks for a 9.6 or later as the bootstrapping
# compiler. Its hadrian/bootstrap/ has a plan for exactly a 9.8.4 boot
# compiler, plan-bootstrap-9_8_4.json, copied here verbatim. 9.14.1's
# configure accepts a 9.6 too, but its stage-0 ghci needs the boot
# compiler's ghc-internal, which exists from 9.10 on (nix/ghc914), so this
# is the rung between 9.8.4 and 9.14.1.
#
# Of the patches nixpkgs applies to 9.12.4 none is for x86-64 Linux with
# glibc: include-modern-utimbuf is Windows-only, the adjustor stack overrun
# is i386, ELF64_ST_VISIBILITY is in glibc 2.42's elf.h, the rest are
# PowerPC, docs or JavaScript.
{ callPackage, ghc98, ghc94 }:
(callPackage ../hadrian-ghc.nix { }) {
  version = "9.12.4";
  sha256 = "02d1ee5080acf00e135b93b238f09015b06ff27254cde59669cf57c42c2bee43";
  bootGhc = ghc98;
  happy = ghc94.happy120;
  alex = ghc94.alex327;
  plan = ./plan-bootstrap-9_8_4.json;
}
