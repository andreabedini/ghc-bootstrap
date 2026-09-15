-- GHC 6.0's FastMutInt is one machine word in a MutableByteArray#, poked with
-- readIntArray#/writeIntArray#. MicroHs has neither; an IORef Int is the same
-- abstraction without the primops (cf. D20: reimplement, don't emulate).
module FastMutInt(
  FastMutInt, newFastMutInt,
  readFastMutInt, writeFastMutInt,
  incFastMutInt, incFastMutIntBy
  ) where

import Data.IORef

newtype FastMutInt = FastMutInt (IORef Int)

newFastMutInt :: IO FastMutInt
newFastMutInt = FastMutInt `fmap` newIORef 0

readFastMutInt :: FastMutInt -> IO Int
readFastMutInt (FastMutInt r) = readIORef r

writeFastMutInt :: FastMutInt -> Int -> IO ()
writeFastMutInt (FastMutInt r) = writeIORef r

incFastMutInt :: FastMutInt -> IO Int          -- returns the original value
incFastMutInt m = incFastMutIntBy m 1

incFastMutIntBy :: FastMutInt -> Int -> IO Int -- returns the original value
incFastMutIntBy (FastMutInt r) n = do
  i <- readIORef r
  writeIORef r (i + n)
  return i
