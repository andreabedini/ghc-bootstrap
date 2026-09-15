module Main where
import System.IO
main :: IO ()
main = do
  h <- openFile "test/FSize.hs" ReadMode
  n <- hFileSize h
  putStrLn ("hFileSize reports " ++ show n)
  hClose h
