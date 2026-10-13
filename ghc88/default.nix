# GHC 8.8.4 built by the chain's GHC 8.4.4, as one derivation: the installed
# compiler (ghc.nix), with the generator the next rung needs reachable as an
# attribute.
#
#   nix-build -A ghc88             GHC 8.8.4, configure and make with 8.4.4 (ghc.nix)
#   nix-build -A ghc88.happy11912  happy 1.19.12, compiled by 8.8.4; fixed point (happy11912.nix)
#
# 8.8.4 itself regenerates its parsers and lexers with 7.4.2's happy 1.19.5
# and alex 3.2.7.4 (common/regen-parsers.sh). 9.0.2 asks for a happy >= 1.19.10
# and < 1.20, which no earlier rung can build (1.19.6 on want mtl >= 2.2.1;
# 8.8.4 has 2.2.2); 1.19.12 is also the happy that made the parsers 8.8.4 and
# 9.0.2 ship, so 9.0.2's regeneration is compared strictly.
{ lib
, newScope
, registerised ? true
}:

let
  parts = lib.makeScope newScope (self: {
    happy11912 = self.callPackage ./happy11912.nix { };
    ghc = self.callPackage ./ghc.nix { inherit registerised; };
  });
in
parts.ghc // { inherit (parts) happy11912; }
