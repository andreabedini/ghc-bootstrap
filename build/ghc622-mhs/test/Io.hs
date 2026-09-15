module Main where
import System.IO
import System.Environment
import System.Exit
import Data.IORef
import Data.Char (toUpper)
main :: IO ()
main = do
  hSetBuffering stdout LineBuffering
  args <- getArgs
  name <- getProgName
  putStrLn (name ++ " " ++ show args)
  l <- getLine
  putStrLn (map toUpper l)
  rest <- getContents
  print (length (lines rest), sum (map read (lines rest) :: [Int]))
  r <- newIORef (0 :: Int)
  mapM_ (\i -> modifyIORef r (+i)) [1..100]
  readIORef r >>= print
  writeFile "tmp/io-test.txt" (unlines (map show [1..10 :: Int]))
  s <- readFile "tmp/io-test.txt"
  print (sum (map read (lines s) :: [Int]))
  appendFile "tmp/io-test.txt" "11\n"
  h <- openFile "tmp/io-test.txt" ReadMode
  n <- fmap (length . lines) (hGetContents h)
  print n
  hPutStrLn stderr "to stderr"
  hFlush stdout
  exitWith (ExitFailure 3)
