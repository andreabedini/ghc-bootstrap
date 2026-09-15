module Main where
main :: IO ()
main = print (2.5 :: Double) >> print (truncate (1e10 :: Double) :: Int) >> print (floor (-0.5 :: Double) :: Int)
