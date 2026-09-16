#!/bin/sh
# Compile one module of GHC 6.2.2's compiler proper with the stage-1 compiler
# (or, with GHC/OUTDIR/... set as build/Makefile's STAGE3_ENV does, with the
# native stage-2 compiler into stage3/), for build/Makefile: run-compiler.sh's
# loop body for a single module.
#   sh build/mk/compile-stage2.sh <Module> <dir/File.ext>     exit 0 iff .hi and .hc exist
# Flags: ghc/compiler/Makefile's SRC_HC_OPTS for a bootstrapped no-GHCi no-NCG
# build, plus the per-module <file>_HC_OPTS (extra_flags), -O by default
# (Parser -Onot). Retry ladder on a runtime death/panic/timeout, not on a plain
# compile error: -O -> -O -fno-strictness -> -O0; $S/flags.tsv (module<TAB>opt)
# names the rung to start at (seeded from the 2026-09-15 run, where 25 modules
# needed -fno-strictness after a ~4 min doomed -O attempt each). fixups/<path>
# replaces a source the *stage-1* compiler cannot read (USE_FIXUPS=0 to
# disable, e.g. for a native GHC). Outputs are removed before each attempt;
# the .hi must decode (check-hi.sh). Appends a row to results.tsv.
# Env: GHC, OUTDIR (stage2), OUT, LOGS, MODTIMEOUT (3600), VERB, MHSRTS, EXTRA,
# FLAGS (the seed tsv; default $S/flags.tsv, /dev/null for an unseeded ladder).
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
S="$R/build/ghc622-stage2"
GHC="${GHC:-$R/build/ghc622-mhs/ghc}"
TOPDIR="$S/topdir"
SRC="$S/src/ghc-6.2.2/ghc/compiler"
ODIR="${OUTDIR:-$S/stage2}"
ulimit -s unlimited 2>/dev/null || ulimit -s 65536
OUT="${OUT:-$S/results.tsv}"
LOGS="${LOGS:-$S/logs/$(basename "$ODIR")}"; mkdir -p "$LOGS"
m=$1; path=$2; dir=$(dirname "$path")
# GHC 6.2.2 names temp files ghc<pid>.<ext> and steps to pid+1 when the name
# is taken, so parallel compiles sharing one TMPDIR can read each other's
# preprocessed source (2026-09-16: GHC/Unicode.hi came out as GHC.STRef's).
# Each compile gets a directory of its own.
export TMPDIR="$S/tmp/$m.$$"; mkdir -p "$TMPDIR"; trap 'rm -rf "$TMPDIR"' EXIT
ALL_DIRS="utils basicTypes types hsSyn prelude rename typecheck deSugar coreSyn specialise simplCore stranal stgSyn simplStg codeGen absCSyn main profiling parser cprAnalysis compMan ndpFlatten"
IDIRS=""
for d in $ALL_DIRS; do
  mkdir -p "$ODIR/$d"; IDIRS="$IDIRS -i$ODIR/$d"
  for b in "$SRC/$d"/*.hi-boot*; do   # Makefile 'boot': .hi-boot beside the .hi
    [ -f "$b" ] && [ ! -e "$ODIR/$d/$(basename "$b")" ] && ln -sf "$b" "$ODIR/$d/$(basename "$b")"
  done
done
hc="$ODIR/$dir/$m.hc"; hi="$ODIR/$dir/$m.hi"; log="$LOGS/$m.log"
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
first_opt() {
  case "$1" in parser/Parser.hs) echo "-Onot" ;; *) echo "${OPT:--O}" ;; esac
}
extra=$(extra_flags "$path")
fixnote=""; src="$path"
if [ -f "$S/fixups/$path" ] && [ "${USE_FIXUPS:-1}" = 1 ]; then src="$S/fixups/$path"; fixnote=" [fixups]"; fi
cd "$SRC" || exit 1
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
FLAGS="${FLAGS:-$S/flags.tsv}"
if [ -f "$FLAGS" ]; then
  seed=$(awk -F'\t' -v m="$m" '$1==m {print $2}' "$FLAGS" | tail -1)
  case "$seed" in
    *-fno-strictness*) opt="-O -fno-strictness"; ladder="$opt [flags.tsv]" ;;
    -O0)               opt="-O0";               ladder="$opt [flags.tsv]" ;;
  esac
fi
attempt "$opt"; rc=$?
if [ $rc != 0 ] && retryable $rc; then
  cp "$log" "$log.1"
  case "$opt" in -O0|-Onot) ;; *)
    case "$opt" in *-fno-strictness*) ;; *) opt="$opt -fno-strictness"; ladder="$ladder -> $opt"; attempt "$opt"; rc=$? ;; esac
    if [ $rc != 0 ] && retryable $rc; then
      cp "$log" "$log.2"; opt="-O0"; ladder="$ladder -> $opt"; attempt "$opt"; rc=$?
    fi ;;
  esac
fi
secs=$(( $(date +%s) - start ))
if [ $rc = 0 ] && [ -f "$hc" ] && [ -f "$hi" ] && sh "$R/build/mk/check-hi.sh" "$hi" "$m" >> "$log" 2>&1; then
  printf 'OK\t%s\t%ss\t%s %s\t%s lines hc\t%s%s\n' "$m" "$secs" "$opt" "$extra" "$(wc -l < "$hc")" "$ladder" "$fixnote" >> "$OUT"
  echo "$(basename "$ODIR") $m: OK ${secs}s ($opt$fixnote)"
else
  printf 'FAIL\t%s\t%ss\trc=%s\t%s\t%s%s\n' "$m" "$secs" "$rc" "$ladder" "$(tr '\n' ' ' < "$log" | sed 's/  */ /g' | cut -c1-400)" "$fixnote" >> "$OUT"
  rm -f "$hc" "$hi"; echo "$(basename "$ODIR") $m: FAIL rc=$rc ($ladder), see $log"; exit 1
fi
