#!/bin/sh
# Make happy 1.19.5's output acceptable to GHC 6.2.2. Applied to the three
# generated parsers (main/ParsePkgConf.hs, parser/ParserCore.hs,
# parser/Parser.hs) right after happy writes them; regen-generated.sh and
# build/gen622/regen.sh both call this.
#
#   sh ghc622/tools/fix-generated-parsers.sh <file>...
#
# Three rewrites, each a 2020s template habit that a 2004 compiler rejects
# (build/ghc622-stage2/LOG.md, fixes 2 and 3 and the 2026-09-15 resume):
#  1. `{-# OPTIONS_GHC -w #-}` -> `{-# OPTIONS -w #-}`: 6.2.2's matchOptions
#     matches the prefix OPTIONS and reads `_GHC` as a flag.
#  2. drop `import Control.Applicative(Applicative(..))` and
#     `import Control.Monad (ap)`: no 6.2.2 base has Control.Applicative, and
#     with `%monad { P }` nothing in the file uses either.
#  3. `(P) HappyAbsSyn` -> `P HappyAbsSyn` in the action_*/happyReduce_*
#     signature block. When the grammar's monad is a type synonym for a
#     function type (ParserCore: `type P a = String -> Int -> ParseResult a`),
#     6.2.2's tcHsType applies the parenthesised head without expanding the
#     synonym, leaving a bare TyConApp that uTys cannot unify with a FunTy
#     ("Couldn't match `String -> Int -> ParseResult a' against `P
#     HappyAbsSyn'"). Later GHCs expand synonyms during unification, so happy
#     never noticed. Harmless where P is a newtype (Parser, ParsePkgConf).
set -u
for f in "$@"; do
  sed -i \
    -e '1s/^{-# OPTIONS_GHC -w #-}$/{-# OPTIONS -w #-}/' \
    -e '/^import Control\.Applicative(Applicative(\.\.))$/d' \
    -e '/^import Control\.Monad (ap)$/d' \
    -e "s/(\([A-Za-z][A-Za-z0-9_']*\)) HappyAbsSyn/\1 HappyAbsSyn/g" \
    "$f"
done
