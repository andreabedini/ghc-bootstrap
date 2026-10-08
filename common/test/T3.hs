-- The install check for GHC 6.10 and later (ghc66/test/T2.hs
-- with 6.10's extensible exceptions): sorting, Data.Map, Integer through GMP,
-- Int bounds, Double show/read/round, a caught divide by zero, and the length
-- of 1000!. Expected output: T3.out.
import Data.List (sort)
import qualified Data.Map as M
import Control.Exception (evaluate, try, SomeException)
main :: IO ()
main = do
  putStrLn "hello from a ghc built by the chain"
  print (sort [3,1,2 :: Int], M.toList (M.fromList [(1::Int,"a"),(2,"b")]))
  print (2 ^ (200 :: Int) :: Integer, minBound :: Int, maxBound :: Int)
  print (show (1.5 :: Double), read "2.25" :: Double, round (2.5 :: Double) :: Int)
  r <- try (evaluate (1 `div` (0 :: Int))) :: IO (Either SomeException Int)
  print r
  print (length (show (product [1..1000 :: Integer])))
