module Main where
import Prelude hiding (catch)
import Control.Exception hiding (catch)
import qualified Control.Exception as E
import System.IO (hFlush, stdout)
main :: IO ()
main = do
  r <- try (evaluate (1 `div` (0 :: Int)))
  case r of
    Left e -> putStrLn ("caught: " ++ show (e :: Exception))
    Right v -> print v
  r2 <- try (evaluate (head ([] :: [Int])))
  putStrLn (either (\e -> "caught: " ++ takeWhile (/= '\n') (show (e :: Exception))) show r2)
  r3 <- try (evaluate (error "boom" :: Int))
  putStrLn (either (\e -> "caught: " ++ show (e :: Exception)) show r3)
  r4 <- try (readFile "/nonexistent/file")
  putStrLn (either (\e -> "caught: " ++ show (e :: Exception)) (const "read?") r4)
  (throwIO (ErrorCall "inner") `E.catch` \e -> putStrLn ("handler: " ++ show (e :: Exception)))
    `finally` putStrLn "finally ran"
  hFlush stdout
  putStrLn "now dying"
  _ <- evaluate (length [1 .. (10 :: Int)] `div` 0)
  putStrLn "not reached"
