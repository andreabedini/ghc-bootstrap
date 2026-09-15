#!/bin/sh
# Compile one module of GHC 4.08.2's own library with the bootstrapped hsc.
#
# hsc is GHC's *compiler proper*: it does not unlit and does not run cpp -- the
# perl driver did both before invoking it. So this reproduces the driver's
# pipeline:
#
#     unlit  (GHC's own, built from ghc/utils/unlit/unlit.c)
#       -> cpphs  (built by mhs from MicroHs's shipped source)
#       -> hsc    (built by mhs from GHC's own source)
#
# The filename must come first: CmdLineOpts.src_filename takes argv's head and
# panics "no filename" if it starts with '-'.
#
#   phase3/compile-lib-module.sh <module.lhs> [extra hsc flags...]
set -u
R="${GHC_BOOTSTRAP_ROOT:?not set: run under mise from the repo (mise exec -- ..., see mise.toml)}"
M="$R/MicroHs"
B="$R/build/ghc-mhs"
G="$R/build/ghc-4.08.2"
OUT="$B/lib"
export PATH="$M/bin:$B:$R/build/tools-ghc:$PATH"

src="$1"; shift
base=$(basename "$src"); base="${base%.*}"
mkdir -p "$OUT" && cd "$OUT" || exit 1

# GHC 4.08.2's sources are Latin-1, not UTF-8: CPUTime.lhs carries a stray 0xA0
# (a non-breaking space) inside a comment. hsc runs on mhs, whose file reader is
# UTF-8-only and aborts with "ERR: getb_utf8". So transcode when the bytes are
# not already valid UTF-8. Every other file in ghc/lib/std is pure ASCII, where
# the two encodings agree, so this is a no-op for them.
in_src="$src"
if ! iconv -f utf-8 -t utf-8 "$src" >/dev/null 2>&1; then
  in_src="$OUT/$base.latin1.lhs"
  iconv -f iso-8859-1 -t utf-8 "$src" > "$in_src" || exit 1
fi

# .lhs is literate and needs unlit; .hs is already plain Haskell. The driver
# dispatches on the suffix (ghc.lprl:37, "- .lhs literate Haskell: unlit").
# hslibs/lang has three plain .hs files -- ArrayBase, IArray and MArray.
case "$src" in
  *.lhs) unlit "$in_src" "$OUT/$base.unlit.hs" || exit 1 ;;
  *)     cp "$in_src" "$OUT/$base.unlit.hs" || exit 1 ;;
esac
# __CONCURRENT_HASKELL__ is how GHC 4.08 built its libraries; without it
# PrelIOBase takes a dead branch importing PrelArr(MutableVar, readVar),
# and MutableVar is not defined anywhere in the 4.08.2 tree.
# exactly ghc.lprl:387, @HsSourceCppOpts
cpphs --strip --linepragma -D__HASKELL__=98 -D__HASKELL1__=5 \
      -D__GLASGOW_HASKELL__=408 -D__HASKELL98__ -D__CONCURRENT_HASKELL__ \
      -I"$G/ghc/includes" -I"$(dirname "$src")" \
      "$OUT/$base.unlit.hs" -O"$OUT/$base.hs" || exit 1

