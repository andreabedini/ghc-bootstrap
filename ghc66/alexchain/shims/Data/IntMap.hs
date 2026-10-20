-- Data.IntMap for the alex chain (ghc66/alexchain.nix): a Map Int, the
-- functions alex 3 uses.
module Data.IntMap(IntMap, empty, singleton, insert, insertWith, lookup,
                   member, findWithDefault, fromList, fromListWith, toList,
                   toAscList, elems, keys, unionWith, mapWithKey, size) where
import Prelude hiding (lookup)
import Data.Map

type IntMap = Map Int
