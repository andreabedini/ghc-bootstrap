#!/bin/sh
# Stage 2's fixups: for each PATCHES/<path>.patch, OUT/<path> is SRC/<path>
# (the compiler source, ghc/compiler of the patched tree) with that patch
# applied. The stage-1 compiler compiles OUT/<path> in place of SRC/<path>.
#   sh make-fixups.sh SRC PATCHES OUT
set -eu
S=${1:?usage: make-fixups.sh SRC PATCHES OUT}; P=${2:?}; O=${3:?}
(cd "$P" && find . -name '*.patch' | sort) | while read -r p; do
  f=${p#./}; f=${f%.patch}
  mkdir -p "$O/$(dirname "$f")"
  cp "$S/$f" "$O/$f"; chmod u+w "$O/$f"
  patch -s "$O/$f" < "$P/$p"
done
