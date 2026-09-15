#!/bin/sh
# Compile the hslibs/lang modules that hsc itself imports, with the bootstrapped
# hsc, reusing the Prelude interfaces built by build-prelude.sh.
#
# Scope: the compiler imports 44 modules from outside ghc/compiler. 20 come from
# ghc/lib/std and 24 from hslibs, all of them in hslibs/lang -- the transitive
# closure of Addr, Bits, ByteArray, Exception, Foreign, GlaExts, IOExts, Int,
# MutableArray, NativeInfo, ST and Word. None of the other eleven hslibs
# packages is needed. (SocketPrim and BSD appear in Main.lhs but sit behind
# "#if REPORT_TO_MOTHERLODE", which is off.)
#
# hslibs/lang/Makefile adds -I$(GHC_INCLUDE_DIR) over the std flags; the
# per-module -H/-monly-3-regs settings are heap and register tuning that do not
# apply to this unregisterised build.
#
#   phase3/build-hslibs-lang.sh [start-module]
set -u
R=/home/andrea/work/haskell/ghc-bootstrap
G="$R/build/ghc-4.08.2"
B="$R/build/ghc-mhs"
SRC="$G/hslibs/lang"
OUT="$B/lib"
ORDER="$R/phase3/hslibs-lang-order.txt"

mkdir -p "$OUT"
start="${1:-}"; started=0; [ -z "$start" ] && started=1
ok=0; fail=0
total=$(wc -l < "$ORDER")
n=0
while IFS= read -r m; do
  [ -z "$m" ] && continue
  n=$((n + 1))
  if [ "$started" = 0 ]; then [ "$m" = "$start" ] && started=1 || continue; fi
  src="$SRC/$m.lhs"; [ -f "$src" ] || src="$SRC/$m.hs"
  [ -f "$src" ] || { printf '%3d/%s  %-18s SKIP (no source)\n' "$n" "$total" "$m"; continue; }
  printf '%3d/%s  %-18s ' "$n" "$total" "$m"
  # hslibs/mk/target.mk:125 adds -package-name $(HSLIB); hslibs/lang/Makefile
  # sets HSLIB = lang and leaves HSLIB_DEPS empty, so no -package flags.
  # -static comes from hslibs/mk/target.mk:88; ghc.lprl:1676 passes it straight to hsc.
  # Without it the code generator treats cross-module closures as living in
  # another DLL and emits DLL_SRT_ENTRY, which InfoMacros.h defines as the
  # literal text "no-can-do" so that the C compiler refuses it.
  log="$OUT/$m.log"
  "$R/phase3/compile-lib-module.sh" "$src" \
      -inpackage=lang -static -fglasgow-exts -olang=C -fhi-version=408 \
      -fsimplify "[" -fmax-simplifier-iterations4 "]" \
      "-himap=$OUT%.hi" "-hifile=$OUT/$m.hi" "-ofile=$OUT/$m.hc" > "$log" 2>&1
  if [ -s "$OUT/$m.hc" ] && [ -s "$OUT/$m.hi" ]; then
    incs=""
    if [ -s "$OUT/$m.ccinc" ]; then
      # paths are already resolved by compile-lib-module.sh
      while IFS= read -r h; do [ -n "$h" ] && incs="$incs -include $h"; done < "$OUT/$m.ccinc"
    fi
    # -std=gnu89: Stable.h and friends use "extern inline", whose meaning is
    # inverted between GNU89 (inline only, emit nothing) and C99 (emit an
    # external definition here). Under C99 rules every .hc defines
    # deRefStablePtr and the link fails with multiple definitions. 1999 gcc
    # defaulted to gnu89, which is what this C was written against.
    if cc -c -x c -w -std=gnu89 -O -DNO_REGS -DUSE_MINIINTERPRETER \
          -I"$G/ghc/includes" -I"$SRC" -include "$G/ghc/includes/Stg.h" $incs \
          "$OUT/$m.hc" -o "$OUT/$m.o" >> "$log" 2>&1; then
      echo "OK"; ok=$((ok + 1))
    else
      echo "hc OK, gcc FAILED"; fail=$((fail + 1))
    fi
  else
    echo "FAILED: $(rg -v 'Warning|topCoreBindsToStg|ifaceBinds|^\s*$|^\s' "$log" 2>/dev/null | head -1 | cut -c1-90)"
    fail=$((fail + 1))
  fi
done < "$ORDER"
echo "compiled $ok, failed $fail"
