module DupProbe(main) where
import Util(removeDups, equivClasses, sortLt)
main :: IO ()
main = do
  print (sortLt (<) [3,1,2,1::Int])
  print (equivClasses compare [3,1,2,1::Int])
  print (removeDups compare [3,1,2,1::Int])
  print (removeDups compare [4,3,2,1::Int])   -- no dups: expect ([1,2,3,4],[])
