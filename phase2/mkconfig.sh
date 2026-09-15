#!/bin/sh
# Generate ghc/includes/config.h exactly as GHC's own build does.
#
# Two steps, both GHC's:
#   1. ./configure produces mk/config.h from mk/config.h.in (177 autoconf
#      probes: word sizes, endianness, HAVE_* for the cbits headers, ...).
#   2. ghc/includes/Makefile prepends the platform CPP defines taken from
#      mk/config.mk and appends mk/config.h verbatim.
#
# This replaces a 49-line config.h I had written by hand, which covered only
# what the RTS headers needed. That was not enough: cbits/timezone.h needs
# HAVE_TM_ZONE, and it had LEADING_UNDERSCORE defined as 0 -- but MachMisc.lhs
# tests it with #ifdef, where "defined as 0" reads as true.
#
# Running configure needs three accommodations, all recorded in DECISIONS.md:
#   - config.sub and configure predate x86-64 (patches 0023, 0024)
#   - autoconf 2.13 probes use pre-C99 "main(){}", so the probes are compiled
#     as gnu89
#   - configure's happy version test compares versions as strings, so the
#     result is pre-seeded into the cache
set -eu
R=/home/andrea/work/haskell/ghc-bootstrap
G="$R/build/ghc-4.08.2"
HAPPY="$R/build/happy-mhs/happy-mhs"

bin=$(mktemp -d)
trap 'rm -rf "$bin"' EXIT
ln -sf "$HAPPY" "$bin/happy"

cd "$G"
cat > config.cache <<'CACHE'
# GHC's configure does: expr "$fptools_cv_happy_version" "<" 1.6
# That is a string comparison, so "1.19.5" < "1.6" (because '1' < '6' at the
# third character) and any happy with a two-digit minor version is rejected.
# happy was 1.8 in 2000, so the bug could not fire then. Seeding the cache
# variable makes configure skip the branch containing the broken test. The
# probed value is correct; only the comparison is wrong.
fptools_cv_happy_version=${fptools_cv_happy_version='1.19.5'}
CACHE

PATH="$bin:$PATH" \
CFLAGS='-std=gnu89 -Wno-implicit-function-declaration -Wno-implicit-int -Wno-int-conversion -Wno-return-mismatch' \
  ./configure --cache-file="$G/config.cache" \
              --host=x86_64-unknown-linux \
              --build=x86_64-unknown-linux \
              --target=x86_64-unknown-linux > "$G/configure.log" 2>&1

# Step 2: ghc/includes/Makefile's $(H_CONFIG) rule, transcribed.
cpp=$(sed -n 's/^HostPlatform_CPP[ \t]*=[ \t]*//p' mk/config.mk | tr -d ' \t')
arch=$(sed -n 's/^HostArch_CPP[ \t]*=[ \t]*//p'    mk/config.mk | tr -d ' \t')
os=$(sed -n 's/^HostOS_CPP[ \t]*=[ \t]*//p'        mk/config.mk | tr -d ' \t')
vendor=$(sed -n 's/^HostVendor_CPP[ \t]*=[ \t]*//p' mk/config.mk | tr -d ' \t')

out=ghc/includes/config.h
{
  echo "#define HostPlatform_TYPE   $cpp"
  echo "#define TargetPlatform_TYPE $cpp"
  echo "#define BuildPlatform_TYPE  $cpp"
  echo
  echo "#define ${cpp}_HOST	1"
  echo "#define ${cpp}_TARGET	1"
  echo "#define ${cpp}_BUILD	1"
  echo
  echo "#define ${arch}_HOST_ARCH	1"
  echo "#define ${arch}_TARGET_ARCH	1"
  echo "#define ${arch}_BUILD_ARCH	1"
  echo "#define HOST_ARCH		\"$arch\""
  echo
  echo "#define ${os}_HOST_OS		1"
  echo "#define ${os}_TARGET_OS		1"
  echo "#define ${os}_BUILD_OS		1"
  echo "#define HOST_OS		\"$os\""
  echo
  echo "#define ${vendor}_HOST_VENDOR	1"
  echo "#define ${vendor}_TARGET_VENDOR	1"
  echo "#define ${vendor}_BUILD_VENDOR	1"
  cat mk/config.h
} > "$out"
echo "wrote $out ($(grep -c '^#define' "$out") defines)"
