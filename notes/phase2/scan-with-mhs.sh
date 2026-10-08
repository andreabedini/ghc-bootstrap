#!/bin/sh
# Run mhs over a GHC compiler tree, one module at a time, and classify what it
# rejects. This is the mhs-side check that notes/phase1/FINDINGS.md says is missing:
# phase1 measured what GHC *uses*, this measures what mhs *refuses*.
#
#   notes/phase2/scan-with-mhs.sh [tree] > notes/phase2/scan.log
#
# Each module is compiled alone with -c -fno-code, so a failure deep in the
# import graph is reported against every module that reaches it. Read the
# summary at the end, not the per-module lines.
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
M="$R/MicroHs"
TREE="${1:-$R/build/ghc-4.08.2/ghc/compiler}"
export PATH="$M/bin:$PATH"

# every subdirectory of the compiler is a source root, plus our shims
# Generated parsers live outside the tree so the tarball stays pristine
# (see D11): patches, not edits in place.
INC="-i$R/common/shims -i$R/build/ghc-parsers"
for d in "$TREE"/*/; do
  [ -d "$d" ] && INC="$INC -i${d%/}"
done
INC="$INC -i$TREE -I$TREE -I$R/build/ghc-4.08.2/ghc/includes"

mkdir -p "$R/build/ghc-scan" && cd "$R/build/ghc-scan" || exit 1

for f in $(find "$TREE" -name '*.lhs' -o -name '*.hs' | sort); do
  m=$(basename "$f"); m="${m%.*}"
  out=$("$M/bin/mhs" -C -c -fno-code -XCPP $INC "$m" 2>&1 | tr '\n' ' ')
  case "$out" in
    *"No code generated"*) printf 'OK\t%s\n' "$m" ;;
    *) printf 'FAIL\t%s\t%s\n' "$m" "$(printf '%s' "$out" | sed 's|.*uncaught exception: ||' | cut -c1-200)" ;;
  esac
done
