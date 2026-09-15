#!/bin/sh
# Compile and link one Haskell program with the mhs-built GHC 6.2.2, base
# and RTS from this tree.
#
#   sh build/ghc622-mhs/link.sh test/Hello.hs [hello]     (output: test/hello)
#
# Reproduces by hand what DriverPipeline.staticLink (ghc/compiler/main/
# DriverPipeline.hs:990-1080) would issue:
#   gcc -o <out> <o_files> [-L<user>] [-optl] -L<pkg lib dirs> <pkg link opts>
# where the package link opts are, in dependency order base then rts
# (getPackageLinkOpts, DriverState.hs:383-397):
#   base: -lHSbase -lHSbase_cbits              (hs_libraries + extra_libraries)
#   rts:  -lHSrts -lm -lgmp -ldl + extra_ld_opts, the 32 "-u sym" options
#         from ghc/rts/package.conf.in (the RTS forward-references those
#         base closures/info tables; -u makes ld pull their modules in).
# Main.o supplies ZCMain_main_closure and __stginit_ZCMain; libHSrts.a's
# Main.o (rts/Main.c) supplies main(), which calls startupHaskell and
# rts_evalLazyIO on ZCMain_main_closure.
#
# -fwrapv: see build-hc.sh.
# The .hs -> .hc step is the driver (-C, -O, -package base; the driver adds
# unregFlags itself), the .hc -> .o step is build-hc.sh's recipe.
set -u
R=/home/andrea/work/haskell/ghc-bootstrap
W="$R/build/ghc622-mhs"
INC="$R/build/ghc-6.2.2-run1/ghc/includes"
CC=${CC:-gcc}
export TMPDIR="$W/test/tmp"; mkdir -p "$TMPDIR"
ulimit -s unlimited 2>/dev/null
src="$1"; dir=$(dirname "$src"); base=$(basename "$src" .hs)
out="${2:-$(printf '%s' "$base" | tr 'A-Z' 'a-z')}"
cd "$dir" || exit 1
(ulimit -v 6000000; "$W/ghc" +RTS -K5M -RTS "-B$W/topdir" ${VERB:--v1} -C ${OPT:--O} -package base ${HCFLAGS:-} "$base.hs" > "$base.compile.log" 2>&1) || { echo "ghc failed, see $dir/$base.compile.log"; tail -5 "$base.compile.log"; exit 1; }
$CC -c -x c -std=gnu89 -O -fwrapv ${CFLAGS:-} -w -DNO_REGS -DUSE_MINIINTERPRETER -D__GLASGOW_HASKELL__=622 \
    -I"$INC" -I"$W/libraries/base/include" -include "$INC/Stg.h" "$base.hc" -o "$base.o" || exit 1
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
    -L"$W/lib" -L"$R/build/rts622" \
    -lHSbase -lHSbase_cbits -lHSrts -lm -lgmp -ldl $U 2> "$base.link.log"
rc=$?
if [ $rc != 0 ]; then
  echo "link failed (rc=$rc): $(grep -c 'undefined reference' "$base.link.log") undefined references, see $dir/$base.link.log"
  grep -o "undefined reference to \`[^']*'" "$base.link.log" | sort | uniq -c | sort -rn | head -40
  exit $rc
fi
echo "linked $dir/$out"
