module PatSyn(main) where
type Int# = Int
pattern I# :: Int# -> Int
pattern I# x = x
double :: Int -> Int
double n = case n of I# m -> I# (m + m)
main :: IO ()
main = print (double 21)
