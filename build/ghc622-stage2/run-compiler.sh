#!/bin/sh
# Stage 2: compile GHC 6.2.2's compiler proper (pristine sources in src/) with
# the stage-1, mhs-built ghc, one module at a time in dependency order, to
# .hi + .hc under stage2/<dir>/ (explicit -o/-ohi, as ghc/compiler/Makefile
# does for its stageN trees; .hi-boot files are linked in beside the .hi).
#
#   sh build/ghc622-stage2/run-compiler.sh [order-file]      (default order.txt)
#
# Flags are ghc/compiler/Makefile's SRC_HC_OPTS for a bootstrapped, no-GHCi,
# no-NCG build: -cpp -fglasgow-exts -I. -IcodeGen -InativeGen -Iparser
# -DOMIT_NATIVE_CODEGEN '-#include "hschooks.h"' -recomp, -O (GhcStage2HcOpts is
# empty in mk/config.mk.in; the shipped binaries were built -O), plus the
# per-module <file>_HC_OPTS of the Makefile (see extra_flags below).  Dropped:
# -Rghc-timing and -H16M (RTS hooks, no-ops under the MicroHs runtime).  The
# packages base and haskell98 are auto (topdir/package.conf); the driver adds
# unregFlags itself because Config.cGhcUnregisterised = "YES".
#
# Retry ladder when an attempt dies of a runtime error/panic/timeout (not on a
# plain compile error): -O -> -O -fno-strictness -> -O0.  Each row of the tsv
# records the flags that produced the module.
#
# Env: FRESH=0 to resume (rows already OK in the tsv are skipped, and modules
# whose outputs are newer than the source are marked cached), MODTIMEOUT (s,
# default 3600), STOP=1 to stop at the first failure, VERB (default -v1),
# MHSRTS (default "+RTS -K50M -RTS": MicroHs stack; consumed by the runtime,
# not the driver), GHC (the compiler to use; default the stage-1 one),
# OUTDIR (default stage2; the stage-3 run uses stage3), OUT (tsv path).
set -u
R=/home/andrea/work/haskell/ghc-bootstrap
S="$R/build/ghc622-stage2"
GHC="${GHC:-$R/build/ghc622-mhs/ghc}"
TOPDIR="$S/topdir"
SRC="$S/src/ghc-6.2.2/ghc/compiler"
ODIR="${OUTDIR:-$S/stage2}"
export TMPDIR="$S/tmp"
mkdir -p "$TMPDIR"
ulimit -s unlimited 2>/dev/null || ulimit -s 65536
ORDER="${1:-$S/order.txt}"
OUT="${OUT:-$S/results.tsv}"
LOGS="${LOGS:-$S/logs/$(basename "$ODIR")}"
mkdir -p "$LOGS"
[ "${FRESH:-1}" = 1 ] && : > "$OUT"

