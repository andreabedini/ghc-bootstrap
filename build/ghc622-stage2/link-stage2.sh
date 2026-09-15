#!/bin/sh
# Link the stage-2 ghc from obj/*.o, the way DriverPipeline.staticLink would
# (build/ghc622-mhs/link.sh, with haskell98 added): packages in dependency
# order haskell98, base, rts -- hs_libraries, extra_libraries, then rts's
# extra_ld_opts (the 32 -u symbols of ghc/rts/package.conf.in).  main() comes
# from libHSrts.a's Main.o; the compiler's Main.o supplies ZCMain_main_closure;
# hschooks.o overrides the RTS's default hooks (each hook is its own archive
# member, so the explicit object wins without -u).
#   OUTDIR=stage3 sh link-stage2.sh   -> ghc-stage3  from obj-stage3/
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
S="$R/build/ghc622-stage2"
ODIR="${OUTDIR:-stage2}"
if [ "$ODIR" = stage2 ]; then OBJ="$S/obj"; BIN="$S/ghc"; else OBJ="$S/obj${ODIR#stage2}"; BIN="$S/ghc-${ODIR}"; fi
CC=${CC:-gcc}
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
$CC ${LDFLAGS:-} -o "$BIN" "$OBJ"/*.o \
    -L"$S/libraries/haskell98" -L"$R/build/ghc622-mhs/lib" -L"$R/build/rts622" \
    -lHShaskell98 -lHSbase -lHSbase_cbits -lHSrts -lm -lgmp -ldl $U 2> "$S/link-$ODIR.log"
rc=$?
if [ $rc != 0 ]; then
  echo "link failed (rc=$rc): $(grep -c 'undefined reference' "$S/link-$ODIR.log") undefined references, see $S/link-$ODIR.log"
  grep -o "undefined reference to \`[^']*'" "$S/link-$ODIR.log" | sort | uniq -c | sort -rn | head -40
  exit $rc
fi
ls -la "$BIN"; echo "linked $BIN"
