#!/bin/sh
# ghc/compiler/main/Config.hs for the chain's GHC 6.2.2: what the compiler
# Makefile's $(CONFIG_HS) rule writes from a configured tree's mk/config.mk,
# with the settings in OVERRIDES (ghc622/gen/config-hs.mk) read last.
#   sh config-hs.sh TREE OVERRIDES OUT      (writes OUT/Config.hs)
set -eu
T=${1:?usage: config-hs.sh TREE OVERRIDES OUT}; M=${2:?}; O=${3:?}
W=$(mktemp -d "${TMPDIR:-/tmp}/config-hs.XXXXXX")
cp -r "$T/." "$W/"; chmod -R u+w "$W"
rm -f "$W/ghc/compiler/main/Config.hs"
make -s -C "$W/ghc/compiler" -f Makefile -f "$M" main/Config.hs > /dev/null
mkdir -p "$O"; cp "$W/ghc/compiler/main/Config.hs" "$O/Config.hs"
rm -rf "$W"
