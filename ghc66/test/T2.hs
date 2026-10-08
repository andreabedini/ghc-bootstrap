import Data.List (sort)
import qualified Data.Map as M
import Control.Exception (evaluate, try, Exception)
main :: IO ()
main = do
  putStrLn "hello from ghc 6.6 built by 6.2.2"
  print (sort [3,1,2 :: Int], M.toList (M.fromList [(1::Int,"a"),(2,"b")]))
  print (2 ^ (200 :: Int) :: Integer, minBound :: Int, maxBound :: Int)
  print (show (1.5 :: Double), read "2.25" :: Double, round (2.5 :: Double) :: Int)
  r <- try (evaluate (1 `div` (0 :: Int))) :: IO (Either Exception Int)
  print r
  print (length (show (product [1..1000 :: Integer])))
