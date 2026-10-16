# happy 1.19.5 compiled by mhs, as one derivation (happy.nix), with the check
# on its seed reachable as an attribute.
#
#   nix-build -A happy         happy 1.19.5 by mhs; its seed is a fixed point (happy.nix)
#   nix-build -A happy.ddc115  the seed again, from happy 1.15's unrelated one:
#                              diverse double compilation (ddc115.nix); also
#                              happy.tests.ddc115, the nixpkgs passthru.tests idiom
#
# The check is its own derivation so that happy's, and with it every
# derivation of the chain after it, does not change.
{ lib, newScope }:

let
  parts = lib.makeScope newScope (self: {
    happy = self.callPackage ./happy.nix { };
    ddc115 = self.callPackage ./ddc115.nix { };
  });
in
parts.happy // { inherit (parts) ddc115; tests.ddc115 = parts.ddc115; }
