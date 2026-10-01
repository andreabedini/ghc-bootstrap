# GHC 6.6 built by the chain's GHC 6.2.2, as one derivation: the installed
# compiler (ghc.nix), with the two generators it needs reachable as attributes.
#
#   nix-build -A ghc66           GHC 6.6, configure and make with 6.2.2 (ghc.nix)
#   nix-build -A ghc66.happy116  happy 1.16, compiled by 6.2.2; seedless, fixed point (happy116.nix)
#   nix-build -A ghc66.alex210   alex 2.1.0, compiled by 6.2.2; Scan.hs by fixed point (alex210.nix)
#
# happy 1.16 and alex 2.1.0 are the versions that made the parsers and lexers
# the 6.6 tarball ships; ghc.nix deletes those and lets 6.6's own Makefile
# rules regenerate them, then checks the result against the shipped files.
# cpp-template.sh, cmp-generated.sh and shims622/ are theirs.
{ lib
, newScope
}:

let
  parts = lib.makeScope newScope (self: {
    happy116 = self.callPackage ./happy116.nix { };
    alex210 = self.callPackage ./alex210.nix { };
    ghc = self.callPackage ./ghc.nix { };
  });
in
parts.ghc // { inherit (parts) happy116 alex210; }
