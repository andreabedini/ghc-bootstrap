#!/bin/sh
# Compare a regenerated parser or lexer with the one a tarball shipped:
#
#   sh cmp-generated.sh <regenerated> <shipped>       exit 0 iff they agree
#
# They must agree line for line once blank lines and lines that are exactly
# a LINE pragma are dropped. Those are the parts a different cpp writes
# differently: the tool templates are cpp output, and 2006's gcc wrote
# `# 1 "<command line>"` where today's writes `# 0 "<command-line>"` and adds
# stdc-predef.h. Everything else, the tables, the actions and the template
# code, must be identical. Prints the first differences otherwise.
set -u
norm() { grep -v -E -e '^[[:space:]]*$' -e '^\{-# LINE [0-9]+ "[^"]*" #-\}$' "$1"; }
norm "$1" > "$1.norm"; norm "$2" > "$1.shipped.norm"
if cmp -s "$1.norm" "$1.shipped.norm"; then
  echo "$1: as shipped, modulo blank lines and LINE pragmas"
  rm "$1.norm" "$1.shipped.norm"
else
  echo "$1: DIFFERS from $2"; diff "$1.shipped.norm" "$1.norm" | head -20; exit 1
fi
