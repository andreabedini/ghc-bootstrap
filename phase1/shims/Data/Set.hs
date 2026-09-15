-- A sorted-list Data.Set. MicroHs has no containers; happy uses ten functions
-- of it. O(n) insert is fine at happy's scale and keeps the shim auditable.
module Data.Set(Set, empty, singleton, insert, delete, member, notMember,
                union, unions, difference, intersection, null, size,
                toList, toAscList, fromList, elems, foldr, map, filter,
                (\\)) where
import Prelude hiding (null, foldr, map, filter)
import qualified Prelude as P
import qualified Data.List as L

newtype Set a = Set [a]        -- always sorted and duplicate-free

instance Show a => Show (Set a) where
  show (Set xs) = "fromList " ++ show xs

instance Eq a => Eq (Set a) where
  Set a == Set b = a == b

instance Ord a => Ord (Set a) where
  compare (Set a) (Set b) = compare a b

instance Ord a => Semigroup (Set a) where
  (<>) = union

instance Ord a => Monoid (Set a) where
  mempty = empty

empty :: Set a
empty = Set []

singleton :: a -> Set a
singleton x = Set [x]

insert :: Ord a => a -> Set a -> Set a
insert x (Set ys) = Set (ins ys)
  where ins [] = [x]
        ins (y:ys') = case compare x y of
                        LT -> x : y : ys'
                        EQ -> y : ys'
                        GT -> y : ins ys'

delete :: Ord a => a -> Set a -> Set a
delete x (Set ys) = Set (P.filter (/= x) ys)

member :: Ord a => a -> Set a -> Bool
member x (Set ys) = x `elem` ys

notMember :: Ord a => a -> Set a -> Bool
notMember x s = not (member x s)

union :: Ord a => Set a -> Set a -> Set a
union (Set a) (Set b) = Set (L.sort (L.nub (a ++ b)))

unions :: Ord a => [Set a] -> Set a
unions = P.foldr union empty

-- containers spells difference this way too, and happy uses the operator
infixl 9 \\
(\\) :: Ord a => Set a -> Set a -> Set a
(\\) = difference

difference :: Ord a => Set a -> Set a -> Set a
difference (Set a) (Set b) = Set (P.filter (`notElem` b) a)

intersection :: Ord a => Set a -> Set a -> Set a
intersection (Set a) (Set b) = Set (P.filter (`elem` b) a)

null :: Set a -> Bool
null (Set xs) = P.null xs

size :: Set a -> Int
size (Set xs) = length xs

toList, toAscList, elems :: Set a -> [a]
toList (Set xs) = xs
toAscList = toList
elems = toList

fromList :: Ord a => [a] -> Set a
fromList xs = Set (L.sort (L.nub xs))

foldr :: (a -> b -> b) -> b -> Set a -> b
foldr f z (Set xs) = P.foldr f z xs

map :: Ord b => (a -> b) -> Set a -> Set b
map f (Set xs) = fromList (P.map f xs)

filter :: (a -> Bool) -> Set a -> Set a
filter p (Set xs) = Set (P.filter p xs)
