#!/bin/sh
# GHC 6.2.2's hsc2hs sources as mhs compiles them, from a configured 6.2.2 tree:
# the tarball's ghc/utils/hsc2hs with PATCH applied to Main.hs, and the
# Config.hs that its Makefile's $(CONFIG_HS) rule writes from mk/config.mk.
#   sh hsc2hs-src.sh TREE PATCH OUT     (OUT gets Main.hs Config.hs template-hsc.h hsc2hs.sh)
set -eu
T=${1:?usage: hsc2hs-src.sh TREE PATCH OUT}; PATCH=${2:?}; O=${3:?}
W=$(mktemp -d "${TMPDIR:-/tmp}/hsc2hs-src.XXXXXX")
# cp -a: fresh mtimes in copy order can leave configure older than aclocal.m4,
# and make would then try to rerun autoconf, which fails on this tree.
cp -a "$T/." "$W/"; chmod -R u+w "$W"
make -s -C "$W/ghc/utils/hsc2hs" Config.hs > /dev/null
(cd "$W/ghc/utils/hsc2hs" && patch -s -p1 < "$PATCH")
mkdir -p "$O"
for f in Main.hs Config.hs template-hsc.h hsc2hs.sh; do cp "$W/ghc/utils/hsc2hs/$f" "$O/$f"; done
rm -rf "$W"
