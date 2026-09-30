#!/bin/sh
# The template step of happy 1.16's and alex 2.1.0's Setup.lhs (myPostBuild,
# cpp_template), for building them without Cabal:
#
#   sh cpp-template.sh <ghc> <src> <dst> [cpp flags...]
#
# `ghc -E -cpp` then perl turning cpp's `# 27 "File.hs"` into
# `{-# LINE 27 "File.hs" #-}`. One change to their regex: it also eats the
# flags a modern cpp puts after the file name (`# 1 "stdc-predef.h" 1 3 4`,
# gcc's include-enter/leave markers), which the 2006 regex left behind as
# stray tokens in the template.
set -eu
ghc=$1 src=$2 dst=$3; shift 3
"$ghc" -o "$dst.hspp" -E -cpp "$src" "$@"
perl -pe 's/^#\s+(\d+)\s+("[^"]*")(\s+\d+)*/{-# LINE \1 \2 #-}/g;s/\$(Id:.*)\$/\1/g' "$dst.hspp" > "$dst"
rm "$dst.hspp"
