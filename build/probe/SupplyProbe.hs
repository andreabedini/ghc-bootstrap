module SupplyProbe(main) where
import UniqSupply
import Unique
main :: IO ()
main = do
  us <- mkSplitUniqSupply 'x'
  let ten = uniqsFromSupply 10 us
  print (map getKey ten)
  let (a, b) = splitUniqSupply us
  print (getKey (uniqFromSupply a), getKey (uniqFromSupply b))
  let (c, d) = splitUniqSupply a
  print (getKey (uniqFromSupply c), getKey (uniqFromSupply d))