ALL_DIRS="utils basicTypes types hsSyn prelude rename typecheck deSugar coreSyn specialise simplCore stranal stgSyn simplStg codeGen absCSyn main profiling parser cprAnalysis compMan ndpFlatten"
IDIRS=""
for d in $ALL_DIRS; do
  mkdir -p "$ODIR/$d"
  IDIRS="$IDIRS -i$ODIR/$d"
  # Makefile 'boot': the .hi-boot files must live where the .hi files do.
  for b in "$SRC/$d"/*.hi-boot*; do
    [ -f "$b" ] && ln -sf "$b" "$ODIR/$d/$(basename "$b")"
  done
done

# ghc/compiler/Makefile's per-module options (those that are not RTS/profiling/
# platform-specific).  -fvia-C is implied (unregisterised); -H80m dropped.
extra_flags() {
  case "$1" in
    utils/Binary.hs)          echo "-funbox-strict-fields -O" ;;
    main/ParsePkgConf.hs)     echo "-fno-warn-incomplete-patterns" ;;
    parser/Parser.hs)         echo "-fno-warn-incomplete-patterns" ;;
    parser/Lexer.hs)          echo "-funbox-strict-fields" ;;
    main/BinIface.hs|utils/FastMutInt.lhs) echo "-O" ;;
    compMan/CompManager.lhs|main/CmdLineOpts.lhs|main/DriverFlags.hs|main/DriverMkDepend.hs|main/DriverPipeline.hs|main/DriverState.hs|main/DriverUtil.hs|main/Finder.lhs|main/SysTools.lhs) echo "-fno-cse" ;;
    prelude/PrimOp.lhs)       echo "-no-recomp" ;;
    *) echo "" ;;
  esac
}
# Makefile: parser/Parser_HC_OPTS += -Onot.  Everything else starts at -O.
first_opt() {
  case "$1" in
    parser/Parser.hs) echo "-Onot" ;;
    *) echo "${OPT:--O}" ;;
  esac
}

cd "$SRC" || exit 1
ok=0; fail=0
while IFS="$(printf '\t')" read -r m path; do
  [ -n "$m" ] || continue
  dir=$(dirname "$path")
  hc="$ODIR/$dir/$m.hc"; hi="$ODIR/$dir/$m.hi"
  if [ "${FRESH:-1}" = 0 ]; then
    if grep -q "^OK	$m	" "$OUT" 2>/dev/null; then ok=$((ok+1)); continue; fi
    if [ -f "$hc" ] && [ -f "$hi" ] && [ "$hc" -nt "$path" ]; then
      printf 'OK\t%s\t(cached)\n' "$m" >> "$OUT"; ok=$((ok+1)); continue; fi
  fi
  log="$LOGS/$m.log"
  extra=$(extra_flags "$path")
  # fixups/<path>: a copy of the source compiled in place of the pristine one
  # when the *stage-1* compiler cannot read it (parser/Ctype.lhs: Latin-1
  # bytes in comments, GetImports.hs reads text under MicroHs). Only for
  # GHC=stage 1; a native compiler takes the pristine file.
  fixnote=""
  src="$path"
  if [ -f "$S/fixups/$path" ] && [ "${USE_FIXUPS:-1}" = 1 ]; then src="$S/fixups/$path"; fixnote=" [fixups]"; fi
  attempt() {   # $1 = opt flags for this attempt
    rm -f "$hc" "$hi"
    ( ulimit -v 8000000
      timeout "${MODTIMEOUT:-3600}" "$GHC" ${MHSRTS:-+RTS -K50M -RTS} "-B$TOPDIR" ${VERB:--v1} -C \
        -cpp -fglasgow-exts -I. -IcodeGen -InativeGen -Iparser -DOMIT_NATIVE_CODEGEN \
        '-#include' '"hschooks.h"' -recomp $IDIRS $1 $extra ${EXTRA:-} \
        -o "$hc" -ohi "$hi" "$src" ) > "$log" 2>&1
  }
  retryable() {  # a runtime death, a panic or a timeout -- not a plain compile error
    [ "$1" = 124 ] || [ "$1" = 137 ] || [ "$1" = 134 ] || [ "$1" = 139 ] || \
      grep -q -e 'ERR:' -e 'panic' -e 'impossible' -e 'exhausted' -e 'stack overflow' -e 'Killed' -e 'Segmentation' -e 'out of memory' "$log"
  }
  start=$(date +%s)
  opt=$(first_opt "$path"); ladder="$opt"
  attempt "$opt"; rc=$?
  if [ $rc != 0 ] && retryable $rc; then
    cp "$log" "$log.1"
    case "$opt" in -O0|-Onot) ;; *)
      opt="$opt -fno-strictness"; ladder="$ladder -> $opt"; attempt "$opt"; rc=$?
      if [ $rc != 0 ] && retryable $rc; then
        cp "$log" "$log.2"; opt="-O0"; ladder="$ladder -> $opt"; attempt "$opt"; rc=$?
      fi ;;
    esac
  fi
  secs=$(( $(date +%s) - start ))
  if [ $rc = 0 ] && [ -f "$hc" ] && [ -f "$hi" ]; then
    printf 'OK\t%s\t%ss\t%s\t%s lines hc\t%s%s\n' "$m" "$secs" "$opt $extra" "$(wc -l < "$hc")" "$ladder" "$fixnote" >> "$OUT"; ok=$((ok+1))
  else
    msg=$(tr '\n' ' ' < "$log" | sed 's/  */ /g' | cut -c1-300)
    printf 'FAIL\t%s\t%ss\trc=%s\t%s\t%s\n' "$m" "$secs" "$rc" "$ladder" "$msg" >> "$OUT"; fail=$((fail+1))
    [ "${STOP:-0}" = 1 ] && break
  fi
done < "$ORDER"
echo "stage2: $ok OK, $fail FAIL (see $OUT)"
