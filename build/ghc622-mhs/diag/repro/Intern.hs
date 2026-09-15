-- Minimal reproducer for the FastString intern collision (no GHC involved).
-- With one entry already in the table, M.lookup compares b's string against
-- it and so forces the string; the string is built from a's contents, which
-- forces a's FastString, whose strict unique field runs a nested intern while
-- the outer call still holds its stale table snapshot.
module Intern(main) where
import FastString

main :: IO ()
main = do
  let c = mkFastString "$wlgo"     -- a key sharing the "$w" prefix, as in GHC.List
  print (uniqueOfFS c, unpackFS c)
  let a = mkFastString "$smaximum"
      b = mkFastString ("$w" ++ unpackFS a)   -- what OccName.mkWorkerOcc does
  print (uniqueOfFS b, unpackFS b)
  print (uniqueOfFS a, unpackFS a)
  let a' = mkFastString "$smaximum"           -- a fresh lookup of a's string
  print (uniqueOfFS a', unpackFS a')
  putStrLn (if uniqueOfFS a == uniqueOfFS b || uniqueOfFS a /= uniqueOfFS a'
              then "COLLISION" else "ok")
