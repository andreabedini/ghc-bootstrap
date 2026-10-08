-- Pattern guards (Haskell 2010) under Hugs.  Expected output at the bottom.
module Main where

import Data.List(sort)
import Data.IORef(IORef,newIORef,readIORef,modifyIORef)
import System.IO.Unsafe(unsafePerformIO)

-- 1. basic generator
f1 :: Maybe Int -> Int
f1 m | Just y <- m = y
     | otherwise   = 0

-- 2. generator followed by a boolean, sharing the bound variable
f2 :: Maybe Int -> String
f2 m | Just y <- m, y > 10 = "big"
     | Just _ <- m         = "small"
     | otherwise           = "none"

-- 3. fall-through to the NEXT EQUATION when every guard fails
f3 :: [Int] -> String
f3 xs | (y:_) <- xs, y > 0 = "positive head"
f3 [] = "empty"
f3 _  = "other"

-- 4. bindings must not escape to a later guard: the y below is the top-level one
y :: Int
y = 99
f4 :: Maybe Int -> Int
f4 m | Just y <- m, False = y
     | otherwise          = y      -- must be 99, not the pattern-bound y

-- 5. let qualifier
f5 :: Int -> Int
f5 n | let m = n * 2, m > 10 = m
     | otherwise            = 0

-- 6. several generators in one guard, later depending on earlier
f6 :: Maybe (Maybe Int) -> Int
f6 mm | Just m <- mm, Just v <- m, v > 0 = v
      | otherwise                        = -1

-- 7. in a case alternative, with a where clause on the alternative
f7 :: Maybe Int -> Int
f7 m = case m of
         _ | Just v <- m, v > lim -> v
           | otherwise            -> lim
         where lim = 5

-- 8. nested patterns and wildcards
f8 :: [(Int,String)] -> String
f8 ps | ((_,s):_) <- ps = s
      | otherwise       = "none"

-- 9. shadowing: the guard binding shadows an outer name within its own guard
n :: Int
n = 1
f9 :: Maybe Int -> (Int,Int)
f9 m | Just n <- m = (n, y)
     | otherwise   = (n, y)

-- 10. laziness: the scrutinee is duplicated by the desugaring, so make sure a
--     guard that never forces its way past the first component still works
f10 :: (Int,[Int]) -> Int
f10 p | (a,_) <- p = a

-- 11. pattern guards inside a class instance method
class Describe a where
  describe :: a -> String
instance Describe (Maybe Int) where
  describe m | Just v <- m, even v = "even " ++ show v
             | Just v <- m         = "odd " ++ show v
             | otherwise           = "nothing"

-- 12. ordinary guards still behave (regression)
f12 :: Int -> String
f12 x | x < 0     = "neg"
      | x == 0    = "zero"
      | otherwise = "pos"

-- 13. TYPE FLOW: the type of the bound variable is fixed only by the body of
--     the guard.  `reads' is overloaded on its result, so unless the guard and
--     the body are typed together there is a Read constraint nothing can
--     discharge.
readInt :: String -> Maybe Int
readInt s | [(v,"")] <- reads s = Just v
          | otherwise           = Nothing

-- 14. the same, with the overloading behind a second, dependent generator
readTwo :: String -> Maybe (Int,Int)
readTwo s | [(a,r)]  <- reads s
          , [(b,"")] <- reads r = Just (a,b)
          | otherwise           = Nothing

-- 15. type flow out of a `let' qualifier as well
readLet :: String -> Int
readLet s | let v = read s, v > (0::Int) = v
          | otherwise                    = 0

-- 16. a guard alongside a where clause: the where binding is visible in the
--     guard, and the guard's own lifted binding must not disturb it
f16 :: Int -> Int
f16 x | Just v <- lk = v + off
      | otherwise    = off
  where lk  = lookup x [(1,10),(2,20)]
        off = 100

-- 17. guarded rhs nested inside the where part of a guarded rhs
f17 :: Int -> Int
f17 x | Just v <- Just x = g v
      | otherwise        = 0
  where g n | Just w <- Just (n*2), w > 4 = w
            | otherwise                   = -1

-- 18. a guard inside a case alternative inside a guard's own qualifier
f18 :: Int -> String
f18 x | Just v <- (case x of _ | x > 0 -> Just x
                               | otherwise -> Nothing) = "pos " ++ show v
      | otherwise                                      = "non-pos"

-- 19. the scrutinee is matched once, not once per guard and once per body
counter :: IORef Int
counter = unsafePerformIO (newIORef 0)

tick :: a -> a
tick v = unsafePerformIO (do modifyIORef counter (+1); return v)

f19 :: Int -> Int
f19 x | Just v <- tick (Just x) = v
      | otherwise               = 0

-- 20. purely boolean multi-qualifier guards need no lifted binding
f20 :: Int -> String
f20 x | x > 0, x < 10 = "small"
      | x > 0         = "big"
      | otherwise     = "other"

-- 21. pattern bindings (not just function bindings) carry guards too
p21 :: (Int,Int)
p21 | Just v <- Just (7::Int) = (v, v*2)
    | otherwise               = (0,0)

-- 22. guards in a local `let', binding a name that also exists outside
lim22 :: Int
lim22 = 3
f22 :: Int -> Int
f22 x = let h lim | Just v <- Just lim, v > lim22 = v
                  | otherwise                     = lim22
        in h x

-- 23. the lifted binding is spliced into the same decls list as the where
--     part, so multi-equation functions there must stay contiguous (and a
--     type signature among them must still attach to its binding)
f23 :: Int -> String
f23 x | Just v <- lk x, v == "one" = "1:" ++ p v
      | Just v <- lk x             = "?:" ++ p v
      | otherwise                  = "-"
  where lk 1 = Just "one"
        lk 2 = Just "two"
        lk _ = Nothing
        p a  = a
        cnt :: Int -> Int
        cnt 0 = 0
        cnt n = cnt (n-1)

main :: IO ()
main = do
  print (f1 (Just 3), f1 Nothing)
  print (f2 (Just 20), f2 (Just 1), f2 Nothing)
  print (f3 [5,6], f3 [], f3 [-1])
  print (f4 (Just 7))
  print (f5 8, f5 1)
  print (f6 (Just (Just 4)), f6 (Just Nothing), f6 Nothing)
  print (f7 (Just 9), f7 (Just 1), f7 Nothing)
  print (f8 [(1,"a")], f8 [])
  print (f9 (Just 42), f9 Nothing)
  print (f10 (7, undefined))
  print (describe (Just (4::Int)), describe (Just (5::Int)), describe (Nothing :: Maybe Int))
  print (f12 (-1), f12 0, f12 1)
  print (readInt "42", readInt "x", readInt "1 2")
  print (readTwo "1 2", readTwo "nope")
  print (readLet "5", readLet "-5")
  print (f16 1, f16 3)
  print (f17 3, f17 1)
  print (f18 2, f18 (-2))
  print (f19 5)
  readIORef counter >>= \c -> putStrLn ("scrutinee matched " ++ show c ++ " time(s)")
  print (f20 5, f20 50, f20 (-1))
  print p21
  print (f22 9, f22 1)
  print (f23 1, f23 2, f23 3)
  print (sort [3,1,2::Int])