# GHC's driver scans the de-litified source for {-# OPTIONS ... #-} and appends
# what it finds to the command line (ghc.lprl:2778, check_for_source_options).
# hsc does not read pragmas itself, so reproduce the scan here -- exactly the
# driver's rules: match only at column 0, skip blank / #line / {-# LINE lines,
# and stop at the first other non-empty line.
#
# 31 of the 45 std modules carry -fno-implicit-prelude this way. Without the
# scan they are compiled with an implicit "import Prelude", which changes how
# ParseUtil resolves [], () and tuples -- and does so silently, since the
# modules still typecheck.
opts=$(awk '
  /^\{-# OPTIONS / { sub(/^\{-# OPTIONS /,""); sub(/#-\}.*$/,""); print; next }
  /^[ 	]*$/       { next }
  /^#line/         { next }
  /^\{-# LINE/     { next }
  { exit }
' "$OUT/$base.unlit.hs")

# -#include is a driver flag, not an hsc flag: it names a C header to inject
# into the generated .hc (ghc.lprl:3433). Split the two apart.
# Resolve one -#include value to something gcc's -include will find.
# Three shapes occur in the 4.08.2 sources:
#   <sys/stat.h>          a system header -- strip the brackets and let the
#                         include path find it
#   ../../rts/Schedule.h  relative to the module's own directory
#   Assembler.h           relative to ghc/includes
#   stgio.h               relative to ghc/lib/std/cbits -- hslibs/lang/Makefile:20
#                         adds -I$(GHC_IO_INCLUDE_DIR) for IOExts alone
resolve_inc() {
  h=$(printf '%s' "$1" | tr -d '"')
  case "$h" in
    \<*\>) printf '%s\n' "$h" | tr -d '<>' ; return ;;
  esac
  d=$(dirname "$src")
  if [ -f "$d/$h" ]; then printf '%s\n' "$d/$h"
  elif [ -f "$G/ghc/includes/$h" ]; then printf '%s\n' "$G/ghc/includes/$h"
  elif [ -f "$G/ghc/lib/std/cbits/$h" ]; then printf '%s\n' "$G/ghc/lib/std/cbits/$h"
  else printf '%s\n' "$h"
  fi
}

hsc_opts=""; : > "$OUT/$base.ccinc"
want_inc=0
for o in $opts; do
  if [ "$want_inc" = 1 ]; then
    resolve_inc "$o" >> "$OUT/$base.ccinc"
    want_inc=0; continue
  fi
  case "$o" in
    -\#include*)
      # "-#include" and its value are separate words after splitting; the value
      # may also be glued on as -#include"foo.h".
      v=${o#-\#include}
      if [ -n "$v" ]; then resolve_inc "$v" >> "$OUT/$base.ccinc"
      else want_inc=1; fi ;;
    -*) hsc_opts="$hsc_opts $o" ;;
  esac
done

ulimit -s unlimited 2>/dev/null
# no `| head` here: hsc emits many trace lines, and a truncating
# pipe SIGPIPEs it mid-compile, leaving a half-written .hi
# OPTIONS go at the back of the command line, as the driver appends them.
"$B/hsc" "$OUT/$base.hs" +RTS -K20M -H500M -RTS "$@" $hsc_opts 2>&1
rc=$?

# hsc writes only a *partial* interface: no module-version integer, no
# per-declaration versions, and the sections in MkIface's emission order rather
# than the order ParseIface.y demands. GHC's driver fixed that up with
# ghc/driver/ghc-iface.lprl, and MkIface.lhs says so:
#
#   NOTE: ALWAYS remember that ghc-iface.lprl rewrites the interface file,
#   so you have to keep it in synch with the code below.
#
# Run GHC's own script rather than reimplement it -- see DECISIONS.md D28 for
# why perl in the chain is acceptable here.
hi=$(printf '%s\n' "$@" | sed -n 's/^-hifile=//p')
if [ -n "${hi:-}" ] && [ -s "$hi" ]; then
  # The script looks for a *previous* interface for this module by name, and
  # the working directory is where hsc just wrote one -- it would find its own
  # input and compute a version delta against it, leaving the module version
  # empty. Move the raw output aside so no PrelX.hi is visible while it runs.
  mv -f "$hi" "$hi.raw"
  GHC_IFACE_PRL="$R/build/tools-ghc/ghc-iface.prl" \
    perl "$R/phase3/hi-postprocess.pl" "$hi.raw" "$hi" "$base" 2>/dev/null \
    || mv -f "$hi.raw" "$hi"
  rm -f "$hi.raw"
fi
exit $rc
