-- A weight-balanced binary search tree, the same shape containers uses.
--
-- The first version of this shim was a sorted association list, which is fine
-- at happy's scale and hopeless at GHC's: FastString interning does one lookup
-- and possibly one insert per identifier in the source, so O(n) per operation
-- is O(n^2) over a compilation. This is O(log n).
module Data.Map(Map, empty, singleton, insert, insertWith, delete, adjust,
                lookup, member, findWithDefault, union, unions, difference,
                (\\), toList, toAscList, fromList, keys, elems, null, size,
                foldrWithKey, filterWithKey) where
import Prelude hiding (lookup, null, filter)
import qualified Prelude as P

data Map k v = Tip | Bin !Int !k v !(Map k v) !(Map k v)

delta, ratio :: Int
delta = 3       -- how far out of balance a subtree may get
ratio = 2       -- single vs double rotation

size :: Map k v -> Int
size Tip = 0
size (Bin n _ _ _ _) = n

bin :: k -> v -> Map k v -> Map k v -> Map k v
bin k v l r = Bin (size l + size r + 1) k v l r

-- rebalance after one insertion or deletion
balance :: k -> v -> Map k v -> Map k v -> Map k v
balance k v l r
  | sl + sr <= 1   = bin k v l r
  | sr > delta*sl  = rotateL k v l r
  | sl > delta*sr  = rotateR k v l r
  | otherwise      = bin k v l r
  where sl = size l
        sr = size r

rotateL, rotateR :: k -> v -> Map k v -> Map k v -> Map k v
rotateL k v l r@(Bin _ _ _ rl rr)
  | size rl < ratio * size rr = singleL k v l r
  | otherwise                 = doubleL k v l r
rotateL k v l Tip = bin k v l Tip
rotateR k v l@(Bin _ _ _ ll lr) r
  | size lr < ratio * size ll = singleR k v l r
  | otherwise                 = doubleR k v l r
rotateR k v Tip r = bin k v Tip r

singleL, singleR, doubleL, doubleR :: k -> v -> Map k v -> Map k v -> Map k v
singleL k1 v1 t1 (Bin _ k2 v2 t2 t3) = bin k2 v2 (bin k1 v1 t1 t2) t3
singleL k1 v1 t1 Tip                 = bin k1 v1 t1 Tip
singleR k1 v1 (Bin _ k2 v2 t1 t2) t3 = bin k2 v2 t1 (bin k1 v1 t2 t3)
singleR k1 v1 Tip t3                 = bin k1 v1 Tip t3
doubleL k1 v1 t1 (Bin _ k2 v2 (Bin _ k3 v3 t2 t3) t4) =
  bin k3 v3 (bin k1 v1 t1 t2) (bin k2 v2 t3 t4)
doubleL k v l r = singleL k v l r
doubleR k1 v1 (Bin _ k2 v2 t1 (Bin _ k3 v3 t2 t3)) t4 =
  bin k3 v3 (bin k2 v2 t1 t2) (bin k1 v1 t3 t4)
doubleR k v l r = singleR k v l r

empty :: Map k v
empty = Tip

singleton :: k -> v -> Map k v
singleton k v = Bin 1 k v Tip Tip

insert :: Ord k => k -> v -> Map k v -> Map k v
insert = insertWith const

insertWith :: Ord k => (v -> v -> v) -> k -> v -> Map k v -> Map k v
insertWith f k v Tip = singleton k v
insertWith f k v (Bin n k' v' l r) = case compare k k' of
  LT -> balance k' v' (insertWith f k v l) r
  GT -> balance k' v' l (insertWith f k v r)
  EQ -> Bin n k' (f v v') l r

lookup :: Ord k => k -> Map k v -> Maybe v
lookup _ Tip = Nothing
lookup k (Bin _ k' v l r) = case compare k k' of
  LT -> lookup k l
  GT -> lookup k r
  EQ -> Just v

member :: Ord k => k -> Map k v -> Bool
member k m = case lookup k m of { Just _ -> True; _ -> False }

findWithDefault :: Ord k => v -> k -> Map k v -> v
findWithDefault d k m = case lookup k m of { Just v -> v; _ -> d }

adjust :: Ord k => (v -> v) -> k -> Map k v -> Map k v
adjust _ _ Tip = Tip
adjust f k (Bin n k' v l r) = case compare k k' of
  LT -> Bin n k' v (adjust f k l) r
  GT -> Bin n k' v l (adjust f k r)
  EQ -> Bin n k' (f v) l r

-- deletion goes through the sorted list; it is rare in this codebase and not
-- worth the extra balancing cases
delete :: Ord k => k -> Map k v -> Map k v
delete k m = fromList [kv | kv <- toList m, fst kv /= k]

union :: Ord k => Map k v -> Map k v -> Map k v
union a b = P.foldr (\ (k, v) m -> insert k v m) b (toList a)

unions :: Ord k => [Map k v] -> Map k v
unions = P.foldr union empty

difference :: Ord k => Map k v -> Map k v' -> Map k v
difference a b = fromList [kv | kv <- toList a, not (member (fst kv) b)]

infixl 9 \\
(\\) :: Ord k => Map k v -> Map k v' -> Map k v
(\\) = difference

toList, toAscList :: Map k v -> [(k, v)]
toList = foldrWithKey (\k v acc -> (k, v) : acc) []
toAscList = toList

foldrWithKey :: (k -> v -> b -> b) -> b -> Map k v -> b
foldrWithKey _ z Tip = z
foldrWithKey f z (Bin _ k v l r) = foldrWithKey f (f k v (foldrWithKey f z r)) l

filterWithKey :: Ord k => (k -> v -> Bool) -> Map k v -> Map k v
filterWithKey p m = fromList [kv | kv <- toList m, p (fst kv) (snd kv)]

fromList :: Ord k => [(k, v)] -> Map k v
fromList = P.foldl (\m kv -> insertWith (\_ old -> old) (fst kv) (snd kv) m) empty

keys :: Map k v -> [k]
keys = P.map fst . toList

elems :: Map k v -> [v]
elems = P.map snd . toList

null :: Map k v -> Bool
null Tip = True
null _   = False

instance (Show k, Show v) => Show (Map k v) where
  show m = "fromList " ++ show (toList m)

instance (Eq k, Eq v) => Eq (Map k v) where
  a == b = toList a == toList b
