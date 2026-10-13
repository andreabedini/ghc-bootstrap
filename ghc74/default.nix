# GHC 7.4.2 built by the chain's GHC 6.12.3, as one derivation: the installed
# compiler (ghc.nix), with the two generators the rungs after it need, and
# the mtl one of them needs, reachable as attributes.
#
#   nix-build -A ghc74            GHC 7.4.2, configure and make with 6.12.3 (ghc.nix)
#   nix-build -A ghc74.mtl        mtl 1.1.1.1 from 7.4.2's tarball, which builds but does not install it (mtl.nix)
#   nix-build -A ghc74.happy1195  happy 1.19.5, compiled by 7.4.2 with that mtl; fixed point (happy1195.nix)
#   nix-build -A ghc74.alex327    alex 3.2.7.4, compiled by 7.4.2; Scan.hs by fixed point (alex327.nix)
#
# 7.4.2 itself regenerates its parsers and lexers with 6.6's happy 1.16 and
# alex 2.1.0 (common/regen-parsers.sh). The releases after it ask for more:
# 7.8.4 for happy >= 1.19 and alex >= 3.1, 8.0.2 to 8.8.4 for happy >= 1.19.4
# and alex >= 3.1.0 (3.1.7 from 8.8), 9.0.2 for the same, 9.4.8 and later
# for alex >= 3.2.6. happy 1.19.5 is the newest happy 7.4.2's libraries can
# build (1.19.6 and later want an mtl with Control.Monad.Except; the mtl
# 1.1.1.1 of 7.4.2's tree, which its build keeps in-tree, is mtl.nix), and
# it is the happy that made 8.0.2's shipped parsers; it serves 7.8.4 to
# 8.8.4. alex 3.2.7.4 builds with 7.4.2 and serves every rung from 7.8.4 to
# 9.14.1 (alex327.nix says why no 3.1.x can).
{ lib
, newScope
, registerised ? true
, gdbModule ? null   # diagnostic, see ghc.nix
}:

let
  parts = lib.makeScope newScope (self: {
    mtl = self.callPackage ./mtl.nix { };
    happy1195 = self.callPackage ./happy1195.nix { };
    alex327 = self.callPackage ./alex327.nix { };
    ghc = self.callPackage ./ghc.nix { inherit registerised gdbModule; };
  });
in
parts.ghc // { inherit (parts) mtl happy1195 alex327; }
