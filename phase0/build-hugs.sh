#!/bin/sh
# Build Hugs 98 plus (Sep 2006) on a modern toolchain.
# Verified 2026-09-02 on Fedora 44, GCC 16.2.1, x86_64.
#
# Three fixes are needed versus a plain ./configure && make:
#
# 1. GCC >= 14 turns implicit-int / implicit-function-declaration /
#    int-conversion into hard errors. The 2006 autoconf probes are written in
#    K&R-ish C and all fail. -fpermissive downgrades them to warnings again.
#
# 2. The probe that detects how to build loadable libraries runs
#    `${CC} -shared conftest_dl.c ...` and does NOT interpolate $CFLAGS
#    (configure:15502, :15667). So the permissive flags must ride inside $CC,
#    not $CFLAGS, or every probe fails silently and Hugs is configured with no
#    shared-object flags at all -- which then shows up much later as
#    "undefined reference to `main'" when linking each FFI stub .so.
#
# 3. libraries/tools/make_bootlib configures packages/base itself, in a
#    subshell that only inherits the environment. CC/CFLAGS must therefore be
#    exported for `make` too, not just passed to ./configure -- otherwise the
#    base HTYPE_* probes fail and you get
#    "Undefined type constructor HTYPE_INT" in Foreign/Storable.hs.
set -eu

SRC=${1:-hugs98-plus-Sep2006}
PREFIX=${2:-$PWD/prefix}
PATCHES=$PWD/patches

PERMISSIVE_CC="gcc -std=gnu89 -fcommon -fpermissive -w"

cd "$SRC"

# Sandbox-only: make_bootlib hardcodes /tmp. Harmless elsewhere.
if [ -n "${TMPDIR:-}" ]; then
    sed -i 's|^tmpdir_root=/tmp$|tmpdir_root=${TMPDIR:-/tmp}|' libraries/tools/make_bootlib
fi

# Haskell 2010 pattern guards, which Hugs Sep2006 does not implement and which
# MicroHs (and any modern Haskell source) needs. Requires bison to regenerate
# parser.c; the Makefile does that automatically once parser.y is newer.
if ! grep -q mkGuard src/parser.y; then
    patch -p0 < "$PATCHES/0002-hugs-pattern-guards.patch"
fi

# MicroHs compiling itself needs far more control stack than the 160000 cells
# the "large" Hugs build allocates. cellStack is heap-allocated (TABALLOC), so
# this costs address space, not a static array.
if ! grep -q 40000000 src/prelude.h; then
    patch -p0 < "$PATCHES/0003-hugs-bigger-control-stack.patch"
fi

./configure --prefix="$PREFIX" CC="$PERMISSIVE_CC" CFLAGS="-O1"

CC="$PERMISSIVE_CC" CFLAGS="-O1" make
CC="$PERMISSIVE_CC" CFLAGS="-O1" make install

echo "Hugs installed to $PREFIX; add $PREFIX/bin to PATH."
