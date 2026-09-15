module Main where
import Data.List (foldl')
main :: IO ()
main = do
  let xs = [1 .. 2000000] :: [Int]
  print (foldl' (+) 0 xs)
  print (length (filter even (map (*3) xs)))
  let big = product [1 .. 3000 :: Integer]
  print (length (show big))
  let ys = reverse [1 .. 300000 :: Int]
  print (sum (take 10 ys), length ys)
  print (sum (map fromIntegral (take 100000 xs)) :: Integer)
