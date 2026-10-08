#!/bin/sh
# Build GHC 6.6 with the chain's GHC 6.2.2 (build/ghc66-by-622/NOTES.md).
#   mise exec -- sh build/ghc66-by-622/build-66.sh        (queue under pueue-agent)
# Steps, each logged in logs/: configure, make (stage 1, rts, libraries, stage 2
# as the top-level Makefile orders them), then a hello-world through the
# in-place compilers. Re-runnable: configure is skipped once mk/config.mk exists.
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
B="$R/build/ghc66-by-622"; I="$B/ghc622-inst"
# TREE=<dir> selects the extraction dir (default src); FRESH=1 re-extracts the
# pristine tarball there and applies ghc-6.6-by-622.patch (the four tree edits).
T="${TREE:-$B/src}"; case "$T" in /*) ;; *) T="$R/$T" ;; esac; G="$T/ghc-6.6"
L="$B/logs${TREE:+-$(basename "$T")}"; mkdir -p "$L" "$B/tmp"
if [ "${FRESH:-0}" = 1 ]; then
  rm -rf "$G"; mkdir -p "$T"
  tar xjf "$R/ghc-6.6-src.tar.bz2" -C "$T" || exit 1
  (cd "$T" && patch -p0 < "$R/ghc66/ghc-6.6-by-622.patch") > "$L/patch.log" 2>&1 || { cat "$L/patch.log"; exit 1; }
  echo "fresh tree: $G, patch applied ($(rg -c '^\+\+\+' "$R/ghc66/ghc-6.6-by-622.patch") files)"
fi
export TMPDIR="$B/tmp"
# The machine's own GHC (ghcup, cabal) must not be found by configure or make.
clean=$(printf '%s' "$PATH" | tr ':' '\n' | grep -v -e '\.ghcup' -e '\.cabal' | paste -sd: -)
export PATH="$I/bin:$R/build/happy-mhs:$clean"
ulimit -s unlimited 2>/dev/null
stamp() { date '+%Y-%m-%d %H:%M:%S'; }
echo "$(stamp) start; ghc=$(command -v ghc) $(ghc --numeric-version); happy=$(command -v happy); gcc=$(gcc -dumpversion)"
cd "$G" || exit 1
if [ ! -f mk/config.mk ]; then
  echo "$(stamp) configure"
  ./configure --with-ghc="$I/bin/ghc" --with-gcc=gcc CFLAGS="-std=gnu89 -fpermissive -w" > "$L/configure.log" 2>&1
  rc=$?; echo "$(stamp) configure rc=$rc"; [ $rc = 0 ] || { tail -20 "$L/configure.log"; exit $rc; }
fi
echo "$(stamp) make"
make > "$L/make.log" 2>&1
rc=$?; echo "$(stamp) make rc=$rc"
echo "--- artefacts"
for f in compiler/stage1/ghc-6.6 compiler/stage2/ghc-6.6 compiler/ghc-inplace libraries/base/libHSbase.a rts/libHSrts.a utils/ghc-pkg/ghc-pkg-inplace utils/hsc2hs/hsc2hs-inplace compat/libghccompat.a; do
  if [ -e "$f" ]; then printf 'present  %s  %s\n' "$(stat -c %s "$f")" "$f"; else printf 'MISSING  %s\n' "$f"; fi
done
if [ $rc != 0 ]; then echo "--- last errors"; grep -n -i -E 'error|Error|\*\*\*' "$L/make.log" | tail -15; tail -30 "$L/make.log"; exit $rc; fi
echo "--- hello through the in-place compilers"
mkdir -p "$B/test" && printf 'main :: IO ()\nmain = putStrLn "hello from ghc 6.6 built by 6.2.2"\n' > "$B/test/Hello.hs"
cd "$B/test" || exit 1
for c in "$G/compiler/stage1/ghc-inplace" "$G/compiler/ghc-inplace"; do
  [ -x "$c" ] || { echo "no $c"; continue; }
  rm -f Hello.o Hello.hi hello
  if "$c" -v1 --make Hello.hs -o hello > "$L/hello-$(basename "$(dirname "$c")").log" 2>&1 && ./hello; then echo "OK   $c"; else echo "FAIL $c (see logs)"; fi
done
echo "$(stamp) done"
