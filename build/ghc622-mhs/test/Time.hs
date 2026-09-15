module Main where
import System.Time
import System.CPUTime
import System.Directory
import System.Random
import Text.Regex
import Data.List (sort)
main :: IO ()
main = do
  t <- getClockTime
  c <- toCalendarTime t
  putStrLn ("year ok: " ++ show (ctYear c >= 2026))
  let d = diffClockTimes (addToClockTime noTimeDiff { tdMin = 90 } t) t
  print (tdMin (normalizeTimeDiff d), tdHour (normalizeTimeDiff d))
  putStrLn (calendarTimeToString (toUTCTime (TOD 0 0)))
  cpu <- getCPUTime
  print (cpu >= 0, cpuTimePrecision > 0)
  cwd <- getCurrentDirectory
  print (not (null cwd))
  e1 <- doesFileExist "Time.hs"
  e2 <- doesDirectoryExist "tmp"
  e3 <- doesFileExist "no-such-file"
  print (e1, e2, e3)
  fs <- getDirectoryContents "."
  print ("Time.hs" `elem` fs, "Hello.hs" `elem` fs)
  createDirectory "tmp/dirtest"
  writeFile "tmp/dirtest/a" "x"
  renameFile "tmp/dirtest/a" "tmp/dirtest/b"
  fs2 <- getDirectoryContents "tmp/dirtest"
  print (sort fs2)
  removeFile "tmp/dirtest/b"
  removeDirectory "tmp/dirtest"
  let g = mkStdGen 42
      (a, g') = randomR (1, 6 :: Int) g
      (b, _) = randomR (1, 6 :: Int) g'
  print (a >= 1 && a <= 6, b >= 1 && b <= 6, take 5 (randomRs (0, 9 :: Int) g) == take 5 (randomRs (0, 9 :: Int) (mkStdGen 42)))
  r <- randomRIO (100, 200 :: Int)
  print (r >= 100 && r <= 200)
  xs <- sequence (replicate 1000 (randomRIO (0, 1 :: Double)))
  print (all (\x -> x >= 0 && x <= 1) xs, length (filter (< 0.5) xs) > 300)
  print (matchRegex (mkRegex "([a-z]+)-([0-9]+)") "item abc-123 end")
  print (matchRegex (mkRegex "^foo") "barfoo")
