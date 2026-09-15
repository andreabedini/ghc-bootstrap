#!/bin/sh
# Archive libHSbase.a and libHSbase_cbits.a for the mhs-built GHC 6.2.2.
#   libHSbase.a       = every $HCOBJ/*.o (default hcobj) build-hc.sh produced (one per base
#                       module) + cbitsobj/Control_Concurrent_stub.o
#   libHSbase_cbits.a = cbitsobj/*.o from build-cbits.sh (minus the stub)
# Rerun after build-hc.sh adds modules; nothing is recompiled here.
# Output: build/ghc622-mhs/lib/.
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
W="$R/build/ghc622-mhs"
LIB="$W/lib"
OBJ="${HCOBJ:-$W/hcobj}"
mkdir -p "$LIB"
n=$(ls "$OBJ"/*.o | wc -l)
rm -f "$LIB/libHSbase.a" "$LIB/libHSbase_cbits.a"
ar rcs "$LIB/libHSbase.a" "$OBJ"/*.o "$W/cbitsobj/Control_Concurrent_stub.o" || exit 1
c=0; set --
for o in "$W"/cbitsobj/*.o; do
  case "$o" in */Control_Concurrent_stub.o) continue ;; esac
  set -- "$@" "$o"; c=$((c+1))
done
ar rcs "$LIB/libHSbase_cbits.a" "$@" || exit 1
echo "libHSbase.a: $n module objects + stub; libHSbase_cbits.a: $c objects"
