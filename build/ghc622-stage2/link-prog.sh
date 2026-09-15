#!/bin/sh
# build/ghc622-mhs/link.sh parameterised on the compiler: compile and link one
# Haskell program against the stage-1-built base/haskell98 and build/rts622.
#   GHC=<compiler> sh link-prog.sh test/Hello.hs [out]     (default GHC: the stage-2 ghc)
# Same steps: driver -C (with the stage-2 topdir: base + haskell98 auto),
# gcc -std=gnu89 -O -fwrapv on the .hc, then staticLink's line by hand.
# When the compiler is a native one no +RTS -K is passed (the 6.2.2 RTS has
# its own defaults via hschooks.c); MHSRTS overrides.
set -u
R=/home/andrea/work/haskell/ghc-bootstrap
S="$R/build/ghc622-stage2"
GHC="${GHC:-$S/ghc}"
INC="$S/src/ghc-6.2.2/ghc/includes"
CC=${CC:-gcc}
export TMPDIR="$S/tmp"; mkdir -p "$TMPDIR"
ulimit -s unlimited 2>/dev/null
src="$1"; dir=$(dirname "$src"); base=$(basename "$src" .hs)
out="${2:-$(printf '%s' "$base" | tr 'A-Z' 'a-z')}"
cd "$dir" || exit 1
start=$(date +%s.%N)
(ulimit -v 8000000; "$GHC" ${MHSRTS:-} "-B$S/topdir" ${VERB:--v1} -C ${OPT:--O} ${HCFLAGS:-} "$base.hs" > "$base.compile.log" 2>&1) || { echo "ghc failed, see $dir/$base.compile.log"; tail -5 "$base.compile.log"; exit 1; }
printf 'compile %s: %.2f s\n' "$base.hs" "$(echo "$(date +%s.%N) - $start" | bc)"
$CC -c -x c -std=gnu89 -O -fwrapv ${CFLAGS:-} -w -DNO_REGS -DUSE_MINIINTERPRETER -D__GLASGOW_HASKELL__=602 \
    -I"$INC" -I"$S/libraries/base/include" -include "$INC/Stg.h" "$base.hc" -o "$base.o" || exit 1
U=""
for s in GHCziBase_Izh_static_info GHCziBase_Czh_static_info GHCziFloat_Fzh_static_info \
         GHCziFloat_Dzh_static_info GHCziPtr_Ptr_static_info GHCziWord_Wzh_static_info \
         GHCziInt_I8zh_static_info GHCziInt_I16zh_static_info GHCziInt_I32zh_static_info \
         GHCziInt_I64zh_static_info GHCziWord_W8zh_static_info GHCziWord_W16zh_static_info \
         GHCziWord_W32zh_static_info GHCziWord_W64zh_static_info GHCziStable_StablePtr_static_info \
         GHCziBase_Izh_con_info GHCziBase_Czh_con_info GHCziFloat_Fzh_con_info GHCziFloat_Dzh_con_info \
         GHCziPtr_Ptr_con_info GHCziPtr_FunPtr_con_info GHCziStable_StablePtr_con_info \
         GHCziBase_False_closure GHCziBase_True_closure GHCziPack_unpackCString_closure \
         GHCziIOBase_stackOverflow_closure GHCziIOBase_heapOverflow_closure \
         GHCziIOBase_NonTermination_closure GHCziIOBase_BlockedOnDeadMVar_closure \
         GHCziIOBase_Deadlock_closure GHCziWeak_runFinalizzerBatch_closure __stginit_Prelude; do
  U="$U -u $s"
done
$CC ${LDFLAGS:-} -o "$out" "$base.o" ${EXTRA_O:-} \
    -L"$S/libraries/haskell98" -L"$R/build/ghc622-mhs/lib" -L"$R/build/rts622" \
    -lHShaskell98 -lHSbase -lHSbase_cbits -lHSrts -lm -lgmp -ldl $U 2> "$base.link.log"
rc=$?
if [ $rc != 0 ]; then
  echo "link failed (rc=$rc): $(grep -c 'undefined reference' "$base.link.log") undefined references, see $dir/$base.link.log"
  grep -o "undefined reference to \`[^']*'" "$base.link.log" | sort | uniq -c | sort -rn | head -40
  exit $rc
fi
echo "linked $dir/$out"
