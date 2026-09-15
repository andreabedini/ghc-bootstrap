#!/bin/sh
# Generalised version of scan-with-mhs.sh: run mhs over any GHC compiler tree,
# one module at a time, and record what it rejects.
#
#   phase2/scan-tree.sh <label> <tree> <includes> [extra-i-dir ...]
#
# Writes build/scan-<label>.tsv  (STATUS \t module \t message)
#
# Every tree is scanned with the SAME shim set and the SAME cpp defines, so the
# numbers are comparable across versions. -D__GLASGOW_HASKELL__=408 makes the
# source take its old-compiler CPP branches, which is the path an mhs bootstrap
# would actually follow; leaving it undefined would make #ifdef __GLASGOW_HASKELL__
# modules compile as empty and score a spurious OK.
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
M="$R/MicroHs"
LABEL="$1"
# absolutise: the script cd's into its work dir before scanning
TREE=$(cd "$2" && pwd) || exit 1
INCDIR=$(cd "$3" && pwd) || exit 1
shift 3
export PATH="$M/bin:$PATH"

INC="-i$R/phase1/shims -i$R/phase1/shims-ghc -i$R/phase1/shims-h98"
for d in "$@"; do INC="$INC -i$(cd "$d" && pwd)"; done
for d in "$TREE"/*/; do
  [ -d "$d" ] && INC="$INC -i${d%/}"
done
INC="$INC -i$TREE -I$TREE -I$INCDIR"

W="$R/build/scan-$LABEL"
mkdir -p "$W" && cd "$W" || exit 1
OUT="$R/build/scan-$LABEL.tsv"
: > "$OUT"

find "$TREE" -name '*.lhs' -o -name '*.hs' | sort | while read -r f; do
  m=$(basename "$f"); m="${m%.*}"
  out=$("$M/bin/mhs" -C -c -fno-code -XCPP -D__GLASGOW_HASKELL__=408 $INC "$m" 2>&1 | tr '\n' ' ')
  case "$out" in
    *"No code generated"*) printf 'OK\t%s\t\n' "$m" >> "$OUT" ;;
    *) printf 'FAIL\t%s\t%s\n' "$m" \
         "$(printf '%s' "$out" | sed 's|.*uncaught exception: ||' | cut -c1-240)" >> "$OUT" ;;
  esac
done
echo "done $LABEL: $(grep -c '^OK' "$OUT") OK / $(wc -l < "$OUT") total"
