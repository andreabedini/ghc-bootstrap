#!/bin/sh
# Compare a regenerated parser or lexer with the one a tarball shipped:
#
#   sh cmp-generated.sh <regenerated> <shipped>       exit 0 iff they agree
#
# They must agree line for line once blank lines, lines that are exactly a
# LINE pragma, and lines that are exactly a raw cpp line marker
# (`# 1 "/usr/include/stdc-predef.h" 1 3 4`) are dropped. Those are the
# parts a different cpp writes differently: the tool templates are cpp
# output, and 2006's gcc wrote `# 1 "<command line>"` where today's writes
# `# 0 "<command-line>"` and adds stdc-predef.h; and a template cpp'd
# through happy's or alex's Setup.lhs keeps a marker with flags after the
# file name as it is (the regex bug cpp-template.sh fixes), so parsers made
# upstream by such a happy carry raw markers (happy 1.19.12's own, by
# 1.19.10). Everything else, the tables, the actions and the template code,
# must be identical. Prints the first differences otherwise.
set -u
norm() { grep -v -E -e '^[[:space:]]*$' -e '^\{-# LINE [0-9]+ "[^"]*" #-\}$' -e '^# [0-9]+ "[^"]*"( [0-9]+)*$' "$1"; }
norm "$1" > "$1.norm"; norm "$2" > "$1.shipped.norm"
if cmp -s "$1.norm" "$1.shipped.norm"; then
  echo "$1: as shipped, modulo blank lines and LINE pragmas"
  rm "$1.norm" "$1.shipped.norm"
else
  echo "$1: DIFFERS from $2"; diff "$1.shipped.norm" "$1.norm" | head -20; exit 1
fi
