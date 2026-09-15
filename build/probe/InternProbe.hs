module InternProbe(main) where
import FastString
main :: IO ()
main = do
  let a = mkFastString "alpha"
      b = mkFastString "beta"
      a2 = mkFastString "alpha"
  print (uniqueOfFS a, uniqueOfFS b, uniqueOfFS a2)
  print ("a==b (should be False):", a == b)
  print ("a==a2 (should be True):", a == a2)
