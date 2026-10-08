-- Data.Array.MArray over MicroHs's Mhs.MutArr. These are genuinely mutable
-- (primArrRead/primArrWrite), so reads and writes are O(1) as they must be for
-- happy's table builder; only the MArray *class* is missing, and no caller here
-- needs the overloading.
module Data.Array.MArray(STArray, STUArray, newArray, readArray, writeArray,
                         getBounds, freeze, thaw, getElems) where
import Mhs.Array
import Mhs.MutArr
import Control.Monad.ST

data STArray s i e = STArray (i, i) Int (MutSTArr s e)

type STUArray = STArray

newArray :: Ix i => (i, i) -> e -> ST s (STArray s i e)
newArray b e = do
  let n = rangeSize b
  a <- newMutSTArr n e
  return (STArray b n a)

readArray :: Ix i => STArray s i e -> i -> ST s e
readArray (STArray b _ a) i = unsafeReadMutSTArr a (index b i)

writeArray :: Ix i => STArray s i e -> i -> e -> ST s ()
writeArray (STArray b _ a) i x = unsafeWriteMutSTArr a (index b i) x

getBounds :: STArray s i e -> ST s (i, i)
getBounds (STArray b _ _) = return b

getElems :: STArray s i e -> ST s [e]
getElems (STArray _ n a) = mapM (unsafeReadMutSTArr a) [0 .. n - 1]

freeze :: Ix i => STArray s i e -> ST s (Array i e)
freeze arr@(STArray b _ _) = do
  es <- getElems arr
  return (listArray b es)

thaw :: Ix i => Array i e -> ST s (STArray s i e)
thaw arr = do
  let b = bounds arr
      n = rangeSize b
  a <- newMutSTArr n (error "thaw: uninitialised")
  mapM_ (\ (i, e) -> unsafeWriteMutSTArr a (index b i) e) (assocs arr)
  return (STArray b n a)
