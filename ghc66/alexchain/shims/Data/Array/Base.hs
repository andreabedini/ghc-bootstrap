-- Data.Array.Base for the alex chain (ghc66/alexchain.nix): common/shims'
-- one, plus the unsafeRead that alex's Output.hs imports. As in GHC it
-- takes the offset from the start of the array, whatever the bounds.
module Data.Array.Base(module Mhs.Array, UArray, unsafeRead) where
import Mhs.Array
import Control.Monad.ST
import Data.Array.MArray

type UArray = Array

unsafeRead :: STArray s Int e -> Int -> ST s e
unsafeRead arr i = do
  (l, _) <- getBounds arr
  readArray arr (l + i)
