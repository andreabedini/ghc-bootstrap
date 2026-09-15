module Main where
main :: IO ()
main = getLine >>= \s -> print (round (read s :: Double) :: Integer, round (2.5 :: Double) :: Int, round (2.5 :: Float) :: Integer)
