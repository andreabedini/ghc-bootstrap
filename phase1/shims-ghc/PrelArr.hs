-- GHC 4.08's array types. ByteArray here is only ever used to hold the bytes
-- of a string (FastString, StringBuffer, PrimPacked), so it is backed by a
-- String rather than by an emulation of GHC's ByteArray# primitives.
module PrelArr(ByteArray(..), ByteArray#, MutableByteArray#,
               StateAndByteArray#(..), StateAndMutableByteArray#(..),
               Array, STArray, newSTArray) where
import Data.Array(Array)
import Data.Array.MArray(STArray, newArray)
import Data.Ix(Ix)
import Control.Monad.ST(ST)

type ByteArray#        = String
type MutableByteArray# = String

data ByteArray i = ByteArray i i ByteArray#

data StateAndByteArray# s        = StateAndByteArray# s ByteArray#
data StateAndMutableByteArray# s = StateAndMutableByteArray# s MutableByteArray#

newSTArray :: Ix i => (i, i) -> e -> ST s (STArray s i e)
newSTArray = newArray
