#!/bin/sh
# The order in which libraries/base is compiled (ghc622/nix/base.nix,
# build/Makefile): base-order.py's dependency order of the modules that need
# no hsc2hs, less those in AFTER, then AFTER as written -- the four modules
# hsc2hs generates and the three that import them, compiled once hsc2hs has run.
#   sh base-rebuild-order.sh BASE INCLUDES AFTER > base-rebuild-order.txt
set -eu
B=${1:?usage: base-rebuild-order.sh BASE INCLUDES AFTER}; I=${2:?}; A=${3:?}
python3 "$(dirname "$0")/base-order.py" "$B" "$I" | grep -vxF -f "$A"
cat "$A"
