#!/bin/sh
# Reproduce the GHC 6.2.2 compiler tree that mhs compiles (DECISIONS.md D45,
# D46) from the pristine tarball, with one command:
#
#   sh phase4/reproduce-6.2.2.sh [dest]        default dest: build/repro-622
#
# Result, under <dest>:
#   src/ghc-6.2.2/    full extraction, patched and configured (the RTS work
#                     in build/rts622 starts from the same tree)
#   ghc/              the compiler tree in the shape build/ghc-6.2.2-run1/ghc
#                     has: compiler/ includes/ utils/ghc-pkg/, i.e. what
#                     build/probe-ordered-622.sh takes as <tree> and <includes>
#   order-6.2.2.txt   the module order, regenerated with phase2/build-order.py
#   log/              one log per step; log/verify.diff if a reference exists
#
# Steps (each records its provenance in phase4/FINDINGS.md):
#   1  tar xjf ghc-6.2.2-src.tar.bz2, sha256 checked
#   2  patch -p1 with ghc622/patches/*.patch (exact: no fuzz, no offset allowed)
#   3  ./configure --enable-hc-boot --enable-hc-boot-unregisterised, with a
#      PATH that holds no ghc (build/rts622/FINDINGS.md section 1)
#   4  make -C ghc/includes config.h      (GHC's own $(H_CONFIG) rule)
#   5  ghc/includes/DerivedConstants.h from mkDerivedConstants.c, compiled with
#      the unregisterised flags -DNO_REGS -DUSE_MINIINTERPRETER (STD_ITBL_SIZE 3)
#  5b  ghc/includes/NativeDefs.h from mkNativeHdr.c, same flags (TcForeign.lhs
#      reaches it through nativeGen/NCG.h even without a native code generator)
#   6  phase4/regen-generated.sh: primops.txt, 10 primop-*.hs-incl, 3 parsers
#      (post-processed by ghc622/tools/fix-generated-parsers.sh)
#   7  ghc622/tools/convert-lexer.py on the shipped alex output parser/Lexer.hs
#   8  ln -s ../../utils/ghc-pkg ghc/compiler/utils/ghc-pkg
#      (main/Packages.lhs #includes ../utils/ghc-pkg/Package.hs)
#   9  assemble <dest>/ghc, regenerate the order file
#  10  verify: diff -r against build/ghc-6.2.2-run1/ghc when it exists
#
# Not produced here, because they are inputs rather than tree contents (see
# FINDINGS.md "Inputs that are not in the tree"): ghc622/shims,
# ghc622/hsboot, ghc622/gen/Config.hs.
#
# Needs: gcc, GNU make, patch, python3, tar/bzip2, and the chain's own tools
# (MicroHs/bin/{mhs,cpphs}, build/happy-mhs/happy-mhs2). Takes 3-4 minutes.
set -eu
R=$(cd "$(dirname "$0")/.." && pwd)
P4=$R/phase4
D=${1:-$R/build/repro-622}
mkdir -p "$D"; D=$(cd "$D" && pwd)
TARBALL=$R/ghc-6.2.2-src.tar.bz2
SHA256=a0fe7eb8d447f25fbc616cdbce2bb4e03961a884c2c37969d1e23588b588a852
REF=$R/build/ghc-6.2.2-run1/ghc

mkdir -p "$D/tmp" "$D/log"
export TMPDIR="$D/tmp"                         # patch(1) and mhs need a writable one
rm -rf "$D/src" "$D/ghc" "$D/tools"
mkdir -p "$D/src"
step() { printf '== %s\n' "$*"; }

# 1 ---------------------------------------------------------------------------
step "extract $TARBALL"
have=$(sha256sum "$TARBALL" | cut -d' ' -f1)
[ "$have" = "$SHA256" ] || { echo "sha256 mismatch: $have"; exit 1; }
tar xjf "$TARBALL" -C "$D/src"
S=$D/src/ghc-6.2.2
[ -d "$S/ghc/compiler" ] || { echo "unexpected tarball layout"; exit 1; }

