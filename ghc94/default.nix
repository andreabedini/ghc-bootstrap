# GHC 9.4.8 built by the chain's GHC 9.0.2, as one derivation: the installed
# compiler (ghc.nix), with the happy its build demands reachable as an
# attribute.
#
#   nix-build -A ghc94           GHC 9.4.8, configure and make with 9.0.2 (ghc.nix)
#   nix-build -A ghc94.happy120  happy 1.20.1.1, compiled by 9.0.2; seedless, fixed point (happy120.nix)
#
# 9.4's and 9.8's Cabal files declare build-tool-depends on alex >= 3.2.6 and
# happy >= 1.20.0 although the tarballs ship every generated parser and
# lexer; ghc-cabal and Hadrian refuse to configure without the programs.
# The alex is ghc74.alex327 (3.2.7.4, compiled by 7.4.2, which serves every
# rung from 7.8.4 on); happy 1.20, like 1.19.6, wants an mtl 7.4.2 has not,
# hence this scope.
{ lib
, newScope
}:

let
  parts = lib.makeScope newScope (self: {
    happy120 = self.callPackage ./happy120.nix { };
    ghc = self.callPackage ./ghc.nix { };
  });
in
parts.ghc // { inherit (parts) happy120; }
