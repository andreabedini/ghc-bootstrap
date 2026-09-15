#!/bin/sh
# Compile GHC 4.08.2's Prelude (ghc/lib/std) with the bootstrapped hsc, in
# dependency order. Each module produces a .hi (for later modules to import)
# and a .hc, which gcc then turns into a .o.
#
# hsc is never run with an empty Core-to-Core pass list: ghc.lprl's
# @HsC_minusNoO_flags passes "-fsimplify [ -fmax-simplifier-iterations4 ]" even
# when the user asks for no optimisation at all. Without it the inline-me
# wrapper around a _ccall_ is never inlined and the code generator dies with
#     cgPanic: lookupBindC: no info for $wccall_...
# on every module that does a foreign call.
#
#   phase3/build-prelude.sh [start-module]
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
G="$R/build/ghc-4.08.2"
B="$R/build/ghc-mhs"
SRC="$G/ghc/lib/std"
OUT="$B/lib"
ORDER="$R/phase3/lib-order.txt"

mkdir -p "$OUT"
# GHC's own rule: the primop interface is shipped, not compiled
cp -n "$SRC"/*.hi-boot "$OUT/" 2>/dev/null
cp -f "$SRC/PrelGHC.hi-boot" "$OUT/PrelGHC.hi"

# -fno-implicit-prelude is not passed here: 31 of the 45 modules carry it in
# their own {-# OPTIONS #-} pragma, and compile-lib-module.sh reproduces the
# driver's pragma scan (ghc.lprl:2778). Passing it positionally instead got six
# modules wrong -- Array, Char, Maybe, PrelArrExtra, PrelHugs and PrelStable all
# declare the flag but sort after Prelude. They compiled either way, which is
# exactly the problem: the flag changes how [] and () resolve, silently.

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
  # GHC's driver turns -package-name into hsc's own -inpackage flag
  #     ghc.lprl:3140  push(@HsC_flags,"-inpackage=$package")
  # and ghc/lib/std/Makefile:29 sets PACKAGE = -package-name std. Without it
  # opt_InPackage defaults to "Main" (CmdLineOpts.lhs:397), every interface is
  # stamped __interface "Main", and cross-package name lookup misbehaves.
  # -static comes from ghc/lib/std/Makefile:46; ghc.lprl:1676 passes it straight to hsc.
  # Without it the code generator treats cross-module closures as living in
  # another DLL and emits DLL_SRT_ENTRY, which InfoMacros.h defines as the
  # literal text "no-can-do" so that the C compiler refuses it.
  log="$OUT/$m.log"
  "$R/phase3/compile-lib-module.sh" "$src" \
      -inpackage=std -static -fglasgow-exts -olang=C -fhi-version=408 \
      -fsimplify "[" -fmax-simplifier-iterations4 "]" \
      "-himap=$OUT%.hi" "-hifile=$OUT/$m.hi" "-ofile=$OUT/$m.hc" > "$log" 2>&1
  if [ -s "$OUT/$m.hc" ] && [ -s "$OUT/$m.hi" ]; then
    # headers named by the module's -#include OPTIONS, which the driver used to
    # inject into the generated .hc; paths in them are relative to the source dir
    incs=""
    if [ -s "$OUT/$m.ccinc" ]; then
      # paths are already resolved by compile-lib-module.sh
      while IFS= read -r h; do [ -n "$h" ] && incs="$incs -include $h"; done < "$OUT/$m.ccinc"
    fi
    # -O is not a preference here, it is required. Stable.h declares
    # deRefStablePtr/freeStablePtr/splitStablePtr extern and then defines them
    # "extern inline", which under GNU89 emits no out-of-line copy -- and no .c
    # file provides one. Every call must therefore be inlined, which only
    # happens with optimisation on. GHC compiled everything this way:
    # mk/config.mk.in sets GhcLibHcOpts=-O and the cbits Makefile adds -O.
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
