#!/bin/sh
# Compile a GHC compiler tree with mhs in dependency order, sharing the -C cache.
# 6.2.2 variant of build/probe-ordered-slit.sh (identical defines; see header).
# This is the shape that D22 says is the only one that works: module-at-a-time
# standalone compilation mis-binds boot modules, so it under-reports badly.
#
#   sh build/probe-ordered-622.sh <label> <tree> <includes> <order-file> <hsboot-dir> [extra-i ...]
#
# Writes build/probe-<label>.tsv  (STATUS \t module \t message)
#
# 6.2.2 decisions (2026-09-09):
#  * -D__GLASGOW_HASKELL__=408 is kept. HsVersions.h maps GLAEXTS/DATA_BITS/
#    UNSAFE_IO/... to the pre-hierarchical names (GlaExts, Bits, IOExts) under
#    __GLASGOW_HASKELL__ < 504, which is what phase1/shims* and shims-6.2.2-run1
#    provide; the >= 504 branches want GHC.Exts/GHC.IOBase/GHC.Handle.
#    Consequence in 6.2.2: SysTools takes its "< 603" branch (private rawSystem,
#    imports CForeign + Foreign(withMany, withArray0, nullPtr, Ptr)), hence the
#    CForeign.hs and Foreign.hs shims in build/shims-6.2.2-run1.
#  * No -DHscIfaceFileVersion: 6.2.2 (like 6.0) reads it from Config.hs
#    (cHscIfaceFileVersion = "6", ghc/mk/version.mk); no cpp reference remains
#    in the compiler sources (rg confirms only Makefile:192 mentions it).
#  * -DOMIT_NATIVE_CODEGEN as before; nativeGen/ is not in the order file.
#  * GHCI is not defined (as in 6.0-run2): Main does not import InteractiveUI.
set -u
R=/home/andrea/work/haskell/ghc-bootstrap
M="$R/MicroHs"
LABEL="$1"
TREE=$(cd "$2" && pwd)   || exit 1
INCDIR=$(cd "$3" && pwd) || exit 1
ORDER=$(cd "$(dirname "$4")" && pwd)/$(basename "$4")
HSBOOT=$(cd "$5" && pwd) || exit 1
shift 5
DEFS="${DEFS:-}"
# The five defines the perl driver passes to cpp for every Haskell source
# (ghc.lprl @HsSourceCppOpts). They are not optional: HsVersions.h keys
# FMAP/ISALPHANUM/IOERROR/PSEQ off __HASKELL1__, so without them FMAP
# expands to map instead of fmap and 60+ modules fail to typecheck.
HSCPP="-D__HASKELL__=98 -D__HASKELL1__=5 -D__GLASGOW_HASKELL__=408 -D__HASKELL98__ -D__CONCURRENT_HASKELL__"
export PATH="$M/bin:$PATH"

# EXTRA_SHIMS: a directory searched before phase1/shims-ghc, so a tree-specific
# shim (6.0 needs LitString in FastString) can shadow the 4.08.2 one.
INC="-i$HSBOOT${EXTRA_SHIMS:+ -i$EXTRA_SHIMS} -i$R/phase1/shims -i$R/phase1/shims-ghc -i$R/phase1/shims-h98"
for d in "$@"; do INC="$INC -i$(cd "$d" && pwd)"; done
for d in "$TREE"/*/; do
  [ -d "$d" ] && INC="$INC -i${d%/}"
done
INC="$INC -i$TREE -I$TREE -I$INCDIR"

W="$R/build/probe-$LABEL"
[ "${FRESH:-1}" = 1 ] && rm -rf "$W"
mkdir -p "$W" && cd "$W" || exit 1
OUT="$R/build/probe-$LABEL.tsv"
: > "$OUT"

while read -r m; do
  [ -n "$m" ] || continue
  # Codegen mode, not -fno-code: mhs only reads and writes the -C cache when it
  # generates code, so with -fno-code every module recompiled MicroHs's library
  # and all its tree dependencies from scratch (~40s floor, quadratic overall).
  # Success is the exit status; the criterion is "compiles to code", which is
  # stricter than "typechecks".
  raw=$(timeout "${MODTIMEOUT:-180}" "$M/bin/mhs" ${MHSRTS:-+RTS -K20M -RTS} -C -c -XCPP $HSCPP -DOMIT_NATIVE_CODEGEN $DEFS $INC "$m" 2>&1); rc=$?
  out=$(printf '%s' "$raw" | tr '\n' ' ')
  # A crash mid-write (e.g. a stack overflow) leaves .mhscache truncated and
  # every later module fails with "Bad LZMA signature". Keep a copy of the last
  # good cache and fall back to it once, so one crash cannot void the run.
  case "$out" in *"Bad LZMA signature"*)
    if [ -f .mhscache.good ]; then cp .mhscache.good .mhscache
      raw=$(timeout "${MODTIMEOUT:-180}" "$M/bin/mhs" ${MHSRTS:-+RTS -K20M -RTS} -C -c -XCPP $HSCPP -DOMIT_NATIVE_CODEGEN $DEFS $INC "$m" 2>&1); rc=$?
      out=$(printf '%s' "$raw" | tr '\n' ' ')
    fi ;;
  esac
  case "$rc" in
    0)   printf 'OK\t%s\t\n' "$m" >> "$OUT"; cp .mhscache .mhscache.good 2>/dev/null ;;
    124) printf 'TIMEOUT\t%s\tkilled after ${MODTIMEOUT:-180}s\n' "$m" >> "$OUT" ;;
    *) printf 'FAIL\t%s\t%s\n' "$m" \
         "$(printf '%s' "$out" | sed 's|.*uncaught exception: ||' | cut -c1-240)" >> "$OUT" ;;
  esac
done < "$ORDER"
echo "done $LABEL: $(grep -c '^OK' "$OUT") OK / $(wc -l < "$OUT") total"
