# GHC 6.6 built by the chain's GHC 6.2.2, as one derivation: the installed
# compiler (ghc.nix), with the two generators it needs reachable as attributes.
#
#   nix-build -A ghc66           GHC 6.6, configure and make with 6.2.2 (ghc.nix)
#   nix-build -A ghc66.happy116  happy 1.16, compiled by 6.2.2; seedless, fixed point (happy116.nix)
#   nix-build -A ghc66.alex210   alex 2.1.0, compiled by 6.2.2; Scan.hs by fixed point (alex210.nix)
#   nix-build -A ghc66.alex210ddc  that Scan.hs again, from a hand-written scanner, by mhs:
#                                diverse double compilation (alex210ddc.nix)
#   nix-build -A ghc66.alexChain   alex 3.2.7.4 by mhs, its Scan.hs made by that alex 2.1.0:
#                                the tarball's again, byte for byte (alexchain.nix)
#   nix-build -A ghc66.alexChainLexers  that alex against ghc74.alex327 on GHC 7.8.4's and
#                                9.14.1's lexers (alexchain-lexers.nix; needs the chain to 7.4.2)
#
# happy 1.16 and alex 2.1.0 are the versions that made the parsers and lexers
# the 6.6 tarball ships; ghc.nix deletes those and lets 6.6's own Makefile
# rules regenerate them, then checks the result against the shipped files.
# cpp-template.sh, cmp-generated.sh and shims622/ are theirs.
{ lib
, newScope
, gdbModule ? null   # diagnostic, see ghc.nix
}:

let
  parts = lib.makeScope newScope (self: {
    happy116 = self.callPackage ./happy116.nix { };
    alex210 = self.callPackage ./alex210.nix { };
    alex210ddc = self.callPackage ./alex210ddc.nix { ghc66src = self.ghc.src; };
    alexChain = self.callPackage ./alexchain.nix { };
    alexChainLexers = self.callPackage ./alexchain-lexers.nix { };
    ghc = self.callPackage ./ghc.nix { inherit gdbModule; };
  });
in
parts.ghc // { inherit (parts) happy116 alex210 alex210ddc alexChain alexChainLexers; }
