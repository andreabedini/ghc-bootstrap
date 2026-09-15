module Main where
import GHC.Base (minInt, maxInt)
import Data.Int
main :: IO ()
main = do
  print (minBound :: Int)
  print (maxBound :: Int)
  print (minInt == minBound, maxInt == maxBound, minInt)
  print (negate 5 :: Int, -5 :: Int, minBound + 1 :: Int)
  print (minBound :: Int8, minBound :: Int16, minBound :: Int32, minBound :: Int64)
  print (map fromEnum "a\955")
  putStrLn (show (minBound :: Int) ++ " " ++ show (toInteger (minBound :: Int)))
