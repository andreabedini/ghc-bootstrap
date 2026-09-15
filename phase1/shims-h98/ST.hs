-- hslibs' ST: the ST monad plus the ST-array operations, which later moved to
-- Data.Array.MArray under different names.
module ST(module Control.Monad.ST, module Data.STRef,
          STArray, newSTArray, readSTArray, writeSTArray, freezeSTArray) where
import Control.Monad.ST
import Data.STRef
import Data.Array.MArray(STArray, newArray, readArray, writeArray, freeze)
import Data.Array(Array)
import Data.Ix(Ix)

newSTArray :: Ix i => (i, i) -> e -> ST s (STArray s i e)
newSTArray = newArray

readSTArray :: Ix i => STArray s i e -> i -> ST s e
readSTArray = readArray

writeSTArray :: Ix i => STArray s i e -> i -> e -> ST s ()
writeSTArray = writeArray

freezeSTArray :: Ix i => STArray s i e -> ST s (Array i e)
freezeSTArray = freeze
