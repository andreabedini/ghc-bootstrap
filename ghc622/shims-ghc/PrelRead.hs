-- GHC 4.08 used PrelRead's non-standard readRational__ to turn the lexer's
-- float literals into exact Rationals.
--
-- The first version of this shim used `reads`, which at type Rational parses
-- the `numerator % denominator` form -- not "0.5" -- so it failed on the first
-- float literal in the Prelude. This parses the Haskell literal syntax
--
--     digits [ . digits ] [ (e|E) [+|-] digits ]
--
-- and builds the value exactly, without going through Double, so no precision
-- is lost for literals a Double cannot represent.
module PrelRead(readRational__) where

import Data.Char(isDigit)
import Data.Ratio((%))

readRational__ :: String -> Rational
readRational__ s0 =
  let (sign, s1) = case s0 of
                     '-':r -> (-1, r)
                     '+':r -> ( 1, r)
                     r     -> ( 1, r)
      (ipart, s2) = span isDigit s1
      (fpart, s3) = case s2 of
                      '.':r -> span isDigit r
                      r     -> ("", r)
      expo        = case s3 of
                      c:r | c == 'e' || c == 'E' ->
                        case r of
                          '+':d -> readInt d
                          '-':d -> negate (readInt d)
                          d     -> readInt d
                      _ -> 0
      mantissa    = readInt (ipart ++ fpart)
      scale       = 10 ^ length fpart
      base        = mantissa % scale
  in  if null ipart && null fpart
        then error ("readRational__: " ++ s0)
        else sign * (if expo >= 0 then base * (10 ^ expo)
                                  else base / (10 ^ negate expo))

readInt :: String -> Integer
readInt = foldl (\a c -> a * 10 + toInteger (fromEnum c - fromEnum '0')) 0
