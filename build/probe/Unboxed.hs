module Unboxed(main) where
type Int# = Int
main :: IO ()
main = print (0# + 1#)