# 2 ---------------------------------------------------------------------------
step "apply ghc622/patches"
cd "$S"
n=0
for p in "$R"/ghc622/patches/*.patch; do
  out=$(patch -p1 -N -i "$p" 2>&1) || { printf '%s\n' "$out"; echo "FAILED: $p"; exit 1; }
  case "$out" in *fuzz*|*offset*) printf '%s\n' "$out"; echo "INEXACT: $p"; exit 1 ;; esac
  n=$((n + 1))
done
echo "   $n patches applied exactly"

# 3 ---------------------------------------------------------------------------
step "configure (no ghc on PATH)"
# The machine may have a GHC installed; GHC's configure would probe it and
# record it as the booter. The bootstrap has no GHC, so configure must not
# see one: a minimal PATH. --enable-hc-boot is what lets configure finish
# without a ghc; --enable-hc-boot-unregisterised selects the C-only build.
PATH=/usr/bin:/bin ./configure --enable-hc-boot --enable-hc-boot-unregisterised \
    --host=x86_64-unknown-linux --build=x86_64-unknown-linux \
    --target=x86_64-unknown-linux > "$D/log/configure.log" 2>&1 \
  || { tail -20 "$D/log/configure.log"; echo "configure failed"; exit 1; }
grep -q '^HostArch_CPP[[:space:]]*=[[:space:]]*x86_64' mk/config.mk || { echo "configure did not select x86_64"; exit 1; }

# 4 ---------------------------------------------------------------------------
step "ghc/includes/config.h (GHC's H_CONFIG rule)"
# ghc/includes/Makefile prepends the platform defines from mk/config.mk to
# mk/config.h. Running the rule itself instead of transcribing it.
PATH=/usr/bin:/bin make -C ghc/includes config.h > "$D/log/config-h.log" 2>&1 \
  || { cat "$D/log/config-h.log"; echo "make config.h failed"; exit 1; }
grep -q '^#define x86_64_TARGET_ARCH' ghc/includes/config.h || { echo "config.h lacks x86_64_TARGET_ARCH"; exit 1; }

# 5 ---------------------------------------------------------------------------
step "ghc/includes/DerivedConstants.h"
# ghc/includes/Makefile builds mkDerivedConstants with the RTS's CFLAGS; for an
# unregisterised build mk/bootstrap.mk adds -DNO_REGS -DUSE_MINIINTERPRETER
# (no TABLES_NEXT_TO_CODE, so the info table carries an entry pointer:
# STD_ITBL_SIZE 3). Modern gcc needs -include stdio.h (the file uses printf
# without including it) and the linker must ignore the never-called gmp and
# stable-pointer inlines Stg.h drags in.
gcc -O2 -w -include stdio.h -DNO_REGS -DUSE_MINIINTERPRETER -Ighc/includes \
    -Wl,--unresolved-symbols=ignore-all ghc/includes/mkDerivedConstants.c \
    -o "$D/tmp/mkDerivedConstants" > "$D/log/derived-constants.log" 2>&1
"$D/tmp/mkDerivedConstants" > ghc/includes/DerivedConstants.h
grep -Eq 'STD_ITBL_SIZE +3' ghc/includes/DerivedConstants.h || { echo "unexpected STD_ITBL_SIZE"; exit 1; }

# 5b --------------------------------------------------------------------------
step "ghc/includes/NativeDefs.h"
# ghc/includes/Makefile: `all :: NativeDefs.h`, built from mkNativeHdr.c with
# the same flags, unconditionally (not only with a native code generator).
# The compiler needs it even without the NCG: typecheck/TcForeign.lhs
# includes nativeGen/NCG.h for the *_TARGET_ARCH macros, and NCG.h includes
# ../includes/NativeDefs.h (found by the stage-2 build on 2026-09-15; the mhs
# probe's cpphs had let the missing include pass).
gcc -O2 -w -include stdio.h -DNO_REGS -DUSE_MINIINTERPRETER -Ighc/includes \
    -Wl,--unresolved-symbols=ignore-all ghc/includes/mkNativeHdr.c \
    -o "$D/tmp/mkNativeHdr" > "$D/log/native-defs.log" 2>&1
"$D/tmp/mkNativeHdr" > ghc/includes/NativeDefs.h
grep -q 'OFFSET_R1' ghc/includes/NativeDefs.h || { echo "NativeDefs.h looks wrong"; exit 1; }

step "regenerate parsers and primop tables (happy-mhs2, cpphs, genprimopcode)"
sh "$P4/regen-generated.sh" "$S" "$D/tools" > "$D/log/regen.log" 2>&1 \
  || { tail -20 "$D/log/regen.log"; echo "regeneration failed"; exit 1; }

# 7 ---------------------------------------------------------------------------
step "ghc/includes/config.h: HTYPE_* (gen-htypes.c)"
# configure's FPTOOLS_CHECK_HTYPE probes have a K&R main() that gcc >= 14
# rejects, so config.h leaves every HTYPE_* #undef and Foreign.Storable (and
# the 96 base modules behind it) will not compile. ghc622/tools/gen-htypes.c reruns
# the probes' logic and its output is appended (DECISIONS.md D47). This step
# runs AFTER the primops regeneration on purpose: cpphs echoes every directive
# of an included header as a blank line, and primops.txt in the working tree
# was generated before the HTYPE block existed (the 71 trailing blank lines
# would otherwise differ; genprimopcode does not care either way).
gcc -O -w -o "$D/tmp/gen-htypes" "$R/ghc622/tools/gen-htypes.c" > "$D/log/gen-htypes.log" 2>&1 \
  || { cat "$D/log/gen-htypes.log"; echo "gen-htypes failed"; exit 1; }
# Inside the include guard, as build/ghc-6.2.2-run1 has it: the closing
# `#endif /* __FPTOOLS_CONFIG_H__ */` is moved after the appended block.
tail -1 ghc/includes/config.h | grep -q '^#endif' || { echo "config.h does not end with #endif"; exit 1; }
sed '$d' ghc/includes/config.h > "$D/tmp/config.h.body"
{ cat "$D/tmp/config.h.body"; "$D/tmp/gen-htypes"; printf '\n#endif /* __FPTOOLS_CONFIG_H__ */\n'; } > ghc/includes/config.h
grep -q '^#define HTYPE_INT ' ghc/includes/config.h || { echo "config.h lacks HTYPE_INT"; exit 1; }

# 6 ---------------------------------------------------------------------------
step "convert the alex lexer"
# The tarball ships alex's -g output (parser/Lexer.hs); its Addr# tables are
# decoded into boxed arrays (build/lexer622/FINDINGS.md). The converter
# asserts every line it touches against the pristine text.
python3 "$R/ghc622/tools/convert-lexer.py" ghc/compiler/parser/Lexer.hs "$D/tmp/Lexer.hs" > "$D/log/lexer.log" 2>&1
mv "$D/tmp/Lexer.hs" ghc/compiler/parser/Lexer.hs

# 8 ---------------------------------------------------------------------------
step "ghc-pkg symlink"
ln -s ../../utils/ghc-pkg ghc/compiler/utils/ghc-pkg

# 9 ---------------------------------------------------------------------------
step "assemble $D/ghc"
mkdir -p "$D/ghc/utils"
cp -a ghc/compiler "$D/ghc/compiler"
cp -a ghc/includes "$D/ghc/includes"
cp -a ghc/utils/ghc-pkg "$D/ghc/utils/ghc-pkg"

step "module order"
# phase2/build-order.py, then drop the ilxGen test programs (they are not
# modules of the compiler; build/order-6.2.2.txt was made the same way).
python3 - "$R" "$D/ghc/compiler" > "$D/order-6.2.2.txt" <<'EOF'
import importlib.util, sys
R, tree = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("bo", R + "/phase2/build-order.py")
bo = importlib.util.module_from_spec(spec); spec.loader.exec_module(bo)
deps, defined = bo.scan(tree)
for m in bo.order(deps):
    if "/ilxGen/tests/" not in defined[m]:
        print(m)
EOF
echo "   $(wc -l < "$D/order-6.2.2.txt") modules"
if [ -f "$R/build/order-6.2.2.txt" ]; then
  if diff "$D/order-6.2.2.txt" "$R/build/order-6.2.2.txt" > "$D/log/order.diff"; then
    echo "   identical to build/order-6.2.2.txt"
  else
    echo "   DIFFERS from build/order-6.2.2.txt (see log/order.diff)"
  fi
fi

# 10 --------------------------------------------------------------------------
if [ -d "$REF" ]; then
  step "verify against $REF"
  if diff -r -x tmp -x '.mhscache*' -x '*.log' -x '*.rej' -x '*.orig' -x '*.o' \
          -x '*.comb' -x .claude "$D/ghc" "$REF" > "$D/log/verify.diff" 2>&1; then
    echo "   IDENTICAL"
  else
    echo "   differences (log/verify.diff):"
    grep -E '^(diff|Only in)' "$D/log/verify.diff" | sed 's/^/     /'
    # config.h: build/ghc-6.2.2-run1's copy was transcribed by hand from the
    # Makefile rule (build/rts622); it differs from the rule's own output only
    # in the tabs of its 28-line prologue. Report whether that is all.
    if diff -r -w -x tmp -x '.mhscache*' -x '*.log' -x '*.rej' -x '*.orig' -x '*.o' \
            -x '*.comb' -x .claude "$D/ghc" "$REF" > /dev/null 2>&1; then
      echo "   whitespace-insensitive: IDENTICAL"
    fi
  fi
fi
echo "== done: $D"
