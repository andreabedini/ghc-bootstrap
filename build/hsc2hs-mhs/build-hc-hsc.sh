#!/bin/sh
# Compile the .hc files of the seven hsc2hs-dependent modules (hsc-order.txt) to .o
# with exactly build/ghc622-mhs/build-hc.sh's recipe, into the same hcobj/ directory.
# build-hc.sh itself walks every .hc under libraries/base and would rewrite the 137
# objects another run owns; this touches only the listed modules' objects.
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
W="$R/build/ghc622-mhs"
INC="$R/build/ghc-6.2.2-run1/ghc/includes"
CC=${CC:-gcc}
cd "$W/libraries/base" || exit 1
ok=0; fail=0
while read -r m; do
  [ -n "$m" ] || continue
  hc="$(printf '%s' "$m" | tr . /).hc"
  o="$W/hcobj/$(printf '%s' "$m" | tr . _).o"
  if [ ! -f "$hc" ]; then printf '%-28s no .hc\n' "$m"; fail=$((fail+1)); continue; fi
  if $CC -c -x c -std=gnu89 -O -w -fmax-errors=20 \
        -DNO_REGS -DUSE_MINIINTERPRETER -D__GLASGOW_HASKELL__=622 \
        -I"$INC" -Iinclude -I. -include "$INC/Stg.h" "$hc" -o "$o" 2> "$o.log"; then
    ok=$((ok+1)); printf '%-28s ok  %s\n' "$m" "$(wc -c < "$o") bytes"
  else
    fail=$((fail+1)); printf '%-28s %s\n' "$m" "$(grep -m1 error "$o.log" | cut -c1-120)"
  fi
done < "${1:-$R/build/hsc2hs-mhs/hsc-order.txt}"
echo "hc -> o: $ok ok, $fail failed"
