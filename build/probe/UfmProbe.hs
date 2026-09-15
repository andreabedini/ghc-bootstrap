module UfmProbe(main) where
import FastString(mkFastString)
import Unique
import UniqFM
main :: IO ()
main = do
  let ks = [mkFastString s | s <- ["alpha","beta","gamma","f","T","A","B"]]
      fm = listToUFM [(k, s) | (k, s) <- zip ks ["1","2","3","4","5","6","7"]]
  print (sizeUFM fm)
  print [lookupUFM fm k | k <- ks]
