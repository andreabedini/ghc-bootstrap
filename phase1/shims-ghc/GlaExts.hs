-- GlaExts: the GHC-extensions module that GHC 4.08.2's own compiler imports
-- from its `base` (26 import sites, the largest single RTS dependency).
--
-- MicroHs has no unboxed types, so every unboxed type here is an alias for its
-- boxed counterpart and every primop is the ordinary operation. The boxing
-- constructors -- I#, C#, W#, F#, D# -- become *identity pattern synonyms*,
-- which mhs supports, so GHC's `case n of I# n# -> ...` and `I# (a +# b)` both
-- work unchanged. That is what lets the compiler's source stay unpatched
-- (DECISIONS.md D11) despite 215 uses of these constructors across 35 modules.
--
-- The semantics differ from GHC's in exactly one way that matters: these are
-- lifted, so an "unboxed" value here can be bottom. Nothing in the compiler
-- relies on the difference for correctness, only for speed.
module GlaExts(
  -- unboxed types
  Int#, Char#, Word#, Addr#, Float#, Double#, RealWorld, State#, Ptr,
  -- HsVersions.h maps _ByteArray/_MutableArray/_ST/_RealWorld onto these
  ByteArray, ByteArray#, MutableByteArray, MutableByteArray#, MutableArray,
  ST, runST, stToIO, unsafeInterleaveIO, unsafePerformIO,
  -- boxing
  pattern I#, pattern C#, pattern W#, pattern F#, pattern D#,
  -- arithmetic
  (+#), (-#), (*#), quotInt#, remInt#, negateInt#,
  -- comparison
  (==#), (/=#), (<#), (<=#), (>#), (>=#),
  -- characters
  ord#, chr#, eqChar#, neChar#, ltChar#, leChar#, gtChar#, geChar#,
  -- words and bits
  int2Word#, word2Int#, and#, or#, xor#, not#,
  shiftL#, shiftRL#, iShiftL#, iShiftRA#, uncheckedShiftL#,
  narrow16Int#, intToInt16#,
  -- Haskell 98 leftovers GHC 4.08 still used
  fromInt,
  module Data.Int, module Data.Word, module Data.Char, module Data.Bits,
  ) where

import Data.Bits
import Data.Char
import Data.Int
import Data.Word
import Foreign.Ptr(Ptr)
import Control.Monad.ST(ST, runST, stToIO)
import System.IO.Unsafe(unsafeInterleaveIO, unsafePerformIO)
import PrelArr(ByteArray(..), ByteArray#, MutableByteArray#)
import Data.Array.MArray(STArray)
import qualified Data.Bits as B

type Int#    = Int
type Char#   = Char
type Word#   = Word
type Addr#   = Ptr Word8    -- a real pointer: PrimPacked does peek at these
type Float#  = Float
type Double# = Double
data RealWorld
type MutableByteArray = ByteArray
type MutableArray = STArray
type State# s = ()

pattern I# :: Int#    -> Int
pattern I# x = x
pattern C# :: Char#   -> Char
pattern C# x = x
pattern W# :: Word#   -> Word
pattern W# x = x
pattern F# :: Float#  -> Float
pattern F# x = x
pattern D# :: Double# -> Double
pattern D# x = x

infixl 6 +#, -#
infixl 7 *#
infix  4 ==#, /=#, <#, <=#, >#, >=#

(+#), (-#), (*#), quotInt#, remInt# :: Int# -> Int# -> Int#
(+#) = (+)
(-#) = (-)
(*#) = (*)
quotInt# = quot
remInt#  = rem

negateInt# :: Int# -> Int#
negateInt# = negate

(==#), (/=#), (<#), (<=#), (>#), (>=#) :: Int# -> Int# -> Bool
(==#) = (==)
(/=#) = (/=)
(<#)  = (<)
(<=#) = (<=)
(>#)  = (>)
(>=#) = (>=)

eqChar#, neChar#, ltChar#, leChar#, gtChar#, geChar# :: Char# -> Char# -> Bool
eqChar# = (==)
neChar# = (/=)
ltChar# = (<)
leChar# = (<=)
gtChar# = (>)
geChar# = (>=)

ord# :: Char# -> Int#
ord# = ord
chr# :: Int# -> Char#
chr# = chr

int2Word# :: Int# -> Word#
int2Word# = fromIntegral
word2Int# :: Word# -> Int#
word2Int# = fromIntegral

and#, or#, xor# :: Word# -> Word# -> Word#
and# = (B..&.)
or#  = (B..|.)
xor# = B.xor

not# :: Word# -> Word#
not# = complement

shiftL#, shiftRL#, uncheckedShiftL# :: Word# -> Int# -> Word#
shiftL#          = shiftL
shiftRL#         = shiftR
uncheckedShiftL# = shiftL

iShiftL#, iShiftRA# :: Int# -> Int# -> Int#
iShiftL#  = shiftL
iShiftRA# = shiftR

-- sign-extend the low 16 bits, as GHC's narrow16Int# does
narrow16Int#, intToInt16# :: Int# -> Int#
narrow16Int# i = let m = i B..&. 0xffff
                 in if m >= 0x8000 then m - 0x10000 else m
intToInt16# = narrow16Int#

-- Haskell 98 had fromInt in the Num class; base dropped it.
fromInt :: Num a => Int -> a
fromInt = fromIntegral
