module Main where
main :: IO ()
main = print (properFraction (2.5 :: Double) :: (Integer, Double))
