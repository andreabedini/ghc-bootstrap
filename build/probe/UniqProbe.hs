module UniqProbe(main) where
import FastString(mkFastString, uniqueOfFS)
import Unique
main :: IO ()
main = do
  let a = mkFastString "alpha"
      b = mkFastString "beta"
      ua = getUnique a
      ub = getUnique b
  print (uniqueOfFS a, uniqueOfFS b)
  print (getKey ua, getKey ub)
  print ("uniques differ (should be True):", ua /= ub)
  let m1 = mkUnique 'x' 1
      m2 = mkUnique 'x' 2
      m3 = mkUnique 'y' 1
  print (getKey m1, getKey m2, getKey m3)
  print ("mkUnique distinct:", m1 /= m2, m1 /= m3)
